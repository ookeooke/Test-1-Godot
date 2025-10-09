extends Node2D

@export var ranger_hero_scene: PackedScene

var current_hero = null
var spawned_heroes = []  # Track all spawned heroes

func _init():
	print("🔥 HERO MANAGER _init() CALLED")

func _enter_tree():
	print("🔥 HERO MANAGER _enter_tree() CALLED")

func _ready():
	print("========================================")
	print("🔥 HERO MANAGER READY")
	print("  Ranger hero scene: ", ranger_hero_scene)
	print("========================================")
	
	await get_tree().process_frame
	await get_tree().process_frame
	connect_hero_spots()

func connect_hero_spots():
	print("🔥 CONNECTING HERO SPOTS...")
	
	var spots = get_tree().get_nodes_in_group("hero_spot")
	print("Found ", spots.size(), " hero spots")
	
	for spot in spots:
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_hero_spot_clicked)
			print("  ✓ Connected spot: ", spot.name)

func _on_hero_spot_clicked(spot):
	print("🎉 HERO_SPOT_CLICKED!")
	
	if ranger_hero_scene == null:
		print("❌ ERROR: No ranger hero scene assigned!")
		return
	
	# Spawn hero
	var hero = ranger_hero_scene.instantiate()
	spot.add_child(hero)
	hero.global_position = spot.global_position
	
	if hero.has_method("set_home_position"):
		hero.set_home_position(spot.global_position)
	
	# Connect hero signals
	if hero.has_signal("hero_died"):
		hero.hero_died.connect(spot._on_hero_died)
	
	if hero.has_signal("hero_selected"):
		hero.hero_selected.connect(_on_hero_selected)
	
	spawned_heroes.append(hero)
	print("✓ Hero spawned and connected!")

func _on_hero_selected(hero):
	print("Hero selected via signal: ", hero.name)
	
	# Deselect all other heroes
	for h in spawned_heroes:
		if h != hero and is_instance_valid(h):
			h.deselect()
	
	# Select this hero
	hero.select()
	current_hero = hero

func _unhandled_input(event):
	# Handle deselection
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			get_viewport().set_input_as_handled()
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			get_viewport().set_input_as_handled()
		return
	
	# Handle movement commands for selected hero
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if UI was clicked
		if get_viewport().gui_get_focus_owner() != null:
			return
		
		var mouse_pos = get_global_mouse_position()
		
		# Only handle if we have a selected hero and didn't click on anything else
		if current_hero and is_instance_valid(current_hero) and current_hero.is_selected:
			# The event will be marked as handled by tower spots/heroes if they were clicked
			# So if we reach here, it's a ground click
			current_hero.move_to_position(mouse_pos)
			print("Hero moving to: ", mouse_pos)
