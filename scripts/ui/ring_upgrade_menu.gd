extends Control

# ============================================
# RING UPGRADE MENU - Circular Tower Upgrade UI
# ============================================
# Kingdom Rush-style radial menu for tower management
# Replaces vertical tower_info_menu with consistent ring design

signal upgrade_selected(tower)
signal sell_selected(tower)
signal menu_closed()
signal damage_path_chosen(tower)
signal range_path_chosen(tower)
signal targeting_mode_changed(tower, mode: int)
signal rally_mode_entered(tower)
signal enemy_list_toggled(visible: bool)

# LAYOUT SETTINGS (matches ring_menu.gd)
const RING_RADIUS = 140.0
const BUTTON_SIZE_LARGE = 100.0    # Upgrade/Path buttons
const BUTTON_SIZE_MEDIUM = 90.0    # Sell/Rally/Targeting buttons
const BUTTON_SIZE_SMALL = 70.0     # Targeting mode buttons (in submenu)
const BUTTON_SIZE_SUBMENU = 60.0   # Targeting submenu buttons (smaller)
const SUBMENU_RADIUS = 80.0        # Targeting submenu circle radius
const ANIMATION_SPEED = 0.15

# VISUAL SETTINGS
const BACKGROUND_RADIUS = 170.0
const BACKGROUND_COLOR = Color(0.08, 0.08, 0.12, 0.95)
const BORDER_COLOR = Color(0.8, 0.7, 0.4, 1.0)
const BORDER_WIDTH = 3.0

# CENTER PANEL
const CENTER_PANEL_SIZE = Vector2(180, 140)
const CENTER_BG_COLOR = Color(0.08, 0.08, 0.12, 0.95)
const CENTER_BORDER_COLOR = Color(0.8, 0.7, 0.4, 1.0)

# ENEMY LIST PANEL
const ENEMY_LIST_OFFSET = Vector2(200, 0)  # To right of ring
const ENEMY_LIST_SIZE = Vector2(180, 300)

# BUTTON COLORS
const COLOR_UPGRADE = Color(0.5, 1.0, 0.5)      # Green
const COLOR_SELL = Color(1.0, 0.5, 0.5)         # Red
const COLOR_DAMAGE_PATH = Color(1.2, 1.0, 0.8)  # Orange
const COLOR_RANGE_PATH = Color(0.8, 1.0, 1.2)   # Blue
const COLOR_RALLY = Color(1.0, 0.9, 0.3)        # Gold
const COLOR_TARGETING_ACTIVE = Color(0.5, 0.8, 1.0)    # Blue
const COLOR_TARGETING_INACTIVE = Color(0.6, 0.6, 0.6)  # Gray
const COLOR_DISABLED = Color(0.3, 0.3, 0.3)     # Dark gray
const COLOR_CONFIRM = Color(1.0, 1.0, 0.5)      # Yellow glow

# BUTTON EMOJIS
const EMOJI_UPGRADE = "⬆️"
const EMOJI_SELL = "💰"
const EMOJI_DAMAGE = "🔥"
const EMOJI_RANGE = "🎯"
const EMOJI_RALLY = "🚩"
const EMOJI_ENEMY_LIST = "👁️"
const EMOJI_FIRST = "1️⃣"
const EMOJI_LAST = "🔙"
const EMOJI_CLOSE = "📍"
const EMOJI_STRONG = "💪"
const EMOJI_WEAK = "🎲"

# TARGETING MODES (from tower.gd)
enum TargetingMode {
	FIRST = 0,
	LAST = 1,
	CLOSE = 2,
	STRONG = 3,
	WEAK = 4
}

# STATE
var tower: Node = null
var spot: Node = null
var is_open: bool = false
var is_garrison_tower: bool = false
var is_max_level: bool = false

# PREVIEW STATE (two-click system)
var preview_mode: String = ""  # "", "upgrade", "sell", "damage_path", "range_path", "targeting"
var preview_stats: Dictionary = {}

# TARGETING SUBMENU STATE
var targeting_submenu_open: bool = false
var submenu_buttons: Dictionary = {}  # button_id -> Button (for targeting submenu)
var submenu_container: Control = null

# REFERENCES
var buttons_container: Control
var action_buttons: Dictionary = {}  # button_id -> Button
var center_panel: Panel
var center_label: RichTextLabel
var enemy_list_panel: Panel = null
var enemy_list_visible: bool = false
var enemy_list_container: VBoxContainer = null  # Container for enemy labels
var enemy_update_timer: Timer = null  # Real-time enemy list updates

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Create visual background
	_create_background()

	# Create center stats panel
	_create_center_panel()

	# Create container for buttons (centered on menu)
	buttons_container = Control.new()
	buttons_container.name = "ButtonsContainer"
	add_child(buttons_container)

	# Create update timer for real-time enemy list
	enemy_update_timer = Timer.new()
	enemy_update_timer.name = "EnemyUpdateTimer"
	enemy_update_timer.wait_time = 0.1  # Update 10 times per second
	enemy_update_timer.timeout.connect(_update_enemy_list)
	add_child(enemy_update_timer)

	print("[RingUpgradeMenu] Initialized")

# ============================================
# PUBLIC API
# ============================================

func open_for_tower(spot_position: Vector2, tower_node: Node, spot_node: Node):
	"""Open ring upgrade menu for a tower

	Args:
		spot_position: Screen position to open menu at
		tower_node: Tower to manage
		spot_node: Tower spot reference
	"""
	if is_open:
		close()
		return

	tower = tower_node
	spot = spot_node

	# Detect tower type
	is_garrison_tower = tower.has_method("get_soldier_count")
	is_max_level = _is_tower_max_level()

	# DEBUG: Print tower state
	var tower_lv = tower.tower_level if "tower_level" in tower else -1
	var path = tower.upgrade_path if "upgrade_path" in tower else "???"
	var needs_path = false
	if tower.has_method("needs_path_choice"):
		needs_path = tower.needs_path_choice()

	print("[RingUpgradeMenu] Opening for tower:")
	print("  Name: %s" % tower.name)
	print("  Level: %d" % tower_lv)
	print("  Path: '%s'" % path)
	print("  is_garrison: %s" % is_garrison_tower)
	print("  is_max_level: %s" % is_max_level)
	print("  needs_path_choice(): %s" % needs_path)

	# Clear old buttons
	_clear_buttons()

	# Create buttons based on tower state
	_create_upgrade_ring_buttons()

	# Update center stats
	_update_center_stats()

	# Position menu at tower spot (AFTER button creation to avoid layout jumps)
	global_position = spot_position

	# Show with animation
	_show_animated()

	print("[RingUpgradeMenu] Opened for tower: %s (Lv%d)" % [tower.name, tower.tower_level])

func close():
	"""Close the ring upgrade menu with animation"""
	if not is_open:
		return

	# Hide enemy list if open
	if enemy_list_panel:
		enemy_list_panel.queue_free()
		enemy_list_panel = null
		enemy_list_visible = false

	# Cancel any preview
	_cancel_preview()

	_hide_animated()
	menu_closed.emit()
	print("[RingUpgradeMenu] Closed")

# ============================================
# VISUAL CREATION
# ============================================

func _create_background():
	"""Create circular background with border"""
	pass  # We use _draw() for custom rendering

func _create_center_panel():
	"""Create center stats panel"""
	# Panel background
	center_panel = Panel.new()
	center_panel.name = "CenterPanel"
	center_panel.custom_minimum_size = CENTER_PANEL_SIZE
	center_panel.position = -CENTER_PANEL_SIZE / 2  # Center it

	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = CENTER_BG_COLOR
	style.set_border_width_all(2)
	style.border_color = CENTER_BORDER_COLOR
	style.set_corner_radius_all(8)
	center_panel.add_theme_stylebox_override("panel", style)

	add_child(center_panel)

	# Rich text label for stats with BBCode
	center_label = RichTextLabel.new()
	center_label.name = "CenterLabel"
	center_label.bbcode_enabled = true
	center_label.fit_content = true
	center_label.scroll_active = false
	center_label.custom_minimum_size = CENTER_PANEL_SIZE - Vector2(10, 10)
	center_label.position = Vector2(5, 5)

	# Style text
	center_label.add_theme_font_size_override("normal_font_size", 11)
	center_label.add_theme_font_size_override("bold_font_size", 14)

	center_panel.add_child(center_label)

func _draw():
	"""Custom draw for circular background and border"""
	if not is_open:
		return

	# Draw background circle
	draw_circle(Vector2.ZERO, BACKGROUND_RADIUS, BACKGROUND_COLOR)

	# Draw border circle
	draw_arc(Vector2.ZERO, BACKGROUND_RADIUS, 0, TAU, 64, BORDER_COLOR, BORDER_WIDTH, true)

# ============================================
# BUTTON LAYOUT SYSTEM
# ============================================

func _calculate_button_positions() -> Dictionary:
	"""Calculate button positions based on tower state

	Returns:
		Dictionary mapping button_id -> {angle: float, size: float, emoji: String, color: Color}
	"""
	var positions = {}

	# DEBUG: Check path choice status
	if tower and tower.has_method("needs_path_choice"):
		var needs_path = tower.needs_path_choice()
		var tower_lv = tower.tower_level if "tower_level" in tower else -1
		var path = tower.upgrade_path if "upgrade_path" in tower else "???"
		print("[RingUpgradeMenu] Path choice check: Level=%d, Path='%s', needs_path_choice()=%s" % [tower_lv, path, needs_path])

	if is_garrison_tower:
		# GARRISON LAYOUT: 4 buttons
		# 12:00 - Upgrade/Max
		# 2:00 - Rally Point
		# 5:00 - Enemy List
		# 6:00 - Sell
		positions["upgrade"] = {
			"angle": -PI/2, "size": BUTTON_SIZE_LARGE,
			"emoji": EMOJI_UPGRADE if not is_max_level else "⭐",
			"color": COLOR_UPGRADE if not is_max_level else COLOR_DISABLED
		}
		positions["rally"] = {
			"angle": -PI/2 + PI/3, "size": BUTTON_SIZE_MEDIUM,
			"emoji": EMOJI_RALLY, "color": COLOR_RALLY
		}
		positions["enemy_list"] = {
			"angle": PI/6, "size": BUTTON_SIZE_SMALL,
			"emoji": EMOJI_ENEMY_LIST, "color": COLOR_TARGETING_INACTIVE
		}
		positions["sell"] = {
			"angle": PI/2, "size": BUTTON_SIZE_MEDIUM,
			"emoji": EMOJI_SELL, "color": COLOR_SELL
		}

	elif tower.has_method("needs_path_choice") and tower.needs_path_choice():
		# PATH CHOICE LAYOUT: 5 buttons (DYNAMIC based on tower type)
		# 12:00 - Path 1 (damage/cannon/inferno/defense)
		# 3:00 - Targeting (collapsed)
		# 6:00 - Sell
		# 8:00 - Path 2 (range/mortar/frost/offense)
		# 9:00 - Enemy List

		# Get path choices from tower (dynamic per tower type)
		var path_choices = []
		if tower.has_method("get_path_choices"):
			path_choices = tower.get_path_choices()

		# Add path buttons dynamically
		if path_choices.size() >= 2:
			# First path (top position)
			positions[path_choices[0]["id"]] = {
				"angle": -PI/2, "size": BUTTON_SIZE_LARGE,
				"emoji": path_choices[0]["emoji"], "color": COLOR_DAMAGE_PATH
			}
			# Second path (bottom-left position)
			positions[path_choices[1]["id"]] = {
				"angle": PI - PI/4, "size": BUTTON_SIZE_LARGE,
				"emoji": path_choices[1]["emoji"], "color": COLOR_RANGE_PATH
			}
		else:
			# Fallback to hardcoded for backwards compatibility
			positions["damage_path"] = {
				"angle": -PI/2, "size": BUTTON_SIZE_LARGE,
				"emoji": EMOJI_DAMAGE, "color": COLOR_DAMAGE_PATH
			}
			positions["range_path"] = {
				"angle": PI - PI/4, "size": BUTTON_SIZE_LARGE,
				"emoji": EMOJI_RANGE, "color": COLOR_RANGE_PATH
			}

		positions["targeting"] = {
			"angle": 0, "size": BUTTON_SIZE_MEDIUM,
			"emoji": "🎯", "color": COLOR_TARGETING_ACTIVE
		}
		positions["sell"] = {
			"angle": PI/2, "size": BUTTON_SIZE_MEDIUM,
			"emoji": EMOJI_SELL, "color": COLOR_SELL
		}
		positions["enemy_list"] = {
			"angle": PI, "size": BUTTON_SIZE_MEDIUM,
			"emoji": EMOJI_ENEMY_LIST, "color": COLOR_TARGETING_INACTIVE
		}

	else:
		# STANDARD LAYOUT: 4 buttons (SIMPLIFIED)
		# 12:00 - Upgrade/Max
		# 3:00 - Targeting (collapsed)
		# 6:00 - Sell
		# 9:00 - Enemy List
		positions["upgrade"] = {
			"angle": -PI/2, "size": BUTTON_SIZE_LARGE,
			"emoji": EMOJI_UPGRADE if not is_max_level else "⭐",
			"color": COLOR_UPGRADE if not is_max_level else COLOR_DISABLED
		}
		positions["targeting"] = {
			"angle": 0, "size": BUTTON_SIZE_MEDIUM,
			"emoji": "🎯", "color": COLOR_TARGETING_ACTIVE
		}
		positions["sell"] = {
			"angle": PI/2, "size": BUTTON_SIZE_MEDIUM,
			"emoji": EMOJI_SELL, "color": COLOR_SELL
		}
		positions["enemy_list"] = {
			"angle": PI, "size": BUTTON_SIZE_MEDIUM,
			"emoji": EMOJI_ENEMY_LIST, "color": COLOR_TARGETING_INACTIVE
		}

	return positions

func _get_targeting_color(mode: int) -> Color:
	"""Get color for targeting mode button based on tower's current mode"""
	if tower and tower.has_method("get_targeting_mode"):
		if tower.get_targeting_mode() == mode:
			return COLOR_TARGETING_ACTIVE
	return COLOR_TARGETING_INACTIVE

# ============================================
# BUTTON CREATION
# ============================================

func _clear_buttons():
	"""Remove all existing buttons"""
	for button_id in action_buttons.keys():
		var button = action_buttons[button_id]
		button.queue_free()
	action_buttons.clear()

func _create_upgrade_ring_buttons():
	"""Create tower upgrade buttons in circular layout"""
	var button_positions = _calculate_button_positions()

	for button_id in button_positions.keys():
		var btn_data = button_positions[button_id]
		var button = _create_action_button(button_id, btn_data)
		action_buttons[button_id] = button

func _create_action_button(button_id: String, btn_data: Dictionary) -> Button:
	"""Create a single action button

	Args:
		button_id: ID of button (e.g., "upgrade", "sell", "first")
		btn_data: {angle, size, emoji, color}

	Returns:
		Button node
	"""
	var button = Button.new()
	button.name = "ActionButton_%s" % button_id
	button.custom_minimum_size = Vector2(btn_data["size"], btn_data["size"])

	# Calculate position on circle
	var angle = btn_data["angle"]
	var offset = Vector2(
		cos(angle) * RING_RADIUS,
		sin(angle) * RING_RADIUS
	)

	# Position button (centered on offset point)
	button.position = offset - (Vector2(btn_data["size"], btn_data["size"]) / 2)

	# Set button text
	button.text = _get_button_text(button_id, btn_data["emoji"])

	# Style the button
	_style_action_button(button, btn_data["color"], button_id)

	# Store button_id in metadata
	button.set_meta("button_id", button_id)

	# Connect click signal
	button.pressed.connect(_on_action_button_pressed.bind(button_id))

	# Add to container
	buttons_container.add_child(button)

	return button

func _get_button_text(button_id: String, emoji: String) -> String:
	"""Get button text with emoji and additional info"""
	match button_id:
		"upgrade":
			if is_max_level:
				return "%s\nMAX\nLEVEL" % emoji
			else:
				var cost = _get_upgrade_cost()
				var next_level = tower.tower_level + 1
				return "%s\nLv%d\n%dg" % [emoji, next_level, cost]
		"sell":
			var sell_value = _calculate_sell_value()
			return "%s\nSELL\n%dg" % [emoji, sell_value]
		"damage_path":
			var cost = _get_upgrade_cost()
			return "%s\nDAMAGE\n%dg" % [emoji, cost]
		"range_path":
			var cost = _get_upgrade_cost()
			return "%s\nRANGE\n%dg" % [emoji, cost]
		"rally":
			return "%s\nRALLY\nPOINT" % emoji
		"enemy_list":
			return "%s\nENEMY\nLIST" % emoji
		"targeting":
			# Show current targeting mode
			var mode_name = _get_current_targeting_mode_name()
			return "%s\n%s" % [emoji, mode_name]
		_:
			# Targeting modes in submenu - just emoji
			return emoji

func _style_action_button(button: Button, tint_color: Color, button_id: String):
	"""Apply visual styling to action button"""
	# Create StyleBox for normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.95) * tint_color
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color(0.5, 0.4, 0.25, 1.0)
	style_normal.set_corner_radius_all(12)

	# Create StyleBox for hover state
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.25, 0.3, 1.0) * tint_color
	style_hover.set_border_width_all(4)
	style_hover.border_color = Color(0.9, 0.8, 0.5, 1.0)
	style_hover.set_corner_radius_all(12)

	# Create StyleBox for pressed state
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.1, 0.1, 0.15, 1.0) * tint_color
	style_pressed.set_border_width_all(3)
	style_pressed.border_color = Color(1.0, 0.9, 0.6, 1.0)
	style_pressed.set_corner_radius_all(12)

	# Apply styles
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Adjust font size based on button size
	if button_id in ["upgrade", "damage_path", "range_path"]:
		button.add_theme_font_size_override("font_size", 16)
	elif button_id in ["sell", "rally"]:
		button.add_theme_font_size_override("font_size", 14)
	else:
		button.add_theme_font_size_override("font_size", 24)  # Big emoji for targeting

	# Disable button if max level
	if button_id == "upgrade" and is_max_level:
		button.disabled = true

# ============================================
# CENTER STATS PANEL
# ============================================

func _update_center_stats():
	"""Update center stats panel with tower information"""
	if not tower or not center_label:
		return

	var text = "[center]"

	# Tower name and level
	var tower_name = tower.name if "name" in tower else "Tower"
	var level_text = "Lv%d" % tower.tower_level

	# Add path info if chosen
	if tower.has_method("get_upgrade_path") and tower.get_upgrade_path() != "":
		var path = tower.get_upgrade_path()
		level_text += "\n[color=orange]%s[/color]" % path.capitalize()

	text += "[b]%s %s[/b]\n\n" % [tower_name.replace("Tower", ""), level_text]

	# Stats
	if preview_mode != "":
		# Show preview stats with green bonuses
		text += _get_preview_stats_text()
	else:
		# Show normal stats
		text += _get_normal_stats_text()

	text += "[/center]"

	center_label.text = text

func _get_normal_stats_text() -> String:
	"""Get normal stats text (no preview)"""
	var text = ""

	if tower.has_method("get_stat_damage"):
		text += "DMG: %d\n" % int(tower.get_stat_damage())
	if tower.has_method("get_stat_attack_speed"):
		text += "AS: %.1f/s\n" % tower.get_stat_attack_speed()
	if tower.has_method("get_stat_range"):
		text += "Range: %d\n" % int(tower.get_stat_range())

	# Garrison-specific
	if is_garrison_tower and tower.has_method("get_soldier_count"):
		text += "Squad: %d/%d" % [tower.get_soldier_count(), tower.max_soldiers]

	return text

func _get_preview_stats_text() -> String:
	"""Get preview stats text with green bonuses"""
	var text = ""

	# This will be populated by _enter_preview_mode()
	if preview_stats.has("damage"):
		var bonus = preview_stats.get("damage_bonus", 0)
		text += "DMG: %d" % preview_stats["damage"]
		if bonus > 0:
			text += " [color=green]+%d[/color]" % bonus
		text += "\n"

	if preview_stats.has("attack_speed"):
		var bonus = preview_stats.get("attack_speed_bonus", 0)
		text += "AS: %.1f/s" % preview_stats["attack_speed"]
		if bonus > 0:
			text += " [color=green]+%.1f[/color]" % bonus
		text += "\n"

	if preview_stats.has("range"):
		var bonus = preview_stats.get("range_bonus", 0)
		text += "Range: %d" % preview_stats["range"]
		if bonus > 0:
			text += " [color=green]+%d[/color]" % bonus
		text += "\n"

	return text

# ============================================
# TWO-CLICK SYSTEM
# ============================================

func _on_action_button_pressed(button_id: String):
	"""Handle button click with two-click confirmation

	Args:
		button_id: ID of clicked button
	"""
	print("[RingUpgradeMenu] Button clicked: %s (Preview mode: %s)" % [button_id, preview_mode])

	# FIRST CLICK: Enter preview mode
	if preview_mode == "":
		_enter_preview_mode(button_id)
		return

	# SECOND CLICK on same button: Confirm action
	if preview_mode == button_id:
		_confirm_action(button_id)
		return

	# CLICK on different button: Switch preview
	_cancel_preview()
	_enter_preview_mode(button_id)

func _enter_preview_mode(button_id: String):
	"""Enter preview mode for a button (first click)"""
	preview_mode = button_id

	match button_id:
		"upgrade":
			if not is_max_level and tower.has_method("get_upgrade_stats"):
				preview_stats = tower.get_upgrade_stats()
				_update_center_stats()
				_update_button_preview_visual(button_id, "CONFIRM")

		"sell":
			_update_button_preview_visual(button_id, "CONFIRM")

		"rally":
			_update_button_preview_visual(button_id, "CONFIRM")

		"enemy_list":
			# Enemy list toggles IMMEDIATELY (single-click, no preview)
			enemy_list_visible = not enemy_list_visible
			enemy_list_toggled.emit(enemy_list_visible)
			if enemy_list_visible:
				_show_enemy_list()
			else:
				_hide_enemy_list()
			# Don't enter preview mode - action is instant
			return

		"targeting":
			# SPECIAL: Open targeting submenu instead of preview
			_show_targeting_submenu()

		_:
			# Targeting modes (in submenu)
			if button_id in ["first", "last", "close", "strong", "weak"]:
				_update_button_preview_visual(button_id, "CONFIRM")
			# Generic path button handler (cannon_path, mortar_path, inferno_path, frost_path, defense_path, offense_path, etc.)
			elif button_id.ends_with("_path"):
				_handle_path_button_preview(button_id)

func _confirm_action(button_id: String):
	"""Confirm action (second click)"""
	print("[RingUpgradeMenu] Action confirmed: %s" % button_id)

	match button_id:
		"upgrade":
			if not is_max_level:
				upgrade_selected.emit(tower)
				# Menu will auto-close after upgrade in PlacementManager

		"sell":
			sell_selected.emit(tower)
			# Menu will close automatically

		"rally":
			rally_mode_entered.emit(tower)
			close()  # Close menu to let player place rally point

		"enemy_list":
			# Enemy list now handles toggling in _enter_preview_mode (single-click)
			# This case should never be reached
			pass

		_:
			# Generic path button handler (cannon_path, mortar_path, inferno_path, frost_path, defense_path, offense_path, etc.)
			if button_id.ends_with("_path"):
				_handle_path_button_confirm(button_id)
			# Targeting modes
			elif button_id in ["first", "last", "close", "strong", "weak"]:
				var mode = _get_targeting_mode_from_button_id(button_id)
				if mode != -1:
					targeting_mode_changed.emit(tower, mode)
					_cancel_preview()  # Return to normal, update button colors

func _cancel_preview():
	"""Cancel preview mode (click outside or different button)"""
	if preview_mode == "":
		return

	print("[RingUpgradeMenu] Preview cancelled: %s" % preview_mode)

	var old_preview = preview_mode
	preview_mode = ""
	preview_stats.clear()

	# Restore button visuals
	_restore_button_visual(old_preview)

	# Restore other path button if was dimmed
	if old_preview == "damage_path":
		_restore_button_visual("range_path")
	elif old_preview == "range_path":
		_restore_button_visual("damage_path")

	# Update stats
	_update_center_stats()

func _update_button_preview_visual(button_id: String, confirm_text: String):
	"""Update button to show preview/confirm state"""
	if not action_buttons.has(button_id):
		return

	var button = action_buttons[button_id]
	var btn_data = _calculate_button_positions()[button_id]

	# Update text
	button.text = "%s\n%s" % [btn_data["emoji"], confirm_text]

	# Add glow border
	var style_glow = StyleBoxFlat.new()
	style_glow.bg_color = Color(0.3, 0.3, 0.4, 1.0) * btn_data["color"]
	style_glow.set_border_width_all(6)
	style_glow.border_color = COLOR_CONFIRM  # Yellow glow
	style_glow.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", style_glow)

func _restore_button_visual(button_id: String):
	"""Restore button to normal visual state"""
	if not action_buttons.has(button_id):
		return

	# Safety check: Ensure button exists in current layout
	var positions = _calculate_button_positions()
	if not positions.has(button_id):
		print("[RingUpgradeMenu] Cannot restore %s - not in current layout" % button_id)
		return

	var button = action_buttons[button_id]
	var btn_data = positions[button_id]

	# Restore text
	button.text = _get_button_text(button_id, btn_data["emoji"])

	# Restore style
	_style_action_button(button, btn_data["color"], button_id)

func _dim_other_path_button(button_id: String):
	"""Dim the other path choice button"""
	if not action_buttons.has(button_id):
		return

	var button = action_buttons[button_id]
	button.modulate = Color(0.5, 0.5, 0.5)  # Dim

func _handle_path_button_preview(button_id: String):
	"""Generic handler for path button previews (works for any tower type)"""
	# Get path internal name from button_id (e.g., "cannon_path" → "cannon")
	var internal_name = button_id.trim_suffix("_path")

	# Get preview stats from tower
	if tower.has_method("get_upgrade_stats"):
		preview_stats = tower.get_upgrade_stats(internal_name)

	_update_center_stats()
	_update_button_preview_visual(button_id, "CONFIRM")

	# Dim the other path button
	if tower.has_method("get_path_choices"):
		var path_choices = tower.get_path_choices()
		for choice in path_choices:
			if choice["id"] != button_id:
				_dim_other_path_button(choice["id"])

func _handle_path_button_confirm(button_id: String):
	"""Generic handler for path button confirmation (works for any tower type)"""
	# Map button to position (first or second path choice)
	# PlacementManager uses damage_path_chosen for LEFT button, range_path_chosen for RIGHT button
	var path_choices = []
	if tower.has_method("get_path_choices"):
		path_choices = tower.get_path_choices()

	# Determine which position this button is in
	var is_first_path = false
	if path_choices.size() >= 2:
		is_first_path = (button_id == path_choices[0]["id"])

	# Emit appropriate signal based on position
	if is_first_path:
		damage_path_chosen.emit(tower)  # LEFT button (damage/cannon/inferno/defense)
	else:
		range_path_chosen.emit(tower)   # RIGHT button (range/mortar/frost/offense)

func _get_targeting_mode_from_button_id(button_id: String) -> int:
	"""Convert button_id to TargetingMode enum"""
	match button_id:
		"first": return TargetingMode.FIRST
		"last": return TargetingMode.LAST
		"close": return TargetingMode.CLOSE
		"strong": return TargetingMode.STRONG
		"weak": return TargetingMode.WEAK
		_: return -1

# ============================================
# ENEMY LIST PANEL
# ============================================

func _show_enemy_list():
	"""Show floating enemy list panel"""
	if enemy_list_panel:
		return  # Already showing

	# Create panel
	enemy_list_panel = Panel.new()
	enemy_list_panel.name = "EnemyListPanel"
	enemy_list_panel.custom_minimum_size = ENEMY_LIST_SIZE
	enemy_list_panel.position = ENEMY_LIST_OFFSET

	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = CENTER_BG_COLOR
	style.set_border_width_all(2)
	style.border_color = CENTER_BORDER_COLOR
	style.set_corner_radius_all(8)
	enemy_list_panel.add_theme_stylebox_override("panel", style)

	add_child(enemy_list_panel)

	# Create scrollable container for enemy list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = ENEMY_LIST_SIZE - Vector2(10, 10)
	scroll.position = Vector2(5, 5)
	enemy_list_panel.add_child(scroll)

	enemy_list_container = VBoxContainer.new()
	scroll.add_child(enemy_list_container)

	# Add title
	var title = Label.new()
	title.text = "Enemies in Range"
	title.add_theme_font_size_override("font_size", 12)
	enemy_list_container.add_child(title)

	# Initial enemy list population
	_update_enemy_list()

	# Start real-time updates
	if enemy_update_timer:
		enemy_update_timer.start()

	enemy_list_visible = true
	print("[RingUpgradeMenu] Enemy list shown with real-time updates")

func _update_enemy_list():
	"""Update enemy list content in real-time"""
	if not enemy_list_container or not tower:
		return

	# Clear old enemy labels (keep title)
	var children = enemy_list_container.get_children()
	for i in range(1, children.size()):  # Skip first child (title)
		children[i].queue_free()

	# Get current enemies from tower
	var enemies = []
	if "enemies_in_range" in tower:
		enemies = tower.enemies_in_range

	if enemies.size() > 0:
		for i in range(min(enemies.size(), 10)):  # Limit to 10
			var enemy = enemies[i]
			if not is_instance_valid(enemy):
				continue

			var enemy_label = Label.new()
			var enemy_name = enemy.get_enemy_name() if enemy.has_method("get_enemy_name") else "Enemy"
			var hp = enemy.current_health if "current_health" in enemy else 0
			var max_hp = enemy.max_health if "max_health" in enemy else 0
			var gold = enemy.gold_reward if "gold_reward" in enemy else 0
			var armor = enemy.armor if "armor" in enemy else 0.0
			var armor_percent = int(armor * 100)

			# Get progress percentage (distance to goal)
			var progress = 0.0
			if enemy.has_method("get_path_progress"):
				progress = enemy.get_path_progress()
			elif "waypoint_progress" in enemy:
				progress = enemy.waypoint_progress
			var progress_percent = int(progress * 100)

			# Format display with armor and gold indicators
			var armor_text = " [⛨%d%%]" % armor_percent if armor > 0.0 else ""
			enemy_label.text = "[%d] %s%s\nHP: %d/%d | 💰%dg | %d%%" % [
				i+1, enemy_name, armor_text, hp, max_hp, gold, progress_percent
			]

			# Add boss highlighting
			if _is_enemy_boss(enemy):
				enemy_label.add_theme_color_override("font_color", Color(1.0, 0.4, 1.0))  # Magenta for bosses

			enemy_label.add_theme_font_size_override("font_size", 10)
			enemy_list_container.add_child(enemy_label)
	else:
		var no_enemies = Label.new()
		no_enemies.text = "No enemies in range"
		no_enemies.add_theme_font_size_override("font_size", 10)
		enemy_list_container.add_child(no_enemies)

func _hide_enemy_list():
	"""Hide floating enemy list panel"""
	# Stop real-time updates
	if enemy_update_timer:
		enemy_update_timer.stop()

	if enemy_list_panel:
		enemy_list_panel.queue_free()
		enemy_list_panel = null
		enemy_list_container = null

	enemy_list_visible = false
	print("[RingUpgradeMenu] Enemy list hidden")

func _is_enemy_boss(enemy) -> bool:
	"""Check if enemy is a boss"""
	if "is_boss" in enemy:
		return enemy.is_boss
	var name = enemy.get_enemy_name() if enemy.has_method("get_enemy_name") else ""
	return "boss" in name.to_lower()

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
	var button_list = action_buttons.values()
	for i in range(button_list.size()):
		var button = button_list[i]
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
# TARGETING SUBMENU
# ============================================

func _show_targeting_submenu():
	"""Show targeting mode submenu (5 buttons in small circle)"""
	if targeting_submenu_open:
		return  # Already open

	print("[RingUpgradeMenu] Opening targeting submenu")
	targeting_submenu_open = true

	# Dim main menu buttons
	for button in action_buttons.values():
		button.modulate = Color(0.6, 0.6, 0.6)  # Dim to 60%

	# Create submenu container
	submenu_container = Control.new()
	submenu_container.name = "TargetingSubmenu"
	buttons_container.add_child(submenu_container)

	# Define 5 targeting mode buttons in circle
	var targeting_modes = [
		{"id": "first", "angle": -PI/2, "emoji": EMOJI_FIRST, "mode": TargetingMode.FIRST},
		{"id": "strong", "angle": -PI/2 + (TAU / 5), "emoji": EMOJI_STRONG, "mode": TargetingMode.STRONG},
		{"id": "weak", "angle": -PI/2 + (TAU / 5) * 2, "emoji": EMOJI_WEAK, "mode": TargetingMode.WEAK},
		{"id": "close", "angle": -PI/2 + (TAU / 5) * 3, "emoji": EMOJI_CLOSE, "mode": TargetingMode.CLOSE},
		{"id": "last", "angle": -PI/2 + (TAU / 5) * 4, "emoji": EMOJI_LAST, "mode": TargetingMode.LAST},
	]

	# Create buttons
	for mode_data in targeting_modes:
		var button = _create_submenu_button(mode_data)
		submenu_buttons[mode_data["id"]] = button

	# Animate submenu buttons
	for i in range(submenu_buttons.values().size()):
		var button = submenu_buttons.values()[i]
		button.scale = Vector2.ZERO
		var delay = i * 0.03
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, ANIMATION_SPEED).set_delay(delay)

func _create_submenu_button(mode_data: Dictionary) -> Button:
	"""Create a targeting mode button for submenu"""
	var button = Button.new()
	button.name = "SubmenuButton_%s" % mode_data["id"]
	button.custom_minimum_size = Vector2(BUTTON_SIZE_SUBMENU, BUTTON_SIZE_SUBMENU)

	# Calculate position on small circle
	var angle = mode_data["angle"]
	var offset = Vector2(
		cos(angle) * SUBMENU_RADIUS,
		sin(angle) * SUBMENU_RADIUS
	)

	# Position button
	button.position = offset - (Vector2(BUTTON_SIZE_SUBMENU, BUTTON_SIZE_SUBMENU) / 2)

	# Set button text (just emoji)
	button.text = mode_data["emoji"]

	# Style button - highlight if active mode
	var is_active = false
	if tower and tower.has_method("get_targeting_mode"):
		is_active = tower.get_targeting_mode() == mode_data["mode"]

	var tint_color = COLOR_TARGETING_ACTIVE if is_active else COLOR_TARGETING_INACTIVE
	_style_submenu_button(button, tint_color)

	# Store mode in metadata
	button.set_meta("targeting_mode", mode_data["mode"])
	button.set_meta("button_id", mode_data["id"])

	# Connect click signal
	button.pressed.connect(_on_submenu_targeting_clicked.bind(mode_data["mode"]))

	# Add to container
	submenu_container.add_child(button)

	return button

func _style_submenu_button(button: Button, tint_color: Color):
	"""Style a submenu button"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.95) * tint_color
	style_normal.set_border_width_all(2)
	style_normal.border_color = Color(0.5, 0.4, 0.25, 1.0)
	style_normal.set_corner_radius_all(10)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.25, 0.3, 1.0) * tint_color
	style_hover.set_border_width_all(3)
	style_hover.border_color = Color(0.9, 0.8, 0.5, 1.0)
	style_hover.set_corner_radius_all(10)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_font_size_override("font_size", 20)  # Smaller emoji

func _on_submenu_targeting_clicked(mode: int):
	"""Handle click on targeting mode in submenu"""
	print("[RingUpgradeMenu] Targeting mode selected from submenu: %d" % mode)

	# Change targeting mode immediately
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(mode)
		targeting_mode_changed.emit(tower, mode)
		print("✅ Targeting mode changed to: %d" % mode)

	# Update main TARGETING button text to show new mode
	if action_buttons.has("targeting"):
		var targeting_button = action_buttons["targeting"]
		var mode_name = _get_targeting_mode_name_from_int(mode)
		targeting_button.text = "🎯\n%s" % mode_name

	# Close submenu
	_hide_targeting_submenu()

func _hide_targeting_submenu():
	"""Hide targeting mode submenu"""
	if not targeting_submenu_open:
		return

	print("[RingUpgradeMenu] Closing targeting submenu")
	targeting_submenu_open = false

	# Restore main menu button brightness
	for button in action_buttons.values():
		button.modulate = Color(1.0, 1.0, 1.0)  # Full brightness

	# Remove submenu buttons
	if submenu_container:
		submenu_container.queue_free()
		submenu_container = null
	submenu_buttons.clear()

	# Clear preview mode
	preview_mode = ""

func _get_targeting_mode_name_from_int(mode: int) -> String:
	"""Get targeting mode name from integer"""
	match mode:
		TargetingMode.FIRST: return "FIRST"
		TargetingMode.LAST: return "LAST"
		TargetingMode.CLOSE: return "CLOSE"
		TargetingMode.STRONG: return "STRONG"
		TargetingMode.WEAK: return "WEAK"
		_: return "FIRST"

# ============================================
# INPUT HANDLING
# ============================================

func _unhandled_input(event: InputEvent):
	"""Close menu when clicking outside, or cancel preview"""
	if not is_open:
		return

	# Check for mouse click or touch
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)

	if is_click or is_touch:
		# Check if click is outside menu area
		var click_pos = event.position
		var distance_from_center = click_pos.distance_to(global_position)

		# Close if click is outside ring radius + largest button
		if distance_from_center > RING_RADIUS + (BUTTON_SIZE_LARGE / 2) + 20:
			# Priority 1: Close targeting submenu if open
			if targeting_submenu_open:
				_hide_targeting_submenu()
			# Priority 2: Cancel preview if active
			elif preview_mode != "":
				_cancel_preview()
			# Priority 3: Close menu entirely
			else:
				close()
			get_viewport().set_input_as_handled()

# ============================================
# HELPER FUNCTIONS
# ============================================

func _get_current_targeting_mode_name() -> String:
	"""Get the name of the current targeting mode"""
	if not tower or not tower.has_method("get_targeting_mode"):
		return "FIRST"

	var mode = tower.get_targeting_mode()
	match mode:
		TargetingMode.FIRST:
			return "FIRST"
		TargetingMode.LAST:
			return "LAST"
		TargetingMode.CLOSE:
			return "CLOSE"
		TargetingMode.STRONG:
			return "STRONG"
		TargetingMode.WEAK:
			return "WEAK"
		_:
			return "FIRST"

func _is_tower_max_level() -> bool:
	"""Check if tower is at max level"""
	if not tower:
		return false

	# Check if tower has max level defined
	if tower.has_method("get_max_level"):
		return tower.tower_level >= tower.get_max_level()

	# Default max level is 5 for most towers (Lv1-4 upgrades + path choice)
	return tower.tower_level >= 5

func _get_upgrade_cost() -> int:
	"""Get upgrade cost for current level"""
	if not tower or is_max_level:
		return 0

	if tower.has_method("get_upgrade_cost"):
		return tower.get_upgrade_cost()

	# Fallback: get from TowerData
	if tower.has_method("get_tower_id"):
		var tower_id = tower.get_tower_id() if tower.has_method("get_tower_id") else tower.tower_id
		var next_level = tower.tower_level + 1
		var tower_data = TowerData.get_tower_stats(tower_id, next_level)
		if tower_data:
			return tower_data.get("upgrade_cost", 0)

	return 60  # Default fallback

func _calculate_sell_value() -> int:
	"""Calculate sell value (70% of build cost)"""
	if not tower:
		return 0

	if tower.has_method("get_sell_value"):
		return tower.get_sell_value()

	# Fallback: 70% of build_cost
	var build_cost = tower.build_cost if "build_cost" in tower else 100
	return int(build_cost * 0.7)

func _gui_input(event: InputEvent):
	"""Consume clicks inside panel to prevent click-through"""
	if event is InputEventMouseButton and event.pressed:
		accept_event()  # Prevent click from going through to game world
