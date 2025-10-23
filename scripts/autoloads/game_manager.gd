extends Node

# ============================================
# GAME MANAGER - Global game state
# ============================================

# NOTE: Gold and lives are now managed by GameStateManager
# These properties delegate to GameStateManager for backward compatibility
var gold: int:
	get: return GameStateManager.gold if GameStateManager else 0
	set(value): if GameStateManager: GameStateManager.gold = value

var lives: int:
	get: return GameStateManager.lives if GameStateManager else 0
	set(value): if GameStateManager: GameStateManager.lives = value

# SIGNALS (forwarded from GameStateManager)
signal gold_changed(new_amount)
signal lives_changed(new_amount)
signal game_defeated()

# SCENES
var pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var defeat_screen_scene = preload("res://scenes/ui/defeat_screen.tscn")

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Forward GameStateManager signals to maintain backward compatibility
	if GameStateManager:
		GameStateManager.gold_changed.connect(_on_gold_changed)
		GameStateManager.lives_changed.connect(_on_lives_changed)

	print("GameManager initialized (delegating to GameStateManager)")

	# Give player some test items (TEMP FOR TESTING)
	_give_test_items()

func _on_gold_changed(new_amount: int):
	gold_changed.emit(new_amount)

func _on_lives_changed(new_amount: int):
	lives_changed.emit(new_amount)

# ============================================
# RESOURCE MANAGEMENT (delegates to GameStateManager)
# ============================================

func add_gold(amount: int):
	if GameStateManager:
		GameStateManager.add_gold(amount)

func spend_gold(amount: int) -> bool:
	if GameStateManager:
		return GameStateManager.spend_gold(amount)
	return false

func lose_life(amount: int = 1):
	if GameStateManager:
		GameStateManager.lose_life(amount)

func game_over():
	print("GAME OVER!")
	game_defeated.emit()

	# End balance tracking with defeat
	if BalanceTracker:
		BalanceTracker.end_run("defeat", 0)
		# Auto-save data on defeat
		if BalanceExporter:
			BalanceExporter.export_current_run()

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

# ============================================
# UI PREFERENCES
# ============================================

# User preferences for UI
var show_enemy_list_default = false  # Hidden by default

func set_enemy_list_preference(visible: bool):
	"""Save enemy list visibility preference"""
	show_enemy_list_default = visible
	print("[GameManager] Enemy list preference saved: %s" % ("visible" if visible else "hidden"))
	# TODO: Save to config file if needed

func get_enemy_list_preference() -> bool:
	"""Get enemy list visibility preference"""
	return show_enemy_list_default


# ============================================
# TEST ITEMS (TEMPORARY FOR DEVELOPMENT)
# ============================================

func _give_test_items():
	"""Give player some test items to demonstrate emoji icons"""
	# Wait for ItemDatabase to be ready
	await get_tree().create_timer(0.1).timeout

	if not InventoryManager:
		print("[GameManager] InventoryManager not found")
		return

	# Add fire bow with emoji icon
	InventoryManager.add_item("fire_bow", 1)

	# Add other existing items for comparison
	InventoryManager.add_item("basic_bow", 1)
	InventoryManager.add_item("leather_vest", 1)

	print("[GameManager] Test items added to inventory")
