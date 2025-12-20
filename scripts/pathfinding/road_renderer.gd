@tool
extends Node2D
class_name RoadRenderer

## RoadRenderer - Automatically draws the road path between waypoints
## Add this to your level and it will find all waypoints and draw the road
## The road will update automatically when you move waypoints in the editor

# ============================================
# CONFIGURATION
# ============================================

@export_group("Road Visual Settings")
## Road texture/color
@export var road_color: Color = Color(0.5, 0.4, 0.3, 1.0): # Brighter brown dirt road
	set(value):
		road_color = value
		queue_redraw()

## Road border color
@export var road_border_color: Color = Color(0.25, 0.2, 0.15, 1.0): # Darker brown border
	set(value):
		road_border_color = value
		queue_redraw()

## Road highlight overlay (makes it pop more)
@export var use_highlight_overlay: bool = true:
	set(value):
		use_highlight_overlay = value
		queue_redraw()

@export var highlight_color: Color = Color(0.6, 0.5, 0.4, 0.3): # Subtle highlight
	set(value):
		highlight_color = value
		queue_redraw()

## Show road in game
@export var visible_in_game: bool = true

## Update road every frame in editor (set to false for performance)
@export var auto_update_in_editor: bool = true

## Number of segments to draw between waypoints (higher = smoother curves)
@export var segments_per_connection: int = 20:
	set(value):
		segments_per_connection = max(2, value)
		queue_redraw()

@export_group("Road Style")
## Draw road border
@export var draw_border: bool = true:
	set(value):
		draw_border = value
		queue_redraw()

## Border width in pixels
@export var border_width: float = 6.0:
	set(value):
		border_width = value
		queue_redraw()

## Draw grid lines on road
@export var draw_grid_lines: bool = false:
	set(value):
		draw_grid_lines = value
		queue_redraw()

@export_group("Directional Indicators")
## Show direction arrows on road
@export var show_direction_arrows: bool = true:
	set(value):
		show_direction_arrows = value
		queue_redraw()

## Arrow spacing (distance between arrows)
@export var arrow_spacing: float = 150.0:
	set(value):
		arrow_spacing = max(50.0, value)
		queue_redraw()

## Arrow color
@export var arrow_color: Color = Color(0.4, 0.35, 0.25, 0.6):
	set(value):
		arrow_color = value
		queue_redraw()

## Arrow size
@export var arrow_size: float = 20.0:
	set(value):
		arrow_size = value
		queue_redraw()

@export_group("Center Line")
## Draw center dashed line (Kingdom Rush style)
@export var draw_center_line: bool = true:
	set(value):
		draw_center_line = value
		queue_redraw()

## Center line color
@export var center_line_color: Color = Color(0.4, 0.3, 0.2, 0.7):
	set(value):
		center_line_color = value
		queue_redraw()

## Dash length
@export var dash_length: float = 20.0:
	set(value):
		dash_length = value
		queue_redraw()

## Gap length
@export var gap_length: float = 15.0:
	set(value):
		gap_length = value
		queue_redraw()

@export_group("Animation (Optional)")
## Animate arrows (moving effect)
@export var animate_arrows: bool = false:
	set(value):
		animate_arrows = value
		set_process(value) # Only process if animating

## Animation speed (pixels per second)
@export var animation_speed: float = 50.0

# ============================================
# RUNTIME VARIABLES
# ============================================

var waypoints: Array[PathWaypoint] = []
var road_segments: Array[Dictionary] = []
var animation_offset: float = 0.0 # For animated arrows

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Add to group
	add_to_group("road_renderer")

	# Find all waypoints
	_update_waypoints()

	# Hide in game unless specified
	if not Engine.is_editor_hint() and not visible_in_game:
		visible = false

	# Draw initial road
	queue_redraw()

func _process(delta):
	# Auto-update in editor mode
	if Engine.is_editor_hint() and auto_update_in_editor:
		queue_redraw()

	# Animate arrows in game
	if animate_arrows and not Engine.is_editor_hint():
		animation_offset += animation_speed * delta
		# Reset offset to prevent overflow
		if animation_offset > arrow_spacing:
			animation_offset -= arrow_spacing
		queue_redraw()

func _draw():
	# Update waypoints list
	_update_waypoints()

	# Build road segments
	_build_road_segments()

	# Draw all road segments
	for segment in road_segments:
		_draw_road_segment(segment)

	# Draw debug info if in editor
	if Engine.is_editor_hint():
		_draw_debug_info()

# ============================================
# WAYPOINT MANAGEMENT
# ============================================

func _update_waypoints():
	"""Find all PathWaypoint nodes in the scene"""
	waypoints.clear()

	# Find all waypoints in the scene tree
	var all_waypoints = get_tree().get_nodes_in_group("waypoints")

	for wp in all_waypoints:
		if wp is PathWaypoint:
			waypoints.append(wp)

func _build_road_segments():
	"""Build a list of road segments to draw"""
	road_segments.clear()

	for waypoint in waypoints:
		# Draw connection to each next waypoint
		for next_wp in waypoint.next_waypoints:
			if is_instance_valid(next_wp):
				road_segments.append({
					"start": waypoint,
					"end": next_wp,
					"start_pos": waypoint.global_position,
					"end_pos": next_wp.global_position,
					"start_width": waypoint.road_width,
					"end_width": next_wp.road_width
				})

# ============================================
# DRAWING FUNCTIONS
# ============================================

func _draw_road_segment(segment: Dictionary):
	"""Draw a single road segment between two waypoints"""
	var start_pos = to_local(segment.start_pos)
	var end_pos = to_local(segment.end_pos)
	var start_width = segment.start_width
	var end_width = segment.end_width

	# Calculate perpendicular direction for road edges
	var direction = (end_pos - start_pos).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)

	# Build points for road polygon (tapered from start width to end width)
	var points_left = PackedVector2Array()
	var points_right = PackedVector2Array()

	for i in range(segments_per_connection + 1):
		var t = float(i) / segments_per_connection
		var pos = start_pos.lerp(end_pos, t)
		var width = lerp(start_width, end_width, t)

		points_left.append(pos + perpendicular * width / 2.0)
		points_right.append(pos - perpendicular * width / 2.0)

	# Combine left and right sides into one polygon
	var road_polygon = points_left
	points_right.reverse()
	road_polygon.append_array(points_right)

	# Draw border first (if enabled)
	if draw_border:
		var border_polygon_left = PackedVector2Array()
		var border_polygon_right = PackedVector2Array()

		for i in range(segments_per_connection + 1):
			var t = float(i) / segments_per_connection
			var pos = start_pos.lerp(end_pos, t)
			var width = lerp(start_width, end_width, t)

			border_polygon_left.append(pos + perpendicular * (width / 2.0 + border_width))
			border_polygon_right.append(pos - perpendicular * (width / 2.0 + border_width))

		var border_polygon = border_polygon_left
		border_polygon_right.reverse()
		border_polygon.append_array(border_polygon_right)

		draw_colored_polygon(border_polygon, road_border_color)

	# Draw main road
	draw_colored_polygon(road_polygon, road_color)

	# Draw highlight overlay for better visibility
	if use_highlight_overlay:
		# Create slightly narrower polygon for highlight
		var highlight_polygon = PackedVector2Array()
		for i in range(segments_per_connection + 1):
			var t = float(i) / segments_per_connection
			var pos = start_pos.lerp(end_pos, t)
			var width = lerp(start_width, end_width, t) * 0.6 # 60% width for highlight
			highlight_polygon.append(pos + perpendicular * width / 2.0)

		for i in range(segments_per_connection, -1, -1):
			var t = float(i) / segments_per_connection
			var pos = start_pos.lerp(end_pos, t)
			var width = lerp(start_width, end_width, t) * 0.6
			highlight_polygon.append(pos - perpendicular * width / 2.0)

		draw_colored_polygon(highlight_polygon, highlight_color)

	# Draw center dashed line (Kingdom Rush style)
	if draw_center_line:
		_draw_center_line(start_pos, end_pos, perpendicular)

	# Draw directional arrows
	if show_direction_arrows:
		_draw_direction_arrows(start_pos, end_pos, direction, perpendicular, start_width, end_width)

	# Draw grid lines (optional decorative effect)
	if draw_grid_lines:
		for i in range(1, segments_per_connection):
			var t = float(i) / segments_per_connection
			var pos = start_pos.lerp(end_pos, t)
			var width = lerp(start_width, end_width, t)

			var left = pos + perpendicular * width / 2.0
			var right = pos - perpendicular * width / 2.0

			draw_line(left, right, Color(0, 0, 0, 0.2), 1.0)

func _draw_center_line(start_pos: Vector2, end_pos: Vector2, _perpendicular: Vector2):
	"""Draw dashed center line down the middle of the road"""
	var total_distance = start_pos.distance_to(end_pos)
	var dash_and_gap = dash_length + gap_length
	var num_dashes = int(total_distance / dash_and_gap)

	for i in range(num_dashes):
		var dash_start_t = (i * dash_and_gap) / total_distance
		var dash_end_t = (i * dash_and_gap + dash_length) / total_distance

		if dash_end_t > 1.0:
			dash_end_t = 1.0

		var dash_start = start_pos.lerp(end_pos, dash_start_t)
		var dash_end = start_pos.lerp(end_pos, dash_end_t)

		draw_line(dash_start, dash_end, center_line_color, 3.0)

func _draw_direction_arrows(start_pos: Vector2, end_pos: Vector2, direction: Vector2, perpendicular: Vector2, _start_width: float, _end_width: float):
	"""Draw directional arrows showing enemy movement direction"""
	var total_distance = start_pos.distance_to(end_pos)
	var num_arrows = max(1, int(total_distance / arrow_spacing))

	for i in range(num_arrows):
		var base_t = (float(i) + 0.5) / num_arrows # Center arrows in segments

		# Apply animation offset if enabled
		var offset_distance = 0.0
		if animate_arrows:
			offset_distance = animation_offset

		var arrow_distance = base_t * total_distance + offset_distance
		# Wrap around
		arrow_distance = fmod(arrow_distance, total_distance)
		var t = arrow_distance / total_distance

		var arrow_pos = start_pos.lerp(end_pos, t)
		# var width_at_arrow = lerp(start_width, end_width, t) # Unused

		# Draw arrow chevron pointing in direction of travel
		var arrow_forward = direction * arrow_size
		var arrow_back = - direction * arrow_size * 0.6
		var arrow_side = perpendicular * arrow_size * 0.5

		# Create chevron shape (> pointing forward)
		var arrow_points = PackedVector2Array([
			arrow_pos + arrow_back + arrow_side, # Top left
			arrow_pos + arrow_forward, # Point
			arrow_pos + arrow_back - arrow_side # Bottom left
		])

		# Draw filled chevron
		draw_colored_polygon(arrow_points, arrow_color)

		# Draw outline for better visibility
		draw_polyline(arrow_points, Color(0, 0, 0, 0.4), 2.0)

func _draw_debug_info():
	"""Draw debug information in editor"""
	if waypoints.is_empty():
		# Show warning if no waypoints found
		var font = ThemeDB.fallback_font
		var text = "No waypoints found! Add PathWaypoint nodes to the scene."
		draw_string(font, Vector2(10, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED)

# ============================================
# HELPER FUNCTIONS
# ============================================

func get_road_segments() -> Array[Dictionary]:
	"""Get all road segments (useful for other systems)"""
	_build_road_segments()
	return road_segments

func is_point_on_road(point: Vector2, tolerance: float = 20.0) -> bool:
	"""Check if a point is on the road (useful for tower placement validation)"""
	# WEB FIX: Lazy-load waypoints if list is empty (handles race conditions where level loads after renderer)
	if waypoints.is_empty():
		_update_waypoints()
		_build_road_segments()
		
	for waypoint in waypoints:
		if waypoint.is_point_in_road_area(point):
			return true

	# Also check if point is near any road segment
	for segment in road_segments:
		var closest = Geometry2D.get_closest_point_to_segment(
			point,
			segment.start_pos,
			segment.end_pos
		)
		var distance = point.distance_to(closest)

		# Get width at this point
		var segment_length = segment.start_pos.distance_to(segment.end_pos)
		var point_distance = segment.start_pos.distance_to(closest)
		var t = point_distance / segment_length if segment_length > 0 else 0
		var width_at_point = lerp(segment.start_width, segment.end_width, t)

		if distance <= width_at_point / 2.0 + tolerance:
			return true

	return false

func get_start_waypoint() -> PathWaypoint:
	"""Get the first waypoint (no incoming connections)"""
	for wp in waypoints:
		var is_start = true
		for other in waypoints:
			if other.next_waypoints.has(wp):
				is_start = false
				break
		if is_start:
			return wp
	return null

func get_end_waypoints() -> Array[PathWaypoint]:
	"""Get all end waypoints (no outgoing connections)"""
	var ends: Array[PathWaypoint] = []
	for wp in waypoints:
		if wp.next_waypoints.is_empty():
			ends.append(wp)
	return ends
