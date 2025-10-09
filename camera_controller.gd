extends Camera2D

# ============================================
# CAMERA CONTROLLER - Commercial-quality camera for tower defense
# ============================================

# ZOOM SETTINGS
@export var min_zoom = 0.3  # Max zoom out (smaller = further)
@export var max_zoom = 1.5  # Max zoom in (larger = closer)
@export var zoom_speed = 0.1  # How much to zoom per scroll
@export var zoom_smoothing = 0.15  # Lerp factor for smooth zoom

# PAN SETTINGS
@export var keyboard_pan_speed = 500.0  # Pixels per second
@export var edge_scroll_margin = 50  # Pixels from edge to trigger scroll
@export var edge_scroll_speed = 400.0  # Pixels per second
@export var drag_speed = 1.0  # Multiplier for drag sensitivity

# INERTIA SETTINGS (for touch drag)
@export var inertia_enabled = true
@export var inertia_friction = 0.9  # How quickly inertia decays (0-1)
@export var min_inertia_velocity = 10.0  # Stop if below this

# CAMERA BOUNDS
@export var use_bounds = true
@export var level_rect = Rect2(0, 0, 2000, 1200)  # Adjust to your level size

# DRAG THRESHOLD
@export var drag_threshold = 5.0  # Pixels before drag starts

# INPUT STATE
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var last_mouse_pos = Vector2.ZERO
var touch_points = {}  # For pinch-to-zoom

# INERTIA STATE
var velocity = Vector2.ZERO
var is_inertia_moving = false

# ZOOM STATE
var target_zoom = Vector2.ONE

# PINCH-TO-ZOOM STATE
var last_pinch_distance = 0.0
var pinch_center = Vector2.ZERO

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Set initial zoom
	target_zoom = zoom
	
	# Calculate bounds if using auto bounds
	if use_bounds:
		update_camera_limits()
	
	print("✓ Camera Controller initialized")
	print("  Zoom range: ", min_zoom, " to ", max_zoom)
	print("  Level bounds: ", level_rect)

func update_camera_limits():
	"""Set camera limits based on level size and viewport"""
	var viewport_size = get_viewport_rect().size
	
	# Calculate how far camera can move at minimum zoom
	var half_view_at_min_zoom = (viewport_size / min_zoom) / 2.0
	
	# Set limits
	limit_left = int(level_rect.position.x + half_view_at_min_zoom.x)
	limit_right = int(level_rect.end.x - half_view_at_min_zoom.x)
	limit_top = int(level_rect.position.y + half_view_at_min_zoom.y)
	limit_bottom = int(level_rect.end.y - half_view_at_min_zoom.y)
	
	# Ensure limits are valid
	if limit_left >= limit_right:
		limit_left = int(level_rect.position.x)
		limit_right = int(level_rect.end.x)
	if limit_top >= limit_bottom:
		limit_top = int(level_rect.position.y)
		limit_bottom = int(level_rect.end.y)

# ============================================
# INPUT HANDLING
# ============================================

func _unhandled_input(event):
	# MOUSE WHEEL ZOOM (PC)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at_point(event.position, zoom_speed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at_point(event.position, -zoom_speed)
			get_viewport().set_input_as_handled()
		
		# MIDDLE/RIGHT MOUSE DRAG (PC)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				start_drag(event.position)
			else:
				end_drag()
			get_viewport().set_input_as_handled()
	
	# MOUSE MOTION (for dragging)
	elif event is InputEventMouseMotion:
		if is_dragging:
			update_drag(event.position)
			get_viewport().set_input_as_handled()
	
	# TOUCH INPUT (Mobile)
	elif event is InputEventScreenTouch:
		handle_touch(event)
	
	elif event is InputEventScreenDrag:
		handle_touch_drag(event)

func handle_touch(event: InputEventScreenTouch):
	"""Handle touch press/release"""
	if event.pressed:
		touch_points[event.index] = event.position
		
		# Single finger - start drag
		if touch_points.size() == 1:
			start_drag(event.position)
		
		# Two fingers - start pinch zoom
		elif touch_points.size() == 2:
			is_dragging = false  # Stop drag if second finger added
			var points = touch_points.values()
			last_pinch_distance = points[0].distance_to(points[1])
			pinch_center = (points[0] + points[1]) / 2.0
	else:
		touch_points.erase(event.index)
		
		# If no more touches, end drag
		if touch_points.is_empty():
			end_drag()
		# If went from 2 fingers to 1, restart drag
		elif touch_points.size() == 1:
			start_drag(touch_points.values()[0])

func handle_touch_drag(event: InputEventScreenDrag):
	"""Handle touch drag motion"""
	touch_points[event.index] = event.position
	
	# Two finger pinch zoom
	if touch_points.size() == 2:
		var points = touch_points.values()
		var current_distance = points[0].distance_to(points[1])
		var distance_delta = current_distance - last_pinch_distance
		
		# Calculate zoom change
		var zoom_delta = distance_delta * 0.01
		var new_pinch_center = (points[0] + points[1]) / 2.0
		
		zoom_at_point(new_pinch_center, zoom_delta)
		
		last_pinch_distance = current_distance
		pinch_center = new_pinch_center
	
	# Single finger drag
	elif touch_points.size() == 1 and is_dragging:
		update_drag(event.position)

# ============================================
# DRAG FUNCTIONS
# ============================================

func start_drag(screen_pos: Vector2):
	"""Start dragging the camera"""
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
	
	# Scale by drag speed
	delta *= drag_speed
	
	# Move camera (opposite direction of drag)
	position -= delta
	
	# Store velocity for inertia
	velocity = -delta
	
	last_mouse_pos = screen_pos
	
	# Apply bounds
	apply_bounds()

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
	# Get world position under cursor before zoom
	var viewport_size = get_viewport_rect().size
	var cursor_offset = (screen_point - viewport_size / 2) / zoom
	var world_pos_before = position + cursor_offset
	
	# Calculate new zoom
	var new_zoom_value = target_zoom.x + zoom_delta
	new_zoom_value = clamp(new_zoom_value, min_zoom, max_zoom)
	target_zoom = Vector2(new_zoom_value, new_zoom_value)
	
	# Adjust position to keep world position under cursor
	var cursor_offset_after = (screen_point - viewport_size / 2) / target_zoom
	var world_pos_after = position + cursor_offset_after
	
	# Move camera to compensate
	position += world_pos_before - world_pos_after
	
	apply_bounds()

# ============================================
# PROCESS
# ============================================

func _process(delta):
	# Handle keyboard panning (PC)
	handle_keyboard_pan(delta)
	
	# Handle edge scrolling (PC)
	if OS.has_feature("pc"):
		handle_edge_scroll(delta)
	
	# Handle inertia
	if is_inertia_moving:
		update_inertia(delta)
	
	# Smooth zoom
	if zoom != target_zoom:
		zoom = zoom.lerp(target_zoom, zoom_smoothing)
		apply_bounds()  # Reapply bounds when zoom changes

func handle_keyboard_pan(delta):
	"""Pan camera with arrow keys or WASD"""
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
		position += direction * keyboard_pan_speed * delta / zoom.x
		apply_bounds()
		
		# Cancel inertia if manually moving
		is_inertia_moving = false
		velocity = Vector2.ZERO

func handle_edge_scroll(delta):
	"""Scroll camera when mouse near screen edge"""
	if is_dragging:
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
		position += direction * edge_scroll_speed * delta / zoom.x
		apply_bounds()

func update_inertia(delta):
	"""Update inertia-based movement"""
	if velocity.length() < min_inertia_velocity:
		is_inertia_moving = false
		velocity = Vector2.ZERO
		return
	
	# Apply velocity
	position += velocity
	
	# Apply friction
	velocity *= inertia_friction
	
	apply_bounds()

# ============================================
# BOUNDS
# ============================================

func apply_bounds():
	"""Clamp camera position to stay within level bounds"""
	if not use_bounds:
		return
	
	var viewport_size = get_viewport_rect().size
	var half_view = (viewport_size / zoom) / 2.0
	
	# Calculate allowed range
	var min_x = level_rect.position.x + half_view.x
	var max_x = level_rect.end.x - half_view.x
	var min_y = level_rect.position.y + half_view.y
	var max_y = level_rect.end.y - half_view.y
	
	# Clamp position
	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)
	
	# Stop inertia if hitting bounds
	if position.x <= min_x or position.x >= max_x:
		velocity.x = 0
	if position.y <= min_y or position.y >= max_y:
		velocity.y = 0

# ============================================
# UTILITY FUNCTIONS
# ============================================

func reset_to_center():
	"""Reset camera to level center"""
	position = level_rect.get_center()
	target_zoom = Vector2(0.5, 0.5)
	velocity = Vector2.ZERO
	is_inertia_moving = false

func set_level_bounds(rect: Rect2):
	"""Update level bounds at runtime"""
	level_rect = rect
	update_camera_limits()
	apply_bounds()
