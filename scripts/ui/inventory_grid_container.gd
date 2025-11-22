@tool
extends Control
class_name InventoryGridContainer

## Custom inventory grid that supports variable-sized items (Diablo 2 style)
## Unlike GridContainer, this allows items to span multiple cells with absolute positioning
## @tool directive enables grid rendering in Godot editor preview

@export var columns: int = 8
@export var cell_size: Vector2 = Vector2(80, 80)
@export var cell_gap: Vector2 = Vector2(5, 5)

var show_grid: bool = false # Toggle for debug grid visualization (disabled by default)
var item_layer: Control = null # Layer for rendering items on top of static grid (z_index=10)

## Professional Feature #3: Visual Feedback (Diablo 2 / Path of Exile style)
## Shows which cells would be occupied during drag with green (valid) or red (invalid)
var _highlight_cells: Array[Vector2i] = [] # Cells to highlight during drag
var _highlight_valid: bool = true # Green (true) or red (false)

func _ready():
	# Create item overlay layer (renders items on top of static grid)
	item_layer = Control.new()
	item_layer.name = "ItemLayer"
	item_layer.z_index = 10 # Render on top of grid slots

	# CRITICAL FIX: Use IGNORE, not PASS!
	# IGNORE = Container ignores input, ONLY children (ItemSprites) handle it
	# PASS = Container AND nodes beneath it receive input (breaks ItemSprite clicks!)
	# This ensures ItemSprites receive clicks BEFORE empty ItemSlots beneath them
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# CRITICAL FIX: Don't use anchors! They cause position calculation issues
	# Explicitly size to match parent instead
	# item_layer.anchor_right = 1.0   # REMOVED - causes global_position issues
	# item_layer.anchor_bottom = 1.0  # REMOVED
	item_layer.size = size # Match parent size explicitly

	add_child(item_layer)

	# Connect to child signals to trigger layout when children are added
	child_entered_tree.connect(_on_child_added)

	# Connect to resized signal to keep item_layer sized correctly
	resized.connect(_on_resized)

	# Initial layout
	call_deferred("_layout_children")

	# Trigger initial draw for editor preview (@tool mode)
	queue_redraw()


func _on_child_added(_child: Node):
	"""Trigger layout when a new child is added"""
	# CRITICAL FIX: Ensure item_layer is ALWAYS on top of slots (last child)
	# This ensures ItemSprites receive input events before empty ItemSlots
	if item_layer and item_layer.get_index() != get_child_count() - 1:
		move_child(item_layer, -1)
		
	call_deferred("_layout_children")


func _on_resized():
	"""Update item_layer size when parent resizes (maintains correct coordinate system)"""
	if item_layer:
		item_layer.size = size
		print("[InventoryGrid] Resized - item_layer size updated to %s" % size)


func _layout_children():
	"""Position all children based on their grid_x and grid_y properties"""
	for child in get_children():
		if not child is Control:
			continue

		# Skip if child doesn't have grid coordinates
		if not "grid_x" in child or not "grid_y" in child:
			continue

		var grid_x: int = child.grid_x
		var grid_y: int = child.grid_y

		# Calculate position based on grid coordinates
		var x_pos = grid_x * (cell_size.x + cell_gap.x)
		var y_pos = grid_y * (cell_size.y + cell_gap.y)

		child.position = Vector2(x_pos, y_pos)

		# Let child control its own size (via custom_minimum_size)
		# Don't override like GridContainer does


func set_columns(new_columns: int):
	"""Update column count for responsive layout"""
	columns = new_columns
	_layout_children()


func set_cell_size(new_size: Vector2):
	"""Update cell size for responsive layout"""
	cell_size = new_size
	_layout_children()


func get_grid_size() -> Vector2i:
	"""Calculate total grid size based on children"""
	var max_x = 0
	var max_y = 0

	for child in get_children():
		if "grid_x" in child and "grid_y" in child:
			max_x = max(max_x, child.grid_x)
			max_y = max(max_y, child.grid_y)

	return Vector2i(max_x + 1, max_y + 1)


func _get_minimum_size() -> Vector2:
	"""Calculate minimum size needed to contain all children"""
	# Use fixed grid size for editor preview when no children exist
	var grid_size = Vector2i(columns, 8) if get_grid_size() == Vector2i(0, 0) else get_grid_size()

	var min_width = grid_size.x * cell_size.x + (grid_size.x - 1) * cell_gap.x
	var min_height = grid_size.y * cell_size.y + (grid_size.y - 1) * cell_gap.y

	return Vector2(min_width, min_height)


## Professional Feature #1: World-to-Cell Conversion (Diablo 2 / Path of Exile style)
## Converts screen coordinates to grid coordinates for real-time feedback during drag

func screen_to_grid(screen_pos: Vector2, grab_offset: Vector2i = Vector2i(0, 0)) -> Vector2i:
	"""Convert screen position to grid coordinates with anchor point correction

	Used during drag operations to show which cell the cursor is over.
	Returns clamped coordinates (always within valid grid bounds).

	🔧 FIX: Added grab_offset parameter for anchor point correction (Diablo 2 / PoE style)
	When user drags a multi-cell item by clicking on a non-top-left cell, we subtract
	the offset to calculate the correct top-left landing position.

	Args:
		screen_pos: Global screen position (from get_global_mouse_position())
		grab_offset: Which cell within the item was clicked (0,0 = top-left)
	"""
	# Convert global position to local coordinates (relative to item_layer)
	var local_pos = screen_pos - global_position
	var grid_x = int(local_pos.x / (cell_size.x + cell_gap.x))
	var grid_y = int(local_pos.y / (cell_size.y + cell_gap.y))

	# 🔧 FIX: Apply anchor point correction (subtract cells clicked within item)
	# This ensures item's TOP-LEFT corner lands at the correct position regardless
	# of where user clicked to grab the item
	grid_x -= grab_offset.x
	grid_y -= grab_offset.y

	# Clamp to valid grid bounds
	grid_x = clamp(grid_x, 0, columns - 1)
	var max_rows = get_grid_size().y
	grid_y = clamp(grid_y, 0, max(max_rows - 1, 0))

	return Vector2i(grid_x, grid_y)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	"""Convert grid coordinates to world position

	Returns the top-left corner position of the grid cell in local coordinates.
	"""
	var x_pos = grid_pos.x * (cell_size.x + cell_gap.x)
	var y_pos = grid_pos.y * (cell_size.y + cell_gap.y)
	return Vector2(x_pos, y_pos)


func is_valid_grid_position(grid_pos: Vector2i, item_width: int = 1, item_height: int = 1) -> bool:
	"""Check if an item can fit at the given grid position

	Args:
		grid_pos: Top-left grid coordinate
		item_width: Item width in cells (default 1)
		item_height: Item height in cells (default 1)

	Returns:
		true if item fits within grid bounds
	"""
	# Check if top-left is within bounds
	if grid_pos.x < 0 or grid_pos.y < 0:
		return false

	# Check if bottom-right is within bounds
	var max_rows = get_grid_size().y
	if grid_pos.x + item_width > columns:
		return false
	if grid_pos.y + item_height > max_rows:
		return false

	return true


func highlight_cells(cells: Array[Vector2i], is_valid: bool):
	"""Highlight specific cells with green (valid) or red (invalid) overlay

	Used during drag operations to show where the item would be placed.

	Args:
		cells: Array of grid coordinates to highlight
		is_valid: true = green (valid placement), false = red (invalid)
	"""
	_highlight_cells = cells
	_highlight_valid = is_valid
	queue_redraw()


func clear_highlight():
	"""Clear all cell highlights"""
	_highlight_cells.clear()
	queue_redraw()


func toggle_grid_visualization():
	"""Toggle debug grid visualization (F3 key)"""
	show_grid = !show_grid
	queue_redraw()
	print("[InventoryGrid] Grid visualization: %s" % ("ON" if show_grid else "OFF"))


func refresh_items_display():
	"""Called when items change - refreshes debug grid visualization"""
	queue_redraw() # Redraw grid lines to match current item positions


func _draw():
	"""Draw debug grid lines when enabled"""
	if not show_grid:
		return

	# Use fixed grid size for editor preview when no children exist
	var grid_size = Vector2i(columns, 8) if get_grid_size() == Vector2i(0, 0) else get_grid_size()
	var grid_color = Color(0.5, 0.5, 1.0, 0.3) # Semi-transparent blue

	# Draw vertical lines
	for x in range(grid_size.x + 1):
		var x_pos = x * (cell_size.x + cell_gap.x)
		var start_pos = Vector2(x_pos, 0)
		var end_pos = Vector2(x_pos, grid_size.y * (cell_size.y + cell_gap.y))
		draw_line(start_pos, end_pos, grid_color, 1.0)

	# Draw horizontal lines
	for y in range(grid_size.y + 1):
		var y_pos = y * (cell_size.y + cell_gap.y)
		var start_pos = Vector2(0, y_pos)
		var end_pos = Vector2(grid_size.x * (cell_size.x + cell_gap.x), y_pos)
		draw_line(start_pos, end_pos, grid_color, 1.0)

	# Draw cell labels (grid coordinates)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var x_pos = x * (cell_size.x + cell_gap.x) + 5
			var y_pos = y * (cell_size.y + cell_gap.y) + 15
			var label_text = "(%d,%d)" % [x, y]
			draw_string(ThemeDB.fallback_font, Vector2(x_pos, y_pos), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 1.0, 0.5))

	# Draw cell highlights (green for valid, red for invalid placement)
	if not _highlight_cells.is_empty():
		var highlight_color = Color(0.0, 1.0, 0.0, 0.3) if _highlight_valid else Color(1.0, 0.0, 0.0, 0.3)
		for cell in _highlight_cells:
			var x_pos = cell.x * (cell_size.x + cell_gap.x)
			var y_pos = cell.y * (cell_size.y + cell_gap.y)
			var rect = Rect2(x_pos, y_pos, cell_size.x, cell_size.y)
			draw_rect(rect, highlight_color)
