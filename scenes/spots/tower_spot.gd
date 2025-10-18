extends Node2D

signal spot_clicked(spot)
signal tower_clicked(spot, tower)

var has_tower = false
var current_tower = null

@onready var sprite = $Sprite2D
@onready var click_area: Area2D = $ClickArea

func _ready():
	# Setup click detection with Area2D
	if click_area:
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

# ============================================
# CLICK HANDLING - Using Area2D
# ============================================

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_clicked()
			get_viewport().set_input_as_handled()

func _on_clicked():
	"""Called when this spot is clicked"""
	if not has_tower:
		# Empty spot - open build menu
		spot_clicked.emit(self)
	else:
		# Tower exists - open tower info
		# NOTE: This shouldn't be called when tower is here since we disable clicking
		# The tower itself should handle clicks
		tower_clicked.emit(self, current_tower)

func _on_mouse_entered():
	"""Called when mouse enters spot area"""
	if not has_tower:
		sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	"""Called when mouse leaves spot area"""
	if not has_tower:
		sprite.modulate = Color(1, 1, 1)

# ============================================
# TOWER MANAGEMENT
# ============================================

func place_tower(tower_scene: PackedScene):
	var tower = tower_scene.instantiate()

	# Set parent_spot reference before adding to tree
	if "parent_spot" in tower:
		tower.parent_spot = self

	# Add to tree first - this triggers _ready()
	add_child(tower)

	# Then set position (needs to be in tree for global_position to work)
	tower.global_position = global_position

	current_tower = tower
	has_tower = true

	sprite.visible = false

	# Disable clicking on this spot now that tower is here
	if click_area:
		click_area.input_pickable = false

	# Camera effects: focus on new tower (shake disabled)
	# var camera = get_viewport().get_camera_2d()
	# CameraEffects.medium_shake(camera)  # Disabled - adjust in inspector if needed
	# CameraEffects.focus_on_tower(camera, tower)  # Disabled - no auto-focus

func remove_tower():
	"""Called when tower is sold"""
	if current_tower and is_instance_valid(current_tower):
		current_tower.queue_free()
	
	has_tower = false
	current_tower = null
	sprite.visible = true

	# Re-enable clicking on this spot
	if click_area:
		click_area.input_pickable = true

func get_position_for_menu() -> Vector2:
	return global_position + Vector2(0, -100)
