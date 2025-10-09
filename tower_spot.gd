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
	set_process_input(true)

func _on_click_area_input(viewport, event, shape_idx):
	print("!!! INPUT EVENT RECEIVED on ", name, " !!!")
	print("  Event type: ", event.get_class())
	
	if event is InputEventMouseButton:
		print("  Mouse button event:")
		print("    - Button index: ", event.button_index)
		print("    - Pressed: ", event.pressed)
		print("    - Is left click: ", event.button_index == MOUSE_BUTTON_LEFT)
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("  >>> LEFT CLICK DETECTED! <<<")
			if not has_tower:
				print("  >>> EMITTING SPOT_CLICKED SIGNAL! <<<")
				spot_clicked.emit(self)
			else:
				print("  >>> Already has tower, not emitting signal <<<")

func _on_mouse_entered():
	print(">>> Mouse ENTERED tower spot: ", name)
	if not has_tower:
		sprite.modulate = Color(1.2, 1.2, 1.2)
		print("  Sprite brightened")

func _on_mouse_exited():
	print("<<< Mouse EXITED tower spot: ", name)
	sprite.modulate = Color(1, 1, 1)
	print("  Sprite reset")

func place_tower(tower_scene: PackedScene):
	print("PLACING TOWER at ", name)
	var tower = tower_scene.instantiate()
	add_child(tower)
	tower.global_position = global_position
	current_tower = tower
	has_tower = true
	
	sprite.visible = false
	click_area.monitoring = false
	
	print("Tower placed successfully!")

func get_position_for_menu() -> Vector2:
	return global_position + Vector2(0, -100)

# Add this to detect ANY input
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var distance = global_position.distance_to(mouse_pos)
		print("GLOBAL INPUT on ", name, " - Mouse at: ", mouse_pos, " Distance: ", distance)
