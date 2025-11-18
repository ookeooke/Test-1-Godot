extends Control
class_name DualPanelScreen

## DualPanelScreen - Mobile-first Equipment & Inventory UI
## Left panel: Equipment (fixed)
## Right panel: Inventory (fixed)
## Responsive design supporting 1920x1080 to 2340x1080+ resolutions
## Based on Diablo Immortal mobile UI patterns

signal screen_closed

@export var hero_id: String = "ranger"
@export var allow_during_waves: bool = false  # If false, only accessible between waves

# UI References
@onready var canvas_layer: CanvasLayer = $CanvasLayer if has_node("CanvasLayer") else null
@onready var background: ColorRect = $CanvasLayer/Background if has_node("CanvasLayer/Background") else null
@onready var main_container: VBoxContainer = $CanvasLayer/CenterContainer/MainContainer if has_node("CanvasLayer/CenterContainer/MainContainer") else null
@onready var left_panel: FlexiblePanel = $CanvasLayer/CenterContainer/MainContainer/PanelsContainer/LeftPanel if has_node("CanvasLayer/CenterContainer/MainContainer/PanelsContainer/LeftPanel") else null
@onready var right_panel: FlexiblePanel = $CanvasLayer/CenterContainer/MainContainer/PanelsContainer/RightPanel if has_node("CanvasLayer/CenterContainer/MainContainer/PanelsContainer/RightPanel") else null
@onready var close_button: Button = $CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/CloseButton if has_node("CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/CloseButton") else null
@onready var back_button: Button = $CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/BackButton if has_node("CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/BackButton") else null
@onready var title_label: Label = $CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/TitleLabel if has_node("CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/TitleLabel") else null
@onready var wave_status_label: Label = $CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/WaveStatusLabel if has_node("CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/WaveStatusLabel") else null

# State
var is_wave_active: bool = false
var is_transitioning: bool = false  # Prevent rapid toggling


func _ready():
	print("🔍 [DualPanelScreen] _ready() called - initial visible:", visible)

	# Add to group for easy lookup by InventoryView
	add_to_group("dual_panel_screen")

	# Set up as always-process (for pause compatibility)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect signals
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	# Set panel sides for identification
	if left_panel:
		left_panel.panel_side = "left"
	if right_panel:
		right_panel.panel_side = "right"

	# Update title
	if title_label:
		title_label.text = "Gear & Equipment"

	# Detect if we're in standalone mode (has back button) or overlay mode (has close button only)
	if back_button:
		# STANDALONE MODE - stay visible and enable panels
		print("🔍 [DualPanelScreen] Standalone mode detected - staying visible")
		visible = true
		if canvas_layer:
			canvas_layer.visible = true
		# Enable panels for interaction
		if left_panel:
			left_panel.set_process_mode(Node.PROCESS_MODE_INHERIT)
			left_panel.set_hero_id(hero_id)
			left_panel.refresh_current_view()
			print("🔍 [DualPanelScreen] Initialized left panel with hero_id: %s" % hero_id)
		if right_panel:
			right_panel.set_process_mode(Node.PROCESS_MODE_INHERIT)
			right_panel.set_hero_id(hero_id)
			right_panel.refresh_current_view()
			print("🔍 [DualPanelScreen] Initialized right panel with hero_id: %s" % hero_id)
	else:
		# OVERLAY MODE - hide by default until user opens it
		print("🔍 [DualPanelScreen] Overlay mode - hiding by default")
		visible = false
		hide()
		if canvas_layer:
			canvas_layer.visible = false
		# Defer panel loading
		if left_panel:
			left_panel.set_process_mode(Node.PROCESS_MODE_DISABLED)
		if right_panel:
			right_panel.set_process_mode(Node.PROCESS_MODE_DISABLED)

	# Setup responsive breakpoints
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()  # Initial check


func _input(event: InputEvent):
	# ESC KEY PRIORITY: This runs after level_controller and pause_menu
	# Only processes ESC if this panel is visible and game is not paused

	# Prevent rapid toggling
	if is_transitioning:
		return

	# Only allow ESC to close, not toggle_inventory to open
	# Opening should only be via button click
	if event.is_action_pressed("ui_cancel") and visible:
		hide_screen()
		get_viewport().set_input_as_handled()  # Consume to prevent further propagation


func _on_viewport_resized():
	"""Handle responsive layout based on viewport width"""
	if not left_panel or not right_panel or not main_container:
		return

	var width = get_viewport().get_visible_rect().size.x

	print("[DualPanelScreen] Viewport resized to: %d" % width)

	if width >= 2340:  # Wide phone (19.5:9 aspect ratio like modern flagships)
		main_container.custom_minimum_size = Vector2(1760, 900)  # 750 + 950 + 30 separation + margins
		left_panel.custom_minimum_size = Vector2(750, 0)
		right_panel.custom_minimum_size = Vector2(950, 0)
		print("[DualPanelScreen] Applied WIDE layout (2340+): Equipment 750px, Inventory 950px")

	elif width >= 1920:  # Standard (16:9 aspect ratio)
		main_container.custom_minimum_size = Vector2(1660, 900)  # 750 + 850 + 30 separation + margins
		left_panel.custom_minimum_size = Vector2(750, 0)
		right_panel.custom_minimum_size = Vector2(850, 0)
		print("[DualPanelScreen] Applied STANDARD layout (1920+): Equipment 750px, Inventory 850px")

	else:  # Tablet or smaller screens
		main_container.custom_minimum_size = Vector2(1360, 900)  # 625 + 675 + 30 separation + margins
		left_panel.custom_minimum_size = Vector2(625, 0)
		right_panel.custom_minimum_size = Vector2(675, 0)
		print("[DualPanelScreen] Applied COMPACT layout (<1920): Equipment 625px, Inventory 675px")

	# Force layout recalculation
	main_container.queue_sort()


func show_screen():
	"""Show the dual panel screen with fade-in animation"""
	print("🚨 [DualPanelScreen] show_screen() CALLED! Stack trace:")
	print_stack()

	# Check if we're allowed to open during waves
	if is_wave_active and not allow_during_waves:
		print("[DualPanelScreen] Cannot open during wave!")
		_show_wave_warning()
		return

	is_transitioning = true
	visible = true
	print("🚨 [DualPanelScreen] visible set to TRUE")

	# CRITICAL: Show the CanvasLayer (it bypasses parent visibility)
	if canvas_layer:
		canvas_layer.visible = true
		print("🚨 [DualPanelScreen] CanvasLayer shown")

	# Re-enable panels now that we're showing
	if left_panel:
		left_panel.set_process_mode(Node.PROCESS_MODE_ALWAYS)
		# Connect to equipment view's switch hero signal
		var equipment_view = left_panel.get_current_view()
		if equipment_view and equipment_view.has_signal("switch_hero_requested"):
			if not equipment_view.switch_hero_requested.is_connected(_on_switch_hero_requested):
				equipment_view.switch_hero_requested.connect(_on_switch_hero_requested)
	if right_panel:
		right_panel.set_process_mode(Node.PROCESS_MODE_ALWAYS)

	# Start with transparent background and scaled-down main container
	if background:
		background.modulate.a = 0.0
	if main_container:
		main_container.scale = Vector2(0.95, 0.95)
		main_container.modulate.a = 0.0

	# Set hero ID for both panels
	if left_panel:
		left_panel.set_hero_id(hero_id)
		left_panel.refresh_current_view()

	if right_panel:
		right_panel.set_hero_id(hero_id)
		right_panel.refresh_current_view()

	# Update wave status
	_update_wave_status()

	# Animate fade-in
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	if background:
		tween.tween_property(background, "modulate:a", 1.0, 0.2)

	if main_container:
		tween.tween_property(main_container, "scale", Vector2.ONE, 0.3)
		tween.tween_property(main_container, "modulate:a", 1.0, 0.2)

	print("[DualPanelScreen] Opened")

	# Allow input again after animation
	await tween.finished
	is_transitioning = false


func hide_screen():
	"""Hide the dual panel screen with fade-out animation"""
	is_transitioning = true

	# Animate fade-out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)

	if background:
		tween.tween_property(background, "modulate:a", 0.0, 0.15)

	if main_container:
		tween.tween_property(main_container, "scale", Vector2(0.95, 0.95), 0.2)
		tween.tween_property(main_container, "modulate:a", 0.0, 0.15)

	await tween.finished

	visible = false

	# CRITICAL: Hide the CanvasLayer
	if canvas_layer:
		canvas_layer.visible = false

	# Save preferences
	SaveManager.save_current_profile()

	screen_closed.emit()
	print("[DualPanelScreen] Closed")

	is_transitioning = false


func _on_close_button_pressed():
	hide_screen()

func _on_back_button_pressed():
	"""Return to world map (used in standalone scene mode)"""
	print("⬅️ [GearScreen] Back button pressed - returning to world map")
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")

func set_hero_id(p_hero_id: String):
	"""Set which hero to display"""
	hero_id = p_hero_id

	if left_panel:
		left_panel.set_hero_id(hero_id)

	if right_panel:
		right_panel.set_hero_id(hero_id)

	if title_label:
		title_label.text = "%s - Hero Management" % hero_id.capitalize()


func set_wave_active(active: bool):
	"""Update wave status (called by WaveManager)"""
	is_wave_active = active
	_update_wave_status()

	# Close screen if wave starts and we don't allow during waves
	if is_wave_active and not allow_during_waves and visible:
		hide_screen()
		print("[DualPanelScreen] Closed due to wave start")


func _update_wave_status():
	"""Update wave status label"""
	if not wave_status_label:
		return

	if is_wave_active:
		wave_status_label.text = "[WAVE ACTIVE]"
		wave_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		wave_status_label.text = "[Between Waves]"
		wave_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))


func _show_wave_warning():
	"""Show temporary warning that UI can't be opened during waves"""
	# Create a temporary warning popup
	var warning_panel = PanelContainer.new()
	warning_panel.position = Vector2(get_viewport().size.x / 2 - 200, 100)
	warning_panel.custom_minimum_size = Vector2(400, 80)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	warning_panel.add_child(margin)

	var label = Label.new()
	label.text = "⚠ Cannot access gear during combat!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	margin.add_child(label)

	# Add to scene
	add_child(warning_panel)

	# Animate in
	warning_panel.modulate.a = 0.0
	warning_panel.scale = Vector2(0.8, 0.8)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(warning_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(warning_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Shake animation
	await tween.finished
	var shake_tween = create_tween()
	shake_tween.tween_property(warning_panel, "position:x", warning_panel.position.x + 10, 0.05)
	shake_tween.tween_property(warning_panel, "position:x", warning_panel.position.x - 10, 0.05)
	shake_tween.tween_property(warning_panel, "position:x", warning_panel.position.x + 10, 0.05)
	shake_tween.tween_property(warning_panel, "position:x", warning_panel.position.x, 0.05)

	# Wait and fade out
	await get_tree().create_timer(1.5).timeout

	var fade_out = create_tween()
	fade_out.tween_property(warning_panel, "modulate:a", 0.0, 0.3)
	await fade_out.finished

	warning_panel.queue_free()


## Public API

func refresh_all_views():
	"""Refresh both panels"""
	if left_panel:
		left_panel.refresh_current_view()
	if right_panel:
		right_panel.refresh_current_view()


func get_left_panel() -> FlexiblePanel:
	"""Get the left panel"""
	return left_panel


func get_right_panel() -> FlexiblePanel:
	"""Get the right panel"""
	return right_panel


func _on_switch_hero_requested():
	"""Handle hero switching request from equipment view"""
	# TODO: Implement hero selection UI
	# For now, just show a simple message
	print("[DualPanelScreen] Switch hero requested - hero selection UI not yet implemented")

	# Future implementation will show a hero roster overlay
	# Player taps a hero card to switch
	# Updates both left and right panels with new hero_id


## Integration with WaveManager

func connect_to_wave_manager(wave_manager: Node):
	"""Connect to wave manager for wave status updates"""
	if wave_manager.has_signal("wave_started"):
		wave_manager.wave_started.connect(func(_wave_number): set_wave_active(true))

	if wave_manager.has_signal("wave_completed"):
		wave_manager.wave_completed.connect(func(): set_wave_active(false))

	if wave_manager.has_signal("all_waves_complete"):
		wave_manager.all_waves_complete.connect(func(): set_wave_active(false))

	print("[DualPanelScreen] Connected to WaveManager")
