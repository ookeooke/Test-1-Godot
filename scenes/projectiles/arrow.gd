extends Area2D

# ============================================
# ARROW PROJECTILE - Flies toward enemy
# ============================================

# PROJECTILE PROPERTIES
var speed = 500  # Pixels per second
var damage = 10  # Will be set by tower

# TARGETING
var target = null  # The enemy we're chasing
var direction = Vector2.ZERO  # Direction we're flying

# ============================================
# SETUP
# ============================================

func setup(enemy, projectile_damage):
	# Called by the tower when spawned
	target = enemy
	damage = projectile_damage
	
	# Calculate direction to target
	if target and is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
		# Point arrow in direction of movement
		rotation = direction.angle()

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Move toward target
	if target and is_instance_valid(target):
		# Update direction (enemy might have moved)
		direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()
	
	# Move forward
	global_position += direction * speed * delta
	
	# Check if we're off-screen (cleanup)
	if global_position.length() > 5000:
		queue_free()

# ============================================
# COLLISION
# ============================================

func _on_body_entered(body):
	# We hit something!
	if body.is_in_group("enemy"):
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("Arrow hit enemy for ", damage, " damage!")
		
		# Destroy this arrow
		queue_free()
