extends Node2D

# ============================================
# PLACEMENT MANAGER - Handles tower spots and build menu
# ============================================

var build_menu_scene = preload("res://build_menu.tscn")
var current_build_menu = null
var current_spot = null

func _ready():
	# Find all tower spots and connect their signals
	await get_tree().process_frame
	connect_tower_spots()

func connect_tower_spots():
	# Get all TowerSpot nodes in the scene
	var spots = get_tree().get_nodes_in_group("tower_spot")
	for spot in spots:
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_tower_spot_clicked)
			print("Connected tower spot: ", spot.name)

func _on_tower_spot_clicked(spot):
	print("Tower spot clicked!")
	
	# Close existing menu if any
	if current_build_menu:
		current_build_menu.queue_free()
		current_build_menu = null
	
	# Create new build menu
	current_spot = spot
	show_build_menu(spot)

func show_build_menu(spot):
	# Create the menu
	current_build_menu = build_menu_scene.instantiate()
	get_tree().root.add_child(current_build_menu)
	
	# Position it above the spot
	var menu_pos = spot.get_position_for_menu()
	# Convert world position to screen position
	var camera = get_viewport().get_camera_2d()
	var canvas_pos = camera.get_screen_center_position()
	var zoom = camera.zoom
	var offset = (menu_pos - canvas_pos) * zoom
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	current_build_menu.global_position = screen_center + offset
	current_build_menu.global_position -= current_build_menu.size / 2  # Center the menu
	
	# Connect menu signals
	current_build_menu.tower_selected.connect(_on_tower_selected)
	current_build_menu.menu_closed.connect(_on_menu_closed)

func _on_tower_selected(tower_scene):
	if current_spot:
		current_spot.place_tower(tower_scene)
		current_spot = null

func _on_menu_closed():
	current_spot = null
