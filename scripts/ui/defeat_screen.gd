extends Control

# Defeat Screen - Shown when player loses (lives reach 0)
# Simple retry or quit options

@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton
@onready var level_select_button: Button = $Panel/VBoxContainer/LevelSelectButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton

func _ready():
	# Connect signals
	retry_button.pressed.connect(_on_retry_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_retry_pressed():
	print("DefeatScreen: Retry level")
	# Reload current level
	get_tree().reload_current_scene()

func _on_level_select_pressed():
	print("DefeatScreen: Return to level select")
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_main_menu_pressed():
	print("DefeatScreen: Return to main menu")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
