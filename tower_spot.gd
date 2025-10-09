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
	click_area.input_event.connect(_on_click_area_input)
	# Set up visual feedback on hover
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

func _on_click_area_input(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not has_tower:
				spot_clicked.emit(self)

func _on_mouse_entered():
	if not has_tower:
		sprite.modulate = Color(1.2, 1.2, 1.2)  # Brighten on hover

func _on_mouse_exited():
	sprite.modulate = Color(1, 1, 1)  # Reset

func place_tower(tower_scene: PackedScene):
	# Create and place the tower
	var tower = tower_scene.instantiate()
	add_child(tower)
	tower.global_position = global_position
	current_tower = tower
	has_tower = true
	
	# Hide the spot indicator
	sprite.visible = false
	click_area.monitoring = false
	
	print("Tower placed at spot!")

func get_position_for_menu() -> Vector2:
	# Return position for build menu (above the spot)
	return global_position + Vector2(0, -100)
