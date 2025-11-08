extends StaticBody2D

# ============================================
# SOLDIER TOWER - Spawns a garrison of melee fighters
# ============================================
# - Spawns squad of soldiers in ring formation
# - Manages respawn timers when soldiers die
# - Rally flag allows player to position the squad
# - Plugs into existing tower placement system

# BASE STATS (constants for reference)
const BASE_SOLDIER_HEALTH = 100.0
const BASE_SOLDIER_DAMAGE = 10.0
const BASE_SOLDIER_ATTACK_SPEED = 1.0
const BASE_RESPAWN_DELAY = 5.0

# TOWER STATS - Unified Stat System
var stat_soldier_health: Stat
var stat_soldier_damage: Stat
var stat_soldier_attack_speed: Stat
var stat_respawn_delay: Stat

# Computed properties for backwards compatibility
var soldier_health: float:
	get: return stat_soldier_health.get_value() if stat_soldier_health else BASE_SOLDIER_HEALTH

var soldier_damage: float:
	get: return stat_soldier_damage.get_value() if stat_soldier_damage else BASE_SOLDIER_DAMAGE

var soldier_attack_speed: float:
	get: return stat_soldier_attack_speed.get_value() if stat_soldier_attack_speed else BASE_SOLDIER_ATTACK_SPEED

var respawn_delay: float:
	get: return stat_respawn_delay.get_value() if stat_respawn_delay else BASE_RESPAWN_DELAY

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
	"""Initialize all Stat objects with base values"""
	stat_soldier_health = Stat.new(BASE_SOLDIER_HEALTH)
	stat_soldier_damage = Stat.new(BASE_SOLDIER_DAMAGE)
	stat_soldier_attack_speed = Stat.new(BASE_SOLDIER_ATTACK_SPEED)
	stat_respawn_delay = Stat.new(BASE_RESPAWN_DELAY)

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
	print("🔧 [SoldierTower] Level changed: %d → %d (Cost: %dg)" % [old_level, tower_level, upgrade_cost])

	# Remove old level modifiers (clean slate for new level)
	var old_source = "upgrade_level_%d" % old_level
	stat_soldier_health.remove_modifiers_from_source(old_source)
	stat_soldier_damage.remove_modifiers_from_source(old_source)
	stat_respawn_delay.remove_modifiers_from_source(old_source)

	# Apply stat increases per level using MODIFIER SYSTEM
	var mod_source = "upgrade_level_%d" % tower_level
	match tower_level:
		2:
			# 100 → 120 (+20 flat health)
			stat_soldier_health.add_modifier(StatModifier.create_flat(20.0, mod_source, "Soldier Upgrade Level 2"))
			# 10 → 12 (+2 flat damage)
			stat_soldier_damage.add_modifier(StatModifier.create_flat(2.0, mod_source, "Soldier Upgrade Level 2"))
			# 5.0 → 4.5 (-0.5 flat respawn time - NEGATIVE is faster!)
			stat_respawn_delay.add_modifier(StatModifier.create_flat(-0.5, mod_source, "Soldier Upgrade Level 2"))
			print("✅ [SoldierTower] Upgraded to Level 2: HP=%.1f, DMG=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, respawn_delay])
		3:
			# 100 → 150 (+50 flat health from base)
			stat_soldier_health.add_modifier(StatModifier.create_flat(50.0, mod_source, "Soldier Upgrade Level 3"))
			# 10 → 15 (+5 flat damage from base)
			stat_soldier_damage.add_modifier(StatModifier.create_flat(5.0, mod_source, "Soldier Upgrade Level 3"))
			# 5.0 → 4.0 (-1.0 flat respawn time from base)
			stat_respawn_delay.add_modifier(StatModifier.create_flat(-1.0, mod_source, "Soldier Upgrade Level 3"))
			print("✅ [SoldierTower] Upgraded to Level 3: HP=%.1f, DMG=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, respawn_delay])
		5:
			# Level 4→5 upgrade (path-specific final upgrade)
			if upgrade_path == "defense":
				# DEFENSE PATH: Tankier soldiers, faster respawn
				# 100 → 220 (+120 flat health from base)
				stat_soldier_health.add_modifier(StatModifier.create_flat(120.0, mod_source, "Soldier Upgrade Level 5 Defense"))
				# 10 → 18 (+8 flat damage from base)
				stat_soldier_damage.add_modifier(StatModifier.create_flat(8.0, mod_source, "Soldier Upgrade Level 5 Defense"))
				# 5.0 → 2.5 (-2.5 flat respawn time from base)
				stat_respawn_delay.add_modifier(StatModifier.create_flat(-2.5, mod_source, "Soldier Upgrade Level 5 Defense"))
				print("✅ [SoldierTower] Upgraded to Level 5 DEFENSE: HP=%.1f, DMG=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, respawn_delay])
			elif upgrade_path == "offense":
				# OFFENSE PATH: Higher damage, same tankiness
				# 100 → 200 (+100 flat health from base)
				stat_soldier_health.add_modifier(StatModifier.create_flat(100.0, mod_source, "Soldier Upgrade Level 5 Offense"))
				# 10 → 25 (+15 flat damage from base)
				stat_soldier_damage.add_modifier(StatModifier.create_flat(15.0, mod_source, "Soldier Upgrade Level 5 Offense"))
				# 5.0 → 3.0 (-2.0 flat respawn time from base)
				stat_respawn_delay.add_modifier(StatModifier.create_flat(-2.0, mod_source, "Soldier Upgrade Level 5 Offense"))
				print("✅ [SoldierTower] Upgraded to Level 5 OFFENSE: HP=%.1f, DMG=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, respawn_delay])

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

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_soldier_health.remove_modifiers_from_source(old_source)
	stat_soldier_damage.remove_modifiers_from_source(old_source)
	stat_respawn_delay.remove_modifiers_from_source(old_source)

	# Level 4 DEFENSE stats: Tankier soldiers
	var mod_source = "upgrade_path_defense"
	# 100 → 180 (+80 flat health from base)
	stat_soldier_health.add_modifier(StatModifier.create_flat(80.0, mod_source, "Defense Path Level 4"))
	# 10 → 18 (+8 flat damage from base)
	stat_soldier_damage.add_modifier(StatModifier.create_flat(8.0, mod_source, "Defense Path Level 4"))
	# 5.0 → 3.0 (-2.0 flat respawn time from base)
	stat_respawn_delay.add_modifier(StatModifier.create_flat(-2.0, mod_source, "Defense Path Level 4"))

	_update_existing_soldiers()

	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "defense")

	print("✅ [SoldierTower] Chose DEFENSE path - Level 4: HP=%.1f, DMG=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, respawn_delay])
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

	# Remove old level modifiers
	var old_source = "upgrade_level_%d" % old_level
	stat_soldier_health.remove_modifiers_from_source(old_source)
	stat_soldier_damage.remove_modifiers_from_source(old_source)
	stat_respawn_delay.remove_modifiers_from_source(old_source)

	# Level 4 OFFENSE stats: Higher damage
	var mod_source = "upgrade_path_offense"
	# 100 → 170 (+70 flat health from base)
	stat_soldier_health.add_modifier(StatModifier.create_flat(70.0, mod_source, "Offense Path Level 4"))
	# 10 → 20 (+10 flat damage from base)
	stat_soldier_damage.add_modifier(StatModifier.create_flat(10.0, mod_source, "Offense Path Level 4"))
	# 5.0 → 3.5 (-1.5 flat respawn time from base)
	stat_respawn_delay.add_modifier(StatModifier.create_flat(-1.5, mod_source, "Offense Path Level 4"))

	_update_existing_soldiers()

	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, path_cost, "offense")

	print("✅ [SoldierTower] Chose OFFENSE path - Level 4: HP=%.1f, DMG=%.1f, Respawn=%.1fs" % [soldier_health, soldier_damage, respawn_delay])
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
	"""Get cost for next upgrade (matching archer tower pricing)"""
	if tower_level < MAX_LEVEL_BEFORE_CHOICE:
		# Standard upgrades (Level 1→2, 2→3)
		match tower_level:
			1: return 60  # Level 1→2
			2: return 90  # Level 2→3
	elif tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		# Path choice upgrade (Level 3→4)
		return 150  # Level 3→4 path choice
	elif tower_level == 4 and upgrade_path != "":
		# Final upgrade after path choice (Level 4→5)
		return 200  # Level 4→5 final upgrade

	return 0  # Max level reached

func get_upgrade_stats(preview_path: String = "") -> Dictionary:
	"""Get preview of what stats will be after upgrade"""
	var next_level = tower_level + 1

	# Calculate preview stats
	var preview_health = soldier_health
	var preview_damage = soldier_damage
	var preview_respawn = respawn_delay

	if tower_level < MAX_LEVEL_BEFORE_CHOICE:
		# Standard upgrades
		match next_level:
			2:
				preview_health = 120.0
				preview_damage = 12.0
				preview_respawn = 4.5
			3:
				preview_health = 150.0
				preview_damage = 15.0
				preview_respawn = 4.0
	elif tower_level == MAX_LEVEL_BEFORE_CHOICE:
		# Path choice preview
		if preview_path == "defense":
			preview_health = 180.0
			preview_damage = 18.0
			preview_respawn = 3.0
		elif preview_path == "offense":
			preview_health = 170.0
			preview_damage = 20.0
			preview_respawn = 3.5
	elif tower_level == 4:
		# Final upgrade
		if upgrade_path == "defense":
			preview_health = 220.0
			preview_damage = 18.0
			preview_respawn = 2.5
		elif upgrade_path == "offense":
			preview_health = 200.0
			preview_damage = 25.0
			preview_respawn = 3.0

	return {
		"soldier_health": preview_health,
		"soldier_damage": preview_damage,
		"respawn_delay": preview_respawn,
		"squad_size": squad_size
	}

func needs_path_choice() -> bool:
	"""Check if tower is at level 3 and needs path choice"""
	return tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == ""

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Clean up soldiers
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.queue_free()
