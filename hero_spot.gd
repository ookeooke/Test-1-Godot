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
	print("HERO SPOT READY: ", name, " at ", global_position)
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
		
		# Check if click is within spot radius
		if distance < 32:
			if not has_hero and not is_respawning:
				print("!!! HERO SPOT CLICKED: ", name, " !!!")
				spot_clicked.emit(self)
				get_viewport().set_input_as_handled()

func spawn_hero(hero_scene: PackedScene):
	print("SPAWNING HERO at ", name)
	var hero = hero_scene.instantiate()
	add_child(hero)
	hero.global_position = global_position
	
	# Set hero's home position
	if hero.has_method("set_home_position"):
		hero.set_home_position(global_position)
	
	# Connect hero death signal
	if hero.has_signal("hero_died"):
		hero.hero_died.connect(_on_hero_died)
	
	current_hero = hero
	has_hero = true
	sprite.visible = false
	
	print("Hero spawned successfully!")

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
