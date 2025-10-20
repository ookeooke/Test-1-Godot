extends BasePanelView
class_name InventoryView

## InventoryView - Main inventory UI with categorized tabs
## Diablo-style grid inventory with drag-drop support
## Extends BasePanelView for use in FlexiblePanel

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")

# Tab buttons
@onready var equipment_tab: Button = $MarginContainer/VBoxContainer/TabContainer/EquipmentTab if has_node("MarginContainer/VBoxContainer/TabContainer/EquipmentTab") else null
@onready var consumables_tab: Button = $MarginContainer/VBoxContainer/TabContainer/ConsumablesTab if has_node("MarginContainer/VBoxContainer/TabContainer/ConsumablesTab") else null
@onready var materials_tab: Button = $MarginContainer/VBoxContainer/TabContainer/MaterialsTab if has_node("MarginContainer/VBoxContainer/TabContainer/MaterialsTab") else null

# Grid containers for each category
@onready var equipment_grid: GridContainer = $MarginContainer/VBoxContainer/ContentContainer/EquipmentGrid if has_node("MarginContainer/VBoxContainer/ContentContainer/EquipmentGrid") else null
@onready var consumables_grid: GridContainer = $MarginContainer/VBoxContainer/ContentContainer/ConsumablesGrid if has_node("MarginContainer/VBoxContainer/ContentContainer/ConsumablesGrid") else null
@onready var materials_grid: GridContainer = $MarginContainer/VBoxContainer/ContentContainer/MaterialsGrid if has_node("MarginContainer/VBoxContainer/ContentContainer/MaterialsGrid") else null

# Info labels
@onready var category_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/CategoryLabel if has_node("MarginContainer/VBoxContainer/HeaderContainer/CategoryLabel") else null
@onready var slots_label: Label = $MarginContainer/VBoxContainer/FooterContainer/SlotsLabel if has_node("MarginContainer/VBoxContainer/FooterContainer/SlotsLabel") else null
@onready var gold_label: Label = $MarginContainer/VBoxContainer/FooterContainer/GoldLabel if has_node("MarginContainer/VBoxContainer/FooterContainer/GoldLabel") else null

# Item tooltip
@onready var tooltip_panel: PanelContainer = $TooltipPanel if has_node("TooltipPanel") else null
@onready var tooltip_label: RichTextLabel = $TooltipPanel/MarginContainer/TooltipLabel if has_node("TooltipPanel/MarginContainer/TooltipLabel") else null

# Current state
var current_category: String = "equipment"
var item_slots: Dictionary = {}  # {category: Array[ItemSlot]}


func _ready():
	super._ready()
	view_name = "Inventory"

	# Initialize item slot arrays
	item_slots["equipment"] = []
	item_slots["consumables"] = []
	item_slots["materials"] = []

	# Create item slots for each category
	_create_item_slots()

	# Connect signals
	if InventoryManager:
		if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
			InventoryManager.inventory_changed.connect(_on_inventory_changed)

	# Set up tab buttons
	if equipment_tab:
		equipment_tab.pressed.connect(_on_equipment_tab_pressed)
	if consumables_tab:
		consumables_tab.pressed.connect(_on_consumables_tab_pressed)
	if materials_tab:
		materials_tab.pressed.connect(_on_materials_tab_pressed)

	# Hide tooltip initially
	if tooltip_panel:
		tooltip_panel.visible = false

	# Show equipment tab by default
	_switch_to_category("equipment")


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	_refresh_inventory()


func _create_item_slots():
	"""Create ItemSlot instances for each category"""
	# Equipment slots
	var equipment_count = InventoryManager.max_slots.get("equipment", 20)
	_create_slots_for_category("equipment", equipment_grid, equipment_count, 5)

	# Consumables slots
	var consumables_count = InventoryManager.max_slots.get("consumables", 15)
	_create_slots_for_category("consumables", consumables_grid, consumables_count, 5)

	# Materials slots
	var materials_count = InventoryManager.max_slots.get("materials", 30)
	_create_slots_for_category("materials", materials_grid, materials_count, 6)


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


func _refresh_inventory():
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

	# Fill consumables slots
	var consumables_items = InventoryManager.get_items_by_category("consumables")
	_fill_category_slots("consumables", consumables_items)

	# Fill materials slots
	var materials_items = InventoryManager.get_items_by_category("materials")
	_fill_category_slots("materials", materials_items)

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

	# Hide all grids
	if equipment_grid:
		equipment_grid.visible = (category == "equipment")
	if consumables_grid:
		consumables_grid.visible = (category == "consumables")
	if materials_grid:
		materials_grid.visible = (category == "materials")

	# Update category label
	if category_label:
		category_label.text = category.capitalize() + " Inventory"

	# Update slots label
	_update_labels()


func _update_labels():
	"""Update info labels"""
	# Update gold label
	if gold_label:
		var gold = SaveManager.get_currency()
		gold_label.text = "Gold: %d" % gold

	# Update slots label
	if slots_label:
		var category_items = InventoryManager.get_items_by_category(current_category)
		var max_slots = InventoryManager.max_slots.get(current_category, 20)
		slots_label.text = "Slots: %d / %d" % [category_items.size(), max_slots]


func _on_inventory_changed():
	"""Called when inventory changes"""
	_refresh_inventory()


func _on_equipment_tab_pressed():
	_switch_to_category("equipment")


func _on_consumables_tab_pressed():
	_switch_to_category("consumables")


func _on_materials_tab_pressed():
	_switch_to_category("materials")


func _on_item_slot_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is left-clicked"""
	print("[InventoryView] Item clicked: ", item_id)
	# TODO: Show item details, use consumable, etc.


func _on_item_slot_right_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is right-clicked"""
	print("[InventoryView] Item right-clicked: ", item_id)
	# Show context menu (sell, drop, etc.)
	_show_item_context_menu(item_id, slot)


func _show_item_context_menu(item_id: String, slot: ItemSlot):
	"""Show context menu for item actions"""
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return

	# For now, just sell the item
	var confirm = "Sell %s for %d gold?" % [item_data.item_name, item_data.sell_value]
	print(confirm)

	# TODO: Create proper context menu UI
	# For now, auto-sell on right-click (temporary)
	InventoryManager.sell_item(item_id, 1)


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


func cleanup():
	"""Clean up when view is closed"""
	super.cleanup()
	if tooltip_panel:
		tooltip_panel.visible = false
