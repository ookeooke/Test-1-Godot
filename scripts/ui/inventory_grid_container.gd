extends Control
class_name InventoryGridContainer

## Custom inventory grid that supports variable-sized items (Diablo 2 style)
## Unlike GridContainer, this allows items to span multiple cells with absolute positioning

@export var columns: int = 8
@export var cell_size: Vector2 = Vector2(80, 80)
@export var cell_gap: Vector2 = Vector2(5, 5)

func _ready():
	# Connect to child signals to trigger layout when children are added
	child_entered_tree.connect(_on_child_added)

	# Initial layout
	call_deferred("_layout_children")


func _on_child_added(_child: Node):
	"""Trigger layout when a new child is added"""
	call_deferred("_layout_children")


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
	var grid_size = get_grid_size()

	var min_width = grid_size.x * cell_size.x + (grid_size.x - 1) * cell_gap.x
	var min_height = grid_size.y * cell_size.y + (grid_size.y - 1) * cell_gap.y

	return Vector2(min_width, min_height)
