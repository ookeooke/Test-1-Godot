extends "res://scripts/enemies/base_enemy.gd"

## Orc Warrior Enemy
## Tanky ground enemy with high HP and damage.

func _init():
	# Set orc-specific stats
	speed = 33.0  # PACING FIX: Reduced from 55 (-40% total: -25% KR pacing, -20% strategic slowdown)
	max_health = 150.0  # BALANCE FIX: Was 200 (16.7s TTK), now 150 (12.5s TTK - smoother difficulty curve)
	melee_damage = 10.0
	attack_cooldown = 1.0
	gold_reward = 20  # Increased from 16 (+25% gold rewards)
	life_damage = 2
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"
	armor = 0.20  # 20% damage reduction for tank enemy

	# Hit point for arrows (center to head area, like other humanoids)
	hit_point_offset = Vector2(0, -10)

func get_enemy_name() -> String:
	return "Orc"
