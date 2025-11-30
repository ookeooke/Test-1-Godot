extends Button
class_name AbilityButton

## ============================================
## ABILITY BUTTON - In-battle active skill button
## ============================================
##
## Shows skill icon, cooldown timer, and handles activation
## Attached to hero portrait in battle UI

signal ability_activated(skill_id: String)

# ============================================
# PROPERTIES
# ============================================

@export var skill_id: String = "" # Which skill this button represents
@export var hotkey: String = "1" # Keyboard hotkey

# References
var skill_manager: HeroSkillManager = null
var skill_data: HeroSkillData = null

# UI Elements
var icon_rect: TextureRect
var cooldown_label: Label
var hotkey_label: Label
var cooldown_overlay: ColorRect # Visual overlay during cooldown
var progress_bar: ProgressBar # Radial or linear cooldown indicator

# State
var is_ready: bool = true
var cooldown_remaining: float = 0.0
var cooldown_total: float = 0.0

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Setup button
	custom_minimum_size = Vector2(60, 60)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Create UI hierarchy
	_setup_ui()

	# Connect button press
	pressed.connect(_on_pressed)

	# Listen for input
	set_process_input(true)

func _setup_ui():
	"""Create child UI elements"""

	# Container for icon
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(icon_rect)

	# Cooldown overlay (darkens button during cooldown)
	cooldown_overlay = ColorRect.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.color = Color(0, 0, 0, 0.6)
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.visible = false
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cooldown_overlay)

	# Cooldown timer label
	cooldown_label = Label.new()
	cooldown_label.name = "CooldownLabel"
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 20)
	cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	cooldown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cooldown_label.add_theme_constant_override("outline_size", 2)
	cooldown_label.visible = false
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cooldown_label)

	# Hotkey indicator
	hotkey_label = Label.new()
	hotkey_label.name = "HotkeyLabel"
	hotkey_label.text = hotkey
	hotkey_label.add_theme_font_size_override("font_size", 12)
	hotkey_label.add_theme_color_override("font_color", Color.WHITE)
	hotkey_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hotkey_label.add_theme_constant_override("outline_size", 1)
	hotkey_label.position = Vector2(2, 2)
	hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotkey_label)

	# Progress bar (optional - shows cooldown visually)
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.show_percentage = false
	progress_bar.max_value = 100
	progress_bar.value = 100
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	progress_bar.offset_top = -6
	add_child(progress_bar)

# ============================================
# SETUP
# ============================================

func setup(p_skill_id: String, p_skill_manager: HeroSkillManager, p_skill_data: HeroSkillData, p_hotkey: String = "1"):
	"""Initialize the button with skill data"""
	print("🔧 AbilityButton: setup() called for ", p_skill_id)
	if p_skill_manager == null:
		print("⚠️ AbilityButton: setup() received NULL skill_manager!")
	else:
		print("✅ AbilityButton: setup() received valid skill_manager: ", p_skill_manager)

	skill_id = p_skill_id
	skill_manager = p_skill_manager
	skill_data = p_skill_data
	hotkey = p_hotkey

	# Update hotkey display
	if hotkey_label:
		hotkey_label.text = hotkey

	# Set icon
	if skill_data and skill_data.icon and icon_rect:
		icon_rect.texture = skill_data.icon
	else:
		# Placeholder icon
		if icon_rect:
			icon_rect.modulate = Color(0.5, 0.5, 0.8)

	# Set tooltip
	if skill_data:
		var upgrade_level = skill_manager.get_skill_level(skill_id)
		tooltip_text = skill_data.get_display_description(upgrade_level)
		tooltip_text += "\n\nHotkey: " + hotkey

	# Connect to skill manager signals
	if skill_manager:
		if not skill_manager.cooldown_updated.is_connected(_on_cooldown_updated):
			skill_manager.cooldown_updated.connect(_on_cooldown_updated)
		if not skill_manager.skill_ready.is_connected(_on_skill_ready):
			skill_manager.skill_ready.connect(_on_skill_ready)

	# Initial state
	_update_visual_state()

	print("✅ AbilityButton setup complete: ", skill_id)

func _exit_tree():
	"""Disconnect signals when removed"""
	print("🗑️ AbilityButton: _exit_tree() called")
	if skill_manager:
		if skill_manager.cooldown_updated.is_connected(_on_cooldown_updated):
			skill_manager.cooldown_updated.disconnect(_on_cooldown_updated)
		if skill_manager.skill_ready.is_connected(_on_skill_ready):
			skill_manager.skill_ready.disconnect(_on_skill_ready)

# ============================================
# INPUT HANDLING
# ============================================

func _input(event: InputEvent):
	"""Handle hotkey presses"""
	if not visible or not is_ready:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Check if hotkey matches
		var key_string = OS.get_keycode_string(event.keycode)
		if key_string.to_upper() == hotkey.to_upper():
			_activate_ability()
			get_viewport().set_input_as_handled()

func _on_pressed():
	"""Handle button click"""
	print("🔘 AbilityButton: Clicked! (Skill ID: ", skill_id, ")")
	_activate_ability()

func _activate_ability():
	"""Try to activate the ability"""
	if not skill_manager:
		print("⚠️ AbilityButton: Cannot activate - Skill Manager is NULL")
		return

	if not is_ready:
		print("⚠️ AbilityButton: Cannot activate - Skill is NOT READY (Cooldown: ", cooldown_remaining, ")")
		return

	if skill_manager.activate_skill(skill_id):
		# Activation successful
		ability_activated.emit(skill_id)
		_update_visual_state()

		# Visual feedback
		_play_activation_animation()
	else:
		# Activation failed (probably on cooldown)
		_play_fail_animation()

# ============================================
# COOLDOWN TRACKING
# ============================================

func _on_cooldown_updated(updated_skill_id: String, remaining: float, total: float):
	"""Called when cooldown updates"""
	if updated_skill_id != skill_id:
		return

	cooldown_remaining = remaining
	cooldown_total = total
	is_ready = false

	# Update visuals
	_update_cooldown_display()

func _on_skill_ready(ready_skill_id: String):
	"""Called when skill comes off cooldown"""
	if ready_skill_id != skill_id:
		return

	is_ready = true
	cooldown_remaining = 0.0

	# Update visuals
	_update_visual_state()

	# Play ready animation
	_play_ready_animation()

# ============================================
# VISUAL UPDATES
# ============================================

func _update_visual_state():
	"""Update button appearance based on state"""
	if is_ready:
		# Ready state
		disabled = false
		modulate = Color.WHITE

		if cooldown_overlay:
			cooldown_overlay.visible = false
		if cooldown_label:
			cooldown_label.visible = false
		if progress_bar:
			progress_bar.value = 100
	else:
		# On cooldown
		disabled = true
		modulate = Color(0.7, 0.7, 0.7)

		if cooldown_overlay:
			cooldown_overlay.visible = true
		if cooldown_label:
			cooldown_label.visible = true

func _update_cooldown_display():
	"""Update cooldown timer and progress"""
	if cooldown_label:
		cooldown_label.text = str(ceil(cooldown_remaining))

	if progress_bar and cooldown_total > 0:
		var progress = 1.0 - (cooldown_remaining / cooldown_total)
		progress_bar.value = progress * 100.0

# ============================================
# ANIMATIONS
# ============================================

func _play_activation_animation():
	"""Visual feedback when ability is activated"""
	# Flash effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate", Color(0.7, 0.7, 0.7), 0.2)

	# Scale pulse
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _play_fail_animation():
	"""Visual feedback when activation fails"""
	# Red flash
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	# Shake
	var original_pos = position
	var shake_tween = create_tween()
	shake_tween.tween_property(self, "position", original_pos + Vector2(-3, 0), 0.05)
	shake_tween.tween_property(self, "position", original_pos + Vector2(3, 0), 0.05)
	shake_tween.tween_property(self, "position", original_pos, 0.05)

func _play_ready_animation():
	"""Visual feedback when ability comes off cooldown"""
	# Glow pulse
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.0), 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

	# Could also play a sound here
	print("✨ Ability ready: ", skill_id)
