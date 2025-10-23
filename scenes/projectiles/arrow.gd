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
@export var prediction_time: float = 0.6  ## How far ahead to predict (seconds) - matches typical arrow flight time

@export_group("Flight")
@export var flight_speed: float = 500.0  ## Speed of projectile

@export_group("Rotation")
@export var rotation_smoothing: bool = true  ## Enable smooth rotation for realistic "gravity facing"
@export var rotation_decay_rate: float = 15.0  ## Rotation smoothing speed (5=gentle, 15=balanced, 30=instant)

# RUNTIME PROPERTIES
var damage = 10  # Will be set by tower
var target = null  # The enemy we're targeting
var direction = Vector2.ZERO  # Direction we're flying
var source = null  # The tower/hero that fired this arrow (for balance tracking)

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

func setup(enemy, projectile_damage, projectile_source = null):
	# Called by the tower when spawned
	target = enemy
	damage = projectile_damage
	source = projectile_source
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
				# FIXED: Get actual path direction, not arrow-to-enemy direction
				# Use PathFollow2D's transform to get forward direction along path
				var path_direction = Vector2.RIGHT  # Default fallback

				# Method 1: Use PathFollow2D's rotation (most reliable)
				if parent.has_method("get_transform"):
					# PathFollow2D's rotation follows the path curve
					# Transform's x-axis points in the direction of travel
					path_direction = parent.get_transform().x.normalized()

				# Calculate velocity: direction × speed
				enemy_velocity = path_direction * target.speed

				DebugConfig.log_targeting("🎯 Arrow prediction: enemy_vel=%s, speed=%.1f, dir=%s" % [enemy_velocity, target.speed, path_direction])

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

func _update_ballistic_movement(_delta):
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

	# ROTATION: Calculate realistic arrow orientation facing velocity vector
	# Arrows "face gravity" by aligning with their velocity (horizontal + gravity-affected vertical)
	var horizontal_dir = (target_position - start_position).normalized()

	# Build FULL 2D velocity vector (not just X component!)
	# Horizontal: Full directional velocity maintaining trajectory
	# Vertical: Gravity-affected velocity (starts positive/up, becomes negative/down)
	var horizontal_velocity = horizontal_dir * flight_speed  # Full 2D horizontal motion

	var actual_velocity = Vector2(
		horizontal_velocity.x,                          # X component of horizontal
		horizontal_velocity.y - current_visual_velocity # Y component + gravity effect
	)

	# Calculate target rotation from velocity direction
	var target_rotation = actual_velocity.angle()

	# Apply rotation with optional smoothing for realistic "weight" feeling
	if rotation_smoothing:
		# Framerate-independent exponential decay smoothing
		# With decay_rate=15: arrow reaches 50% in 0.05s, 90% in 0.15s
		# This eliminates jitter and adds subtle inertia without feeling laggy
		var dt = get_physics_process_delta_time()
		var smoothing_factor = 1.0 - exp(-rotation_decay_rate * dt)
		rotation = lerp_angle(rotation, target_rotation, smoothing_factor)
	else:
		# Instant rotation (physically accurate, current behavior)
		rotation = target_rotation

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
	"""Check for enemy collisions along the movement path using MULTI-POINT raycast
	IMPORTANT: Uses 4 raycasts in a radial pattern to prevent tunneling through fast enemies"""
	# Skip if we haven't moved
	if from_pos.distance_to(to_pos) < 0.1:
		return

	# Get the physics space
	var space_state = get_world_2d().direct_space_state

	# CRITICAL: Rotate collision offset to match arrow's current orientation!
	# CollisionShape2D is at (10, 0) in LOCAL space (arrow tip)
	# But we need to transform it to WORLD space using arrow's rotation
	var local_offset = Vector2(10, 0)  # Tip offset in arrow's local space
	var rotated_offset = local_offset.rotated(rotation)  # Transform to world space

	# NEW: Calculate visual height offset at previous and current frame
	# This makes the raycast follow the visual arc instead of ground level!
	var delta = get_physics_process_delta_time()
	var visual_offset_from = _get_visual_offset_at_time(travel_time - delta)
	var visual_offset_to = _get_visual_offset_at_time(travel_time)

	# Apply BOTH the rotated tip offset AND the visual height offset
	# This ensures collision detection matches where the arrow sprite actually appears
	var from_with_offset = from_pos + rotated_offset + visual_offset_from
	var to_with_offset = to_pos + rotated_offset + visual_offset_to

	# MULTI-POINT RAYCAST: Check 5 points (center + 4 radial points)
	# This creates "thick" collision detection to catch fast-moving enemies
	# Collision radius from CircleShape2D is now 12.0 (doubled from 6.0)
	var collision_radius = 12.0
	var check_points = [
		Vector2.ZERO,  # Center ray
		Vector2(collision_radius * 0.7, 0),  # Right
		Vector2(-collision_radius * 0.7, 0),  # Left
		Vector2(0, collision_radius * 0.7),  # Down
		Vector2(0, -collision_radius * 0.7)  # Up
	]

	# Check each point for collision
	for offset in check_points:
		# Rotate offset to match arrow's orientation
		var rotated_check_offset = offset.rotated(rotation)

		# Create raycast from (previous + offset) to (current + offset)
		var check_from = from_with_offset + rotated_check_offset
		var check_to = to_with_offset + rotated_check_offset

		# DEBUG: Visualize raycast lines when F4 debug enabled
		if DebugConfig.visual_debug_enabled:
			_debug_draw_raycast(check_from, check_to, Color.CYAN)

		var query = PhysicsRayQueryParameters2D.create(check_from, check_to)
		query.collision_mask = 1  # Layer 1 = enemies
		query.collide_with_areas = false  # Only check bodies, not areas
		query.collide_with_bodies = true

		# Perform the raycast
		var result = space_state.intersect_ray(query)

		# If we hit something
		if result and result.has("collider"):
			var hit_body = result.collider

			# Check if it's an enemy
			if hit_body.is_in_group("enemy"):
				DebugConfig.log_targeting("✅ Multi-raycast HIT: offset=%s" % [offset])

				# DEBUG: Draw hit raycast in green
				if DebugConfig.visual_debug_enabled:
					_debug_draw_raycast(check_from, check_to, Color.GREEN)

				_hit_enemy(hit_body)
				return  # Stop checking once we hit something

func _hit_enemy(enemy):
	"""Deal damage to enemy"""
	# Calculate the ACTUAL VISUAL position where arrow appears on screen
	var visual_offset = Vector2(0, 0)

	# Account for visual arc height (sprite is offset upward during flight)
	if has_node("ColorRect"):
		var arrow_sprite = get_node("ColorRect")
		visual_offset.y = arrow_sprite.position.y  # This is -visual_height (negative = up)

	# CRITICAL: Rotate collision offset to match arrow's current orientation!
	# CollisionShape2D is at (10, 0) in LOCAL space - must transform to world space
	var local_offset = Vector2(10, 0)  # Tip offset in arrow's local space
	var rotated_collision_offset = local_offset.rotated(rotation)  # Transform to world space

	# Final hit position = base position + visual offset + rotated collision offset
	var hit_position = global_position + visual_offset + rotated_collision_offset

	# Spawn red X hit marker at VISUAL impact point (where arrow appears)
	# IMPORTANT: Attach to enemy as child so it follows the moving enemy!
	if hit_marker_scene and enemy and is_instance_valid(enemy):
		var hit_marker = hit_marker_scene.instantiate()

		# Calculate hit position in enemy's LOCAL coordinate space
		# This way the marker moves with the enemy automatically
		var local_hit_position = hit_position - enemy.global_position

		# Attach marker as child of enemy (like health bar)
		enemy.add_child(hit_marker)
		hit_marker.position = local_hit_position  # Use local position, not global

	# Track damage dealt (before applying, to capture who shot it)
	var source_type = "tower"
	if source and source.has_method("get_hero_id"):
		source_type = "hero_ranged"

	if BalanceTracker and source:
		BalanceTracker.record_damage(source, enemy, damage, source_type)

	# Deal damage to enemy (pass source for kill tracking)
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, source, source_type)

	# Destroy arrow
	queue_free()

# ============================================
# COLLISION
# ============================================

func _on_body_entered(body):
	# We hit something!
	if body.is_in_group("enemy"):
		_hit_enemy(body)

# ============================================
# HELPER FUNCTIONS
# ============================================

func _get_visual_offset_at_time(time: float) -> Vector2:
	"""Calculate the visual Y-offset at a specific time in the flight
	This is used to make collision detection follow the visual arc"""
	if not use_ballistic:
		return Vector2.ZERO

	# Use same physics formula as _update_ballistic_movement (line 169)
	# Calculate height using ballistic formula: h = v0*t - 0.5*g*t^2
	var height = (visual_z_velocity * time) - (0.5 * visual_gravity * time * time)

	# Clamp to ground level (don't go below 0)
	height = max(0.0, height)

	# Return as Vector2 offset (negative Y = up on screen, matching line 177)
	return Vector2(0, -height)

func _debug_draw_raycast(from: Vector2, to: Vector2, color: Color):
	"""Draw a debug line showing the raycast path (F4 debug mode)"""
	# Create temporary line to visualize raycast
	var debug_line = Line2D.new()
	get_tree().root.add_child(debug_line)
	debug_line.add_point(from)
	debug_line.add_point(to)
	debug_line.width = 1.0
	debug_line.default_color = color
	debug_line.z_index = 1000  # Draw on top

	# Remove after 1 frame (0.016s at 60 FPS)
	await get_tree().create_timer(0.016).timeout
	if is_instance_valid(debug_line):
		debug_line.queue_free()
