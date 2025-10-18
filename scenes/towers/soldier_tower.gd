extends StaticBody2D

# ============================================
# SOLDIER TOWER - Spawns a garrison of melee fighters
# ============================================
# - Spawns squad of soldiers in ring formation
# - Manages respawn timers when soldiers die
# - Rally flag allows player to position the squad
# - Plugs into existing tower placement system

# TOWER STATS
@export_group("Garrison Settings")
@export var squad_size: int = 4  ## Number of soldiers in the squad
@export var spawn_radius: float = 60.0  ## How far from tower center soldiers spawn
@export var respawn_delay: float = 5.0  ## Seconds before dead soldier respawns
@export var rally_flag_default_offset: Vector2 = Vector2(150, 0)  ## Default flag position

@export_group("Soldier Stats")
@export var soldier_scene: PackedScene  ## Soldier unit scene to spawn
@export var soldier_health: float = 100.0
@export var soldier_damage: float = 10.0
@export var soldier_attack_speed: float = 1.0

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
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
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
# CLEANUP
# ============================================

func _exit_tree():
	# Clean up soldiers
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.queue_free()
