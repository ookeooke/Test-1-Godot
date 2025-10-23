extends "res://scripts/enemies/base_enemy.gd"

## Wolf Runner Enemy
## Fast ground enemy with low HP, high speed.

func _init():
	# Set wolf-specific stats
	speed = 101.0  # Reduced from 135 (-25% Kingdom Rush pacing)
	max_health = 80.0
	melee_damage = 5.0
	attack_cooldown = 0.7
	gold_reward = 7  # Increased from 6 (+17% gold rewards)
	life_damage = 1
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"
	armor = 0.10  # 10% damage reduction for fast enemy

	# Hit point for arrows (slightly forward/center on wolf)
	hit_point_offset = Vector2(0, -5)

func get_enemy_name() -> String:
	return "Wolf"
