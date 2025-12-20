extends Node2D

# ============================================
# HERO MANAGER - Manages hero selection and movement
# ============================================

@export var ranger_hero_scene: PackedScene
@export var debug_input = false # Print all input events

var current_hero = null
var spawned_heroes = []
var hero_button = null # Reference to the UI hero button

signal hero_selected(hero)

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
	"""Find and connect to the HeroButton (or HeroCommandWidget) in the UI"""
	# 1. Try finding the new UnifiedHeroWidget first (Group-based)
	var widgets = get_tree().get_nodes_in_group("hero_command_widget")
	if not widgets.is_empty():
		hero_button = widgets[0] # Use the first one found
		print("✅ [HeroManager] Connected to HeroCommandWidget")
		return

	# 2. Fallback: Search for classic HeroButton in the scene tree
	var ui_layer = get_tree().get_first_node_in_group("ui")
	if not ui_layer:
		# Try to find by path
		var root = get_tree().current_scene
		if root.has_node("UI/HeroButton"):
			hero_button = root.get_node("UI/HeroButton")
		else:
			print("WARNING: HeroButton/HeroCommandWidget not found")
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
		
	hero_selected.emit(hero)


func _unhandled_input(event):
	"""Handle hero movement commands and deselection"""
	# IMPORTANT: This runs in the _unhandled_input stage (stage 3)
	# This allows UI controls and Area2D physics clicks to process first
	# This prevents blocking tower/hero clicks when no hero is selected

	# DEBUG: Log input events
	if debug_input:
		print("[HeroManager DEBUG] _unhandled_input called")
		print("  Event type: ", event.get_class())
		print("  current_hero: ", current_hero)
		if event is InputEventMouseButton:
			print("  Button: ", event.button_index, " Pressed: ", event.pressed)

	# DEBUG: Trace input flow for mouse clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🖱️ [HeroManager] Left click detected in _unhandled_input")

	# Don't process input if GUI is focused
	var gui_element = get_viewport().gui_get_hovered_control()
	if debug_input:
		print("[HeroManager DEBUG] GUI element: ", gui_element)
	if gui_element:
		# DEBUG: Help identify invisible UI blockers
		if gui_element.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("🚫 [HeroManager] Input BLOCKED by UI: ", gui_element.name, " (", gui_element, ")")
		if debug_input:
			print("[HeroManager DEBUG] GUI detected - returning")
		return

	# ESC to deselect (also check InputMap action)
	if Input.is_action_just_pressed("deselect") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if current_hero and is_instance_valid(current_hero):
			if debug_input:
				print("[HeroManager DEBUG] ESC pressed - deselecting hero")
			current_hero.deselect()
			current_hero = null
			if hero_button:
				hero_button.set_selected(false)
			get_viewport().set_input_as_handled()
		return

	# CHECK: Ensure action exists (Safety check)
	if not InputMap.has_action("interact"):
		push_error("CRITICAL: 'interact' action missing! InputActionsSetup failed?")
		return

	# Left-click/tap on empty space to move hero (using InputMap action)
	if Input.is_action_just_pressed("interact"):
		print("✅ [HeroManager] 'interact' action fired!")
		if current_hero and is_instance_valid(current_hero) and current_hero.is_selected:
			if debug_input:
				print("[HeroManager DEBUG] Left-click - checking target")

			# Get world position
			# FIX: Use get_global_mouse_position() which handles Canvas/Viewport transforms automatically on all platforms (including Web)
			# The previous manual calculation was double-applying transforms or using incorrect feedback
			var click_world_pos = get_global_mouse_position()
			print("📍 [HeroManager] Processing Move to: ", click_world_pos)
			if debug_input:
				print("[HeroManager] Click World Pos: ", click_world_pos)

			# RAYCAST: Check if clicking on interactive object (tower/hero/item)
			# This prevents hero movement from blocking tower/hero clicks
			var space_state = get_viewport().get_world_2d().direct_space_state
			var query = PhysicsPointQueryParameters2D.new()
			query.position = click_world_pos
			query.collide_with_areas = true # Check Area2D (towers, heroes, items)
			query.collide_with_bodies = false # Don't check bodies (we only want Area2D)

			var results = space_state.intersect_point(query, 5) # Check up to 5 objects

			# Check if clicking on tower/hero/item
			var clicking_interactive_object = false
			for result in results:
				var collider = result.collider
				# Check if object is a tower, hero, or item
				if collider.is_in_group("towers") or collider.is_in_group("heroes") or collider.is_in_group("items"):
					clicking_interactive_object = true
					if debug_input:
						print("[HeroManager DEBUG] Clicking on interactive object: ", collider.name)
					break

			# If clicking interactive object, DON'T move hero - let Area2D handle it
			if clicking_interactive_object:
				print("🚫 [HeroManager] Click BLOCKED by interactive object")
				return # Exit without consuming input - let Area2D (Stage 4) process it

			# ROAD CONSTRAINT CHECK (Only if RoadRenderer exists)
			var road_renderer = get_tree().get_first_node_in_group("road_renderer")
			var can_move = true
			
			if road_renderer and is_instance_valid(road_renderer) and road_renderer.visible:
				# Check if point is on road (with tolerance)
				if not road_renderer.is_point_on_road(click_world_pos, 40.0):
					print("[HeroManager] Movement blocked: Target not on road")
					can_move = false
					# Visual feedback for blocked move
					if current_hero and current_hero.has_method("_show_floating_text"):
						current_hero._show_floating_text("Can't move there!", Color.RED)
			
			if can_move:
				print("🏃 [HeroManager] Sending Move Command to: ", current_hero.name)
				current_hero.move_to_position(click_world_pos)
				
				# Auto-deselect hero after giving move command
				current_hero.deselect()
				current_hero = null
				if hero_button:
					hero_button.set_selected(false)
				get_viewport().set_input_as_handled()
		return

	# Right-click deselect REMOVED - use ESC key instead (via "deselect" action above)
	# This allows right-click to always pass through to camera for panning
	# Users can press ESC to deselect hero, then use right-drag for camera
