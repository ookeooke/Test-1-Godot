extends Control

# Victory Screen - Shown when player completes all waves
# Kingdom Rush style victory with stars and stats

@export var level_id: String = "level_01"
@export var stars_earned: int = 3

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var stars_label: Label = $Panel/VBoxContainer/StarsLabel
@onready var next_level_button: Button = $Panel/VBoxContainer/NextLevelButton
@onready var retry_button: Button = $Panel/VBoxContainer/RetryButton
@onready var level_select_button: Button = $Panel/VBoxContainer/LevelSelectButton

func _ready():
	print("VictoryScreen: _ready() called")

	# Verify nodes exist
	if not next_level_button:
		print("ERROR: next_level_button is null!")
	if not retry_button:
		print("ERROR: retry_button is null!")
	if not level_select_button:
		print("ERROR: level_select_button is null!")

	# Connect signals
	next_level_button.pressed.connect(_on_next_level_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	print("VictoryScreen: Button signals connected")

	# Update UI
	_update_display()

	# Save progress
	_save_completion()

func _update_display():
	# Show stars
	var star_text = ""
	for i in range(3):
		if i < stars_earned:
			star_text += "★ "
		else:
			star_text += "☆ "

	stars_label.text = star_text

	# Make stars green (victory color)
	stars_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))

	# Disable next level button (no level 2 yet)
	next_level_button.disabled = true
	next_level_button.text = "Next Level (Not Available)"

func _save_completion():
	# Mark level as complete in save system
	if SaveManager.has_current_profile():
		SaveManager.mark_level_complete(level_id, stars_earned)
		print("VictoryScreen: Level ", level_id, " completed with ", stars_earned, " stars")

func _on_next_level_pressed():
	print("VictoryScreen: Next level pressed")
	# TODO: Implement when level 2 exists
	# get_tree().change_scene_to_file("res://scenes/levels/level_02.tscn")

func _on_retry_pressed():
	print("VictoryScreen: Retry level")
	# Unpause the game
	get_tree().paused = false
	# Free the victory screen and its canvas layer parent, then reload
	var canvas_layer = get_parent()
	if canvas_layer:
		canvas_layer.queue_free()
	await get_tree().process_frame  # Wait for cleanup
	get_tree().reload_current_scene()

func _on_level_select_pressed():
	print("VictoryScreen: Return to level select")
	# Unpause the game
	get_tree().paused = false
	# Free the victory screen and its canvas layer parent, then change scene
	var canvas_layer = get_parent()
	if canvas_layer:
		canvas_layer.queue_free()
	await get_tree().process_frame  # Wait for cleanup
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

# Called from WaveManager to set stars earned
func set_stars(stars: int):
	stars_earned = clamp(stars, 0, 3)
	if is_node_ready():
		_update_display()
