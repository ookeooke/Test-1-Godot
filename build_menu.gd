extends Control

# ============================================
# BUILD MENU - Shows tower options
# ============================================

signal tower_selected(tower_scene)
signal menu_closed()

# Tower scenes
var archer_tower_scene = preload("res://scenes/towers/archer_tower.tscn")
var mage_tower_scene = null  # Placeholder for second tower

# Tower costs
var archer_cost = 100
var mage_cost = 150

# References
@onready var archer_button = $Panel/MarginContainer/HBoxContainer/ArcherButton
@onready var mage_button = $Panel/MarginContainer/HBoxContainer/MageButton
@onready var archer_cost_label = $Panel/MarginContainer/HBoxContainer/ArcherButton/CostLabel
@onready var mage_cost_label = $Panel/MarginContainer/HBoxContainer/MageButton/CostLabel

func _ready():
	# Connect button signals
	archer_button.pressed.connect(_on_archer_button_pressed)
	mage_button.pressed.connect(_on_mage_button_pressed)
	
	# Update cost labels
	archer_cost_label.text = str(archer_cost) + "g"
	mage_cost_label.text = str(mage_cost) + "g"
	
	# Update button states based on gold
	update_button_states()
	
	# Connect to gold changes
	GameManager.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(new_amount):
	update_button_states()

func update_button_states():
	# Enable/disable buttons based on gold
	archer_button.disabled = GameManager.gold < archer_cost
	mage_button.disabled = GameManager.gold < mage_cost or mage_tower_scene == null

func _on_archer_button_pressed():
	if GameManager.spend_gold(archer_cost):
		tower_selected.emit(archer_tower_scene)
		queue_free()
	else:
		print("Not enough gold for Archer Tower!")

func _on_mage_button_pressed():
	if mage_tower_scene == null:
		print("Mage Tower not implemented yet!")
		return
	
	if GameManager.spend_gold(mage_cost):
		tower_selected.emit(mage_tower_scene)
		queue_free()
	else:
		print("Not enough gold for Mage Tower!")

func _input(event):
	# Close menu if player clicks outside
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not get_global_rect().has_point(get_global_mouse_position()):
				menu_closed.emit()
				queue_free()
