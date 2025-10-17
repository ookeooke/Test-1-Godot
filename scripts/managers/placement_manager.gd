extends Node2D

# ============================================
# PLACEMENT MANAGER - Handles tower spots and menus
# ============================================

var build_menu_scene = preload("res://scenes/ui/build_menu.tscn")
var tower_info_menu_scene = preload("res://scenes/ui/tower_info_menu.tscn")
var current_menu = null
var current_spot = null
var current_selected_tower = null  # Track selected tower for deselection

func _ready():
	await get_tree().process_frame
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
	get_tree().root.add_child(current_menu)

	position_menu(spot)

	current_menu.tower_selected.connect(_on_tower_selected)
	current_menu.menu_closed.connect(_on_menu_closed)

func show_tower_info_menu(spot, tower):
	"""Show the tower info/upgrade menu"""
	current_menu = tower_info_menu_scene.instantiate()
	get_tree().root.add_child(current_menu)

	if current_menu.has_method("setup"):
		current_menu.setup(tower, spot)

	position_menu(spot)

	current_menu.upgrade_selected.connect(_on_tower_upgraded)
	current_menu.sell_selected.connect(_on_tower_sold)
	current_menu.menu_closed.connect(_on_menu_closed)

func position_menu(spot):
	"""Position a menu above the given spot"""
	var menu_pos = spot.get_position_for_menu()

	var camera = get_viewport().get_camera_2d()
	if camera:
		var canvas_pos = camera.get_screen_center_position()
		var zoom = camera.zoom
		var offset = (menu_pos - canvas_pos) * zoom
		var screen_center = get_viewport().get_visible_rect().size / 2

		current_menu.global_position = screen_center + offset
		current_menu.global_position -= current_menu.size / 2
	else:
		print("WARNING: No camera found, positioning at world position")
		current_menu.global_position = menu_pos

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
