extends "res://scripts/enemies/base_enemy.gd"

## Goblin Scout Enemy
## Basic ground enemy with low HP and speed.

func _init():
	# Set goblin-specific stats
	speed = 100.0
	max_health = 50.0
	melee_damage = 5.0
	attack_cooldown = 1.0
	gold_reward = 5
	life_damage = 1
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"

	# Hit point for arrows (center/chest of goblin)
	hit_point_offset = Vector2(0, 0)

func get_enemy_name() -> String:
	return "Goblin"
