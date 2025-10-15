extends Control

# Kingdom Rush-style Health Bar (ColorRect approach)
# Simple, reliable, and works exactly like Kingdom Rush

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill

# Bar dimensions
const BAR_WIDTH = 50
const BAR_HEIGHT = 6

func _ready():
	# Start hidden (full health)
	visible = false

	# Ensure proper size
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	# Center the bar above parent
	position = Vector2(-BAR_WIDTH / 2.0, -30)

	# Set z-index to render on top
	z_index = 100

func update_health(current: float, maximum: float):
	if maximum <= 0:
		return

	var percentage = clamp(current / maximum, 0.0, 1.0)

	# Update fill width
	if fill:
		fill.size.x = BAR_WIDTH * percentage

	# Kingdom Rush behavior: hide at 100%, show when damaged
	if percentage >= 1.0:
		visible = false
	else:
		visible = true
