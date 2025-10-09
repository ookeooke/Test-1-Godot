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
	# IMPORTANT: Set mouse filter to stop clicks from going through
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# CRITICAL: Make sure labels don't block button clicks
	archer_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mage_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
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
	
	print("Build menu ready!")
	



func _on_gold_changed(new_amount):
	update_button_states()

func update_button_states():
	# Enable/disable buttons based on gold
	archer_button.disabled = GameManager.gold < archer_cost
	mage_button.disabled = GameManager.gold < mage_cost or mage_tower_scene == null

func _on_archer_button_pressed():
	print("🏹 Archer button pressed!")
	if GameManager.spend_gold(archer_cost):
		print("  ✓ Gold spent, emitting tower_selected signal")
		tower_selected.emit(archer_tower_scene)
		# CHANGED: Don't queue_free() here - let PlacementManager close the menu
		# This prevents race condition where menu closes before tower is placed
		# queue_free()  # REMOVED
	else:
		print("  ✗ Not enough gold for Archer Tower!")

func _on_mage_button_pressed():
	if mage_tower_scene == null:
		print("Mage Tower not implemented yet!")
		return
	
	if GameManager.spend_gold(mage_cost):
		tower_selected.emit(mage_tower_scene)
		# CHANGED: Don't queue_free() here
		# queue_free()  # REMOVED
	else:
		print("Not enough gold for Mage Tower!")

func _input(event):
	# CHANGED: Only consume clicks OUTSIDE the menu
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Get the panel's global rect
			var panel_rect = $Panel.get_global_rect()
			var mouse_pos = get_global_mouse_position()
			
			# If clicked outside the panel, close menu
			if not panel_rect.has_point(mouse_pos):
				print("Clicked outside menu, closing")
				menu_closed.emit()
				get_viewport().set_input_as_handled()
				queue_free()
			# If clicked inside, DON'T consume the event - let buttons handle it!
