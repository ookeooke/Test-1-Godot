extends Node2D

signal spot_clicked(spot)

var has_hero = false
var current_hero = null
var is_respawning = false
var respawn_time_left = 0.0

@onready var sprite = $Sprite2D
@onready var respawn_label = $RespawnLabel
@onready var click_area = $ClickArea  # Add this

func _ready():
	print("HERO SPOT READY: ", name)
	respawn_label.visible = false
	
	# Setup click detection
	if click_area:
		click_area.input_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)
		click_area.collision_layer = 8
		click_area.collision_mask = 0

func _on_click_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not has_hero and not is_respawning:
			print("!!! HERO SPOT CLICKED (via Area2D) !!!")
			spot_clicked.emit(self)
			get_viewport().set_input_as_handled()

func _process(delta):
	if is_respawning:
		respawn_time_left -= delta
		respawn_label.text = "Respawn: " + str(ceil(respawn_time_left)) + "s"
		
		if respawn_time_left <= 0:
			respawn_hero()
	
	# Hover effect
	if not has_hero and not is_respawning:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		if distance < 32:
			sprite.modulate = Color(1.2, 1.5, 1.2)
		else:
			sprite.modulate = Color(1, 1, 1)

func _on_hero_died(respawn_time: float):
	print("Hero died - Respawn in ", respawn_time, "s")
	has_hero = false
	current_hero = null
	is_respawning = true
	respawn_time_left = respawn_time
	sprite.visible = true
	respawn_label.visible = true

func respawn_hero():
	print("Hero respawning!")
	is_respawning = false
	respawn_label.visible = false
	spot_clicked.emit(self)

func get_spawn_position() -> Vector2:
	return global_position
