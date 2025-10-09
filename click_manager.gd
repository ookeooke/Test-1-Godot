extends Node

# ============================================
# CLICK MANAGER - Centralized clicking system for commercial games
# ============================================
# Benefits:
# - Single input handler (not 100 Area2D nodes checking input)
# - Query objects only when clicked (not every frame)
# - Clear priority system
# - Easily debuggable and testable
# - Scales to thousands of objects

signal object_clicked(object, click_position)
signal object_right_clicked(object, click_position)
signal object_hovered(object)
signal hover_ended(object)
signal empty_space_clicked(click_position)

# Click priorities (higher number = higher priority)
enum ClickPriority {
	UI = 100,           # UI always takes precedence
	HERO = 50,          # Heroes before everything else
	TOWER = 30,         # Towers
	ENEMY = 20,         # Enemies
	TERRAIN = 10,       # Ground/terrain markers
}

# Registered clickable objects organized by priority
var clickable_objects = {
	ClickPriority.UI: [],
	ClickPriority.HERO: [],
	ClickPriority.TOWER: [],
	ClickPriority.ENEMY: [],
	ClickPriority.TERRAIN: []
}

# Hover state
var currently_hovered = null
var hover_check_interval = 0.05  # Check hover every 50ms (20 times per second)
var hover_timer = 0.0

# Click configuration
var default_click_radius = 40.0  # Default detection radius in pixels
var double_click_time = 0.3  # Max time between clicks for double-click
var last_click_time = 0.0
var last_clicked_object = null

# Debug
var debug_mode = false

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("========================================")
	print("✓ CLICK MANAGER INITIALIZED")
	print("  This will handle ALL clicking in the game")
	print("========================================")
	
	# Set high process priority so we handle input first
	process_priority = -100

# ============================================
# REGISTRATION API
# ============================================

func register_clickable(object: Node2D, priority: ClickPriority, click_radius: float = -1.0) -> void:
	"""
	Register an object as clickable
	
	Args:
		object: The Node2D to make clickable
		priority: Click priority level
		click_radius: Custom click radius (uses default if -1)
	"""
	if not is_instance_valid(object):
		push_error("Tried to register invalid object")
		return
	
	if not clickable_objects.has(priority):
		push_error("Invalid click priority: ", priority)
		return
	
	# Check if already registered
	for data in clickable_objects[priority]:
		if data["object"] == object:
			print("⚠️ Object already registered: ", object.name)
			return
	
	var click_data = {
		"object": object,
		"priority": priority,
		"radius": click_radius if click_radius > 0 else default_click_radius,
		"enabled": true,
		"hover_enabled": true
	}
	
	clickable_objects[priority].append(click_data)
	
	if debug_mode:
		print("✓ Registered: ", object.name, " (priority: ", priority, ", radius: ", click_data["radius"], ")")

func unregister_clickable(object: Node2D) -> void:
	"""Remove an object from the click system"""
	for priority in clickable_objects:
		var initial_size = clickable_objects[priority].size()
		clickable_objects[priority] = clickable_objects[priority].filter(
			func(data): return data["object"] != object
		)
		
		if clickable_objects[priority].size() < initial_size:
			if debug_mode:
				print("✓ Unregistered: ", object.name)
			
			# Clear hover if this was the hovered object
			if currently_hovered == object:
				if is_instance_valid(currently_hovered) and currently_hovered.has_method("on_hover_end"):
					currently_hovered.on_hover_end()
				hover_ended.emit(currently_hovered)
				currently_hovered = null
			return

func set_clickable_enabled(object: Node2D, enabled: bool) -> void:
	"""Enable/disable clicking for a specific object"""
	for priority in clickable_objects:
		for data in clickable_objects[priority]:
			if data["object"] == object:
				data["enabled"] = enabled
				if debug_mode:
					print("Set clickable ", "enabled" if enabled else "disabled", " for ", object.name)
				return

func set_hover_enabled(object: Node2D, enabled: bool) -> void:
	"""Enable/disable hover detection for a specific object"""
	for priority in clickable_objects:
		for data in clickable_objects[priority]:
			if data["object"] == object:
				data["hover_enabled"] = enabled
				return

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	# Skip if camera is dragging
	var camera = get_viewport().get_camera_2d()
	if camera and "is_dragging" in camera and camera.is_dragging:
		return
	# skip world clicks if a menu is open
	if get_tree().root.has_node("BuildMenu") or get_tree().root.has_node("TowerInfoMenu"):
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(event.position, false)
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		handle_click(event.position, true)
		return

func _process(delta):
	
	
	# Efficient hover checking (not every frame)
	hover_timer += delta
	if hover_timer >= hover_check_interval:
		hover_timer = 0.0
		update_hover()

# ============================================
# CLICK DETECTION
# ============================================

func handle_click(screen_pos: Vector2, is_right_click: bool) -> void:
	"""Main click handler - finds and processes clicked objects"""
	
	# Check if UI has focus (don't process world clicks if typing, etc.)
	var focused_control = get_viewport().gui_get_focus_owner()
	if focused_control != null:
		if debug_mode:
			print("UI has focus, ignoring world click")
		return
	
	# Convert screen position to world position
	var click_world_pos = screen_to_world(screen_pos)
	
	if debug_mode:
		print("Click at screen: ", screen_pos, " -> world: ", click_world_pos)
	
	# Find clicked object by priority (highest first)
	var clicked_object = find_clicked_object(click_world_pos)
	
	if clicked_object:
		handle_object_clicked(clicked_object, click_world_pos, is_right_click)
	else:
		handle_empty_space_click(click_world_pos, is_right_click)
	
	# Mark event as handled
	get_viewport().set_input_as_handled()

func find_clicked_object(world_pos: Vector2) -> Node2D:
	"""Find the highest priority object at the click position"""
	
	# Sort priorities from highest to lowest
	var priorities_sorted = clickable_objects.keys()
	priorities_sorted.sort()
	priorities_sorted.reverse()
	
	# Check each priority level
	for priority in priorities_sorted:
		var closest = find_closest_object_in_list(world_pos, clickable_objects[priority])
		if closest:
			return closest
	
	return null

func find_closest_object_in_list(world_pos: Vector2, object_list: Array) -> Node2D:
	"""Find the closest enabled object within click radius"""
	var closest_object = null
	var closest_distance = INF
	
	for data in object_list:
		# Skip if disabled or invalid
		if not data["enabled"]:
			continue
		
		var obj = data["object"]
		if not is_instance_valid(obj):
			continue
		
		# Check distance
		var distance = obj.global_position.distance_to(world_pos)
		
		if distance <= data["radius"] and distance < closest_distance:
			closest_object = obj
			closest_distance = distance
	
	return closest_object

func handle_object_clicked(object: Node2D, world_pos: Vector2, is_right_click: bool) -> void:
	"""Process a successful click on an object"""
	
	if debug_mode:
		print("🎯 ", "Right-clicked: " if is_right_click else "Clicked: ", object.name)
	
	# Check for double-click (left clicks only)
	var is_double_click = false
	if not is_right_click:
		var current_time = Time.get_ticks_msec() / 1000.0
		if object == last_clicked_object and (current_time - last_click_time) < double_click_time:
			is_double_click = true
			if debug_mode:
				print("  ⚡ DOUBLE CLICK!")
		
		last_clicked_object = object
		last_click_time = current_time
	
	# Call object's click handler if it exists
	if is_right_click:
		if object.has_method("on_right_clicked"):
			object.on_right_clicked()
		object_right_clicked.emit(object, world_pos)
	else:
		if object.has_method("on_clicked"):
			object.on_clicked(is_double_click)
		object_clicked.emit(object, world_pos)

func handle_empty_space_click(world_pos: Vector2, is_right_click: bool) -> void:
	"""Handle clicks on empty space"""
	if debug_mode:
		print("Clicked empty space at: ", world_pos)
	
	empty_space_clicked.emit(world_pos)
	
	# Reset double-click tracking
	if not is_right_click:
		last_clicked_object = null

# ============================================
# HOVER DETECTION
# ============================================

func update_hover() -> void:
	"""Check what object is under the mouse cursor"""
	var mouse_screen_pos = get_viewport().get_mouse_position()
	var mouse_world_pos = screen_to_world(mouse_screen_pos)
	
	# Find highest priority hovered object
	var hovered_object = find_hovered_object(mouse_world_pos)
	
	# Handle hover state changes
	if hovered_object != currently_hovered:
		# End hover on old object
		if currently_hovered and is_instance_valid(currently_hovered):
			if currently_hovered.has_method("on_hover_end"):
				currently_hovered.on_hover_end()
			hover_ended.emit(currently_hovered)
		
		# Start hover on new object
		currently_hovered = hovered_object
		if currently_hovered:
			if currently_hovered.has_method("on_hover_start"):
				currently_hovered.on_hover_start()
			object_hovered.emit(currently_hovered)

func find_hovered_object(world_pos: Vector2) -> Node2D:
	"""Find the highest priority object at mouse position"""
	var priorities_sorted = clickable_objects.keys()
	priorities_sorted.sort()
	priorities_sorted.reverse()
	
	for priority in priorities_sorted:
		var hovered = find_closest_hovered_in_list(world_pos, clickable_objects[priority])
		if hovered:
			return hovered
	
	return null

func find_closest_hovered_in_list(world_pos: Vector2, object_list: Array) -> Node2D:
	"""Find closest object with hover enabled"""
	var closest_object = null
	var closest_distance = INF
	
	for data in object_list:
		if not data["enabled"] or not data["hover_enabled"]:
			continue
		
		var obj = data["object"]
		if not is_instance_valid(obj):
			continue
		
		var distance = obj.global_position.distance_to(world_pos)
		
		if distance <= data["radius"] and distance < closest_distance:
			closest_object = obj
			closest_distance = distance
	
	return closest_object

# ============================================
# UTILITY FUNCTIONS
# ============================================

func screen_to_world(screen_pos: Vector2) -> Vector2:
	"""Convert screen coordinates to world coordinates"""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		push_error("No Camera2D found in scene!")
		return screen_pos
	
	var camera_pos = camera.get_screen_center_position()
	var zoom = camera.zoom
	var viewport_size = get_viewport().get_visible_rect().size
	var offset = (screen_pos - viewport_size / 2) / zoom
	
	return camera_pos + offset

func get_objects_in_radius(center: Vector2, radius: float, priority: ClickPriority = -1) -> Array:
	"""Get all objects within a radius - useful for area selection"""
	var results = []
	
	var lists_to_check = []
	if priority == -1:
		# Check all priorities
		for p in clickable_objects:
			lists_to_check.append(clickable_objects[p])
	else:
		lists_to_check.append(clickable_objects[priority])
	
	for object_list in lists_to_check:
		for data in object_list:
			if not data["enabled"]:
				continue
			var obj = data["object"]
			if is_instance_valid(obj):
				var distance = obj.global_position.distance_to(center)
				if distance <= radius:
					results.append(obj)
	
	return results

func get_all_registered_objects(priority: ClickPriority = -1) -> Array:
	"""Get all registered objects, optionally filtered by priority"""
	var results = []
	
	if priority == -1:
		for p in clickable_objects:
			for data in clickable_objects[p]:
				if is_instance_valid(data["object"]):
					results.append(data["object"])
	else:
		for data in clickable_objects[priority]:
			if is_instance_valid(data["object"]):
				results.append(data["object"])
	
	return results

func clear_all() -> void:
	"""Clear all registered objects - useful when changing scenes"""
	for priority in clickable_objects:
		clickable_objects[priority].clear()
	currently_hovered = null
	last_clicked_object = null
	print("✓ ClickManager cleared all registered objects")

func get_registration_count() -> int:
	"""Get total number of registered objects"""
	var count = 0
	for priority in clickable_objects:
		count += clickable_objects[priority].size()
	return count
