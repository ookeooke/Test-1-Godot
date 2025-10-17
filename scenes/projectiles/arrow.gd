extends Area2D

# ============================================
# ARROW PROJECTILE - Kingdom Rush Style
# ============================================

# INSPECTOR SETTINGS - Adjust these to tune arrow behavior!
@export_group("Trajectory")
@export var arc_height: float = 50.0  ## How high the arrow arcs visually (0 = straight line, 100 = high arc)
@export var use_ballistic: bool = true  ## Use arc trajectory (true) or homing (false)

@export_group("Targeting")
@export var use_prediction: bool = true  ## Predict enemy movement
@export var prediction_time: float = 0.3  ## How far ahead to predict (seconds)

@export_group("Flight")
@export var flight_speed: float = 500.0  ## Speed of projectile

# RUNTIME PROPERTIES
var damage = 10  # Will be set by tower
var target = null  # The enemy we're targeting
var direction = Vector2.ZERO  # Direction we're flying

# TRAJECTORY VARIABLES
var start_position: Vector2
var target_position: Vector2
var travel_time: float = 0.0
var flight_time: float = 0.0  # Total calculated flight time
var previous_position: Vector2  # For continuous collision detection

# VISUAL GRAVITY SIMULATION (for realistic arc feel)
var visual_z_velocity: float = 0.0  # Initial upward velocity
var visual_gravity: float = 980.0   # Gravity strength (980 = Earth gravity)

# HIT MARKER EFFECT
var hit_marker_scene = preload("res://scenes/effects/hit_marker.tscn")

# ============================================
# SETUP
# ============================================

func setup(enemy, projectile_damage):
	# Called by the tower when spawned
	target = enemy
	damage = projectile_damage
	start_position = global_position
	previous_position = global_position  # Initialize for collision detection

	if not target or not is_instance_valid(target):
		queue_free()
		return

	# Calculate target position (with prediction if enabled)
	target_position = _calculate_target_position()

	if use_ballistic:
		# KINGDOM RUSH STYLE: Ballistic arc trajectory
		_setup_ballistic_trajectory()
	else:
		# OLD STYLE: Simple homing
		direction = (target_position - global_position).normalized()
		rotation = direction.angle()

func _calculate_target_position() -> Vector2:
	"""Calculate where to aim (current pos or predicted pos)"""
	if not use_prediction or not target or not is_instance_valid(target):
		return _get_target_hit_point()

	# Get the base hit point (visual center or HitPoint marker)
	var base_position = _get_target_hit_point()

	# Try to get enemy velocity for prediction
	var enemy_velocity = Vector2.ZERO
	if target is CharacterBody2D:
		# Enemy is moving along path - estimate velocity
		var parent = target.get_parent()
		if parent and parent is PathFollow2D:
			# Estimate velocity based on enemy speed
			if "speed" in target:
				# Get the direction enemy is traveling
				var current_pos = base_position
				# Simple forward prediction
				enemy_velocity = (current_pos - global_position).normalized() * target.speed

	# Predict future position
	var predicted_pos = base_position + (enemy_velocity * prediction_time)
	return predicted_pos

func _get_target_hit_point() -> Vector2:
	"""Get the visual center / hit point of the target enemy"""
	if not target or not is_instance_valid(target):
		return global_position

	# OPTION 1: Check for "HitPoint" marker node (preferred - allows artistic control)
	if target.has_node("HitPoint"):
		return target.get_node("HitPoint").global_position

	# OPTION 2: Fallback to enemy origin (backward compatibility)
	return target.global_position

func _setup_ballistic_trajectory():
	"""Setup visual arc with gravity simulation (Kingdom Rush style)"""
	var distance = target_position.distance_to(start_position)

	# Calculate how long the arrow will take to reach target
	flight_time = distance / flight_speed

	# Calculate initial upward velocity needed to reach arc_height
	# Using physics: to reach height h, need velocity v = sqrt(2 * g * h)
	# But we want the peak at halfway through flight, so adjust timing
	var time_to_peak = flight_time / 2.0
	# v = g * t (at peak, velocity = 0, so v0 = g * t)
	visual_z_velocity = visual_gravity * time_to_peak

	# Point arrow toward target initially (will update during flight)
	var direction_to_target = (target_position - start_position).normalized()
	rotation = direction_to_target.angle()

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Connect collision signal
	body_entered.connect(_on_body_entered)

	# Get shadow reference if it exists
	if has_node("Shadow"):
		var shadow = get_node("Shadow")
		# Shadow stays at relative position (0,0) = ground level

func _physics_process(delta):
	travel_time += delta

	if use_ballistic:
		# KINGDOM RUSH STYLE: Visual arc with straight-line movement
		_update_ballistic_movement(delta)
	else:
		# OLD STYLE: Homing missile
		_update_homing_movement(delta)

	# Timeout check (flight_time + buffer)
	if travel_time > flight_time + 1.0:
		queue_free()

	# Off-screen check
	if global_position.length() > 5000:
		queue_free()

func _update_ballistic_movement(delta):
	"""Ballistic arc with gravity simulation - looks like Kingdom Rush!"""

	# Calculate progress from 0.0 (start) to 1.0 (target)
	var progress = clamp(travel_time / flight_time, 0.0, 1.0)

	# CONTINUOUS COLLISION DETECTION: Check path before moving
	var new_position = start_position.lerp(target_position, progress)
	_check_collision_along_path(previous_position, new_position)

	# POSITION: Move in straight line from start to target (lerp)
	previous_position = global_position  # Store old position
	global_position = new_position

	# VISUAL ARC: Use gravity physics for realistic arc
	# Current vertical velocity (decreases due to gravity)
	var current_visual_velocity = visual_z_velocity - (visual_gravity * travel_time)

	# Calculate height using ballistic formula: h = v0*t - 0.5*g*t^2
	var visual_height = (visual_z_velocity * travel_time) - (0.5 * visual_gravity * travel_time * travel_time)

	# Clamp to ground level (don't go below 0)
	visual_height = max(0.0, visual_height)

	# Move arrow sprite UP (negative Y = up on screen)
	if has_node("ColorRect"):
		var arrow_sprite = get_node("ColorRect")
		arrow_sprite.position.y = -visual_height  # Negative = UP on screen

	# Scale arrow larger when higher (simulates perspective)
	# Use actual height vs expected peak height
	var expected_peak = (visual_z_velocity * visual_z_velocity) / (2.0 * visual_gravity)
	var height_ratio = visual_height / max(expected_peak, 1.0)
	var scale_factor = 1.0 + height_ratio * 0.4
	if has_node("ColorRect"):
		get_node("ColorRect").scale = Vector2(scale_factor, scale_factor)

	# Shadow gets smaller when arrow is higher
	if has_node("Shadow"):
		var shadow_scale = 1.0 - height_ratio * 0.5
		get_node("Shadow").scale = Vector2(shadow_scale, shadow_scale)

	# ROTATION: Calculate true ballistic angle
	# Arrow angle = atan2(vertical_velocity, horizontal_velocity)
	var horizontal_dir = (target_position - start_position).normalized()
	var horizontal_speed = flight_speed

	# Calculate angle from velocities (negative because up is negative Y)
	var arc_angle = atan2(-current_visual_velocity, horizontal_speed)
	rotation = horizontal_dir.angle() + arc_angle

	# Check if arrow reached target (progress >= 1.0)
	if progress >= 1.0:
		# Arrow always hits - no missing!
		if target and is_instance_valid(target):
			_hit_enemy(target)
		else:
			queue_free()

func _update_homing_movement(delta):
	"""Classic homing missile behavior"""
	# Update direction (enemy might have moved)
	if target and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()

	# CONTINUOUS COLLISION DETECTION: Check path before moving
	var new_position = global_position + direction * flight_speed * delta
	_check_collision_along_path(previous_position, new_position)

	# Move forward
	previous_position = global_position  # Store old position
	global_position = new_position

func _check_collision_along_path(from_pos: Vector2, to_pos: Vector2):
	"""Check for enemy collisions along the movement path using raycast"""
	# Skip if we haven't moved
	if from_pos.distance_to(to_pos) < 0.1:
		return

	# Get the physics space
	var space_state = get_world_2d().direct_space_state

	# IMPORTANT: Account for collision shape offset!
	# CollisionShape2D is at position (10, 0) - arrow tip position
	var collision_offset = Vector2(10, 0)
	var from_with_offset = from_pos + collision_offset
	var to_with_offset = to_pos + collision_offset

	# Create a raycast query from previous position to new position
	var query = PhysicsRayQueryParameters2D.create(from_with_offset, to_with_offset)
	query.collision_mask = 1  # Layer 1 = enemies (from base_enemy.gd line 70)
	query.collide_with_areas = false  # Only check bodies, not areas
	query.collide_with_bodies = true

	# Perform the raycast
	var result = space_state.intersect_ray(query)

	# If we hit something
	if result and result.has("collider"):
		var hit_body = result.collider

		# Check if it's an enemy
		if hit_body.is_in_group("enemy"):
			_hit_enemy(hit_body)

func _hit_enemy(enemy):
	"""Deal damage to enemy"""
	# Calculate the ACTUAL VISUAL position where arrow appears on screen
	var visual_offset = Vector2(0, 0)

	# Account for visual arc height (sprite is offset upward during flight)
	if has_node("ColorRect"):
		var arrow_sprite = get_node("ColorRect")
		visual_offset.y = arrow_sprite.position.y  # This is -visual_height (negative = up)

	# Account for collision shape offset (arrow tip is at x=10)
	var collision_offset = Vector2(10, 0)

	# Final hit position = base position + visual offset + collision offset
	var hit_position = global_position + visual_offset + collision_offset

	# Spawn red X hit marker at VISUAL impact point (where arrow appears)
	if hit_marker_scene:
		var hit_marker = hit_marker_scene.instantiate()
		get_tree().root.add_child(hit_marker)
		hit_marker.global_position = hit_position

	# Deal damage to enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)

	# Destroy arrow
	queue_free()

# ============================================
# COLLISION
# ============================================

func _on_body_entered(body):
	# We hit something!
	if body.is_in_group("enemy"):
		_hit_enemy(body)
