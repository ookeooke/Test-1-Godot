extends "res://scripts/enemies/base_enemy.gd"

## Wolf Runner Enemy
## Fast ground enemy with low HP, high speed.
## Stats are defined in wolf_stats.tres resource file.

func get_enemy_name() -> String:
	return "Wolf"
