extends Control
## Settings Menu - UI Scale Control
##
## This menu provides user-adjustable UI scaling (50%-200%)
## Integrates with UIScaleManager and SaveManager

@onready var ui_scale_slider: HSlider = $Panel/VBox/UIScaleControl/Slider
@onready var ui_scale_label: Label = $Panel/VBox/UIScaleControl/ValueLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready():
	# Load saved UI scale preference (default 1.0 = 100%)
	var saved_multiplier = 1.0
	if SaveManager and SaveManager.has_method("get_setting"):
		saved_multiplier = SaveManager.get_setting("ui_scale_multiplier", 1.0)

	# Setup slider
	ui_scale_slider.min_value = 0.5  # 50%
	ui_scale_slider.max_value = 2.0  # 200%
	ui_scale_slider.step = 0.1       # 10% increments
	ui_scale_slider.value = saved_multiplier
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)

	# Setup close button
	close_button.pressed.connect(_on_close_pressed)

	# Update label to show current scale
	_update_label(saved_multiplier)

	# Apply the saved scale
	UIScaleManager.set_user_scale(saved_multiplier)


func _on_ui_scale_changed(value: float):
	"""Called when slider value changes"""
	# Apply scale change
	UIScaleManager.set_user_scale(value)

	# Update label
	_update_label(value)

	# Save preference (if SaveManager available)
	if SaveManager and SaveManager.has_method("save_setting"):
		SaveManager.save_setting("ui_scale_multiplier", value)


func _update_label(value: float):
	"""Update label to show percentage"""
	var percentage = int(value * 100)
	ui_scale_label.text = "%d%%" % percentage


func _on_close_pressed():
	"""Close settings menu"""
	queue_free()


## Optional: Handle ESC key to close
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
