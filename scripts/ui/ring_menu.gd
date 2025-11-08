extends Control

# ============================================
# RING MENU - Circular Tower Selection UI
# ============================================
# Phase 3B: Radial menu for tower placement
# Shows player's loadout towers in a circle when clicking tower spots

signal tower_selected(tower_id: String)
signal menu_closed()

# LAYOUT SETTINGS
const RING_RADIUS = 140.0  # Distance from center to buttons (increased for KR-style spacing)
const BUTTON_SIZE = 90.0   # Size of each tower button (larger like KR)
const ANIMATION_SPEED = 0.15  # How fast menu appears (seconds)

# VISUAL SETTINGS
const BACKGROUND_RADIUS = 170.0  # Size of background circle (adjusted for larger ring)
const BACKGROUND_COLOR = Color(0.08, 0.08, 0.12, 0.95)  # Darker, more opaque (KR-style)
const BORDER_COLOR = Color(0.8, 0.7, 0.4, 1.0)  # Golden border
const BORDER_WIDTH = 3.0

# STATE
var tower_spot_position: Vector2 = Vector2.ZERO  # Where the tower spot is
var available_towers: Array = []  # Tower IDs to show in menu
var is_open: bool = false

# REFERENCES
var buttons_container: Control
var tower_buttons: Array[Button] = []
var background_panel: Panel
var center_label: Label

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Create visual background
	_create_background()

	# Create center label
	_create_center_label()

	# Create container for buttons (centered on menu)
	buttons_container = Control.new()
	buttons_container.name = "ButtonsContainer"
	add_child(buttons_container)

	print("[RingMenu] Initialized")

# ============================================
# PUBLIC API
# ============================================

func open_at_position(spot_position: Vector2, tower_ids: Array):
	"""Open ring menu at a tower spot with given tower options

	Args:
		spot_position: World position of tower spot
		tower_ids: Array of tower_id strings to show (3-4 towers)
	"""
	if is_open:
		close()
		return

	tower_spot_position = spot_position
	available_towers = tower_ids

	# Position menu at tower spot
	global_position = spot_position

	# Clear old buttons
	_clear_buttons()

	# Create buttons in circle
	_create_ring_buttons()

	# Show with animation
	_show_animated()

	print("[RingMenu] Opened at %s with towers: %s" % [spot_position, tower_ids])

func close():
	"""Close the ring menu with animation"""
	if not is_open:
		return

	_hide_animated()
	menu_closed.emit()
	print("[RingMenu] Closed")

# ============================================
# VISUAL CREATION
# ============================================

func _create_background():
	"""Create circular background with border"""
	# We'll use _draw() for custom circle rendering
	# Just set up the base panel
	pass

func _create_center_label():
	"""Create center label for menu"""
	center_label = Label.new()
	center_label.name = "CenterLabel"
	center_label.text = "⚔️"  # Sword icon
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at center (0,0 relative to this Control)
	center_label.position = Vector2(-20, -20)  # Offset to center the label
	center_label.custom_minimum_size = Vector2(40, 40)

	# Style the label
	center_label.add_theme_font_size_override("font_size", 32)

	add_child(center_label)

func _draw():
	"""Custom draw for circular background and border"""
	if not is_open:
		return

	# Draw background circle
	draw_circle(Vector2.ZERO, BACKGROUND_RADIUS, BACKGROUND_COLOR)

	# Draw border circle (as multiple arc segments for smooth outline)
	draw_arc(Vector2.ZERO, BACKGROUND_RADIUS, 0, TAU, 64, BORDER_COLOR, BORDER_WIDTH, true)

# ============================================
# BUTTON CREATION
# ============================================

func _clear_buttons():
	"""Remove all existing tower buttons"""
	for button in tower_buttons:
		button.queue_free()
	tower_buttons.clear()

func _create_ring_buttons():
	"""Create tower buttons in circular layout"""
	var button_count = available_towers.size()

	if button_count == 0:
		push_warning("[RingMenu] No towers to display")
		return

	# Calculate angle between each button
	var angle_step = TAU / button_count  # TAU = 2*PI = full circle
	var start_angle = -PI / 2  # Start at top (-90 degrees)

	for i in range(button_count):
		var tower_id = available_towers[i]

		# Calculate position on circle
		var angle = start_angle + (i * angle_step)
		var offset = Vector2(
			cos(angle) * RING_RADIUS,
			sin(angle) * RING_RADIUS
		)

		# Create button
		var button = _create_tower_button(tower_id, offset)
		tower_buttons.append(button)

func _create_tower_button(tower_id: String, offset: Vector2) -> Button:
	"""Create a single tower button

	Args:
		tower_id: Tower to create button for
		offset: Position relative to menu center

	Returns:
		Button node
	"""
	var button = Button.new()
	button.name = "TowerButton_%s" % tower_id
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)

	# Position button (centered on offset point)
	button.position = offset - (Vector2(BUTTON_SIZE, BUTTON_SIZE) / 2)

	# Get tower data
	var tower_data = TowerData.get_tower_data(tower_id)
	var tower_name = tower_data.get("name", "???")
	var tower_icon = tower_data.get("icon", "?")
	var tower_cost = tower_data.get("build_cost", 0)

	# Set button text (icon + cost)
	button.text = "%s\n%dg" % [tower_icon, tower_cost]

	# Style the button
	_style_tower_button(button)

	# Store tower_id in metadata for callback
	button.set_meta("tower_id", tower_id)

	# Connect click signal
	button.pressed.connect(_on_tower_button_pressed.bind(tower_id))

	# Add to container
	buttons_container.add_child(button)

	return button

func _style_tower_button(button: Button):
	"""Apply visual styling to tower button (Kingdom Rush inspired)"""
	# Create StyleBox for normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.95)  # Darker, more opaque
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color(0.5, 0.4, 0.25, 1.0)  # Brown border
	style_normal.set_corner_radius_all(12)  # More rounded like KR

	# Create StyleBox for hover state
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.25, 0.3, 1.0)  # Lighter on hover
	style_hover.set_border_width_all(4)
	style_hover.border_color = Color(0.9, 0.8, 0.5, 1.0)  # Bright golden border on hover
	style_hover.set_corner_radius_all(12)

	# Create StyleBox for pressed state
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.1, 0.1, 0.15, 1.0)  # Even darker when pressed
	style_pressed.set_border_width_all(3)
	style_pressed.border_color = Color(1.0, 0.9, 0.6, 1.0)  # Very bright golden border
	style_pressed.set_corner_radius_all(12)

	# Apply styles
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Increase font size for icons (larger buttons = larger icons)
	button.add_theme_font_size_override("font_size", 24)

# ============================================
# CALLBACKS
# ============================================

func _on_tower_button_pressed(tower_id: String):
	"""Called when a tower button is clicked

	Args:
		tower_id: The tower that was selected
	"""
	print("[RingMenu] Tower selected: %s" % tower_id)
	tower_selected.emit(tower_id)
	close()

# ============================================
# ANIMATION
# ============================================

func _show_animated():
	"""Show menu with fade-in animation"""
	is_open = true
	visible = true

	# Trigger redraw for background circle
	queue_redraw()

	# Animate fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, ANIMATION_SPEED)

	# Animate buttons scaling in (stagger for nice effect)
	for i in range(tower_buttons.size()):
		var button = tower_buttons[i]
		button.scale = Vector2.ZERO

		var delay = i * 0.05  # Stagger each button by 50ms
		var button_tween = create_tween()
		button_tween.tween_property(button, "scale", Vector2.ONE, ANIMATION_SPEED).set_delay(delay)

func _hide_animated():
	"""Hide menu with fade-out animation"""
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_SPEED / 2)
	tween.tween_callback(func():
		visible = false
		is_open = false
		queue_redraw()  # Clear the drawn circle
	)

# ============================================
# INPUT HANDLING
# ============================================

func _unhandled_input(event: InputEvent):
	"""Close menu when clicking outside"""
	if not is_open:
		return

	# Check for mouse click or touch
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)

	if is_click or is_touch:
		# Check if click is outside menu area
		var click_pos = event.position
		var distance_from_center = click_pos.distance_to(global_position)

		# Close if click is outside ring radius + button radius
		if distance_from_center > RING_RADIUS + (BUTTON_SIZE / 2) + 20:
			close()
			get_viewport().set_input_as_handled()
