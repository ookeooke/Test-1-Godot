extends Control

# Profile Creation - Kingdom Rush style profile setup
# Simple name input and create button

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var create_button: Button = $VBoxContainer/CreateButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var error_label: Label = $VBoxContainer/ErrorLabel

var validation_timer: Timer

func _ready():
	# Connect signals
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_on_back_pressed)
	name_input.text_changed.connect(_on_name_changed)
	name_input.focus_exited.connect(_on_name_focus_exited)

	# Setup
	error_label.visible = false
	name_input.grab_focus()

	# Allow Enter key to create profile
	name_input.text_submitted.connect(_on_name_submitted)

	# Create polling timer for Android compatibility
	validation_timer = Timer.new()
	validation_timer.wait_time = 0.3
	validation_timer.timeout.connect(_validate_button_state)
	add_child(validation_timer)
	validation_timer.start()

	# Initial validation check with delay for any pre-filled text
	await get_tree().create_timer(0.1).timeout
	_validate_button_state()

func _input(_event):
	# WORKAROUND: For Godot web export on mobile browsers
	# text_changed signal doesn't fire reliably on Android Chrome/mobile browsers
	# This is a known issue: https://github.com/godotengine/godot/issues/64590
	# Using _input() as workaround to monitor LineEdit text changes
	if name_input:
		_validate_button_state()

func _validate_button_state():
	# Reusable function to check and update button state
	# Called from multiple places to ensure reliability on Android
	var current_text = name_input.text.strip_edges()
	create_button.disabled = current_text.is_empty()

func _on_name_changed(_new_text: String):
	# Clear error when user types
	error_label.visible = false

	# Validate button state
	_validate_button_state()

func _on_name_focus_exited():
	# Android virtual keyboard compatibility
	# Validate when user closes keyboard or taps away
	_validate_button_state()

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
		# Go to Hero Selection Screen (to choose starter hero)
		get_tree().change_scene_to_file("res://scenes/ui/hero_selection_screen.tscn")
	else:
		_show_error("Failed to create profile")

func _on_back_pressed():
	# Go back to profile select screen
	get_tree().change_scene_to_file("res://scenes/ui/profile_select.tscn")

func _show_error(message: String):
	error_label.text = message
	error_label.visible = true
