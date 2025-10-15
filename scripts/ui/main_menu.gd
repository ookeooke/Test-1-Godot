extends Control

# Main Menu - Entry point for the game
# Simple Kingdom Rush-style menu with basic buttons

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Check if we have any saved profiles
	_update_continue_button()

func _update_continue_button():
	var profiles = SaveManager.list_profiles()

	if profiles.is_empty():
		# No saves exist - disable continue button
		continue_button.disabled = true
		continue_button.tooltip_text = "No saved games found"
	else:
		# We have saves - enable continue button
		continue_button.disabled = false
		var last_profile = SaveManager.get_last_played_profile()
		continue_button.tooltip_text = "Continue as: " + last_profile

func _on_new_game_pressed():
	# Go to profile selection screen (shows 3 slots)
	get_tree().change_scene_to_file("res://scenes/ui/profile_select.tscn")

func _on_continue_pressed():
	# Load the last played profile and go straight to level select
	var last_profile = SaveManager.get_last_played_profile()

	if last_profile.is_empty():
		push_error("MainMenu: No profiles found!")
		return

	if SaveManager.load_profile(last_profile):
		# Go to level select
		get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")
	else:
		push_error("MainMenu: Failed to load profile: ", last_profile)

func _on_settings_pressed():
	# TODO: Implement settings screen in future
	pass

func _on_quit_pressed():
	get_tree().quit()
