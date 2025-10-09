extends Node2D

# ============================================
# TOWER SPOT - Kingdom Rush style placement
# ============================================

signal spot_clicked(spot)

# State
var has_tower = false
var current_tower = null

# References
@onready var sprite = $Sprite2D
@onready var click_area = $ClickArea

func _ready():
	print("TOWER SPOT READY: ", name, " at ", global_position)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		
		# Check if click is within 32 pixels (our collision radius)
		if distance < 32:
			print("!!! CLICK DETECTED ON ", name, " !!!")
			if not has_tower:
				spot_clicked.emit(self)
				get_viewport().set_input_as_handled()

func _process(delta):
	# Check if mouse is hovering
	var mouse_pos = get_global_mouse_position()
	var distance = global_position.distance_to(mouse_pos)
	
	if distance < 32 and not has_tower:
		if sprite.modulate != Color(1.2, 1.2, 1.2):
			sprite.modulate = Color(1.2, 1.2, 1.2)
	else:
		if sprite.modulate != Color(1, 1, 1):
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
