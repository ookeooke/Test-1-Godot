extends CanvasLayer

# REFERENCES
@onready var gold_label = $TopBar/HBoxContainer/GoldLabel
@onready var wave_label = $TopBar/HBoxContainer/WaveLabel
@onready var lives_label = $TopBar/HBoxContainer/LivesLabel

func _ready():
	# Connect to GameManager signals
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)

	# Initialize display
	gold_label.text = "Gold: " + str(GameManager.gold)
	lives_label.text = "Lives: " + str(GameManager.lives)

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
