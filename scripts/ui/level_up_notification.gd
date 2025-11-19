extends Control

##
## Level-Up Notification
##
## Animated popup that appears when hero levels up
## Floats upward and fades out, then auto-destroys
## Spawn this at hero's screen position
##

@onready var label = $PanelContainer/VBoxContainer/LevelUpLabel
@onready var level_label = $PanelContainer/VBoxContainer/LevelNumberLabel

# Animation settings
const RISE_DISTANCE = 80.0  # Pixels to float upward
const ANIMATION_DURATION = 2.0  # Total animation time
const FADE_START = 1.0  # When to start fading (seconds)


func _ready():
	# Start animation sequence
	_animate()


func show_level_up(new_level: int):
	"""Set the level number and update text"""
	if level_label:
		level_label.text = "Level %d" % new_level


func _animate():
	"""Animate notification: rise + fade out"""
	# Create tween for animation
	var tween = create_tween()
	tween.set_parallel(true)  # Run animations simultaneously

	# Initial setup
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	# Phase 1: Fade in + scale up (0.3s)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Phase 2: Rise upward (entire duration)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, ANIMATION_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Phase 3: Fade out (starts after FADE_START)
	tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION - FADE_START) \
		.set_delay(FADE_START).set_ease(Tween.EASE_IN)

	# Destroy after animation completes
	await tween.finished
	queue_free()


## Static helper to spawn notification at a position
static func spawn_at_position(spawn_position: Vector2, level: int, parent: Node = null) -> Control:
	"""Spawn a level-up notification at the given position"""
	# Load scene
	var notification_scene = preload("res://scenes/ui/level_up_notification.tscn")
	var notification = notification_scene.instantiate()

	# Set level
	if notification.has_method("show_level_up"):
		notification.show_level_up(level)

	# Position notification
	notification.global_position = spawn_position

	# Add to scene tree (parent or root)
	if parent:
		parent.add_child(notification)
	else:
		notification.get_tree().root.add_child(notification)

	return notification
