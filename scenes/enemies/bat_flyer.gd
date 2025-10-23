extends "res://scripts/enemies/base_enemy.gd"

## Bat Flyer Enemy
## Flying enemy that ignores hero blocking.

func _init():
	# Set bat-specific stats
	speed = 60.0  # Reduced from 80 (-25% Kingdom Rush pacing)
	max_health = 120.0
	melee_damage = 0.0  # Bats don't attack heroes
	attack_cooldown = 1.0
	gold_reward = 10  # Reduced from 12 (tight economy)
	life_damage = 1
	can_be_blocked = false  # FLYING - can't be blocked!
	melee_detection_range = 100.0
	death_shake = "None"

	# Hit point for arrows (center of flying bat)
	hit_point_offset = Vector2(0, -10)

func get_enemy_name() -> String:
	return "Bat"
