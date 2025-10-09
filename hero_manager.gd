extends Node2D

# ============================================
# HERO MANAGER - Manages hero spawning
# ============================================

# Hero scene (will expand to multiple heroes later)
@export var ranger_hero_scene: PackedScene

var current_hero = null

# Print immediately when script loads
func _init():
	print("🔥 HERO MANAGER _init() CALLED")

func _enter_tree():
	print("🔥 HERO MANAGER _enter_tree() CALLED")

func _ready():
	print("========================================")
	print("🔥 HERO MANAGER READY")
	print("  Ranger hero scene: ", ranger_hero_scene)
	print("  Scene is null: ", ranger_hero_scene == null)
	print("  Node path: ", get_path())
	print("========================================")
	
	# Wait for scene to be ready, then connect hero spots
	await get_tree().process_frame
	await get_tree().process_frame  # Wait an extra frame
	connect_hero_spots()

func connect_hero_spots():
	print("========================================")
	print("🔥 CONNECTING HERO SPOTS...")
	print("========================================")
	
	var spots = get_tree().get_nodes_in_group("hero_spot")
	print("Found ", spots.size(), " hero spots in 'hero_spot' group")
	
	if spots.size() == 0:
		print("⚠️ WARNING: NO HERO SPOTS FOUND!")
		print("  Searching all nodes...")
		
		# Manual search
		var all_nodes = get_tree().root.get_children()
		print("  Root has ", all_nodes.size(), " children")
		for node in all_nodes:
			print("    - ", node.name, " (", node.get_class(), ")")
		
		return
	
	for spot in spots:
		print("  Checking spot: ", spot.name)
		print("    Path: ", spot.get_path())
		print("    Has signal 'spot_clicked': ", spot.has_signal("spot_clicked"))
		
		if spot.has_signal("spot_clicked"):
			var err = spot.spot_clicked.connect(_on_hero_spot_clicked)
			print("    Connection result: ", err)
			if err == OK:
				print("    ✓ Connected successfully!")
			else:
				print("    ✗ Connection FAILED with error: ", err)
		else:
			print("    ✗ ERROR: No 'spot_clicked' signal!")
	
	print("========================================")

func _on_hero_spot_clicked(spot):
	print("========================================")
	print("🎉 !!! HERO_SPOT_CLICKED SIGNAL RECEIVED !!!")
	print("  Spot: ", spot.name)
	print("  Spot path: ", spot.get_path())
	print("  Ranger scene: ", ranger_hero_scene)
	print("========================================")
	
	# Spawn ranger hero at this spot
	if ranger_hero_scene == null:
		print("❌ ERROR: No ranger hero scene assigned in HeroManager!")
		print("   Check Inspector → HeroManager → Ranger Hero Scene")
		return
	
	print("Calling spot.spawn_hero()...")
	spot.spawn_hero(ranger_hero_scene)
	print("spawn_hero() call completed")

func _unhandled_input(event):
	# Deselect hero with ESC or right-click
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			get_viewport().set_input_as_handled()
			print("Hero deselected (ESC)")
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			get_viewport().set_input_as_handled()
			print("Hero deselected (Right-click)")
		return
	
	# Handle hero selection and movement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		# First, check if we clicked on a tower spot or hero spot
		# (Let those handle their clicks first)
		var tower_spots = get_tree().get_nodes_in_group("tower_spot")
		for spot in tower_spots:
			if spot.global_position.distance_to(mouse_pos) < 32:
				# Clicked on tower spot - don't handle this click
				return
		
		var hero_spots = get_tree().get_nodes_in_group("hero_spot")
		for spot in hero_spots:
			if spot.global_position.distance_to(mouse_pos) < 32:
				# Clicked on hero spot - don't handle this click
				return
		
		# Check if we clicked on a hero
		var heroes = get_tree().get_nodes_in_group("hero")
		var clicked_hero = null
		
		for hero in heroes:
			if hero.global_position.distance_to(mouse_pos) < 30:
				clicked_hero = hero
				break
		
		if clicked_hero:
			# Deselect all other heroes
			for hero in heroes:
				if hero != clicked_hero:
					hero.deselect()
			
			# Select this hero
			clicked_hero.select()
			current_hero = clicked_hero
			get_viewport().set_input_as_handled()
			print("Selected hero: ", clicked_hero.name)
		else:
			# Clicked empty space
			# If we have a selected hero, move them to clicked position
			if current_hero and is_instance_valid(current_hero):
				if current_hero.is_selected:
					current_hero.move_to_position(mouse_pos)
					get_viewport().set_input_as_handled()
					print("Commanding hero to move to: ", mouse_pos)
			else:
				# No hero selected and clicked empty space - do nothing
				# This allows deselection naturally
				pass
