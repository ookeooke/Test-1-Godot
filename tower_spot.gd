extends Node2D

signal spot_clicked(spot)
signal tower_clicked(spot, tower)  # NEW: Signal for tower interactions

var has_tower = false
var current_tower = null

@onready var sprite = $Sprite2D
@onready var click_area = $ClickArea

func _ready():
	print("TOWER SPOT READY: ", name, " at ", global_position)
	
	# Enable the ClickArea for input detection
	click_area.input_pickable = true
	click_area.input_event.connect(_on_click_area_input_event)
	
	# Set collision layer for clickable objects
	click_area.collision_layer = 8  # Layer 4 for clickable UI elements
	click_area.collision_mask = 0
	
	# Connect hover signals for optimized hover detection
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

func _on_click_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("!!! CLICK DETECTED ON ", name, " (via Area2D) !!!")
		
		if not has_tower:
			# Empty spot - open build menu
			spot_clicked.emit(self)
			get_viewport().set_input_as_handled()
		else:
			# Tower exists - emit tower interaction signal
			print("Clicked on existing tower at ", name)
			tower_clicked.emit(self, current_tower)
			get_viewport().set_input_as_handled()

# Optimized hover detection using Area2D signals instead of distance checks
func _on_mouse_entered():
	if not has_tower:
		sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	if not has_tower:
		sprite.modulate = Color(1, 1, 1)

func place_tower(tower_scene: PackedScene):
	print("PLACING TOWER at ", name)
	var tower = tower_scene.instantiate()
	add_child(tower)
	tower.global_position = global_position
	current_tower = tower
	has_tower = true
	
	sprite.visible = false
	
	print("Tower placed successfully!")

func get_position_for_menu() -> Vector2:
	return global_position + Vector2(0, -100)
