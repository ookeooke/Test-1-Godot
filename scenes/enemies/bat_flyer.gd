extends "res://scripts/enemies/base_enemy.gd"

## Bat Flyer Enemy
## Flying enemy that ignores hero blocking.
## Stats are defined in bat_stats.tres resource file (can_be_blocked = false).

func get_enemy_name() -> String:
	return "Bat"

# Note: Flying behavior is handled by stats.can_be_blocked = false
# The base enemy class automatically prevents blocking when this is set.
# No override needed!
