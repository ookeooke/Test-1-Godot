class_name ItemVisualHelper
extends RefCounted

## ItemVisualHelper - Shared logic for item rendering and interaction
##
## Centralizes logic shared between:
## 1. EquipmentSlot (Equipment slots)
## 2. ItemSprite (Inventory grid items)
##
## Handles:
## - Tooltip generation
## - Visual setup (icon, quantity, upgrade labels)
## - Rarity border coloring

# ==============================================================================
# VISUAL SETUP
# ==============================================================================

static func setup_item_visuals(_parent: Control, icon: TextureRect, quantity_label: Label, upgrade_label: Label, rarity_border: Panel, item_instance: ItemInstance):
	"""Update all visual elements for an item"""
	if not item_instance:
		clear_visuals(icon, quantity_label, upgrade_label, rarity_border)
		return

	var item_data = item_instance.get_data()
	if not item_data:
		return

	# 1. Icon
	if icon:
		icon.texture = item_data.icon
		icon.modulate = Color.WHITE

	# 2. Quantity
	if quantity_label:
		if item_data.item_type != ItemData.ItemType.CURRENCY and item_instance.quantity > 1:
			quantity_label.text = "×%d" % item_instance.quantity
		else:
			quantity_label.text = ""

	# 3. Upgrade Level
	if upgrade_label:
		if item_data.can_upgrade and item_instance.upgrade_level > 0:
			upgrade_label.text = "+%d" % item_instance.upgrade_level
		else:
			upgrade_label.text = ""

	# 4. Rarity Border
	if rarity_border:
		if item_data.rarity != ItemData.Rarity.NORMAL:
			rarity_border.visible = true
			rarity_border.modulate = item_data.get_rarity_color()
		else:
			rarity_border.visible = false

static func clear_visuals(icon: TextureRect, quantity_label: Label, upgrade_label: Label, rarity_border: Panel):
	"""Clear all visual elements"""
	if icon:
		icon.texture = null
		icon.modulate = Color(1, 1, 1, 0.3) # Dim placeholder
	
	if quantity_label:
		quantity_label.text = ""
		
	if upgrade_label:
		upgrade_label.text = ""
		
	if rarity_border:
		rarity_border.visible = false
		rarity_border.modulate = Color.WHITE

# ==============================================================================
# TOOLTIP GENERATION
# ==============================================================================

static func generate_tooltip(item_instance: ItemInstance) -> String:
	"""Generate standardized tooltip text"""
	if not item_instance:
		return ""
		
	var item_data = item_instance.get_data()
	if not item_data:
		return ""

	var tooltip = "[b]%s[/b]\n" % item_data.item_name
	tooltip += "[color=gray]%s[/color]\n\n" % item_data.get_rarity_name()

	# Description
	if item_data.description != "":
		tooltip += "%s\n\n" % item_data.description

	# Stat Bonuses
	var stats_lines: Array = []
	if item_data.damage_bonus > 0:
		stats_lines.append("+%d Damage" % item_data.damage_bonus)
	if item_data.range_bonus > 0:
		stats_lines.append("+%d Range" % item_data.range_bonus)
	if item_data.attack_speed_multiplier > 1.0:
		var speed_percent = (item_data.attack_speed_multiplier - 1.0) * 100
		stats_lines.append("+%d%% Attack Speed" % speed_percent)
	if item_data.health_bonus > 0:
		stats_lines.append("+%d Health" % item_data.health_bonus)
	if item_data.defense_bonus > 0:
		stats_lines.append("+%d Defense" % item_data.defense_bonus)

	if not stats_lines.is_empty():
		tooltip += "\n".join(stats_lines) + "\n"

	# Upgrade Level
	if item_instance.upgrade_level > 0:
		tooltip += "\n[color=green]+%d Upgrade Level[/color]" % item_instance.upgrade_level

	return tooltip
