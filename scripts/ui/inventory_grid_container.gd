@tool
extends Control
class_name InventoryGridContainer

## Custom inventory grid that supports variable-sized items (Diablo 2 style)
## Unlike GridContainer, this allows items to span multiple cells with absolute positioning
## @tool directive enables grid rendering in Godot editor preview

@export var columns: int = 8
@export var rows: int = 8
@export var cell_size: Vector2 = Vector2(80, 80)
@export var cell_gap: Vector2 = Vector2(5, 5)
@export var background_texture: Texture2D # Optional tiling background for grid

# Debug mode
const DEBUG_LOGGING = false # Enable verbose logging for grid operations
const DEBUG_DROP_MARKER = false # Enable visual drop position marker (shows where items land)

## Highlight states for 3-color feedback (Professional ARPG UX)
enum HighlightState {VALID, SWAP, INVALID}

var show_grid: bool = false # Toggle for debug grid visualization (disabled by default)
var item_layer: Control = null # Layer for rendering items on top of static grid (z_index=10)

## Professional Feature #3: Visual Feedback (Diablo 2 / Path of Exile style)
## Shows which cells would be occupied during drag with green/orange/red
var _highlight_cells: Array[Vector2i] = [] # Cells to highlight during drag
var _highlight_state: int = HighlightState.VALID # GREEN=valid, ORANGE=swap, RED=invalid
var _is_dragging: bool = false # Track active drag state for real-time highlighting
var _container = null # Reference to InventoryContainer for collision checking

## Debug: Track last drop position for visual comparison
var _debug_drop_marker: Array[Vector2i] = [] # Where item actually dropped (CYAN)
var _debug_highlight_marker: Array[Vector2i] = [] # Where highlight was showing (MAGENTA)
var _debug_drop_timer: float = 0.0 # Timer to fade out both markers

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
	# item_layer.size = size # REMOVED - causes race condition (size may be 0,0 at _ready time)

	add_child(item_layer)

	# Defer size initialization until after layout completes
	call_deferred("_finalize_item_layer_size")

	# Connect to child signals to trigger layout when children are added
	child_entered_tree.connect(_on_child_added)

	# Connect to resized signal to keep item_layer sized correctly
	resized.connect(_on_resized)

	# Initial layout
	call_deferred("_layout_children")

	# Trigger initial draw for editor preview (@tool mode)
	queue_redraw()


func _notification(what: int):
	"""Track drag lifecycle for real-time highlighting (Diablo 2 / Path of Exile style)"""
	if what == NOTIFICATION_DRAG_BEGIN:
		_is_dragging = true
	elif what == NOTIFICATION_DRAG_END:
		_is_dragging = false
		clear_highlight()


func _process(delta: float):
	"""Update drag highlighting in real-time during drag operations"""
	# Update debug drop marker timer
	if DEBUG_DROP_MARKER and _debug_drop_timer > 0:
		_debug_drop_timer -= delta
		if _debug_drop_timer <= 0:
			_debug_drop_marker.clear()
			_debug_highlight_marker.clear()
		queue_redraw()

	if not _is_dragging or not get_viewport().gui_is_dragging():
		return
	_update_drag_highlighting()


func _update_drag_highlighting():
	"""Calculate and display cells that would be occupied on drop (Professional ARPG UX)"""
	# Only show highlights if mouse is over THIS grid (fixes dual-grid highlight bug)
	var mouse_pos = get_global_mouse_position()
	var local_mouse = mouse_pos - global_position
	var grid_rect = Rect2(Vector2.ZERO, size)
	if not grid_rect.has_point(local_mouse):
		clear_highlight()
		return

	var drag_data = get_viewport().gui_get_drag_data()
	if not drag_data or not drag_data is Dictionary or not drag_data.has("item_id"):
		clear_highlight()
		return

	var item_data = ItemDatabase.get_item(drag_data.item_id)
	if not item_data:
		clear_highlight()
		return

	var grab_offset_x = drag_data.get("grab_offset_x", 0)
	var grab_offset_y = drag_data.get("grab_offset_y", 0)

	var grid_pos = screen_to_grid(
		get_global_mouse_position(),
		Vector2i(grab_offset_x, grab_offset_y),
		item_data.inventory_width,
		item_data.inventory_height
	)

	# Generate array of cells that would be occupied
	var cells: Array[Vector2i] = []
	for y in range(item_data.inventory_height):
		for x in range(item_data.inventory_width):
			cells.append(Vector2i(grid_pos.x + x, grid_pos.y + y))

	# Determine highlight state (3-state feedback: GREEN/ORANGE/RED)
	var state = HighlightState.INVALID

	# Check bounds first
	if is_valid_grid_position(grid_pos, item_data.inventory_width, item_data.inventory_height):
		if _container:
			var item_instance = drag_data.get("item_instance")
			if item_instance:
				var blocking = _container.get_items_in_area(item_instance, grid_pos.x, grid_pos.y)
				if blocking.size() == 0:
					state = HighlightState.VALID # Empty cells - GREEN
				elif blocking.size() == 1:
					state = HighlightState.SWAP # 1 item blocking - ORANGE (swap possible)
				# else: 2+ items blocking = INVALID (RED) - stays default
		else:
			state = HighlightState.VALID # No container reference - assume valid

	highlight_cells(cells, state)


func _on_child_added(_child: Node):
	"""Trigger layout when a new child is added"""
	# CRITICAL FIX: Ensure item_layer is ALWAYS on top of slots (last child)
	# This ensures ItemSprites receive input events before empty ItemSlots
	if item_layer and item_layer.get_index() != get_child_count() - 1:
		move_child(item_layer, -1)
		
	call_deferred("_layout_children")


func _finalize_item_layer_size():
	"""Initialize item_layer size after layout completes (deferred from _ready)

	This runs on the next frame after _ready(), ensuring the parent InventoryGridContainer
	has been properly laid out by Godot's layout system before we set item_layer size.
	Fixes race condition where size=(0,0) during _ready() causes ItemSprites to be clipped.
	"""
	if item_layer:
		item_layer.size = size
		if DEBUG_LOGGING:
			print("[InventoryGrid] ✅ Finalized item_layer size: %s (parent size: %s)" % [item_layer.size, size])


func _on_resized():
	"""Update item_layer size when parent resizes (maintains correct coordinate system)"""
	if item_layer:
		item_layer.size = size
		if DEBUG_LOGGING:
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
	var found_children = false

	for child in get_children():
		if "grid_x" in child and "grid_y" in child:
			max_x = max(max_x, child.grid_x)
			max_y = max(max_y, child.grid_y)
			found_children = true

	if not found_children:
		return Vector2i(0, 0)

	return Vector2i(max_x + 1, max_y + 1)


func _get_minimum_size() -> Vector2:
	"""Calculate minimum size needed to contain all children"""
	# Use fixed grid size for editor preview when no children exist
	var grid_size = Vector2i(columns, rows) if get_grid_size() == Vector2i(0, 0) else get_grid_size()

	var min_width = grid_size.x * cell_size.x + (grid_size.x - 1) * cell_gap.x
	var min_height = grid_size.y * cell_size.y + (grid_size.y - 1) * cell_gap.y

	return Vector2(min_width, min_height)


## Professional Feature #1: World-to-Cell Conversion (Diablo 2 / Path of Exile style)
## Converts screen coordinates to grid coordinates for real-time feedback during drag

func screen_to_grid(screen_pos: Vector2, grab_offset: Vector2i = Vector2i(0, 0), item_width: int = 1, item_height: int = 1) -> Vector2i:
	"""Convert screen position to grid coordinates with smart clamping

	Used during drag operations to show which cell the cursor is over.
	Returns smart-clamped coordinates that ensure items fit entirely within grid bounds.

	🔧 FIX: Added grab_offset parameter for anchor point correction (Diablo 2 / PoE style)
	When user drags a multi-cell item by clicking on a non-top-left cell, we subtract
	the offset to calculate the correct top-left landing position.

	🔧 FIX: Added item dimensions for smart edge clamping (Professional ARPG UX)
	Instead of blindly clamping to grid edge (which fails validation for multi-cell items),
	we calculate the rightmost/bottommost position where the item actually FITS.
	This creates the "magnetic snap to edge" behavior seen in Diablo 2 / Path of Exile.

	Args:
		screen_pos: Global screen position (from get_global_mouse_position())
		grab_offset: Which cell within the item was clicked (0,0 = top-left)
		item_width: Width of item in cells (default 1 for backward compatibility)
		item_height: Height of item in cells (default 1 for backward compatibility)
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

	# 🔧 FIX: Smart clamping - ensure item fits entirely within grid bounds
	# Calculate max valid position where item won't extend beyond edge
	# Example: 8-column grid, 2-wide item → max_x = 8 - 2 = 6 (occupies cells 6,7)
	var max_rows = get_grid_size().y
	var max_valid_x = max(0, columns - item_width)
	var max_valid_y = max(0, max_rows - item_height)

	# Clamp to valid range (Diablo 2 / PoE style: magnetic snap to edge)
	grid_x = clamp(grid_x, 0, max_valid_x)
	grid_y = clamp(grid_y, 0, max_valid_y)

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
	# Use configured rows as fallback when get_grid_size() returns 0 (equipment grids)
	var grid_size = get_grid_size()
	var max_rows = grid_size.y if grid_size.y > 0 else rows
	if grid_pos.x + item_width > columns:
		return false
	if grid_pos.y + item_height > max_rows:
		return false

	return true


func highlight_cells(cells: Array[Vector2i], state: int = HighlightState.VALID):
	"""Highlight specific cells with green/orange/red overlay (3-state feedback)

	Used during drag operations to show where the item would be placed.

	Args:
		cells: Array of grid coordinates to highlight
		state: HighlightState.VALID (green), SWAP (orange), or INVALID (red)
	"""
	_highlight_cells = cells
	_highlight_state = state
	queue_redraw()


func clear_highlight():
	"""Clear all cell highlights"""
	# DEBUG: Save highlight position before clearing (for comparison with drop marker)
	if DEBUG_DROP_MARKER and not _highlight_cells.is_empty():
		_debug_highlight_marker = _highlight_cells.duplicate()
	_highlight_cells.clear()
	queue_redraw()


func show_debug_drop_marker(grid_pos: Vector2i, item_width: int = 1, item_height: int = 1):
	"""DEBUG: Show cyan marker where item actually dropped (compare to green highlight)

	Call this from drop handlers to visualize if drop position matches highlight position.
	Marker fades out over 2 seconds.
	"""
	if not DEBUG_DROP_MARKER:
		return

	# 🔧 FIX: Save highlight position NOW (before it's cleared by NOTIFICATION_DRAG_END)
	# The drop handler runs BEFORE drag end notification, so _highlight_cells is still valid
	if not _highlight_cells.is_empty():
		_debug_highlight_marker = _highlight_cells.duplicate()

	_debug_drop_marker.clear()
	for y in range(item_height):
		for x in range(item_width):
			_debug_drop_marker.append(Vector2i(grid_pos.x + x, grid_pos.y + y))

	_debug_drop_timer = 2.0 # Show for 2 seconds
	queue_redraw()

	# Log both positions for easy comparison
	var highlight_pos = _debug_highlight_marker[0] if not _debug_highlight_marker.is_empty() else Vector2i(-1, -1)
	var match_status = "✅ MATCH" if (highlight_pos.x == grid_pos.x and highlight_pos.y == grid_pos.y) else "❌ MISMATCH"
	print("[InventoryGrid] 🎯 DEBUG: HIGHLIGHT=(%d,%d) → DROP=(%d,%d) %s" % [highlight_pos.x, highlight_pos.y, grid_pos.x, grid_pos.y, match_status])


func set_container(container) -> void:
	"""Set the InventoryContainer reference for collision checking during drag highlight"""
	_container = container


func toggle_grid_visualization():
	"""Toggle debug grid visualization (F3 key)"""
	show_grid = !show_grid
	queue_redraw()
	print("[InventoryGrid] Grid visualization: %s" % ("ON" if show_grid else "OFF"))


func refresh_items_display():
	"""Called when items change - refreshes debug grid visualization"""
	queue_redraw() # Redraw grid lines to match current item positions


func _draw():
	"""Draw tiled background texture and optional debug grid lines"""
	# Use fixed grid size for editor preview when no children exist
	var grid_size = Vector2i(columns, rows) if get_grid_size() == Vector2i(0, 0) else get_grid_size()

	# Draw tiled background texture FIRST (renders behind everything)
	if background_texture:
		var tile_size = Vector2(85, 85) # Cell (80px) + gap (5px)
		var total_width = grid_size.x * (cell_size.x + cell_gap.x)
		var total_height = grid_size.y * (cell_size.y + cell_gap.y)

		# Calculate how many tiles needed to cover the grid area
		var tiles_x = int(ceil(total_width / tile_size.x))
		var tiles_y = int(ceil(total_height / tile_size.y))

		# Draw tiled texture to fill entire grid area
		for y in range(tiles_y):
			for x in range(tiles_x):
				var pos = Vector2(x * tile_size.x, y * tile_size.y)
				draw_texture(background_texture, pos)

	# Draw cell highlights ALWAYS (Professional ARPG UX - Diablo 2 / PoE style)
	# This must render regardless of show_grid so drag highlighting works in normal gameplay
	if not _highlight_cells.is_empty():
		var highlight_color: Color
		match _highlight_state:
			HighlightState.VALID:
				highlight_color = Color(0.0, 1.0, 0.0, 0.3) # Green - empty, valid drop
			HighlightState.SWAP:
				highlight_color = Color(1.0, 0.6, 0.0, 0.3) # Orange - swap will occur
			HighlightState.INVALID:
				highlight_color = Color(1.0, 0.0, 0.0, 0.3) # Red - invalid placement
			_:
				highlight_color = Color(1.0, 0.0, 0.0, 0.3) # Default to red

		for cell in _highlight_cells:
			var x_pos = cell.x * (cell_size.x + cell_gap.x)
			var y_pos = cell.y * (cell_size.y + cell_gap.y)
			var rect = Rect2(x_pos, y_pos, cell_size.x, cell_size.y)
			draw_rect(rect, highlight_color)

	# DEBUG: Draw drop position marker (cyan/blue to contrast with green/orange/red highlights)
	# Shows where item ACTUALLY dropped vs where highlight showed
	if DEBUG_DROP_MARKER and not _debug_drop_marker.is_empty():
		var alpha = clampf(_debug_drop_timer / 2.0, 0.0, 1.0) # Fade out over 2 seconds
		var drop_color = Color(0.0, 0.8, 1.0, 0.5 * alpha) # Cyan with fade
		var border_color = Color(0.0, 0.5, 1.0, alpha) # Blue border

		for cell in _debug_drop_marker:
			var x_pos = cell.x * (cell_size.x + cell_gap.x)
			var y_pos = cell.y * (cell_size.y + cell_gap.y)
			var rect = Rect2(x_pos, y_pos, cell_size.x, cell_size.y)
			draw_rect(rect, drop_color) # Fill
			draw_rect(rect, border_color, false, 3.0) # Border

		# Draw coordinate label at first cell
		if _debug_drop_marker.size() > 0:
			var first_cell = _debug_drop_marker[0]
			var label_x = first_cell.x * (cell_size.x + cell_gap.x) + 5
			var label_y = first_cell.y * (cell_size.y + cell_gap.y) + 20
			var label_text = "DROP: (%d,%d)" % [first_cell.x, first_cell.y]
			draw_string(ThemeDB.fallback_font, Vector2(label_x, label_y), label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.0, 0.8, 1.0, alpha))

	# DEBUG: Draw highlight position marker (magenta - where green highlight WAS)
	# Shows comparison: magenta = where you EXPECTED to drop, cyan = where it ACTUALLY dropped
	if DEBUG_DROP_MARKER and not _debug_highlight_marker.is_empty() and _debug_drop_timer > 0:
		var alpha = clampf(_debug_drop_timer / 2.0, 0.0, 1.0)
		var highlight_color = Color(1.0, 0.0, 1.0, 0.3 * alpha) # Magenta with fade
		var border_color = Color(0.8, 0.0, 0.8, alpha) # Purple border

		for cell in _debug_highlight_marker:
			var x_pos = cell.x * (cell_size.x + cell_gap.x)
			var y_pos = cell.y * (cell_size.y + cell_gap.y)
			var rect = Rect2(x_pos, y_pos, cell_size.x, cell_size.y)
			draw_rect(rect, highlight_color) # Fill
			draw_rect(rect, border_color, false, 2.0) # Border (thinner than cyan)

		# Draw coordinate label at first cell (offset to not overlap with DROP label)
		if _debug_highlight_marker.size() > 0:
			var first_cell = _debug_highlight_marker[0]
			var label_x = first_cell.x * (cell_size.x + cell_gap.x) + 5
			var label_y = first_cell.y * (cell_size.y + cell_gap.y) + 40 # Below DROP label
			var label_text = "HIGHLIGHT: (%d,%d)" % [first_cell.x, first_cell.y]
			draw_string(ThemeDB.fallback_font, Vector2(label_x, label_y), label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.0, 1.0, alpha))

	# Draw debug grid lines (only when enabled)
	if not show_grid:
		return

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


## Parent-Level Drop Handling: Catches drops in gaps between slots
## This solves the "dead zone" problem where 5px gaps have no handler

func _can_drop_data(_at_position: Vector2, data) -> bool:
	"""Fallback handler for drops that miss ItemSlots

	This catches drops in the 5px gaps between cells.
	Only called if no ItemSlot/ItemSprite accepted the drop first.
	Validates if drop would be valid at nearest grid position.
	"""
	if not data is Dictionary or not data.has("item_id"):
		return false

	# Get item data to check dimensions
	var item_data = ItemDatabase.get_item(data.item_id)
	if not item_data:
		return false

	# Get grab offset for anchor point correction
	var grab_offset_x = data.get("grab_offset_x", 0)
	var grab_offset_y = data.get("grab_offset_y", 0)

	# Convert mouse position to grid coordinates with smart clamping
	# Pass item dimensions so edge drops auto-snap to valid positions
	var grid_pos = screen_to_grid(
		get_global_mouse_position(),
		Vector2i(grab_offset_x, grab_offset_y),
		item_data.inventory_width,
		item_data.inventory_height
	)

	# Validate bounds (should always pass now due to smart clamping, but check anyway)
	return is_valid_grid_position(grid_pos, item_data.inventory_width, item_data.inventory_height)


func _drop_data(_at_position: Vector2, data):
	"""Forward gap drops to nearest ItemSlot

	When user drops in a gap, find the nearest slot and delegate.
	Creates a 'magnetic snap' feel where gaps automatically find slots.
	"""
	# Get item data for smart clamping
	var item_data = ItemDatabase.get_item(data.get("item_id", ""))
	var item_w = item_data.inventory_width if item_data else 1
	var item_h = item_data.inventory_height if item_data else 1

	# Get grab offset
	var grab_offset_x = data.get("grab_offset_x", 0)
	var grab_offset_y = data.get("grab_offset_y", 0)

	# Convert to grid coordinates with smart clamping
	var grid_pos = screen_to_grid(
		get_global_mouse_position(),
		Vector2i(grab_offset_x, grab_offset_y),
		item_w,
		item_h
	)

	# Find ItemSlot at this position
	var target_slot = _find_slot_at_grid(grid_pos.x, grid_pos.y)
	if not target_slot:
		if DEBUG_LOGGING:
			print("[InventoryGrid] ❌ Gap drop failed - no slot at (%d,%d)" % [grid_pos.x, grid_pos.y])
		return

	# Delegate to ItemSlot's handler
	if DEBUG_LOGGING:
		print("[InventoryGrid] 🧲 Gap drop → Snapped to slot (%d,%d)" % [grid_pos.x, grid_pos.y])

	# 🔧 FIX: Pass calculated grid_pos to ItemSlot (fixes coordinate mismatch bug)
	# ItemSlot was using its own grid_x/y instead of the calculated drop position
	data["target_grid_x"] = grid_pos.x
	data["target_grid_y"] = grid_pos.y

	# DEBUG: Show where item actually drops (compare to green highlight)
	show_debug_drop_marker(grid_pos, item_w, item_h)

	# Call ItemSlot's sprite drop handler
	var source_sprite = data.get("source_sprite")
	if source_sprite:
		target_slot._handle_sprite_drop(data)
	else:
		# Regular slot-to-slot drop
		target_slot._drop_data(_at_position, data)


func _find_slot_at_grid(x: int, y: int) -> InventoryGridSlot:
	"""Find InventoryGridSlot at specific grid coordinates

	Searches all children for an InventoryGridSlot matching the grid position.
	Returns null if no slot found at that position.
	"""
	for child in get_children():
		if child is InventoryGridSlot:
			if child.grid_x == x and child.grid_y == y:
				return child
	return null
