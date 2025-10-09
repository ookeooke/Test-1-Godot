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

# References
@onready var sprite = $Sprite2D
@onready var respawn_label = $RespawnLabel

func _ready():
	print("========================================")
	print("HERO SPOT READY: ", name, " at ", global_position)
	print("  Has sprite: ", sprite != null)
	print("  Has label: ", respawn_label != null)
	print("  In groups: ", get_groups())
	print("========================================")
	respawn_label.visible = false

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

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		print("========================================")
		print("MOUSE CLICK DETECTED!")
		print("  Mouse pos: ", mouse_pos)
		print("  Hero spot pos: ", global_position)
		print("  Distance: ", distance)
		print("  Has hero: ", has_hero)
		print("  Is respawning: ", is_respawning)
		print("========================================")
		
		# Check if click is within spot radius
		if distance < 32:
			if not has_hero and not is_respawning:
				print("!!! EMITTING SPOT_CLICKED SIGNAL !!!")
				spot_clicked.emit(self)
				get_viewport().set_input_as_handled()
			else:
				print("  Cannot spawn: has_hero=", has_hero, " is_respawning=", is_respawning)

func spawn_hero(hero_scene: PackedScene):
	print("========================================")
	print("SPAWN_HERO CALLED!")
	print("  Hero scene: ", hero_scene)
	print("  Hero scene is null: ", hero_scene == null)
	print("========================================")
	
	if hero_scene == null:
		print("ERROR: Hero scene is NULL!")
		return
	
	print("Instantiating hero...")
	var hero = hero_scene.instantiate()
	print("  Hero instantiated: ", hero)
	print("  Hero is null: ", hero == null)
	
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
	
	# Emit signal to spawn hero again
	spot_clicked.emit(self)

func get_spawn_position() -> Vector2:
	return global_position
