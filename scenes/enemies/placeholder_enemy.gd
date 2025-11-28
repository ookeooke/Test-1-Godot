extends "res://scripts/enemies/base_enemy.gd"

@onready var token = $PlaceholderToken

func _ready():
	super._ready()
	
	# Configure token based on enemy name/type
	if token and token.has_method("setup"):
		token.setup(get_enemy_name())

func get_enemy_name() -> String:
	# This should be overridden by specific placeholder instances
	# or set via an exported variable if we want to be generic
	return "Tank"
