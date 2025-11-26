class_name InventoryGridSlot
extends PanelContainer

## InventoryGridSlot - Lightweight grid cell for InventoryView
##
## Replaces EquipmentSlot (formerly ItemSlot) for the "dumb" background grid in InventoryView.
## Does NOT handle item rendering (ItemSprite does that).
## Does NOT handle input (ItemSprite or Parent does that).
## ONLY handles:
## 1. Grid positioning (grid_x, grid_y)
## 2. Drop target logic (receiving drops from ItemSprite)

const DEBUG_DRAG_DROP = false

var grid_x: int = -1
var grid_y: int = -1
var slot_index: int = -1
var slot_type: String = "inventory" # Always "inventory"
var hero_id: String = "" # Inherited from parent view

func _ready():
	# Set default size (same as EquipmentSlot)
	custom_minimum_size = Vector2(80, 80)

	# Ensure mouse filter allows drops
	mouse_filter = Control.MOUSE_FILTER_PASS

	# FIX: Make background transparent so parent's grid texture shows through
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

## Godot drag-and-drop: Check if can drop here
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("item_id"):
		return false
		
	# Don't drop on self (if dragging from this slot - though this slot is empty)
	# But ItemSprite initiates drag, so source is never this slot.
	
	# For inventory slots, we allow dropping anywhere (fuzzy validation)
	# The backend (ItemTransactionService) handles collision/swapping.
	return true

## Godot drag-and-drop: Handle drop
func _drop_data(_at_position: Vector2, data):
	if DEBUG_DRAG_DROP:
		print("[InventoryGridSlot] 📥 _drop_data called - item: %s to slot (%d,%d)" % [data.get("item_id"), grid_x, grid_y])

	# Clear visual feedback
	var grid_container = _find_parent_grid_container()
	if grid_container:
		grid_container.clear_highlight()

	# Forward to unified handler
	_handle_sprite_drop(data)

## Handle drop from ItemSprite (overlay mode)
func _handle_sprite_drop(data: Dictionary):
	"""Handle drop logic - Forward to ItemTransactionService"""

	# 🔧 FIX: Check if source is an equipment slot
	var source_slot = data.get("source_slot")
	var source_slot_type = data.get("source_slot_type", "inventory")

	if source_slot_type == "equipment":
		# Equipment → Inventory: Use unequip logic instead of move_item
		_handle_equipment_to_inventory_drop(data, source_slot)
		return

	# 1. Determine Source (for inventory-to-inventory moves)
	var source_inv_id = data.get("source_container_id", "")
	if source_inv_id == "":
		source_inv_id = data.get("source_hero_id", "stash")
	if source_inv_id == "":
		source_inv_id = "stash"

	# 2. Determine Target
	var target_inv_id = "stash"
	var parent_view = _find_parent_inventory_view()
	
	# Priority logic (same as EquipmentSlot)
	if parent_view and "container_id" in parent_view and parent_view.container_id != "":
		target_inv_id = parent_view.container_id
	elif parent_view and "common_chest_mode" in parent_view and parent_view.common_chest_mode:
		target_inv_id = "stash"
	elif hero_id != "":
		target_inv_id = hero_id
	elif parent_view and "hero_id" in parent_view and parent_view.hero_id != "":
		target_inv_id = parent_view.hero_id

	# 3. Execute Move
	var target_x_pos = grid_x
	var target_y_pos = grid_y
	
	# If data has specific target coordinates (e.g. from gap drop), use them
	if data.has("target_grid_x") and data.has("target_grid_y"):
		target_x_pos = data.target_grid_x
		target_y_pos = data.target_grid_y

	if DEBUG_DRAG_DROP:
		print("[InventoryGridSlot] 🎯 Executing Move: %s -> %s at (%d,%d)" % [source_inv_id, target_inv_id, target_x_pos, target_y_pos])

	# Check if target is occupied (for sound feedback)
	var was_occupied = false
	var container = InventoryRegistry.get_container(target_inv_id)
	if container:
		var item_at_target = container.get_item_at(target_x_pos, target_y_pos)
		if item_at_target:
			was_occupied = true

	if ItemTransactionService.move_item(data.uuid, source_inv_id, target_inv_id, target_x_pos, target_y_pos):
		if was_occupied:
			AudioManager.play("swap", 0.1)
		else:
			AudioManager.play("drop", 0.1)
	else:
		AudioManager.play("error", 0.1)

## Handle drop from equipment slot to inventory
func _handle_equipment_to_inventory_drop(data: Dictionary, source_slot):
	"""Unequip item from equipment slot into inventory at drop position"""

	var source_hero_id = data.get("source_hero_id", "")
	var source_slot_name = ""
	if source_slot and "equipment_slot_name" in source_slot:
		source_slot_name = source_slot.equipment_slot_name

	# Determine target inventory
	var target_inv_id = "stash"
	var parent_view = _find_parent_inventory_view()

	if parent_view and "container_id" in parent_view and parent_view.container_id != "":
		target_inv_id = parent_view.container_id
	elif parent_view and "common_chest_mode" in parent_view and parent_view.common_chest_mode:
		target_inv_id = "stash"
	elif hero_id != "":
		target_inv_id = hero_id
	elif parent_view and "hero_id" in parent_view and parent_view.hero_id != "":
		target_inv_id = parent_view.hero_id

	if DEBUG_DRAG_DROP:
		print("[InventoryGridSlot] 🎯 Equipment→Inventory: hero=%s slot=%s -> %s at (%d,%d)" % [source_hero_id, source_slot_name, target_inv_id, grid_x, grid_y])

	# Use unequip_item with target position (where user dropped)
	if ItemTransactionService.unequip_item(source_hero_id, source_slot_name, target_inv_id, grid_x, grid_y):
		AudioManager.play("drop", 0.1)
	else:
		AudioManager.play("error", 0.1)

# Helpers
func _find_parent_inventory_view():
	var node = get_parent()
	while node:
		if node.has_method("_refresh_inventory") or node.has_method("_refresh_shared_stash"):
			return node
		node = node.get_parent()
	return null

func _find_parent_grid_container():
	var node = get_parent()
	while node:
		if node.has_method("highlight_cells"):
			return node
		node = node.get_parent()
	return null
