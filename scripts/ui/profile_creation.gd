extends Control

# Profile Creation - Kingdom Rush style profile setup
# Simple name input and create button

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var create_button: Button = $VBoxContainer/CreateButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _ready():
	# Connect signals
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_on_back_pressed)
	name_input.text_changed.connect(_on_name_changed)

	# Setup
	error_label.visible = false
	name_input.grab_focus()

	# Allow Enter key to create profile
	name_input.text_submitted.connect(_on_name_submitted)

func _on_name_changed(new_text: String):
	# Clear error when user types
	error_label.visible = false

	# Enable/disable create button based on input
	create_button.disabled = new_text.strip_edges().is_empty()

func _on_name_submitted(_text: String):
	# Enter key pressed in name field
	if not create_button.disabled:
		_on_create_pressed()

func _on_create_pressed():
	var profile_name = name_input.text.strip_edges()

	# Validate name
	if profile_name.is_empty():
		_show_error("Please enter a name")
		return

	if profile_name.length() < 2:
		_show_error("Name must be at least 2 characters")
		return

	if profile_name.length() > 20:
		_show_error("Name must be 20 characters or less")
		return

	# Check if profile already exists
	if SaveManager.profile_exists(profile_name):
		_show_error("Profile already exists")
		return

	# Create new profile
	print("ProfileCreation: Creating profile: ", profile_name)

	if SaveManager.create_new_profile(profile_name):
		print("ProfileCreation: Profile created successfully!")
		# Go to level select
		get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")
	else:
		_show_error("Failed to create profile")

func _on_back_pressed():
	# Go back to profile select screen
	get_tree().change_scene_to_file("res://scenes/ui/profile_select.tscn")

func _show_error(message: String):
	error_label.text = message
	error_label.visible = true
