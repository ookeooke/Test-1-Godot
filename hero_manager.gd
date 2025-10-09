extends Node2D

# ============================================
# HERO MANAGER - Manages hero spawning and selection
# ============================================

@export var ranger_hero_scene: PackedScene  # Keep this for reference, but spots will handle spawning

var current_hero = null
var spawned_heroes = []  # Track all spawned heroes

func _init():
	print("🔥 HERO MANAGER _init() CALLED")

func _enter_tree():
	print("🔥 HERO MANAGER _enter_tree() CALLED")
	# Add to group so hero spots can find us
	add_to_group("hero_manager")

func _ready():
	print("========================================")
	print("🔥 HERO MANAGER READY")
	print("  HeroManager will handle hero selection")
	print("========================================")
	
	# Wait for heroes to spawn automatically
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find all heroes that were auto-spawned and connect their signals
	connect_existing_heroes()

func connect_existing_heroes():
	"""Connect to any heroes that already exist in the scene"""
	print("Connecting to existing heroes...")
	var heroes = get_tree().get_nodes_in_group("hero")
	
	for hero in heroes:
		if hero.has_signal("hero_selected"):
			if not hero.hero_selected.is_connected(_on_hero_selected):
				hero.hero_selected.connect(_on_hero_selected)
				spawned_heroes.append(hero)
				print("  ✓ Connected to hero: ", hero.name)

func _on_hero_selected(hero):
	"""Called when a hero is clicked"""
	print("Hero selected via signal: ", hero.name)
	
	# Deselect all other heroes
	for h in spawned_heroes:
		if h != hero and is_instance_valid(h):
			h.deselect()
	
	# Select this hero
	hero.select()
	current_hero = hero

func _unhandled_input(event):
	# Handle deselection with ESC or right-click
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
		var gui_control = get_viewport().gui_get_focus_owner()
		if gui_control != null:
			return
		
		var mouse_pos = get_global_mouse_position()
		
		# Only handle if we have a selected hero
		# The event will be marked as handled by tower spots/heroes/etc if they were clicked
		# So if we reach here with a selected hero, it's likely a ground click
		if current_hero and is_instance_valid(current_hero) and current_hero.is_selected:
			# Small delay to let other input handlers process first
			await get_tree().process_frame
			
			# Check if event was already handled
			if not event.is_pressed():  # Event was consumed
				return
			
			current_hero.move_to_position(mouse_pos)
			get_viewport().set_input_as_handled()
			print("Hero moving to: ", mouse_pos)
