extends Node

## HeroInventoryManager - Autoload Singleton
## Manages per-hero inventories (separate from shared stash)
## Each hero has their own 8x8 spatial grid inventory

signal hero_inventory_changed(hero_id: String)
signal hero_item_added(hero_id: String, item_id: String, quantity: int)
signal hero_item_removed(hero_id: String, item_id: String, quantity: int)
signal hero_inventory_full(hero_id: String, item_id: String)

const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 8

## Per-hero inventory storage
## Structure: {
##   "ranger_hero_1": {
##     "items": {"bow_01": {quantity: 1, upgrade_level: 0}},
##     "grid": [["",...], ...],  # 8x8 array
##     "positions": {"bow_01": {x: 0, y: 0}}
##   }
## }
var _hero_inventories: Dictionary = {}


func _ready():
	print("[HeroInventoryManager] Initialized per-hero inventory system")


## ============================================
## HERO REGISTRATION
## ============================================

func register_hero(hero_id: String) -> void:
	"""Register a new hero with empty inventory"""
	if _hero_inventories.has(hero_id):
		print("[HeroInventoryManager] Hero already registered: ", hero_id)
		return

	_hero_inventories[hero_id] = {
		"items": {},
		"grid": _create_empty_grid(),
		"positions": {}
	}

	print("[HeroInventoryManager] Registered hero: ", hero_id)


func unregister_hero(hero_id: String) -> void:
	"""Unregister a hero (cleanup on removal)"""
	_hero_inventories.erase(hero_id)
	print("[HeroInventoryManager] Unregistered hero: ", hero_id)


func is_hero_registered(hero_id: String) -> bool:
	return _hero_inventories.has(hero_id)


func _create_empty_grid() -> Array:
	"""Create an empty 8x8 grid"""
	var grid = []
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append("")  # Empty cell
		grid.append(row)
	return grid


## ============================================
## ITEM MANAGEMENT
## ============================================

func add_item_to_hero(hero_id: String, item_id: String, quantity: int = 1, upgrade_level: int = 0) -> bool:
	"""Add an item to a hero's inventory"""
	if not _hero_inventories.has(hero_id):
		push_error("[HeroInventoryManager] Hero not registered: ", hero_id)
		return false

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		push_error("[HeroInventoryManager] Invalid item_id: ", item_id)
		return false

	var hero_inv = _hero_inventories[hero_id]

	# Check dictionary limit (prevent memory issues)
	if not hero_inv.items.has(item_id) and hero_inv.items.size() >= 100:
		hero_inventory_full.emit(hero_id, item_id)
		print("[HeroInventoryManager] ⚠️ Hero inventory dictionary limit reached (100 unique items)")
		return false

	# Check if we have space
	if not has_space_for_item(hero_id, item_data):
		hero_inventory_full.emit(hero_id, item_id)
		var size_str = "%d×%d" % [item_data.inventory_width, item_data.inventory_height]
		print("[HeroInventoryManager] ⚠️ Hero inventory full - no %s space for '%s'" % [size_str, item_data.item_name])
		return false

	# Add to inventory
	if hero_inv.items.has(item_id):
		# Stack existing item
		hero_inv.items[item_id].quantity += quantity
		print("[HeroInventoryManager] ✅ Stacked item for %s: %s (total: %d)" % [hero_id, item_id, hero_inv.items[item_id].quantity])
	else:
		# New item - add to dictionary AND grid atomically
		hero_inv.items[item_id] = {
			"quantity": quantity,
			"upgrade_level": upgrade_level
		}

		# Auto-place in grid
		if not _auto_place_item(hero_id, item_id):
			# Rollback if grid placement fails
			hero_inv.items.erase(item_id)
			hero_inventory_full.emit(hero_id, item_id)
			print("[HeroInventoryManager] ❌ Grid full - could not place item: ", item_data.item_name)
			return false

		print("[HeroInventoryManager] ✅ Added new item for %s: %s at %s" % [hero_id, item_id, hero_inv.positions.get(item_id, "unknown")])

	hero_item_added.emit(hero_id, item_id, quantity)
	hero_inventory_changed.emit(hero_id)
	SaveManager.mark_dirty()
	return true


func remove_item_from_hero(hero_id: String, item_id: String, quantity: int = 1) -> bool:
	"""Remove an item from a hero's inventory"""
	if not _hero_inventories.has(hero_id):
		push_error("[HeroInventoryManager] Hero not registered: ", hero_id)
		return false

	var hero_inv = _hero_inventories[hero_id]

	if not hero_inv.items.has(item_id):
		print("[HeroInventoryManager] Item not in hero inventory: ", item_id)
		return false

	if hero_inv.items[item_id].quantity < quantity:
		print("[HeroInventoryManager] Not enough of item %s (have %d, need %d)" % [item_id, hero_inv.items[item_id].quantity, quantity])
		return false

	hero_inv.items[item_id].quantity -= quantity

	# Remove completely if quantity reaches zero
	if hero_inv.items[item_id].quantity <= 0:
		hero_inv.items.erase(item_id)
		_clear_item_from_grid(hero_id, item_id)
		hero_inv.positions.erase(item_id)

	hero_item_removed.emit(hero_id, item_id, quantity)
	hero_inventory_changed.emit(hero_id)
	SaveManager.mark_dirty()
	return true


func get_item_quantity(hero_id: String, item_id: String) -> int:
	"""Get quantity of an item in hero's inventory"""
	if not _hero_inventories.has(hero_id):
		return 0

	var hero_inv = _hero_inventories[hero_id]
	if hero_inv.items.has(item_id):
		return hero_inv.items[item_id].quantity
	return 0


func get_item_upgrade_level(hero_id: String, item_id: String) -> int:
	"""Get upgrade level of an item in hero's inventory"""
	if not _hero_inventories.has(hero_id):
		return 0

	var hero_inv = _hero_inventories[hero_id]
	if hero_inv.items.has(item_id):
		return hero_inv.items[item_id].upgrade_level
	return 0


func has_item(hero_id: String, item_id: String, quantity: int = 1) -> bool:
	"""Check if hero has a specific item"""
	return get_item_quantity(hero_id, item_id) >= quantity


func get_all_items(hero_id: String) -> Array:
	"""Get all items in hero's inventory"""
	if not _hero_inventories.has(hero_id):
		return []

	var hero_inv = _hero_inventories[hero_id]
	var result = []

	for item_id in hero_inv.items.keys():
		# Skip items without grid positions (shouldn't happen, but safety check)
		if not hero_inv.positions.has(item_id):
			continue

		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		result.append({
			"item_id": item_id,
			"item_data": item_data,
			"quantity": hero_inv.items[item_id].quantity,
			"upgrade_level": hero_inv.items[item_id].upgrade_level
		})

	return result


## ============================================
## GRID MANAGEMENT
## ============================================

func has_space_for_item(hero_id: String, item_data: ItemData) -> bool:
	"""Check if hero has space for an item"""
	if not _hero_inventories.has(hero_id):
		return false

	var hero_inv = _hero_inventories[hero_id]

	# If stackable and already exists, always has space
	if item_data.is_stackable() and hero_inv.items.has(item_data.item_id):
		return true

	# Check actual grid availability
	var available_pos = _find_available_position(hero_id, item_data.item_id)
	return available_pos.x != -1 and available_pos.y != -1


func get_grid_position(hero_id: String, item_id: String) -> Dictionary:
	"""Get the grid position of an item"""
	if not _hero_inventories.has(hero_id):
		return {"x": -1, "y": -1}

	var hero_inv = _hero_inventories[hero_id]
	if hero_inv.positions.has(item_id):
		return hero_inv.positions[item_id]

	return {"x": -1, "y": -1}


func set_grid_position(hero_id: String, item_id: String, x: int, y: int) -> bool:
	"""Manually set grid position for an item (for drag-drop)"""
	if not _hero_inventories.has(hero_id):
		return false

	var hero_inv = _hero_inventories[hero_id]

	if not hero_inv.items.has(item_id):
		return false

	if not _can_place_item(hero_id, item_id, x, y):
		return false

	# Clear old position
	if hero_inv.positions.has(item_id):
		_clear_item_from_grid(hero_id, item_id)

	# Place at new position
	return _place_item(hero_id, item_id, x, y)


func _can_place_item(hero_id: String, item_id: String, x: int, y: int) -> bool:
	"""Check if an item can be placed at a specific position"""
	if not _hero_inventories.has(hero_id):
		return false

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	var hero_inv = _hero_inventories[hero_id]
	var grid = hero_inv.grid

	# Check bounds
	if x + item_data.inventory_width > GRID_WIDTH:
		return false
	if y + item_data.inventory_height > GRID_HEIGHT:
		return false

	# Check if all required cells are empty (or occupied by this same item)
	for dy in range(item_data.inventory_height):
		for dx in range(item_data.inventory_width):
			var check_x = x + dx
			var check_y = y + dy
			var occupant = grid[check_y][check_x]

			if occupant != "" and occupant != item_id:
				return false

	return true


func _place_item(hero_id: String, item_id: String, x: int, y: int) -> bool:
	"""Place an item at a specific grid position"""
	if not _hero_inventories.has(hero_id):
		return false

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	if not _can_place_item(hero_id, item_id, x, y):
		return false

	var hero_inv = _hero_inventories[hero_id]
	var grid = hero_inv.grid

	# Mark all cells as occupied
	for dy in range(item_data.inventory_height):
		for dx in range(item_data.inventory_width):
			grid[y + dy][x + dx] = item_id

	# Store position
	hero_inv.positions[item_id] = {"x": x, "y": y}

	hero_inventory_changed.emit(hero_id)
	return true


func _auto_place_item(hero_id: String, item_id: String) -> bool:
	"""Auto-place an item in the first available position"""
	var pos = _find_available_position(hero_id, item_id)
	if pos.x == -1:
		return false

	return _place_item(hero_id, item_id, pos.x, pos.y)


func _find_available_position(hero_id: String, item_id: String) -> Dictionary:
	"""Find the first available position for an item"""
	if not _hero_inventories.has(hero_id):
		return {"x": -1, "y": -1}

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return {"x": -1, "y": -1}

	# Scan grid left-to-right, top-to-bottom
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if _can_place_item(hero_id, item_id, x, y):
				return {"x": x, "y": y}

	return {"x": -1, "y": -1}  # No space found


func _clear_item_from_grid(hero_id: String, item_id: String) -> void:
	"""Clear all grid cells occupied by an item"""
	if not _hero_inventories.has(hero_id):
		return

	var hero_inv = _hero_inventories[hero_id]
	var grid = hero_inv.grid

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] == item_id:
				grid[y][x] = ""


## ============================================
## SAVE/LOAD INTEGRATION
## ============================================

func save_to_dict() -> Dictionary:
	"""Export all hero inventories to save dictionary"""
	var save_dict = {}

	for hero_id in _hero_inventories.keys():
		save_dict[hero_id] = {
			"items": _hero_inventories[hero_id].items.duplicate(true),
			"positions": _hero_inventories[hero_id].positions.duplicate(true)
		}
		# Note: Grid is reconstructed from positions on load, no need to save

	return save_dict


func load_from_dict(save_dict: Dictionary) -> void:
	"""Load all hero inventories from save dictionary"""
	_hero_inventories.clear()

	for hero_id in save_dict.keys():
		var hero_data = save_dict[hero_id]

		# Register hero with empty grid
		register_hero(hero_id)

		# Load items
		_hero_inventories[hero_id].items = hero_data.items.duplicate(true)
		_hero_inventories[hero_id].positions = hero_data.positions.duplicate(true)

		# Reconstruct grid from positions
		_reconstruct_grid(hero_id)

	print("[HeroInventoryManager] Loaded inventories for %d heroes" % save_dict.size())


func _reconstruct_grid(hero_id: String) -> void:
	"""Reconstruct grid occupation from item positions"""
	if not _hero_inventories.has(hero_id):
		return

	var hero_inv = _hero_inventories[hero_id]

	# Clear grid
	hero_inv.grid = _create_empty_grid()

	# Re-place all items
	for item_id in hero_inv.positions.keys():
		var pos = hero_inv.positions[item_id]
		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		# Mark grid cells
		for dy in range(item_data.inventory_height):
			for dx in range(item_data.inventory_width):
				var x = pos.x + dx
				var y = pos.y + dy
				if x < GRID_WIDTH and y < GRID_HEIGHT:
					hero_inv.grid[y][x] = item_id


## ============================================
## ITEM TRANSFER (Between Hero Inventory and Shared Stash)
## ============================================

func transfer_to_shared_stash(hero_id: String, item_id: String, quantity: int = 1) -> bool:
	"""
	Transfer an item from hero inventory to shared stash

	Returns: true if transfer succeeded, false otherwise
	"""
	if not _hero_inventories.has(hero_id):
		print("[HeroInventoryManager] Cannot transfer - hero not registered: ", hero_id)
		return false

	if not InventoryManager:
		print("[HeroInventoryManager] Cannot transfer - InventoryManager not found")
		return false

	var hero_inv = _hero_inventories[hero_id]

	# Check if hero has the item
	if not hero_inv.items.has(item_id):
		print("[HeroInventoryManager] Cannot transfer - hero doesn't have item: ", item_id)
		return false

	if hero_inv.items[item_id].quantity < quantity:
		print("[HeroInventoryManager] Cannot transfer - not enough quantity (have %d, need %d)" % [hero_inv.items[item_id].quantity, quantity])
		return false

	# Get item data
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		print("[HeroInventoryManager] Cannot transfer - invalid item: ", item_id)
		return false

	# Check if shared stash has space
	if not InventoryManager.has_space_for_item(item_data):
		print("[HeroInventoryManager] Cannot transfer - shared stash full")
		return false

	# Get upgrade level before removal
	var upgrade_level = hero_inv.items[item_id].upgrade_level

	# Remove from hero inventory
	if not remove_item_from_hero(hero_id, item_id, quantity):
		print("[HeroInventoryManager] Transfer failed - could not remove from hero")
		return false

	# Add to shared stash (note: InventoryManager.add_item only takes 2 params)
	if not InventoryManager.add_item(item_id, quantity):
		# Rollback: Add back to hero inventory
		add_item_to_hero(hero_id, item_id, quantity, upgrade_level)
		print("[HeroInventoryManager] Transfer failed - could not add to shared stash (rolled back)")
		return false

	# Set upgrade level separately if needed
	if upgrade_level > 0 and InventoryManager.has_method("set_item_upgrade_level"):
		InventoryManager.set_item_upgrade_level(item_id, upgrade_level)

	print("[HeroInventoryManager] ✅ Transferred '%s' from hero '%s' to shared stash" % [item_data.item_name, hero_id])
	return true


func transfer_from_shared_stash(hero_id: String, item_id: String, quantity: int = 1) -> bool:
	"""
	Transfer an item from shared stash to hero inventory

	Returns: true if transfer succeeded, false otherwise
	"""
	if not _hero_inventories.has(hero_id):
		print("[HeroInventoryManager] Cannot transfer - hero not registered: ", hero_id)
		register_hero(hero_id)  # Auto-register if needed

	if not InventoryManager:
		print("[HeroInventoryManager] Cannot transfer - InventoryManager not found")
		return false

	# Check if shared stash has the item
	if not InventoryManager.has_item(item_id, quantity):
		print("[HeroInventoryManager] Cannot transfer - shared stash doesn't have enough")
		return false

	# Get item data
	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		print("[HeroInventoryManager] Cannot transfer - invalid item: ", item_id)
		return false

	# Check if hero inventory has space
	if not has_space_for_item(hero_id, item_data):
		print("[HeroInventoryManager] Cannot transfer - hero inventory full")
		return false

	# Get upgrade level before removal
	var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)

	# Remove from shared stash
	if not InventoryManager.remove_item(item_id, quantity):
		print("[HeroInventoryManager] Transfer failed - could not remove from shared stash")
		return false

	# Add to hero inventory
	if not add_item_to_hero(hero_id, item_id, quantity, upgrade_level):
		# Rollback: Add back to shared stash (only 2 params)
		InventoryManager.add_item(item_id, quantity)
		# Restore upgrade level if needed
		if upgrade_level > 0 and InventoryManager.has_method("set_item_upgrade_level"):
			InventoryManager.set_item_upgrade_level(item_id, upgrade_level)
		print("[HeroInventoryManager] Transfer failed - could not add to hero (rolled back)")
		return false

	print("[HeroInventoryManager] ✅ Transferred '%s' from shared stash to hero '%s'" % [item_data.item_name, hero_id])
	return true
