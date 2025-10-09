extends Node2D

# ============================================
# HERO SPOT - Where heroes spawn on the map
# ============================================

signal spot_clicked(spot)

# State
var has_hero = false
var current_hero = null
var is_respawning = false
var respawn_time_left = 0.0

# Hero scene to spawn
@export var hero_scene: PackedScene  # NEW: Assign hero scene directly to spot

# References
@onready var sprite = $Sprite2D
@onready var respawn_label = $RespawnLabel
@onready var click_area = $ClickArea  # Add this if you want click-to-spawn later

func _ready():
	print("========================================")
	print("HERO SPOT READY: ", name, " at ", global_position)
	print("  Hero scene assigned: ", hero_scene != null)
	print("========================================")
	respawn_label.visible = false
	
	# Setup click detection (optional - for manual spawning later)
	if click_area:
		click_area.input_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)
		click_area.collision_layer = 8
		click_area.collision_mask = 0
	
	# AUTO-SPAWN: Wait a moment for scene to fully load, then spawn hero
	await get_tree().process_frame
	await get_tree().process_frame
	
	if hero_scene != null:
		auto_spawn_hero()
	else:
		print("WARNING: No hero scene assigned to ", name, "!")

func auto_spawn_hero():
	"""Automatically spawn hero at start"""
	print("Auto-spawning hero at ", name)
	spawn_hero(hero_scene)

func _on_click_area_input_event(viewport, event, shape_idx):
	"""Optional: Allow clicking to spawn hero manually"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not has_hero and not is_respawning:
			print("!!! HERO SPOT CLICKED (via Area2D) !!!")
			spot_clicked.emit(self)
			get_viewport().set_input_as_handled()

func _process(delta):
	# Handle respawn countdown
	if is_respawning:
		respawn_time_left -= delta
		respawn_label.text = "Respawn: " + str(ceil(respawn_time_left)) + "s"
		
		if respawn_time_left <= 0:
			respawn_hero()
	
	# Hover effect (only if no hero and not respawning)
	if not has_hero and not is_respawning:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		if distance < 32:
			sprite.modulate = Color(1.2, 1.5, 1.2)  # Green tint
		else:
			sprite.modulate = Color(1, 1, 1)

func spawn_hero(hero_scene_to_spawn: PackedScene):
	"""Spawn a hero at this spot"""
	print("========================================")
	print("SPAWN_HERO CALLED!")
	print("  Hero scene: ", hero_scene_to_spawn)
	print("========================================")
	
	if hero_scene_to_spawn == null:
		print("ERROR: Hero scene is NULL!")
		return
	
	print("Instantiating hero...")
	var hero = hero_scene_to_spawn.instantiate()
	print("  Hero instantiated: ", hero)
	
	if hero == null:
		print("ERROR: Failed to instantiate hero!")
		return
	
	print("Adding hero as child...")
	add_child(hero)
	print("  Hero added to tree: ", hero.is_inside_tree())
	
	hero.global_position = global_position
	print("  Hero position set to: ", hero.global_position)
	
	# Set hero's home position
	if hero.has_method("set_home_position"):
		print("  Calling set_home_position...")
		hero.set_home_position(global_position)
	else:
		print("  WARNING: Hero doesn't have set_home_position method!")
	
	# Connect hero death signal
	if hero.has_signal("hero_died"):
		print("  Connecting hero_died signal...")
		hero.hero_died.connect(_on_hero_died)
	else:
		print("  WARNING: Hero doesn't have hero_died signal!")
	
	# Connect hero selection signal (for HeroManager)
	if hero.has_signal("hero_selected"):
		print("  Connecting hero_selected signal...")
		# Find HeroManager and connect
		var hero_manager = get_tree().get_first_node_in_group("hero_manager")
		if hero_manager and hero_manager.has_method("_on_hero_selected"):
			hero.hero_selected.connect(hero_manager._on_hero_selected)
			print("  ✓ Connected to HeroManager")
		else:
			print("  WARNING: HeroManager not found!")
	
	current_hero = hero
	has_hero = true
	sprite.visible = false
	
	print("✓ HERO SPAWNED SUCCESSFULLY!")
	print("========================================")

func _on_hero_died(respawn_time: float):
	print("Hero died at spot: ", name, " - Respawn in ", respawn_time, "s")
	has_hero = false
	current_hero = null
	is_respawning = true
	respawn_time_left = respawn_time
	sprite.visible = true
	respawn_label.visible = true

func respawn_hero():
	print("Hero respawning at: ", name)
	is_respawning = false
	respawn_label.visible = false
	
	# Auto-spawn hero again
	if hero_scene != null:
		spawn_hero(hero_scene)

func get_spawn_position() -> Vector2:
	return global_position
