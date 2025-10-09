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

# IMPORTANT: Prevent race condition - wait for mouse release before accepting close clicks
var mouse_was_released = false

# References
@onready var archer_button = $Panel/MarginContainer/HBoxContainer/ArcherButton
@onready var mage_button = $Panel/MarginContainer/HBoxContainer/MageButton
@onready var archer_cost_label = $Panel/MarginContainer/HBoxContainer/ArcherButton/CostLabel
@onready var mage_cost_label = $Panel/MarginContainer/HBoxContainer/MageButton/CostLabel

func _ready():
	# IMPORTANT: Set mouse filter to stop clicks from going through
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# CRITICAL FIX: Override the broken mouse_filter setting from .tscn
	# The .tscn file has mouse_filter = 2 (IGNORE) which blocks all clicks!
	archer_button.mouse_filter = Control.MOUSE_FILTER_STOP
	mage_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
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
	else:
		print("  ✗ Not enough gold for Archer Tower!")

func _on_mage_button_pressed():
	if mage_tower_scene == null:
		print("Mage Tower not implemented yet!")
		return
	
	if GameManager.spend_gold(mage_cost):
		tower_selected.emit(mage_tower_scene)
	else:
		print("Not enough gold for Mage Tower!")

func _input(event):
	if event is InputEventMouseButton:
		# Track when mouse is released - this marks the end of the "opening click"
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			mouse_was_released = true
			print("Mouse released - menu can now be closed by clicking outside")
			return
		
		# Only process clicks AFTER the mouse has been released once
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mouse_was_released:
			# Get the panel's global rect
			var panel_rect = $Panel.get_global_rect()
			var mouse_pos = get_global_mouse_position()
			
			# If clicked outside the panel, close menu
			if not panel_rect.has_point(mouse_pos):
				print("Clicked outside menu, closing")
				menu_closed.emit()
				get_viewport().set_input_as_handled()
				queue_free()
			# If clicked inside, the button will handle it
