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
