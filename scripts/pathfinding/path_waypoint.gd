@tool
extends Node2D
class_name PathWaypoint

## PathWaypoint - Waypoint system for tower defense enemy paths
## Place these nodes to define the enemy path with variable road width
## Enemies will move from waypoint to waypoint with random positions within the road width

# ============================================
# CONFIGURATION
# ============================================

@export_group("Waypoint Connection")
## Next waypoint(s) in the path. Can have multiple for branching paths!
@export var next_waypoints: Array[PathWaypoint] = []

@export_group("Road Width")
## Width of the road at this waypoint (enemies can spread out within this width)
@export var road_width: float = 100.0:
	set(value):
		road_width = value
		queue_redraw()

@export_group("Visual Settings")
## Color of the waypoint marker in editor
@export var waypoint_color: Color = Color(1.0, 0.8, 0.0, 1.0): # Yellow
	set(value):
		waypoint_color = value
		queue_redraw()

## Show waypoint in game (not just editor)
@export var visible_in_game: bool = false

## Waypoint marker size
@export var marker_radius: float = 15.0:
	set(value):
		marker_radius = value
		queue_redraw()

@export_group("Soldier Tower Placement")
## Can soldier towers be placed at this waypoint?
@export var allows_soldier_placement: bool = true

# ============================================
# RUNTIME VARIABLES
# ============================================

# Unique ID for this waypoint (for debugging)
var waypoint_id: int = 0

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Assign unique ID
	waypoint_id = get_instance_id()

	# Hide in game unless specified
	if not Engine.is_editor_hint() and not visible_in_game:
		visible = false

	# Add to waypoint group for easy finding
	add_to_group("waypoints")

	# Trigger initial draw
	queue_redraw()

func _draw():
	# Draw waypoint marker (always visible in editor)
	if Engine.is_editor_hint() or visible_in_game:
		# Draw road width circle (semi-transparent)
		draw_circle(Vector2.ZERO, road_width / 2.0, Color(waypoint_color, 0.15))

		# Draw road width outline
		draw_arc(Vector2.ZERO, road_width / 2.0, 0, TAU, 32, Color(waypoint_color, 0.4), 2.0)

		# Draw center waypoint marker
		draw_circle(Vector2.ZERO, marker_radius, waypoint_color)

		# Draw inner circle for contrast
		draw_circle(Vector2.ZERO, marker_radius * 0.6, Color(1, 1, 1, 0.8))

		# Draw waypoint number/ID
		var text = str(name)
		var font = ThemeDB.fallback_font
		var font_size = 12
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2(-text_size.x / 2.0, font_size / 2.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)

		# Draw connections to next waypoints
		for next_wp in next_waypoints:
			if is_instance_valid(next_wp):
				var direction = to_local(next_wp.global_position)
				var distance = direction.length()

				# Draw arrow line
				draw_line(Vector2.ZERO, direction, Color.GREEN, 3.0)

				# Draw arrowhead
				var arrow_pos = direction.normalized() * (distance - marker_radius)
				var arrow_size = 15.0
				var perp = Vector2(-direction.y, direction.x).normalized()
				var arrow_points = PackedVector2Array([
					arrow_pos,
					arrow_pos - direction.normalized() * arrow_size + perp * arrow_size * 0.5,
					arrow_pos - direction.normalized() * arrow_size - perp * arrow_size * 0.5
				])
				draw_colored_polygon(arrow_points, Color.GREEN)

		# Draw soldier placement indicator
		if allows_soldier_placement:
			draw_arc(Vector2.ZERO, marker_radius + 5, 0, TAU, 16, Color(0.8, 0.4, 0.2, 0.8), 2.0)

# ============================================
# WAYPOINT FUNCTIONS
# ============================================

func get_random_position_in_road() -> Vector2:
	"""Get a random position within the road width at this waypoint"""
	var offset = Vector2(
		randf_range(-road_width / 2.0, road_width / 2.0),
		randf_range(-road_width / 2.0, road_width / 2.0)
	)
	return global_position + offset

func get_next_waypoint() -> PathWaypoint:
	"""Get the next waypoint (random if multiple branches)"""
	if next_waypoints.is_empty():
		return null

	if next_waypoints.size() == 1:
		return next_waypoints[0]

	# Multiple branches - pick random
	return next_waypoints.pick_random()

func is_point_in_road_area(point: Vector2) -> bool:
	"""Check if a point is within this waypoint's road width"""
	var distance = global_position.distance_to(point)
	return distance <= road_width / 2.0

func get_direction_to_next() -> Vector2:
	"""Get the direction vector to the next waypoint"""
	var next = get_next_waypoint()
	if not next:
		return Vector2.ZERO
	return (next.global_position - global_position).normalized()

# ============================================
# EDITOR HELPER FUNCTIONS
# ============================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()

	# Warn if no next waypoint (unless this is intentionally the end)
	if next_waypoints.is_empty() and not name.to_lower().contains("end"):
		warnings.append("No next waypoints connected. Is this the end of the path?")

	# Warn if road width is very small
	if road_width < 50.0:
		warnings.append("Road width is very narrow (< 50px). Enemies might overlap.")

	return warnings
