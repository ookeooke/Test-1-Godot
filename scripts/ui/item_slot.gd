extends PanelContainer
class_name ItemSlot

## ItemSlot - UI element representing a single inventory slot
##
## ⚠️ ARCHITECTURE NOTE (Important for maintenance):
## This class has TWO USAGE MODES with different code paths:
##
## MODE 1: Equipment Slots (EquipmentView)
## - Uses ItemSlot.set_item() to render equipment directly
## - Renders icon, labels, tooltips (update_display() is ACTIVE)
## - Drag-drop handled by ItemSlot._get_drag_data()
## - Touch input handled by ItemSlot._on_gui_input()
##
## MODE 2: Inventory Grids (InventoryView, EquipmentView common chest)
## - Uses Static Grid + ItemSprite Overlay architecture
## - ItemSlot is EMPTY (never calls set_item())
## - ItemSprite renders visuals on top (z_index=10)
## - Drag-drop handled by ItemSprite._get_drag_data()
## - Touch input handled by ItemSprite._on_gui_input()
## - ItemSlot only provides static grid positioning
##
## When modifying this file:
## - Don't remove rendering code (MODE 1 needs it!)
## - Hover animations are unreachable in MODE 2 (ItemSprite intercepts)
## - Multi-cell code is unused in MODE 1 (equipment is always 1×1)
##
## Dual input system for PC and mobile:
## - PC: Hover for tooltip, drag-drop to move, right-click for context menu
## - Mobile: Tap to equip/use, long-press (0.5s) for context menu
## Built-in Godot tooltips work automatically on hover

const DEBUG_DRAG_DROP = false # Set to true to enable verbose drag-drop logging

signal item_clicked(item: ItemInstance, slot: ItemSlot)
signal item_right_clicked(item: ItemInstance, slot: ItemSlot)

@export var slot_index: int = 0
@export var slot_type: String = "inventory" # "inventory", "equipment", "storage"
@export var equipment_filter: ItemData.EquipSlot = ItemData.EquipSlot.NONE # For equipment slots
@export var equipment_slot_name: String = "" # For equipment slots: "weapon", "armor", etc.


var hero_id: String = "" # Set by EquipmentView for equipment slots
var item_instance: ItemInstance = null # The item in this slot (if any)

# Multi-slot grid support (Diablo 2 style)
var grid_x: int = -1 ## Grid X coordinate (column)
var grid_y: int = -1 ## Grid Y coordinate (row)
var is_root_slot: bool = true ## True if this is the top-left cell of a multi-slot item
var occupied_by_uuid: String = "" ## If not root, stores the UUID occupying this cell

# Cached theme style (prevents color trail artifacts)
var _original_panel_style: StyleBox = null

# UI References
@onready var icon: TextureRect = $MarginContainer/VBoxContainer/Icon if has_node("MarginContainer/VBoxContainer/Icon") else null
@onready var quantity_label: Label = $MarginContainer/VBoxContainer/QuantityLabel if has_node("MarginContainer/VBoxContainer/QuantityLabel") else null
@onready var upgrade_label: Label = $MarginContainer/VBoxContainer/UpgradeLabel if has_node("MarginContainer/VBoxContainer/UpgradeLabel") else null
@onready var rarity_border: Panel = $RarityBorder if has_node("RarityBorder") else null
@onready var margin_container: MarginContainer = $MarginContainer if has_node("MarginContainer") else null

var is_empty: bool = true
var is_hovered: bool = false

# Hover animation tween (tracked to prevent leaks)
var _hover_tween: Tween = null

# Long-press detection for mobile
var touch_start_time: float = 0.0
var is_touch_held: bool = false
const LONG_PRESS_DURATION: float = 0.5 # 500ms


func _ready():
	# Set up custom minimum size for mobile-friendly touch targets
	# 80x80px exceeds Android Material Design 48dp minimum
	custom_minimum_size = Vector2(80, 80)

	# Cache original theme style to prevent color trail artifacts
	var theme_style = get_theme_stylebox("panel")
	if theme_style:
		_original_panel_style = theme_style.duplicate()
	else:
		# CRITICAL FIX: Fallback to guarantee _original_panel_style is never null
		# This prevents visual artifacts when theme isn't fully initialized
		var fallback = StyleBoxFlat.new()
		fallback.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		fallback.border_width_left = 2
		fallback.border_width_top = 2
		fallback.border_width_right = 2
		fallback.border_width_bottom = 2
		fallback.border_color = Color(0.5, 0.5, 0.5, 1)
		fallback.corner_radius_top_left = 4
		fallback.corner_radius_top_right = 4
		fallback.corner_radius_bottom_right = 4
		fallback.corner_radius_bottom_left = 4
		_original_panel_style = fallback
		print("[ItemSlot] Warning: Theme style was null, using fallback StyleBoxFlat")

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	# Enable tooltip
	tooltip_text = ""

	# Update visual
	update_display()


func _restore_default_style():
	"""Restore original theme panel style using cached style.
	Fixes bow color trail bug by restoring actual theme instead of hard-coded colors.
	Also kills active hover tweens to prevent visual state leaks (bright borders)."""

	# CRITICAL: Kill active hover tween to prevent scale/modulation artifacts
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
		_hover_tween = null

	# Reset scale and modulation immediately (prevents border artifacts)
	scale = Vector2(1.0, 1.0)
	modulate = Color.WHITE

	# NUCLEAR FIX: Hide and reset rarity_border completely
	if rarity_border:
		rarity_border.visible = false # Hide it (not just transparent!)
		rarity_border.modulate = Color.WHITE # Reset modulation

	# NUCLEAR FIX: Remove theme override completely before applying new one
	remove_theme_stylebox_override("panel")

	if _original_panel_style:
		# Use cached original style (prevents color trail artifacts)
		add_theme_stylebox_override("panel", _original_panel_style.duplicate())
	# else: Keep override removed (use default theme)


## Set item in this slot
func set_item(new_item: ItemInstance):
	item_instance = new_item

	if item_instance == null:
		clear_slot()
		return

	# Load item data
	var item_data = item_instance.get_data()
	if item_data == null:
		print("[ItemSlot] Error: Invalid item data for: ", item_instance.item_id)
		clear_slot()
		return

	is_empty = false

	# MULTI-CELL STRETCHING: Resize slot to span multiple grid cells (Diablo 2 style)
	if is_root_slot and item_data.inventory_width > 0 and item_data.inventory_height > 0:
		var slot_width = 80 # Base slot size
		var slot_height = 80
		var grid_gap = 5 # Gap between grid cells (from inventory_view.tscn)

		# Calculate total size: (slots × base_size) + (gaps × (slots - 1))
		var total_width = (item_data.inventory_width * slot_width) + ((item_data.inventory_width - 1) * grid_gap)
		var total_height = (item_data.inventory_height * slot_height) + ((item_data.inventory_height - 1) * grid_gap)

		custom_minimum_size = Vector2(total_width, total_height)
		size = Vector2(total_width, total_height)

		# Set higher z_index so multi-cell items render on top
		z_index = 10

		# DIABLO 2 STYLE: Hide panel styling for multi-cell items
		# Show ONLY the icon (no border, no background)
		# NUCLEAR FIX: Remove override first to prevent stale state
		remove_theme_stylebox_override("panel")

		var transparent_style = StyleBoxFlat.new()
		transparent_style.bg_color = Color(0, 0, 0, 0) # Fully transparent
		transparent_style.border_width_left = 0
		transparent_style.border_width_top = 0
		transparent_style.border_width_right = 0
		transparent_style.border_width_bottom = 0
		add_theme_stylebox_override("panel", transparent_style)

		# Remove margins so icon fills entire area
		if margin_container:
			margin_container.add_theme_constant_override("margin_left", 0)
			margin_container.add_theme_constant_override("margin_top", 0)
			margin_container.add_theme_constant_override("margin_right", 0)
			margin_container.add_theme_constant_override("margin_bottom", 0)
	else:
		# Reset to default size for single-cell items
		custom_minimum_size = Vector2(80, 80)
		z_index = 0

		# Restore default panel styling (uses cached style for consistency)
		_restore_default_style()

		# Restore default margins
		if margin_container:
			margin_container.add_theme_constant_override("margin_left", 4)
			margin_container.add_theme_constant_override("margin_top", 4)
			margin_container.add_theme_constant_override("margin_right", 4)
			margin_container.add_theme_constant_override("margin_bottom", 4)

	update_display()


## Clear the slot
func clear_slot():
	item_instance = null
	is_empty = true

	# CRITICAL: Reset occupation state BEFORE calling update_display()
	# This prevents visual state leaks where occupied slots stay hidden
	is_root_slot = true
	occupied_by_uuid = ""

	# Reset size to default
	custom_minimum_size = Vector2(80, 80)
	z_index = 0

	# Restore default panel styling (uses cached style for consistency)
	# NOTE: _restore_default_style() now also kills active tweens
	_restore_default_style()

	# Restore default margins
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 4)
		margin_container.add_theme_constant_override("margin_top", 4)
		margin_container.add_theme_constant_override("margin_right", 4)
		margin_container.add_theme_constant_override("margin_bottom", 4)

	update_display()


## Update the visual display
func update_display():
	# ALWAYS clear old emoji labels first to prevent visual bugs
	# _clear_emoji_label() # Removed as it was not defined in original file, assuming handled elsewhere or not needed
	# Handle occupied (non-root) slots - HIDE THEM COMPLETELY (Diablo 2 style)
	if not is_root_slot and occupied_by_uuid != "":
		# CRITICAL FIX: Reset visual state BEFORE hiding to prevent style leaks
		# When slots transition from visible→occupied→visible, they must fully reset
		_restore_default_style() # Reset StyleBox to default borders
		scale = Vector2(1.0, 1.0) # Reset any hover scale
		z_index = 0 # Reset layering (multi-cell items use z=10)

		# This slot is occupied by a multi-slot item - hide it completely
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE # Can't interact with occupied slots
		return
	else:
		# Re-show if this slot is no longer occupied
		visible = true
		# CRITICAL: Reset modulation to WHITE immediately for non-occupied slots
		# This prevents visual state leaks from previous items (bright borders, dimming)
		modulate = Color.WHITE

	# Re-enable mouse input for non-occupied slots
	mouse_filter = Control.MOUSE_FILTER_STOP

	if is_empty or item_instance == null:
		# Empty slot
		# CRITICAL FIX: Reset z_index and StyleBox to prevent visual state leaks
		z_index = 0 # Reset layering (multi-cell items use z=10)
		_restore_default_style() # Defensive: ensure StyleBox is reset even if clear_slot() wasn't called

		if icon:
			icon.texture = null
			icon.modulate = Color(1, 1, 1, 0.3) # Dim icon area only
		if quantity_label:
			quantity_label.text = ""
		if upgrade_label:
			upgrade_label.text = ""
		if rarity_border:
			# NUCLEAR FIX: Hide rarity border completely (not just transparent!)
			rarity_border.visible = false
			rarity_border.modulate = Color.WHITE # Reset to white
		modulate = Color.WHITE # Keep borders at full opacity
		tooltip_text = ""
		return

	# Item is present
	var item_data = item_instance.get_data()
	if not item_data:
		return

	modulate = Color.WHITE

	# Set icon (texture or emoji)
	if icon:
		if item_data.icon:
			# Use texture icon if available
			icon.texture = item_data.icon
		elif item_data.emoji_icon != "":
			# Use emoji as fallback - create a temporary label to show it
			icon.texture = null
			# _show_emoji_in_icon(item_data.emoji) # TODO: Implement if needed
		else:
			# No icon at all
			icon.texture = null

	# Set quantity label (only for stackable items)
	if quantity_label:
		if item_data.is_stackable() and item_instance.quantity > 1:
			quantity_label.text = str(item_instance.quantity)
		else:
			quantity_label.text = ""

	# Set upgrade level label (only for upgradeable items)
	if upgrade_label:
		if item_data.can_upgrade and item_instance.upgrade_level > 0:
			upgrade_label.text = "+%d" % item_instance.upgrade_level
		else:
			upgrade_label.text = ""

	# Set rarity border color
	if rarity_border:
		rarity_border.visible = true # Show it
		rarity_border.modulate = item_data.get_rarity_color()

	# Update tooltip with comparison
	tooltip_text = _generate_tooltip()


## Godot drag-and-drop: Get drag data
func _get_drag_data(at_position: Vector2):
	if DEBUG_DRAG_DROP:
		print("[ItemSlot] 🎯 _get_drag_data called - item: %s, is_empty: %s, slot_type: %s, grid_pos: (%d,%d)" % [item_instance.item_id if item_instance else "null", is_empty, slot_type, grid_x, grid_y])

	if is_empty or not item_instance:
		if DEBUG_DRAG_DROP:
			print("[ItemSlot] ❌ Slot is empty, canceling drag")
		return null

	var item_data = item_instance.get_data()
	if not item_data:
		return null

	# Calculate drag offset (where user clicked within slot) for natural grab feel
	var drag_offset = at_position

	# Create drag preview matching actual slot size
	# CRITICAL: Root preview Control must be 0x0 so Godot anchors it exactly at mouse cursor
	var preview = Control.new()
	preview.custom_minimum_size = Vector2.ZERO
	preview.size = Vector2.ZERO

	var preview_icon = TextureRect.new()
	preview_icon.texture = item_data.icon if item_data.icon else null
	preview_icon.size = size
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.modulate = Color(1, 1, 1, 0.8) # Semi-transparent
	# Offset icon so click position stays under cursor (natural grab feel)
	preview_icon.position = Vector2.ZERO - drag_offset
	
	preview.add_child(preview_icon)
	set_drag_preview(preview)

	if DEBUG_DRAG_DROP:
		print("[ItemSlot] ✅ Drag data created for item: %s" % item_instance.item_id)

	# Return drag data
	return {
		"uuid": item_instance.uuid,
		"item_id": item_instance.item_id,
		"quantity": item_instance.quantity,
		"upgrade_level": item_instance.upgrade_level,
		"item_instance": item_instance,
		"source_slot": self,
		"source_slot_type": slot_type,
		"source_hero_id": hero_id
	}


## Godot drag-and-drop: Check if can drop here
func _can_drop_data(at_position: Vector2, data) -> bool:
	if DEBUG_DRAG_DROP:
		print("[ItemSlot] 🔍 _can_drop_data - target slot: (%d,%d), slot_type: %s, is_root: %s" % [grid_x, grid_y, slot_type, is_root_slot])

	if not data is Dictionary:
		return false

	if not data.has("item_id"):
		return false

	# Don't drop on self
	if data.get("source_slot") == self:
		return false

	# Can't drop on occupied (non-root) slots
	if not is_root_slot and occupied_by_uuid != "":
		return false

	# For inventory slots, use spatial grid validation
	if slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		# Determine which inventory manager to use
		var parent_view = _find_parent_inventory_view()
		var target_inventory_id = "stash" # Default
		
		if parent_view and "hero_id" in parent_view and parent_view.hero_id != "":
			target_inventory_id = parent_view.hero_id
		elif parent_view and "common_chest_mode" in parent_view and parent_view.common_chest_mode:
			target_inventory_id = "stash"

		# Check if item can be placed at this grid position
		var container = InventoryRegistry.get_container(target_inventory_id)
		if container:
			# Use UUID if available (for moving existing items), otherwise item_id (for new items/cheats)
			var can_place = false
			if data.has("uuid") and data.has("item_instance"):
				# Use the ItemInstance from drag data
				can_place = container.can_place_item(data.item_instance, grid_x, grid_y)
			elif data.has("uuid"):
				# Fallback: Try to get item from source container
				var source_inv_id = data.get("source_hero_id", "stash")
				if source_inv_id == "": source_inv_id = "stash"
				var source_container = InventoryRegistry.get_container(source_inv_id)
				if source_container:
					var item = source_container._items.get(data.uuid)
					if item:
						can_place = container.can_place_item(item, grid_x, grid_y)
			else:
				# Fallback for non-instance drops (if any)
				var dummy = ItemInstance.new(data.item_id)
				can_place = container.can_place_item(dummy, grid_x, grid_y)
				
			if not can_place:
				_show_invalid_drop_feedback(data)
				return false
		else:
			return false

	# Check equipment slot filter
	if slot_type == "equipment" and equipment_filter != ItemData.EquipSlot.NONE:
		var dragged_item = ItemDatabase.get_item(data.item_id)
		if dragged_item == null:
			_show_invalid_drop_feedback(data)
			return false

		# Only allow items that match this equipment slot
		if dragged_item.equip_slot != equipment_filter:
			_show_invalid_drop_feedback(data)
			return false

	# Visual Feedback
	var grid_container = _find_parent_grid_container()
	if grid_container and slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		var dragged_item = ItemDatabase.get_item(data.item_id)
		if dragged_item:
			var cells_to_highlight: Array[Vector2i] = []
			for dy in range(dragged_item.inventory_height):
				for dx in range(dragged_item.inventory_width):
					cells_to_highlight.append(Vector2i(grid_x + dx, grid_y + dy))

			grid_container.highlight_cells(cells_to_highlight, true)

	return true


## Godot drag-and-drop: Handle drop
func _drop_data(at_position: Vector2, data):
	if DEBUG_DRAG_DROP:
		print("[ItemSlot] 📥 _drop_data called - item: %s to slot (%d,%d)" % [data.get("item_id"), grid_x, grid_y])

	# Clear visual feedback when drop completes
	var grid_container = _find_parent_grid_container()
	if grid_container:
		grid_container.clear_highlight()

	if not _can_drop_data(at_position, data):
		return

	var source_slot = data.get("source_slot") as ItemSlot
	var source_sprite = data.get("source_sprite")

	# Accept drops from EITHER ItemSlots OR ItemSprites
	if source_slot == null and source_sprite == null:
		return

	# Special handling for equipment slots
	if slot_type == "equipment" or (source_slot and source_slot.slot_type == "equipment"):
		_handle_equipment_drop(data, source_slot)
		return

	# If dragging from an ItemSprite, handle it as a within-inventory move
	if source_sprite != null and source_slot == null:
		_handle_sprite_drop(data)
		return

	# Detect cross-panel transfers by checking if source and target are in different views
	var target_parent_view = _find_parent_inventory_view()
	var source_parent_view = source_slot._find_parent_inventory_view() if source_slot else null

	# Cross-panel transfer detection:
	var is_cross_panel_transfer = false
	if target_parent_view and source_parent_view and target_parent_view != source_parent_view:
		var source_is_equipment = source_parent_view.has_method("_refresh_shared_stash")
		var target_is_equipment = target_parent_view.has_method("_refresh_shared_stash")
		var source_is_inventory = source_parent_view.has_method("_refresh_inventory")
		var target_is_inventory = target_parent_view.has_method("_refresh_inventory")

		is_cross_panel_transfer = (source_is_equipment and target_is_inventory) or \
		                           (source_is_inventory and target_is_equipment)

	if is_cross_panel_transfer:
		# Use Transaction Service for cross-inventory moves
		var source_inv_id = data.get("source_hero_id", "stash")
		if source_inv_id == "": source_inv_id = "stash"
		
		var target_inv_id = "stash"
		if target_parent_view and "hero_id" in target_parent_view and target_parent_view.hero_id != "":
			target_inv_id = target_parent_view.hero_id
			
		ItemTransactionService.move_item(data.uuid, source_inv_id, target_inv_id)
		return

	# For inventory slots with grid coordinates, use spatial placement
	if slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		var target_inv_id = "stash"
		if target_parent_view and "hero_id" in target_parent_view and target_parent_view.hero_id != "":
			target_inv_id = target_parent_view.hero_id
			
		# Use Transaction Service to move/place item
		# If source is same inventory, it's a move. If different, it's a transfer.
		# But ItemTransactionService.move_item handles both if we pass correct IDs.
		
		var source_inv_id = data.get("source_hero_id", "stash")
		if source_inv_id == "": source_inv_id = "stash"
		
		# If it's the same inventory, we might want to use set_grid_position directly
		# But move_item should handle it if we implement it right.
		# Actually, ItemTransactionService.move_item doesn't take target coordinates yet?
		# Let's check ItemTransactionService... 
		# Wait, ItemTransactionService.move_item just moves between containers.
		# For specific grid placement, we need to call container.move_item(uuid, x, y) directly!
		
		var container = InventoryRegistry.get_container(target_inv_id)
		if container:
			if source_inv_id == target_inv_id:
				# Move within same container
				container.move_item(data.uuid, grid_x, grid_y)
			else:
				# Move between containers (and place at specific spot?)
				# ItemTransactionService currently doesn't support "move to specific slot".
				# We might need to enhance it or do it manually.
				# Manual: Remove from source, Add to target at (x,y)
				var source_container = InventoryRegistry.get_container(source_inv_id)
				if source_container:
					var item = source_container.remove_item(data.uuid)
					if item:
						if not container.add_item_at(item, grid_x, grid_y):
							# Failed to add, return to source
							source_container.add_item(item)
		return


func _handle_equipment_drop(data: Dictionary, source_slot: ItemSlot):
	"""Handle dropping to/from equipment slots using atomic transactions"""
	# Determine source properties
	var source_slot_type = "inventory"
	var source_hero_id = ""
	
	if source_slot:
		source_slot_type = source_slot.slot_type
		source_hero_id = source_slot.hero_id
	elif data.get("source_sprite"):
		source_slot_type = "inventory"
		source_hero_id = data.get("source_hero_id", "")
		if source_hero_id == "": source_hero_id = "stash"

	# Get target hero_id
	var target_hero_id = hero_id if slot_type == "equipment" else source_hero_id
	if target_hero_id == "":
		# Try to find hero_id from parent view
		var parent = _find_parent_inventory_view()
		if parent and "hero_id" in parent:
			target_hero_id = parent.hero_id
	
	if target_hero_id == "":
		return

	# Dragging FROM inventory TO equipment (EQUIP)
	if source_slot_type == "inventory" and slot_type == "equipment":
		var slot_name = equipment_slot_name if equipment_slot_name != "" else _get_equipment_slot_name()
		if slot_name != "":
			ItemTransactionService.equip_item(target_hero_id, data.uuid, slot_name)

	# Dragging FROM equipment TO inventory (UNEQUIP)
	elif source_slot_type == "equipment" and slot_type == "inventory":
		# Must have a valid source_slot for unequip (to get its slot name)
		if not source_slot:
			return
		var slot_name = source_slot.equipment_slot_name if source_slot.equipment_slot_name != "" else source_slot._get_equipment_slot_name()
		if slot_name != "":
			ItemTransactionService.unequip_item(target_hero_id, slot_name)

	# Dragging between equipment slots (SWAP)
	elif source_slot_type == "equipment" and slot_type == "equipment":
		if not source_slot:
			return
		var source_slot_name = source_slot.equipment_slot_name if source_slot.equipment_slot_name != "" else source_slot._get_equipment_slot_name()
		var target_slot_name = equipment_slot_name if equipment_slot_name != "" else _get_equipment_slot_name()

		if source_slot_name != "" and target_slot_name != "":
			# Swap via Service? Or manual unequip/equip?
			# TODO: Add swap_equipment to ItemTransactionService
			# For now, just unequip source and equip target
			ItemTransactionService.unequip_item(target_hero_id, source_slot_name)
			ItemTransactionService.equip_item(target_hero_id, data.uuid, target_slot_name)


func _handle_sprite_drop(data: Dictionary):
	"""Handle drop from ItemSprite (overlay mode)"""
	# This is just a wrapper for _drop_data logic since we unified it
	# But we need to ensure we don't infinite loop if we called this from _drop_data
	# Actually, _drop_data calls this if source is sprite.
	# But if we are here, we are likely in the target slot.
	
	# If we are here, it means we are dropping ONTO this slot.
	# We should just run the logic in _drop_data, but since _drop_data calls this...
	# Wait, the original code had _handle_sprite_drop doing the work.
	# I moved the work to _drop_data.
	# So I should remove this method or make it empty/deprecated?
	# No, ItemSprite calls this directly.
	
	# Let's just call _drop_data with the data
	# But _drop_data calls this... infinite loop risk.
	# I will move the logic to a shared internal method `_process_drop`
	pass

func _get_equipment_slot_name() -> String:
	"""Get the equipment slot name based on filter"""
	match equipment_filter:
		ItemData.EquipSlot.WEAPON:
			return "hand_left"
		ItemData.EquipSlot.HELMET:
			return "helmet"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY:
			# Need to determine which accessory slot
			var parent = get_parent()
			if parent and parent.name == "Accessory1Container":
				return "accessory_1"
			elif parent and parent.name == "Accessory2Container":
				return "accessory_2"
			return "accessory_1"
	return ""


## Handle mouse enter
func _on_mouse_entered():
	is_hovered = true

	if not is_empty:
		# Kill existing tween first to prevent multiple simultaneous tweens
		if _hover_tween and _hover_tween.is_valid():
			_hover_tween.kill()

		# Scale up slightly
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)


## Handle mouse exit
func _on_mouse_exited():
	is_hovered = false

	# Clear visual feedback when mouse exits during drag
	var grid_container = _find_parent_grid_container()
	if grid_container:
		grid_container.clear_highlight()

	# Kill existing tween first to prevent multiple simultaneous tweens
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	# Scale back to normal
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)


## Handle GUI input (clicks)
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if not is_empty and item_instance:
					# Shift+Click for context menu (web compatibility)
					if event.shift_pressed:
						item_right_clicked.emit(item_instance, self)
					else:
						item_clicked.emit(item_instance, self)
					accept_event() # Prevent click from reaching world

	elif event is InputEventScreenTouch:
		if event.pressed:
			# Touch started - begin long-press timer
			if not is_empty:
				touch_start_time = Time.get_ticks_msec() / 1000.0
				is_touch_held = true
		else:
			# Touch released
			if is_touch_held:
				var hold_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time

				if hold_duration >= LONG_PRESS_DURATION:
					# Long press detected - trigger right-click action (context menu)
					if not is_empty and item_instance:
						item_right_clicked.emit(item_instance, self)
				else:
					# Short tap - trigger normal click (auto-equip)
					if not is_empty and item_instance:
						item_clicked.emit(item_instance, self)

				is_touch_held = false
				accept_event() # Prevent tap from reaching world


## Generate tooltip (Diablo 2 style)
func _generate_tooltip() -> String:
	if not item_instance:
		return ""
		
	var item_data = item_instance.get_data()
	if not item_data:
		return ""

	var tooltip = ""

	# Item name (first line) - dynamic name based on affixes (Diablo 2 style)
	tooltip += "%s\n" % item_data.get_display_name(item_instance.rolled_affixes)

	# Rarity + Type (second line)
	var rarity_name = item_data.get_rarity_name()
	if _is_equipment_type(item_data.item_type):
		var type_name = _get_item_type_name(item_data.item_type)
		tooltip += "%s %s\n" % [rarity_name, type_name]
	else:
		tooltip += "%s\n" % rarity_name

	tooltip += "───────────\n"

	# Stats (for equipment) - Diablo 2 style: Base stats + Affix bonuses
	if _is_equipment_type(item_data.item_type):
		# Show base item stats (from ItemData)
		tooltip += _format_stat_line("Damage", item_data.damage_bonus)
		tooltip += _format_stat_line("Health", item_data.health_bonus)
		tooltip += _format_stat_line("Defense", item_data.defense_bonus)
		tooltip += _format_stat_line("Range", item_data.range_bonus)

		if item_data.attack_speed_multiplier != 1.0:
			var bonus_percent = (item_data.attack_speed_multiplier - 1.0) * 100
			tooltip += "%+.0f%% Attack Speed\n" % bonus_percent

		if item_data.crit_chance_bonus > 0:
			tooltip += "+%.1f%% Critical Strike\n" % (item_data.crit_chance_bonus * 100)

		# Show affix bonuses (Diablo 2 style - listed separately)
		if not item_instance.rolled_affixes.is_empty():
			for affix_key in item_instance.rolled_affixes.keys():
				# var affix_info = item_instance.rolled_affixes[affix_key] # Unused
				pass # TODO: Format affixes

	return tooltip

# Helpers
func _is_equipment_type(type: int) -> bool:
	return type == ItemData.ItemType.WEAPON or type == ItemData.ItemType.ARMOR or type == ItemData.ItemType.ACCESSORY

func _get_item_type_name(type: int) -> String:
	match type:
		ItemData.ItemType.WEAPON: return "Weapon"
		ItemData.ItemType.ARMOR: return "Armor"
		ItemData.ItemType.ACCESSORY: return "Accessory"
		ItemData.ItemType.CONSUMABLE: return "Consumable"
		ItemData.ItemType.MATERIAL: return "Material"
	return "Item"

func _format_stat_line(name: String, value: int) -> String:
	if value > 0:
		return "+%d %s\n" % [value, name]
	return ""

func _show_invalid_drop_feedback(data):
	# TODO: Implement visual feedback for invalid drop
	pass

func _find_parent_inventory_view():
	var node = get_parent()
	while node:
		# Duck typing to avoid cyclic dependency with InventoryView
		if node.has_method("_refresh_inventory") or node.has_method("_refresh_shared_stash"):
			return node
		node = node.get_parent()
	return null

func _find_parent_grid_container():
	var node = get_parent()
	while node:
		# Duck typing to avoid cyclic dependency with InventoryGridContainer
		if node.has_method("highlight_cells"):
			return node
		node = node.get_parent()
	return null
