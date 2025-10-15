extends Area2D

# ============================================
# ARROW PROJECTILE - Kingdom Rush Style
# ============================================

# INSPECTOR SETTINGS - Adjust these to tune arrow behavior!
@export_group("Trajectory")
@export var arc_height: float = 50.0  ## How high the arrow arcs (0 = straight line, 100 = high arc)
@export var use_ballistic: bool = true  ## Use parabolic arc (true) or homing (false)
@export var gravity_strength: float = 980.0  ## Simulated gravity for arc

@export_group("Targeting")
@export var use_prediction: bool = true  ## Predict enemy movement
@export var prediction_time: float = 0.3  ## How far ahead to predict (seconds)

@export_group("Flight")
@export var flight_speed: float = 500.0  ## Speed of projectile

# RUNTIME PROPERTIES
var damage = 10  # Will be set by tower
var target = null  # The enemy we're targeting
var direction = Vector2.ZERO  # Direction we're flying

# BALLISTIC TRAJECTORY VARIABLES
var start_position: Vector2
var target_position: Vector2
var velocity: Vector2
var travel_time: float = 0.0
var max_flight_time: float = 3.0  # Max time before arrow despawns
var flight_time: float = 0.0  # Total calculated flight time
var current_arc_offset: float = 0.0  # Current height in arc

# ============================================
# SETUP
# ============================================

func setup(enemy, projectile_damage):
	# Called by the tower when spawned
	target = enemy
	damage = projectile_damage
	start_position = global_position

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
		return target.global_position

	# Try to get enemy velocity for prediction
	var enemy_velocity = Vector2.ZERO
	if target is CharacterBody2D:
		# Enemy is moving along path - estimate velocity
		var parent = target.get_parent()
		if parent and parent is PathFollow2D:
			# Estimate velocity based on enemy speed
			if "speed" in target:
				# Get the direction enemy is traveling
				var current_pos = target.global_position
				# Simple forward prediction
				enemy_velocity = (current_pos - global_position).normalized() * target.speed

	# Predict future position
	var predicted_pos = target.global_position + (enemy_velocity * prediction_time)
	return predicted_pos

func _setup_ballistic_trajectory():
	"""Setup parabolic arc physics (Kingdom Rush style)"""
	var horizontal_distance = target_position.distance_to(start_position)
	var direction_to_target = (target_position - start_position).normalized()

	# Calculate flight time based on horizontal distance and speed
	flight_time = horizontal_distance / flight_speed
	max_flight_time = flight_time * 1.5  # Add buffer for safety

	# Horizontal velocity (constant throughout flight)
	velocity = direction_to_target * flight_speed

	# Point arrow in initial direction
	rotation = velocity.angle()

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	travel_time += delta

	if use_ballistic:
		# KINGDOM RUSH STYLE: Ballistic arc physics
		_update_ballistic_movement(delta)
	else:
		# OLD STYLE: Homing missile
		_update_homing_movement(delta)

	# Timeout check
	if travel_time > max_flight_time:
		queue_free()

	# Off-screen check
	if global_position.length() > 5000:
		queue_free()

func _update_ballistic_movement(delta):
	"""Move arrow along parabolic arc"""
	# Move forward along horizontal path
	global_position += velocity * delta

	# Calculate arc height at current travel time
	# Parabolic formula: height = -4 * max_height * (t/flight_time) * (t/flight_time - 1)
	# This creates a smooth arc that peaks at 50% of flight time
	if flight_time > 0:
		var progress = travel_time / flight_time  # 0.0 to 1.0
		current_arc_offset = -4.0 * arc_height * progress * (progress - 1.0)
	else:
		current_arc_offset = 0

	# Apply visual arc effect by scaling the arrow (simulates height in 2D)
	# Arrow appears larger when higher in arc
	var scale_factor = 1.0 + (current_arc_offset / arc_height) * 0.3  # Up to 30% larger at peak
	scale = Vector2(scale_factor, scale_factor)

	# Rotate arrow to match velocity direction
	rotation = velocity.angle()

	# Check if we reached the target (close enough)
	var distance_to_target = global_position.distance_to(target_position)
	if distance_to_target < 20:  # Hit threshold
		# Try to hit the actual enemy if it's still there
		if target and is_instance_valid(target):
			var distance_to_enemy = global_position.distance_to(target.global_position)
			if distance_to_enemy < 50:  # Enemy is close enough to predicted position
				_hit_enemy(target)
				return
		# Missed the enemy (moved away from prediction)
		queue_free()

func _update_homing_movement(delta):
	"""Classic homing missile behavior"""
	# Update direction (enemy might have moved)
	if target and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()

	# Move forward
	global_position += direction * flight_speed * delta

func _hit_enemy(enemy):
	"""Deal damage to enemy"""
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		print("Arrow hit enemy for ", damage, " damage!")
	queue_free()

# ============================================
# COLLISION
# ============================================

func _on_body_entered(body):
	# We hit something!
	if body.is_in_group("enemy"):
		_hit_enemy(body)
