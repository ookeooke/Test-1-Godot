extends BasePanelView
class_name InventoryView

## InventoryView - Unified single inventory for all items
## Mobile-first Diablo Immortal style - no category tabs
## All equipment, consumables, and materials in one grid
## Extends BasePanelView for use in FlexiblePanel

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")
@export var swap_dialog_scene: PackedScene = preload("res://scenes/ui/swap_confirmation_dialog.tscn")
@export var total_slots: int = 60  # Total inventory capacity

# Grid container
@onready var inventory_grid: GridContainer = $MarginContainer/VBoxContainer/ContentContainer/InventoryGrid if has_node("MarginContainer/VBoxContainer/ContentContainer/InventoryGrid") else null

# Info labels
@onready var slots_label: Label = $MarginContainer/VBoxContainer/FooterContainer/SlotsLabel if has_node("MarginContainer/VBoxContainer/FooterContainer/SlotsLabel") else null
@onready var gold_label: Label = $MarginContainer/VBoxContainer/FooterContainer/GoldLabel if has_node("MarginContainer/VBoxContainer/FooterContainer/GoldLabel") else null

# Item tooltip
@onready var tooltip_panel: PanelContainer = $TooltipPanel if has_node("TooltipPanel") else null
@onready var tooltip_label: RichTextLabel = $TooltipPanel/MarginContainer/TooltipLabel if has_node("TooltipPanel/MarginContainer/TooltipLabel") else null

# Item slots
var item_slots: Array[ItemSlot] = []

# Swap confirmation dialog
var swap_dialog: SwapConfirmationDialog = null


func _ready():
	super._ready()
	view_name = "Inventory"

	# Create unified inventory slots
	_create_item_slots()

	# Connect signals
	if InventoryManager:
		if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
			InventoryManager.inventory_changed.connect(_on_inventory_changed)

	# Hide tooltip initially
	if tooltip_panel:
		tooltip_panel.visible = false

	# Setup responsive column adjustment
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()  # Initial setup

	# Create swap confirmation dialog
	_setup_swap_dialog()


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	_refresh_inventory()


func _create_item_slots():
	"""Create unified inventory slots - all items in one grid"""
	if inventory_grid == null:
		return

	# Set grid columns (will be adjusted by responsive system)
	inventory_grid.columns = 8

	# Create all inventory slots with grid coordinates
	var grid_width = InventoryManager.GRID_WIDTH
	var grid_height = InventoryManager.GRID_HEIGHT

	for y in grid_height:
		for x in grid_width:
			var slot = item_slot_scene.instantiate() as ItemSlot
			var i = y * grid_width + x
			slot.slot_index = i
			slot.slot_type = "inventory"
			slot.grid_x = x
			slot.grid_y = y

			# Connect signals
			slot.item_clicked.connect(_on_item_slot_clicked)
			slot.item_right_clicked.connect(_on_item_slot_right_clicked)
			slot.mouse_entered.connect(_on_item_slot_hovered.bind(slot))
			slot.mouse_exited.connect(_on_item_slot_unhovered)

			inventory_grid.add_child(slot)
			item_slots.append(slot)


func _refresh_inventory():
	"""Refresh all inventory slots from InventoryManager (spatial grid mode)"""
	if not InventoryManager:
		return

	# Clear all slots first and reset occupation states
	for slot in item_slots:
		slot.clear_slot()
		slot.is_root_slot = true
		slot.occupied_by_item_id = ""

	# Get ALL items from inventory (all categories combined)
	var all_items = InventoryManager.get_all_items()

	# Place items using spatial grid positions
	for item_info in all_items:
		var item_id = item_info.item_id
		var item_data = item_info.item_data

		# Get item's grid position from InventoryManager
		var pos = InventoryManager.get_item_position(item_id)
		if pos.x == -1 or pos.y == -1:
			# Item not yet placed in grid - auto-place it
			if InventoryManager.auto_place_item(item_id):
				pos = InventoryManager.get_item_position(item_id)
			else:
				print("[InventoryView] Warning: Could not place item in grid: ", item_id)
				continue

		# Find the root slot for this item
		var root_slot = _get_slot_at_position(pos.x, pos.y)
		if root_slot == null:
			print("[InventoryView] Warning: No slot found at position (%d, %d)" % [pos.x, pos.y])
			continue

		# Set the root slot
		root_slot.set_item(item_id, item_info.quantity, item_info.upgrade_level)
		root_slot.is_root_slot = true

		# Mark occupied cells for multi-slot items
		for dy in range(item_data.inventory_height):
			for dx in range(item_data.inventory_width):
				if dx == 0 and dy == 0:
					continue  # Skip root cell

				var occupied_slot = _get_slot_at_position(pos.x + dx, pos.y + dy)
				if occupied_slot:
					occupied_slot.is_root_slot = false
					occupied_slot.occupied_by_item_id = item_id
					occupied_slot.update_display()

	# Update all slot displays
	for slot in item_slots:
		slot.update_display()

	# Update labels
	_update_labels()


## Get slot at specific grid coordinates
func _get_slot_at_position(x: int, y: int) -> ItemSlot:
	var grid_width = InventoryManager.GRID_WIDTH
	var index = y * grid_width + x

	if index >= 0 and index < item_slots.size():
		return item_slots[index]

	return null


func _update_labels():
	"""Update info labels"""
	# Update gold label
	if gold_label:
		var gold = SaveManager.get_gems()
		gold_label.text = "Gold: %d" % gold

	# Update slots label
	if slots_label:
		var all_items = InventoryManager.get_all_items()
		slots_label.text = "Slots: %d / %d" % [all_items.size(), total_slots]


func _on_inventory_changed():
	"""Called when inventory changes"""
	_refresh_inventory()


func _on_item_slot_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is left-clicked - auto-equip for mobile, Ctrl+click for PC"""
	print("[InventoryView] Item clicked: ", item_id)

	# Get item data
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return

	# PC: Only equip with Ctrl+Click (drag-and-drop is primary)
	# Mobile: Auto-equip on tap (drag is difficult on touch)
	var is_pc = OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
	var ctrl_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)  # Meta for Mac Command key

	# Auto-equip logic for equipment items
	if item_data.item_type == ItemData.ItemType.WEAPON or item_data.item_type == ItemData.ItemType.ARMOR:
		# PC: Only equip if Ctrl is held (otherwise rely on drag-and-drop)
		# Mobile: Always equip on tap
		if not is_pc or ctrl_held:
			_try_auto_equip_item(item_id, item_data)
		else:
			print("[InventoryView] PC: Use drag-and-drop or Ctrl+Click to equip")
	elif item_data.item_type == ItemData.ItemType.CONSUMABLE:
		# TODO: Use consumable
		print("[InventoryView] Consumable clicked - use not yet implemented")
	else:
		# Just show info for other items
		print("[InventoryView] Item clicked - showing info only")


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

	# TODO: Create proper context menu UI (Equip/Unequip/Drop/Split/Info)
	# For now, right-click does nothing to prevent accidental item loss
	print("[InventoryView] Right-click context menu not yet implemented for: ", item_data.item_name)


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


func _try_auto_equip_item(item_id: String, item_data: ItemData):
	"""Try to auto-equip an item when tapped (mobile-friendly)"""
	# Find equipment manager
	var equipment_manager = _find_equipment_manager()
	if not equipment_manager:
		print("[InventoryView] Error: Could not find EquipmentManager")
		return

	# Determine which slot to equip to
	var slot_name = _get_slot_name_for_item(item_data)
	if slot_name == "":
		print("[InventoryView] Error: Could not determine slot for item")
		return

	# Check if there's already an item equipped in this slot
	var equipped_item_id = equipment_manager.get_equipped_item(slot_name)

	if equipped_item_id != "":
		# Item already equipped in this slot - show swap confirmation
		_show_swap_confirmation(item_id, item_data, equipped_item_id, slot_name, equipment_manager)
	else:
		# No item equipped - just equip directly
		equipment_manager.equip_item(slot_name, item_id)
		print("[InventoryView] Auto-equipped %s to %s" % [item_data.item_name, slot_name])


func _get_slot_name_for_item(item_data: ItemData) -> String:
	"""Get the equipment slot name for an item"""
	match item_data.equip_slot:
		ItemData.EquipSlot.WEAPON:
			return "weapon"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY:
			# For accessories, find first empty slot or use slot 1
			var equipment_manager = _find_equipment_manager()
			if equipment_manager:
				var acc1 = equipment_manager.get_equipped_item("accessory_1")
				if acc1 == "":
					return "accessory_1"
				else:
					return "accessory_2"
			return "accessory_1"
	return ""


func _setup_swap_dialog():
	"""Create and setup the swap confirmation dialog"""
	if not swap_dialog_scene:
		print("[InventoryView] Error: No swap dialog scene configured")
		return

	swap_dialog = swap_dialog_scene.instantiate() as SwapConfirmationDialog
	if not swap_dialog:
		print("[InventoryView] Error: Could not instantiate swap dialog")
		return

	# Add to scene tree
	add_child(swap_dialog)

	# Connect signals
	swap_dialog.confirmed.connect(_on_swap_confirmed)
	swap_dialog.cancelled.connect(_on_swap_cancelled)

	print("[InventoryView] Swap dialog created and ready")


func _show_swap_confirmation(new_item_id: String, new_item_data: ItemData, old_item_id: String, slot_name: String, equipment_manager: EquipmentManager):
	"""Show confirmation dialog for swapping equipped item"""
	var old_item_data = ItemDatabase.get_item(old_item_id)
	if not old_item_data:
		# If can't load old item, just equip new one
		equipment_manager.equip_item(slot_name, new_item_id)
		return

	# Show swap confirmation dialog
	if swap_dialog:
		swap_dialog.show_dialog(new_item_id, old_item_id, slot_name)
	else:
		# Fallback: auto-swap if dialog not available
		print("[InventoryView] Warning: Swap dialog not available, auto-swapping")
		equipment_manager.equip_item(slot_name, new_item_id)


func _on_swap_confirmed(new_item_id: String, slot_name: String):
	"""Handle confirmed swap from dialog"""
	var equipment_manager = _find_equipment_manager()
	if equipment_manager:
		equipment_manager.equip_item(slot_name, new_item_id)
		print("[InventoryView] Item swapped successfully: %s to %s" % [new_item_id, slot_name])


func _on_swap_cancelled():
	"""Handle cancelled swap from dialog"""
	print("[InventoryView] Swap cancelled by user")


func _find_equipment_manager() -> EquipmentManager:
	"""Find equipment manager in the scene tree"""
	# Try to find from parent views/panels
	var node = get_parent()
	while node != null:
		if node is EquipmentView:
			return node.equipment_manager
		if node.has_method("get_current_view"):
			# This is likely a FlexiblePanel, check its views
			var panel = node
			var left_panel = _find_flexible_panel_with_equipment()
			if left_panel:
				var equipment_view = left_panel.get_current_view()
				if equipment_view and equipment_view.has_node_and_resource("equipment_manager"):
					return equipment_view.equipment_manager
		node = node.get_parent()

	# Search in scene tree for DualPanelScreen
	if get_tree():
		var dual_panels = get_tree().get_nodes_in_group("dual_panel_screen")
		for panel in dual_panels:
			if panel.has_method("get_left_panel"):
				var left_panel = panel.get_left_panel()
				if left_panel:
					var equipment_view = left_panel.get_current_view()
					if equipment_view and "equipment_manager" in equipment_view:
						return equipment_view.equipment_manager

	return null


func _find_flexible_panel_with_equipment() -> FlexiblePanel:
	"""Find the FlexiblePanel that contains EquipmentView"""
	if get_tree():
		var dual_panels = get_tree().get_nodes_in_group("dual_panel_screen")
		for panel in dual_panels:
			if panel.has_method("get_left_panel"):
				return panel.get_left_panel()
	return null


func _on_viewport_resized():
	"""Adjust grid columns based on viewport width (responsive design)"""
	if not inventory_grid:
		return

	var width = get_viewport().get_visible_rect().size.x

	if width >= 2340:
		# Wide phone (19.5:9 aspect ratio) - more horizontal space
		inventory_grid.columns = 9
		print("[InventoryView] Wide layout: 9 columns (width: %d)" % width)

	elif width >= 1920:
		# Standard (16:9 aspect ratio)
		inventory_grid.columns = 8
		print("[InventoryView] Standard layout: 8 columns (width: %d)" % width)

	else:
		# Compact/tablet screens
		inventory_grid.columns = 6
		print("[InventoryView] Compact layout: 6 columns (width: %d)" % width)


func cleanup():
	"""Clean up when view is closed"""
	super.cleanup()
	if tooltip_panel:
		tooltip_panel.visible = false
