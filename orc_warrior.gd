extends CharacterBody2D

# Signal to notify when this enemy is removed
signal enemy_died

var speed := 70.0
var max_health := 150.0
var current_health := 150.0

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D

func _physics_process(delta):
	if path_follower:
		path_follower.progress += speed * delta
		# no need to set global_position; you inherit it
		if path_follower.progress_ratio >= 1.0:
			reached_end()

func reached_end():
	print("ORK reached the end!")
	# Player loses a life
	GameManager.lose_life(2)
	enemy_died.emit()  # Notify the wave manager
	queue_free()

func take_damage(amount: float):
	current_health -= amount
	print("ORK took ", amount, " damage! HP: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("ORK died!")
	# Give player gold
	GameManager.add_gold(10)
	enemy_died.emit()  # Notify the wave manager
	queue_free()
	
	# Helper function for wave manager
func set_path_follower(follower: PathFollow2D):
	path_follower = follower
