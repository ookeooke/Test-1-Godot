extends "res://scripts/enemies/base_enemy.gd"

## Goblin Scout Enemy
## Basic ground enemy with low HP and speed.

func _init():
	# Set goblin-specific stats
	speed = 45.0  # PACING FIX: Reduced from 75 (-40% total: -25% KR pacing, -20% strategic slowdown)
	max_health = 35.0  # BALANCE FIX: Was 50 (4.2s TTK), now 35 (2.9s TTK - matches KR1's 3.2s)
	melee_damage = 5.0
	attack_cooldown = 1.0
	gold_reward = 5  # Increased from 4 (+25% gold rewards)
	life_damage = 1
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"

	# Hit point for arrows (center/chest of goblin)
	hit_point_offset = Vector2(0, 0)

func get_enemy_name() -> String:
	return "Goblin"
