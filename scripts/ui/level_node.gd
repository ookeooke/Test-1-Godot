extends Control
class_name LevelNode

# LevelNode - Kingdom Rush style animated level button
# Features: bounce animation, glow, star display, locked/unlocked states

signal level_selected(level_data: LevelNodeData)

@export var level_data: LevelNodeData

# Node references
@onready var button: Button = $Button
@onready var stars_container: HBoxContainer = $StarsContainer
@onready var star_1: TextureRect = $StarsContainer/Star1
@onready var star_2: TextureRect = $StarsContainer/Star2
@onready var star_3: TextureRect = $StarsContainer/Star3
@onready var lock_icon: TextureRect = $LockIcon
@onready var glow_effect: ColorRect = $GlowEffect
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var level_label: Label = $LevelLabel

# State
var is_unlocked: bool = false
var earned_stars: int = 0
var is_hovered: bool = false

# Animation properties
var bounce_timer: float = 0.0
var bounce_offset: float = 0.0
var glow_intensity: float = 0.0

func _ready():
	if button:
		button.pressed.connect(_on_button_pressed)
		button.mouse_entered.connect(_on_mouse_entered)
		button.mouse_exited.connect(_on_mouse_exited)

	# Initialize animations
	_setup_animations()

	# Update visual state
	if level_data:
		update_display()

func _setup_animations():
	# Create animation player if it doesn't exist
	if not animation_player:
		animation_player = AnimationPlayer.new()
		add_child(animation_player)

	# Setup bounce animation
	var bounce_anim = Animation.new()
	var track_index = bounce_anim.add_track(Animation.TYPE_VALUE)
	bounce_anim.track_set_path(track_index, ".:position:y")
	bounce_anim.length = 2.0
	bounce_anim.loop_mode = Animation.LOOP_LINEAR

	# Keyframes for bounce
	bounce_anim.track_insert_key(track_index, 0.0, 0.0)
	bounce_anim.track_insert_key(track_index, 1.0, -10.0)
	bounce_anim.track_insert_key(track_index, 2.0, 0.0)

	animation_player.add_animation("bounce", bounce_anim)

	# Setup glow pulse animation
	var glow_anim = Animation.new()
	var glow_track = glow_anim.add_track(Animation.TYPE_VALUE)
	glow_anim.track_set_path(glow_track, "GlowEffect:modulate:a")
	glow_anim.length = 1.5
	glow_anim.loop_mode = Animation.LOOP_LINEAR

	glow_anim.track_insert_key(glow_track, 0.0, 0.3)
	glow_anim.track_insert_key(glow_track, 0.75, 0.7)
	glow_anim.track_insert_key(glow_track, 1.5, 0.3)

	animation_player.add_animation("glow_pulse", glow_anim)

func update_display():
	if not level_data:
		return

	# Check if level is unlocked
	is_unlocked = _check_unlock_status()

	# Get stars earned
	earned_stars = SaveManager.get_level_stars(level_data.level_id)

	# Update label
	if level_label:
		level_label.text = level_data.level_name

	# Update button state
	if button:
		button.disabled = not is_unlocked
		if is_unlocked:
			button.modulate = Color.WHITE
		else:
			button.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# Update lock icon
	if lock_icon:
		lock_icon.visible = not is_unlocked

	# Update stars
	_update_stars()

	# Start animations if unlocked
	if is_unlocked and animation_player:
		# Gentle bounce for unlocked levels
		animation_player.play("bounce")

		# Glow effect if not yet completed
		if earned_stars == 0:
			if glow_effect:
				glow_effect.visible = true
			animation_player.play("glow_pulse")
		else:
			if glow_effect:
				glow_effect.visible = false
	else:
		if animation_player:
			animation_player.stop()
		if glow_effect:
			glow_effect.visible = false

func _check_unlock_status() -> bool:
	if not level_data:
		return false

	# First level is always unlocked
	if level_data.required_level_id.is_empty():
		return true

	# Check if required level is completed
	if not SaveManager.is_level_completed(level_data.required_level_id):
		return false

	# Check star requirements
	if level_data.required_stars > 0:
		var total_stars = _get_total_stars_earned()
		return total_stars >= level_data.required_stars

	return true

func _get_total_stars_earned() -> int:
	var total = 0
	# This would need to sum all stars from all levels
	# For now, just check the required level
	if not level_data.required_level_id.is_empty():
		total = SaveManager.get_level_stars(level_data.required_level_id)
	return total

func _update_stars():
	if not stars_container:
		return

	# Hide all stars initially
	if star_1:
		star_1.modulate = Color(0.3, 0.3, 0.3, 1.0)
	if star_2:
		star_2.modulate = Color(0.3, 0.3, 0.3, 1.0)
	if star_3:
		star_3.modulate = Color(0.3, 0.3, 0.3, 1.0)

	# Show earned stars
	if earned_stars >= 1 and star_1:
		star_1.modulate = Color(1.0, 0.9, 0.0, 1.0)  # Gold
	if earned_stars >= 2 and star_2:
		star_2.modulate = Color(1.0, 0.9, 0.0, 1.0)
	if earned_stars >= 3 and star_3:
		star_3.modulate = Color(1.0, 0.9, 0.0, 1.0)

	# Hide stars container if locked
	stars_container.visible = is_unlocked

func _on_button_pressed():
	if is_unlocked and level_data:
		level_selected.emit(level_data)

func _on_mouse_entered():
	is_hovered = true
	if is_unlocked and button:
		# Scale up on hover
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)

func _on_mouse_exited():
	is_hovered = false
	if button:
		# Scale back to normal
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2)

func set_level_data(data: LevelNodeData):
	level_data = data
	if is_node_ready():
		update_display()
