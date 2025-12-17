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
	tower.position = Vector2.ZERO # Position relative to this spot (spot is already at correct position)

	# Start tower invisible and small for build animation
	tower.scale = Vector2.ZERO
	tower.modulate.a = 0.0

	# Add to tree - this triggers _ready() with correct position
	add_child(tower)

	# Ensure global position is correct (redundant but safe)
	tower.global_position = global_position

	current_tower = tower
	has_tower = true

	# Note: sprite.visible is NOT set to false here anymore.
	# We interpret the spot sprite as the "foundation" during construction.
	# It is hidden at the END of _play_build_animation.

	# Disable clicking on this spot now that tower is here
	if click_area:
		click_area.input_pickable = false

	# Play quick build animation (instant gameplay, visual polish)
	play_construction_intro(tower)

	# Camera effects: focus on new tower (shake disabled)
	# var camera = get_viewport().get_camera_2d()
	# CameraEffects.medium_shake(camera)  # Disabled - adjust in inspector if needed
	# CameraEffects.focus_on_tower(camera, tower)  # Disabled - no auto-focus

func play_construction_intro(tower: Node2D):
	"""Kingdom Rush style intro: Flash & Foundation"""
	print("[TowerSpot] 🏗️ Playing Construction Intro for %s" % tower.name)
	# STAGE 1: Initial Flash & Foundation (0.15s)
	_play_construction_flash()
	await _play_foundation_stage(tower)
	
	# NOTE: We stop here. The 'Construction Loop' is handled by BaseTower's ConstructionSite.

func play_construction_complete(tower: Node2D):
	"""Stage 4: Completion flash and bounce"""
	print("[TowerSpot] ✨ Playing Construction Complete for %s" % tower.name)
	
	# CRITICAL FIX: Ensure tower is fully visible/solid before playing completion
	# (In case the Intro left it desaturated/transparent)
	tower.modulate = Color(1, 1, 1, 1)
	tower.scale = Vector2.ONE
	
	await _play_completion_stage(tower)
	
	# NOTE: We DO NOT hide sprite.visible here anymore.
	# BaseTower._on_construction_finished() will handle hiding the spot.

# Legacy / Internal helper
# _play_construction_stage is skipped in the sync model as BaseTower handles the "loop".

func _play_construction_flash():
	"""Stage 1: Initial bright flash when construction starts"""
	var flash = ColorRect.new()
	add_child(flash)
	flash.position = Vector2(-30, -30) # Centered on 60x60
	flash.size = Vector2(60, 60)
	flash.color = Color(1.2, 1.2, 1.0, 1.0) # OVERBRIGHT (HDR) for extra pop
	flash.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)

	await tween.finished
	flash.queue_free()

func _play_foundation_stage(tower: Node2D):
	"""Stage 2: Foundation appears with dust particles"""
	# Create foundation dust burst
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.4
	particles.explosiveness = 1.0

	# Ground dust spreading outward
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.direction = Vector2(0, 0) # Radial
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2(0, 50)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.6, 0.5, 0.4, 0.7)

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.7, 0.6, 0.5, 0.8))
	gradient.add_point(1.0, Color(0.5, 0.4, 0.3, 0.0))
	particles.color_ramp = gradient

	# Tower starts to appear (small scale)
	tower.scale = Vector2(0.3, 0.3)
	tower.modulate.a = 0.5
	tower.modulate = Color(0.8, 0.8, 0.8, 0.5) # Desaturated during construction

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(tower, "scale", Vector2(0.5, 0.5), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(tower, "modulate:a", 0.7, 0.15)

	await tween.finished

	# Cleanup particles after they finish
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

# _play_construction_stage removed (Moved logic to ConstructionSite.tscn)

func _play_completion_stage(tower: Node2D):
	"""Stage 4: Completion flash, bounce, and celebration particles"""
	# Golden completion flash
	var flash = ColorRect.new()
	add_child(flash)
	flash.position = Vector2(-40, -40)
	flash.size = Vector2(80, 80)
	flash.color = Color(1.0, 0.9, 0.4, 0.0) # Golden

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.6, 0.1)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)

	# Victory sparkles burst
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.position = Vector2(0, -20)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.5
	particles.explosiveness = 1.0

	# Upward celebration burst
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 15.0
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 150)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.95, 0.6, 1.0) # Bright golden

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.95, 0.6, 1.0))
	gradient.add_point(0.7, Color(1.0, 0.9, 0.5, 0.5))
	gradient.add_point(1.0, Color(0.9, 0.8, 0.4, 0.0))
	particles.color_ramp = gradient

	# Satisfying bounce effect (Kingdom Rush style)
	var bounce_tween = create_tween()
	bounce_tween.tween_property(tower, "scale", Vector2(1.15, 1.15), 0.08).set_ease(Tween.EASE_OUT)
	bounce_tween.tween_property(tower, "scale", Vector2(0.95, 0.95), 0.08).set_ease(Tween.EASE_IN_OUT)
	bounce_tween.tween_property(tower, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT)

	await bounce_tween.finished

	# Cleanup
	flash.queue_free()
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

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
