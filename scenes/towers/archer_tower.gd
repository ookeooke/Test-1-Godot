extends StaticBody2D

# ============================================
# ARCHER TOWER - Shoots arrows at enemies
# ============================================
#
# TARGETING SYSTEM:
# - FIRST mode: Targets enemy furthest along the path (closest to exit)
# - STRONG mode: Targets enemy with highest current health
# - Focus stickiness prevents rapid target swapping
# - Deterministic tie-breaking for consistent behavior
# - Player can change mode via tower upgrade menu
# ============================================

# TARGETING MODES
enum TargetingMode {
	FIRST,   # Furthest on path (default)
	LAST,    # Closest to path start
	CLOSE,   # Nearest to tower
	STRONG,  # Highest current health
	WEAK     # Lowest current health
}

# BASE STATS (constants for reference)
const BASE_DAMAGE = 12.0
const BASE_ATTACK_SPEED = 1.0
const BASE_RANGE = 300.0

# TOWER STATS - Unified Stat System (Kingdom Rush pacing: -25% to match slower enemies)
var stat_damage: Stat
var stat_attack_speed: Stat
var stat_range: Stat

# Computed properties for backwards compatibility
var damage: float:
	get: return stat_damage.get_value() if stat_damage else BASE_DAMAGE

var attack_speed: float:
	get: return stat_attack_speed.get_value() if stat_attack_speed else BASE_ATTACK_SPEED

var range_radius: float:
	get: return stat_range.get_value() if stat_range else BASE_RANGE

var targeting_mode = TargetingMode.FIRST  # Default targeting mode
var build_cost = 70  # BALANCE FIX: Was 100g, now 70g (28% of 250g start gold - matches KR1's 26%)

# UPGRADE SYSTEM
var tower_level = 1  # Current upgrade level (1-5)
var upgrade_path = "" # "" = not chosen, "damage" = damage path, "range" = range path
const MAX_LEVEL_BEFORE_CHOICE = 3  # At level 3, player must choose a path
const MAX_LEVEL = 5  # Maximum tower level after all upgrades

# TARGET SELECTION TUNING
const PROGRESS_EPSILON := 0.01
const PROGRESS_SWITCH_THRESHOLD := 0.05
const HEALTH_EPSILON := 1.0
const HEALTH_SWITCH_THRESHOLD := 25.0
const MIN_TARGET_LOCK_TIME := 0.25

var last_target_change_time_msec := 0

# REFERENCES
var detection_range: Area2D
var click_area: Area2D  # For clicking the tower
var range_indicator: Polygon2D  # Changed from Line2D to Polygon2D for filled circle
var shoot_timer: Timer
var archer_weapon: Node2D  # The weapon that rotates toward enemies
var mode_label: Label  # Visual indicator for targeting mode
var debug_line: Line2D  # Visual targeting line (F4 debug)

# SELECTION STATE
var is_selected = false

# TARGETING
var enemies_in_range = []  # List of enemies we can shoot
var current_target = null  # Enemy we're currently aiming at

# PROJECTILE
@export var projectile_scene: PackedScene

# TOWER SPOT reference (set by tower_spot when placing)
var parent_spot = null

# ============================================
# STAT INITIALIZATION
# ============================================

func _initialize_stats():
	"""Initialize all Stat objects with base values"""
	stat_damage = Stat.new(BASE_DAMAGE)
	stat_attack_speed = Stat.new(BASE_ATTACK_SPEED)
	stat_range = Stat.new(BASE_RANGE)

	print("[ArcherTower] Stats initialized - DMG: %.1f, AS: %.1f, Range: %.1f" % [stat_damage.get_value(), stat_attack_speed.get_value(), stat_range.get_value()])

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Initialize stat system FIRST
	_initialize_stats()

	# Get references to child nodes
	detection_range = $DetectionRange
	range_indicator = $RangeIndicator

	# Setup click detection (if ClickArea node exists in scene)
	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	# Get archer weapon reference
	if has_node("Archer/Weapon"):
		archer_weapon = $Archer/Weapon

	# IMPORTANT: Set collision mask to detect enemies (layer 1)
	detection_range.collision_layer = 8  # Tower range is layer 4
	detection_range.collision_mask = 1   # Detect enemies on layer 1
	detection_range.monitoring = true

	# Connect detection signals
	detection_range.body_entered.connect(_on_enemy_entered_range)
	detection_range.body_exited.connect(_on_enemy_exited_range)

	# Godot won't emit body_entered for enemies already inside the Area2D
	# when the tower is placed. Wait for physics to update, then detect them.
	# CRITICAL: Must wait for physics frame to ensure collision detection is ready
	# and tower position is properly set (prevents race conditions)
	_defer_enemy_registration()

	# Create shoot timer
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 1.0 / attack_speed  # Convert attacks/sec to seconds
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	shoot_timer.start()

	# Draw range indicator (filled circle)
	draw_range_circle()

	# Hide range by default (show only when selected)
	range_indicator.visible = false

	# Create mode label for visual feedback
	mode_label = Label.new()
	add_child(mode_label)
	mode_label.position = Vector2(-30, -80)  # Above tower
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 10)
	update_mode_label()

	# Create debug line for visual targeting (F4)
	debug_line = Line2D.new()
	add_child(debug_line)
	debug_line.width = 3.0
	debug_line.default_color = Color.RED
	debug_line.z_index = 100
	debug_line.visible = false

	last_target_change_time_msec = Time.get_ticks_msec()

	# Register with BalanceTracker
	if BalanceTracker:
		BalanceTracker.register_tower(self, "archer_tower", build_cost)

func _process(delta):
	# Rotate archer's weapon toward the current target
	if current_target and is_instance_valid(current_target):
		if archer_weapon:
			# Make weapon point at enemy
			archer_weapon.look_at(current_target.global_position)

		# Visual debug: Draw line to current target (F4)
		if DebugConfig.visual_debug_enabled and debug_line:
			debug_line.visible = true
			debug_line.points = [Vector2.ZERO, to_local(current_target.global_position)]
	else:
		if debug_line:
			debug_line.visible = false

	# Queue redraw for custom debug rendering
	if DebugConfig.visual_debug_enabled:
		queue_redraw()

func _physics_process(delta):
	# Safety: Ensure monitoring is always enabled
	# This prevents detection failures if monitoring gets disabled somehow
	if detection_range and not detection_range.monitoring:
		push_warning("[ArcherTower] Detection range monitoring was disabled! Re-enabling...")
		detection_range.monitoring = true

func _draw():
	"""Custom drawing for debug visualization (F4)"""
	if not DebugConfig.visual_debug_enabled:
		return

	# Draw detection range circle outline
	draw_arc(Vector2.ZERO, range_radius, 0, TAU, 64, Color(0, 1, 0, 0.5), 2.0)

	# Draw range text
	var range_text = "R: %d" % range_radius
	var font = ThemeDB.fallback_font
	var font_size = 16
	draw_string(font, Vector2(-20, -range_radius - 10), range_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.GREEN)

	# Draw enemy info for all enemies in range
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue

		var enemy_pos = to_local(enemy.global_position)
		var distance = global_position.distance_to(enemy.global_position)
		var is_boss = _is_enemy_boss(enemy)

		# Draw distance line - RED for boss, gray for normal enemies
		var line_color = Color.RED if is_boss else Color(0.5, 0.5, 0.5, 0.3)
		var line_width = 3.0 if is_boss else 1.0
		draw_line(Vector2.ZERO, enemy_pos, line_color, line_width)

		# Draw boss highlight circle
		if is_boss:
			draw_circle(enemy_pos, 40.0, Color(1, 0, 0, 0.3))  # Red translucent circle
			draw_arc(enemy_pos, 40.0, 0, TAU, 32, Color.RED, 3.0)  # Red outline

		# Get enemy info
		var progress = _get_enemy_progress(enemy)
		var health = _get_enemy_health(enemy)

		# Build info text based on targeting mode
		var info_text = ""
		match targeting_mode:
			TargetingMode.FIRST, TargetingMode.LAST:
				info_text = "P:%.2f" % progress
			TargetingMode.CLOSE:
				info_text = "D:%d" % int(distance)
			TargetingMode.STRONG, TargetingMode.WEAK:
				info_text = "H:%d" % int(health)

		# Add BOSS tag for boss enemies
		if is_boss:
			info_text = "🔴BOSS🔴\n" + info_text

		# Draw info label near enemy
		var label_pos = enemy_pos + Vector2(0, -50 if is_boss else -30)
		var text_color = Color.RED if is_boss else (Color.YELLOW if enemy == current_target else Color.WHITE)
		draw_string(font, label_pos, info_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16 if is_boss else 14, text_color)

	# Draw enemy count
	var count_text = "Enemies: %d" % enemies_in_range.size()
	draw_string(font, Vector2(-40, range_radius + 20), count_text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.CYAN)

# ============================================
# CLICK HANDLING - Using Area2D
# ============================================

func _on_area_input_event(_viewport, event, _shape_idx):
	# Support both mouse and touch input
	var is_interact = false

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_interact = true
	elif event is InputEventScreenTouch and event.pressed:
		is_interact = true

	if is_interact:
		_on_clicked()
		get_viewport().set_input_as_handled()

func _on_clicked():
	"""Called when tower is clicked"""
	# Find the parent tower spot and emit its signal
	if parent_spot:
		parent_spot.tower_clicked.emit(parent_spot, self)
	else:
		# Fallback: try to find parent spot by going up the tree
		var spot = get_parent()
		if spot and spot.has_signal("tower_clicked"):
			spot.tower_clicked.emit(spot, self)
		else:
			print("ERROR: Could not find parent tower spot!")

func _on_mouse_entered():
	"""Called when mouse enters tower area"""
	# Brighten the tower visual
	if has_node("TowerVisual"):
		$TowerVisual.modulate = Color(1.3, 1.3, 1.3)

func _on_mouse_exited():
	"""Called when mouse leaves tower area"""
	# Reset tower visual
	if has_node("TowerVisual"):
		$TowerVisual.modulate = Color(1, 1, 1)

# ============================================
# TARGETING FUNCTIONS
# ============================================

func _on_enemy_entered_range(body):
	# An enemy entered our range
	if body.is_in_group("enemy"):
		# CRITICAL: Connect death signal FIRST, before duplicate check
		# This ensures signal is always connected even if enemy is already in list
		if body.has_signal("enemy_died") and not body.enemy_died.is_connected(_on_enemy_died):
			body.enemy_died.connect(_on_enemy_died.bind(body))

		# Prevent duplicates (can happen when manually registering existing enemies)
		if enemies_in_range.has(body):
			return

		var enemy_name = body.get_enemy_name() if body.has_method("get_enemy_name") else "Unknown"
		var is_boss = _is_enemy_boss(body)
		var boss_tag = " [BOSS]" if is_boss else ""

		enemies_in_range.append(body)

		# Debug logging
		DebugConfig.log_targeting("✅ Enemy entered range: %s%s (Total: %d)" % [enemy_name, boss_tag, enemies_in_range.size()])

		# Extra debug for boss enemies
		if is_boss:
			print("🔴 BOSS DETECTED IN RANGE: %s at position %s" % [enemy_name, body.global_position])
			print("   - Parent type: %s" % body.get_parent().get_class())
			print("   - Has current_health: %s" % ("current_health" in body))
			if "current_health" in body:
				print("   - Current health: %.1f" % body.current_health)

func _on_enemy_exited_range(body):
	# An enemy left our range
	if body.is_in_group("enemy"):
		enemies_in_range.erase(body)

		if current_target == body:
			if body.has_method("set_debug_targeted"):
				body.set_debug_targeted(false)
			current_target = null
			_record_target_change_time()


func _defer_enemy_registration():
	"""Async wrapper to wait for physics frame before registering enemies"""
	await get_tree().physics_frame
	_register_existing_enemies()

func _register_existing_enemies():
	"""Detect enemies that were already in range when tower was placed"""
	if not detection_range:
		print("[ArcherTower] WARNING: detection_range not found during enemy registration")
		return

	var found_enemies = detection_range.get_overlapping_bodies()
	print("[ArcherTower] Registering %d existing enemies in range" % found_enemies.size())

	for body in found_enemies:
		_on_enemy_entered_range(body)


func _on_enemy_died(enemy):
	"""Called when an enemy dies - remove immediately and retarget"""
	# Remove from tracking list
	enemies_in_range.erase(enemy)

	# If this was our current target, immediately find new target
	if current_target == enemy:
		DebugConfig.log_targeting("Target died, retargeting...")
		if enemy.has_method("set_debug_targeted"):
			enemy.set_debug_targeted(false)
		current_target = get_target_by_mode()
		_record_target_change_time()

		# If we found a new target and we're ready to shoot, shoot immediately
		# This prevents DPS downtime during intense waves
		if current_target != null and shoot_timer.time_left < 0.1:
			shoot_at(current_target)

func get_target_by_mode():
	"""Get target based on current targeting mode"""
	var original_count = enemies_in_range.size()

	# Clean up dead/invalid enemies first
	var filtered_enemies = []
	for e in enemies_in_range:
		var is_valid = is_instance_valid(e)
		var is_alive = not e.has_method("is_dead") or not e.is_dead()
		var has_health = "current_health" not in e or e.current_health > 0.0

		if is_valid and is_alive and has_health:
			filtered_enemies.append(e)
		else:
			# Debug logging for filtered enemies
			var enemy_name = e.get_enemy_name() if is_valid and e.has_method("get_enemy_name") else "Unknown"
			var reason = ""
			if not is_valid:
				reason = "Invalid instance"
			elif not is_alive:
				reason = "Dead"
			elif not has_health:
				reason = "No health"

			if _is_enemy_boss(e):
				print("🔴 BOSS FILTERED OUT: %s - Reason: %s" % [enemy_name, reason])

			DebugConfig.log_targeting("❌ Filtered out: %s - %s" % [enemy_name, reason])

	enemies_in_range = filtered_enemies

	if original_count != enemies_in_range.size():
		DebugConfig.log_targeting("Filtered enemies: %d → %d" % [original_count, enemies_in_range.size()])

	if enemies_in_range.is_empty():
		return null

	# Select target based on mode
	match targeting_mode:
		TargetingMode.FIRST:
			return get_first_enemy()
		TargetingMode.LAST:
			return get_last_enemy()
		TargetingMode.CLOSE:
			return get_closest_enemy()
		TargetingMode.STRONG:
			return get_strongest_enemy()
		TargetingMode.WEAK:
			return get_weakest_enemy()

	return null

func get_first_enemy():
	"""Target enemy furthest along the path with deterministic tie-breaking"""
	var furthest = enemies_in_range[0]
	var furthest_progress = _get_enemy_progress(furthest)
	var furthest_offset = _get_enemy_path_offset(furthest)

	for enemy in enemies_in_range:
		var progress = _get_enemy_progress(enemy)
		if progress > furthest_progress + PROGRESS_EPSILON:
			furthest = enemy
			furthest_progress = progress
			furthest_offset = _get_enemy_path_offset(enemy)
		elif abs(progress - furthest_progress) <= PROGRESS_EPSILON:
			var offset = _get_enemy_path_offset(enemy)
			if offset > furthest_offset:
				furthest = enemy
				furthest_progress = progress
				furthest_offset = offset

	return furthest

func get_last_enemy():
	"""Target enemy closest to the path start (opposite of FIRST)"""
	var last = enemies_in_range[0]
	var last_progress = _get_enemy_progress(last)
	var last_offset = _get_enemy_path_offset(last)

	for enemy in enemies_in_range:
		var progress = _get_enemy_progress(enemy)
		if progress < last_progress - PROGRESS_EPSILON:
			last = enemy
			last_progress = progress
			last_offset = _get_enemy_path_offset(enemy)
		elif abs(progress - last_progress) <= PROGRESS_EPSILON:
			var offset = _get_enemy_path_offset(enemy)
			if offset < last_offset:
				last = enemy
				last_progress = progress
				last_offset = offset

	return last

func get_closest_enemy():
	"""Target enemy nearest to this tower (distance-based, not path-based)"""
	var closest = enemies_in_range[0]
	var min_distance = global_position.distance_to(closest.global_position)
	var furthest_progress = _get_enemy_progress(closest)

	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance - 1.0:  # 1px epsilon for distance comparison
			closest = enemy
			min_distance = distance
			furthest_progress = _get_enemy_progress(enemy)
		elif abs(distance - min_distance) <= 1.0:
			# Tie-breaker: prefer enemy further on path
			var progress = _get_enemy_progress(enemy)
			if progress > furthest_progress + PROGRESS_EPSILON:
				closest = enemy
				min_distance = distance
				furthest_progress = progress

	return closest

func get_strongest_enemy():
	"""Target enemy with highest current health"""
	var strongest = enemies_in_range[0]
	var highest_health = _get_enemy_health(strongest)
	var furthest_progress = _get_enemy_progress(strongest)

	for enemy in enemies_in_range:
		var enemy_health = _get_enemy_health(enemy)
		if enemy_health > highest_health + HEALTH_EPSILON:
			strongest = enemy
			highest_health = enemy_health
			furthest_progress = _get_enemy_progress(enemy)
		elif abs(enemy_health - highest_health) <= HEALTH_EPSILON:
			var progress = _get_enemy_progress(enemy)
			if progress > furthest_progress + PROGRESS_EPSILON:
				strongest = enemy
				highest_health = enemy_health
				furthest_progress = progress

	return strongest

func get_weakest_enemy():
	"""Target enemy with lowest current health (opposite of STRONG)"""
	var weakest = enemies_in_range[0]
	var lowest_health = _get_enemy_health(weakest)
	var furthest_progress = _get_enemy_progress(weakest)

	for enemy in enemies_in_range:
		var enemy_health = _get_enemy_health(enemy)
		if enemy_health < lowest_health - HEALTH_EPSILON:
			weakest = enemy
			lowest_health = enemy_health
			furthest_progress = _get_enemy_progress(enemy)
		elif abs(enemy_health - lowest_health) <= HEALTH_EPSILON:
			# Tie-breaker: prefer enemy further on path
			var progress = _get_enemy_progress(enemy)
			if progress > furthest_progress + PROGRESS_EPSILON:
				weakest = enemy
				lowest_health = enemy_health
				furthest_progress = progress

	return weakest

func _get_enemy_progress(enemy) -> float:
	"""Get how far along the path an enemy is (0.0 = start, 1.0 = end)"""
	if not enemy or not is_instance_valid(enemy):
		return 0.0

	# Enemy is a child of PathFollow2D (Path2D system)
	var path_follower = enemy.get_parent()
	if path_follower and path_follower is PathFollow2D:
		return path_follower.progress_ratio

	# Fallback: Check if enemy has waypoint_progress property (Waypoint system)
	if "waypoint_progress" in enemy:
		return enemy.waypoint_progress

	# Fallback: Check if enemy has a get_progress() method
	if enemy.has_method("get_progress"):
		return enemy.get_progress()

	# Last resort: Use global position as rough approximation
	# Enemies further right/down are considered "further" in progress
	# This ensures targeting still works even without proper path tracking
	var normalized_position = enemy.global_position / 1000.0  # Normalize to 0.0-1.0 range
	return clamp(normalized_position.x + normalized_position.y, 0.0, 1.0)

func _get_enemy_path_offset(enemy) -> float:
	if not enemy or not is_instance_valid(enemy):
		return 0.0

	var path_follower = enemy.get_parent()
	if path_follower and path_follower is PathFollow2D:
		return path_follower.progress

	return 0.0

func _get_enemy_health(enemy) -> float:
	if not enemy or not is_instance_valid(enemy):
		return 0.0

	if "current_health" in enemy:
		return float(enemy.current_health)

	return 0.0

func _is_enemy_boss(enemy) -> bool:
	"""Check if an enemy is a boss (by name or properties)"""
	if not enemy or not is_instance_valid(enemy):
		return false

	# Check for boss flag
	if "is_boss" in enemy:
		return enemy.is_boss

	# Check by enemy name/type
	var enemy_name = enemy.get_enemy_name() if enemy.has_method("get_enemy_name") else ""
	return "troll" in enemy_name.to_lower() or "boss" in enemy_name.to_lower()

func _pick_target_with_stickiness(old_target, candidate_target):
	if candidate_target == null:
		if old_target != null:
			_record_target_change_time()
		return null

	if old_target == candidate_target:
		return candidate_target

	var now_msec = Time.get_ticks_msec()
	var elapsed = (now_msec - last_target_change_time_msec) / 1000.0

	var old_valid = old_target != null and is_instance_valid(old_target) and enemies_in_range.has(old_target)

	if old_valid:
		if elapsed < MIN_TARGET_LOCK_TIME:
			return old_target

		match targeting_mode:
			TargetingMode.FIRST:
				var old_progress = _get_enemy_progress(old_target)
				var new_progress = _get_enemy_progress(candidate_target)
				if new_progress < old_progress + PROGRESS_SWITCH_THRESHOLD:
					return old_target
			TargetingMode.LAST:
				var old_progress = _get_enemy_progress(old_target)
				var new_progress = _get_enemy_progress(candidate_target)
				if new_progress > old_progress - PROGRESS_SWITCH_THRESHOLD:
					return old_target
			TargetingMode.CLOSE:
				var old_dist = global_position.distance_to(old_target.global_position)
				var new_dist = global_position.distance_to(candidate_target.global_position)
				if new_dist > old_dist - 50.0:  # Must be 50px closer to switch
					return old_target
			TargetingMode.STRONG:
				var old_health = _get_enemy_health(old_target)
				var new_health = _get_enemy_health(candidate_target)
				if new_health <= old_health + HEALTH_SWITCH_THRESHOLD:
					return old_target
			TargetingMode.WEAK:
				var old_health = _get_enemy_health(old_target)
				var new_health = _get_enemy_health(candidate_target)
				if new_health >= old_health - HEALTH_SWITCH_THRESHOLD:
					return old_target

	if old_target != candidate_target:
		_record_target_change_time(now_msec)

	return candidate_target

func _record_target_change_time(now_msec := -1):
	last_target_change_time_msec = now_msec if now_msec >= 0 else Time.get_ticks_msec()

func set_targeting_mode(mode: TargetingMode):
	"""Change the targeting mode and update visual feedback"""
	targeting_mode = mode
	update_mode_label()
	var mode_name = _get_mode_name(mode)
	DebugConfig.log_targeting("Mode changed to: %s" % mode_name)

func _get_mode_name(mode: TargetingMode) -> String:
	"""Get string name for targeting mode"""
	match mode:
		TargetingMode.FIRST: return "FIRST"
		TargetingMode.LAST: return "LAST"
		TargetingMode.CLOSE: return "CLOSE"
		TargetingMode.STRONG: return "STRONG"
		TargetingMode.WEAK: return "WEAK"
	return "UNKNOWN"

func update_mode_label():
	"""Update the visual label showing current targeting mode"""
	if not mode_label:
		return

	match targeting_mode:
		TargetingMode.FIRST:
			mode_label.text = "[FIRST]"
			mode_label.modulate = Color.CYAN
		TargetingMode.LAST:
			mode_label.text = "[LAST]"
			mode_label.modulate = Color.LIGHT_BLUE
		TargetingMode.CLOSE:
			mode_label.text = "[CLOSE]"
			mode_label.modulate = Color.YELLOW
		TargetingMode.STRONG:
			mode_label.text = "[STRONG]"
			mode_label.modulate = Color.RED
		TargetingMode.WEAK:
			mode_label.text = "[WEAK]"
			mode_label.modulate = Color.ORANGE

# ============================================
# SHOOTING FUNCTIONS
# ============================================

func _on_shoot_timer_timeout():
	# Try to shoot every X seconds
	# Get target based on current targeting mode
	var old_target = current_target
	var candidate_target = get_target_by_mode()
	current_target = _pick_target_with_stickiness(old_target, candidate_target)

	# Track tower state (active when has target, idle when no target)
	if BalanceTracker:
		var has_target = current_target != null
		var had_target = old_target != null
		if has_target != had_target:  # State changed
			BalanceTracker.record_tower_state(self, has_target)

	# Debug: Show when tower switches targets (F3)
	if current_target != old_target and current_target != null:
		var target_name = current_target.get_enemy_name() if current_target.has_method("get_enemy_name") else "Enemy"
		var mode_name = _get_mode_name(targeting_mode)

		if old_target == null:
			DebugConfig.log_targeting("Tower → %s (%s mode)" % [target_name, mode_name])
		else:
			var old_name = old_target.get_enemy_name() if old_target.has_method("get_enemy_name") else "Enemy"
			DebugConfig.log_targeting("Tower switched → %s (from %s)" % [target_name, old_name])

		# Update enemy highlight (F4)
		if old_target and is_instance_valid(old_target) and old_target.has_method("set_debug_targeted"):
			old_target.set_debug_targeted(false)

		if current_target.has_method("set_debug_targeted"):
			current_target.set_debug_targeted(true)
	elif current_target == null and old_target != null and old_target.has_method("set_debug_targeted"):
		old_target.set_debug_targeted(false)

	if current_target != null:
		shoot_at(current_target)

func shoot_at(target):
	if projectile_scene == null:
		print("ERROR: No projectile scene assigned!")
		return

	# Validate target is alive
	if not is_instance_valid(target):
		print("⚠ Target is dead/invalid, aborting shot")
		current_target = null
		return

	# PRIMARY VALIDATION: Trust Area2D collision detection (Kingdom Rush approach)
	# If enemy is in our detection list, we can shoot it
	if not enemies_in_range.has(target):
		# Enemy left range - Area2D already removed it
		current_target = null
		return

	# SECONDARY DIAGNOSTIC: Distance check for debugging/monitoring only
	# This NEVER rejects shots - it only logs warnings for extreme cases
	var distance_to_target = global_position.distance_to(target.global_position)

	if distance_to_target > range_radius + 100:
		# Extremely far beyond range - shouldn't happen, but we shoot anyway
		DebugConfig.log_targeting("⚠ WARNING: Shooting far beyond range: %.1f / %d (+100px buffer exceeded)" % [distance_to_target, range_radius])
	elif distance_to_target > range_radius + 50:
		# Moderately beyond range - expected for large enemies like bosses
		DebugConfig.log_targeting("ℹ Target beyond buffer: %.1f / %d (+50px buffer)" % [distance_to_target, range_radius])
	elif distance_to_target > range_radius:
		# Slightly beyond range - normal for moving enemies at edge
		DebugConfig.log_targeting("ℹ Target at edge: %.1f / %d (within detection)" % [distance_to_target, range_radius])

	# Track shot fired
	if BalanceTracker:
		BalanceTracker.record_tower_shot(self)

	# FIX: Use call_deferred to avoid "flushing queries" error
	# Create projectile deferred to avoid physics state change during query
	call_deferred("_spawn_projectile", target)

func _spawn_projectile(target):
	"""Spawn arrow projectile (called deferred to avoid physics errors)"""
	# Double-check target is still valid
	if not is_instance_valid(target):
		DebugConfig.log_targeting("⚠ WARNING: Deferred shot target became invalid before projectile spawn!")
		# Target died/disappeared between shoot decision and actual spawn
		# This is expected in fast-paced gameplay, so just skip the shot
		return

	# Trigger muzzle flash effect (AFTER validation passes)
	if archer_weapon and archer_weapon.has_node("MuzzleFlash"):
		var muzzle_flash = archer_weapon.get_node("MuzzleFlash")
		muzzle_flash.restart()

	# Create projectile
	var arrow = projectile_scene.instantiate()
	get_tree().root.add_child(arrow)  # Add to scene root (not as child of tower)

	# Position arrow at weapon position (not tower center)
	# This creates visual continuity - arrow spawns where bow is
	if archer_weapon:
		arrow.global_position = archer_weapon.global_position
	else:
		# Fallback to tower center if weapon not found
		arrow.global_position = global_position

	# Tell arrow where to go and who shot it
	arrow.setup(target, damage, self)

	# Debug log
	print("🏹 Hero shooting arrow at: ", target.get_enemy_name() if target.has_method("get_enemy_name") else "Enemy")

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

	# Set Kingdom Rush blue color with transparency
	range_indicator.color = Color(0.3, 0.5, 1.0, 0.3)  # Blue, 30% opacity

func select_tower():
	"""Show range indicator when tower is selected"""
	is_selected = true
	range_indicator.visible = true

func deselect_tower():
	"""Hide range indicator when tower is deselected"""
	is_selected = false
	range_indicator.visible = false

# ============================================
# UPGRADE SYSTEM
# ============================================

func upgrade_tower():
	"""Apply standard upgrade (levels 1→2→3 and 4→5 after path choice)"""
	print("🔧 [DEBUG] upgrade_tower() called")
	print("🔧 [DEBUG] Current tower_level: %d" % tower_level)
	print("🔧 [DEBUG] MAX_LEVEL_BEFORE_CHOICE: %d" % MAX_LEVEL_BEFORE_CHOICE)
	print("🔧 [DEBUG] MAX_LEVEL: %d" % MAX_LEVEL)
	print("🔧 [DEBUG] Current stats - DMG:%d, AS:%.1f, Range:%d" % [damage, attack_speed, range_radius])

	# Check if at Level 3 (needs path choice) or at max level
	if tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		push_warning("[ArcherTower] Cannot upgrade past level 3 - must choose path!")
		print("❌ [DEBUG] Upgrade BLOCKED - need to choose path first")
		return false

	if tower_level >= MAX_LEVEL:
		push_warning("[ArcherTower] Tower already at MAX LEVEL!")
		print("❌ [DEBUG] Upgrade BLOCKED - already at max level %d" % tower_level)
		return false

	print("✅ [DEBUG] Upgrade check passed - proceeding with upgrade")
	var old_level = tower_level
	var upgrade_cost = get_upgrade_cost()  # Get cost BEFORE upgrading
	tower_level += 1
	print("🔧 [DEBUG] Level changed: %d → %d (Cost: %dg)" % [old_level, tower_level, upgrade_cost])

	# Remove old level modifiers (clean slate for new level)
	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)

	# Apply stat increases per level using MODIFIER SYSTEM (Kingdom Rush -25% damage scaling)
	var mod_source = "upgrade_level_%d" % tower_level
	match tower_level:
		2:
			print("🔧 [DEBUG] Applying Level 2 stats...")
			# 12 → 17 (+5 flat damage)
			stat_damage.add_modifier(StatModifier.create_flat(5.0, mod_source, "Tower Upgrade Level 2"))
			# 1.0 → 1.3 (+0.3 flat attack speed)
			stat_attack_speed.add_modifier(StatModifier.create_flat(0.3, mod_source, "Tower Upgrade Level 2"))
			# 300 → 350 (+50 flat range)
			stat_range.add_modifier(StatModifier.create_flat(50.0, mod_source, "Tower Upgrade Level 2"))
			# Result: 22.1 DPS (+84% from Level 1, efficiency 1.84x vs 2.17x before)
			print("✅ [ArcherTower] Upgraded to Level 2: DMG=%.1f, AS=%.1f, Range=%.1f, DPS=%.1f" % [damage, attack_speed, range_radius, damage * attack_speed])
		3:
			print("🔧 [DEBUG] Applying Level 3 stats...")
			# 12 → 27 (+15 flat damage from base)
			stat_damage.add_modifier(StatModifier.create_flat(15.0, mod_source, "Tower Upgrade Level 3"))
			# 1.0 → 1.6 (+0.6 flat attack speed from base)
			stat_attack_speed.add_modifier(StatModifier.create_flat(0.6, mod_source, "Tower Upgrade Level 3"))
			# 300 → 400 (+100 flat range from base)
			stat_range.add_modifier(StatModifier.create_flat(100.0, mod_source, "Tower Upgrade Level 3"))
			# Result: 43.2 DPS (+66% from Level 2)
			print("✅ [ArcherTower] Upgraded to Level 3: DMG=%.1f, AS=%.1f, Range=%.1f, DPS=%.1f" % [damage, attack_speed, range_radius, damage * attack_speed])
		5:
			# Level 4→5 upgrade (path-specific final upgrade)
			print("🔧 [DEBUG] Applying Level 5 stats (path: %s)..." % upgrade_path)
			if upgrade_path == "damage":
				# DAMAGE PATH Level 5: Ultimate glass cannon
				# 12 → 40 (+28 flat damage from base)
				stat_damage.add_modifier(StatModifier.create_flat(28.0, mod_source, "Tower Upgrade Level 5 Damage"))
				# 1.0 → 2.5 (+1.5 flat attack speed from base)
				stat_attack_speed.add_modifier(StatModifier.create_flat(1.5, mod_source, "Tower Upgrade Level 5 Damage"))
				# Range stays at path level 4 (500)
				# Result: 100 DPS - ULTIMATE GLASS CANNON!
				print("✅ [ArcherTower] Upgraded to Level 5 DAMAGE: DMG=%.1f, AS=%.1f, Range=%.1f, DPS=%.1f" % [damage, attack_speed, range_radius, damage * attack_speed])
			elif upgrade_path == "range":
				# RANGE PATH Level 5: Balanced sniper with less range
				# 12 → 35 (+23 flat damage from base)
				stat_damage.add_modifier(StatModifier.create_flat(23.0, mod_source, "Tower Upgrade Level 5 Range"))
				# 1.0 → 1.8 (+0.8 flat attack speed from base)
				stat_attack_speed.add_modifier(StatModifier.create_flat(0.8, mod_source, "Tower Upgrade Level 5 Range"))
				# 300 → 450 (+150 flat range from base)
				stat_range.add_modifier(StatModifier.create_flat(150.0, mod_source, "Tower Upgrade Level 5 Range"))
				# Result: 63 DPS - BALANCED SNIPER
				print("✅ [ArcherTower] Upgraded to Level 5 RANGE: DMG=%.1f, AS=%.1f, Range=%.1f, DPS=%.1f" % [damage, attack_speed, range_radius, damage * attack_speed])
			else:
				print("⚠️ [DEBUG] WARNING: Level 5 but no path chosen!")
		_:
			print("⚠️ [DEBUG] WARNING: Unexpected tower_level: %d" % tower_level)

	print("🔧 [DEBUG] New stats - DMG:%d, AS:%.1f, Range:%d" % [damage, attack_speed, range_radius])

	# Update detection range collision shape
	print("🔧 [DEBUG] Updating detection range...")
	_update_detection_range()

	# Redraw range indicator with new radius
	print("🔧 [DEBUG] Redrawing range circle...")
	draw_range_circle()

	# Update shoot timer with new attack speed
	if shoot_timer:
		print("🔧 [DEBUG] Updating shoot timer: %.3fs" % (1.0 / attack_speed))
		shoot_timer.wait_time = 1.0 / attack_speed
	else:
		print("⚠️ [DEBUG] WARNING: shoot_timer is null!")

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, upgrade_cost)

	print("✅ [DEBUG] upgrade_tower() completed successfully")
	return true

func choose_damage_path():
	"""Choose damage specialization path (Level 3 → 4 Damage)"""
	if tower_level != MAX_LEVEL_BEFORE_CHOICE:
		push_warning("[ArcherTower] Can only choose path at level 3!")
		return false

	if upgrade_path != "":
		push_warning("[ArcherTower] Path already chosen: %s" % upgrade_path)
		return false

	var path_cost = get_upgrade_cost()  # Get cost before upgrading
	var old_level = tower_level
	tower_level += 1
	upgrade_path = "damage"

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)

	# DAMAGE PATH: Using modifiers instead of direct assignment
	var mod_source = "upgrade_path_damage"
	# 12 → 36 (+24 flat damage from base)
	stat_damage.add_modifier(StatModifier.create_flat(24.0, mod_source, "Damage Path Level 4"))
	# 1.0 → 2.0 (+1.0 flat attack speed from base)
	stat_attack_speed.add_modifier(StatModifier.create_flat(1.0, mod_source, "Damage Path Level 4"))
	# 300 → 500 (+200 flat range from base)
	stat_range.add_modifier(StatModifier.create_flat(200.0, mod_source, "Damage Path Level 4"))
	# Result: 72 DPS (+67% from Level 3) - GLASS CANNON!

	print("[ArcherTower] DAMAGE PATH chosen: DMG=%.1f, AS=%.1f, Range=%.1f, DPS=%.1f - High DPS glass cannon!" % [damage, attack_speed, range_radius, damage * attack_speed])

	# Update shoot timer
	if shoot_timer:
		shoot_timer.wait_time = 1.0 / attack_speed

	# Update detection range
	_update_detection_range()
	draw_range_circle()

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "damage")

	return true

func choose_range_path():
	"""Choose range specialization path (Level 3 → 4 Range)"""
	if tower_level != MAX_LEVEL_BEFORE_CHOICE:
		push_warning("[ArcherTower] Can only choose path at level 3!")
		return false

	if upgrade_path != "":
		push_warning("[ArcherTower] Path already chosen: %s" % upgrade_path)
		return false

	var path_cost = get_upgrade_cost()  # Get cost before upgrading
	var old_level = tower_level
	tower_level += 1
	upgrade_path = "range"

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)

	# RANGE PATH: Using modifiers - keeps Level 3 damage/AS, increases range
	var mod_source = "upgrade_path_range"
	# Damage: 12 → 27 (keep level 3 stats)
	stat_damage.add_modifier(StatModifier.create_flat(15.0, mod_source, "Range Path Level 4"))
	# Attack speed: 1.0 → 1.6 (keep level 3 stats)
	stat_attack_speed.add_modifier(StatModifier.create_flat(0.6, mod_source, "Range Path Level 4"))
	# Range: 300 → 500 (+200 flat range from base)
	stat_range.add_modifier(StatModifier.create_flat(200.0, mod_source, "Range Path Level 4"))
	# Result: 43.2 DPS - Long-range sniper

	print("[ArcherTower] RANGE PATH chosen: Range=%.1f, DMG=%.1f, AS=%.1f, DPS=%.1f - Long-range sniper!" % [range_radius, damage, attack_speed, damage * attack_speed])

	# Update detection range collision shape
	_update_detection_range()

	# Redraw range indicator
	draw_range_circle()

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "range")

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
				print("[ArcherTower] Detection range updated to: %d" % range_radius)
			else:
				push_error("[ArcherTower] Failed to update detection range - shape is invalid or not CircleShape2D")
			break

	# CRITICAL: Revalidate all tracked enemies after range change
	# Range shrinking doesn't emit body_exited, enemies might be outside new range
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
			print("[ArcherTower] Enemy removed from range after range update (distance: %d > %d)" % [distance, range_radius])

	# Remove invalid enemies
	for enemy in enemies_to_remove:
		enemies_in_range.erase(enemy)
		if current_target == enemy:
			if enemy.has_method("set_debug_targeted"):
				enemy.set_debug_targeted(false)
			current_target = null
			_record_target_change_time()

func get_upgrade_cost() -> int:
	"""Get cost for next upgrade (REDUCED by 25% for better economy)"""
	if tower_level < MAX_LEVEL_BEFORE_CHOICE:
		# Standard upgrades (Level 1→2, 2→3)
		match tower_level:
			1: return 60  # Level 1→2 (Reduced from 80g -25%)
			2: return 90  # Level 2→3 (Reduced from 120g -25%)
	elif tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		# Path choice upgrade (Level 3→4)
		return 150  # Level 3→4 path choice (increased for economy balance)
	elif tower_level == 4 and upgrade_path != "":
		# Final upgrade after path choice (Level 4→5)
		return 200  # Level 4→5 final upgrade (most expensive)

	return 0  # Max level reached

func get_upgrade_stats(preview_path: String = "") -> Dictionary:
	"""Get preview of what stats will be after upgrade (for two-click upgrade system)

	Args:
		preview_path: For Level 3, specify "damage" or "range" to preview that path choice
	"""
	var current_damage = damage
	var current_attack_speed = attack_speed
	var current_range = range_radius

	# Calculate bonuses based on next level
	var damage_bonus = 0
	var attack_speed_bonus = 0.0
	var range_bonus = 0

	if tower_level < MAX_LEVEL_BEFORE_CHOICE:
		# Standard upgrades - MUST MATCH upgrade_tower() actual values!
		match tower_level:
			1:  # Level 1→2
				damage_bonus = 17 - current_damage  # Will be 17
				attack_speed_bonus = 1.3 - current_attack_speed  # Will be 1.3
				range_bonus = 350 - current_range  # Will be 350
			2:  # Level 2→3
				damage_bonus = 27 - current_damage  # Will be 27
				attack_speed_bonus = 1.6 - current_attack_speed  # Will be 1.6
				range_bonus = 400 - current_range  # Will be 400
	elif tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		# Level 3→4 path choice preview - MUST MATCH choose_damage_path() / choose_range_path()
		if preview_path == "damage":
			# Damage path preview: 27→36 damage, 1.6→2.0 AS, 400→500 range
			damage_bonus = 36 - current_damage  # +9 damage (+33%)
			attack_speed_bonus = 2.0 - current_attack_speed  # +0.4 AS (+25%)
			range_bonus = 500 - current_range  # +100 range (+25%)
		elif preview_path == "range":
			# Range path preview: damage/AS stay same, 400→500 range
			damage_bonus = 0  # Stays 27
			attack_speed_bonus = 0.0  # Stays 1.6
			range_bonus = 500 - current_range  # +100 range (+25%)
	elif tower_level == 4 and upgrade_path != "":
		# Level 4→5 upgrade (path-specific) - MUST MATCH upgrade_tower() Level 5 values!
		if upgrade_path == "damage":
			# Damage path Level 5 preview
			damage_bonus = 40 - current_damage  # BALANCE FIX: 36 → 40 (was 45)
			attack_speed_bonus = 2.5 - current_attack_speed  # 2.0 → 2.5
			range_bonus = 0  # Range stays 500
		elif upgrade_path == "range":
			# Range path Level 5 preview
			damage_bonus = 35 - current_damage  # 27 → 35
			attack_speed_bonus = 1.8 - current_attack_speed  # 1.6 → 1.8
			range_bonus = 450 - current_range  # 500 → 450 (reduced!)

	return {
		"damage": current_damage,
		"damage_bonus": damage_bonus,
		"attack_speed": current_attack_speed,
		"attack_speed_bonus": attack_speed_bonus,
		"range": current_range,
		"range_bonus": range_bonus
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
# CLEANUP
# ============================================

func _exit_tree():
	# Cleanup (Area2D will auto-cleanup its signals)
	pass
