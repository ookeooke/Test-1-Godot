extends BasePanelView
class_name InventoryView

## InventoryView - Dual inventory system with tabs
## - "My Items" tab: Per-hero inventory (items picked up go here first)
## - "Shared Stash" tab: Account-wide shared storage
## Extends BasePanelView for use in FlexiblePanel

enum InventoryMode {
	HERO_INVENTORY,    # My Items - per-hero inventory
	SHARED_STASH       # Shared Stash - account-wide inventory
}

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")
@export var swap_dialog_scene: PackedScene = preload("res://scenes/ui/swap_confirmation_dialog.tscn")
@export var total_slots: int = 64  # Total inventory capacity (8×8 grid)
@export var debug_logging: bool = false  # Enable detailed inventory logging (F3 to toggle)

# Current inventory mode
var current_mode: InventoryMode = InventoryMode.HERO_INVENTORY

# Hero ID for per-hero inventory
var hero_id: String = ""  # Set by EquipmentView or hero selection

# Tab bar
@onready var tab_bar: TabBar = $MarginContainer/VBoxContainer/TabBar if has_node("MarginContainer/VBoxContainer/TabBar") else null

# Grid container (now InventoryGridContainer with absolute positioning)
@onready var inventory_grid: InventoryGridContainer = $MarginContainer/VBoxContainer/ContentContainer/InventoryGrid if has_node("MarginContainer/VBoxContainer/ContentContainer/InventoryGrid") else null

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

# Context menu
var context_menu: PopupMenu = null
var context_menu_item_id: String = ""  # Track which item the menu is for
var context_menu_slot: ItemSlot = null


func _ready():
	super._ready()
	view_name = "Inventory"

	# Setup tab bar
	_setup_tabs()

	# Create unified inventory slots
	_create_item_slots()

	# Connect signals for both inventories
	if InventoryManager:
		if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
			InventoryManager.inventory_changed.connect(_on_inventory_changed)
		if not InventoryManager.inventory_full.is_connected(_on_inventory_full):
			InventoryManager.inventory_full.connect(_on_inventory_full)

	if HeroInventoryManager:
		if not HeroInventoryManager.hero_inventory_changed.is_connected(_on_hero_inventory_changed):
			HeroInventoryManager.hero_inventory_changed.connect(_on_hero_inventory_changed)
		if not HeroInventoryManager.hero_inventory_full.is_connected(_on_hero_inventory_full):
			HeroInventoryManager.hero_inventory_full.connect(_on_hero_inventory_full)

	# Hide tooltip initially
	if tooltip_panel:
		tooltip_panel.visible = false

	# Setup responsive column adjustment
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()  # Initial setup

	# Create swap confirmation dialog
	_setup_swap_dialog()

	# Create context menu
	_setup_context_menu()


func _input(event: InputEvent):
	"""Handle F3 key for grid visualization and debug logging toggle"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			if inventory_grid:
				inventory_grid.toggle_grid_visualization()
			# Toggle debug logging
			debug_logging = !debug_logging
			print("[InventoryView] Debug logging %s" % ("enabled" if debug_logging else "disabled"))
			accept_event()


func on_view_shown():
	super.on_view_shown()
	# Set hero_id from equipment view if not already set
	if hero_id == "":
		hero_id = _get_hero_id_from_equipment_view()
		if hero_id != "" and HeroInventoryManager:
			# Register hero if not already registered
			HeroInventoryManager.register_hero(hero_id)
	refresh_view()


func refresh_view():
	super.refresh_view()
	_refresh_inventory()


func set_hero_id(new_hero_id: String):
	"""Set the hero ID for per-hero inventory tracking"""
	hero_id = new_hero_id
	if hero_id != "" and HeroInventoryManager:
		# Register hero if not already registered
		HeroInventoryManager.register_hero(hero_id)
	# Refresh if currently viewing hero inventory
	if current_mode == InventoryMode.HERO_INVENTORY:
		_refresh_inventory()


func _create_item_slots():
	"""Create unified inventory slots - all items in one grid"""
	if inventory_grid == null:
		return

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
	"""Refresh all inventory slots from current inventory mode (hero or shared stash)"""
	if debug_logging:
		var mode_name = "My Items" if current_mode == InventoryMode.HERO_INVENTORY else "Shared Stash"
		print("[InventoryView] 🔄 Refreshing inventory (%s)..." % mode_name)

	# Validate managers exist
	if current_mode == InventoryMode.HERO_INVENTORY and not HeroInventoryManager:
		if debug_logging:
			print("[InventoryView] ❌ HeroInventoryManager not found!")
		return
	elif current_mode == InventoryMode.SHARED_STASH and not InventoryManager:
		if debug_logging:
			print("[InventoryView] ❌ InventoryManager not found!")
		return

	# Clear all slots first and reset occupation states
	for slot in item_slots:
		slot.clear_slot()
		slot.is_root_slot = true
		slot.occupied_by_item_id = ""
		# Force visibility and mouse filter reset
		slot.visible = true
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		# Reset scale from abandoned hover tweens (fixes border thickness artifacts)
		slot.scale = Vector2(1.0, 1.0)
		# Force complete style reset using cached default (prevents border artifacts)
		if slot.has_method("_restore_default_style"):
			slot._restore_default_style()
		if slot.margin_container:
			slot.margin_container.add_theme_constant_override("margin_left", 4)
			slot.margin_container.add_theme_constant_override("margin_top", 4)
			slot.margin_container.add_theme_constant_override("margin_right", 4)
			slot.margin_container.add_theme_constant_override("margin_bottom", 4)

	# Get ALL items from current inventory mode
	var all_items: Array
	if current_mode == InventoryMode.HERO_INVENTORY:
		all_items = HeroInventoryManager.get_all_items(hero_id)
	else:  # SHARED_STASH
		all_items = InventoryManager.get_all_items()

	if debug_logging:
		print("[InventoryView] Found %d items in inventory" % all_items.size())

	# Place items using spatial grid positions
	for item_info in all_items:
		var item_id = item_info.item_id
		var item_data = item_info.item_data

		# Get item's grid position from appropriate manager
		var pos: Dictionary
		if current_mode == InventoryMode.HERO_INVENTORY:
			pos = HeroInventoryManager.get_grid_position(hero_id, item_id)
		else:  # SHARED_STASH
			pos = InventoryManager.get_item_position(item_id)

		if pos.x == -1 or pos.y == -1:
			if debug_logging:
				print("[InventoryView] Warning: Item not placed in grid: ", item_id)
			continue

		# Find the root slot for this item
		var root_slot = _get_slot_at_position(pos.x, pos.y)
		if root_slot == null:
			if debug_logging:
				print("[InventoryView] Warning: No slot found at position (%d, %d)" % [pos.x, pos.y])
			continue

		# Set the root slot
		root_slot.set_item(item_id, item_info.quantity, item_info.upgrade_level)
		root_slot.is_root_slot = true
		if debug_logging:
			print("[InventoryView] Placed item '%s' in slot at (%d, %d)" % [item_id, pos.x, pos.y])

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
	"""Update info labels for current inventory mode"""
	# Update gold label
	if gold_label:
		var gold = SaveManager.get_gems()
		gold_label.text = "Gold: %d" % gold

	# Update slots label based on current mode
	if slots_label:
		var all_items: Array
		var label_text: String

		if current_mode == InventoryMode.HERO_INVENTORY:
			if HeroInventoryManager and hero_id != "":
				all_items = HeroInventoryManager.get_all_items(hero_id)
				label_text = "My Items: %d / %d" % [all_items.size(), total_slots]
			else:
				label_text = "My Items: 0 / %d" % total_slots
		else:  # SHARED_STASH
			if InventoryManager:
				all_items = InventoryManager.get_all_items()
				label_text = "Shared Stash: %d / %d" % [all_items.size(), total_slots]
			else:
				label_text = "Shared Stash: 0 / %d" % total_slots

		slots_label.text = label_text


func _on_inventory_changed():
	"""Called when inventory changes"""
	_refresh_inventory()


func _on_item_slot_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is left-clicked - auto-equip for mobile, Ctrl+click for PC"""

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
			pass  # PC without Ctrl - show info only
	else:
		# Just show info for other items
		pass


func _on_item_slot_right_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is right-clicked"""
	# Show context menu (sell, drop, etc.)
	_show_item_context_menu(item_id, slot)


func _show_item_context_menu(item_id: String, slot: ItemSlot):
	"""Show context menu for item actions"""
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return

	if context_menu == null:
		print("[InventoryView] Error: Context menu not initialized")
		return

	# Store context for when menu item is selected
	context_menu_item_id = item_id
	context_menu_slot = slot

	# Enable/disable menu items based on context
	var can_equip = item_data.equip_slot != ItemData.EquipSlot.NONE
	context_menu.set_item_disabled(0, not can_equip)  # Equip option

	# Update transfer menu text based on current mode
	var transfer_text: String
	if current_mode == InventoryMode.HERO_INVENTORY:
		transfer_text = "📦 Transfer to Shared Stash"
	else:
		transfer_text = "📦 Transfer to My Items"
	context_menu.set_item_text(3, transfer_text)

	# Disable transfer if hero_id is not set (can't transfer without knowing which hero)
	var can_transfer = hero_id != "" and HeroInventoryManager != null and InventoryManager != null
	context_menu.set_item_disabled(3, not can_transfer)

	# Show menu at mouse position
	context_menu.position = get_viewport().get_mouse_position()
	context_menu.popup()


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

	# Position tooltip near mouse with bounds checking
	var mouse_pos = get_global_mouse_position()
	var offset = Vector2(20, 20)
	var tooltip_pos = mouse_pos + offset

	# Get viewport size and tooltip size
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = tooltip_panel.size

	# Clamp to viewport bounds (prevent clipping off screen)
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = mouse_pos.x - tooltip_size.x - 20  # Show on left instead
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 10  # Push up

	tooltip_panel.global_position = tooltip_pos


func _on_item_slot_unhovered():
	"""Hide tooltip"""
	if tooltip_panel:
		tooltip_panel.visible = false


func _try_auto_equip_item(item_id: String, item_data: ItemData):
	"""Try to auto-equip an item when tapped (mobile-friendly)"""
	# Get hero_id from associated EquipmentView
	var hero_id_val = _get_hero_id_from_equipment_view()
	if hero_id_val == "":
		print("[InventoryView] Error: Could not find associated hero ID")
		return

	# Determine which slot to equip to
	var slot_name = _get_slot_name_for_item(item_data)
	if slot_name == "":
		print("[InventoryView] Error: Could not determine slot for item")
		return

	# Check if there's already an item equipped in this slot
	var equipped_item_id = HeroEquipmentRegistry.get_equipped_item(hero_id_val, slot_name)

	if equipped_item_id != "":
		# Item already equipped in this slot - show swap confirmation
		_show_swap_confirmation(item_id, item_data, equipped_item_id, slot_name, hero_id_val)
	else:
		# No item equipped - equip from appropriate inventory
		var success = false

		if current_mode == InventoryMode.HERO_INVENTORY and HeroInventoryManager:
			# TODO: Implement hero inventory equip logic
			# For now, items in hero inventory can't be equipped directly
			print("[InventoryView] Warning: Equipping from hero inventory not yet implemented")
		elif current_mode == InventoryMode.SHARED_STASH and InventoryManager:
			success = InventoryManager.equip_item_atomic(hero_id_val, slot_name, item_id)

		if success:
			pass  # Success
		else:
			pass  # Failure


func _get_slot_name_for_item(item_data: ItemData) -> String:
	"""Get the equipment slot name for an item"""
	match item_data.equip_slot:
		ItemData.EquipSlot.WEAPON:
			# Always equip weapons to left hand by default
			# TODO: Add two-handed weapon logic later
			return "hand_left"
		ItemData.EquipSlot.HELMET:
			return "helmet"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY:
			# For accessories, find first empty slot or use slot 1
			var hero_id_val = _get_hero_id_from_equipment_view()
			if hero_id_val != "":
				var acc1 = HeroEquipmentRegistry.get_equipped_item(hero_id_val, "accessory_1")
				if acc1 == "":
					return "accessory_1"
				else:
					return "accessory_2"
			return "accessory_1"
	return ""


func _setup_tabs():
	"""Setup tab bar with My Items and Shared Stash tabs"""
	if not tab_bar:
		return

	# Add tabs
	tab_bar.add_tab("🎒 My Items")
	tab_bar.add_tab("🏦 Shared Stash")

	# Set initial tab
	tab_bar.current_tab = current_mode

	# Connect tab changed signal
	if not tab_bar.tab_changed.is_connected(_on_tab_changed):
		tab_bar.tab_changed.connect(_on_tab_changed)


func _on_tab_changed(tab_index: int):
	"""Called when user switches between inventory tabs"""
	current_mode = tab_index as InventoryMode
	print("[InventoryView] Switched to %s" % ("My Items" if current_mode == InventoryMode.HERO_INVENTORY else "Shared Stash"))
	refresh_view()


func _on_hero_inventory_changed(hero_id: String):
	"""Called when hero inventory changes"""
	# Only refresh if viewing hero inventory and it's the current hero
	if current_mode == InventoryMode.HERO_INVENTORY and hero_id == self.hero_id:
		_refresh_inventory()


func _on_hero_inventory_full(hero_id: String, item_id: String):
	"""Called when hero inventory is full"""
	if hero_id == self.hero_id:
		print("[InventoryView] Hero inventory full for item: ", item_id)


func _setup_swap_dialog():
	"""Create and setup the swap confirmation dialog"""
	if not swap_dialog_scene:
		return

	swap_dialog = swap_dialog_scene.instantiate() as SwapConfirmationDialog
	if not swap_dialog:
		return

	# Add to scene tree
	add_child(swap_dialog)

	# Connect signals
	swap_dialog.confirmed.connect(_on_swap_confirmed)
	swap_dialog.cancelled.connect(_on_swap_cancelled)


func _setup_context_menu():
	"""Create and setup the right-click context menu"""
	context_menu = PopupMenu.new()
	context_menu.name = "ContextMenu"
	add_child(context_menu)

	# Add menu items (IDs match indices)
	context_menu.add_item("⚔️ Equip", 0)
	context_menu.add_item("💰 Sell", 1)
	context_menu.add_item("🗑️ Drop", 2)
	context_menu.add_separator()
	context_menu.add_item("📦 Transfer to...", 3)  # Will update text based on mode
	context_menu.add_separator()
	context_menu.add_item("ℹ️ Item Info", 4)
	context_menu.add_separator()
	context_menu.add_item("❌ Cancel", 5)

	# Connect signal
	context_menu.index_pressed.connect(_on_context_menu_item_selected)


func _on_context_menu_item_selected(index: int):
	"""Handle context menu item selection"""
	var item_id = context_menu_item_id
	var item_data = ItemDatabase.get_item(item_id)

	if item_data == null:
		return

	match index:
		0:  # Equip
			_try_auto_equip_item(item_id, item_data)
		1:  # Sell
			_sell_item(item_id, item_data)
		2:  # Drop
			_drop_item(item_id, item_data)
		3:  # Transfer
			_transfer_item(item_id, item_data)
		4:  # Item Info
			_show_item_info(item_id, item_data)
		5:  # Cancel
			pass  # Do nothing


func _sell_item(item_id: String, item_data: ItemData):
	"""Sell an item for gold from current inventory mode"""
	# Check if item is rare or upgraded - require confirmation
	var requires_confirmation = false
	var confirmation_reason = ""

	if item_data.rarity >= 2:  # Epic (2) or Legendary (3)
		requires_confirmation = true
		confirmation_reason = "rare (%s)" % item_data.get_rarity_name()

	# Check if item is upgraded based on current mode
	var upgrade_level = 0
	if current_mode == InventoryMode.HERO_INVENTORY and HeroInventoryManager:
		# Hero inventory doesn't track upgrade levels separately yet
		# TODO: Add upgrade tracking to HeroInventoryManager
		upgrade_level = 0
	elif current_mode == InventoryMode.SHARED_STASH and InventoryManager:
		upgrade_level = InventoryManager.get_item_upgrade_level(item_id)

	if upgrade_level > 0:
		requires_confirmation = true
		confirmation_reason += " +%d upgraded" % upgrade_level if confirmation_reason != "" else "upgraded (+%d)" % upgrade_level

	# Check if item is equipped (use getter instead of direct dictionary access)
	# DEFENSIVE: Verify item is actually equipped, not just missing from grid
	var item_pos: Dictionary
	if current_mode == InventoryMode.HERO_INVENTORY and HeroInventoryManager:
		item_pos = HeroInventoryManager.get_grid_position(hero_id, item_id)
	elif current_mode == InventoryMode.SHARED_STASH and InventoryManager:
		item_pos = InventoryManager.get_item_position(item_id)

	if item_pos.x == -1:  # Item not in grid - should be equipped
		# Verify item is actually equipped on any hero (prevents false positives from data corruption)
		var is_actually_equipped = false
		if HeroEquipmentRegistry:
			for hero_id_check in HeroEquipmentRegistry._equipment_registry.keys():
				var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id_check)
				for equipped_item_id in equipped_items.values():
					if equipped_item_id == item_id:
						is_actually_equipped = true
						break
				if is_actually_equipped:
					break

		if is_actually_equipped:
			requires_confirmation = true
			confirmation_reason += " equipped" if confirmation_reason != "" else "equipped"
		else:
			# Data corruption: item in inventory but not in grid and not equipped
			push_error("[InventoryView] Data corruption detected: item '%s' not in grid and not equipped" % item_id)

	if requires_confirmation:
		# Show confirmation dialog
		_show_sell_confirmation(item_id, item_data, confirmation_reason)
	else:
		# Sell immediately (Common/Uncommon items)
		print("[InventoryView] Selling item: %s for %d gold" % [item_data.item_name, item_data.sell_value])

		# Remove from appropriate inventory
		if current_mode == InventoryMode.HERO_INVENTORY and HeroInventoryManager:
			HeroInventoryManager.remove_item_from_hero(hero_id, item_id, 1)
		elif current_mode == InventoryMode.SHARED_STASH and InventoryManager:
			InventoryManager.sell_item(item_id)

		# Add gold
		SaveManager.add_gems(item_data.sell_value)


func _show_sell_confirmation(item_id: String, item_data: ItemData, reason: String):
	"""Show confirmation dialog before selling valuable items"""
	# Create simple ConfirmationDialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Sell Item?"
	dialog.dialog_text = "Are you sure you want to sell [b]%s[/b]?\n\nThis item is %s.\n\nYou will receive [color=yellow]%d gold[/color]." % [
		item_data.item_name,
		reason,
		item_data.sell_value
	]
	dialog.ok_button_text = "Sell"
	dialog.cancel_button_text = "Cancel"

	# Connect signals
	dialog.confirmed.connect(func():
		print("[InventoryView] Confirmed sell: %s for %d gold" % [item_data.item_name, item_data.sell_value])

		# Remove from appropriate inventory
		if current_mode == InventoryMode.HERO_INVENTORY and HeroInventoryManager:
			HeroInventoryManager.remove_item_from_hero(hero_id, item_id, 1)
		elif current_mode == InventoryMode.SHARED_STASH and InventoryManager:
			InventoryManager.sell_item(item_id)

		# Add gold
		SaveManager.add_gems(item_data.sell_value)

		dialog.queue_free()
	)
	dialog.cancelled.connect(func():
		print("[InventoryView] Cancelled sell: %s" % item_data.item_name)
		dialog.queue_free()
	)

	# Add to scene tree and show
	add_child(dialog)
	dialog.popup_centered()


func _drop_item(item_id: String, item_data: ItemData):
	"""Drop an item (remove from inventory permanently)"""
	print("[InventoryView] Dropping item: %s" % item_data.item_name)
	# TODO: Add confirmation dialog for Epic+ items

	# Remove from appropriate inventory
	if current_mode == InventoryMode.HERO_INVENTORY and HeroInventoryManager:
		HeroInventoryManager.remove_item_from_hero(hero_id, item_id, 1)
	elif current_mode == InventoryMode.SHARED_STASH and InventoryManager:
		InventoryManager.remove_item(item_id)


func _transfer_item(item_id: String, item_data: ItemData):
	"""Transfer an item between hero inventory and shared stash"""
	if hero_id == "":
		print("[InventoryView] Cannot transfer - no hero selected")
		return

	if not HeroInventoryManager or not InventoryManager:
		print("[InventoryView] Cannot transfer - managers not available")
		return

	var success: bool = false
	var source: String
	var destination: String

	if current_mode == InventoryMode.HERO_INVENTORY:
		# Transfer from hero inventory to shared stash
		source = "My Items"
		destination = "Shared Stash"
		success = HeroInventoryManager.transfer_to_shared_stash(hero_id, item_id, 1)
	else:
		# Transfer from shared stash to hero inventory
		source = "Shared Stash"
		destination = "My Items"
		success = HeroInventoryManager.transfer_from_shared_stash(hero_id, item_id, 1)

	if success:
		print("[InventoryView] ✅ Transferred '%s' from %s to %s" % [item_data.item_name, source, destination])
		# Refresh will happen automatically via signals
	else:
		print("[InventoryView] ❌ Failed to transfer '%s' (inventory may be full)" % item_data.item_name)
		# Show error message to user
		if slots_label:
			var original_color = slots_label.modulate
			slots_label.modulate = Color(1.0, 0.3, 0.3)  # Red
			slots_label.text = "⚠️ Transfer failed - %s full!" % destination
			await get_tree().create_timer(2.0).timeout
			slots_label.modulate = original_color
			_update_labels()


func _show_item_info(item_id: String, item_data: ItemData):
	"""Show detailed item information modal"""
	print("[InventoryView] Showing info for: %s" % item_data.item_name)
	# TODO: Create detailed item info modal
	# For now, just print to console
	print("  Description: %s" % item_data.description)
	print("  Rarity: %s" % item_data.get_rarity_name())
	print("  Sell Value: %d gold" % item_data.sell_value)


func _show_swap_confirmation(new_item_id: String, new_item_data: ItemData, old_item_id: String, slot_name: String, hero_id_val: String):
	"""Show confirmation dialog for swapping equipped item"""
	var old_item_data = ItemDatabase.get_item(old_item_id)
	if not old_item_data:
		# If can't load old item, just equip new one
		if current_mode == InventoryMode.SHARED_STASH and InventoryManager:
			InventoryManager.equip_item_atomic(hero_id_val, slot_name, new_item_id)
		return

	# Show swap confirmation dialog
	if swap_dialog:
		swap_dialog.show_dialog(new_item_id, old_item_id, slot_name)
	else:
		# Fallback: auto-swap if dialog not available
		if current_mode == InventoryMode.SHARED_STASH and InventoryManager:
			InventoryManager.equip_item_atomic(hero_id_val, slot_name, new_item_id)


func _on_swap_confirmed(new_item_id: String, slot_name: String):
	"""Handle confirmed swap from dialog"""
	var hero_id_val = _get_hero_id_from_equipment_view()
	if hero_id_val != "":
		# Equip from appropriate inventory
		if current_mode == InventoryMode.SHARED_STASH and InventoryManager:
			if InventoryManager.equip_item_atomic(hero_id_val, slot_name, new_item_id):
				pass  # Success
			else:
				pass  # Failure


func _on_swap_cancelled():
	pass  # Dialog dismissed
	"""Handle cancelled swap from dialog"""


func _get_hero_id_from_equipment_view() -> String:
	"""Get hero_id from associated EquipmentView (via DualPanelScreen)"""
	if get_tree():
		var dual_panels = get_tree().get_nodes_in_group("dual_panel_screen")
		for panel in dual_panels:
			if panel.has_method("get_left_panel"):
				var left_panel = panel.get_left_panel()
				if left_panel and left_panel.has_method("get_current_view"):
					var equipment_view = left_panel.get_current_view()
					if equipment_view and "hero_id" in equipment_view:
						return equipment_view.hero_id
	return ""


func _find_flexible_panel_with_equipment() -> FlexiblePanel:
	"""Find the FlexiblePanel that contains EquipmentView"""
	if get_tree():
		var dual_panels = get_tree().get_nodes_in_group("dual_panel_screen")
		for panel in dual_panels:
			if panel.has_method("get_left_panel"):
				return panel.get_left_panel()
	return null


func _on_viewport_resized():
	"""Adjust grid cell size based on viewport width (responsive design)"""
	if not inventory_grid:
		return

	var width = get_viewport().get_visible_rect().size.x

	# Note: InventoryGridContainer uses columns property for display purposes only
	# Actual layout is based on cell_size and item grid coordinates
	if width >= 2340:
		# Wide phone (19.5:9 aspect ratio) - more horizontal space
		inventory_grid.set_columns(9)
		if debug_logging:
			print("[InventoryView] Wide layout: 9 columns (width: %d)" % width)

	elif width >= 1920:
		# Standard (16:9 aspect ratio)
		inventory_grid.set_columns(8)
		if debug_logging:
			print("[InventoryView] Standard layout: 8 columns (width: %d)" % width)

	else:
		# Compact/tablet screens
		inventory_grid.set_columns(6)
		if debug_logging:
			print("[InventoryView] Compact layout: 6 columns (width: %d)" % width)


func _on_inventory_full(item_id: String):
	"""Show detailed notification when inventory is full"""
	# Get item details for better error message
	var item_data = ItemDatabase.get_item(item_id)
	var item_name = item_data.item_name if item_data else item_id
	var size_info = ""

	if item_data and (item_data.inventory_width > 1 or item_data.inventory_height > 1):
		size_info = " (%d×%d)" % [item_data.inventory_width, item_data.inventory_height]

	print("[InventoryView] ⚠️ Inventory full! Cannot add '%s'%s" % [item_name, size_info])

	# Show detailed error message in red temporarily
	if slots_label:
		var original_color = slots_label.modulate
		slots_label.modulate = Color(1.0, 0.3, 0.3)  # Red

		# Show helpful message with item name and size
		if size_info != "":
			slots_label.text = "⚠️ FULL! No %s space for %s" % [size_info.strip_edges(), item_name]
		else:
			slots_label.text = "⚠️ INVENTORY FULL! No space for %s" % item_name

		# Reset after 3 seconds (longer for readability)
		await get_tree().create_timer(3.0).timeout
		slots_label.modulate = original_color
		_update_labels()


func cleanup():
	"""Clean up when view is closed"""
	super.cleanup()

	# Disconnect signals to prevent memory leaks
	if InventoryManager:
		if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
			InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
		if InventoryManager.inventory_full.is_connected(_on_inventory_full):
			InventoryManager.inventory_full.disconnect(_on_inventory_full)

	if HeroInventoryManager:
		if HeroInventoryManager.hero_inventory_changed.is_connected(_on_hero_inventory_changed):
			HeroInventoryManager.hero_inventory_changed.disconnect(_on_hero_inventory_changed)
		if HeroInventoryManager.hero_inventory_full.is_connected(_on_hero_inventory_full):
			HeroInventoryManager.hero_inventory_full.disconnect(_on_hero_inventory_full)

	if tooltip_panel:
		tooltip_panel.visible = false
