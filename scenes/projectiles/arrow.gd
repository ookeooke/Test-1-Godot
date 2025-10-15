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
	"""Setup simple visual arc (Kingdom Rush style - simplified)"""
	var distance = target_position.distance_to(start_position)

	# Calculate how long the arrow will take to reach target
	flight_time = distance / flight_speed

	# Point arrow toward target initially
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
	"""Simple visual arc - arrow moves straight but sprite arcs (Kingdom Rush style)"""

	# Calculate progress from 0.0 (start) to 1.0 (target)
	var progress = clamp(travel_time / flight_time, 0.0, 1.0)

	# POSITION: Move in straight line from start to target (lerp)
	global_position = start_position.lerp(target_position, progress)

	# VISUAL ARC: Sine wave creates smooth up/down arc
	# sin(progress * PI) creates perfect arc: 0 -> 1 -> 0
	var visual_height = sin(progress * PI) * arc_height

	# Move arrow sprite UP (negative Y) when at height
	if has_node("ColorRect"):
		var arrow_sprite = get_node("ColorRect")
		arrow_sprite.position.y = -visual_height  # Up on screen

	# Scale arrow larger when higher (simulates perspective)
	var scale_factor = 1.0 + (visual_height / max(arc_height, 1.0)) * 0.4
	if has_node("ColorRect"):
		get_node("ColorRect").scale = Vector2(scale_factor, scale_factor)

	# Shadow gets smaller when arrow is higher
	if has_node("Shadow"):
		var shadow_scale = 1.0 - (visual_height / max(arc_height, 1.0)) * 0.5
		get_node("Shadow").scale = Vector2(shadow_scale, shadow_scale)

	# Rotate arrow to follow arc angle
	# Calculate visual velocity direction based on sine derivative
	var direction_to_target = (target_position - start_position).normalized()
	var arc_angle = cos(progress * PI) * (arc_height / flight_time) * 0.01  # Derivative of sine
	rotation = direction_to_target.angle() - arc_angle

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
