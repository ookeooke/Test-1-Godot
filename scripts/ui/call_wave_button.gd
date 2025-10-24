extends Button

# ============================================
# CALL NEXT WAVE BUTTON - Kingdom Rush Style
# ============================================
# Floating button that appears at spawn points during wave breaks
# Allows player to call the next wave early for a gold bonus

# ============================================
# SIGNALS
# ============================================
signal wave_called()  # Emitted when player clicks to call next wave

# ============================================
# CONFIGURATION
# ============================================
@export var spawn_world_position: Vector2 = Vector2.ZERO  # World position to follow
@export var base_gold_bonus: int = 5  # Maximum gold bonus for instant call
@export var show_gold_bonus: bool = true  # Display bonus amount on button

# ============================================
# ANIMATION SETTINGS
# ============================================
@export_group("Animation")
@export var bounce_amount: float = 8.0  # Vertical bounce distance in pixels
@export var bounce_speed: float = 2.0  # Bounce cycles per second
@export var pulse_enabled: bool = true  # Enable color pulse effect
@export var pulse_speed: float = 1.5  # Pulse cycles per second

# ============================================
# STATE
# ============================================
var camera: Camera2D = null
var base_y_offset: float = 0.0  # Base vertical offset for positioning
var time_accumulated: float = 0.0  # For animation timing
var is_animating: bool = true

# Break timer tracking (for gold bonus calculation)
var break_time_total: float = 3.0  # Total break duration
var break_time_remaining: float = 3.0  # Time left in break
var current_gold_bonus: int = 5  # Current bonus amount

# Tweens for animations
var appear_tween: Tween
var click_tween: Tween

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Find the camera in the scene
	camera = get_viewport().get_camera_2d()
	if not camera:
		push_error("[CallWaveButton] No Camera2D found in scene!")
		queue_free()
		return

	# Connect button signals
	pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Set initial appearance
	modulate = Color.WHITE
	scale = Vector2.ZERO  # Start invisible for appear animation

	# Play appear animation
	play_appear_animation()

	# Update button text
	update_button_text()

# ============================================
# ANIMATION FUNCTIONS
# ============================================

func play_appear_animation():
	"""Appear with elastic bounce (Kingdom Rush style)"""
	if appear_tween:
		appear_tween.kill()

	appear_tween = create_tween()
	appear_tween.set_ease(Tween.EASE_OUT)
	appear_tween.set_trans(Tween.TRANS_ELASTIC)

	# Scale from 0 → 1.2 → 1.0 with elastic bounce
	appear_tween.tween_property(self, "scale", Vector2.ONE * 1.2, 0.3)
	appear_tween.tween_property(self, "scale", Vector2.ONE, 0.2)

	# Start idle animation after appearing
	await appear_tween.finished
	is_animating = true

func play_click_animation():
	"""Click animation: scale down and disappear"""
	is_animating = false  # Stop idle animation

	if click_tween:
		click_tween.kill()

	click_tween = create_tween()
	click_tween.set_parallel(true)
	click_tween.set_ease(Tween.EASE_IN)
	click_tween.set_trans(Tween.TRANS_BACK)

	# Scale down and fade out
	click_tween.tween_property(self, "scale", Vector2.ONE * 0.3, 0.2)
	click_tween.tween_property(self, "modulate:a", 0.0, 0.2)

func _on_mouse_entered():
	"""Hover effect: scale up slightly"""
	if not is_animating:
		return

	var hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.tween_property(self, "scale", Vector2.ONE * 1.15, 0.1)

func _on_mouse_exited():
	"""Exit hover: return to normal scale"""
	if not is_animating:
		return

	var hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# ============================================
# UPDATE FUNCTIONS
# ============================================

func _process(delta):
	# Skip if camera not found
	if not camera:
		return

	# Update screen position based on world position and camera
	update_screen_position()

	# Update idle animations
	if is_animating:
		update_idle_animations(delta)

	# Update gold bonus based on remaining time
	update_gold_bonus(delta)

func update_screen_position():
	"""Convert world position to screen position, accounting for camera"""
	if not camera:
		return

	# Get viewport size
	var viewport_size = get_viewport_rect().size

	# Calculate offset from camera center to spawn point (in world space)
	var world_offset = spawn_world_position - camera.global_position

	# Convert to screen space (multiply by zoom)
	var screen_offset = world_offset * camera.zoom

	# Position relative to screen center, with base offset
	var screen_pos = viewport_size / 2.0 + screen_offset
	screen_pos.y += base_y_offset  # Add vertical offset for positioning above spawn

	# Clamp to viewport bounds (keep button on screen)
	var button_size = size
	screen_pos.x = clamp(screen_pos.x, button_size.x / 2, viewport_size.x - button_size.x / 2)
	screen_pos.y = clamp(screen_pos.y, button_size.y / 2, viewport_size.y - button_size.y / 2)

	# Set position (anchored at center)
	position = screen_pos - size / 2.0

func update_idle_animations(delta):
	"""Update bounce and pulse animations"""
	time_accumulated += delta

	# Bounce animation (vertical movement)
	var bounce_offset = sin(time_accumulated * bounce_speed * TAU) * bounce_amount
	base_y_offset = -60.0 + bounce_offset  # Float above spawn point with bounce

	# Pulse animation (color tint)
	if pulse_enabled:
		var pulse = (sin(time_accumulated * pulse_speed * TAU) + 1.0) / 2.0  # 0.0 to 1.0
		var pulse_color = Color.WHITE.lerp(Color(1.0, 0.9, 0.5), pulse * 0.3)  # White → golden tint
		modulate = Color(pulse_color.r, pulse_color.g, pulse_color.b, modulate.a)

func update_gold_bonus(delta):
	"""Update gold bonus based on remaining break time"""
	if break_time_remaining > 0:
		break_time_remaining -= delta
		break_time_remaining = max(0, break_time_remaining)

	# Calculate current bonus (decays over time)
	var time_ratio = break_time_remaining / break_time_total if break_time_total > 0 else 0.0
	current_gold_bonus = int(base_gold_bonus * time_ratio)
	current_gold_bonus = max(1, current_gold_bonus)  # Minimum 1 gold

	# Update button text if showing bonus
	if show_gold_bonus:
		update_button_text()

func update_button_text():
	"""Update button text to show current gold bonus"""
	if show_gold_bonus:
		text = "+%dg" % current_gold_bonus
	else:
		text = "CALL WAVE"

# ============================================
# PUBLIC API
# ============================================

func setup(world_pos: Vector2, total_break_time: float, gold_bonus: int = 5):
	"""Initialize button with spawn position and timing info"""
	spawn_world_position = world_pos
	break_time_total = total_break_time
	break_time_remaining = total_break_time
	base_gold_bonus = gold_bonus
	current_gold_bonus = gold_bonus
	update_button_text()

func get_current_bonus() -> int:
	"""Get current gold bonus amount"""
	return current_gold_bonus

# ============================================
# BUTTON CALLBACK
# ============================================

func _on_button_pressed():
	"""Handle button click - call next wave early"""
	# Play click animation
	play_click_animation()

	# Emit signal (WaveManager will handle starting wave and awarding gold)
	wave_called.emit()

	# Wait for animation to finish, then remove button
	await get_tree().create_timer(0.25).timeout
	queue_free()
