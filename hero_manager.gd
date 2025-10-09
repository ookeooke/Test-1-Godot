extends Node2D

# ============================================
# HERO MANAGER - Manages hero spawning and selection
# ============================================

@export var ranger_hero_scene: PackedScene

var current_hero = null
var spawned_heroes = []

func _init():
	print("🔥 HERO MANAGER _init() CALLED")

func _enter_tree():
	print("🔥 HERO MANAGER _enter_tree() CALLED")
	add_to_group("hero_manager")

func _ready():
	print("========================================")
	print("🔥 HERO MANAGER READY")
	print("  HeroManager will handle hero selection")
	print("========================================")
	
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	
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
	print("🎯 Hero selected via signal: ", hero.name)
	
	# Deselect all other heroes
	for h in spawned_heroes:
		if h != hero and is_instance_valid(h):
			h.deselect()
	
	# Select this hero
	hero.select()
	current_hero = hero

# CHANGED: Use _input instead of _unhandled_input for higher priority
func _input(event):
	"""Handle hero commands with HIGH PRIORITY"""
	
	# ESC or Right-click to deselect
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
	
	# Left-click to move selected hero
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only handle if we have a selected hero
		if current_hero and is_instance_valid(current_hero) and current_hero.is_selected:
			# Check if UI has focus
			var focused_control = get_viewport().gui_get_focus_owner()
			if focused_control != null:
				print("UI has focus, ignoring click")
				return
			
			# IMPORTANT: Add small delay to let hero click events process first
			await get_tree().process_frame
			
			# Check if event was already handled (by hero click)
			if event.is_pressed():
				# Event not handled yet, so this is a movement command
				var mouse_pos = get_global_mouse_position()
				current_hero.move_to_position(mouse_pos)
				get_viewport().set_input_as_handled()
				print("✓ Hero moving to: ", mouse_pos)
