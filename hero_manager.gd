extends Node2D

# ============================================
# HERO MANAGER - Manages hero spawning
# ============================================

# Hero scene (will expand to multiple heroes later)
@export var ranger_hero_scene: PackedScene

var current_hero = null

func _ready():
	print("========================================")
	print("HERO MANAGER READY")
	print("========================================")
	
	# Wait for scene to be ready, then connect hero spots
	await get_tree().process_frame
	connect_hero_spots()

func connect_hero_spots():
	print("Connecting hero spots...")
	var spots = get_tree().get_nodes_in_group("hero_spot")
	print("Found ", spots.size(), " hero spots")
	
	for spot in spots:
		print("  Connecting hero spot: ", spot.name)
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_hero_spot_clicked)
			print("    ✓ Connected hero spot: ", spot.name)
		else:
			print("    ✗ ERROR: Spot doesn't have 'spot_clicked' signal!")

func _on_hero_spot_clicked(spot):
	print("========================================")
	print("!!! HERO SPOT CLICKED !!!")
	print("  Spot: ", spot.name)
	print("========================================")
	
	# Spawn ranger hero at this spot
	if ranger_hero_scene == null:
		print("ERROR: No ranger hero scene assigned!")
		return
	
	spot.spawn_hero(ranger_hero_scene)
	print("Hero spawned at spot!")

func _unhandled_input(event):
	# Handle hero selection and movement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
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
			print("Selected hero: ", clicked_hero.name)
		else:
			# If we have a selected hero, move them to clicked position
			if current_hero and is_instance_valid(current_hero):
				if current_hero.is_selected:
					current_hero.move_to_position(mouse_pos)
					print("Commanding hero to move to: ", mouse_pos)
