extends Node2D

# ============================================
# PLACEMENT MANAGER - Handles tower spots and menus
# ============================================

var build_menu_scene = preload("res://build_menu.tscn")
var tower_info_menu_scene = preload("res://tower_info_menu.tscn")  # NEW
var current_menu = null
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
	var spots = get_tree().get_nodes_in_group("tower_spot")
	print("Found ", spots.size(), " tower spots in 'tower_spot' group")
	
	for spot in spots:
		print("  Checking spot: ", spot.name)
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_tower_spot_clicked)
			print("    ✓ Connected spot_clicked signal: ", spot.name)
		# NEW: Connect to tower_clicked signal
		if spot.has_signal("tower_clicked"):
			spot.tower_clicked.connect(_on_tower_clicked)
			print("    ✓ Connected tower_clicked signal: ", spot.name)

func _on_tower_spot_clicked(spot):
	"""Handle clicks on empty tower spots"""
	print("========================================")
	print("!!! TOWER SPOT CLICKED SIGNAL RECEIVED !!!")
	print("  Spot name: ", spot.name)
	print("  Spot position: ", spot.global_position)
	print("========================================")
	
	# Close existing menu if any
	close_current_menu()
	
	# Create new build menu
	current_spot = spot
	show_build_menu(spot)

# NEW: Handle clicks on existing towers
func _on_tower_clicked(spot, tower):
	"""Handle clicks on existing towers"""
	print("========================================")
	print("!!! TOWER CLICKED SIGNAL RECEIVED !!!")
	print("  Spot: ", spot.name)
	print("  Tower: ", tower.name if tower else "null")
	print("========================================")
	
	# Close existing menu if any
	close_current_menu()
	
	# Create tower info menu
	current_spot = spot
	show_tower_info_menu(spot, tower)

func close_current_menu():
	"""Close any open menu"""
	if current_menu:
		print("Closing existing menu...")
		current_menu.queue_free()
		current_menu = null

func show_build_menu(spot):
	"""Show the tower build menu"""
	print("Creating build menu...")
	
	# Create the menu
	current_menu = build_menu_scene.instantiate()
	get_tree().root.add_child(current_menu)
	
	print("  Menu created and added to scene")
	
	# Position it above the spot
	position_menu(spot)
	
	# Connect menu signals
	current_menu.tower_selected.connect(_on_tower_selected)
	current_menu.menu_closed.connect(_on_menu_closed)
	
	print("BUILD MENU SHOWN!")

# NEW: Show tower info menu
func show_tower_info_menu(spot, tower):
	"""Show the tower info/upgrade menu"""
	print("Creating tower info menu...")
	
	# Create the menu
	current_menu = tower_info_menu_scene.instantiate()
	get_tree().root.add_child(current_menu)
	
	print("  Tower info menu created")
	
	# Setup the menu with tower data
	if current_menu.has_method("setup"):
		current_menu.setup(tower, spot)
	
	# Position it above the spot
	position_menu(spot)
	
	# Connect menu signals
	current_menu.upgrade_selected.connect(_on_tower_upgraded)
	current_menu.sell_selected.connect(_on_tower_sold)
	current_menu.menu_closed.connect(_on_menu_closed)
	
	print("TOWER INFO MENU SHOWN!")

func position_menu(spot):
	"""Position a menu above the given spot"""
	var menu_pos = spot.get_position_for_menu()
	print("  Menu world position: ", menu_pos)
	
	# Convert world position to screen position
	var camera = get_viewport().get_camera_2d()
	if camera:
		var canvas_pos = camera.get_screen_center_position()
		var zoom = camera.zoom
		var offset = (menu_pos - canvas_pos) * zoom
		var screen_center = get_viewport().get_visible_rect().size / 2
		
		current_menu.global_position = screen_center + offset
		current_menu.global_position -= current_menu.size / 2  # Center the menu
		
		print("  Menu screen position: ", current_menu.global_position)
	else:
		print("  WARNING: No camera found, positioning at world position")
		current_menu.global_position = menu_pos

func _on_tower_selected(tower_scene):
	"""Handle tower build selection"""
	print("Tower selected from menu!")
	if current_spot:
		current_spot.place_tower(tower_scene)
		current_spot = null
	else:
		print("ERROR: No current spot!")

# NEW: Handle tower upgrade
func _on_tower_upgraded(tower):
	"""Handle tower upgrade"""
	print("Tower upgraded: ", tower.name if tower else "null")
	# TODO: Implement actual upgrade logic
	# Increase tower stats, update visuals, etc.
	if tower and "damage" in tower:
		tower.damage += 5
		print("  New damage: ", tower.damage)

# NEW: Handle tower sell
func _on_tower_sold(tower):
	"""Handle tower sell"""
	print("Tower sold: ", tower.name if tower else "null")
	if current_spot:
		# Reset the spot
		current_spot.has_tower = false
		current_spot.current_tower = null
		current_spot.sprite.visible = true
		
		# Remove the tower
		if tower and is_instance_valid(tower):
			tower.queue_free()
		
		current_spot = null

func _on_menu_closed():
	"""Handle menu close"""
	print("Menu closed")
	current_spot = null
