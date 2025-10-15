extends Control

# Pause Menu - In-game pause overlay
# Triggered by ESC key during gameplay

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton

func _ready():
	# Connect signals
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	# Pause the game when this menu appears
	get_tree().paused = true

func _input(event):
	# Allow ESC to close pause menu
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()

func _on_resume_pressed():
	print("PauseMenu: Resume game")
	get_tree().paused = false
	queue_free()

func _on_restart_pressed():
	print("PauseMenu: Restart level")
	get_tree().paused = false

	# Reload current scene
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("PauseMenu: Return to main menu")
	get_tree().paused = false

	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _exit_tree():
	# Ensure game is unpaused when menu is removed
	get_tree().paused = false
