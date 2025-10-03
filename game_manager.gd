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
	# TODO: Show game over screen
