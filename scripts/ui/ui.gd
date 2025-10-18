extends CanvasLayer

# REFERENCES
@onready var gold_label = $TopBar/HBoxContainer/GoldLabel
@onready var wave_label = $TopBar/HBoxContainer/WaveLabel
@onready var lives_label = $TopBar/HBoxContainer/LivesLabel
@onready var speed_button = $TopBar/HBoxContainer/SpeedButton

# SPEED CONTROL
var current_speed: int = 1  # Current game speed (1, 2, or 4)

func _ready():
	# Connect to GameManager signals
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)

	# Connect speed button
	speed_button.pressed.connect(_on_speed_button_pressed)

	# Initialize display
	gold_label.text = "Gold: " + str(GameManager.gold)
	lives_label.text = "Lives: " + str(GameManager.lives)
	_update_speed_display()

func _on_gold_changed(new_amount):
	gold_label.text = "Gold: " + str(new_amount)

func _on_lives_changed(new_amount):
	lives_label.text = "Lives: " + str(new_amount)

	# Visual feedback when lives are low
	if new_amount <= 5:
		lives_label.add_theme_color_override("font_color", Color.RED)
	elif new_amount <= 10:
		lives_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		lives_label.add_theme_color_override("font_color", Color.WHITE)

# SPEED CONTROL FUNCTIONS
func _on_speed_button_pressed():
	# Cycle through speeds: 1 -> 2 -> 4 -> 1
	if current_speed == 1:
		current_speed = 2
	elif current_speed == 2:
		current_speed = 4
	else:
		current_speed = 1

	# Apply the speed to the engine
	Engine.time_scale = current_speed

	# Update button display
	_update_speed_display()

func _update_speed_display():
	speed_button.text = str(current_speed) + "x"
