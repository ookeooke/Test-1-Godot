extends CanvasLayer

# REFERENCES
@onready var gold_label = $GoldLabel
@onready var wave_label = $WaveLabel

func _ready():
	# Connect to GameManager signals
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	
	# Initialize display
	gold_label.text = "Gold: " + str(GameManager.gold)

func _on_gold_changed(new_amount):
	gold_label.text = "Gold: " + str(new_amount)

func _on_lives_changed(new_amount):
	# We'll add lives UI later
	print("Lives changed to: ", new_amount)
	# TODO: Update lives label when we add it
