class_name InventoryContainer
extends RefCounted

## InventoryContainer
## A generic, reusable logic class for managing a grid-based inventory.
## Handles "Tetris" logic, item storage, and spatial tracking.
## Used by Stash, Heroes, Chests, Pets, etc.

signal content_changed
signal item_added(uuid: String, item_id: String)
signal item_removed(uuid: String, item_id: String)
signal size_changed(width: int, height: int)

# Configuration
var width: int = 8
var height: int = 8
var container_id: String = "" # e.g., "stash", "hero_1"

# State
var _items: Dictionary = {} # UUID -> ItemInstance
var _grid: Array = [] # 2D Array [y][x] -> UUID (String)
var _item_positions: Dictionary = {} # UUID -> Vector2i

## Initialize with dimensions
func _init(p_width: int = 8, p_height: int = 8, p_id: String = ""):
	width = p_width
	height = p_height
	container_id = p_id
	_init_grid()

## Initialize the 2D grid array
func _init_grid():
	_grid.clear()
	for y in range(height):
		var row = []
		for x in range(width):
			row.append("")
		_grid.append(row)

## Add an item instance to the container
## Returns true if successful
func add_item(item: ItemInstance) -> bool:
	if _items.has(item.uuid):
		push_error("Item already in container: " + item.uuid)
		return false
		
	# Find space
	var pos = find_free_space(item)
	if pos == Vector2i(-1, -1):
		return false # No space
		
	# Place in storage
	_items[item.uuid] = item
	_place_on_grid(item, pos.x, pos.y)
	
	item_added.emit(item.uuid, item.item_id)
	content_changed.emit()
	return true

## Remove an item by UUID
## Returns the removed ItemInstance (or null if not found)
func remove_item(uuid: String) -> ItemInstance:
	if not _items.has(uuid):
		return null
		
	var item = _items[uuid]
	
	# Remove from grid
	_clear_from_grid(uuid)
	
	# Remove from storage
	_items.erase(uuid)
	
	item_removed.emit(uuid, item.item_id)
	content_changed.emit()
	return item

## Move an item within the grid
func move_item(uuid: String, to_x: int, to_y: int) -> bool:
	if not _items.has(uuid):
		return false
		
	var item = _items[uuid]
	
	# Temporarily remove from grid to check space
	var old_pos = _item_positions[uuid]
	_clear_from_grid(uuid)
	
	if can_place_item(item, to_x, to_y):
		_place_on_grid(item, to_x, to_y)
		content_changed.emit()
		return true
	else:
		# 🧲 SMART NUDGE: Try to find a nearby valid position
		var nudged_pos = find_nearest_valid_position(item, to_x, to_y)
		if nudged_pos != Vector2i(-1, -1):
			_place_on_grid(item, nudged_pos.x, nudged_pos.y)
			content_changed.emit()
			# User feedback: Item was adjusted to nearby position
			print("[InventoryContainer] 🧲 Smart Nudge: Item snapped to nearby position (%d, %d)" % [nudged_pos.x, nudged_pos.y])
			return true  # ✅ Nudge succeeded

		# Rollback: Put back at old position
		_place_on_grid(item, old_pos.x, old_pos.y)
		return false

## Check if an item can be placed at (x, y)
func can_place_item(item: ItemInstance, x: int, y: int) -> bool:
	var data = item.get_data()
	if not data: return false
	
	# Check bounds
	if x < 0 or y < 0: return false
	if x + data.inventory_width > width: return false
	if y + data.inventory_height > height: return false
	
	# Check collision
	for dy in range(data.inventory_height):
		for dx in range(data.inventory_width):
			var cell_content = _grid[y + dy][x + dx]
			if cell_content != "" and cell_content != item.uuid:
				return false
				
	return true

## Find the first available position for an item (Auto-place)
func find_free_space(item: ItemInstance) -> Vector2i:
	var data = item.get_data()
	if not data: return Vector2i(-1, -1)
	
	for y in range(height):
		for x in range(width):
			if can_place_item(item, x, y):
				return Vector2i(x, y)

	return Vector2i(-1, -1)

## SMART NUDGE: Find the nearest valid position within 1-cell radius
## Returns Vector2i(-1, -1) if no valid position found
## Tries the exact position first, then searches neighbors in distance order
func find_nearest_valid_position(item: ItemInstance, target_x: int, target_y: int) -> Vector2i:
	# 1. Fast path: Check original position first
	if can_place_item(item, target_x, target_y):
		return Vector2i(target_x, target_y)

	# 2. Spiral search - sorted by distance (orthogonal first, then diagonal)
	# Orthogonal neighbors are preferred (feel more natural than diagonal snapping)
	const NUDGE_OFFSETS = [
		# Orthogonal (Manhattan distance 1)
		Vector2i(0, -1),   # North
		Vector2i(0, 1),    # South
		Vector2i(-1, 0),   # West
		Vector2i(1, 0),    # East
		# Diagonal (Euclidean distance ~1.41)
		Vector2i(-1, -1),  # Northwest
		Vector2i(1, -1),   # Northeast
		Vector2i(-1, 1),   # Southwest
		Vector2i(1, 1)     # Southeast
	]

	for offset in NUDGE_OFFSETS:
		var test_x = target_x + offset.x
		var test_y = target_y + offset.y

		if can_place_item(item, test_x, test_y):
			return Vector2i(test_x, test_y)

	# 3. No valid position found within 1-cell radius
	return Vector2i(-1, -1)

## Internal: Mark grid cells as occupied
func _place_on_grid(item: ItemInstance, x: int, y: int):
	var data = item.get_data()
	_item_positions[item.uuid] = Vector2i(x, y)
	
	for dy in range(data.inventory_height):
		for dx in range(data.inventory_width):
			_grid[y + dy][x + dx] = item.uuid

## Internal: Clear grid cells
func _clear_from_grid(uuid: String):
	if not _item_positions.has(uuid): return
	
	var pos = _item_positions[uuid]
	var item = _items[uuid]
	var data = item.get_data()
	
	_item_positions.erase(uuid)
	
	for dy in range(data.inventory_height):
		for dx in range(data.inventory_width):
			if _grid[pos.y + dy][pos.x + dx] == uuid:
				_grid[pos.y + dy][pos.x + dx] = ""

## Get item at specific grid cell
func get_item_at(x: int, y: int) -> ItemInstance:
	if x < 0 or x >= width or y < 0 or y >= height: return null
	var uuid = _grid[y][x]
	if uuid == "": return null
	return _items.get(uuid)

## Get all items (for saving/display)
func get_all_items() -> Array[ItemInstance]:
	var list: Array[ItemInstance] = []
	for key in _items:
		list.append(_items[key])
	return list

## Get item position
func get_item_position(uuid: String) -> Vector2i:
	return _item_positions.get(uuid, Vector2i(-1, -1))

## Check if container has a specific item by UUID
func has_item(uuid: String) -> bool:
	return _items.has(uuid)

## Check if container has space for an item (without adding it)
func has_space_for(item: ItemInstance) -> bool:
	return find_free_space(item) != Vector2i(-1, -1)

## Get all unique items occupying the target area (for Atomic Swap collision detection)
## Returns array of UUIDs (excluding empty cells and the item itself)
## Used to determine if exactly 1 item is blocking placement
func get_items_in_area(item: ItemInstance, x: int, y: int) -> Array[String]:
	var data = item.get_data()
	if not data: return []

	# Check bounds first
	if x < 0 or y < 0: return []
	if x + data.inventory_width > width: return []
	if y + data.inventory_height > height: return []

	# Scan all cells and collect unique blocking UUIDs
	var blocking_items: Dictionary = {}  # Use Dictionary as a Set for O(1) deduplication

	for dy in range(data.inventory_height):
		for dx in range(data.inventory_width):
			var cell_content = _grid[y + dy][x + dx]
			# Skip empty cells and the item itself (self-collision)
			if cell_content != "" and cell_content != item.uuid:
				blocking_items[cell_content] = true

	# Convert Dictionary keys to Array[String]
	var result: Array[String] = []
	for uuid in blocking_items.keys():
		result.append(uuid)

	return result

## Add an item at a specific grid position
## Returns true if successful
func add_item_at(item: ItemInstance, x: int, y: int) -> bool:
	if _items.has(item.uuid):
		push_error("Item already in container: " + item.uuid)
		return false

	if not can_place_item(item, x, y):
		return false

	# Place in storage
	_items[item.uuid] = item
	_place_on_grid(item, x, y)

	item_added.emit(item.uuid, item.item_id)
	content_changed.emit()
	return true

## Serialize state
func to_dict() -> Dictionary:
	var item_list = []
	for item in _items.values():
		item_list.append(item.to_dict())
		
	return {
		"width": width,
		"height": height,
		"items": item_list,
		"positions": _item_positions # Save positions to restore grid layout
	}

## Deserialize state
func load_from_dict(data: Dictionary):
	width = data.get("width", width)
	height = data.get("height", height)
	_init_grid()
	_items.clear()
	_item_positions.clear()
	
	var saved_items = data.get("items", [])
	var saved_positions = data.get("positions", {})
	
	# 1. Load all items
	for item_data in saved_items:
		var item = ItemInstance.from_dict(item_data)
		_items[item.uuid] = item
		
	# 2. Restore positions
	for uuid in saved_positions:
		if _items.has(uuid):
			var pos_str = saved_positions[uuid] # Vector2i might load as String in JSON
			var x = 0
			var y = 0
			
			# Handle Vector2i parsing from JSON if needed
			if typeof(pos_str) == TYPE_STRING:
				var parts = pos_str.replace("(", "").replace(")", "").split(",")
				x = int(parts[0])
				y = int(parts[1])
			elif typeof(pos_str) == TYPE_VECTOR2I or typeof(pos_str) == TYPE_VECTOR2:
				x = int(pos_str.x)
				y = int(pos_str.y)
				
			_place_on_grid(_items[uuid], x, y)
			
	# 3. Auto-place items that lost their position (safety)
	for item in _items.values():
		if not _item_positions.has(item.uuid):
			var new_pos = find_free_space(item)
			if new_pos != Vector2i(-1, -1):
				_place_on_grid(item, new_pos.x, new_pos.y)
			else:
				push_error("Could not restore item position: " + item.item_id)

## ============================================
## DEBUG UTILITIES
## ============================================

## Print the entire grid state (for debugging)
func debug_print_grid():
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[InventoryContainer] Grid State for '%s' (%dx%d)" % [container_id, width, height])
	print("  Total Items: %d" % _items.size())

	# Print column headers
	var header = "    "
	for x in range(width):
		header += "%2d " % x
	print(header)
	var separator = "─".repeat(width * 3 + 1)
	print("  " + separator)

	# Print grid with row numbers
	for y in range(height):
		var row = "%2d │" % y
		for x in range(width):
			var cell = _grid[y][x]
			if cell == "":
				row += " . "
			else:
				# Show first 2 chars of UUID
				row += " %s" % cell.substr(0, 2)
		print(row)

	# Print item list with positions
	print("\n  Items:")
	for uuid in _items:
		var item = _items[uuid]
		var pos = _item_positions.get(uuid, Vector2i(-1, -1))
		var data = item.get_data()
		print("    %s: %s at (%d, %d) [%dx%d]" % [
			uuid.substr(0, 8),
			item.item_id,
			pos.x, pos.y,
			data.inventory_width, data.inventory_height
		])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

## Debug: Show why a specific position is blocked
func debug_check_position(item: ItemInstance, x: int, y: int):
	var data = item.get_data()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[InventoryContainer] Position Check for '%s' (%dx%d)" % [container_id, width, height])
	print("  Item: %s (Size: %dx%d)" % [item.item_id, data.inventory_width, data.inventory_height])
	print("  Target Position: (%d, %d)" % [x, y])

	# Check bounds
	print("\n  Bounds Check:")
	print("    X: %d + %d = %d <= %d? %s" % [x, data.inventory_width, x + data.inventory_width, width, "✅" if x + data.inventory_width <= width else "❌"])
	print("    Y: %d + %d = %d <= %d? %s" % [y, data.inventory_height, y + data.inventory_height, height, "✅" if y + data.inventory_height <= height else "❌"])

	var bounds_ok = x >= 0 and y >= 0 and x + data.inventory_width <= width and y + data.inventory_height <= height

	if not bounds_ok:
		print("  ❌ BLOCKED: Out of bounds")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return

	# Check collision
	print("\n  Collision Check:")
	var blocked_cells = []
	for dy in range(data.inventory_height):
		for dx in range(data.inventory_width):
			var check_x = x + dx
			var check_y = y + dy
			var cell_content = _grid[check_y][check_x]
			if cell_content != "" and cell_content != item.uuid:
				blocked_cells.append("(%d, %d) = %s" % [check_x, check_y, cell_content.substr(0, 8)])

	if blocked_cells.size() > 0:
		print("  ❌ BLOCKED: %d cells occupied:" % blocked_cells.size())
		for cell_info in blocked_cells:
			print("    - %s" % cell_info)
	else:
		print("  ✅ CLEAR: All cells available")

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

## ============================================
## AUTO-SORT FEATURE
## ============================================

## Sort inventory using greedy bin packing heuristic
## Optimizes for: Large items first, then by category, rarity, and name
## Uses rollback if any item fails to fit (should never happen unless grid changed)
func sort_inventory() -> bool:
	print("[InventoryContainer] 📦 Starting Auto-Sort for '%s'..." % container_id)

	# 1. Collect all items (keep in _items dict for now)
	var all_items = get_all_items()

	if all_items.is_empty():
		print("[InventoryContainer] ⚠️ No items to sort")
		return true  # Success (nothing to do)

	# 2. Sort items by priority (largest first, then by category, rarity, name)
	all_items.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		var data_a = a.get_data()
		var data_b = b.get_data()

		# Priority 1: Size (area = width × height) - LARGEST FIRST
		var area_a = data_a.inventory_width * data_a.inventory_height
		var area_b = data_b.inventory_width * data_b.inventory_height
		if area_a != area_b:
			return area_a > area_b  # Larger items first (hardest to fit)

		# Priority 2: Category - Weapons > Armor > Accessories > Others
		var cat_a = _get_category_score(data_a.item_type)
		var cat_b = _get_category_score(data_b.item_type)
		if cat_a != cat_b:
			return cat_a < cat_b  # Lower score = higher priority

		# Priority 3: Rarity - Legendary > Epic > Rare > Uncommon > Common
		if data_a.rarity != data_b.rarity:
			return data_a.rarity > data_b.rarity

		# Priority 4: Name (alphabetical for consistency)
		return a.item_id < b.item_id
	)

	# 3. Backup current positions AND grid state for rollback (defensive programming)
	var backup_positions = _item_positions.duplicate(true)  # Deep copy
	var backup_grid = _grid.duplicate(true)  # Deep copy of 2D array

	# 4. Clear grid (but keep items in _items dictionary)
	for item in all_items:
		_clear_from_grid(item.uuid)

	# 5. Re-pack items in sorted order
	var failed_items: Array[ItemInstance] = []
	for item in all_items:
		var pos = find_free_space(item)
		if pos != Vector2i(-1, -1):
			_place_on_grid(item, pos.x, pos.y)
		else:
			# Item doesn't fit (should NEVER happen unless grid shrunk)
			failed_items.append(item)
			push_error("[InventoryContainer] ⚠️ Sort failed: Item '%s' doesn't fit!" % item.item_id)

	# 6. Handle failures (rollback if ANY item failed)
	if not failed_items.is_empty():
		print("[InventoryContainer] ❌ ROLLBACK: %d items failed to fit - restoring original state" % failed_items.size())

		# Restore original grid state (defensive programming)
		_grid = backup_grid
		_item_positions = backup_positions

		# Note: Items are still in _items dictionary (never removed during sort)
		# Grid and positions are fully restored

		content_changed.emit()  # UI should refresh to show rollback
		return false  # Sort failed

	# 7. Success!
	print("[InventoryContainer] ✅ Auto-Sort complete: %d items organized" % all_items.size())
	content_changed.emit()
	return true

## Helper: Map item type to sort priority
## Lower score = higher priority (sorted first)
func _get_category_score(item_type: int) -> int:
	# Assuming ItemData.ItemType enum values
	# WEAPON = 0, ARMOR = 1, ACCESSORY = 2, CONSUMABLE = 3, etc.
	match item_type:
		0: return 1   # WEAPON - highest priority
		1: return 2   # ARMOR - second priority
		2: return 3   # ACCESSORY - third priority
		3: return 4   # CONSUMABLE - fourth priority
		_: return 99  # Unknown types - lowest priority
