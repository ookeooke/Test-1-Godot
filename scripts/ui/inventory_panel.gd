extends Control
class_name InventoryPanel

## InventoryPanel - Main inventory UI with categorized tabs
## Diablo-style grid inventory with drag-drop support

signal inventory_closed

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")

# Tab buttons
@onready var equipment_tab: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/EquipmentTab if has_node("Panel/MarginContainer/VBoxContainer/TabContainer/EquipmentTab") else null

# Grid containers for each category
@onready var equipment_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentGrid if has_node("Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentGrid") else null

# Info labels
@onready var category_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderContainer/CategoryLabel if has_node("Panel/MarginContainer/VBoxContainer/HeaderContainer/CategoryLabel") else null
@onready var slots_label: Label = $Panel/MarginContainer/VBoxContainer/FooterContainer/SlotsLabel if has_node("Panel/MarginContainer/VBoxContainer/FooterContainer/SlotsLabel") else null
@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/FooterContainer/GoldLabel if has_node("Panel/MarginContainer/VBoxContainer/FooterContainer/GoldLabel") else null
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton if has_node("Panel/MarginContainer/VBoxContainer/HeaderContainer/CloseButton") else null

# Item tooltip
@onready var tooltip_panel: PanelContainer = $TooltipPanel if has_node("TooltipPanel") else null
@onready var tooltip_label: RichTextLabel = $TooltipPanel/MarginContainer/TooltipLabel if has_node("TooltipPanel/MarginContainer/TooltipLabel") else null

# Current state
var current_category: String = "equipment"
var item_slots: Dictionary = {}  # {category: Array[ItemSlot]}


func _ready():
	# Set up as always-process (for pause compatibility)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Initialize item slot arrays
	item_slots["equipment"] = []

	# Create item slots for each category
	_create_item_slots()

	# Connect signals
	if InventoryManager:
		InventoryManager.inventory_changed.connect(_on_inventory_changed)

	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# Set up tab buttons
	if equipment_tab:
		equipment_tab.pressed.connect(_on_equipment_tab_pressed)

	# Hide tooltip initially
	if tooltip_panel:
		tooltip_panel.visible = false

	# Show equipment tab by default
	_switch_to_category("equipment")

	# Initial refresh
	refresh_inventory()


func _create_item_slots():
	"""Create ItemSlot instances for each category"""
	# Equipment slots
	var equipment_count = InventoryManager.max_slots.get("equipment", 20)
	_create_slots_for_category("equipment", equipment_grid, equipment_count, 5)


func _create_slots_for_category(category: String, grid: GridContainer, count: int, columns: int):
	"""Create item slots in a grid"""
	if grid == null:
		return

	grid.columns = columns

	for i in count:
		var slot = item_slot_scene.instantiate() as ItemSlot
		slot.slot_index = i
		slot.slot_type = "inventory"

		# Connect signals
		slot.item_clicked.connect(_on_item_slot_clicked)
		slot.item_right_clicked.connect(_on_item_slot_right_clicked)
		slot.mouse_entered.connect(_on_item_slot_hovered.bind(slot))
		slot.mouse_exited.connect(_on_item_slot_unhovered)

		grid.add_child(slot)
		item_slots[category].append(slot)


func refresh_inventory():
	"""Refresh all inventory slots from InventoryManager"""
	if not InventoryManager:
		return

	# Clear all slots first
	for category in item_slots.keys():
		for slot in item_slots[category]:
			slot.clear_slot()

	# Fill equipment slots
	var equipment_items = InventoryManager.get_items_by_category("equipment")
	_fill_category_slots("equipment", equipment_items)

	# Update labels
	_update_labels()


func _fill_category_slots(category: String, items: Array):
	"""Fill slots for a category with items"""
	var slots = item_slots.get(category, [])
	var slot_index = 0

	for item_info in items:
		if slot_index >= slots.size():
			break

		var slot = slots[slot_index]
		slot.set_item(
			item_info.item_id,
			item_info.quantity,
			item_info.upgrade_level
		)
		slot_index += 1


func _switch_to_category(category: String):
	"""Switch visible category"""
	current_category = category

	# Show equipment grid
	if equipment_grid:
		equipment_grid.visible = (category == "equipment")

	# Update category label
	if category_label:
		category_label.text = category.capitalize() + " Inventory"

	# Update slots label
	_update_labels()


func _update_labels():
	"""Update info labels"""
	# Update gold label
	if gold_label:
		var gold = SaveManager.get_gems()
		gold_label.text = "Gold: %d" % gold

	# Update slots label
	if slots_label:
		var category_items = InventoryManager.get_items_by_category(current_category)
		var max_slots = InventoryManager.max_slots.get(current_category, 20)
		slots_label.text = "Slots: %d / %d" % [category_items.size(), max_slots]


func _on_inventory_changed():
	"""Called when inventory changes"""
	refresh_inventory()


func _on_equipment_tab_pressed():
	_switch_to_category("equipment")


func _on_item_slot_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is left-clicked"""
	print("[InventoryPanel] Item clicked: ", item_id)
	# TODO: Show item details, use consumable, etc.


func _on_item_slot_right_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is right-clicked"""
	print("[InventoryPanel] Item right-clicked: ", item_id)
	# Show context menu (sell, drop, etc.)
	_show_item_context_menu(item_id, slot)


func _show_item_context_menu(item_id: String, slot: ItemSlot):
	"""Show context menu for item actions"""
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return

	# TODO: Create proper context menu UI (Equip/Unequip/Drop/Split/Info)
	# For now, right-click does nothing to prevent accidental item loss
	print("[InventoryPanel] Right-click context menu not yet implemented for: ", item_data.item_name)


func _on_item_slot_hovered(slot: ItemSlot):
	"""Show tooltip when hovering over item"""
	if slot.is_empty or tooltip_panel == null or tooltip_label == null:
		return

	var item_data = slot.item_data
	if item_data == null:
		return

	# Build tooltip text
	var tooltip_text = "[b][color=%s]%s[/color][/b]\n" % [item_data.get_rarity_color().to_html(), item_data.item_name]
	tooltip_text += "[color=gray]%s[/color]\n\n" % item_data.get_rarity_name()
	tooltip_text += item_data.description + "\n\n"

	# Show stats
	if item_data.damage_bonus > 0:
		tooltip_text += "+%d Damage\n" % item_data.damage_bonus
	if item_data.health_bonus > 0:
		tooltip_text += "+%d Health\n" % item_data.health_bonus
	if item_data.defense_bonus > 0:
		tooltip_text += "+%d Defense\n" % item_data.defense_bonus
	if item_data.attack_speed_multiplier != 1.0:
		tooltip_text += "%.1f%% Attack Speed\n" % (item_data.attack_speed_multiplier * 100)

	tooltip_text += "\n[color=yellow]Sell: %d gold[/color]" % item_data.sell_value

	tooltip_label.text = tooltip_text
	tooltip_panel.visible = true

	# Position tooltip near mouse
	tooltip_panel.global_position = get_global_mouse_position() + Vector2(20, 20)


func _on_item_slot_unhovered():
	"""Hide tooltip"""
	if tooltip_panel:
		tooltip_panel.visible = false


func _on_close_button_pressed():
	"""Close the inventory panel"""
	hide_inventory()


func show_inventory():
	"""Show the inventory panel"""
	visible = true
	refresh_inventory()


func hide_inventory():
	"""Hide the inventory panel"""
	visible = false
	inventory_closed.emit()


func _input(event: InputEvent):
	"""Handle input for closing inventory"""
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory"):
		hide_inventory()
		get_viewport().set_input_as_handled()
