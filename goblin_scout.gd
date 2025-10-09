extends CharacterBody2D

# Signal to notify when this enemy is removed
signal enemy_died

var speed := 100.0
var max_health := 50.0
var current_health := 50.0
var melee_damage := 5.0  # Damage to hero in melee

# BLOCKING SYSTEM
var is_blocked := false
var blocking_hero = null
var attack_timer := 0.0
var attack_cooldown := 1.0  # Attack hero every 1 second

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D

func _ready():
	# Make sure enemy is on layer 1 and can be detected
	collision_layer = 1  # Enemy layer
	collision_mask = 0   # Doesn't collide with anything
	print("Goblin spawned at: ", global_position)

func _physics_process(delta):
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		# We're fighting a hero - don't move, just attack
		handle_hero_combat(delta)
	elif path_follower:
		# Normal movement along path
		path_follower.progress += speed * delta
		if path_follower.progress_ratio >= 1.0:
			reached_end()

func handle_hero_combat(delta):
	# Attack hero periodically
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		if blocking_hero.has_method("take_damage"):
			blocking_hero.take_damage(melee_damage)
			print("Goblin attacked hero for ", melee_damage, " damage!")

func set_blocked_by_hero(hero):
	# Called by hero when enemy enters melee range
	is_blocked = true
	blocking_hero = hero
	attack_timer = 0.0
	print("Goblin is now blocked by hero!")

func unblock():
	# Called when hero dies or moves away
	is_blocked = false
	blocking_hero = null
	print("Goblin is no longer blocked!")

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
	
	# Unblock from hero if blocked
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		# Hero will detect we left their melee range
		pass
	
	enemy_died.emit()
	queue_free()

func set_path_follower(follower: PathFollow2D):
	path_follower = follower
