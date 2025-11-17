@tool
extends Control
class_name EquipmentSlotGrid

## Visual grid background for equipment slots
## Draws tile grid lines matching the inventory system style
## @tool directive enables grid rendering in Godot editor preview

@export var grid_width: int = 2  # Number of tiles wide
@export var grid_height: int = 2  # Number of tiles tall
@export var tile_size: int = 80  # Size of each tile in pixels
@export var tile_gap: int = 5    # Gap between tiles in pixels
@export var show_grid: bool = true  # Toggle grid visibility

@export_group("Visual Settings")
@export var grid_color: Color = Color(0.5, 0.5, 1.0, 0.3)  # Semi-transparent blue
@export var line_width: float = 1.0


func _ready():
	# Set minimum size based on grid dimensions
	custom_minimum_size = _calculate_size()
	queue_redraw()


func _calculate_size() -> Vector2:
	"""Calculate total size needed for this grid"""
	var width = (grid_width * tile_size) + ((grid_width - 1) * tile_gap)
	var height = (grid_height * tile_size) + ((grid_height - 1) * tile_gap)
	return Vector2(width, height)


func set_grid_dimensions(width: int, height: int):
	"""Update grid dimensions and redraw"""
	grid_width = width
	grid_height = height
	custom_minimum_size = _calculate_size()
	queue_redraw()


func toggle_grid_visibility():
	"""Toggle grid line visibility"""
	show_grid = !show_grid
	queue_redraw()


func _draw():
	"""Draw grid lines"""
	if not show_grid:
		return

	var total_width = (grid_width * tile_size) + ((grid_width - 1) * tile_gap)
	var total_height = (grid_height * tile_size) + ((grid_height - 1) * tile_gap)

	# Draw vertical lines
	for x in range(grid_width + 1):
		var x_pos = x * (tile_size + tile_gap)
		var start_pos = Vector2(x_pos, 0)
		var end_pos = Vector2(x_pos, total_height)
		draw_line(start_pos, end_pos, grid_color, line_width)

	# Draw horizontal lines
	for y in range(grid_height + 1):
		var y_pos = y * (tile_size + tile_gap)
		var start_pos = Vector2(0, y_pos)
		var end_pos = Vector2(total_width, y_pos)
		draw_line(start_pos, end_pos, grid_color, line_width)
