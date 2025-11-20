## ============================================================================
## ItemTooltip.gd
## ============================================================================
## Rich tooltip UI for items with stat comparison.
##
## Features:
## - Rarity-colored borders (Diablo style)
## - Dark fantasy aesthetic (Kingdom Rush meets Diablo)
## - Stat comparison with equipped items (green ↑ / red ↓)
## - Affix display for Magic/Rare items
## - Glow effects for Rare+ items
## - Responsive layout (scales with UIScaleManager)
##
## Structure:
## - Header: Item name (rarity color) + type
## - Separator: Rarity-colored line
## - Main Stats: Damage, Health, Defense, etc. with comparison
## - Affixes: Magic/Rare item affixes
## - Footer: Upgrade level indicator
##
## Usage:
##   set_item(item_instance, equipped_item_instance)
## ============================================================================

extends PanelContainer

## Node references (assigned in _ready or via scene tree)
@onready var item_name_label: Label = %ItemNameLabel
@onready var rarity_type_label: Label = %RarityTypeLabel
@onready var separator: HSeparator = %Separator
@onready var main_stats_container: VBoxContainer = %MainStatsContainer
@onready var affix_container: VBoxContainer = %AffixContainer
@onready var footer_container: VBoxContainer = %FooterContainer
@onready var upgrade_label: Label = %UpgradeLabel

## Current item being displayed
var _current_item: ItemInstance = null

## Equipped item for comparison (can be null)
var _equipped_item: ItemInstance = null


func _ready() -> void:
	# Initial setup
	custom_minimum_size = Vector2(400, 200) * UIScaleManager.ui_scale

	# Connect to scale changes
	if UIScaleManager.has_signal("scale_changed"):
		UIScaleManager.scale_changed.connect(_on_scale_changed)


func _on_scale_changed(new_scale: float) -> void:
	"""Update tooltip size when UI scale changes."""
	custom_minimum_size = Vector2(400, 200) * new_scale


## ============================================================================
## PUBLIC API
## ============================================================================

func set_item(item: ItemInstance, equipped_item: ItemInstance = null) -> void:
	"""
	Populate tooltip with item data and optional comparison.

	Args:
	    item: The item to display
	    equipped_item: Equipped item to compare against (null = no comparison)
	"""
	if not item:
		push_warning("ItemTooltip: Cannot set null item")
		return

	_current_item = item
	_equipped_item = equipped_item

	var item_data = item.get_data()

	# Apply visual style based on rarity
	_apply_rarity_style(item_data.rarity)

	# Populate sections
	_populate_header(item)
	_populate_main_stats(item, equipped_item)
	_populate_affixes(item)
	_populate_footer(item)


## ============================================================================
## VISUAL STYLE
## ============================================================================

func _apply_rarity_style(rarity: ItemData.Rarity) -> void:
	"""Apply rarity-specific colors and glow effects."""
	var style = StyleBoxFlat.new()

	# Dark fantasy background
	style.bg_color = Color(0.17, 0.12, 0.08, 0.95)  # Dark brown

	# Thick chunky border
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4

	# Rounded corners
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8

	# Anti-aliasing for smooth edges
	style.anti_aliasing = true
	style.anti_aliasing_size = 2

	# Rarity-colored border (Diablo style)
	var border_color: Color
	match rarity:
		ItemData.Rarity.NORMAL:
			border_color = Color(0.7, 0.7, 0.7)  # Grey
		ItemData.Rarity.MAGIC:
			border_color = Color(0.29, 0.56, 0.89)  # Blue
		ItemData.Rarity.RARE:
			border_color = Color(0.96, 0.65, 0.14)  # Gold
		ItemData.Rarity.SET:
			border_color = Color(0.3, 0.8, 0.3)  # Green
		ItemData.Rarity.UNIQUE:
			border_color = Color(1.0, 0.27, 0.0)  # Orange
		_:
			border_color = Color.WHITE

	style.border_color = border_color

	# Glow effect for Rare+ items
	if rarity >= ItemData.Rarity.RARE:
		style.shadow_size = 8
		style.shadow_color = border_color * Color(1, 1, 1, 0.5)  # 50% opacity glow
		style.shadow_offset = Vector2(0, 0)  # Centered glow

	# Apply style to panel
	add_theme_stylebox_override("panel", style)

	# Color separator to match border
	if separator:
		separator.modulate = border_color


## ============================================================================
## HEADER SECTION
## ============================================================================

func _populate_header(item: ItemInstance) -> void:
	"""Populate header with item name and type."""
	var item_data = item.get_data()

	# Get display name (includes affixes for Magic/Rare items)
	var display_name = item_data.get_display_name(item.rolled_affixes)

	if item_name_label:
		item_name_label.text = display_name
		# Color name by rarity
		item_name_label.modulate = item_data.get_rarity_color()

	# Rarity + Type subtitle
	if rarity_type_label:
		var rarity_name = _get_rarity_name(item_data.rarity)
		var type_name = _get_item_type_name(item_data.item_type)
		rarity_type_label.text = "%s %s" % [rarity_name, type_name]
		rarity_type_label.modulate = Color(0.7, 0.7, 0.7)  # Grey subtitle


## ============================================================================
## MAIN STATS SECTION
## ============================================================================

func _populate_main_stats(item: ItemInstance, equipped_item: ItemInstance) -> void:
	"""Populate main stats with comparison arrows."""
	if not main_stats_container:
		return

	# Clear existing stat lines
	for child in main_stats_container.get_children():
		child.queue_free()

	# Get total stats (base + affixes + upgrade)
	var item_stats = _calculate_total_stats(item)
	var equipped_stats = _calculate_total_stats(equipped_item) if equipped_item else {}

	# Display stats (only show non-zero values)
	if item_stats.damage > 0:
		_add_stat_line("Damage", item_stats.damage, equipped_stats.get("damage", 0), equipped_item != null)

	if item_stats.health > 0:
		_add_stat_line("Health", item_stats.health, equipped_stats.get("health", 0), equipped_item != null)

	if item_stats.defense > 0:
		_add_stat_line("Defense", item_stats.defense, equipped_stats.get("defense", 0), equipped_item != null)

	if item_stats.range > 0:
		_add_stat_line("Range", item_stats.range, equipped_stats.get("range", 0), equipped_item != null)

	if item_stats.attack_speed != 1.0:
		var as_pct = (item_stats.attack_speed - 1.0) * 100
		var equipped_as_pct = (equipped_stats.get("attack_speed", 1.0) - 1.0) * 100
		_add_stat_line("Attack Speed", as_pct, equipped_as_pct, equipped_item != null, true)

	if item_stats.crit_chance > 0:
		_add_stat_line("Crit Chance", item_stats.crit_chance, equipped_stats.get("crit_chance", 0), equipped_item != null, true)


func _add_stat_line(stat_name: String, value: float, equipped_value: float, has_comparison: bool, is_percentage: bool = false) -> void:
	"""Add a stat line with optional comparison arrow."""
	var line_container = HBoxContainer.new()
	line_container.add_theme_constant_override("separation", 8)

	# Stat name (left-aligned)
	var name_label = Label.new()
	name_label.text = stat_name + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.modulate = Color(0.9, 0.9, 0.9)
	line_container.add_child(name_label)

	# Stat value with comparison (right-aligned)
	var value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if has_comparison and equipped_value != 0:
		# Compare values
		var diff = value - equipped_value
		var comparison_text = _format_stat_comparison(value, diff, is_percentage)
		value_label.text = comparison_text.text
		value_label.modulate = comparison_text.color
	else:
		# No comparison, just show value
		var format_str = "%.1f%%" if is_percentage else "%.0f"
		value_label.text = format_str % value
		value_label.modulate = Color.WHITE

	line_container.add_child(value_label)
	main_stats_container.add_child(line_container)


func _format_stat_comparison(value: float, diff: float, is_percentage: bool) -> Dictionary:
	"""
	Format stat with comparison arrow.
	Returns: {text: String, color: Color}
	"""
	var format_str = "%.1f%%" if is_percentage else "%.0f"
	var value_str = format_str % value

	if abs(diff) < 0.01:  # Effectively the same
		return {
			"text": value_str,
			"color": Color.WHITE
		}
	elif diff > 0:  # Better
		var diff_str = format_str % diff
		return {
			"text": "↑ %s (+%s)" % [value_str, diff_str],
			"color": Color(0.3, 1.0, 0.3)  # Green
		}
	else:  # Worse
		var diff_str = format_str % abs(diff)
		return {
			"text": "↓ %s (-%s)" % [value_str, diff_str],
			"color": Color(1.0, 0.3, 0.3)  # Red
		}


func _calculate_total_stats(item: ItemInstance) -> Dictionary:
	"""Calculate total stats including base, affixes, and upgrades."""
	if not item:
		return {}

	var item_data = item.get_data()
	var upgrade_multiplier = 1.0 + (item.upgrade_level * item_data.stat_increase_per_level)

	var stats = {
		"damage": item_data.damage_bonus * upgrade_multiplier,
		"health": item_data.health_bonus * upgrade_multiplier,
		"defense": item_data.defense_bonus * upgrade_multiplier,
		"range": item_data.range_bonus * upgrade_multiplier,
		"attack_speed": item_data.attack_speed_multiplier,
		"crit_chance": item_data.crit_chance_bonus
	}

	# Add affix bonuses
	for affix_id in item.rolled_affixes.keys():
		var affix_value = item.rolled_affixes[affix_id]
		# Simplified affix parsing (you can expand this based on your affix system)
		if "damage" in affix_id:
			stats.damage += affix_value
		elif "health" in affix_id:
			stats.health += affix_value
		elif "defense" in affix_id:
			stats.defense += affix_value
		elif "range" in affix_id:
			stats.range += affix_value
		elif "attack_speed" in affix_id:
			stats.attack_speed += affix_value / 100.0  # Convert percentage
		elif "crit" in affix_id:
			stats.crit_chance += affix_value

	return stats


## ============================================================================
## AFFIX SECTION
## ============================================================================

func _populate_affixes(item: ItemInstance) -> void:
	"""Display affixes for Magic/Rare items."""
	if not affix_container:
		return

	# Clear existing affixes
	for child in affix_container.get_children():
		child.queue_free()

	var item_data = item.get_data()

	# Only show affixes for Magic/Rare/Set/Unique items
	if item_data.rarity < ItemData.Rarity.MAGIC:
		affix_container.visible = false
		return

	# Show affixes if any
	if item.rolled_affixes.is_empty():
		affix_container.visible = false
		return

	affix_container.visible = true

	# Add separator before affixes
	var affix_separator = HSeparator.new()
	affix_separator.modulate = Color(0.5, 0.5, 0.5)
	affix_container.add_child(affix_separator)

	# Add each affix
	for affix_id in item.rolled_affixes.keys():
		var affix_value = item.rolled_affixes[affix_id]
		var affix_text = _format_affix_text(affix_id, affix_value)

		var affix_label = Label.new()
		affix_label.text = affix_text
		affix_label.modulate = item_data.get_rarity_color() * Color(1, 1, 1, 0.8)
		affix_label.add_theme_font_size_override("font_size", 32)  # Slightly smaller
		affix_container.add_child(affix_label)


func _format_affix_text(affix_id: String, value: float) -> String:
	"""Format affix as readable text (e.g., '+15 Damage')."""
	var readable_name = affix_id.replace("_", " ").capitalize()

	# Determine if percentage or flat value
	if "speed" in affix_id or "chance" in affix_id:
		return "+%.1f%% %s" % [value, readable_name]
	else:
		return "+%.0f %s" % [value, readable_name]


## ============================================================================
## FOOTER SECTION
## ============================================================================

func _populate_footer(item: ItemInstance) -> void:
	"""Show upgrade level and other footer info."""
	if not footer_container or not upgrade_label:
		return

	# Show upgrade level if upgraded
	if item.upgrade_level > 0:
		footer_container.visible = true
		upgrade_label.visible = true
		upgrade_label.text = "Upgraded +%d" % item.upgrade_level
		upgrade_label.modulate = Color(0.3, 1.0, 0.3)  # Green
	else:
		upgrade_label.visible = false

		# Hide footer if empty
		if footer_container.get_child_count() == 1:  # Only upgrade label
			footer_container.visible = false


## ============================================================================
## HELPERS
## ============================================================================

func _get_rarity_name(rarity: ItemData.Rarity) -> String:
	"""Convert rarity enum to display name."""
	match rarity:
		ItemData.Rarity.NORMAL:
			return "Normal"
		ItemData.Rarity.MAGIC:
			return "Magic"
		ItemData.Rarity.RARE:
			return "Rare"
		ItemData.Rarity.SET:
			return "Set"
		ItemData.Rarity.UNIQUE:
			return "Unique"
		_:
			return "Unknown"


func _get_item_type_name(item_type: ItemData.ItemType) -> String:
	"""Convert item type enum to display name."""
	match item_type:
		ItemData.ItemType.WEAPON:
			return "Weapon"
		ItemData.ItemType.ARMOR:
			return "Armor"
		ItemData.ItemType.ACCESSORY:
			return "Accessory"
		ItemData.ItemType.CONSUMABLE:
			return "Consumable"
		ItemData.ItemType.MATERIAL:
			return "Material"
		ItemData.ItemType.CURRENCY:
			return "Currency"
		_:
			return "Item"
