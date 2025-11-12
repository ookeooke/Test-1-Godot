extends StaticBody2D

# ============================================
# SOLDIER TOWER - Spawns a garrison of melee fighters
# ============================================
# - Spawns squad of soldiers in ring formation
# - Manages respawn timers when soldiers die
# - Rally flag allows player to position the squad
# - Plugs into existing tower placement system

# TOWER IDENTITY (for dynamic loading system)
@export var tower_id: String = "barracks"

# TOWER STATS - Unified Stat System (Phase 2A: Stats now loaded from TowerData)
var stat_soldier_health: Stat
var stat_soldier_damage: Stat
var stat_soldier_attack_speed: Stat
var stat_respawn_delay: Stat

# Computed properties for backwards compatibility
var soldier_health: float:
	get: return stat_soldier_health.get_value() if stat_soldier_health else 0.0

var soldier_damage: float:
	get: return stat_soldier_damage.get_value() if stat_soldier_damage else 0.0

var soldier_attack_speed: float:
	get: return stat_soldier_attack_speed.get_value() if stat_soldier_attack_speed else 0.0

var respawn_delay: float:
	get: return stat_respawn_delay.get_value() if stat_respawn_delay else 0.0

var build_cost = 120  # Cost to build this tower (for sell calculation)

# UPGRADE SYSTEM (following archer tower pattern)
var tower_level = 1  # Current upgrade level (1-5)
var upgrade_path = "" # "" = not chosen, "defense" = defense path, "offense" = offense path
const MAX_LEVEL_BEFORE_CHOICE = 3  # At level 3, player must choose a path
const MAX_LEVEL = 5  # Maximum tower level after all upgrades

@export_group("Garrison Settings")
@export var squad_size: int = 4  ## Number of soldiers in the squad
@export var spawn_radius: float = 60.0  ## How far from tower center soldiers spawn
@export var rally_flag_default_offset: Vector2 = Vector2(150, 0)  ## Default flag position

@export_group("Soldier Stats")
@export var soldier_scene: PackedScene  ## Soldier unit scene to spawn

# REFERENCES
var click_area: Area2D  # For clicking the tower
var rally_flag: Node2D  # Visual marker for rally point
var flag_sprite: Polygon2D  # Flag visual

# SELECTION STATE
var is_selected = false

# SQUAD MANAGEMENT
var active_soldiers: Array = []  # Living soldiers
var respawn_queue: Array = []  # Dead soldiers waiting to respawn: [{time: float, index: int}]
var rally_position: Vector2  # Where soldiers march to

# TOWER SPOT reference (set by tower_spot when placing)
var parent_spot = null

# FLAG PLACEMENT MODE (Kingdom Rush style)
var is_placing_rally = false  # True when player clicked "Rally" button in UI

# ============================================
# STAT INITIALIZATION
# ============================================

func _initialize_stats():
	"""Initialize all Stat objects with base values from TowerData"""
	# Phase 2A: Read stats from centralized TowerData instead of hardcoded constants
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)

	if level_1_stats.is_empty():
		push_error("[SoldierTower] CRITICAL: Failed to load stats from TowerData for tower_id: %s - Tower will not function!" % tower_id)
		# Initialize with zero values - tower will be non-functional until data is fixed
		stat_soldier_health = Stat.new(0.0)
		stat_soldier_damage = Stat.new(0.0)
		stat_soldier_attack_speed = Stat.new(0.0)
		stat_respawn_delay = Stat.new(0.0)
	else:
		stat_soldier_health = Stat.new(level_1_stats["soldier_health"])
		stat_soldier_damage = Stat.new(level_1_stats["soldier_damage"])
		stat_soldier_attack_speed = Stat.new(level_1_stats["soldier_attack_speed"])
		stat_respawn_delay = Stat.new(level_1_stats["respawn_time"])

	print("[SoldierTower] Stats initialized - HP: %.1f, DMG: %.1f, AS: %.1f, Respawn: %.1fs" % [stat_soldier_health.get_value(), stat_soldier_damage.get_value(), stat_soldier_attack_speed.get_value(), stat_respawn_delay.get_value()])

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Initialize stat system FIRST
	_initialize_stats()

	# Setup click detection (if ClickArea node exists in scene)
	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	# Initialize rally position
	rally_position = global_position + rally_flag_default_offset

	# Create rally flag
	_create_rally_flag()

	# Spawn initial squad (wait one frame for scene to settle)
	await get_tree().process_frame
	_spawn_initial_squad()

func _process(delta):
	# Handle respawn timers
	_update_respawn_queue(delta)

# ============================================
# CLICK HANDLING - Using Area2D
# ============================================

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_clicked()
			get_viewport().set_input_as_handled()

func _on_clicked():
	"""Called when tower is clicked"""
	if parent_spot:
		parent_spot.tower_clicked.emit(parent_spot, self)
	else:
		# Fallback: try to find parent spot
		var spot = get_parent()
		if spot and spot.has_signal("tower_clicked"):
			spot.tower_clicked.emit(spot, self)

func _on_mouse_entered():
	"""Called when mouse enters tower area"""
	if has_node("TowerVisual"):
		$TowerVisual.modulate = Color(1.3, 1.3, 1.3)

func _on_mouse_exited():
	"""Called when mouse leaves tower area"""
	if has_node("TowerVisual"):
		$TowerVisual.modulate = Color(1, 1, 1)

# ============================================
# SQUAD SPAWNING
# ============================================

func _spawn_initial_squad():
	"""Spawn all soldiers in ring formation"""
	if soldier_scene == null:
		print("ERROR: No soldier scene assigned to Soldier Tower!")
		return

	for i in range(squad_size):
		_spawn_soldier(i)

func _spawn_soldier(index: int):
	"""Spawn a single soldier at formation position"""
	if soldier_scene == null:
		return

	# Calculate position in ring formation
	var angle = (float(index) / squad_size) * TAU  # TAU = 2*PI
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius

	# Instantiate soldier
	var soldier = soldier_scene.instantiate()
	get_tree().root.add_child(soldier)  # Add to scene root (not as child of tower)

	# Configure soldier
	soldier.parent_tower = self
	soldier.respawn_delay = respawn_delay
	soldier.max_health = soldier_health
	soldier.current_health = soldier_health
	soldier.melee_damage = soldier_damage
	soldier.melee_attack_speed = soldier_attack_speed

	# Set positions
	soldier.set_home_position(global_position, offset)
	soldier.set_flag_position(rally_position)

	# Connect death signal
	if soldier.has_signal("soldier_died"):
		soldier.soldier_died.connect(_on_soldier_died.bind(index))

	# Track soldier
	if index >= active_soldiers.size():
		active_soldiers.resize(squad_size)
	active_soldiers[index] = soldier

func _on_soldier_died(time: float, soldier_index: int):
	"""Called when a soldier dies - add to respawn queue"""
	print("Soldier ", soldier_index, " died - respawning in ", time, "s")

	# Clear from active list
	active_soldiers[soldier_index] = null

	# Add to respawn queue
	respawn_queue.append({
		"time": time,
		"index": soldier_index
	})

func _update_respawn_queue(delta):
	"""Tick down respawn timers"""
	for i in range(respawn_queue.size() - 1, -1, -1):
		var entry = respawn_queue[i]
		entry["time"] -= delta

		if entry["time"] <= 0:
			# Respawn this soldier
			_spawn_soldier(entry["index"])
			respawn_queue.remove_at(i)

# ============================================
# RALLY FLAG SYSTEM
# ============================================

func _create_rally_flag():
	"""Create visual rally flag marker"""
	rally_flag = Node2D.new()
	rally_flag.name = "RallyFlag"
	add_child(rally_flag)
	rally_flag.global_position = rally_position

	# Create flag visual (triangle on a pole)
	flag_sprite = Polygon2D.new()
	rally_flag.add_child(flag_sprite)

	# Draw flag shape
	var flag_points = PackedVector2Array([
		Vector2(0, -30),   # Pole top
		Vector2(0, 10),    # Pole bottom
		Vector2(0, -25),   # Flag base
		Vector2(20, -20),  # Flag tip
		Vector2(0, -15)    # Flag base bottom
	])
	flag_sprite.polygon = flag_points
	flag_sprite.color = Color(1.0, 0.8, 0.0, 0.9)  # Gold flag

	# Flag is always visible to show current rally position
	# No ClickManager registration needed - placement is done via UI button

func enter_rally_placement_mode():
	"""Called by tower UI when player clicks 'Rally Point' button"""
	is_placing_rally = true
	print("🚩 Rally placement mode activated - click anywhere to move flag")
	# Could show visual feedback here (highlight valid areas, change cursor, etc.)

func place_rally_at(world_position: Vector2):
	"""Move rally flag to new position"""
	rally_position = world_position
	rally_flag.global_position = rally_position

	# Update all soldiers' flag position
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.set_flag_position(rally_position)

	print("✓ Rally flag moved to: ", rally_position)
	is_placing_rally = false

# ============================================
# VISUAL FUNCTIONS
# ============================================

func select_tower():
	"""Show garrison info when tower is selected"""
	is_selected = true
	# Could show soldier HP bars, respawn timers, etc.

func deselect_tower():
	"""Hide garrison info when tower is deselected"""
	is_selected = false

# ============================================
# INFO API - For tower_info_menu.gd
# ============================================

func get_garrison_info() -> Dictionary:
	"""Return garrison status for UI"""
	var alive_count = 0
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			alive_count += 1

	return {
		"squad_size": squad_size,
		"alive": alive_count,
		"respawning": respawn_queue.size(),
		"next_respawn": respawn_queue[0]["time"] if respawn_queue.size() > 0 else 0.0
	}

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	# Handle rally placement clicks (Kingdom Rush style)
	if is_placing_rally:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Convert screen click to world position
			var world_pos = get_global_mouse_position()
			place_rally_at(world_pos)
			get_viewport().set_input_as_handled()

		# Cancel placement on right-click
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			is_placing_rally = false
			print("Rally placement cancelled")
			get_viewport().set_input_as_handled()

# ============================================
# UPGRADE SYSTEM (following archer tower pattern)
# ============================================

func upgrade_tower():
	"""Apply standard upgrade (levels 1→2→3 and 4→5 after path choice)"""
	print("🔧 [SoldierTower] upgrade_tower() called")
	print("🔧 [SoldierTower] Current tower_level: %d" % tower_level)

	# Check if at Level 3 (needs path choice) or at max level
	if tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		push_warning("[SoldierTower] Cannot upgrade past level 3 - must choose path!")
		return false

	if tower_level >= MAX_LEVEL:
		push_warning("[SoldierTower] Tower already at MAX LEVEL!")
		return false

	var old_level = tower_level
	var upgrade_cost = get_upgrade_cost()
	tower_level += 1
	build_cost += upgrade_cost  # Track total investment for sell refunds
	print("🔧 [SoldierTower] Level changed: %d → %d (Cost: %dg, Total: %dg)" % [old_level, tower_level, upgrade_cost, build_cost])

	# Remove old level modifiers (clean slate for new level)
	var old_source = "upgrade_level_%d" % old_level
	stat_soldier_health.remove_modifiers_from_source(old_source)
	stat_soldier_damage.remove_modifiers_from_source(old_source)
	stat_respawn_delay.remove_modifiers_from_source(old_source)

	# Get target stats for new level from TowerData
	var mod_source = "upgrade_level_%d" % tower_level
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	var target_stats: Dictionary

	if tower_level <= MAX_LEVEL_BEFORE_CHOICE:
		# Levels 2-3: No path choice
		target_stats = TowerData.get_tower_stats(tower_id, tower_level)
	else:
		# Levels 4-5: Path-specific stats
		var path_key = upgrade_path + "_path"
		target_stats = TowerData.get_tower_stats(tower_id, tower_level, path_key)

	if target_stats.is_empty():
		push_error("[SoldierTower] Failed to load upgrade stats from TowerData for level %d" % tower_level)
		return false

	# Calculate deltas from base stats (Level 1)
	print("🔧 [SoldierTower] Applying Level %d stats from TowerData (path: %s)..." % [tower_level, upgrade_path if upgrade_path != "" else "none"])

	var health_delta = target_stats.soldier_health - level_1_stats.soldier_health
	var damage_delta = target_stats.soldier_damage - level_1_stats.soldier_damage
	var attack_speed_delta = target_stats.soldier_attack_speed - level_1_stats.soldier_attack_speed
	var respawn_delta = target_stats.respawn_time - level_1_stats.respawn_time

	# Apply modifiers
	if health_delta != 0:
		stat_soldier_health.add_modifier(StatModifier.create_flat(health_delta, mod_source, "Soldier Upgrade Level %d" % tower_level))
	if damage_delta != 0:
		stat_soldier_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Soldier Upgrade Level %d" % tower_level))
	if attack_speed_delta != 0:
		stat_soldier_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Soldier Upgrade Level %d" % tower_level))
	if respawn_delta != 0:
		stat_respawn_delay.add_modifier(StatModifier.create_flat(respawn_delta, mod_source, "Soldier Upgrade Level %d" % tower_level))

	print("✅ [SoldierTower] Upgraded to Level %d: HP=%.1f, DMG=%.1f, AS=%.1f, Respawn=%.1fs" % [tower_level, soldier_health, soldier_damage, soldier_attack_speed, respawn_delay])

	# Update ALL existing soldiers with new stats
	_update_existing_soldiers()

	# Track upgrade in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, upgrade_cost)

	print("✅ [SoldierTower] upgrade_tower() completed successfully")
	return true

func choose_defense_path():
	"""Choose defense specialization path (Level 3 → 4 Defense)"""
	if tower_level != MAX_LEVEL_BEFORE_CHOICE:
		push_warning("[SoldierTower] Can only choose path at level 3!")
		return false

	if upgrade_path != "":
		push_warning("[SoldierTower] Path already chosen: %s" % upgrade_path)
		return false

	var path_cost = get_upgrade_cost()
	var old_level = tower_level
	tower_level += 1
	upgrade_path = "defense"
	build_cost += path_cost  # Track total investment for sell refunds

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_soldier_health.remove_modifiers_from_source(old_source)
	stat_soldier_damage.remove_modifiers_from_source(old_source)
	stat_soldier_attack_speed.remove_modifiers_from_source(old_source)
	stat_respawn_delay.remove_modifiers_from_source(old_source)

	# Load defense path stats from TowerData
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	var target_stats = TowerData.get_tower_stats(tower_id, 4, "defense_path")

	if target_stats.is_empty():
		push_error("[SoldierTower] Failed to load defense path stats from TowerData")
		return false

	# Calculate deltas from base stats (Level 1)
	var health_delta = target_stats.soldier_health - level_1_stats.soldier_health
	var damage_delta = target_stats.soldier_damage - level_1_stats.soldier_damage
	var attack_speed_delta = target_stats.soldier_attack_speed - level_1_stats.soldier_attack_speed
	var respawn_delta = target_stats.respawn_time - level_1_stats.respawn_time

	# Apply modifiers
	var mod_source = "upgrade_path_defense"
	if health_delta != 0:
		stat_soldier_health.add_modifier(StatModifier.create_flat(health_delta, mod_source, "Defense Path Level 4"))
	if damage_delta != 0:
		stat_soldier_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Defense Path Level 4"))
	if attack_speed_delta != 0:
		stat_soldier_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Defense Path Level 4"))
	if respawn_delta != 0:
		stat_respawn_delay.add_modifier(StatModifier.create_flat(respawn_delta, mod_source, "Defense Path Level 4"))

	_update_existing_soldiers()

	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "defense")

	print("✅ [SoldierTower] Chose DEFENSE path - Level 4: HP=%.1f, DMG=%.1f, AS=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, soldier_attack_speed, respawn_delay])
	return true

func choose_offense_path():
	"""Choose offense specialization path (Level 3 → 4 Offense)"""
	if tower_level != MAX_LEVEL_BEFORE_CHOICE:
		push_warning("[SoldierTower] Can only choose path at level 3!")
		return false

	if upgrade_path != "":
		push_warning("[SoldierTower] Path already chosen: %s" % upgrade_path)
		return false

	var path_cost = get_upgrade_cost()
	var old_level = tower_level
	tower_level += 1
	upgrade_path = "offense"
	build_cost += path_cost  # Track total investment for sell refunds

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_soldier_health.remove_modifiers_from_source(old_source)
	stat_soldier_damage.remove_modifiers_from_source(old_source)
	stat_soldier_attack_speed.remove_modifiers_from_source(old_source)
	stat_respawn_delay.remove_modifiers_from_source(old_source)

	# Load offense path stats from TowerData
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	var target_stats = TowerData.get_tower_stats(tower_id, 4, "offense_path")

	if target_stats.is_empty():
		push_error("[SoldierTower] Failed to load offense path stats from TowerData")
		return false

	# Calculate deltas from base stats (Level 1)
	var health_delta = target_stats.soldier_health - level_1_stats.soldier_health
	var damage_delta = target_stats.soldier_damage - level_1_stats.soldier_damage
	var attack_speed_delta = target_stats.soldier_attack_speed - level_1_stats.soldier_attack_speed
	var respawn_delta = target_stats.respawn_time - level_1_stats.respawn_time

	# Apply modifiers
	var mod_source = "upgrade_path_offense"
	if health_delta != 0:
		stat_soldier_health.add_modifier(StatModifier.create_flat(health_delta, mod_source, "Offense Path Level 4"))
	if damage_delta != 0:
		stat_soldier_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Offense Path Level 4"))
	if attack_speed_delta != 0:
		stat_soldier_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Offense Path Level 4"))
	if respawn_delta != 0:
		stat_respawn_delay.add_modifier(StatModifier.create_flat(respawn_delta, mod_source, "Offense Path Level 4"))

	_update_existing_soldiers()

	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "offense")

	print("✅ [SoldierTower] Chose OFFENSE path - Level 4: HP=%.1f, DMG=%.1f, AS=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, soldier_attack_speed, respawn_delay])
	return true

func _update_existing_soldiers():
	"""Update all living soldiers with new stats after upgrade"""
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.max_health = soldier_health
			soldier.melee_damage = soldier_damage
			soldier.melee_attack_speed = soldier_attack_speed
			soldier.respawn_delay = respawn_delay

			# Heal to new max health (generous upgrade bonus!)
			soldier.current_health = soldier_health
			soldier.update_health_bar()

	print("✅ [SoldierTower] Updated %d existing soldiers with new stats" % active_soldiers.size())

func get_upgrade_cost() -> int:
	"""Get cost for next upgrade from TowerData (data-driven)"""
	if tower_level >= 5:
		return 0  # Max level reached

	# Convert upgrade_path ("defense"/"offense") to TowerData format ("defense_path"/"offense_path")
	var path_param = ""
	if upgrade_path != "":
		path_param = upgrade_path + "_path"

	# Query TowerData for current level's cost_to_next
	var current_stats = TowerData.get_tower_stats(tower_id, tower_level, path_param)

	if current_stats and "cost_to_next" in current_stats:
		return current_stats["cost_to_next"]

	# Fallback: should never happen if TowerData is configured correctly
	print("⚠️ [Barracks] WARNING: No cost_to_next found for level %d, path '%s'" % [tower_level, upgrade_path])
	return 0

func get_upgrade_stats(preview_path: String = "") -> Dictionary:
	"""Get preview of what stats will be after upgrade - Phase 2A: Uses TowerData

	Args:
		preview_path: For Level 3, specify "defense" or "offense" to preview that path choice
	"""
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

	# Use next level stats if available, otherwise use current values
	var preview_health = next_level_stats.get("soldier_health", soldier_health)
	var preview_damage = next_level_stats.get("soldier_damage", soldier_damage)
	var preview_respawn = next_level_stats.get("respawn_time", respawn_delay)
	var preview_squad = next_level_stats.get("squad_size", squad_size)

	return {
		"soldier_health": preview_health,
		"soldier_damage": preview_damage,
		"respawn_delay": preview_respawn,
		"squad_size": preview_squad
	}

func needs_path_choice() -> bool:
	"""Check if tower is at level 3 and needs path choice"""
	return tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == ""

func can_upgrade() -> bool:
	"""Check if tower can be upgraded"""
	if tower_level < MAX_LEVEL_BEFORE_CHOICE:
		return true  # Can do standard upgrade (Lv1→2, Lv2→3)
	elif tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		return true  # Can choose path (Lv3→4)
	elif tower_level == 4 and upgrade_path != "":
		return true  # Can do final upgrade (Lv4→5)
	return false  # Level 5 = MAX LEVEL

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Clean up soldiers
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.queue_free()
