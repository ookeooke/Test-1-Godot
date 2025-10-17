extends Node2D

## Hit Marker - Red X that appears briefly when projectile hits enemy
## Classic tower defense visual feedback

@export var lifetime: float = 0.3  ## How long the X stays visible (seconds)
@export var fade_time: float = 0.15  ## How long it takes to fade out (seconds)
@export var scale_animation: bool = true  ## Scale up slightly when appearing
@export var initial_scale: float = 0.5  ## Starting scale (for pop effect)

var elapsed_time: float = 0.0
var x_visual: Polygon2D

func _ready():
	# Create the red X visual
	x_visual = Polygon2D.new()
	add_child(x_visual)

	# Draw X shape using two diagonal lines
	var size = 12.0  # Size of the X
	var thickness = 3.0  # Thickness of the lines

	# Create X by combining two rectangles (diagonal lines)
	# Line 1: Top-left to bottom-right
	var line1_points = PackedVector2Array([
		Vector2(-size, -size),
		Vector2(-size + thickness, -size),
		Vector2(size, size),
		Vector2(size - thickness, size)
	])

	# Line 2: Top-right to bottom-left
	var line2_points = PackedVector2Array([
		Vector2(size, -size),
		Vector2(size - thickness, -size),
		Vector2(-size, size),
		Vector2(-size + thickness, size)
	])

	# Combine both lines into one polygon for the X
	# Create full X shape by drawing both diagonals
	var x_points = PackedVector2Array([
		Vector2(-size * 0.7, -size),
		Vector2(-size, -size * 0.7),
		Vector2(-size * 0.3, 0),
		Vector2(-size, size * 0.7),
		Vector2(-size * 0.7, size),
		Vector2(0, size * 0.3),
		Vector2(size * 0.7, size),
		Vector2(size, size * 0.7),
		Vector2(size * 0.3, 0),
		Vector2(size, -size * 0.7),
		Vector2(size * 0.7, -size),
		Vector2(0, -size * 0.3)
	])

	x_visual.polygon = x_points
	x_visual.color = Color(1, 0, 0, 1)  # Bright red
	x_visual.z_index = 100  # Draw on top

	# Optional: Add black outline for contrast
	var outline = Line2D.new()
	add_child(outline)
	outline.points = x_points
	outline.closed = true
	outline.width = 1.5
	outline.default_color = Color(0, 0, 0, 0.8)
	outline.z_index = 99

	# Start small if scale animation enabled
	if scale_animation:
		scale = Vector2(initial_scale, initial_scale)

func _process(delta):
	elapsed_time += delta

	# Scale animation - pop in
	if scale_animation and elapsed_time < 0.1:
		var progress = elapsed_time / 0.1
		var target_scale = lerp(initial_scale, 1.0, progress)
		scale = Vector2(target_scale, target_scale)

	# Fade out near end of lifetime
	var fade_start_time = lifetime - fade_time
	if elapsed_time > fade_start_time:
		var fade_progress = (elapsed_time - fade_start_time) / fade_time
		var alpha = 1.0 - fade_progress
		modulate = Color(1, 1, 1, alpha)

	# Cleanup when lifetime expires
	if elapsed_time >= lifetime:
		queue_free()
