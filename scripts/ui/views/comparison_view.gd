extends BasePanelView
class_name ComparisonView

## ComparisonView - Side-by-side item comparison tool
## Compare equipped items with inventory items

@export var hero_id: String = "ranger"

# UI References
@onready var left_panel: PanelContainer = $MarginContainer/VBoxContainer/ComparisonContainer/LeftPanel if has_node("MarginContainer/VBoxContainer/ComparisonContainer/LeftPanel") else null
@onready var right_panel: PanelContainer = $MarginContainer/VBoxContainer/ComparisonContainer/RightPanel if has_node("MarginContainer/VBoxContainer/ComparisonContainer/RightPanel") else null

@onready var left_item_name: Label = $MarginContainer/VBoxContainer/ComparisonContainer/LeftPanel/VBox/ItemName if has_node("MarginContainer/VBoxContainer/ComparisonContainer/LeftPanel/VBox/ItemName") else null
@onready var right_item_name: Label = $MarginContainer/VBoxContainer/ComparisonContainer/RightPanel/VBox/ItemName if has_node("MarginContainer/VBoxContainer/ComparisonContainer/RightPanel/VBox/ItemName") else null

@onready var left_stats: RichTextLabel = $MarginContainer/VBoxContainer/ComparisonContainer/LeftPanel/VBox/StatsLabel if has_node("MarginContainer/VBoxContainer/ComparisonContainer/LeftPanel/VBox/StatsLabel") else null
@onready var right_stats: RichTextLabel = $MarginContainer/VBoxContainer/ComparisonContainer/RightPanel/VBox/StatsLabel if has_node("MarginContainer/VBoxContainer/ComparisonContainer/RightPanel/VBox/StatsLabel") else null

@onready var instructions_label: Label = $MarginContainer/VBoxContainer/Header/InstructionsLabel if has_node("MarginContainer/VBoxContainer/Header/InstructionsLabel") else null
@onready var equip_button: Button = $MarginContainer/VBoxContainer/Footer/EquipButton if has_node("MarginContainer/VBoxContainer/Footer/EquipButton") else null

# Comparison data
var left_item: ItemData = null  # Currently equipped
var right_item: ItemData = null  # Inventory item to compare
var comparison_slot: String = ""  # Which equipment slot (weapon, armor, etc.)


func _ready():
	super._ready()
	view_name = "Comparison"

	if equip_button:
		equip_button.pressed.connect(_on_equip_button_pressed)
		equip_button.disabled = true

	_show_instructions()


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	# Comparison view refreshes when items are set
	if left_item or right_item:
		_update_comparison()
	else:
		_show_instructions()


func set_hero_id(p_hero_id: String):
	"""Set which hero's equipment to compare"""
	hero_id = p_hero_id


func compare_items(equipped_item_id: String, inventory_item_id: String, slot: String):
	"""Set items to compare"""
	comparison_slot = slot

	# Get item data
	if equipped_item_id != "":
		left_item = ItemDatabase.get_item(equipped_item_id)
	else:
		left_item = null

	if inventory_item_id != "":
		right_item = ItemDatabase.get_item(inventory_item_id)
	else:
		right_item = null

	_update_comparison()


func _update_comparison():
	"""Update the comparison display"""
	# Left side (equipped)
	if left_item and left_item_name and left_stats:
		left_item_name.text = "[EQUIPPED] " + left_item.item_name
		left_stats.text = _format_item_stats(left_item, null)
	elif left_item_name and left_stats:
		left_item_name.text = "[EMPTY SLOT]"
		left_stats.text = "[color=gray]No item equipped[/color]"

	# Right side (comparison)
	if right_item and right_item_name and right_stats:
		right_item_name.text = right_item.item_name
		right_stats.text = _format_item_stats(right_item, left_item)
	elif right_item_name and right_stats:
		right_item_name.text = "[SELECT ITEM]"
		right_stats.text = "[color=gray]Select an item from inventory to compare[/color]"

	# Enable equip button if we have a right item
	if equip_button:
		equip_button.disabled = (right_item == null)


func _format_item_stats(item: ItemData, compare_to: ItemData) -> String:
	"""Format item stats with comparison highlights"""
	var text = ""

	# Rarity
	text += "[color=%s]%s[/color]\n\n" % [item.get_rarity_color().to_html(), item.get_rarity_name()]

	# Description
	text += "[color=gray]%s[/color]\n\n" % item.description

	# Stats with comparison
	text += "[b]STATS:[/b]\n"

	# Damage
	if item.damage_bonus > 0:
		var diff = _get_stat_diff(item.damage_bonus, compare_to.damage_bonus if compare_to else 0)
		text += "Damage: %s%d%s\n" % [diff.prefix, item.damage_bonus, diff.suffix]

	# Health
	if item.health_bonus > 0:
		var diff = _get_stat_diff(item.health_bonus, compare_to.health_bonus if compare_to else 0)
		text += "Health: %s%d%s\n" % [diff.prefix, item.health_bonus, diff.suffix]

	# Defense
	if item.defense_bonus > 0:
		var diff = _get_stat_diff(item.defense_bonus, compare_to.defense_bonus if compare_to else 0)
		text += "Defense: %s%d%s\n" % [diff.prefix, item.defense_bonus, diff.suffix]

	# Attack Speed
	if item.attack_speed_multiplier != 1.0:
		var diff = _get_stat_diff(item.attack_speed_multiplier, compare_to.attack_speed_multiplier if compare_to else 1.0)
		text += "Attack Speed: %sx%.2f%s\n" % [diff.prefix, item.attack_speed_multiplier, diff.suffix]

	# Range
	if item.range_bonus > 0:
		var diff = _get_stat_diff(item.range_bonus, compare_to.range_bonus if compare_to else 0)
		text += "Range: %s%d%s\n" % [diff.prefix, item.range_bonus, diff.suffix]

	# Crit Chance
	if item.crit_chance_bonus > 0:
		var diff = _get_stat_diff(item.crit_chance_bonus, compare_to.crit_chance_bonus if compare_to else 0)
		text += "Crit Chance: %s%.1f%%%s\n" % [diff.prefix, item.crit_chance_bonus * 100, diff.suffix]

	return text


func _get_stat_diff(value: float, compare_value: float) -> Dictionary:
	"""Get color prefix/suffix for stat comparison"""
	if compare_value == 0:
		return {"prefix": "", "suffix": ""}

	var diff = value - compare_value
	if diff > 0:
		return {"prefix": "[color=green]", "suffix": " ▲[/color]"}
	elif diff < 0:
		return {"prefix": "[color=red]", "suffix": " ▼[/color]"}
	else:
		return {"prefix": "", "suffix": " ="}


func _show_instructions():
	"""Show instructions when no items selected"""
	if instructions_label:
		instructions_label.text = "Select items to compare"

	if left_item_name:
		left_item_name.text = "[EQUIPPED]"
	if left_stats:
		left_stats.text = "[color=gray]No item equipped in this slot[/color]"

	if right_item_name:
		right_item_name.text = "[SELECT ITEM]"
	if right_stats:
		right_stats.text = "[color=gray]Right-click an inventory item to compare[/color]"


func _on_equip_button_pressed():
	"""Equip the right item"""
	if not right_item or comparison_slot == "":
		return

	# Find equipment manager
	var heroes = get_tree().get_nodes_in_group("hero")
	for hero in heroes:
		if hero.has_method("get_hero_id") and hero.get_hero_id() == hero_id:
			if hero.has_node("EquipmentManager"):
				var equipment_manager = hero.get_node("EquipmentManager")
				equipment_manager.equip_item(comparison_slot, right_item.item_id)
				print("[ComparisonView] Equipped: ", right_item.item_name)

				# Clear comparison
				left_item = null
				right_item = null
				_show_instructions()
				return

	print("[ComparisonView] Error: Could not find equipment manager")
