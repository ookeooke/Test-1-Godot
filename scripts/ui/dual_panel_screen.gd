extends Control
class_name DualPanelScreen

## DualPanelScreen - Professional dual-panel hero & items UI
## Player can customize what information appears in each panel
## Based on research from Diablo 4, WoW, Lost Ark, and Grim Dawn

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
@onready var title_label: Label = $CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/TitleLabel if has_node("CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/TitleLabel") else null
@onready var wave_status_label: Label = $CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/WaveStatusLabel if has_node("CanvasLayer/CenterContainer/MainContainer/HeaderBar/MarginContainer/HBox/WaveStatusLabel") else null

# State
var is_wave_active: bool = false
var is_transitioning: bool = false  # Prevent rapid toggling


func _ready():
	print("🔍 [DualPanelScreen] _ready() called - initial visible:", visible)

	# Set up as always-process (for pause compatibility)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# IMPORTANT: Hide by default - should only open when user clicks button
	visible = false
	hide()

	print("🔍 [DualPanelScreen] After hide() - visible:", visible)

	# Connect signals
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# Set panel sides for preference saving
	if left_panel:
		left_panel.panel_side = "left"
		# IMPORTANT: Defer loading to prevent auto-show
		left_panel.set_process_mode(Node.PROCESS_MODE_DISABLED)
	if right_panel:
		right_panel.panel_side = "right"
		# IMPORTANT: Defer loading to prevent auto-show
		right_panel.set_process_mode(Node.PROCESS_MODE_DISABLED)

	# Update title
	if title_label:
		title_label.text = "Hero Management"

	print("🔍 [DualPanelScreen] _ready() complete - final visible:", visible)

	# CRITICAL FIX: CanvasLayer bypasses parent visibility!
	# We need to hide the CanvasLayer itself, not just the Control parent
	if canvas_layer:
		canvas_layer.visible = false
		print("🔍 [DualPanelScreen] CanvasLayer hidden")

	# Double-check after a frame
	await get_tree().process_frame
	print("🔍 [DualPanelScreen] After 1 frame - visible:", visible, "canvas_layer.visible:", canvas_layer.visible if canvas_layer else "null")
	if visible or (canvas_layer and canvas_layer.visible):
		print("🚨🚨🚨 WARNING: Screen or CanvasLayer became visible!")
		print_stack()


func _input(event: InputEvent):
	# Prevent rapid toggling
	if is_transitioning:
		return

	# Only allow ESC to close, not toggle_inventory to open
	# Opening should only be via button click
	if event.is_action_pressed("ui_cancel") and visible:
		hide_screen()
		get_viewport().set_input_as_handled()


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
