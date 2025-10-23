extends PanelContainer
class_name HeroCard

## HeroCard - Individual hero display in roster
## Shows hero portrait, name, level, class
## Emits signal when clicked for selection

signal hero_selected(hero_data: HeroData)
signal hero_right_clicked(hero_data: HeroData)

@export var hero_data: HeroData

# UI References (will be set up in scene)
@onready var portrait: TextureRect = $VBox/Portrait if has_node("VBox/Portrait") else null
@onready var name_label: Label = $VBox/NameLabel if has_node("VBox/NameLabel") else null
@onready var level_label: Label = $VBox/LevelLabel if has_node("VBox/LevelLabel") else null
@onready var class_label: Label = $VBox/ClassLabel if has_node("VBox/ClassLabel") else null
@onready var select_button: Button = $SelectButton if has_node("SelectButton") else null
@onready var locked_overlay: ColorRect = $LockedOverlay if has_node("LockedOverlay") else null
@onready var locked_label: Label = $LockedOverlay/LockedLabel if has_node("LockedOverlay/LockedLabel") else null

var is_selected: bool = false
var is_locked: bool = false


func _ready():
	# Connect button if it exists
	if select_button:
		select_button.pressed.connect(_on_select_pressed)
		select_button.gui_input.connect(_on_button_gui_input)

	# Apply UI scale for touch targets
	_apply_ui_scale()

	# Initial display
	if hero_data:
		refresh_display()


func _apply_ui_scale():
	"""Ensure minimum touch target size"""
	if UIScaleManager:
		var min_size = Vector2(120, 150) * UIScaleManager.ui_scale
		custom_minimum_size = min_size


func set_hero_data(data: HeroData):
	"""Set the hero to display"""
	hero_data = data

	# Check if locked
	if hero_data and HeroDatabase:
		is_locked = not HeroDatabase.is_hero_unlocked(hero_data.hero_id)

	refresh_display()


func refresh_display():
	"""Update all UI elements"""
	if not hero_data:
		return

	# Portrait
	if portrait:
		if hero_data.portrait:
			portrait.texture = hero_data.portrait
			portrait.modulate = Color.WHITE
		else:
			# Use color as fallback
			portrait.modulate = hero_data.hero_color

	# Name
	if name_label:
		name_label.text = hero_data.hero_name

	# Level
	if level_label:
		var level = hero_data.get_current_level()
		level_label.text = "Lv. %d" % level

	# Class
	if class_label:
		class_label.text = hero_data.get_class_name()
		# Color code by class
		class_label.add_theme_color_override("font_color", hero_data.get_class_color())

	# Locked state
	_update_locked_state()


func _update_locked_state():
	"""Update locked overlay"""
	if locked_overlay:
		locked_overlay.visible = is_locked

	if locked_label and is_locked:
		if hero_data:
			locked_label.text = "🔒 %d Gold" % hero_data.unlock_cost

	# Disable button if locked
	if select_button:
		select_button.disabled = is_locked


func set_selected(selected: bool):
	"""Update visual selection state"""
	is_selected = selected

	if is_selected:
		modulate = Color(1.3, 1.3, 1.0)  # Yellow tint
	else:
		modulate = Color.WHITE


func _on_select_pressed():
	"""Handle button press"""
	if hero_data and not is_locked:
		hero_selected.emit(hero_data)


func _on_button_gui_input(event: InputEvent):
	"""Handle right-click for context menu and touch input"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			if hero_data:
				hero_right_clicked.emit(hero_data)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		# Touch input is handled by button's normal pressed signal
		# This ensures touch works the same as left-click
		pass
