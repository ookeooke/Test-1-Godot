extends Control

# ============================================
# CAMERA SETTINGS UI - For in-game settings menu
# ============================================

signal settings_changed()
signal settings_closed()

# References to UI elements (assign in editor)
@onready var edge_scroll_checkbox = $Panel/MarginContainer/VBoxContainer/EdgeScrollCheckbox
@onready var inertia_checkbox = $Panel/MarginContainer/VBoxContainer/InertiaCheckbox
@onready var shake_checkbox = $Panel/MarginContainer/VBoxContainer/ShakeCheckbox
@onready var keyboard_pan_checkbox = $Panel/MarginContainer/VBoxContainer/KeyboardPanCheckbox

@onready var edge_scroll_slider = $Panel/MarginContainer/VBoxContainer/EdgeScrollSpeedSlider
@onready var zoom_speed_slider = $Panel/MarginContainer/VBoxContainer/ZoomSpeedSlider
@onready var drag_sensitivity_slider = $Panel/MarginContainer/VBoxContainer/DragSensitivitySlider

@onready var edge_scroll_label = $Panel/MarginContainer/VBoxContainer/EdgeScrollSpeedLabel
@onready var zoom_speed_label = $Panel/MarginContainer/VBoxContainer/ZoomSpeedLabel
@onready var drag_sensitivity_label = $Panel/MarginContainer/VBoxContainer/DragSensitivityLabel

@onready var reset_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ResetButton
@onready var close_button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CloseButton

var camera: Camera2D

func _ready():
	# Find camera in scene
	camera = get_viewport().get_camera_2d()

	if not camera or not camera.has_method("set_edge_scroll_enabled"):
		push_error("Camera not found or doesn't support settings!")
		return

	# Connect UI signals
	if edge_scroll_checkbox:
		edge_scroll_checkbox.toggled.connect(_on_edge_scroll_toggled)
	if inertia_checkbox:
		inertia_checkbox.toggled.connect(_on_inertia_toggled)
	if shake_checkbox:
		shake_checkbox.toggled.connect(_on_shake_toggled)
	if keyboard_pan_checkbox:
		keyboard_pan_checkbox.toggled.connect(_on_keyboard_pan_toggled)

	if edge_scroll_slider:
		edge_scroll_slider.value_changed.connect(_on_edge_scroll_speed_changed)
	if zoom_speed_slider:
		zoom_speed_slider.value_changed.connect(_on_zoom_speed_changed)
	if drag_sensitivity_slider:
		drag_sensitivity_slider.value_changed.connect(_on_drag_sensitivity_changed)

	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	# Load current settings
	load_current_settings()

func load_current_settings():
	"""Load settings from camera"""
	if not camera:
		return

	var prefs = camera.user_prefs

	# Checkboxes
	if edge_scroll_checkbox:
		edge_scroll_checkbox.button_pressed = prefs.get("edge_scroll_enabled", true)
	if inertia_checkbox:
		inertia_checkbox.button_pressed = prefs.get("inertia_enabled", true)
	if shake_checkbox:
		shake_checkbox.button_pressed = prefs.get("shake_enabled", true)
	if keyboard_pan_checkbox:
		keyboard_pan_checkbox.button_pressed = prefs.get("keyboard_pan_enabled", true)

	# Sliders (0.5 to 2.0 range)
	if edge_scroll_slider:
		edge_scroll_slider.min_value = 0.5
		edge_scroll_slider.max_value = 2.0
		edge_scroll_slider.step = 0.1
		edge_scroll_slider.value = prefs.get("edge_scroll_speed_multiplier", 1.0)

	if zoom_speed_slider:
		zoom_speed_slider.min_value = 0.5
		zoom_speed_slider.max_value = 2.0
		zoom_speed_slider.step = 0.1
		zoom_speed_slider.value = prefs.get("zoom_speed_multiplier", 1.0)

	if drag_sensitivity_slider:
		drag_sensitivity_slider.min_value = 0.5
		drag_sensitivity_slider.max_value = 2.0
		drag_sensitivity_slider.step = 0.1
		drag_sensitivity_slider.value = prefs.get("drag_sensitivity", 1.0)

	update_labels()

func update_labels():
	"""Update value labels"""
	if edge_scroll_label and edge_scroll_slider:
		edge_scroll_label.text = "Edge Scroll Speed: %.1fx" % edge_scroll_slider.value

	if zoom_speed_label and zoom_speed_slider:
		zoom_speed_label.text = "Zoom Speed: %.1fx" % zoom_speed_slider.value

	if drag_sensitivity_label and drag_sensitivity_slider:
		drag_sensitivity_label.text = "Drag Sensitivity: %.1fx" % drag_sensitivity_slider.value

# ============================================
# SIGNAL CALLBACKS
# ============================================

func _on_edge_scroll_toggled(enabled: bool):
	if camera:
		camera.set_edge_scroll_enabled(enabled)
		settings_changed.emit()

func _on_inertia_toggled(enabled: bool):
	if camera:
		camera.set_inertia_enabled(enabled)
		settings_changed.emit()

func _on_shake_toggled(enabled: bool):
	if camera:
		camera.set_shake_enabled(enabled)
		settings_changed.emit()

func _on_keyboard_pan_toggled(enabled: bool):
	if camera:
		camera.user_prefs["keyboard_pan_enabled"] = enabled
		camera.save_user_preferences()
		settings_changed.emit()

func _on_edge_scroll_speed_changed(value: float):
	if camera:
		camera.set_edge_scroll_speed_multiplier(value)
		update_labels()
		settings_changed.emit()

func _on_zoom_speed_changed(value: float):
	if camera:
		camera.set_zoom_speed_multiplier(value)
		update_labels()
		settings_changed.emit()

func _on_drag_sensitivity_changed(value: float):
	if camera:
		camera.set_drag_sensitivity(value)
		update_labels()
		settings_changed.emit()

func _on_reset_pressed():
	"""Reset all settings to defaults"""
	if camera:
		camera.user_prefs = {
			"edge_scroll_enabled": true,
			"inertia_enabled": true,
			"shake_enabled": true,
			"keyboard_pan_enabled": true,
			"edge_scroll_speed_multiplier": 1.0,
			"zoom_speed_multiplier": 1.0,
			"drag_sensitivity": 1.0,
		}
		camera.load_user_preferences()
		camera.save_user_preferences()
		load_current_settings()
		settings_changed.emit()

func _on_close_pressed():
	"""Close settings"""
	settings_closed.emit()
	queue_free()

func _input(event):
	"""Close on ESC"""
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
