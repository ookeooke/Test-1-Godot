extends Node
## UI Scale Manager - Handles DPI-aware UI scaling for industry-standard responsive design
##
## This autoload calculates a dynamic scale factor based on screen resolution
## and applies it to the UI theme, ensuring consistent physical sizes across devices.
## Target: 44-48dp touch targets (7-9mm physical size)

## Signal emitted when UI scale changes (e.g., window resize)
signal scale_changed(new_scale: float)

## Design resolution baseline (1920x1080)
const DESIGN_WIDTH: int = 1920
const DESIGN_HEIGHT: int = 1080

## Scale factor constraints (prevents extreme scaling)
const MIN_SCALE: float = 0.5
const MAX_SCALE: float = 2.0

## Current UI scale factor (1.0 = 1080p baseline)
var ui_scale: float = 1.0

## Reference to the scaled theme (created at runtime)
var scaled_theme: Theme = null

## Base theme path
const BASE_THEME_PATH: String = "res://resources/themes/main_theme.tres"

## Resize debounce timer (prevents rapid theme reloads during window drag)
var resize_timer: Timer = null
const RESIZE_DEBOUNCE_MS: float = 0.1  # 100ms delay


func _ready() -> void:
	# Calculate initial scale
	calculate_ui_scale()

	# Load and apply scaled theme
	load_and_scale_theme()

	# Setup resize debounce timer
	resize_timer = Timer.new()
	resize_timer.one_shot = true
	resize_timer.wait_time = RESIZE_DEBOUNCE_MS
	resize_timer.timeout.connect(_on_resize_timeout)
	add_child(resize_timer)

	# Listen for window resize events (disconnect first to prevent duplicates)
	var tree = get_tree()
	if tree and tree.root:
		if tree.root.size_changed.is_connected(_on_window_resized):
			tree.root.size_changed.disconnect(_on_window_resized)
		tree.root.size_changed.connect(_on_window_resized)

	print("[UIScaleManager] Initialized with scale factor: %.2f" % ui_scale)


## Calculate UI scale factor based on current window size
func calculate_ui_scale() -> void:
	var window_size: Vector2i = DisplayServer.window_get_size()
	var screen_height: int = window_size.y

	# Validate screen height (prevent division issues)
	if screen_height <= 0:
		push_warning("[UIScaleManager] Invalid screen height: %d, using minimum scale" % screen_height)
		ui_scale = MIN_SCALE
		return

	# Calculate scale based on height (industry standard approach)
	var calculated_scale: float = float(screen_height) / float(DESIGN_HEIGHT)

	# Clamp to sensible bounds
	ui_scale = clampf(calculated_scale, MIN_SCALE, MAX_SCALE)

	print("[UIScaleManager] Screen: %dx%d, Scale: %.2f" % [window_size.x, window_size.y, ui_scale])


## Load base theme and create scaled version
func load_and_scale_theme() -> void:
	# Check if base theme exists
	if not ResourceLoader.exists(BASE_THEME_PATH):
		push_warning("[UIScaleManager] Base theme not found at: %s" % BASE_THEME_PATH)
		push_warning("[UIScaleManager] Skipping theme scaling. Create theme first, then reload.")
		return

	# Load base theme
	var base_theme: Theme = load(BASE_THEME_PATH)
	if not base_theme:
		push_error("[UIScaleManager] Failed to load base theme!")
		return

	# Duplicate theme for scaling (don't modify original)
	scaled_theme = base_theme.duplicate(true)

	# Scale all font sizes
	scale_theme_fonts(scaled_theme)

	# Scale all spacing/margins
	scale_theme_constants(scaled_theme)

	# Apply scaled theme to project (with null check)
	if scaled_theme == null:
		push_error("[UIScaleManager] Scaled theme is null, cannot apply to root")
		return

	var tree = get_tree()
	if tree == null or tree.root == null:
		push_error("[UIScaleManager] Scene tree or root is null")
		return

	tree.root.theme = scaled_theme

	print("[UIScaleManager] Theme loaded and scaled successfully")


## Scale all font sizes in theme by UI scale factor
func scale_theme_fonts(theme: Theme) -> void:
	if theme == null:
		push_error("[UIScaleManager] Theme is null in scale_theme_fonts()")
		return

	# Get all font size types
	var font_size_names: PackedStringArray = theme.get_font_size_list("")

	for size_name in font_size_names:
		var base_size: int = theme.get_font_size(size_name, "")
		var scaled_size: int = roundi(base_size * ui_scale)
		theme.set_font_size(size_name, "", scaled_size)

	# Scale for specific control types if defined
	var control_types: Array = ["Label", "Button", "LineEdit", "TextEdit", "RichTextLabel"]
	for control_type in control_types:
		var type_font_sizes: PackedStringArray = theme.get_font_size_list(control_type)
		for size_name in type_font_sizes:
			var base_size: int = theme.get_font_size(size_name, control_type)
			var scaled_size: int = roundi(base_size * ui_scale)
			theme.set_font_size(size_name, control_type, scaled_size)


## Scale all constant values (margins, spacing, etc.) in theme
func scale_theme_constants(theme: Theme) -> void:
	if theme == null:
		push_error("[UIScaleManager] Theme is null in scale_theme_constants()")
		return

	# Get all constant types
	var constant_names: PackedStringArray = theme.get_constant_list("")

	for const_name in constant_names:
		var base_value: int = theme.get_constant(const_name, "")
		var scaled_value: int = roundi(base_value * ui_scale)
		theme.set_constant(const_name, "", scaled_value)

	# Scale for specific control types
	var control_types: Array = ["MarginContainer", "VBoxContainer", "HBoxContainer", "BoxContainer", "Button", "Panel"]
	for control_type in control_types:
		var type_constants: PackedStringArray = theme.get_constant_list(control_type)
		for const_name in type_constants:
			var base_value: int = theme.get_constant(const_name, control_type)
			var scaled_value: int = roundi(base_value * ui_scale)
			theme.set_constant(const_name, control_type, scaled_value)


## Handle window resize events (debounced to prevent spam)
func _on_window_resized() -> void:
	# Restart debounce timer - only process after user stops resizing
	if resize_timer:
		resize_timer.stop()
		resize_timer.start()


## Process resize after debounce delay
func _on_resize_timeout() -> void:
	var old_scale: float = ui_scale
	calculate_ui_scale()

	# Only reload theme if scale changed significantly
	if abs(ui_scale - old_scale) > 0.01:
		load_and_scale_theme()
		scale_changed.emit(ui_scale)
		print("[UIScaleManager] Scale updated: %.2f -> %.2f" % [old_scale, ui_scale])


## Get scaled value for custom UI elements
## Use this when you need to manually scale sizes in scripts
func get_scaled_value(base_value: float) -> float:
	return base_value * ui_scale


## Get scaled size for custom UI elements
func get_scaled_size(base_size: Vector2) -> Vector2:
	return base_size * ui_scale


## Convert design pixels to physical dp (device-independent pixels)
## Assumes 96 DPI baseline (Windows standard)
func pixels_to_dp(pixels: float) -> float:
	return pixels * ui_scale


## Check if touch target meets minimum size requirement (44dp)
func is_valid_touch_target(size_pixels: Vector2) -> bool:
	var dp_size: Vector2 = Vector2(pixels_to_dp(size_pixels.x), pixels_to_dp(size_pixels.y))
	return dp_size.x >= 44.0 and dp_size.y >= 44.0
