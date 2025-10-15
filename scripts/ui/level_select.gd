extends Control

# Level Select - Map view with level buttons
# Kingdom Rush style - shows unlocked/locked levels

@onready var profile_label: Label = $TopBar/ProfileLabel
@onready var back_button: Button = $TopBar/BackButton
@onready var level_1_button: Button = $CenterContainer/VBoxContainer/Level1Button
@onready var level_2_button: Button = $CenterContainer/VBoxContainer/Level2Button
@onready var level_3_button: Button = $CenterContainer/VBoxContainer/Level3Button

func _ready():
	# Connect signals
	back_button.pressed.connect(_on_back_pressed)
	level_1_button.pressed.connect(_on_level_1_pressed)
	level_2_button.pressed.connect(_on_level_2_pressed)
	level_3_button.pressed.connect(_on_level_3_pressed)

	# Update UI with current profile
	_update_profile_display()
	_update_level_buttons()

func _update_profile_display():
	if SaveManager.has_current_profile():
		var profile_name = SaveManager.get_current_profile_name()
		profile_label.text = "Playing as: " + profile_name
	else:
		profile_label.text = "No Profile Loaded"

func _update_level_buttons():
	if not SaveManager.has_current_profile():
		# No profile - disable all levels
		level_1_button.disabled = true
		level_2_button.disabled = true
		level_3_button.disabled = true
		return

	# Level 1 is always unlocked
	level_1_button.disabled = false

	# Get stars for level 1
	var level_1_stars = SaveManager.get_level_stars("level_01")
	if level_1_stars > 0:
		level_1_button.text = "Level 1 ★" + str(level_1_stars)
	else:
		level_1_button.text = "Level 1"

	# Level 2 and 3 are locked (placeholders for future)
	level_2_button.disabled = true
	level_2_button.text = "Level 2 (LOCKED)"

	level_3_button.disabled = true
	level_3_button.text = "Level 3 (LOCKED)"

	# Future: Unlock level 2 if level 1 completed
	# if SaveManager.is_level_completed("level_01"):
	#     level_2_button.disabled = false
	#     level_2_button.text = "Level 2"

func _on_level_1_pressed():
	print("LevelSelect: Starting Level 1")
	# Load the level scene
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_level_2_pressed():
	print("LevelSelect: Level 2 pressed (not implemented)")
	# TODO: Implement level 2

func _on_level_3_pressed():
	print("LevelSelect: Level 3 pressed (not implemented)")
	# TODO: Implement level 3

func _on_back_pressed():
	print("LevelSelect: Back to main menu")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
