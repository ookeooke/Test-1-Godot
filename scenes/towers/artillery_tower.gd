extends StaticBody2D

# ============================================
# ARTILLERY TOWER - Long-range siege tower
# ============================================
#
# DIFFERENCES FROM ARCHER:
# - Longest range, highest single-shot damage
# - Very slow attack speed
# - Has splash damage (grows with levels)
# - Cannon path adds knockback, Mortar path has massive AOE
# ============================================

# TOWER IDENTITY
@export var tower_id: String = "artillery"

# TARGETING MODES (same as archer)
enum TargetingMode {
	FIRST,   # Furthest on path (default)
	LAST,    # Closest to path start
	CLOSE,   # Nearest to tower
	STRONG,  # Highest current health
	WEAK     # Lowest current health
}

# TOWER STATS - Unified Stat System
var stat_damage: Stat
var stat_attack_speed: Stat
var stat_range: Stat
var stat_splash_radius: Stat

# Computed properties
var damage: float:
	get: return stat_damage.get_value() if stat_damage else 0.0

var attack_speed: float:
	get: return stat_attack_speed.get_value() if stat_attack_speed else 0.0

var range_radius: float:
	get: return stat_range.get_value() if stat_range else 0.0

var splash_radius: float:
	get: return stat_splash_radius.get_value() if stat_splash_radius else 0.0

var targeting_mode = TargetingMode.FIRST
var build_cost = 100  # Most expensive tower

# UPGRADE SYSTEM
var tower_level = 1
var upgrade_path = ""  # "" = not chosen, "cannon" = knockback, "mortar" = AOE
const MAX_LEVEL_BEFORE_CHOICE = 3
const MAX_LEVEL = 5

# TARGET SELECTION TUNING
const PROGRESS_EPSILON := 0.01
const PROGRESS_SWITCH_THRESHOLD := 0.05
const HEALTH_EPSILON := 1.0
const HEALTH_SWITCH_THRESHOLD := 25.0
const MIN_TARGET_LOCK_TIME := 0.25

var last_target_change_time_msec := 0

# REFERENCES
var detection_range: Area2D
var click_area: Area2D
var range_indicator: Polygon2D
var shoot_timer: Timer
var artillery_weapon: Node2D  # Visual weapon node
var mode_label: Label
var debug_line: Line2D

# SELECTION STATE
var is_selected = false

# TARGETING
var enemies_in_range = []
var current_target = null

# PROJECTILE
@export var projectile_scene: PackedScene

# TOWER SPOT reference
var parent_spot = null

# ============================================
# STAT INITIALIZATION
# ============================================

func _initialize_stats():
	"""Initialize all Stat objects with base values from TowerData"""
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)

	if level_1_stats.is_empty():
		push_error("[ArtilleryTower] CRITICAL: Failed to load stats from TowerData!")
		stat_damage = Stat.new(0.0)
		stat_attack_speed = Stat.new(0.0)
		stat_range = Stat.new(0.0)
		stat_splash_radius = Stat.new(0.0)
	else:
		stat_damage = Stat.new(level_1_stats["damage"])
		stat_attack_speed = Stat.new(level_1_stats["attack_speed"])
		stat_range = Stat.new(level_1_stats["range"])
		stat_splash_radius = Stat.new(level_1_stats["splash_radius"])

	print("[ArtilleryTower] Stats initialized - DMG: %.1f, AS: %.1f, Range: %.1f, Splash: %.1f" %
		[stat_damage.get_value(), stat_attack_speed.get_value(), stat_range.get_value(), stat_splash_radius.get_value()])

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Initialize stats FIRST
	_initialize_stats()

	# Get references to child nodes
	detection_range = $DetectionRange
	range_indicator = $RangeIndicator

	# Setup click detection
	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	# Get artillery weapon reference
	if has_node("Artillery/Weapon"):
		artillery_weapon = $Artillery/Weapon

	# Set collision detection
	detection_range.collision_layer = 8  # Tower range is layer 4
	detection_range.collision_mask = 1   # Detect enemies on layer 1
	detection_range.monitoring = true

	# Connect detection signals
	detection_range.body_entered.connect(_on_enemy_entered_range)
	detection_range.body_exited.connect(_on_enemy_exited_range)

	# Register existing enemies
	_defer_enemy_registration()

	# Create shoot timer
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 1.0 / attack_speed
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	shoot_timer.start()

	# Draw range indicator
	_update_range_indicator()

	print("[ArtilleryTower] Ready - Build cost: %dg, Range: %.1f" % [build_cost, range_radius])

func _update_range_indicator():
	"""Draw circular range indicator"""
	if not range_indicator:
		return

	var circle_points = PackedVector2Array()
	var num_points = 64
	for i in range(num_points + 1):
		var angle = (i / float(num_points)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * range_radius
		circle_points.append(point)

	range_indicator.polygon = circle_points
	range_indicator.color = Color(1.0, 0.5, 0.0, 0.2)  # Orange tint for artillery
	range_indicator.visible = is_selected

func _process(_delta):
	# Update weapon rotation toward target
	if current_target and is_instance_valid(current_target) and artillery_weapon:
		var target_direction = (current_target.global_position - global_position).normalized()
		artillery_weapon.rotation = target_direction.angle()

	# Update detection range monitoring
	if detection_range and not detection_range.monitoring:
		detection_range.monitoring = true

	# Update shoot timer if attack speed changed
	if shoot_timer and shoot_timer.wait_time != 1.0 / attack_speed:
		shoot_timer.wait_time = 1.0 / attack_speed

func _defer_enemy_registration():
	"""Wait for physics frame before registering enemies"""
	await get_tree().physics_frame
	_register_existing_enemies()

func _register_existing_enemies():
	"""Detect enemies already in range"""
	if not detection_range:
		return

	var found_enemies = detection_range.get_overlapping_bodies()
	for body in found_enemies:
		_on_enemy_entered_range(body)

# ============================================
# ENEMY DETECTION
# ============================================

func _on_enemy_entered_range(body):
	"""Enemy entered detection range"""
	if not is_instance_valid(body):
		return

	# Check if it's an enemy
	if not body.has_method("take_damage"):
		return

	if not body in enemies_in_range:
		enemies_in_range.append(body)

		# Connect to enemy death signal
		if body.has_signal("enemy_died") and not body.enemy_died.is_connected(_on_enemy_died):
			body.enemy_died.connect(_on_enemy_died.bind(body))

		# Acquire target if we don't have one
		if current_target == null:
			current_target = body

func _on_enemy_exited_range(body):
	"""Enemy left detection range"""
	enemies_in_range.erase(body)

	if current_target == body:
		current_target = null

func _on_enemy_died(enemy):
	"""Enemy died - remove and retarget"""
	enemies_in_range.erase(enemy)

	if current_target == enemy:
		current_target = get_target_by_mode()
		_record_target_change_time()

		# Shoot immediately if we have a new target
		if current_target != null and shoot_timer.time_left < 0.1:
			shoot_at(current_target)

func get_target_by_mode():
	"""Get target based on targeting mode"""
	# Clean up dead enemies
	var filtered_enemies = []
	for e in enemies_in_range:
		if is_instance_valid(e) and (not e.has_method("is_dead") or not e.is_dead()):
			filtered_enemies.append(e)

	enemies_in_range = filtered_enemies

	if enemies_in_range.is_empty():
		return null

	# Select target based on mode
	match targeting_mode:
		TargetingMode.FIRST:
			return _get_first_enemy()
		TargetingMode.LAST:
			return _get_last_enemy()
		TargetingMode.CLOSE:
			return _get_closest_enemy()
		TargetingMode.STRONG:
			return _get_strongest_enemy()
		TargetingMode.WEAK:
			return _get_weakest_enemy()

	return enemies_in_range[0] if enemies_in_range.size() > 0 else null

func _get_first_enemy():
	var best = null
	var best_progress = -1.0
	for e in enemies_in_range:
		var progress = _get_enemy_progress(e)
		if progress > best_progress:
			best_progress = progress
			best = e
	return best

func _get_last_enemy():
	var best = null
	var best_progress = 999.0
	for e in enemies_in_range:
		var progress = _get_enemy_progress(e)
		if progress < best_progress:
			best_progress = progress
			best = e
	return best

func _get_closest_enemy():
	var best = null
	var best_dist = 999999.0
	for e in enemies_in_range:
		var dist = global_position.distance_to(e.global_position)
		if dist < best_dist:
			best_dist = dist
			best = e
	return best

func _get_strongest_enemy():
	var best = null
	var best_health = 0.0
	for e in enemies_in_range:
		var health = _get_enemy_health(e)
		if health > best_health:
			best_health = health
			best = e
	return best

func _get_weakest_enemy():
	var best = null
	var best_health = 999999.0
	for e in enemies_in_range:
		var health = _get_enemy_health(e)
		if health < best_health:
			best_health = health
			best = e
	return best

func _get_enemy_progress(enemy) -> float:
	if enemy.has_method("get_path_progress"):
		return enemy.get_path_progress()
	elif "path_progress" in enemy:
		return enemy.path_progress
	return 0.0

func _get_enemy_health(enemy) -> float:
	if "current_health" in enemy:
		return enemy.current_health
	elif "health" in enemy:
		return enemy.health
	return 0.0

func _record_target_change_time():
	last_target_change_time_msec = Time.get_ticks_msec()

# ============================================
# SHOOTING
# ============================================

func _on_shoot_timer_timeout():
	"""Timer fires - shoot at current target"""
	# Retarget if needed
	if current_target == null or not is_instance_valid(current_target):
		current_target = get_target_by_mode()

	# Shoot if we have a target
	if current_target:
		shoot_at(current_target)

func shoot_at(target):
	"""Shoot artillery projectile with massive damage and splash"""
	if projectile_scene == null:
		print("ERROR: No projectile scene assigned to Artillery Tower!")
		return

	if not is_instance_valid(target):
		current_target = null
		return

	if not enemies_in_range.has(target):
		current_target = null
		return

	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position

	# Set projectile properties
	projectile.damage = damage
	projectile.target = target
	projectile.splash_radius = splash_radius  # AOE damage

	# Add knockback for cannon path
	if upgrade_path == "cannon":
		var cannon_stats = TowerData.get_tower_stats(tower_id, tower_level, "cannon_path")
		if not cannon_stats.is_empty():
			projectile.knockback = cannon_stats.get("knockback", 0)

	print("[ArtilleryTower] Fired artillery shell - DMG: %.1f, Splash: %.1f" % [damage, splash_radius])

# ============================================
# CLICK HANDLING
# ============================================

func _on_area_input_event(_viewport, event, _shape_idx):
	var is_interact = false

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_interact = true
	elif event is InputEventScreenTouch and event.pressed:
		is_interact = true

	if is_interact:
		_on_clicked()
		get_viewport().set_input_as_handled()

func _on_clicked():
	"""Tower clicked - emit signal to parent spot"""
	if parent_spot:
		parent_spot.tower_clicked.emit(parent_spot, self)
	else:
		var spot = get_parent()
		if spot and spot.has_signal("tower_clicked"):
			spot.tower_clicked.emit(spot, self)

func _on_mouse_entered():
	"""Mouse entered tower area"""
	pass

func _on_mouse_exited():
	"""Mouse exited tower area"""
	pass

# ============================================
# SELECTION
# ============================================

func set_selected(selected: bool):
	"""Set tower selection state"""
	is_selected = selected
	if range_indicator:
		range_indicator.visible = is_selected

func get_tower_info() -> Dictionary:
	"""Return tower information for UI"""
	return {
		"tower_id": tower_id,
		"name": TowerData.get_tower_name(tower_id),
		"level": tower_level,
		"path": upgrade_path,
		"damage": damage,
		"attack_speed": attack_speed,
		"range": range_radius,
		"splash_radius": splash_radius,
		"dps": damage * attack_speed,
		"build_cost": build_cost
	}

# ============================================
# UPGRADE SYSTEM (Levels 1-5 with Path Choice)
# ============================================

func upgrade_tower():
	"""Apply standard upgrade (levels 1→2→3 and 4→5 after path choice)"""
	print("🔧 [ArtilleryTower] upgrade_tower() called - Current Level: %d" % tower_level)

	# Check if at Level 3 (needs path choice) or at max level
	if tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		push_warning("[ArtilleryTower] Cannot upgrade past level 3 - must choose path!")
		return false

	if tower_level >= MAX_LEVEL:
		push_warning("[ArtilleryTower] Tower already at MAX LEVEL!")
		return false

	var old_level = tower_level
	var upgrade_cost = get_upgrade_cost()  # Get cost BEFORE upgrading
	tower_level += 1
	build_cost += upgrade_cost  # Track total investment for sell refunds
	print("🔧 [ArtilleryTower] Level changed: %d → %d (Cost: %dg, Total: %dg)" % [old_level, tower_level, upgrade_cost, build_cost])

	# Remove old level modifiers (clean slate for new level)
	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)
	stat_splash_radius.remove_modifiers_from_source(old_source)

	# Get target stats for new level from TowerData
	var mod_source = "upgrade_level_%d" % tower_level
	var target_stats: Dictionary
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)

	if tower_level <= MAX_LEVEL_BEFORE_CHOICE:
		# Levels 2-3: No path choice
		target_stats = TowerData.get_tower_stats(tower_id, tower_level)
	else:
		# Levels 4-5: Path-specific stats
		var path_key = upgrade_path + "_path"
		target_stats = TowerData.get_tower_stats(tower_id, tower_level, path_key)

	if target_stats.is_empty():
		push_error("[ArtilleryTower] Failed to load upgrade stats from TowerData for level %d" % tower_level)
		return false

	# Calculate deltas from base stats (Level 1)
	var damage_delta = target_stats["damage"] - level_1_stats["damage"]
	var attack_speed_delta = target_stats["attack_speed"] - level_1_stats["attack_speed"]
	var range_delta = target_stats["range"] - level_1_stats["range"]
	var splash_delta = target_stats["splash_radius"] - level_1_stats["splash_radius"]

	# Apply modifiers
	if damage_delta != 0:
		stat_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Tower Upgrade Level %d" % tower_level))
	if attack_speed_delta != 0:
		stat_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Tower Upgrade Level %d" % tower_level))
	if range_delta != 0:
		stat_range.add_modifier(StatModifier.create_flat(range_delta, mod_source, "Tower Upgrade Level %d" % tower_level))
	if splash_delta != 0:
		stat_splash_radius.add_modifier(StatModifier.create_flat(splash_delta, mod_source, "Tower Upgrade Level %d" % tower_level))

	print("✅ [ArtilleryTower] Upgraded to Level %d: DMG=%.1f, AS=%.1f, Range=%.1f, Splash=%.1f, DPS=%.1f" % [tower_level, damage, attack_speed, range_radius, splash_radius, damage * attack_speed])

	# Update detection range collision shape
	_update_detection_range()

	# Redraw range indicator with new radius
	draw_range_circle()

	# Update shoot timer with new attack speed
	if shoot_timer:
		shoot_timer.wait_time = 1.0 / attack_speed

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, upgrade_cost)

	return true

func choose_cannon_path():
	"""Choose cannon specialization path (Level 3 → 4 Cannon) - Heavy single-target damage with knockback"""
	if tower_level != MAX_LEVEL_BEFORE_CHOICE:
		push_warning("[ArtilleryTower] Can only choose path at level 3!")
		return false

	if upgrade_path != "":
		push_warning("[ArtilleryTower] Path already chosen: %s" % upgrade_path)
		return false

	var path_cost = get_upgrade_cost()  # Get cost before upgrading
	var old_level = tower_level
	tower_level += 1
	upgrade_path = "cannon"
	build_cost += path_cost  # Track total investment for sell refunds

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)
	stat_splash_radius.remove_modifiers_from_source(old_source)

	# Load cannon path stats from TowerData
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	var target_stats = TowerData.get_tower_stats(tower_id, 4, "cannon_path")

	if target_stats.is_empty():
		push_error("[ArtilleryTower] Failed to load cannon path stats from TowerData")
		return false

	# Calculate deltas from base stats (Level 1)
	var damage_delta = target_stats["damage"] - level_1_stats["damage"]
	var attack_speed_delta = target_stats["attack_speed"] - level_1_stats["attack_speed"]
	var range_delta = target_stats["range"] - level_1_stats["range"]
	var splash_delta = target_stats["splash_radius"] - level_1_stats["splash_radius"]

	# Apply modifiers
	var mod_source = "upgrade_path_cannon"
	if damage_delta != 0:
		stat_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Cannon Path Level 4"))
	if attack_speed_delta != 0:
		stat_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Cannon Path Level 4"))
	if range_delta != 0:
		stat_range.add_modifier(StatModifier.create_flat(range_delta, mod_source, "Cannon Path Level 4"))
	if splash_delta != 0:
		stat_splash_radius.add_modifier(StatModifier.create_flat(splash_delta, mod_source, "Cannon Path Level 4"))

	print("[ArtilleryTower] CANNON PATH chosen: DMG=%.1f, AS=%.1f, Knockback=%.0f - Heavy siege cannon!" % [damage, attack_speed, target_stats.get("knockback", 0)])

	# Update shoot timer
	if shoot_timer:
		shoot_timer.wait_time = 1.0 / attack_speed

	# Update detection range
	_update_detection_range()
	draw_range_circle()

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "cannon")

	return true

func choose_mortar_path():
	"""Choose mortar specialization path (Level 3 → 4 Mortar) - Massive AOE bombardment"""
	if tower_level != MAX_LEVEL_BEFORE_CHOICE:
		push_warning("[ArtilleryTower] Can only choose path at level 3!")
		return false

	if upgrade_path != "":
		push_warning("[ArtilleryTower] Path already chosen: %s" % upgrade_path)
		return false

	var path_cost = get_upgrade_cost()  # Get cost before upgrading
	var old_level = tower_level
	tower_level += 1
	upgrade_path = "mortar"
	build_cost += path_cost  # Track total investment for sell refunds

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)
	stat_splash_radius.remove_modifiers_from_source(old_source)

	# Load mortar path stats from TowerData
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	var target_stats = TowerData.get_tower_stats(tower_id, 4, "mortar_path")

	if target_stats.is_empty():
		push_error("[ArtilleryTower] Failed to load mortar path stats from TowerData")
		return false

	# Calculate deltas from base stats (Level 1)
	var damage_delta = target_stats["damage"] - level_1_stats["damage"]
	var attack_speed_delta = target_stats["attack_speed"] - level_1_stats["attack_speed"]
	var range_delta = target_stats["range"] - level_1_stats["range"]
	var splash_delta = target_stats["splash_radius"] - level_1_stats["splash_radius"]

	# Apply modifiers
	var mod_source = "upgrade_path_mortar"
	if damage_delta != 0:
		stat_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Mortar Path Level 4"))
	if attack_speed_delta != 0:
		stat_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Mortar Path Level 4"))
	if range_delta != 0:
		stat_range.add_modifier(StatModifier.create_flat(range_delta, mod_source, "Mortar Path Level 4"))
	if splash_delta != 0:
		stat_splash_radius.add_modifier(StatModifier.create_flat(splash_delta, mod_source, "Mortar Path Level 4"))

	print("[ArtilleryTower] MORTAR PATH chosen: DMG=%.1f, AS=%.1f, Splash=%.1f - Area bombardment specialist!" % [damage, attack_speed, splash_radius])

	# Update shoot timer
	if shoot_timer:
		shoot_timer.wait_time = 1.0 / attack_speed

	# Update detection range
	_update_detection_range()
	draw_range_circle()

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "mortar")

	return true

func _update_detection_range():
	"""Update the collision shape radius to match new range"""
	if not detection_range:
		return

	# Get the CollisionShape2D child
	for child in detection_range.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape and shape is CircleShape2D:
				shape.radius = range_radius
				print("[ArtilleryTower] Detection range updated to: %d" % range_radius)
			else:
				push_error("[ArtilleryTower] Failed to update detection range - shape is invalid or not CircleShape2D")
			break

	# CRITICAL: Revalidate all tracked enemies after range change
	call_deferred("_revalidate_enemies_in_range")

func _revalidate_enemies_in_range():
	"""Remove enemies that are now outside the updated range"""
	var enemies_to_remove = []

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			enemies_to_remove.append(enemy)
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance > range_radius:
			enemies_to_remove.append(enemy)
			print("[ArtilleryTower] Enemy removed from range after range update (distance: %d > %d)" % [distance, range_radius])

	# Remove invalid enemies
	for enemy in enemies_to_remove:
		enemies_in_range.erase(enemy)
		if current_target == enemy:
			if enemy.has_method("set_debug_targeted"):
				enemy.set_debug_targeted(false)
			current_target = null
			_record_target_change_time()

func get_upgrade_cost() -> int:
	"""Get cost for next upgrade from TowerData (data-driven)"""
	if tower_level >= 5:
		return 0  # Max level reached

	# Query TowerData for current level's cost_to_next
	var current_stats = TowerData.get_tower_stats(tower_id, tower_level, upgrade_path)

	if current_stats and "cost_to_next" in current_stats:
		return current_stats["cost_to_next"]

	# Fallback: should never happen if TowerData is configured correctly
	print("⚠️ [Artillery] WARNING: No cost_to_next found for level %d, path '%s'" % [tower_level, upgrade_path])
	return 0

func get_upgrade_stats(preview_path: String = "") -> Dictionary:
	"""Get preview of what stats will be after upgrade (for UI preview)

	Args:
		preview_path: For Level 3, specify "cannon" or "mortar" to preview that path choice
	"""
	var current_damage = damage
	var current_attack_speed = attack_speed
	var current_range = range_radius
	var current_splash = splash_radius

	# Calculate bonuses based on next level
	var damage_bonus = 0
	var attack_speed_bonus = 0.0
	var range_bonus = 0
	var splash_bonus = 0

	# Determine the preview level and path
	var preview_level = tower_level + 1
	var preview_path_key = ""

	if preview_level == 4 and preview_path != "":
		# Level 3→4 path choice
		preview_path_key = preview_path + "_path"
	elif preview_level == 5 and upgrade_path != "":
		# Level 4→5 with already chosen path
		preview_path_key = upgrade_path + "_path"

	# Load next level stats from TowerData
	var next_level_stats: Dictionary
	if preview_path_key != "":
		next_level_stats = TowerData.get_tower_stats(tower_id, preview_level, preview_path_key)
	else:
		next_level_stats = TowerData.get_tower_stats(tower_id, preview_level)

	if not next_level_stats.is_empty():
		damage_bonus = next_level_stats.get("damage", 0) - current_damage
		attack_speed_bonus = next_level_stats.get("attack_speed", 0.0) - current_attack_speed
		range_bonus = next_level_stats.get("range", 0) - current_range
		splash_bonus = next_level_stats.get("splash_radius", 0) - current_splash

	return {
		"damage": current_damage,
		"damage_bonus": damage_bonus,
		"attack_speed": current_attack_speed,
		"attack_speed_bonus": attack_speed_bonus,
		"range": current_range,
		"range_bonus": range_bonus,
		"splash_radius": current_splash,
		"splash_bonus": splash_bonus
	}

func can_upgrade() -> bool:
	"""Check if tower can be upgraded"""
	if tower_level < MAX_LEVEL_BEFORE_CHOICE:
		return true  # Can do standard upgrade (Lv1→2, Lv2→3)
	elif tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		return true  # Can choose path (Lv3→4)
	elif tower_level == 4 and upgrade_path != "":
		return true  # Can do final upgrade (Lv4→5)
	return false  # Level 5 = MAX LEVEL

func needs_path_choice() -> bool:
	"""Check if tower is at level 3 and needs to choose a path"""
	return tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == ""

# ============================================
# VISUAL FUNCTIONS
# ============================================

func draw_range_circle():
	"""Draw a filled circle to show range (Kingdom Rush style)"""
	var points = []
	var num_points = 64  # More points = smoother circle

	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU  # TAU = 2*PI (full circle)
		var x = cos(angle) * range_radius
		var y = sin(angle) * range_radius
		points.append(Vector2(x, y))

	# Set polygon points for filled circle
	range_indicator.polygon = PackedVector2Array(points)

	# Set orange color for artillery tower (matches Kingdom Rush artillery style)
	range_indicator.color = Color(1.0, 0.5, 0.0, 0.3)  # Orange, 30% opacity

func select_tower():
	"""Show range indicator when tower is selected"""
	is_selected = true
	range_indicator.visible = true

func deselect_tower():
	"""Hide range indicator when tower is deselected"""
	is_selected = false
	range_indicator.visible = false
