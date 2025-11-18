extends Node

## InventoryManager - Autoload Singleton
## Manages player's account-wide inventory (Dungeon Defenders pattern)
## Separate from per-hero equipment slots

signal inventory_changed
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_full(item_id: String)
signal slot_limit_reached(category: String)

## CONSTANTS
const MAX_UNIQUE_ITEMS: int = 100  # Maximum number of unique items allowed (prevents memory/save issues)

## Storage: {item_id: {quantity: int, upgrade_level: int, rolled_affixes: Dictionary}}
var global_inventory: Dictionary = {}

## Item upgrade levels: {item_id: upgrade_level}
var item_upgrades: Dictionary = {}


func _ready():
	# Initialize grid immediately on startup
	_init_grid()
	print("[InventoryManager] Grid initialized: %dx%d" % [GRID_WIDTH, GRID_HEIGHT])

	# Wait for ItemDatabase to load
	if not ItemDatabase.items_loaded.is_connected(_on_item_database_loaded):
		ItemDatabase.items_loaded.connect(_on_item_database_loaded)


func _on_item_database_loaded():
	pass


## Add an item to the inventory
func add_item(item_id: String, quantity: int = 1, rolled_affixes: Dictionary = {}) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		push_error("[InventoryManager] Invalid item_id: %s" % item_id)
		return false

	# Safety check: Prevent dictionary overflow
	# This prevents memory issues and save file corruption from unbounded growth
	if not global_inventory.has(item_id) and global_inventory.size() >= MAX_UNIQUE_ITEMS:
		inventory_full.emit(item_id)
		print("[InventoryManager] ⚠️ Inventory dictionary limit reached (%d unique items)" % MAX_UNIQUE_ITEMS)
		return false

	# Check if we have space (grid availability for non-stackables)
	if !has_space_for_item(item_data):
		inventory_full.emit(item_id)
		var size_str = "%d×%d" % [item_data.inventory_width, item_data.inventory_height] if item_data.inventory_width > 1 or item_data.inventory_height > 1 else "1×1"
		print("[InventoryManager] ⚠️ Inventory full - no %s space for '%s'" % [size_str, item_data.item_name])
		return false

	# Add to inventory
	if global_inventory.has(item_id):
		# Stack existing item (grid position already exists)
		global_inventory[item_id].quantity += quantity
		print("[InventoryManager] ✅ Stacked item: %s (total: %d)" % [item_id, global_inventory[item_id].quantity])
	else:
		# New item entry - add to dictionary AND place in grid atomically
		global_inventory[item_id] = {
			"quantity": quantity,
			"upgrade_level": 0,
			"rolled_affixes": rolled_affixes
		}

		# ATOMIC PLACEMENT: Auto-place in grid immediately
		if not auto_place_item(item_id):
			# Rollback dictionary addition if grid placement fails
			global_inventory.erase(item_id)
			inventory_full.emit(item_id)
			print("[InventoryManager] ❌ Inventory grid full - could not place item: ", item_data.item_name)
			return false

		print("[InventoryManager] ✅ Added new item: %s at position %s" % [item_id, item_positions.get(item_id, "unknown")])

	item_added.emit(item_id, quantity)
	inventory_changed.emit()
	SaveManager.mark_dirty()  # Mark for auto-save
	return true


## Remove an item from the inventory
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if !global_inventory.has(item_id):
		push_error("[InventoryManager] Item not in inventory: %s" % item_id)
		return false

	if global_inventory[item_id].quantity < quantity:
		push_error("[InventoryManager] Not enough of item %s (have %d, need %d)" % [item_id, global_inventory[item_id].quantity, quantity])
		return false

	global_inventory[item_id].quantity -= quantity

	if global_inventory[item_id].quantity <= 0:
		global_inventory.erase(item_id)

	item_removed.emit(item_id, quantity)
	inventory_changed.emit()
	SaveManager.mark_dirty()  # Mark for auto-save
	return true


## Get quantity of a specific item
func get_item_quantity(item_id: String) -> int:
	if global_inventory.has(item_id):
		return global_inventory[item_id].quantity
	return 0


## Get upgrade level of a specific item
func get_item_upgrade_level(item_id: String) -> int:
	if global_inventory.has(item_id):
		return global_inventory[item_id].upgrade_level
	return 0


## Get rolled affixes of a specific item
func get_item_rolled_affixes(item_id: String) -> Dictionary:
	if global_inventory.has(item_id):
		return global_inventory[item_id].get("rolled_affixes", {})
	return {}


## Upgrade an item (increase its level)
func upgrade_item(item_id: String) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null or !item_data.can_upgrade:
		return false

	if !global_inventory.has(item_id):
		push_error("[InventoryManager] Item not in inventory: %s" % item_id)
		return false

	var current_level = global_inventory[item_id].upgrade_level
	if current_level >= item_data.max_upgrade_level:
		print("[InventoryManager] Item already at max level: ", item_id)
		return false

	var upgrade_cost = item_data.get_upgrade_cost(current_level)
	if upgrade_cost < 0:
		return false

	# Check if player has enough gems (persistent currency)
	if SaveManager.get_gems() < upgrade_cost:
		print("[InventoryManager] Not enough gems to upgrade")
		return false

	# Deduct cost and upgrade
	SaveManager.add_gems(-upgrade_cost)
	global_inventory[item_id].upgrade_level += 1

	inventory_changed.emit()
	SaveManager.mark_dirty()  # Mark for auto-save
	return true


## Check if we have space for a new item
func has_space_for_item(item_data: ItemData) -> bool:
	# If item is stackable and already exists, we can always add more
	if item_data.is_stackable() and global_inventory.has(item_data.item_id):
		return true

	# Check actual 2D grid availability for non-stackable items
	# This ensures multi-slot items (like 2×3 bows) are properly validated
	var available_pos = find_available_position(item_data.item_id)
	return available_pos.x != -1 and available_pos.y != -1


## Get all items in a specific category
func get_items_by_category(category: String) -> Array:
	var result = []

	for item_id in global_inventory.keys():
		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		var item_category = _get_category_for_item_type(item_data.item_type)
		if item_category == category:
			result.append({
				"item_id": item_id,
				"item_data": item_data,
				"quantity": global_inventory[item_id].quantity,
				"upgrade_level": global_inventory[item_id].upgrade_level,
				"rolled_affixes": global_inventory[item_id].get("rolled_affixes", {})
			})

	return result


## Get all items by ItemType
func get_items_by_type(item_type: ItemData.ItemType) -> Array:
	var result = []

	for item_id in global_inventory.keys():
		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		if item_data.item_type == item_type:
			result.append({
				"item_id": item_id,
				"item_data": item_data,
				"quantity": global_inventory[item_id].quantity,
				"upgrade_level": global_inventory[item_id].upgrade_level,
				"rolled_affixes": global_inventory[item_id].get("rolled_affixes", {})
			})

	return result


## Get ALL items in inventory (all categories combined)
func get_all_items() -> Array:
	var result = []

	for item_id in global_inventory.keys():
		# Skip equipped items (items without grid positions)
		if not item_positions.has(item_id):
			continue

		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		result.append({
			"item_id": item_id,
			"item_data": item_data,
			"quantity": global_inventory[item_id].quantity,
			"upgrade_level": global_inventory[item_id].upgrade_level,
			"rolled_affixes": global_inventory[item_id].get("rolled_affixes", {})
		})

	return result


## Get category string for an item type
func _get_category_for_item_type(item_type: ItemData.ItemType) -> String:
	# All items are equipment now
	return "equipment"


## Sell an item for gold
func sell_item(item_id: String, quantity: int = 1) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	# Prevent selling account-bound items (starter equipment)
	if item_data.is_account_bound:
		print("[InventoryManager] ⚠️ Cannot sell account-bound item: ", item_id)
		return false

	if !remove_item(item_id, quantity):
		return false

	var sell_value = item_data.sell_value * quantity
	SaveManager.add_gems(sell_value)

	return true


## Check if player has a specific item
func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_quantity(item_id) >= quantity


## Get total number of unique items
func get_unique_item_count() -> int:
	return global_inventory.size()


## ============================================
## EQUIPMENT TRANSACTION WRAPPERS (NEW - Option A Refactor)
## ============================================

func equip_item_atomic(hero_id: String, slot: String, item_id: String) -> bool:
	"""Atomically equip item with inventory/equipment coordination (supports two-handed weapons)"""
	if not global_inventory.has(item_id):
		push_error("[InventoryManager] Cannot equip - item not in inventory: %s" % item_id)
		return false

	# Get item data to check if it's two-handed
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		push_error("[InventoryManager] Cannot equip - invalid item: %s" % item_id)
		return false

	# PREVENT EQUIPPING TWO-HANDED WEAPONS TO RIGHT HAND
	# Two-handed weapons must be equipped to left hand (they will occupy both slots)
	if item_data.is_two_handed and slot == "hand_right":
		print("[InventoryManager] ⚠️ Cannot equip two-handed weapon to right hand - equip to left hand instead")
		return false

	# PRE-VALIDATION: Check space for old item BEFORE starting transaction
	# This prevents rollback failures that could cause permanent item loss
	var old_item = HeroEquipmentRegistry.get_equipped_item(hero_id, slot)
	# Skip validation for 2H occupation markers (they're not real items)
	if old_item != "" and not old_item.begins_with("__2H_OCCUPIED__"):
		var old_item_data = ItemDatabase.get_item(old_item)
		if old_item_data and not has_space_for_item(old_item_data):
			inventory_full.emit(old_item)
			var size_str = "%d×%d" % [old_item_data.inventory_width, old_item_data.inventory_height]
			print("[InventoryManager] ⚠️ Cannot equip - no %s space for old item '%s'" % [size_str, old_item_data.item_name])
			return false  # FAIL EARLY - transaction never starts

	# TWO-HANDED WEAPON LOGIC: If equipping 2H weapon to left hand, also check right hand
	var old_right_hand_item = ""
	if item_data.is_two_handed and slot == "hand_left":
		old_right_hand_item = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_right")
		# Check if right hand has an actual item (not just a 2H marker)
		if old_right_hand_item != "" and not old_right_hand_item.begins_with("__2H_OCCUPIED__"):
			var right_hand_data = ItemDatabase.get_item(old_right_hand_item)
			if right_hand_data and not has_space_for_item(right_hand_data):
				inventory_full.emit(old_right_hand_item)
				var size_str = "%d×%d" % [right_hand_data.inventory_width, right_hand_data.inventory_height]
				print("[InventoryManager] ⚠️ Cannot equip 2H weapon - no %s space for right hand item '%s'" % [size_str, right_hand_data.item_name])
				return false  # FAIL EARLY

	# PREVENT EQUIPPING TO RIGHT HAND IF LEFT HAND HAS 2H WEAPON
	# Also validate right-hand marker consistency
	if slot == "hand_right":
		# Check if right hand already has a 2H occupation marker (corruption check)
		var existing_right_hand = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_right")
		if existing_right_hand.begins_with("__2H_OCCUPIED__"):
			# Extract the item_id from the marker
			var marker_item_id = existing_right_hand.substr(len("__2H_OCCUPIED__"))
			# Validate that the corresponding left-hand item exists
			var left_hand_item_id = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_left")
			if left_hand_item_id != marker_item_id:
				push_warning("[InventoryManager] ⚠️ Corrupted 2H marker detected - left hand doesn't match marker. Cleaning up...")
				# Allow equip to proceed (will clear the corrupted marker)
			else:
				print("[InventoryManager] ⚠️ Cannot equip - right hand occupied by two-handed weapon")
				return false

		# Check if left hand has a 2H weapon (normal validation)
		var left_hand_item_id = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_left")
		if left_hand_item_id != "":
			var left_hand_item_data = ItemDatabase.get_item(left_hand_item_id)
			if left_hand_item_data and left_hand_item_data.is_two_handed:
				print("[InventoryManager] ⚠️ Cannot equip - left hand has two-handed weapon")
				return false

	if not HeroEquipmentRegistry.begin_transaction(hero_id, "equip"):
		return false

	# Store original position for guaranteed rollback
	var item_original_pos = get_item_position(item_id)

	# CRITICAL VALIDATION: Item must be in grid to have valid rollback position
	if item_original_pos.x == -1 or item_original_pos.y == -1:
		print("[InventoryManager] ⚠️ Cannot equip - item not in inventory grid: ", item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false

	if not remove_from_grid(item_id):
		HeroEquipmentRegistry.rollback_transaction()
		return false

	# Unequip old item from target slot (skip 2H markers)
	if old_item != "" and not old_item.begins_with("__2H_OCCUPIED__"):
		if not auto_place_item(old_item):
			# CRITICAL ROLLBACK: Restore to exact original position (guaranteed to succeed)
			if not place_item(item_id, item_original_pos.x, item_original_pos.y):
				push_error("[InventoryManager] CRITICAL: Rollback failed! Item may be lost: %s" % item_id)
			HeroEquipmentRegistry.rollback_transaction()
			return false

	# TWO-HANDED: Unequip old right hand item if equipping 2H weapon to left hand
	if item_data.is_two_handed and slot == "hand_left" and old_right_hand_item != "" and not old_right_hand_item.begins_with("__2H_OCCUPIED__"):
		if not auto_place_item(old_right_hand_item):
			# CRITICAL ROLLBACK
			if old_item != "" and not old_item.begins_with("__2H_OCCUPIED__"):
				remove_from_grid(old_item)
			if not place_item(item_id, item_original_pos.x, item_original_pos.y):
				push_error("[InventoryManager] CRITICAL: Rollback failed! Item may be lost: %s" % item_id)
			HeroEquipmentRegistry.rollback_transaction()
			return false

	# Equip item to target slot
	if not HeroEquipmentRegistry.equip_item_in_transaction(slot, item_id):
		if old_item != "" and not old_item.begins_with("__2H_OCCUPIED__"):
			remove_from_grid(old_item)
		if old_right_hand_item != "" and not old_right_hand_item.begins_with("__2H_OCCUPIED__"):
			remove_from_grid(old_right_hand_item)
		# CRITICAL ROLLBACK: Restore to exact original position
		if not place_item(item_id, item_original_pos.x, item_original_pos.y):
			push_error("[InventoryManager] CRITICAL: Rollback failed! Item may be lost: %s" % item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false

	# TWO-HANDED: Also occupy right hand slot with marker
	if item_data.is_two_handed and slot == "hand_left":
		if not HeroEquipmentRegistry.equip_item_in_transaction("hand_right", "__2H_OCCUPIED__" + item_id):
			if old_item != "" and not old_item.begins_with("__2H_OCCUPIED__"):
				remove_from_grid(old_item)
			if old_right_hand_item != "" and not old_right_hand_item.begins_with("__2H_OCCUPIED__"):
				remove_from_grid(old_right_hand_item)
			if not place_item(item_id, item_original_pos.x, item_original_pos.y):
				push_error("[InventoryManager] CRITICAL: Rollback failed! Item may be lost: %s" % item_id)
			HeroEquipmentRegistry.rollback_transaction()
			return false

	if not HeroEquipmentRegistry.commit_transaction():
		if old_item != "" and not old_item.begins_with("__2H_OCCUPIED__"):
			remove_from_grid(old_item)
		if old_right_hand_item != "" and not old_right_hand_item.begins_with("__2H_OCCUPIED__"):
			remove_from_grid(old_right_hand_item)
		# CRITICAL ROLLBACK: Restore to exact original position
		if not place_item(item_id, item_original_pos.x, item_original_pos.y):
			push_error("[InventoryManager] CRITICAL: Rollback failed! Item may be lost: %s" % item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false

	inventory_changed.emit()
	SaveManager.mark_dirty()  # Mark for auto-save
	return true

func unequip_item_atomic(hero_id: String, slot: String) -> bool:
	"""Atomically unequip item with inventory coordination (supports two-handed weapons)"""
	var item_id = HeroEquipmentRegistry.get_equipped_item(hero_id, slot)
	if item_id == "":
		return true

	# Skip unequipping 2H occupation markers (they're not real items)
	if item_id.begins_with("__2H_OCCUPIED__"):
		print("[InventoryManager] ⚠️ Cannot unequip 2H marker - unequip the left hand weapon instead")
		return false

	# Prevent unequipping starter equipment to empty slot (can only replace)
	var item_data = ItemDatabase.get_item(item_id)
	if item_data and item_data.is_starter_equipment:
		print("[InventoryManager] ⚠️ Cannot unequip starter equipment: ", item_id)
		return false

	if not HeroEquipmentRegistry.begin_transaction(hero_id, "unequip"):
		return false
	if not HeroEquipmentRegistry.equip_item_in_transaction(slot, ""):
		HeroEquipmentRegistry.rollback_transaction()
		return false

	# TWO-HANDED: If unequipping 2H weapon from left hand, also clear right hand marker
	if item_data and item_data.is_two_handed and slot == "hand_left":
		if not HeroEquipmentRegistry.equip_item_in_transaction("hand_right", ""):
			HeroEquipmentRegistry.rollback_transaction()
			return false

	if not auto_place_item(item_id):
		HeroEquipmentRegistry.rollback_transaction()
		inventory_full.emit(item_id)
		print("[InventoryManager] Inventory full - cannot unequip")
		return false
	if not HeroEquipmentRegistry.commit_transaction():
		remove_from_grid(item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false
	inventory_changed.emit()
	SaveManager.mark_dirty()  # Mark for auto-save
	return true

func remove_from_grid(item_id: String) -> bool:
	"""Remove item from grid (for equipping)"""
	if not item_positions.has(item_id):
		return false
	var pos = item_positions[item_id]
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return false
	for x in range(item_data.inventory_width):
		for y in range(item_data.inventory_height):
			var grid_x = pos.x + x
			var grid_y = pos.y + y
			if is_valid_position(grid_x, grid_y):
				grid[grid_y][grid_x] = ""
	item_positions.erase(item_id)
	return true


## Clear entire inventory (for testing/reset)
func clear_inventory():
	global_inventory.clear()
	inventory_changed.emit()


## Save inventory data to dictionary (for SaveManager)
func save_to_dict() -> Dictionary:
	return {
		"global_inventory": global_inventory.duplicate(true),
		"item_positions": item_positions.duplicate(true)
	}


## Load inventory data from dictionary (from SaveManager)
func load_from_dict(data: Dictionary):
	global_inventory = data.get("global_inventory", {})
	# Legacy max_slots removed - spatial grid system is the only capacity limit
	item_positions = data.get("item_positions", {})

	# Migration: Convert old rolled_stats to rolled_affixes for backward compatibility
	for item_id in global_inventory.keys():
		if not global_inventory[item_id].has("rolled_affixes"):
			# Check for legacy rolled_stats and migrate, or default to empty
			if global_inventory[item_id].has("rolled_stats"):
				global_inventory[item_id]["rolled_affixes"] = {}  # Old stat system cannot be converted
				global_inventory[item_id].erase("rolled_stats")  # Clean up old field
			else:
				global_inventory[item_id]["rolled_affixes"] = {}

	# Rebuild grid from item positions
	_init_grid()  # Clear grid first
	var items_placed = 0
	for item_id in item_positions:
		var pos = item_positions[item_id]
		var item_data = ItemDatabase.get_item(item_id)
		if item_data:
			# Mark all cells occupied by this item
			for dy in range(item_data.inventory_height):
				for dx in range(item_data.inventory_width):
					var grid_x = pos.x + dx
					var grid_y = pos.y + dy
					if is_valid_position(grid_x, grid_y):
						grid[grid_y][grid_x] = item_id
			items_placed += 1

	print("[InventoryManager] Loaded inventory: %d items, %d placed in grid" % [global_inventory.size(), items_placed])
	inventory_changed.emit()


## ============================================
## SPATIAL GRID TRACKING (Diablo 2 Style Multi-Slot)
## ============================================

## Grid dimensions (8 columns × 8 rows = 64 slots total)
const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 8

## Spatial positions: {item_id: {x: int, y: int}}
var item_positions: Dictionary = {}

## 2D grid occupation tracking: grid[y][x] = item_id or ""
var grid: Array = []


func _init_grid():
	"""Initialize the 2D grid array"""
	grid.clear()
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append("")  # Empty slot
		grid.append(row)


## Check if a grid position is within bounds
func is_valid_position(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT


## Check if a specific grid cell is occupied
func is_cell_occupied(x: int, y: int) -> bool:
	if not is_valid_position(x, y):
		return true  # Out of bounds = occupied

	if grid.is_empty():
		_init_grid()

	return grid[y][x] != ""


## Get the item_id occupying a specific cell (or "" if empty)
func get_cell_occupant(x: int, y: int) -> String:
	if not is_valid_position(x, y):
		return ""

	if grid.is_empty():
		_init_grid()

	return grid[y][x]


## Check if an item can be placed at a specific position
func can_place_item(item_id: String, x: int, y: int) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	if grid.is_empty():
		_init_grid()

	# Check if item's full area fits within grid bounds
	if x + item_data.inventory_width > GRID_WIDTH:
		return false
	if y + item_data.inventory_height > GRID_HEIGHT:
		return false

	# Check if all required cells are empty (or occupied by this same item if moving)
	for dy in range(item_data.inventory_height):
		for dx in range(item_data.inventory_width):
			var check_x = x + dx
			var check_y = y + dy
			var occupant = grid[check_y][check_x]

			# Cell must be empty OR occupied by the item we're moving
			if occupant != "" and occupant != item_id:
				return false

	return true


## Place an item at a specific position (reserves grid cells)
func place_item(item_id: String, x: int, y: int) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	if not can_place_item(item_id, x, y):
		return false

	# Clear old position if item was already placed
	if item_positions.has(item_id):
		clear_item_from_grid(item_id)

	# Mark all cells as occupied by this item
	for dy in range(item_data.inventory_height):
		for dx in range(item_data.inventory_width):
			grid[y + dy][x + dx] = item_id

	# Store root position
	item_positions[item_id] = {"x": x, "y": y}

	inventory_changed.emit()
	return true


## Clear an item from the grid
func clear_item_from_grid(item_id: String):
	if not item_positions.has(item_id):
		return

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return

	var pos = item_positions[item_id]
	var x = pos.x
	var y = pos.y

	# Clear all cells occupied by this item
	for dy in range(item_data.inventory_height):
		for dx in range(item_data.inventory_width):
			if is_valid_position(x + dx, y + dy):
				if grid[y + dy][x + dx] == item_id:
					grid[y + dy][x + dx] = ""


## Move an item to a new position
func move_item(item_id: String, new_x: int, new_y: int) -> bool:
	if not can_place_item(item_id, new_x, new_y):
		return false

	return place_item(item_id, new_x, new_y)


## Get the grid position of an item
func get_item_position(item_id: String) -> Dictionary:
	if item_positions.has(item_id):
		return item_positions[item_id]
	return {"x": -1, "y": -1}


## Find the first available position for an item (auto-placement)
func find_available_position(item_id: String) -> Dictionary:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return {"x": -1, "y": -1}

	if grid.is_empty():
		_init_grid()

	# Scan grid left-to-right, top-to-bottom
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if can_place_item(item_id, x, y):
				return {"x": x, "y": y}

	return {"x": -1, "y": -1}  # No space found


## Auto-place an item in the first available position
func auto_place_item(item_id: String) -> bool:
	var pos = find_available_position(item_id)
	if pos.x == -1:
		return false

	return place_item(item_id, pos.x, pos.y)


## Remove item from inventory AND grid
func remove_item_from_grid(item_id: String, quantity: int = 1) -> bool:
	if remove_item(item_id, quantity):
		# If item was completely removed, clear from grid
		if not global_inventory.has(item_id):
			clear_item_from_grid(item_id)
			item_positions.erase(item_id)
		return true
	return false


## DEBUG: Print grid state
func debug_print_grid():
	if grid.is_empty():
		return

	for y in range(GRID_HEIGHT):
		var row_str = ""
		for x in range(GRID_WIDTH):
			var cell = grid[y][x]
			if cell == "":
				row_str += "[ ]"
			else:
				row_str += "[X]"
