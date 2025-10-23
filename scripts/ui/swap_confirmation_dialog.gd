extends Control
class_name SwapConfirmationDialog

## SwapConfirmationDialog - Confirmation popup for swapping equipped items
## Shows comparison between current and new item with stat differences
## Mobile-friendly with large touch targets (50px buttons)

signal confirmed(new_item_id: String, slot_name: String)
signal cancelled

# UI References
@onready var current_icon: TextureRect = $CenterContainer/DialogPanel/MarginContainer/VBoxContainer/CurrentItemPanel/MarginContainer/HBoxContainer/CurrentIcon
@onready var current_stats: RichTextLabel = $CenterContainer/DialogPanel/MarginContainer/VBoxContainer/CurrentItemPanel/MarginContainer/HBoxContainer/CurrentStats
@onready var new_icon: TextureRect = $CenterContainer/DialogPanel/MarginContainer/VBoxContainer/NewItemPanel/MarginContainer/HBoxContainer/NewIcon
@onready var new_stats: RichTextLabel = $CenterContainer/DialogPanel/MarginContainer/VBoxContainer/NewItemPanel/MarginContainer/HBoxContainer/NewStats

@onready var cancel_button: Button = $CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonsContainer/CancelButton
@onready var equip_button: Button = $CenterContainer/DialogPanel/MarginContainer/VBoxContainer/ButtonsContainer/EquipButton

# Data
var new_item_id: String = ""
var new_item_data: ItemData = null
var old_item_id: String = ""
var old_item_data: ItemData = null
var slot_name: String = ""


func _ready():
	# Connect button signals
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)

	# Hide by default
	visible = false


func show_dialog(p_new_item_id: String, p_old_item_id: String, p_slot_name: String):
	"""Show the swap confirmation dialog with item comparison"""
	new_item_id = p_new_item_id
	old_item_id = p_old_item_id
	slot_name = p_slot_name

	# Load item data
	new_item_data = ItemDatabase.get_item(new_item_id)
	old_item_data = ItemDatabase.get_item(old_item_id)

	if not new_item_data or not old_item_data:
		print("[SwapConfirmationDialog] Error: Could not load item data")
		_on_cancel_pressed()
		return

	# Update UI
	_update_item_display()

	# Show dialog
	visible = true
	print("[SwapConfirmationDialog] Showing swap dialog: %s -> %s" % [old_item_data.item_name, new_item_data.item_name])


func _update_item_display():
	"""Update the visual display of both items with stat comparison"""
	if not old_item_data or not new_item_data:
		return

	# Update current item
	if current_icon:
		current_icon.texture = old_item_data.icon

	if current_stats:
		var current_text = "[b][color=%s]%s[/color][/b]\n" % [old_item_data.get_rarity_color().to_html(), old_item_data.item_name]
		current_text += _get_item_stats_text(old_item_data, false)
		current_text += "\n[color=gray]%s[/color]" % old_item_data.get_rarity_name()
		current_stats.text = current_text

	# Update new item
	if new_icon:
		new_icon.texture = new_item_data.icon

	if new_stats:
		var new_text = "[b][color=%s]%s[/color][/b]\n" % [new_item_data.get_rarity_color().to_html(), new_item_data.item_name]
		new_text += _get_item_stats_text(new_item_data, true)  # Show comparison arrows
		new_text += "\n[color=gray]%s[/color]" % new_item_data.get_rarity_name()
		new_stats.text = new_text


func _get_item_stats_text(item_data: ItemData, show_comparison: bool) -> String:
	"""Get formatted stats text for an item, optionally with comparison arrows"""
	var stats_text = ""

	# Damage
	if item_data.damage_bonus > 0:
		stats_text += "+%d Attack" % item_data.damage_bonus
		if show_comparison and old_item_data:
			var diff = item_data.damage_bonus - old_item_data.damage_bonus
			if diff > 0:
				stats_text += " [color=green]↑ +%d[/color]" % diff
			elif diff < 0:
				stats_text += " [color=red]↓ %d[/color]" % diff
		stats_text += "\n"

	# Health
	if item_data.health_bonus > 0:
		stats_text += "+%d Health" % item_data.health_bonus
		if show_comparison and old_item_data:
			var diff = item_data.health_bonus - old_item_data.health_bonus
			if diff > 0:
				stats_text += " [color=green]↑ +%d[/color]" % diff
			elif diff < 0:
				stats_text += " [color=red]↓ %d[/color]" % diff
		stats_text += "\n"

	# Defense
	if item_data.defense_bonus > 0:
		stats_text += "+%d Defense" % item_data.defense_bonus
		if show_comparison and old_item_data:
			var diff = item_data.defense_bonus - old_item_data.defense_bonus
			if diff > 0:
				stats_text += " [color=green]↑ +%d[/color]" % diff
			elif diff < 0:
				stats_text += " [color=red]↓ %d[/color]" % diff
		stats_text += "\n"

	# Attack Speed
	if item_data.attack_speed_multiplier != 1.0:
		stats_text += "%.1f%% Attack Speed" % (item_data.attack_speed_multiplier * 100)
		if show_comparison and old_item_data:
			var diff = item_data.attack_speed_multiplier - old_item_data.attack_speed_multiplier
			if diff > 0.01:
				stats_text += " [color=green]↑[/color]"
			elif diff < -0.01:
				stats_text += " [color=red]↓[/color]"
		stats_text += "\n"

	return stats_text


func _on_cancel_pressed():
	"""Handle cancel button press"""
	print("[SwapConfirmationDialog] Swap cancelled")
	visible = false
	cancelled.emit()


func _on_equip_pressed():
	"""Handle equip button press"""
	print("[SwapConfirmationDialog] Swap confirmed: %s" % new_item_data.item_name)
	visible = false
	confirmed.emit(new_item_id, slot_name)
