extends Control

# Defeat Screen - Shown when player loses (lives reach 0)
# Simple retry or quit options

@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton
@onready var level_select_button: Button = $Panel/VBoxContainer/LevelSelectButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton

func _ready():
	# Close any open menus (tower info, build menu, etc.)
	_close_existing_menus()

	# Connect signals
	retry_button.pressed.connect(_on_retry_pressed)
	level_select_button.pressed.connect(_on_main_menu_pressed)  # Swapped: middle button → main menu
	main_menu_button.pressed.connect(_on_level_select_pressed)  # Swapped: bottom button → world map

func _close_existing_menus():
	"""Close tower info menus and other UI that might be open"""
	# Find and close tower info menus
	var tower_info_menus = get_tree().get_nodes_in_group("tower_info_menu")
	for menu in tower_info_menus:
		if is_instance_valid(menu):
			menu.queue_free()

	# Find and close build menus
	var build_menus = get_tree().get_nodes_in_group("build_menu")
	for menu in build_menus:
		if is_instance_valid(menu):
			menu.queue_free()

	print("[DefeatScreen] Closed existing menus")

func _on_retry_pressed():
	print("DefeatScreen: Retry level")

	# Defensive check: verify we're in the right state
	assert(is_instance_valid(self), "DefeatScreen was freed before button handler!")

	# Unpause the game before restarting
	get_tree().paused = false

	# Use centralized restart logic (does this BEFORE freeing to avoid deadlock)
	if NavigationManager:
		NavigationManager.restart_current_level()
	else:
		push_error("[DefeatScreen] NavigationManager not found - cannot restart!")
		return

	# Free the canvas layer parent (after navigation starts)
	var canvas_layer = get_parent()
	if canvas_layer and canvas_layer is CanvasLayer:
		canvas_layer.queue_free()
	else:
		push_warning("[DefeatScreen] Parent is not a CanvasLayer - manual cleanup may be needed")

func _on_level_select_pressed():
	print("DefeatScreen: Return to world map")

	# Defensive check: verify we're in the right state
	assert(is_instance_valid(self), "DefeatScreen was freed before button handler!")

	# Unpause the game before navigation
	get_tree().paused = false

	# Clean up level state before exiting (fixes bug: autoloads kept dirty state)
	if RestartManager:
		RestartManager.cleanup_for_exit()
	else:
		push_error("[DefeatScreen] RestartManager not found - state may be dirty!")

	# Use centralized navigation (BEFORE freeing to avoid deadlock)
	if NavigationManager:
		NavigationManager.go_to_world_map()
	else:
		push_error("[DefeatScreen] NavigationManager not found - cannot navigate!")
		return

	# Free the canvas layer parent (after navigation starts)
	var canvas_layer = get_parent()
	if canvas_layer and canvas_layer is CanvasLayer:
		canvas_layer.queue_free()
	else:
		push_warning("[DefeatScreen] Parent is not a CanvasLayer - manual cleanup may be needed")

func _on_main_menu_pressed():
	print("DefeatScreen: Return to main menu")

	# Defensive check: verify we're in the right state
	assert(is_instance_valid(self), "DefeatScreen was freed before button handler!")

	# Unpause the game before navigation
	get_tree().paused = false

	# Clean up level state before exiting (fixes bug: autoloads kept dirty state)
	if RestartManager:
		RestartManager.cleanup_for_exit()
	else:
		push_error("[DefeatScreen] RestartManager not found - state may be dirty!")

	# Use centralized navigation (BEFORE freeing to avoid deadlock)
	if NavigationManager:
		NavigationManager.go_to_main_menu()
	else:
		push_error("[DefeatScreen] NavigationManager not found - cannot navigate!")
		return

	# Free the canvas layer parent (after navigation starts)
	var canvas_layer = get_parent()
	if canvas_layer and canvas_layer is CanvasLayer:
		canvas_layer.queue_free()
	else:
		push_warning("[DefeatScreen] Parent is not a CanvasLayer - manual cleanup may be needed")

func _exit_tree():
	# Ensure game is unpaused when defeat screen is removed
	# Safety net in case screen is removed unexpectedly
	get_tree().paused = false
	print("[DefeatScreen] Cleaned up and unpaused")
