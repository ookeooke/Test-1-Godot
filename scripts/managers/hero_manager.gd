extends Node2D

# ============================================
# HERO MANAGER - Manages hero selection and movement
# ============================================

@export var ranger_hero_scene: PackedScene

var current_hero = null
var spawned_heroes = []
var hero_button = null  # Reference to the UI hero button

func _ready():
	# Wait for scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame

	connect_existing_heroes()
	connect_hero_button()

func connect_existing_heroes():
	"""Connect to any heroes that already exist in the scene"""
	var heroes = get_tree().get_nodes_in_group("hero")

	for hero in heroes:
		if hero.has_signal("hero_selected"):
			if not hero.hero_selected.is_connected(_on_hero_selected):
				hero.hero_selected.connect(_on_hero_selected)
				spawned_heroes.append(hero)

	# If no heroes found yet, wait and try again
	if heroes.is_empty():
		await get_tree().create_timer(0.5).timeout
		connect_existing_heroes()
	else:
		# Connect first hero to button
		if hero_button and not spawned_heroes.is_empty():
			hero_button.set_hero(spawned_heroes[0])

func connect_hero_button():
	"""Find and connect to the HeroButton in the UI"""
	# Search for HeroButton in the scene tree
	var ui_layer = get_tree().get_first_node_in_group("ui")
	if not ui_layer:
		# Try to find by path
		var root = get_tree().current_scene
		if root.has_node("UI/HeroButton"):
			hero_button = root.get_node("UI/HeroButton")
		else:
			print("WARNING: HeroButton not found")
	else:
		if ui_layer.has_node("HeroButton"):
			hero_button = ui_layer.get_node("HeroButton")

func _on_hero_selected(hero):
	"""Called when a hero is clicked and selects itself"""

	# Deselect all other heroes
	for h in spawned_heroes:
		if h != hero and is_instance_valid(h):
			h.deselect()

	# Select this hero
	hero.select()
	current_hero = hero

	# Update button visual state
	if hero_button:
		hero_button.set_selected(true)


func _input(event):
	"""Handle hero movement commands and deselection"""
	# Don't process input if GUI is focused
	var gui_element = get_viewport().gui_get_hovered_control()
	if gui_element:
		return

	# ESC to deselect
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			if hero_button:
				hero_button.set_selected(false)
			get_viewport().set_input_as_handled()
		return

	# Left-click on empty space to move hero
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_hero and is_instance_valid(current_hero) and current_hero.is_selected:
			# Get world position
			var camera = get_viewport().get_camera_2d()
			if camera:
				var click_world_pos = camera.get_screen_center_position() + (event.position - get_viewport().get_visible_rect().size / 2) / camera.zoom

				# Command hero to move to clicked position
				current_hero.move_to_position(click_world_pos)

				# Auto-deselect hero after giving move command
				current_hero.deselect()
				current_hero = null
				if hero_button:
					hero_button.set_selected(false)
				get_viewport().set_input_as_handled()
		return

	# Right-click to deselect
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			if hero_button:
				hero_button.set_selected(false)
			get_viewport().set_input_as_handled()
		return
