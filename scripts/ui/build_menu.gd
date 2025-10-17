extends Control

# ============================================
# BUILD MENU - Shows tower options
# ============================================

signal tower_selected(tower_scene)
signal menu_closed()

# Tower scenes
var archer_tower_scene = preload("res://scenes/towers/archer_tower.tscn")
var barracks_tower_scene = preload("res://scenes/towers/soldier_tower.tscn")

# Tower costs
var archer_cost = 100
var barracks_cost = 120

# References
@onready var archer_button = $PanelContainer/MarginContainer/HBoxContainer/ArcherButton
@onready var mage_button = $PanelContainer/MarginContainer/HBoxContainer/MageButton

func _ready():
	# IMPORTANT: Use PASS to participate in GUI system but not consume events
	# This allows buttons to receive clicks properly
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Make sure buttons can receive clicks
	archer_button.mouse_filter = Control.MOUSE_FILTER_STOP
	mage_button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Panel should also PASS to allow buttons inside to work
	$PanelContainer.mouse_filter = Control.MOUSE_FILTER_PASS

	# Connect button signals
	archer_button.pressed.connect(_on_archer_button_pressed)
	mage_button.pressed.connect(_on_mage_button_pressed)

	# DEBUG: Connect to gui_input to see if button receives ANY events
	archer_button.gui_input.connect(_on_archer_button_gui_input)

	# Update button text with costs
	archer_button.text = "Archer Tower\n" + str(archer_cost) + "g"
	mage_button.text = "Barracks\n" + str(barracks_cost) + "g"

	# Update button states based on gold
	update_button_states()

	# Connect to gold changes
	GameManager.gold_changed.connect(_on_gold_changed)

	print("Build menu ready!")
	print("  Archer button disabled: ", archer_button.disabled)
	print("  Archer button mouse_filter: ", archer_button.mouse_filter)
	print("  Menu position: ", global_position)
	print("  Menu size: ", size)

func _on_gold_changed(_new_amount):
	update_button_states()

func update_button_states():
	# Enable/disable buttons based on gold
	archer_button.disabled = GameManager.gold < archer_cost
	mage_button.disabled = GameManager.gold < barracks_cost

func _on_archer_button_gui_input(event):
	print("⚠️ Archer button received gui_input event: ", event)
	if event is InputEventMouseButton:
		print("  📍 Mouse button event")
		print("  Pressed: ", event.pressed)
		print("  Button index: ", event.button_index)
		print("  Position: ", event.position)
		print("  Global position: ", event.global_position)
		print("  Button global rect: ", archer_button.get_global_rect())

func _on_archer_button_pressed():
	print("🏹 Archer button pressed!")
	if GameManager.spend_gold(archer_cost):
		print("  ✓ Gold spent, emitting tower_selected signal")
		tower_selected.emit(archer_tower_scene)
	else:
		print("  ✗ Not enough gold for Archer Tower!")

func _on_mage_button_pressed():
	print("🏰 Barracks button pressed!")
	if GameManager.spend_gold(barracks_cost):
		print("  ✓ Gold spent, placing barracks tower")
		tower_selected.emit(barracks_tower_scene)
	else:
		print("  ✗ Not enough gold for Barracks!")
