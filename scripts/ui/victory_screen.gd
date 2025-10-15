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
	# Connect signals
	next_level_button.pressed.connect(_on_next_level_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)

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
	# Reload current level
	get_tree().reload_current_scene()

func _on_level_select_pressed():
	print("VictoryScreen: Return to level select")
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

# Called from WaveManager to set stars earned
func set_stars(stars: int):
	stars_earned = clamp(stars, 0, 3)
	if is_node_ready():
		_update_display()
