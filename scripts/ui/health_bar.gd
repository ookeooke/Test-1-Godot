extends Control

# Kingdom Rush-style Health Bar (ColorRect approach)
# Simple, reliable, and works exactly like Kingdom Rush
# Always positioned above enemy/hero, never rotates

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill

# Bar dimensions
const BAR_WIDTH = 50
const BAR_HEIGHT = 6

# Regeneration visual system
var is_showing_regen: bool = false
var regen_tween: Tween = null

func _ready():
	# Start hidden (full health)
	visible = false

	# Ensure proper size
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	# Center the bar above parent
	position = Vector2(-BAR_WIDTH / 2.0, -30)

	# Set z-index to render on top of enemies/heroes
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

func show_regeneration(enabled: bool):
	"""Show green pulse animation during health regeneration (Kingdom Rush style)"""
	is_showing_regen = enabled

	if enabled:
		# Start green pulse animation
		if regen_tween:
			regen_tween.kill()

		regen_tween = create_tween()
		regen_tween.set_loops()

		# Pulse between green and white (soft, subtle effect)
		regen_tween.tween_property(fill, "modulate", Color(0.5, 1.0, 0.5), 0.5)  # Fade to green
		regen_tween.tween_property(fill, "modulate", Color(1.0, 1.0, 1.0), 0.5)  # Fade to white
	else:
		# Stop pulse, return to normal red color
		if regen_tween:
			regen_tween.kill()
			regen_tween = null

		if fill:
			fill.modulate = Color(1, 1, 1)  # White (normal)
