extends Control

## ============================================
## HERO BUTTON - Kingdom Rush Style
## ============================================
##
## Displays hero portrait, health bar, and name in bottom-left corner.
## Click to select hero, then click world to move hero.
## Always same size regardless of camera zoom (CanvasLayer).

# REFERENCES
@onready var portrait = $Panel/VBoxContainer/Portrait
@onready var health_bar = $Panel/VBoxContainer/HealthBarContainer/HealthBar
@onready var hero_name_label = $Panel/VBoxContainer/HeroName
@onready var button = $Button
@onready var panel = $Panel

# STATE
var hero_reference = null  # Reference to the actual hero in the game world
var is_selected = false

## ============================================
## INITIALIZATION
## ============================================

func _ready():
	print("HeroButton ready")
	# Visual feedback setup
	_update_selection_visual()

	# Debug: Check if button node exists and is configured
	if button:
		print("  ✓ Button node found")
		print("    Button disabled: ", button.disabled)
		print("    Button flat: ", button.flat)
		print("    Button mouse_filter: ", button.mouse_filter)
		print("    Button size: ", button.size)
		print("    Button global position: ", button.global_position)

		# Add a manual GUI input handler as backup
		button.gui_input.connect(_on_button_gui_input)
		print("  ✓ Connected gui_input signal for debugging")
	else:
		print("  ⚠ Button node NOT found!")

## ============================================
## HERO CONNECTION
## ============================================

func set_hero(hero):
	"""Connect this button to a hero in the game world"""
	if hero_reference:
		# Disconnect from old hero
		if hero_reference.has_signal("health_changed"):
			if hero_reference.health_changed.is_connected(_on_hero_health_changed):
				hero_reference.health_changed.disconnect(_on_hero_health_changed)

	hero_reference = hero

	if hero_reference and is_instance_valid(hero_reference):
		# Update display
		_update_hero_info()

		# Connect to health changes (if signal exists, otherwise poll)
		# Note: We'll update health every frame in _process for now
		print("HeroButton connected to hero: ", hero_reference.name)

func _update_hero_info():
	"""Update button display with hero information"""
	if not hero_reference or not is_instance_valid(hero_reference):
		return

	# Update health bar
	if "current_health" in hero_reference and "max_health" in hero_reference:
		var health_percent = (hero_reference.current_health / hero_reference.max_health) * 100.0
		health_bar.value = health_percent

	# Update name
	if hero_reference.has_method("get_hero_name"):
		hero_name_label.text = hero_reference.get_hero_name()
	else:
		hero_name_label.text = hero_reference.name.to_upper()

	# Update portrait color (could be sprite later)
	# For now, use a color that represents the hero type
	portrait.color = Color(0.4, 0.6, 0.8, 1.0)  # Blue for ranger

## ============================================
## UPDATE LOOP
## ============================================

func _process(delta):
	# Update health bar every frame (simple approach)
	if hero_reference and is_instance_valid(hero_reference):
		if "current_health" in hero_reference and "max_health" in hero_reference:
			var health_percent = (hero_reference.current_health / hero_reference.max_health) * 100.0
			health_bar.value = health_percent

func _input(event: InputEvent):
	"""Fallback: Manual click detection if button signal doesn't work"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Get mouse position in local coordinates
		var local_mouse_pos = get_local_mouse_position()
		var button_rect = Rect2(Vector2.ZERO, size)

		if button_rect.has_point(local_mouse_pos):
			print("🖱️ Manual click detected on HeroButton area!")
			_on_button_pressed()
			get_viewport().set_input_as_handled()

## ============================================
## BUTTON INTERACTION
## ============================================

func _on_button_gui_input(event: InputEvent):
	"""Debug handler to see if button receives ANY input events"""
	if event is InputEventMouseButton:
		print("🖱️ Button received mouse event: ", event.button_index, " pressed: ", event.pressed)

func _on_button_pressed():
	"""Called when button is clicked"""
	print("🔘 HeroButton pressed signal triggered!")

	if not hero_reference:
		print("  ⚠ No hero reference set!")
		return

	if not is_instance_valid(hero_reference):
		print("  ⚠ Hero reference is invalid!")
		return

	print("  ✓ Hero reference valid: ", hero_reference.name)

	# Try to call the hero's select method directly
	if hero_reference.has_method("select"):
		print("  ✓ Calling hero.select()")
		hero_reference.select()

	# Also emit the hero_selected signal for HeroManager
	if hero_reference.has_signal("hero_selected"):
		print("  ✓ Emitting hero_selected signal")
		hero_reference.hero_selected.emit(hero_reference)
	else:
		print("  ⚠ Hero doesn't have hero_selected signal")

	# Update visual state
	set_selected(true)
	print("  ✓ Button visual state set to selected")

func set_selected(selected: bool):
	"""Update button visual state when hero is selected/deselected"""
	is_selected = selected
	_update_selection_visual()

func _update_selection_visual():
	"""Update visual appearance based on selection state"""
	if is_selected:
		# Highlighted border or glow
		panel.modulate = Color(1.3, 1.3, 1.0)  # Yellow tint
	else:
		# Normal appearance
		panel.modulate = Color(1.0, 1.0, 1.0)

## ============================================
## CALLBACKS
## ============================================

func _on_hero_health_changed(current_health, max_health):
	"""Called when hero health changes (if signal exists)"""
	var health_percent = (current_health / max_health) * 100.0
	health_bar.value = health_percent
