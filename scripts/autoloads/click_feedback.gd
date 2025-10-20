extends Node

## ============================================
## CLICK FEEDBACK - Visual and audio feedback for clicks
## ============================================
##
## Provides consistent click feedback across the game:
## - Click sounds
## - Visual ripple effects
## - Invalid click feedback (shake/red flash)

# Audio streams (assign these in the inspector or via code)
var click_sound: AudioStream = null
var invalid_click_sound: AudioStream = null

# Visual effect scenes
var ripple_effect_scene: PackedScene = null

func _ready():
	print("ClickFeedback system ready")
	# TODO: Load audio and visual effects when available

## ============================================
## PUBLIC API
## ============================================

func play_click_feedback(position: Vector2 = Vector2.ZERO):
	"""Play successful click feedback (sound + visual)"""
	play_click_sound(position)
	show_ripple_effect(position)

func play_invalid_click_feedback(position: Vector2 = Vector2.ZERO):
	"""Play invalid click feedback (error sound + shake)"""
	play_invalid_sound(position)
	show_invalid_effect(position)

## ============================================
## AUDIO FEEDBACK
## ============================================

func play_click_sound(_position: Vector2):
	"""Play click sound at position"""
	if click_sound:
		var player = AudioStreamPlayer.new()
		player.stream = click_sound
		player.volume_db = -10
		add_child(player)
		player.play()
		# Auto-cleanup
		player.finished.connect(func(): player.queue_free())
	# else:
		# print("ClickFeedback: No click sound assigned")

func play_invalid_sound(_position: Vector2):
	"""Play invalid click sound"""
	if invalid_click_sound:
		var player = AudioStreamPlayer.new()
		player.stream = invalid_click_sound
		player.volume_db = -5
		add_child(player)
		player.play()
		player.finished.connect(func(): player.queue_free())
	# else:
		# print("ClickFeedback: No invalid click sound assigned")

## ============================================
## VISUAL FEEDBACK
## ============================================

func show_ripple_effect(position: Vector2):
	"""Show ripple effect at click position"""
	if ripple_effect_scene:
		var ripple = ripple_effect_scene.instantiate()
		ripple.global_position = position
		get_tree().root.add_child(ripple)
	else:
		# Fallback: Create simple ripple using particles or sprite
		_create_simple_ripple(position)

func show_invalid_effect(position: Vector2):
	"""Show red flash or shake for invalid clicks"""
	# TODO: Implement red flash effect
	_create_simple_invalid_flash(position)

func _create_simple_ripple(position: Vector2):
	"""Create a simple ripple effect using a Circle shape"""
	var circle = ColorRect.new()
	circle.size = Vector2(10, 10)
	circle.position = position - circle.size / 2
	circle.color = Color(1, 1, 1, 0.5)

	get_tree().root.add_child(circle)

	# Animate size and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "size", Vector2(60, 60), 0.3)
	tween.tween_property(circle, "position", position - Vector2(30, 30), 0.3)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): circle.queue_free())

func _create_simple_invalid_flash(position: Vector2):
	"""Create red flash for invalid clicks"""
	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.position = position - flash.size / 2
	flash.color = Color(1, 0, 0, 0.7)

	get_tree().root.add_child(flash)

	# Quick flash and fade
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func(): flash.queue_free())

## ============================================
## HELPERS
## ============================================

func set_click_sound(sound: AudioStream):
	"""Set the click sound effect"""
	click_sound = sound

func set_invalid_click_sound(sound: AudioStream):
	"""Set the invalid click sound effect"""
	invalid_click_sound = sound

func set_ripple_effect(scene: PackedScene):
	"""Set custom ripple effect scene"""
	ripple_effect_scene = scene
