extends Node2D

# ============================================
# PLACEMENT MANAGER - Handles tower spots and menus
# ============================================

var build_menu_scene = preload("res://scenes/ui/build_menu.tscn")
var tower_info_menu_scene = preload("res://scenes/ui/tower_info_menu.tscn")
var current_menu = null
var current_spot = null
var current_selected_tower = null  # Track selected tower for deselection

# MENU LAYER - CanvasLayer for zoom-independent UI
var menu_layer: Control  # Reference to MenuContainer in CanvasLayer

func _ready():
	await get_tree().process_frame

	# Get reference to MenuContainer in CanvasLayer
	# MenuLayer is a sibling node in the level scene
	# The scene structure is: MenuLayer (CanvasLayer) -> MenuContainer (Control)
	var parent_node = get_parent()
	if parent_node.has_node("MenuLayer/MenuContainer"):
		menu_layer = parent_node.get_node("MenuLayer/MenuContainer")
		print("✓ MenuLayer found successfully!")
	else:
		push_error("MenuLayer/MenuContainer not found! Menus will not work correctly.")
		print("Looking for: MenuLayer/MenuContainer")
		print("Parent node: ", parent_node.name)
		print("Available children: ", parent_node.get_children())

	connect_tower_spots()

func connect_tower_spots():
	var spots = get_tree().get_nodes_in_group("tower_spot")

	for spot in spots:
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_tower_spot_clicked)
		if spot.has_signal("tower_clicked"):
			spot.tower_clicked.connect(_on_tower_clicked)

func _on_tower_spot_clicked(spot):
	"""Handle clicks on empty tower spots"""
	close_current_menu()
	current_spot = spot
	show_build_menu(spot)

func _on_tower_clicked(spot, tower):
	"""Handle clicks on existing towers"""
	# Deselect previously selected tower
	if current_selected_tower and is_instance_valid(current_selected_tower):
		if current_selected_tower.has_method("deselect_tower"):
			current_selected_tower.deselect_tower()

	close_current_menu()
	current_spot = spot
	current_selected_tower = tower

	# Show tower range indicator
	if tower and tower.has_method("select_tower"):
		tower.select_tower()

	show_tower_info_menu(spot, tower)

func close_current_menu():
	"""Close any open menu"""
	if current_menu:
		current_menu.queue_free()
		current_menu = null

func show_build_menu(spot):
	"""Show the tower build menu"""
	current_menu = build_menu_scene.instantiate()

	# ADD TO CANVAS LAYER (screen space), not root (world space)
	menu_layer.add_child(current_menu)

	# CRITICAL: Wait for menu to calculate its size
	# Menu containers need to be in tree and go through _ready() to calculate size
	await get_tree().process_frame
	await get_tree().process_frame  # Two frames to ensure size is final

	# Position in screen coordinates (zoom-independent)
	await position_menu_in_screen_space(spot)

	current_menu.tower_selected.connect(_on_tower_selected)
	current_menu.menu_closed.connect(_on_menu_closed)

func show_tower_info_menu(spot, tower):
	"""Show the tower info/upgrade menu"""
	current_menu = tower_info_menu_scene.instantiate()

	# ADD TO CANVAS LAYER (screen space), not root (world space)
	menu_layer.add_child(current_menu)

	if current_menu.has_method("setup"):
		current_menu.setup(tower, spot)

	# CRITICAL: Wait for menu to calculate its size
	# Menu containers need to be in tree and go through _ready() to calculate size
	await get_tree().process_frame
	await get_tree().process_frame  # Two frames to ensure size is final

	# Position in screen coordinates (zoom-independent)
	await position_menu_in_screen_space(spot)

	current_menu.upgrade_selected.connect(_on_tower_upgraded)
	current_menu.sell_selected.connect(_on_tower_sold)
	current_menu.menu_closed.connect(_on_menu_closed)

func position_menu_in_screen_space(spot):
	"""Position menu in screen space, following tower spot but zoom-independent (Kingdom Rush style)"""

	# STEP 1: Get tower spot world position
	var world_pos = spot.global_position
	print("🎯 Menu Positioning:")
	print("  Tower spot world position: ", world_pos)

	# STEP 2: Convert world position to screen position (accounts for camera pan/zoom)
	var camera = get_viewport().get_camera_2d()
	var screen_pos: Vector2

	if camera:
		# Transform: World Space → Camera Space → Screen Space
		# Formula: (world_pos - camera_pos) * zoom + screen_center
		var camera_offset = world_pos - camera.global_position
		var zoom_factor = camera.zoom
		print("  Camera position: ", camera.global_position)
		print("  Camera zoom: ", zoom_factor)
		print("  Camera offset: ", camera_offset)

		screen_pos = camera_offset * zoom_factor
		print("  After zoom multiply: ", screen_pos)

		screen_pos += get_viewport().get_visible_rect().size / 2
		print("  Screen center: ", get_viewport().get_visible_rect().size / 2)
		print("  Final screen position: ", screen_pos)
	else:
		# Fallback if no camera (center of screen)
		screen_pos = get_viewport().get_visible_rect().size / 2
		print("  No camera - using screen center")

	# STEP 3: Offset menu above the tower spot (100 pixels up in screen space)
	screen_pos.y -= 100
	print("  After offset up by 100px: ", screen_pos)

	# STEP 4: Clamp to screen edges (ensure fully visible)
	# Menu size should already be calculated (we waited in show_build_menu)
	var menu_size = current_menu.size
	print("  Menu size at positioning: ", menu_size)
	var viewport_size = get_viewport().get_visible_rect().size

	# Define safe margins (20px from edges)
	var margin = 20.0

	# Clamp horizontally
	if screen_pos.x - menu_size.x / 2 < margin:
		screen_pos.x = menu_size.x / 2 + margin
	elif screen_pos.x + menu_size.x / 2 > viewport_size.x - margin:
		screen_pos.x = viewport_size.x - menu_size.x / 2 - margin

	# Clamp vertically
	if screen_pos.y - menu_size.y < margin:
		screen_pos.y = menu_size.y + margin
	elif screen_pos.y > viewport_size.y - margin:
		screen_pos.y = viewport_size.y - margin

	# STEP 5: Center the menu at calculated position
	current_menu.position = screen_pos - menu_size / 2
	print("  Menu size: ", menu_size)
	print("  Final menu position: ", current_menu.position)
	print("  ✅ Menu positioned!")

func _on_tower_selected(tower_scene):
	"""Handle tower build selection"""
	if current_spot:
		current_spot.place_tower(tower_scene)

		# CHANGED: Close menu AFTER placing tower (fixes race condition)
		close_current_menu()
		current_spot = null
	else:
		print("ERROR: No current spot!")

func _on_tower_upgraded(tower):
	"""Handle tower upgrade"""
	if tower and "damage" in tower:
		tower.damage += 5

func _on_tower_sold(tower):
	"""Handle tower sell"""

	# Deselect tower before selling
	if tower and is_instance_valid(tower) and tower.has_method("deselect_tower"):
		tower.deselect_tower()

	if current_spot:
		current_spot.has_tower = false
		current_spot.current_tower = null
		current_spot.sprite.visible = true

		if tower and is_instance_valid(tower):
			tower.queue_free()

		current_spot = null
		current_selected_tower = null

func _on_menu_closed():
	"""Handle menu close (when clicking outside or pressing ESC)"""
	# Deselect tower when menu closes
	if current_selected_tower and is_instance_valid(current_selected_tower):
		if current_selected_tower.has_method("deselect_tower"):
			current_selected_tower.deselect_tower()

	current_spot = null
	current_selected_tower = null
