extends Camera2D

# ============================================
# ENHANCED CAMERA CONTROLLER - Multi-platform commercial release
# ============================================
# Features:
# - Platform-specific defaults (mobile vs PC)
# - User preference system
# - Double-tap zoom (mobile)
# - Camera shake
# - Snap-to-target
# - Accessibility options
# - Performance optimizations

# ============================================
# PLATFORM DETECTION
# ============================================
enum Platform { MOBILE, PC, CONSOLE }
var current_platform: Platform

# ============================================
# ZOOM SETTINGS - LOCKED (Zoom disabled for now)
# ============================================
@export_group("Zoom Settings")
@export var min_zoom = 1.0  # LOCKED - Zoom disabled
@export var max_zoom = 1.0  # LOCKED - Zoom disabled
@export var default_zoom = 1.0  # LOCKED - Start closer (was 0.6 - too far!)
@export var zoom_speed = 0.0  # DISABLED
@export var zoom_smoothing = 0.0  # DISABLED

# Mobile-specific zoom - LOCKED
@export var mobile_min_zoom = 1.0  # LOCKED
@export var mobile_max_zoom = 1.0  # LOCKED
@export var mobile_zoom_speed = 0.0  # DISABLED

# Double-tap zoom (mobile) - DISABLED
@export var double_tap_zoom_in = 1.0  # DISABLED
@export var double_tap_zoom_out = 1.0  # DISABLED
@export var double_tap_time_threshold = 0.3  # DISABLED

# ============================================
# PAN SETTINGS
# ============================================
@export_group("Pan Settings")
# PC
@export var keyboard_pan_speed = 500.0
@export var pc_drag_speed = 1.0
@export var pc_drag_threshold = 5.0

# Mobile
@export var mobile_drag_speed = 1.2  # Slightly faster for touch
@export var mobile_drag_threshold = 8.0  # Higher to avoid accidental drags

# Edge scrolling (PC only)
@export var edge_scroll_enabled = true  # Can disable in settings
@export var edge_scroll_margin = 50
@export var edge_scroll_speed = 400.0

# ============================================
# INERTIA SETTINGS
# ============================================
@export_group("Inertia")
@export var inertia_enabled = true
@export var pc_inertia_friction = 0.92
@export var mobile_inertia_friction = 0.88  # More friction on mobile
@export var min_inertia_velocity = 10.0
@export var max_inertia_velocity = 2000.0  # Cap for fast swipes

# ============================================
# BOUNDS - AUTOMATED SYSTEM
# ============================================
# Camera limits are automatically calculated from level_rect
# The pink/magenta rectangle in editor shows where camera CENTER can move
#
# Simply set level_rect below and limits auto-calculate at runtime
# Accounts for viewport size and zoom level
@export_group("Level Bounds")
@export var level_rect = Rect2(-200, 200, 2000, 800)  # Define your playable area here

# ============================================
# CAMERA SHAKE
# ============================================
@export_group("Camera Shake")
@export var shake_enabled = false
var shake_intensity = 0.0
var shake_decay = 5.0  # How fast shake fades
var shake_offset = Vector2.ZERO

# ============================================
# SNAP-TO FEATURE
# ============================================
@export_group("Snap To Target")
@export var snap_duration = 0.5  # Time to move to target
@export var snap_zoom_duration = 0.3
var is_snapping = false
var snap_target_pos = Vector2.ZERO
var snap_start_pos = Vector2.ZERO
var snap_progress = 0.0

# ============================================
# STATE
# ============================================
# Input state
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var last_mouse_pos = Vector2.ZERO
var drag_threshold = 5.0
var drag_speed = 1.0

# Touch state
var touch_points = {}
var last_pinch_distance = 0.0
var pinch_center = Vector2.ZERO

# Double-tap detection (mobile)
var last_tap_time = 0.0
var last_tap_position = Vector2.ZERO
var is_double_tap_zoomed = false

# Inertia state
var velocity = Vector2.ZERO
var is_inertia_moving = false
var inertia_friction = 0.9

# Zoom state
var target_zoom = Vector2.ONE
var base_position = Vector2.ZERO  # Position without shake

# ============================================
# USER PREFERENCES (will be saved/loaded)
# ============================================
var user_prefs = {
	"edge_scroll_enabled": true,
	"inertia_enabled": true,
	"shake_enabled": false,
	"keyboard_pan_enabled": true,
	"edge_scroll_speed_multiplier": 1.0,  # 0.5 to 2.0
	"zoom_speed_multiplier": 1.0,  # 0.5 to 2.0
	"drag_sensitivity": 1.0,  # 0.5 to 2.0
}

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Skip runtime initialization in editor
	if Engine.is_editor_hint():
		return

	# Runtime-only initialization
	detect_platform()
	apply_platform_defaults()
	load_user_preferences()

	# Set initial zoom (LOCKED at 1.0)
	target_zoom = Vector2(default_zoom, default_zoom)
	zoom = target_zoom
	base_position = position

	# Auto-calculate camera bounds from level_rect
	update_camera_limits()

	print("[Camera] Initialized - Zoom:", zoom, " Bounds:", Vector4i(limit_left, limit_top, limit_right, limit_bottom))

func detect_platform() -> void:
	"""Auto-detect platform for appropriate defaults"""
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		current_platform = Platform.MOBILE
	elif OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		current_platform = Platform.PC
	else:
		current_platform = Platform.CONSOLE

func apply_platform_defaults() -> void:
	"""Set platform-appropriate defaults"""
	match current_platform:
		Platform.MOBILE:
			# Mobile: More restrictive zoom, no edge scroll, higher thresholds
			min_zoom = mobile_min_zoom
			max_zoom = mobile_max_zoom
			zoom_speed = mobile_zoom_speed
			drag_speed = mobile_drag_speed
			drag_threshold = mobile_drag_threshold
			inertia_friction = mobile_inertia_friction
			edge_scroll_enabled = false

		Platform.PC:
			# PC: Full features
			drag_speed = pc_drag_speed
			drag_threshold = pc_drag_threshold
			inertia_friction = pc_inertia_friction
			edge_scroll_enabled = true

		Platform.CONSOLE:
			# Console: Similar to PC but no keyboard pan
			drag_speed = pc_drag_speed
			drag_threshold = pc_drag_threshold
			edge_scroll_enabled = false

func load_user_preferences() -> void:
	"""Load saved user preferences"""
	# TODO: Load from save file
	# For now, use defaults
	edge_scroll_enabled = user_prefs["edge_scroll_enabled"]
	inertia_enabled = user_prefs["inertia_enabled"]
	shake_enabled = user_prefs["shake_enabled"]

func save_user_preferences() -> void:
	"""Save user preferences to file"""
	# TODO: Implement save system
	pass

# ============================================
# SETTINGS API (called from settings menu)
# ============================================

func set_edge_scroll_enabled(enabled: bool) -> void:
	user_prefs["edge_scroll_enabled"] = enabled
	edge_scroll_enabled = enabled
	save_user_preferences()

func set_inertia_enabled(enabled: bool) -> void:
	user_prefs["inertia_enabled"] = enabled
	inertia_enabled = enabled
	save_user_preferences()

func set_shake_enabled(enabled: bool) -> void:
	user_prefs["shake_enabled"] = enabled
	shake_enabled = enabled
	save_user_preferences()

func set_edge_scroll_speed_multiplier(multiplier: float) -> void:
	user_prefs["edge_scroll_speed_multiplier"] = clamp(multiplier, 0.5, 2.0)
	save_user_preferences()

func set_zoom_speed_multiplier(multiplier: float) -> void:
	user_prefs["zoom_speed_multiplier"] = clamp(multiplier, 0.5, 2.0)
	save_user_preferences()

func set_drag_sensitivity(sensitivity: float) -> void:
	user_prefs["drag_sensitivity"] = clamp(sensitivity, 0.5, 2.0)
	save_user_preferences()

# ============================================
# INPUT HANDLING
# ============================================

func _unhandled_input(event):
	# Skip input handling in editor
	if Engine.is_editor_hint():
		return

	match current_platform:
		Platform.MOBILE:
			handle_mobile_input(event)
		Platform.PC:
			handle_pc_input(event)
		Platform.CONSOLE:
			handle_console_input(event)

func handle_pc_input(event) -> void:
	"""PC-specific input (mouse + keyboard)"""
	if event is InputEventMouseButton:
		# Don't interact with camera when mouse is over GUI
		var gui_element = get_viewport().gui_get_hovered_control()
		if gui_element:
			return  # Let GUI handle the input

		# ZOOM DISABLED - Mouse wheel does nothing
		# if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		# 	var adjusted_speed = zoom_speed * user_prefs["zoom_speed_multiplier"]
		# 	zoom_at_point(event.position, adjusted_speed)
		# 	get_viewport().set_input_as_handled()
		#
		# elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		# 	var adjusted_speed = zoom_speed * user_prefs["zoom_speed_multiplier"]
		# 	zoom_at_point(event.position, -adjusted_speed)
		# 	get_viewport().set_input_as_handled()

		# Middle/Right mouse drag - KEEP WORKING
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				start_drag(event.position)
			else:
				end_drag()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if is_dragging:
			update_drag(event.position)
			get_viewport().set_input_as_handled()

func handle_mobile_input(event) -> void:
	"""Mobile-specific input (touch)"""
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_touch_drag(event)

func handle_console_input(event) -> void:
	"""Console-specific input (gamepad)"""
	# TODO: Add gamepad camera control
	handle_pc_input(event)  # For now, fallback to PC

# ============================================
# TOUCH HANDLING (MOBILE)
# ============================================

func handle_touch(event: InputEventScreenTouch):
	"""Touch handling - ZOOM DISABLED, only drag works"""
	if event.pressed:
		# DOUBLE-TAP ZOOM DISABLED
		# (Code removed - zoom locked at 1.0)

		# Register touch point
		touch_points[event.index] = event.position

		# Single finger - start drag (KEEP WORKING)
		if touch_points.size() == 1:
			start_drag(event.position)

		# Two fingers - PINCH ZOOM DISABLED, just end drag
		elif touch_points.size() == 2:
			is_dragging = false
			# Pinch zoom disabled - two finger touch does nothing

	else:
		touch_points.erase(event.index)

		if touch_points.is_empty():
			end_drag()
		elif touch_points.size() == 1:
			start_drag(touch_points.values()[0])

func handle_touch_drag(event: InputEventScreenDrag):
	"""Handle touch drag motion - PINCH ZOOM DISABLED"""
	touch_points[event.index] = event.position

	# PINCH ZOOM DISABLED
	# Two finger pinch does nothing (zoom locked at 1.0)

	# Single finger drag (KEEP WORKING)
	if touch_points.size() == 1 and is_dragging:
		update_drag(event.position)

# ============================================
# DRAG FUNCTIONS
# ============================================

func start_drag(screen_pos: Vector2):
	"""Start dragging the camera"""
	if is_snapping:
		cancel_snap()

	drag_start_pos = screen_pos
	last_mouse_pos = screen_pos
	is_dragging = false  # Wait for threshold
	is_inertia_moving = false
	velocity = Vector2.ZERO

func update_drag(screen_pos: Vector2):
	"""Update camera position while dragging"""
	# Check if we've moved enough to start drag
	if not is_dragging:
		if drag_start_pos.distance_to(screen_pos) > drag_threshold:
			is_dragging = true
		else:
			return

	# Calculate movement
	var delta = (screen_pos - last_mouse_pos) / zoom

	# Apply sensitivity
	delta *= drag_speed * user_prefs["drag_sensitivity"]

	# Move camera (opposite direction of drag)
	base_position -= delta

	# Store velocity for inertia (frame-independent)
	velocity = -delta / get_process_delta_time()
	velocity = velocity.limit_length(max_inertia_velocity)

	last_mouse_pos = screen_pos

func end_drag():
	"""End dragging and start inertia if enabled"""
	if is_dragging and inertia_enabled and velocity.length() > min_inertia_velocity:
		is_inertia_moving = true
	else:
		is_inertia_moving = false
		velocity = Vector2.ZERO

	is_dragging = false

# ============================================
# ZOOM FUNCTIONS
# ============================================

func zoom_at_point(screen_point: Vector2, zoom_delta: float):
	"""Zoom toward a specific screen point"""
	if is_snapping:
		cancel_snap()

	# Get world position under cursor before zoom
	var viewport_size = get_viewport_rect().size
	var cursor_offset = (screen_point - viewport_size / 2) / zoom
	var world_pos_before = base_position + cursor_offset

	# Calculate new zoom
	var new_zoom_value = target_zoom.x + zoom_delta
	new_zoom_value = clamp(new_zoom_value, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_value, new_zoom_value)

	# Adjust position to keep world position under cursor
	var cursor_offset_after = (screen_point - viewport_size / 2) / target_zoom
	var world_pos_after = base_position + cursor_offset_after

	# Move camera to compensate
	base_position += world_pos_before - world_pos_after

func set_zoom_instant(new_zoom: float) -> void:
	"""Set zoom without smoothing"""
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom, new_zoom)
	zoom = target_zoom

# ============================================
# CAMERA SHAKE
# ============================================

func add_shake(intensity: float) -> void:
	"""Add camera shake (for explosions, damage, etc.)"""
	if shake_enabled:
		shake_intensity = max(shake_intensity, intensity)

func update_shake(delta: float) -> void:
	"""Update camera shake"""
	if shake_intensity > 0.1:
		# Random offset based on intensity
		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

		# Decay shake over time
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		shake_intensity = 0.0
		shake_offset = Vector2.ZERO

# ============================================
# SNAP-TO FEATURE
# ============================================

func snap_to_position(world_pos: Vector2, zoom_to: float = -1.0, duration: float = -1.0) -> void:
	"""Smoothly move camera to a position"""
	is_snapping = true
	snap_start_pos = base_position
	snap_target_pos = world_pos
	snap_progress = 0.0

	if duration > 0:
		snap_duration = duration

	if zoom_to > 0:
		target_zoom = Vector2(zoom_to, zoom_to)

func snap_to_object(object: Node2D, zoom_to: float = -1.0) -> void:
	"""Snap camera to follow an object"""
	if is_instance_valid(object):
		snap_to_position(object.global_position, zoom_to)

func cancel_snap() -> void:
	"""Cancel current snap animation"""
	is_snapping = false
	snap_progress = 0.0

func update_snap(delta: float) -> void:
	"""Update snap-to animation"""
	if not is_snapping:
		return

	snap_progress += delta / snap_duration

	if snap_progress >= 1.0:
		base_position = snap_target_pos
		is_snapping = false
		snap_progress = 0.0
	else:
		# Smooth ease-out curve
		var t = ease_out_cubic(snap_progress)
		base_position = snap_start_pos.lerp(snap_target_pos, t)

func ease_out_cubic(t: float) -> float:
	"""Smooth easing function"""
	return 1.0 - pow(1.0 - t, 3.0)

# ============================================
# PROCESS
# ============================================

func _process(delta):
	# Skip runtime logic in editor
	if Engine.is_editor_hint():
		return

	# Handle snap animation
	if is_snapping:
		update_snap(delta)

	# Handle keyboard panning (PC only)
	if current_platform == Platform.PC and user_prefs.get("keyboard_pan_enabled", true):
		handle_keyboard_pan(delta)

	# Handle edge scrolling (PC only)
	if current_platform == Platform.PC and edge_scroll_enabled:
		handle_edge_scroll(delta)

	# Handle inertia
	if is_inertia_moving and not is_snapping:
		update_inertia(delta)

	# Update camera shake
	if shake_enabled:
		update_shake(delta)

	# Zoom smoothing DISABLED (zoom locked at 1.0)
	# zoom = target_zoom (always 1.0, no smoothing needed)

	# Apply final position with shake
	position = base_position + shake_offset

func handle_keyboard_pan(delta):
	"""Pan camera with arrow keys or WASD"""
	if is_snapping:
		return

	var direction = Vector2.ZERO

	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		base_position += direction * keyboard_pan_speed * delta / zoom.x

		# Cancel inertia if manually moving
		is_inertia_moving = false
		velocity = Vector2.ZERO

func handle_edge_scroll(delta):
	"""Scroll camera when mouse near screen edge"""
	if is_dragging or is_snapping:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	var direction = Vector2.ZERO

	# Check each edge
	if mouse_pos.x < edge_scroll_margin:
		direction.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		direction.x += 1

	if mouse_pos.y < edge_scroll_margin:
		direction.y -= 1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		direction.y += 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		var speed = edge_scroll_speed * user_prefs["edge_scroll_speed_multiplier"]
		base_position += direction * speed * delta / zoom.x

func update_inertia(delta):
	"""Update inertia-based movement (frame-independent)"""
	if velocity.length() < min_inertia_velocity:
		is_inertia_moving = false
		velocity = Vector2.ZERO
		return

	# Apply velocity (frame-independent)
	base_position += velocity * delta

	# Apply friction (frame-independent)
	var friction = pow(inertia_friction, delta * 60.0)  # Normalized to 60fps
	velocity *= friction

# ============================================
# BORDER AUTOMATION FUNCTIONS
# ============================================

func update_camera_limits() -> void:
	"""Automatically calculate camera limits from level_rect"""
	var viewport_size = get_viewport_rect().size

	# Calculate visible area at current zoom
	var half_view = (viewport_size / zoom) / 2.0

	# Set Godot's built-in limit properties (renders as magenta rectangle in editor)
	limit_left = int(level_rect.position.x + half_view.x)
	limit_right = int(level_rect.end.x - half_view.x)
	limit_top = int(level_rect.position.y + half_view.y)
	limit_bottom = int(level_rect.end.y - half_view.y)

	# Ensure limits are valid
	if limit_left >= limit_right:
		limit_left = int(level_rect.position.x)
		limit_right = int(level_rect.end.x)
	if limit_top >= limit_bottom:
		limit_top = int(level_rect.position.y)
		limit_bottom = int(level_rect.end.y)

func set_level_bounds(rect: Rect2) -> void:
	"""Update level bounds at runtime (can be called from level_controller)"""
	level_rect = rect
	update_camera_limits()
	print("[Camera] Bounds updated to:", rect)

# ============================================
# UTILITY FUNCTIONS
# ============================================

func reset_to_center():
	"""Reset camera to center of camera limits"""
	cancel_snap()
	# Calculate center from limit properties
	var center_x = (limit_left + limit_right) / 2.0
	var center_y = (limit_top + limit_bottom) / 2.0
	base_position = Vector2(center_x, center_y)
	position = base_position
	target_zoom = Vector2(default_zoom, default_zoom)
	zoom = target_zoom
	velocity = Vector2.ZERO
	is_inertia_moving = false
	shake_intensity = 0.0
	shake_offset = Vector2.ZERO

func get_camera_state() -> Dictionary:
	"""Get current camera state (for save/load)"""
	return {
		"position": base_position,
		"zoom": zoom.x,
		"preferences": user_prefs.duplicate()
	}

func set_camera_state(state: Dictionary) -> void:
	"""Restore camera state (for save/load)"""
	if state.has("position"):
		base_position = state["position"]
		position = base_position
	if state.has("zoom"):
		var z = state["zoom"]
		zoom = Vector2(z, z)
		target_zoom = zoom
	if state.has("preferences"):
		user_prefs = state["preferences"].duplicate()
		load_user_preferences()
