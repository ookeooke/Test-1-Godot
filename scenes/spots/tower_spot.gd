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
	# Support both mouse and touch input
	# ONLY consume LEFT-CLICK for tower building - let RIGHT/MIDDLE-CLICK pass through to camera
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_clicked()
			get_viewport().set_input_as_handled()
		# Right/middle click - don't consume, let camera handle it
	elif event is InputEventScreenTouch and event.pressed:
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

	# CRITICAL: Set position BEFORE adding to tree
	# This ensures tower's _ready() and collision detection use the correct position
	# Setting position after add_child() causes timing issues where get_overlapping_bodies()
	# checks from the wrong position (0,0 relative to parent)
	tower.position = Vector2.ZERO  # Position relative to this spot (spot is already at correct position)

	# Start tower invisible and small for build animation
	tower.scale = Vector2.ZERO
	tower.modulate.a = 0.0

	# Add to tree - this triggers _ready() with correct position
	add_child(tower)

	# Ensure global position is correct (redundant but safe)
	tower.global_position = global_position

	current_tower = tower
	has_tower = true

	sprite.visible = false

	# Disable clicking on this spot now that tower is here
	if click_area:
		click_area.input_pickable = false

	# Play quick build animation (instant gameplay, visual polish)
	_play_build_animation(tower)

	# Camera effects: focus on new tower (shake disabled)
	# var camera = get_viewport().get_camera_2d()
	# CameraEffects.medium_shake(camera)  # Disabled - adjust in inspector if needed
	# CameraEffects.focus_on_tower(camera, tower)  # Disabled - no auto-focus

func _play_build_animation(tower: Node2D):
	"""Quick pop-in animation - tower works immediately but looks nice"""
	const BUILD_DURATION = 0.2  # Very quick - doesn't affect gameplay

	# Tower is fully functional immediately (no construction time)
	# This is just a visual effect

	# Create build particles
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.randomness = 0.4

	# Dust cloud effect
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.direction = Vector2(0, -1)  # Upward
	particles.spread = 90.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2(0, 100)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.7, 0.6, 0.5, 0.6)  # Dust/construction color

	# Fade out
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.7, 0.6, 0.8))
	gradient.add_point(1.0, Color(0.5, 0.4, 0.3, 0.0))
	particles.color_ramp = gradient

	# Tween animation for tower
	var tween = create_tween()
	tween.set_parallel(true)

	# Pop-in: scale from 0 to 1 with bounce
	tween.tween_property(tower, "scale", Vector2.ONE, BUILD_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Fade in
	tween.tween_property(tower, "modulate:a", 1.0, BUILD_DURATION * 0.7).set_ease(Tween.EASE_OUT)

	# Cleanup particles
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()

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
