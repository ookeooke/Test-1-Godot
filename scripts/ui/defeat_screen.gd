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
	level_select_button.pressed.connect(_on_level_select_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

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

	# Use centralized restart logic
	NavigationManager.restart_current_level()

func _on_level_select_pressed():
	print("DefeatScreen: Return to world map")
	# Use centralized navigation (fixes bug: was going to non-existent level_select.tscn)
	NavigationManager.go_to_world_map()

func _on_main_menu_pressed():
	print("DefeatScreen: Return to main menu")
	# Use centralized navigation
	NavigationManager.go_to_main_menu()
