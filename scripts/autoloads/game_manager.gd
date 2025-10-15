extends Node

# ============================================
# GAME MANAGER - Global game state
# ============================================

# RESOURCES
var gold = 500  # Starting gold
var lives = 20  # Starting lives

# SIGNALS
signal gold_changed(new_amount)
signal lives_changed(new_amount)
signal game_defeated()

# SCENES
var pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var defeat_screen_scene = preload("res://scenes/ui/defeat_screen.tscn")

# ============================================
# RESOURCE MANAGEMENT
# ============================================

func add_gold(amount: int):
	gold += amount
	gold_changed.emit(gold)
	print("Gold: ", gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		print("Gold: ", gold)
		return true
	else:
		print("Not enough gold!")
		return false

func lose_life(amount: int = 1):
	lives -= amount
	lives_changed.emit(lives)
	print("Lives: ", lives)
	
	if lives <= 0:
		game_over()

func game_over():
	print("GAME OVER!")
	game_defeated.emit()

	# Show defeat screen
	_show_defeat_screen()

func _show_defeat_screen():
	# Get the current scene tree
	var root = get_tree().root

	# Instantiate defeat screen
	var defeat_screen = defeat_screen_scene.instantiate()
	root.add_child(defeat_screen)

	print("GameManager: Defeat screen shown")

func show_pause_menu():
	# Get the current scene tree
	var root = get_tree().root

	# Check if pause menu already exists
	if root.has_node("PauseMenu"):
		print("GameManager: Pause menu already open")
		return

	# Instantiate pause menu
	var pause_menu = pause_menu_scene.instantiate()
	root.add_child(pause_menu)

	print("GameManager: Pause menu shown")
