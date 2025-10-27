@tool
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
# DESIGN RESOLUTION & BASELINE
# ============================================
# Reference resolution for consistent framing across devices
const DESIGN_WIDTH = 1920.0
const DESIGN_HEIGHT = 1080.0

# Computed at runtime based on actual viewport
var baseline_zoom = 1.0

# ============================================
# PLATFORM DETECTION
# ============================================
enum Platform { MOBILE, PC, CONSOLE }
var current_platform: Platform

# ============================================
# DEBUG SETTINGS
# ============================================
@export_group("Debug")
@export var debug_input = false  # Print all input events
@export var debug_drag_only = true  # Only debug drag events (not every mouse motion)

# Editor visualization
@export var show_level_borders_in_editor = true  # Show yellow border rectangle in editor
@export var editor_border_color = Color.YELLOW  # Border color (change in Inspector)
@export var editor_border_width = 4.0  # Border line width in pixels

# ============================================
# ZOOM SETTINGS - Slight zoom enabled for detail viewing
# ============================================
@export_group("Zoom Settings")
@export var min_zoom = 1.0  # Baseline (furthest out)
@export var max_zoom = 1.0  # Will be set to 1.25 by platform defaults (25% closer)
@export var default_zoom = 1.0  # Start at baseline
@export var zoom_speed = 0.1  # Smooth zoom speed
@export var zoom_smoothing = 0.15  # Smooth interpolation

# Mobile-specific zoom
@export var mobile_min_zoom = 1.0  # Baseline
@export var mobile_max_zoom = 1.0  # Will be set to 1.2 (20% closer for mobile)
@export var mobile_zoom_speed = 0.08  # Slightly slower for mobile

# Double-tap zoom (mobile) - Keep disabled for now
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
@export var edge_scroll_enabled = false  # Disabled - use right-click drag instead
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
# BOUNDS - MANAGED BY LEVEL CONTROLLER
# ============================================
# Camera limits are automatically calculated from level_rect
# The pink/magenta rectangle in editor shows where camera CENTER can move
#
# IMPORTANT: Level bounds MUST be set by LevelController via set_level_bounds()
# This camera does NOT have a default fallback - bounds come from LevelConfig
@export_group("Level Bounds (Read-Only)")
var level_rect: Rect2 = Rect2()  # Set by LevelController - do not edit directly

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
# Input lock (for menus)
var input_locked = false

# Input state
var is_dragging = false
var drag_button_pressed = false  # Track if drag button is held (separate from threshold)
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
	"edge_scroll_enabled": false,
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
	# STARTUP DEBUG - Verify camera script loads
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🎥 [CAMERA] _ready() called!")
	print("   debug_input: ", debug_input)
	print("   Node path: ", get_path())
	print("   Is editor: ", Engine.is_editor_hint())
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# Skip runtime initialization in editor
	if Engine.is_editor_hint():
		return

	# WEB PLATFORM FIX: Defer initialization on web to allow canvas setup
	if OS.has_feature("web") or OS.get_name() == "Web":
		# Wait 2 frames for canvas to be fully initialized
		await get_tree().process_frame
		await get_tree().process_frame

	# Runtime-only initialization
	calculate_baseline_zoom()
	detect_platform()
	apply_platform_defaults()
	load_user_preferences()

	# Set initial zoom based on baseline (LOCKED at baseline for now)
	target_zoom = Vector2(baseline_zoom, baseline_zoom)
	zoom = target_zoom
	base_position = position

	# Validate that bounds have been set by LevelController
	if level_rect.size == Vector2.ZERO:
		push_warning("[Camera] ⚠️ WARNING: Level bounds not set! Camera requires LevelController to call set_level_bounds()")
		push_warning("[Camera] → Add a LevelController script to your level scene")
		push_warning("[Camera] → Assign a LevelConfig resource to the LevelController")
		push_warning("[Camera] → Camera will continue with zero bounds (may not work correctly)")

	# Auto-calculate camera bounds from level_rect
	update_camera_limits()

	# Connect to viewport resize for dynamic adjustment
	get_viewport().size_changed.connect(_on_viewport_resized)

	print("[Camera] Initialized - Baseline zoom:", baseline_zoom, " Zoom:", zoom, " Bounds:", Vector4i(limit_left, limit_top, limit_right, limit_bottom))
	if level_rect.size != Vector2.ZERO:
		print("[Camera] Level rect:", level_rect)

func calculate_baseline_zoom() -> void:
	"""Calculate baseline zoom from viewport to maintain consistent framing across devices"""
	var viewport_size = get_viewport_rect().size

	# VALIDATION: Prevent division by zero or invalid viewport (especially on web)
	if viewport_size.y <= 0 or viewport_size.x <= 0:
		push_warning("[Camera] Invalid viewport size: ", viewport_size, " - using default baseline")
		baseline_zoom = 1.0
		return

	# Use height as the primary dimension for zoom calculation
	# This keeps vertical framing consistent (same amount of world space visible vertically)
	baseline_zoom = viewport_size.y / DESIGN_HEIGHT

	# Clamp to reasonable values to prevent extreme zoom on unusual displays
	baseline_zoom = clamp(baseline_zoom, 0.5, 2.0)

	print("[Camera] Viewport:", viewport_size, " -> Baseline zoom:", baseline_zoom)

func detect_platform() -> void:
	"""Auto-detect platform for appropriate defaults"""
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		current_platform = Platform.MOBILE
	elif OS.has_feature("web") or OS.get_name() == "Web":
		current_platform = Platform.PC  # Treat web as PC (enable edge scroll, keyboard)
	elif OS.has_feature("pc") or OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		current_platform = Platform.PC
	else:
		current_platform = Platform.CONSOLE

func apply_platform_defaults() -> void:
	"""Set platform-appropriate defaults as ratios of baseline"""
	match current_platform:
		Platform.MOBILE:
			# Mobile: Slight zoom-in capability (20% closer for detail viewing)
			min_zoom = baseline_zoom  # Baseline is furthest out
			max_zoom = baseline_zoom * 1.2  # 20% closer to see details
			default_zoom = baseline_zoom  # Start at baseline
			zoom_speed = mobile_zoom_speed

			# Mobile-specific behavior
			drag_speed = mobile_drag_speed
			drag_threshold = mobile_drag_threshold
			inertia_friction = mobile_inertia_friction
			edge_scroll_enabled = false

		Platform.PC:
			# PC: Slight zoom-in capability (25% closer for detail viewing)
			min_zoom = baseline_zoom  # Baseline is furthest out
			max_zoom = baseline_zoom * 1.25  # 25% closer to see details
			default_zoom = baseline_zoom  # Start at baseline
			zoom_speed = zoom_speed  # Use default zoom_speed

			# PC-specific behavior
			drag_speed = pc_drag_speed
			drag_threshold = pc_drag_threshold
			inertia_friction = pc_inertia_friction
			edge_scroll_enabled = true

		Platform.CONSOLE:
			# Console: Similar to PC zoom range
			min_zoom = baseline_zoom
			max_zoom = baseline_zoom * 1.25
			default_zoom = baseline_zoom
			zoom_speed = zoom_speed

			drag_speed = pc_drag_speed
			drag_threshold = pc_drag_threshold
			edge_scroll_enabled = false

	print("[Camera] Platform:", ["MOBILE", "PC", "CONSOLE"][current_platform], " - Zoom range:", min_zoom, "to", max_zoom)

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
# INPUT LOCK API (for menus - Kingdom Rush style)
# ============================================

func lock_input() -> void:
	"""Lock camera input while menus are open"""
	input_locked = true
	# Cancel any ongoing movement
	is_dragging = false
	is_inertia_moving = false
	velocity = Vector2.ZERO
	print("[Camera] Input LOCKED (menu open)")

func unlock_input() -> void:
	"""Unlock camera input when menus close"""
	input_locked = false
	print("[Camera] Input UNLOCKED (menu closed)")

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	"""DEBUG ONLY - Verify input reaches camera node (runs BEFORE _unhandled_input)"""
	if debug_input:
		# Print for EVERY mouse event to ensure we see SOMETHING
		if event is InputEventMouseButton:
			print("🔵🔵🔵 [Camera _input()] MOUSE BUTTON EVENT RECEIVED!")
			print("  Button: ", event.button_index, " (",
				  "LEFT" if event.button_index == MOUSE_BUTTON_LEFT else
				  "RIGHT" if event.button_index == MOUSE_BUTTON_RIGHT else
				  "MIDDLE" if event.button_index == MOUSE_BUTTON_MIDDLE else "OTHER", ")")
			print("  Pressed: ", event.pressed)
			print("  Position: ", event.position)
			print("  ✅ This PROVES input is reaching the camera node!")
		elif event is InputEventMouseMotion:
			# Only print motion during drag to avoid spam
			if is_dragging:
				print("🟢 [Camera _input()] Mouse motion while dragging")

func _unhandled_input(event):
	# Skip in editor mode (camera script does NOT work in editor 2D view)
	if Engine.is_editor_hint():
		if debug_input and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			print("[Camera DEBUG] ⚠️ In EDITOR MODE - camera script does NOT handle input!")
			print("[Camera DEBUG]   Use Godot built-in editor camera: Middle-mouse drag to pan")
		return

	# DEBUG: Log all input events
	if debug_input:
		print("[Camera DEBUG] _unhandled_input called")
		print("  Event type: ", event.get_class())
		print("  input_locked: ", input_locked)
		if event is InputEventMouseButton:
			print("  Button: ", event.button_index, " Pressed: ", event.pressed, " Position: ", event.position)

	# Skip if input is locked (menu open)
	if input_locked:
		if debug_input:
			print("[Camera DEBUG] Input locked - ignoring event")
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
		# Only block camera input when mouse is over INTERACTIVE GUI elements
		# (labels, containers, and other non-interactive elements should not block camera)
		var gui_element = get_viewport().gui_get_hovered_control()
		if debug_input:
			print("[Camera DEBUG] handle_pc_input - MouseButton")
			print("  GUI element hovered: ", gui_element)

		if gui_element:
			# Check if it's an interactive element that should block camera input
			var is_interactive = gui_element is Button or gui_element is TextureButton or gui_element is LineEdit or gui_element is TextEdit or gui_element is SpinBox or gui_element is Slider

			if debug_input:
				print("[Camera DEBUG] GUI element type: ", gui_element.get_class())
				print("  Is interactive: ", is_interactive)

			if is_interactive:
				if debug_input:
					print("[Camera DEBUG] Interactive GUI detected - ignoring camera input")
				return  # Let GUI handle the input
			else:
				if debug_input:
					print("[Camera DEBUG] Non-interactive GUI (Label/Container) - allowing camera input")

		# Mouse wheel zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				if debug_input:
					print("[Camera DEBUG] Mouse wheel UP - zooming in")
				var zoom_delta = zoom_speed * user_prefs["zoom_speed_multiplier"]
				zoom_at_point(event.position, zoom_delta)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				if debug_input:
					print("[Camera DEBUG] Mouse wheel DOWN - zooming out")
				var zoom_delta = -zoom_speed * user_prefs["zoom_speed_multiplier"]
				zoom_at_point(event.position, zoom_delta)
				get_viewport().set_input_as_handled()

		# Middle/Right mouse drag
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if debug_input:
				print("[Camera DEBUG] Right/Middle mouse - Button: ", event.button_index, " Pressed: ", event.pressed)
			if event.pressed:
				if debug_input:
					print("[Camera DEBUG] Starting drag at: ", event.position)
				start_drag(event.position)
			else:
				if debug_input:
					print("[Camera DEBUG] Ending drag")
				end_drag()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		# Only debug mouse motion if debug_drag_only is FALSE (reduces spam)
		if debug_input and not debug_drag_only and drag_button_pressed:
			print("[Camera DEBUG] Mouse motion while drag button pressed - Position: ", event.position)
		if drag_button_pressed:
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
	"""Touch handling for mobile - single finger drag"""
	if event.pressed:
		# Register touch point
		touch_points[event.index] = event.position

		# Single finger - start drag
		if touch_points.size() == 1:
			start_drag(event.position)
		# Two fingers - end drag (zoom disabled)
		elif touch_points.size() == 2:
			is_dragging = false

	else:
		touch_points.erase(event.index)

		if touch_points.is_empty():
			end_drag()
		elif touch_points.size() == 1:
			start_drag(touch_points.values()[0])

func handle_touch_drag(event: InputEventScreenDrag):
	"""Handle touch drag motion"""
	touch_points[event.index] = event.position

	# Single finger drag
	if touch_points.size() == 1 and is_dragging:
		update_drag(event.position)

# ============================================
# DRAG FUNCTIONS
# ============================================

func start_drag(screen_pos: Vector2):
	"""Start dragging the camera"""
	if debug_input:
		print("[Camera DRAG] 🎯 start_drag() called at position: ", screen_pos)
		print("[Camera DRAG]   input_locked: ", input_locked)
		print("[Camera DRAG]   is_snapping: ", is_snapping)

	if is_snapping:
		cancel_snap()

	drag_button_pressed = true  # Button is held - ready to check threshold
	drag_start_pos = screen_pos
	last_mouse_pos = screen_pos
	is_dragging = false  # Wait for threshold
	is_inertia_moving = false
	velocity = Vector2.ZERO

func update_drag(screen_pos: Vector2):
	"""Update camera position while dragging"""
	# Check if we've moved enough to start drag
	if not is_dragging:
		var distance = drag_start_pos.distance_to(screen_pos)
		if distance > drag_threshold:
			is_dragging = true
			if debug_input:
				print("[Camera DRAG] ✅ Drag threshold exceeded! distance=", distance, " threshold=", drag_threshold)
				print("[Camera DRAG]   NOW DRAGGING - camera will move")
		else:
			if debug_input and debug_drag_only:
				print("[Camera DRAG] ⏳ Waiting for threshold... distance=", distance, " / ", drag_threshold)
			return

	# Calculate movement
	var delta = (screen_pos - last_mouse_pos) / zoom

	# Apply sensitivity
	delta *= drag_speed * user_prefs["drag_sensitivity"]

	# Move camera (opposite direction of drag)
	base_position -= delta

	# Store velocity for inertia (frame-independent)
	velocity = -delta / get_physics_process_delta_time()
	velocity = velocity.limit_length(max_inertia_velocity)

	last_mouse_pos = screen_pos

func end_drag():
	"""End dragging and start inertia if enabled"""
	if is_dragging and inertia_enabled and velocity.length() > min_inertia_velocity:
		is_inertia_moving = true
	else:
		is_inertia_moving = false
		velocity = Vector2.ZERO

	drag_button_pressed = false  # Button released
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

func _physics_process(delta):
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

	# Smooth zoom interpolation
	if zoom != target_zoom:
		zoom = zoom.lerp(target_zoom, zoom_smoothing)
		# Snap to target if very close
		if abs(zoom.x - target_zoom.x) < 0.001:
			zoom = target_zoom

	# Update camera shake
	if shake_enabled:
		update_shake(delta)

	# Apply final position with shake
	position = base_position + shake_offset

	# Manually clamp camera position to stay within level boundaries
	# (Godot's built-in limits are disabled to prevent interference with custom logic)
	var viewport_size = get_viewport_rect().size
	var half_view = (viewport_size / zoom) / 2.0

	# Calculate actual boundaries accounting for viewport size
	var min_x = level_rect.position.x + half_view.x
	var max_x = level_rect.end.x - half_view.x
	var min_y = level_rect.position.y + half_view.y
	var max_y = level_rect.end.y - half_view.y

	# Clamp position to boundaries
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)

	# Update base_position to match (so drag state stays consistent)
	base_position = position - shake_offset

func handle_keyboard_pan(delta):
	"""Pan camera with arrow keys or WASD (using InputMap actions)"""
	if is_snapping or input_locked:
		return

	var direction = Vector2.ZERO

	# Use InputMap actions for unified input handling
	if Input.is_action_pressed("camera_right"):
		direction.x += 1
	if Input.is_action_pressed("camera_left"):
		direction.x -= 1
	if Input.is_action_pressed("camera_down"):
		direction.y += 1
	if Input.is_action_pressed("camera_up"):
		direction.y -= 1

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		base_position += direction * keyboard_pan_speed * delta / zoom.x

		# Cancel inertia if manually moving
		is_inertia_moving = false
		velocity = Vector2.ZERO

func handle_edge_scroll(delta):
	"""Scroll camera when mouse near screen edge"""
	if is_dragging or is_snapping or input_locked:
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
	"""Disable Godot's automatic limit clamping - camera uses custom boundary logic"""
	var viewport_size = get_viewport_rect().size

	# Calculate visible area at current zoom (for reference/debugging)
	var half_view = (viewport_size / zoom) / 2.0

	# DISABLE Godot's built-in limit clamping by setting to very large values
	# This allows the camera's custom movement logic to work without interference
	# The camera script will handle boundary constraints manually in _physics_process()
	limit_left = -100000
	limit_right = 100000
	limit_top = -100000
	limit_bottom = 100000

	# DEBUG: Print camera configuration
	print("[Camera] 📐 LIMITS DISABLED (Using custom boundary logic):")
	print("  Viewport size: ", viewport_size)
	print("  Zoom: ", zoom)
	print("  Half view: ", half_view)
	print("  Level rect: ", level_rect)
	print("  Godot limits: INFINITE (", limit_left, " to ", limit_right, ")")
	print("  Custom boundaries will constrain movement to level_rect")
	print("  Current camera position: ", position)

func set_level_bounds(rect: Rect2) -> void:
	"""Update level bounds at runtime (can be called from level_controller)"""
	level_rect = rect
	update_camera_limits()
	print("[Camera] Bounds updated to:", rect)

func _on_viewport_resized() -> void:
	"""Handle viewport resize (window resize, device rotation, etc.)"""
	print("[Camera] Viewport resized - recalculating baseline and limits")

	# Recalculate baseline zoom for new viewport size
	calculate_baseline_zoom()

	# Reapply platform defaults with new baseline
	apply_platform_defaults()

	# Update zoom to new baseline (keeping zoom disabled for now)
	target_zoom = Vector2(baseline_zoom, baseline_zoom)
	zoom = target_zoom

	# Recalculate camera limits for new viewport
	update_camera_limits()

	print("[Camera] Resize complete - New baseline:", baseline_zoom, " Zoom:", zoom)

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

# ============================================
# EDITOR VISUALIZATION
# ============================================

func _process(_delta):
	"""Update editor visualization (runs in editor only)"""
	if Engine.is_editor_hint() and show_level_borders_in_editor:
		queue_redraw()  # Request redraw every frame in editor

func _draw():
	"""Draw yellow border rectangle in editor to visualize playable area from LevelConfig"""
	# Only draw in editor mode
	if not Engine.is_editor_hint():
		return

	if not show_level_borders_in_editor:
		return

	# Try to find LevelController and get bounds from LevelConfig
	var bounds_to_draw: Rect2 = Rect2()

	# Find the level controller in the scene
	var level_controller = get_parent()
	if level_controller and "level_config" in level_controller:
		var level_config = level_controller.level_config
		if level_config and level_config.camera_bounds:
			bounds_to_draw = level_config.camera_bounds

	# Fallback: If no LevelConfig found, try to use camera's level_rect
	if bounds_to_draw.size == Vector2.ZERO:
		bounds_to_draw = level_rect

	# If still no valid bounds, don't draw anything
	if bounds_to_draw.size == Vector2.ZERO:
		return

	# Draw yellow rectangle showing playable area bounds
	# Convert world coordinates to local coordinates for drawing
	var local_rect_pos = to_local(bounds_to_draw.position)
	var local_rect_end = to_local(bounds_to_draw.end)

	# Draw 4 lines forming the border rectangle
	var top_left = local_rect_pos
	var top_right = Vector2(local_rect_end.x, local_rect_pos.y)
	var bottom_right = local_rect_end
	var bottom_left = Vector2(local_rect_pos.x, local_rect_end.y)

	# Draw rectangle lines
	draw_line(top_left, top_right, editor_border_color, editor_border_width)  # Top
	draw_line(top_right, bottom_right, editor_border_color, editor_border_width)  # Right
	draw_line(bottom_right, bottom_left, editor_border_color, editor_border_width)  # Bottom
	draw_line(bottom_left, top_left, editor_border_color, editor_border_width)  # Left
