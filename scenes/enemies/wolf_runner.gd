extends "res://scripts/enemies/base_enemy.gd"

## Wolf Runner Enemy
## Fast ground enemy with low HP, high speed.

func _init():
	# Set wolf-specific stats
	speed = 180.0
	max_health = 50.0
	melee_damage = 5.0
	attack_cooldown = 0.7
	gold_reward = 8
	life_damage = 1
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"

func get_enemy_name() -> String:
	return "Wolf"
