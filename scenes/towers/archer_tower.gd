extends StaticBody2D

# ============================================
# ARCHER TOWER - Shoots arrows at enemies
# ============================================

# TOWER STATS
var damage = 15
var attack_speed = 1.2  # Attacks per second
var range_radius = 300  # Detection range

# REFERENCES
var detection_range: Area2D
var range_indicator: Line2D
var shoot_timer: Timer

# TARGETING
var enemies_in_range = []  # List of enemies we can shoot
var current_target = null  # Enemy we're currently aiming at

# PROJECTILE
@export var projectile_scene: PackedScene
# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Get references to child nodes
	detection_range = $DetectionRange
	range_indicator = $RangeIndicator
	
	# Connect detection signals
	detection_range.body_entered.connect(_on_enemy_entered_range)
	detection_range.body_exited.connect(_on_enemy_exited_range)
	
	# Create shoot timer
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 1.0 / attack_speed  # Convert attacks/sec to seconds
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	shoot_timer.start()
	
	# Draw range indicator
	draw_range_circle()

func _process(delta):
	# Always aim at the current target
	if current_target and is_instance_valid(current_target):
		look_at(current_target.global_position)

# ============================================
# TARGETING FUNCTIONS
# ============================================

func _on_enemy_entered_range(body):
	# An enemy entered our range
	if body.is_in_group("enemy"):
		enemies_in_range.append(body)
		print("Tower detected enemy! Total in range: ", enemies_in_range.size())

func _on_enemy_exited_range(body):
	# An enemy left our range
	if body.is_in_group("enemy"):
		enemies_in_range.erase(body)

func get_closest_enemy():
	# Find the closest enemy from our list
	if enemies_in_range.is_empty():
		return null
	
	# Clean up dead/invalid enemies
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
	
	if enemies_in_range.is_empty():
		return null
	
	# Find closest
	var closest = enemies_in_range[0]
	var closest_distance = global_position.distance_to(closest.global_position)
	
	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest = enemy
			closest_distance = distance
	
	return closest

# ============================================
# SHOOTING FUNCTIONS
# ============================================

func _on_shoot_timer_timeout():
	# Try to shoot every X seconds
	current_target = get_closest_enemy()
	
	if current_target != null:
		shoot_at(current_target)

func shoot_at(target):
	# Create projectile
	var arrow = projectile_scene.instantiate()
	get_tree().root.add_child(arrow)  # Add to scene root (not as child of tower)
	
	# Position arrow at tower's position
	arrow.global_position = global_position
	
	# Tell arrow where to go
	arrow.setup(target, damage)
	
	print("Tower fired arrow at enemy!")

# ============================================
# VISUAL FUNCTIONS
# ============================================

func draw_range_circle():
	# Draw a circle to show range
	var points = []
	var num_points = 64  # More points = smoother circle
	
	for i in range(num_points + 1):
		var angle = (i / float(num_points)) * TAU  # TAU = 2*PI (full circle)
		var x = cos(angle) * range_radius
		var y = sin(angle) * range_radius
		points.append(Vector2(x, y))
	
	range_indicator.points = PackedVector2Array(points)
