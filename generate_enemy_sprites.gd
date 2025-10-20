extends Node

## Run this scene to generate enemy sprites
## Attach to a Node and run the scene, or call from editor

func _ready():
	print("=== Generating Enemy Sprites ===")

	var SpriteGen = load("res://scripts/utils/enemy_sprite_generator.gd")
	SpriteGen.generate_goblin_sprites()

	print("=== Generation Complete! ===")
	print("Check: assets/sprites/enemies/ folder")
	print("You can now replace these with your own 32x32 PNG sprites")

	# Wait a moment then quit
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
