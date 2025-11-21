extends BasePanelView
class_name InventoryView

## InventoryView - Simple hero inventory display
## Shows only the current hero's inventory (single grid)
## Extends BasePanelView for use in FlexiblePanel
##
## ⚠️ ARCHITECTURE: Static Grid + ItemSprite Overlay (Diablo 2 / Path of Exile style)
## - ItemSlots: Static 8×8 grid (never modified, no item data)
## - ItemSprites: Render items as overlays on top (z_index=10)
## - See item_sprite.gd for full architecture explanation

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")
@export var swap_dialog_scene: PackedScene = preload("res://scenes/ui/swap_confirmation_dialog.tscn")
@export var total_slots: int = 64 # Total inventory capacity (8×8 grid)

# Preload ItemSprite for overlay rendering
const ItemSpriteScript = preload("res://scripts/ui/item_sprite.gd")
@export var debug_logging: bool = false # Enable detailed inventory logging (F3 to toggle)

# Responsive layout breakpoints (screen width in pixels)
const BREAKPOINT_WIDE_PHONE: int = 2340 # 19.5:9 aspect ratio (9 columns)
const BREAKPOINT_STANDARD: int = 1920 # 16:9 aspect ratio (8 columns)
# Below BREAKPOINT_STANDARD = compact/tablet (6 columns)

# Hero ID for per-hero inventory
var hero_id: String = "" # Set by EquipmentView or hero selection

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
var context_menu_item_uuid: String = "" # Track which item the menu is for
var context_menu_slot: ItemSlot = null


func _ready():
	super._ready()
	view_name = "Inventory"

	# Create inventory slots
	_create_item_slots()

	# Connect signals for hero inventory
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
	_on_viewport_resized() # Initial setup

	# Create swap confirmation dialog
	_setup_swap_dialog()

	# Create context menu
	_setup_context_menu()

	# Create sort button
	_setup_sort_button()


func _input(event: InputEvent):
	"""Handle keyboard shortcuts: F3 (grid debug)"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			# Toggle grid visualization
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

	# Refresh inventory
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
	"""Refresh all inventory slots from hero inventory"""
	if debug_logging:
		print("[InventoryView] 🔄 Refreshing inventory (My Items)...")

	# Validate manager exists
	if not HeroInventoryManager:
		if debug_logging:
			print("[InventoryView] ❌ HeroInventoryManager not found!")
		return
		
	# Get container directly from registry
	var container = InventoryRegistry.get_container(hero_id)
	if not container:
		if debug_logging:
			print("[InventoryView] ❌ No container found for hero: ", hero_id)
		return

	# REFACTOR: Static Grid + Item Overlay Architecture
	# Grid slots remain STATIC (never modified)
	# Items are rendered as ItemSprite overlays on top of the grid

	# CRITICAL FIX: Clear old item sprites SYNCHRONOUSLY (not queue_free!)
	# queue_free() is async - nodes aren't freed immediately, causing race conditions
	# If user drags during refresh, they interact with "ghost" sprites queued for deletion
	if inventory_grid and inventory_grid.item_layer:
		for child in inventory_grid.item_layer.get_children():
			child.free() # Synchronous deletion (Path of Exile / Diablo 2 style)

	# Get ALL items from container
	var all_items: Array[ItemInstance] = container.get_all_items()

	# DEBUG: Log hero inventory details
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[InventoryView] 🎒 Refreshing Gear Screen Inventory")
	print("  Hero ID: '%s' (type: %s)" % [hero_id, typeof(hero_id)])
	print("  Items Found: %d" % all_items.size())

	if debug_logging:
		print("[InventoryView] Found %d items in inventory" % all_items.size())

	# Track filtered items
	var displayed_count = 0
	var filtered_count = 0

	# Create ItemSprite overlays for each item
	for item_instance in all_items:
		var uuid = item_instance.uuid
		var item_id = item_instance.item_id

		# Get item's grid position from container
		var pos: Vector2i = container.get_item_position(uuid)

		if pos.x == -1 or pos.y == -1:
			filtered_count += 1
			print("  ⚠️  FILTERED: %s (UUID: %s, no grid position)" % [item_id, uuid])
			if debug_logging:
				print("[InventoryView] Warning: Item not placed in grid: ", item_id)
			continue

		displayed_count += 1

		# Create ItemSprite overlay
		var item_sprite = ItemSprite.new()
		item_sprite.hero_id = hero_id # Set which inventory this belongs to

		# 🆕 UUID SYSTEM: Pass ItemInstance directly (skip animation during refresh)
		item_sprite.set_item(item_instance, true)  # skip_animation=true prevents mass bouncing
		item_sprite.set_grid_position(pos.x, pos.y)

		# 🔧 FIX CRITICAL: Connect ItemSprite signals for click interactions
		# ItemSprite blocks input to ItemSlot (mouse_filter = STOP), so we must
		# connect to ItemSprite's signals instead of ItemSlot's
		item_sprite.item_tapped.connect(_on_item_sprite_tapped)
		item_sprite.item_long_pressed.connect(_on_item_sprite_long_pressed)

		# Add to item layer (renders on top of grid)
		if inventory_grid and inventory_grid.item_layer:
			inventory_grid.item_layer.add_child(item_sprite)

			if debug_logging:
				print("[InventoryView] Created ItemSprite for '%s' at (%d, %d)" % [item_id, pos.x, pos.y])

	# Refresh debug grid visualization
	if inventory_grid:
		inventory_grid.refresh_items_display()

	# Update labels
	_update_labels()

	# DEBUG: Summary
	print("  ✅ Displayed: %d items" % displayed_count)
	print("  ❌ Filtered: %d items (no grid position)" % filtered_count)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


## Get slot at specific grid coordinates
func _get_slot_at_position(x: int, y: int) -> ItemSlot:
	var grid_width = InventoryManager.GRID_WIDTH
	var index = y * grid_width + x

	if index >= 0 and index < item_slots.size():
		return item_slots[index]

	return null


func _update_labels():
	"""Update info labels for hero inventory"""
	# Update gold label
	if gold_label:
		var gold = SaveManager.get_gems()
		gold_label.text = "Gold: %d" % gold

	# Update slots label for hero inventory
	if slots_label:
		if HeroInventoryManager and hero_id != "":
			var container = InventoryRegistry.get_container(hero_id)
			var count = container.get_all_items().size() if container else 0
			slots_label.text = "My Items: %d / %d" % [count, total_slots]
		else:
			slots_label.text = "My Items: 0 / %d" % total_slots


func _on_inventory_changed():
	"""Called when shared stash inventory changes (no longer used in simplified view)"""
	# This handler is no longer needed since we only show hero inventory
	pass


func _on_item_slot_clicked(_item: ItemInstance, slot: ItemSlot):
	"""Called when an item slot is left-clicked - auto-equip for mobile, Ctrl+click for PC"""

	# With ItemSprite overlay, this might not be called directly for items,
	# but ItemSprite passes input to slots if configured correctly.
	# Actually, ItemSprite handles its own input usually.
	# But ItemSlot has signals connected.

	# If slot is empty, ignore
	if slot.is_empty:
		return

	var item_instance = slot.item_instance
	if not item_instance:
		return

	var item_data = item_instance.get_data()
	if not item_data:
		return

	# PC: Only equip with Ctrl+Click (drag-and-drop is primary)
	# Mobile: Auto-equip on tap (drag is difficult on touch)
	var is_pc = OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
	var ctrl_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) # Meta for Mac Command key

	# Auto-equip logic for equipment items
	if item_data.item_type == ItemData.ItemType.WEAPON or item_data.item_type == ItemData.ItemType.ARMOR:
		# PC: Only equip if Ctrl is held (otherwise rely on drag-and-drop)
		# Mobile: Always equip on tap
		if not is_pc or ctrl_held:
			_try_auto_equip_item(item_instance)
		else:
			pass # PC without Ctrl - show info only
	else:
		# Just show info for other items
		pass


func _on_item_slot_right_clicked(_item: ItemInstance, slot: ItemSlot):
	"""Called when an item slot is right-clicked"""
	# Show context menu (sell, drop, etc.)
	if slot.item_instance:
		_show_item_context_menu(slot.item_instance, slot)


func _on_item_sprite_tapped(item_sprite: ItemSprite):
	"""🔧 FIX CRITICAL: Adapter for ItemSprite tap events

	ItemSprite blocks input to ItemSlot (overlay architecture), so we connect
	to ItemSprite signals and forward to existing click logic.

	This enables:
	- Auto-equip on mobile (tap to equip)
	- Auto-equip on PC (Ctrl+Click to equip)
	"""
	if not item_sprite or not item_sprite.item_instance:
		return

	var item_instance = item_sprite.item_instance
	var item_data = item_instance.get_data()
	if not item_data:
		return

	# PC: Only equip with Ctrl+Click (drag-and-drop is primary)
	# Mobile: Auto-equip on tap (drag is difficult on touch)
	var is_pc = OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
	var ctrl_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) # Meta for Mac Command key

	# Auto-equip logic for equipment items
	if item_data.item_type == ItemData.ItemType.WEAPON or item_data.item_type == ItemData.ItemType.ARMOR:
		# PC: Only equip if Ctrl is held (otherwise rely on drag-and-drop)
		# Mobile: Always equip on tap
		if not is_pc or ctrl_held:
			_try_auto_equip_item(item_instance)
		else:
			# PC without Ctrl - just show tooltip (already shown by ItemSprite hover)
			pass


func _on_item_sprite_long_pressed(item_sprite: ItemSprite):
	"""🔧 FIX CRITICAL: Adapter for ItemSprite long-press events

	ItemSprite blocks input to ItemSlot (overlay architecture), so we connect
	to ItemSprite signals and forward to context menu logic.

	This enables:
	- Right-click context menu on PC
	- Long-press context menu on mobile
	"""
	if not item_sprite or not item_sprite.item_instance:
		return

	# Show context menu (sell, transfer, etc.)
	_show_item_context_menu(item_sprite.item_instance, null)


func _show_item_context_menu(item_instance: ItemInstance, slot: ItemSlot):
	"""Show context menu for item actions"""
	var item_data = item_instance.get_data()
	if item_data == null:
		return

	if context_menu == null:
		print("[InventoryView] Error: Context menu not initialized")
		return

	# Store context for when menu item is selected
	context_menu_item_uuid = item_instance.uuid
	context_menu_slot = slot

	# Enable/disable menu items based on context
	var can_equip = item_data.equip_slot != ItemData.EquipSlot.NONE
	context_menu.set_item_disabled(0, not can_equip) # Equip option

	# Set transfer menu text (always hero inventory -> shared stash)
	context_menu.set_item_text(3, "📦 Transfer to Shared Stash")

	# Disable transfer if hero_id is not set (can't transfer without knowing which hero)
	var can_transfer = hero_id != "" and InventoryRegistry.get_container("stash") != null
	context_menu.set_item_disabled(3, not can_transfer)

	# Show menu at mouse position
	context_menu.position = get_viewport().get_mouse_position()
	context_menu.popup()


func _on_item_slot_hovered(slot: ItemSlot):
	"""Show tooltip when hovering over item"""
	if slot.is_empty or tooltip_panel == null or tooltip_label == null:
		return

	# Use slot's _generate_tooltip method if available or build it here
	# ItemSlot has _generate_tooltip but it returns string.
	# We can use that.
	var tooltip_text = slot._generate_tooltip()
	if tooltip_text == "":
		return
		
	# Add sell value
	var item_data = slot.item_instance.get_data()
	if item_data:
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
		tooltip_pos.x = mouse_pos.x - tooltip_size.x - 20 # Show on left instead
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = viewport_size.y - tooltip_size.y - 10 # Push up

	tooltip_panel.global_position = tooltip_pos


func _on_item_slot_unhovered():
	"""Hide tooltip"""
	if tooltip_panel:
		tooltip_panel.visible = false


func _try_auto_equip_item(item_instance: ItemInstance):
	"""Try to auto-equip an item when tapped (mobile-friendly)"""
	# Get hero_id from associated EquipmentView
	var hero_id_val = _get_hero_id_from_equipment_view()
	if hero_id_val == "":
		print("[InventoryView] Error: Could not find associated hero ID")
		return
		
	var item_data = item_instance.get_data()
	if not item_data: return

	# Determine which slot to equip to
	var slot_name = _get_slot_name_for_item(item_data)
	if slot_name == "":
		print("[InventoryView] Error: Could not determine slot for item")
		return

	# Use ItemTransactionService to equip
	# It handles swapping automatically if implemented correctly
	ItemTransactionService.equip_item(hero_id_val, item_instance.uuid, slot_name)


func _get_slot_name_for_item(item_data: ItemData) -> String:
	"""Get the equipment slot name for an item (uses shared helper)"""
	# For accessories, check if we should use slot 2 instead
	if item_data.equip_slot == ItemData.EquipSlot.ACCESSORY:
		var hero_id_val = _get_hero_id_from_equipment_view()
		if hero_id_val != "":
			var acc1 = HeroEquipmentRegistry.get_equipped_item(hero_id_val, "accessory_1")
			if acc1 != null:  # Check for ItemInstance (get_equipped_item returns ItemInstance or null)
				return "accessory_2" # First slot occupied, use second

	# Use shared static helper to avoid code duplication
	return ItemData.equip_slot_to_name(item_data.equip_slot)


func _on_hero_inventory_changed(hero_id: String):
	"""Called when hero inventory changes"""
	# Only refresh if it's the current hero
	if hero_id == self.hero_id:
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
	context_menu.add_item("📦 Transfer to...", 3) # Will update text based on mode
	context_menu.add_separator()
	context_menu.add_item("ℹ️ Item Info", 4)
	context_menu.add_separator()
	context_menu.add_item("❌ Cancel", 5)

	# Connect signal
	context_menu.index_pressed.connect(_on_context_menu_item_selected)


func _setup_sort_button():
	"""Create and add a sort button to the footer"""
	# Get the FooterContainer (HBoxContainer with SlotsLabel and GoldLabel)
	var footer_container = $MarginContainer/VBoxContainer/FooterContainer if has_node("MarginContainer/VBoxContainer/FooterContainer") else null

	if not footer_container:
		print("[InventoryView] Warning: FooterContainer not found, cannot add sort button")
		return

	# Create sort button
	var sort_button = Button.new()
	sort_button.name = "SortButton"
	sort_button.text = "🔄 Sort"
	sort_button.tooltip_text = "Organize inventory by size, category, and rarity"
	sort_button.custom_minimum_size = Vector2(80, 0)  # Minimum width

	# Add button to footer (will appear after labels)
	footer_container.add_child(sort_button)

	# Connect signal
	sort_button.pressed.connect(_on_sort_button_pressed)

	print("[InventoryView] Sort button created and added to footer")


func _on_sort_button_pressed():
	"""Handle sort button press - organize inventory"""
	print("[InventoryView] 📦 Sort button pressed")

	# Get the hero's inventory container
	var container = InventoryRegistry.get_container(hero_id)
	if not container:
		print("[InventoryView] ❌ Cannot sort: Container not found for hero '%s'" % hero_id)
		return

	# Call sort_inventory() on the container
	if container.sort_inventory():
		print("[InventoryView] ✅ Inventory sorted successfully!")
		# Optional: Play success sound effect here
		# AudioManager.play_sound("ui_sort_success")
	else:
		print("[InventoryView] ❌ Sort failed (inventory may be unchanged)")
		# Optional: Show error feedback to user
		# show_error_tooltip("Failed to sort inventory")


func _on_context_menu_item_selected(index: int):
	"""Handle context menu item selection"""
	var uuid = context_menu_item_uuid
	if uuid == "": return
	
	var container = InventoryRegistry.get_container(hero_id)
	if not container: return
	
	var item_instance = container.remove_item(uuid) # Temporarily remove to get data? No, get from container.
	# Actually, we should just get it.
	# But for actions like sell/drop/transfer, we will act on the UUID.
	
	# Re-fetch item to ensure it still exists
	item_instance = container._items.get(uuid)
	if not item_instance:
		return
		
	# var item_data = item_instance.get_data() # Unused

	match index:
		0: # Equip
			_try_auto_equip_item(item_instance)
		1: # Sell
			_sell_item(item_instance)
		2: # Drop
			_drop_item(item_instance)
		3: # Transfer
			_transfer_item(item_instance)
		4: # Item Info
			_show_item_info(item_instance)
		5: # Cancel
			pass # Do nothing


func _sell_item(item_instance: ItemInstance):
	"""Sell an item for gold from hero inventory"""
	var item_data = item_instance.get_data()
	if not item_data: return
	
	# Check if item is rare or upgraded - require confirmation
	var requires_confirmation = false
	var confirmation_reason = ""

	if item_data.rarity >= 2: # Epic (2) or Legendary (3)
		requires_confirmation = true
		confirmation_reason = "rare (%s)" % item_data.get_rarity_name()

	if item_instance.upgrade_level > 0:
		requires_confirmation = true
		confirmation_reason += " upgraded (+%d)" % item_instance.upgrade_level

	if requires_confirmation:
		# Show confirmation dialog
		_show_sell_confirmation(item_instance, confirmation_reason)
	else:
		# Sell immediately (Common/Uncommon items)
		print("[InventoryView] Selling item: %s for %d gold" % [item_data.item_name, item_data.sell_value])

		# Remove from hero inventory
		var container = InventoryRegistry.get_container(hero_id)
		if container:
			container.remove_item(item_instance.uuid)

		# Add gold
		SaveManager.add_gems(item_data.sell_value)


func _show_sell_confirmation(item_instance: ItemInstance, reason: String):
	"""Show confirmation dialog before selling valuable items"""
	var item_data = item_instance.get_data()
	
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

		# Remove from hero inventory
		var container = InventoryRegistry.get_container(hero_id)
		if container:
			container.remove_item(item_instance.uuid)

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


func _drop_item(item_instance: ItemInstance):
	"""Drop an item (remove from hero inventory permanently)"""
	var item_data = item_instance.get_data()
	print("[InventoryView] Dropping item: %s" % item_data.item_name)
	# TODO: Add confirmation dialog for Epic+ items

	# Remove from hero inventory
	var container = InventoryRegistry.get_container(hero_id)
	if container:
		container.remove_item(item_instance.uuid)


func _transfer_item(item_instance: ItemInstance):
	"""Transfer an item from hero inventory to shared stash"""
	if hero_id == "":
		print("[InventoryView] Cannot transfer - no hero selected")
		return

	# Transfer from hero inventory to shared stash
	var success = ItemTransactionService.move_item(item_instance.uuid, hero_id, "stash")

	if success:
		var item_data = item_instance.get_data()
		print("[InventoryView] ✅ Transferred '%s' from My Items to Shared Stash" % item_data.item_name)
		# Refresh will happen automatically via signals
	else:
		var item_data = item_instance.get_data()
		print("[InventoryView] ❌ Failed to transfer '%s' (shared stash may be full)" % item_data.item_name)
		# Show error message to user
		if slots_label:
			var original_color = slots_label.modulate
			slots_label.modulate = Color(1.0, 0.3, 0.3) # Red
			slots_label.text = "⚠️ Transfer failed - Shared Stash full!"
			await get_tree().create_timer(2.0).timeout
			slots_label.modulate = original_color
			_update_labels()


func _show_item_info(item_instance: ItemInstance):
	"""Show detailed item information modal"""
	var item_data = item_instance.get_data()
	print("[InventoryView] Showing info for: %s" % item_data.item_name)
	# TODO: Create detailed item info modal
	# For now, just print to console
	print("  Description: %s" % item_data.description)
	print("  Rarity: %s" % item_data.get_rarity_name())
	print("  Sell Value: %d gold" % item_data.sell_value)


func _show_swap_confirmation(_new_item_id: String, _new_item_data: ItemData, _old_item_id: String, _slot_name: String, _hero_id_val: String):
	"""Show confirmation dialog for swapping equipped item"""
	# TODO: Implement equipping from hero inventory
	print("[InventoryView] Warning: Equipping from hero inventory not yet implemented")
	return


func _on_swap_confirmed(_new_item_id: String, _slot_name: String):
	"""Handle confirmed swap from dialog"""
	# TODO: Implement equipping from hero inventory
	print("[InventoryView] Warning: Equipping from hero inventory not yet implemented")


func _on_swap_cancelled():
	pass # Dialog dismissed
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
	if width >= BREAKPOINT_WIDE_PHONE:
		# Wide phone (19.5:9 aspect ratio) - more horizontal space
		inventory_grid.set_columns(9)
		if debug_logging:
			print("[InventoryView] Wide layout: 9 columns (width: %d)" % width)

	elif width >= BREAKPOINT_STANDARD:
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
		slots_label.modulate = Color(1.0, 0.3, 0.3) # Red

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
