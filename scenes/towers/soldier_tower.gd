@tool
extends BaseTower

# ============================================
# SOLDIER TOWER - Spawns a garrison of melee fighters
# ============================================

# SOLDIER SPECIFIC STATS
var stat_soldier_health: Stat
var stat_soldier_damage: Stat
var stat_soldier_attack_speed: Stat
var stat_respawn_delay: Stat

# Computed properties
var soldier_health: float:
	get: return stat_soldier_health.get_value() if stat_soldier_health else 0.0

var soldier_damage: float:
	get: return stat_soldier_damage.get_value() if stat_soldier_damage else 0.0

var soldier_attack_speed: float:
	get: return stat_soldier_attack_speed.get_value() if stat_soldier_attack_speed else 0.0

var respawn_delay: float:
	get: return stat_respawn_delay.get_value() if stat_respawn_delay else 0.0

# GARRISON SETTINGS
@export_group("Garrison Settings")
@export var squad_size: int = 3
@export var spawn_radius: float = 40.0
@export var rally_flag_default_offset: Vector2 = Vector2(80, 0)
@export var soldier_scene: PackedScene

# VISUAL SCENES (Defaults for Barracks)
@export_group("Visual Scenes")
@export var visual_scene_l1_default: PackedScene = preload("res://scenes/towers/visuals/barracks_visuals_l1.tscn")
@export var visual_scene_l2_default: PackedScene = preload("res://scenes/towers/visuals/barracks_visuals_l2.tscn")

# REFERENCES
var rally_flag: Node2D
var flag_sprite: Polygon2D

# SQUAD MANAGEMENT
var active_soldiers: Array = []
var respawn_queue: Array = []
var rally_position: Vector2

# RALLY PLACEMENT
var is_placing_rally = false
var camera: Camera2D = null

func _ready():
	# Barracks specific setup
	tower_id = "barracks"
	cost = 70 # Stalling Unit (Cheaper)
	
	# Set defaults
	if not visual_scene_l1:
		visual_scene_l1 = visual_scene_l1_default
	if not visual_scene_l2:
		visual_scene_l2 = visual_scene_l2_default

	# Initialize BaseTower logic
	super._ready()
	
	# Initialize rally position
	rally_position = global_position + rally_flag_default_offset
	
	# Create rally flag
	_create_rally_flag()
	
	# Spawn initial squad
	if not Engine.is_editor_hint():
		await get_tree().process_frame
		_spawn_initial_squad()

func _initialize_stats():
	super._initialize_stats()
	
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	if not level_1_stats.is_empty():
		stat_soldier_health = Stat.new(level_1_stats.get("soldier_health", 0.0))
		stat_soldier_damage = Stat.new(level_1_stats.get("soldier_damage", 0.0))
		stat_soldier_attack_speed = Stat.new(level_1_stats.get("soldier_attack_speed", 0.0))
		stat_respawn_delay = Stat.new(level_1_stats.get("respawn_time", 0.0))
	else:
		stat_soldier_health = Stat.new(0.0)
		stat_soldier_damage = Stat.new(0.0)
		stat_soldier_attack_speed = Stat.new(0.0)
		stat_respawn_delay = Stat.new(0.0)
		
	print("[%s] Barracks stats initialized - HP: %.1f, DMG: %.1f" % [name, soldier_health, soldier_damage])

func _process(delta):
	# Base process handles construction
	if is_under_construction:
		return
		
	# Handle respawn timers
	_update_respawn_queue(delta)

func _update_respawn_queue(delta):
	for i in range(respawn_queue.size() - 1, -1, -1):
		var entry = respawn_queue[i]
		entry["time"] -= delta
		
		if entry["time"] <= 0:
			_spawn_soldier(entry["index"])
			respawn_queue.remove_at(i)

# ============================================
# SQUAD SPAWNING
# ============================================

func _spawn_initial_squad():
	if not soldier_scene: return
	
	for i in range(squad_size):
		_spawn_soldier(i)

func _spawn_soldier(index: int):
	if not soldier_scene: return
	
	# Calculate position in ring formation around rally point
	var angle = (float(index) / squad_size) * TAU
	var offset = Vector2(cos(angle), sin(angle)) * 20.0 # Small offset around rally point
	
	var soldier = soldier_scene.instantiate()
	get_tree().root.add_child(soldier)
	
	soldier.parent_tower = self
	soldier.max_health = soldier_health
	soldier.current_health = soldier_health
	soldier.melee_damage = soldier_damage
	soldier.melee_attack_speed = soldier_attack_speed
	soldier.respawn_delay = respawn_delay
	
	# Set positions
	soldier.global_position = global_position # Spawn at tower
	soldier.set_flag_position(rally_position + offset) # Move to rally point
	
	if soldier.has_signal("soldier_died"):
		soldier.soldier_died.connect(_on_soldier_died.bind(index))
		
	if index >= active_soldiers.size():
		active_soldiers.resize(squad_size)
	active_soldiers[index] = soldier

func _on_soldier_died(time: float, soldier_index: int):
	active_soldiers[soldier_index] = null
	respawn_queue.append({
		"time": time,
		"index": soldier_index
	})

# ============================================
# RALLY FLAG SYSTEM
# ============================================

func _create_rally_flag():
	rally_flag = Node2D.new()
	rally_flag.name = "RallyFlag"
	add_child(rally_flag)
	rally_flag.top_level = true # Detach from tower rotation/scale
	rally_flag.global_position = rally_position
	
	flag_sprite = Polygon2D.new()
	rally_flag.add_child(flag_sprite)
	
	var flag_points = PackedVector2Array([
		Vector2(0, -30), Vector2(0, 0),
		Vector2(0, -25), Vector2(20, -20), Vector2(0, -15)
	])
	flag_sprite.polygon = flag_points
	flag_sprite.color = Color(1.0, 0.8, 0.0, 0.9)
	rally_flag.visible = false # Hide by default

func enter_rally_placement_mode():
	is_placing_rally = true
	range_indicator.visible = true # Show range limit
	rally_flag.visible = true
	
	if not camera:
		camera = get_viewport().get_camera_2d()
	# if camera and camera.has_method("lock_input"): camera.lock_input()

func place_rally_at(world_position: Vector2):
	# CLAMP TO RANGE (Kingdom Rush style)
	var direction = world_position - global_position
	var distance = direction.length()
	
	if distance > range_radius:
		direction = direction.normalized() * range_radius
		rally_position = global_position + direction
	else:
		rally_position = world_position
		
	rally_flag.global_position = rally_position
	
	# Update soldiers
	for i in range(active_soldiers.size()):
		var soldier = active_soldiers[i]
		if is_instance_valid(soldier):
			var angle = (float(i) / squad_size) * TAU
			var offset = Vector2(cos(angle), sin(angle)) * 20.0
			soldier.set_flag_position(rally_position + offset)
			
	is_placing_rally = false
	range_indicator.visible = is_selected
	# if camera and camera.has_method("unlock_input"): camera.unlock_input()

func _input(event):
	if is_placing_rally:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("🚩 [SoldierTower] Click detected at: ", get_global_mouse_position())
			place_rally_at(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			print("🚩 [SoldierTower] Rally placement cancelled")
			is_placing_rally = false
			range_indicator.visible = is_selected
			get_viewport().set_input_as_handled()

# ============================================
# UPGRADES
# ============================================

# ============================================
# PATH CHOICES
# ============================================

func get_path_choices() -> Array:
	return [
		{
			"id": "defense_path",
			"emoji": "🛡️", # Knights / High Defense
			"name": "Knights"
		},
		{
			"id": "offense_path",
			"emoji": "⚔️", # Barbarians / High Damage
			"name": "Barbarians"
		}
	]

func choose_defense_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "defense"
	var success = upgrade_tower()
	if success:
		current_build_time = 3.0
		_update_tower_visual()
	return success

func choose_offense_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "offense"
	var success = upgrade_tower()
	if success:
		current_build_time = 3.0
		_update_tower_visual()
	return success

func upgrade_tower():
	var old_level = tower_level
	var success = super.upgrade_tower()
	
	if success:
		var old_source = "upgrade_level_%d" % old_level
		stat_soldier_health.remove_modifiers_from_source(old_source)
		stat_soldier_damage.remove_modifiers_from_source(old_source)
		stat_soldier_attack_speed.remove_modifiers_from_source(old_source)
		stat_respawn_delay.remove_modifiers_from_source(old_source)
		
		var mod_source = "upgrade_level_%d" % tower_level
		var target_stats: Dictionary
		var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
		
		if tower_level <= MAX_LEVEL_BEFORE_CHOICE:
			target_stats = TowerData.get_tower_stats(tower_id, tower_level)
		else:
			var path_key = upgrade_path + "_path"
			target_stats = TowerData.get_tower_stats(tower_id, tower_level, path_key)
			
		if not target_stats.is_empty():
			var health_delta = target_stats.get("soldier_health", 0) - level_1_stats.get("soldier_health", 0)
			if health_delta != 0:
				stat_soldier_health.add_modifier(StatModifier.create_flat(health_delta, mod_source, "Level %d" % tower_level))
				
			var damage_delta = target_stats.get("soldier_damage", 0) - level_1_stats.get("soldier_damage", 0)
			if damage_delta != 0:
				stat_soldier_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Level %d" % tower_level))
				
			var as_delta = target_stats.get("soldier_attack_speed", 0) - level_1_stats.get("soldier_attack_speed", 0)
			if as_delta != 0:
				stat_soldier_attack_speed.add_modifier(StatModifier.create_flat(as_delta, mod_source, "Level %d" % tower_level))
				
			var respawn_delta = target_stats.get("respawn_time", 0) - level_1_stats.get("respawn_time", 0)
			if respawn_delta != 0:
				stat_respawn_delay.add_modifier(StatModifier.create_flat(respawn_delta, mod_source, "Level %d" % tower_level))
				
		_update_existing_soldiers()
		
	return success

func _update_existing_soldiers():
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.max_health = soldier_health
			soldier.melee_damage = soldier_damage
			soldier.melee_attack_speed = soldier_attack_speed
			soldier.respawn_delay = respawn_delay
			soldier.current_health = soldier_health # Heal on upgrade
			if soldier.has_method("update_health_bar"):
				soldier.update_health_bar()

func _exit_tree():
	for soldier in active_soldiers:
		if is_instance_valid(soldier):
			soldier.queue_free()
