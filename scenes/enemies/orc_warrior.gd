extends "res://scripts/enemies/base_enemy.gd"

## Orc Warrior Enemy
## Tanky ground enemy with high HP and damage.

func _init():
	# Set orc-specific stats
	speed = 41.0  # Reduced from 55 (-25% Kingdom Rush pacing)
	max_health = 200.0
	melee_damage = 10.0
	attack_cooldown = 1.0
	gold_reward = 16  # Reduced from 20 (tight economy)
	life_damage = 2
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"

	# Hit point for arrows (center to head area, like other humanoids)
	hit_point_offset = Vector2(0, -10)

func get_enemy_name() -> String:
	return "Orc"
