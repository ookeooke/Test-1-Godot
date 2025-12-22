extends "res://scripts/enemies/base_enemy.gd"

## Orc Warrior Enemy
## Tanky ground enemy with high HP and damage.

func _init():
	# Set orc-specific stats
	speed = 60.0 # KR1 "Medium" (0.8)
	max_health = 80.0 # KR1 Standard (80 HP)
	melee_damage = 8.0 # Moderate damage to soldiers
	attack_cooldown = 1.0
	gold_reward = 7 # KR1 Standard
	life_damage = 1 # Humans usually cost 1 life (Bosses cost more)
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"
	armor = 0.30 # 30% Armor (Light/Medium)

	# Hit point for arrows (center to head area, like other humanoids)
	hit_point_offset = Vector2(0, -10)

func get_enemy_name() -> String:
	return "Orc"
