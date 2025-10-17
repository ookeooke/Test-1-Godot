extends "res://scripts/enemies/base_enemy.gd"

## Troll Boss Enemy
## Boss enemy with very high HP, slow speed, high damage.

func _init():
	# Set troll boss-specific stats
	speed = 40.0
	max_health = 500.0
	melee_damage = 20.0
	attack_cooldown = 1.5
	gold_reward = 50
	life_damage = 3
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"

func get_enemy_name() -> String:
	return "Troll Boss"
