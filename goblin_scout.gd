extends CharacterBody2D

# Signal to notify when this enemy is removed
signal enemy_died

var speed := 100.0
var max_health := 50.0
var current_health := 50.0

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D

func _ready():
	# Make sure enemy is on layer 1 and can be detected
	collision_layer = 1  # Enemy layer
	collision_mask = 0   # Doesn't collide with anything
	print("Goblin spawned at: ", global_position)

func _physics_process(delta):
	if path_follower:
		path_follower.progress += speed * delta
		if path_follower.progress_ratio >= 1.0:
			reached_end()

func reached_end():
	print("Goblin reached the end!")
	GameManager.lose_life(1)
	enemy_died.emit()
	queue_free()

func take_damage(amount: float):
	current_health -= amount
	print("Goblin took ", amount, " damage! HP: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("Goblin died!")
	GameManager.add_gold(5)
	enemy_died.emit()
	queue_free()

func set_path_follower(follower: PathFollow2D):
	path_follower = follower
	
