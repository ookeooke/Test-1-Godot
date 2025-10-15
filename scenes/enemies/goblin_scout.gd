extends "res://scripts/enemies/base_enemy.gd"

## Goblin Scout Enemy
## Basic ground enemy with low HP and speed.
## Stats are defined in goblin_stats.tres resource file.

func get_enemy_name() -> String:
	return "Goblin"

# Optional: Override _ready() for custom visual/audio setup
# func _ready():
# 	super._ready()  # IMPORTANT: Call base implementation
# 	$Sprite.texture = preload("res://assets/goblin.png")
# 	$AnimationPlayer.play("walk")

# Optional: Override for custom behavior
# Most basic enemies don't need any code beyond this!
