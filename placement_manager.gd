extends Node2D

# ============================================
# PLACEMENT MANAGER - Handles tower spots and build menu
# ============================================

var build_menu_scene = preload("res://build_menu.tscn")
var current_build_menu = null
var current_spot = null

func _ready():
	print("========================================")
	print("PLACEMENT MANAGER READY")
	print("========================================")
	# Find all tower spots and connect their signals
	await get_tree().process_frame
	connect_tower_spots()

func connect_tower_spots():
	print("Connecting tower spots...")
	# Get all TowerSpot nodes in the scene
	var spots = get_tree().get_nodes_in_group("tower_spot")
	print("Found ", spots.size(), " tower spots in 'tower_spot' group")
	
	for spot in spots:
		print("  Checking spot: ", spot.name)
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_tower_spot_clicked)
			print("    ✓ Connected tower spot: ", spot.name)
		else:
			print("    ✗ ERROR: Spot doesn't have 'spot_clicked' signal!")

func _on_tower_spot_clicked(spot):
	print("========================================")
	print("!!! TOWER SPOT CLICKED SIGNAL RECEIVED !!!")
	print("  Spot name: ", spot.name)
	print("  Spot position: ", spot.global_position)
	print("========================================")
	
	# Close existing menu if any
	if current_build_menu:
		print("Closing existing menu...")
		current_build_menu.queue_free()
		current_build_menu = null
	
	# Create new build menu
	current_spot = spot
	show_build_menu(spot)

func show_build_menu(spot):
	print("Creating build menu...")
	
	# Create the menu
	current_build_menu = build_menu_scene.instantiate()
	get_tree().root.add_child(current_build_menu)
	
	print("  Menu created and added to scene")
	
	# Position it above the spot
	var menu_pos = spot.get_position_for_menu()
	print("  Menu world position: ", menu_pos)
	
	# Convert world position to screen position
	var camera = get_viewport().get_camera_2d()
	if camera:
		var canvas_pos = camera.get_screen_center_position()
		var zoom = camera.zoom
		var offset = (menu_pos - canvas_pos) * zoom
		var screen_center = get_viewport().get_visible_rect().size / 2
		
		current_build_menu.global_position = screen_center + offset
		current_build_menu.global_position -= current_build_menu.size / 2  # Center the menu
		
		print("  Menu screen position: ", current_build_menu.global_position)
	else:
		print("  WARNING: No camera found, positioning at world position")
		current_build_menu.global_position = menu_pos
	
	# Connect menu signals
	current_build_menu.tower_selected.connect(_on_tower_selected)
	current_build_menu.menu_closed.connect(_on_menu_closed)
	
	print("  Menu signals connected")
	print("BUILD MENU SHOWN!")

func _on_tower_selected(tower_scene):
	print("Tower selected from menu!")
	if current_spot:
		current_spot.place_tower(tower_scene)
		current_spot = null
	else:
		print("ERROR: No current spot!")

func _on_menu_closed():
	print("Menu closed")
	current_spot = null
