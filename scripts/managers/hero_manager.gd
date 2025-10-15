extends Node2D

# ============================================
# HERO MANAGER - Much simpler with ClickManager!
# ============================================

@export var ranger_hero_scene: PackedScene

var current_hero = null
var spawned_heroes = []
var hero_button = null  # Reference to the UI hero button

func _ready():
	print("========================================")
	print("🔥 HERO MANAGER READY")
	print("========================================")

	# Wait for scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame

	connect_existing_heroes()
	connect_hero_button()

	# Connect to ClickManager signals
	ClickManager.object_clicked.connect(_on_object_clicked)
	ClickManager.empty_space_clicked.connect(_on_empty_space_clicked)

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

	# If no heroes found yet, wait and try again
	if heroes.is_empty():
		print("  No heroes found yet, will retry...")
		await get_tree().create_timer(0.5).timeout
		connect_existing_heroes()
	else:
		# Connect first hero to button
		if hero_button and not spawned_heroes.is_empty():
			hero_button.set_hero(spawned_heroes[0])
			print("  ✓ Connected hero to button")

func connect_hero_button():
	"""Find and connect to the HeroButton in the UI"""
	# Search for HeroButton in the scene tree
	var ui_layer = get_tree().get_first_node_in_group("ui")
	if not ui_layer:
		# Try to find by path
		var root = get_tree().current_scene
		if root.has_node("UI/HeroButton"):
			hero_button = root.get_node("UI/HeroButton")
			print("  ✓ Found HeroButton by path")
		else:
			print("  ⚠ HeroButton not found")
	else:
		if ui_layer.has_node("HeroButton"):
			hero_button = ui_layer.get_node("HeroButton")
			print("  ✓ Found HeroButton in UI layer")

func _on_hero_selected(hero):
	"""Called when a hero is clicked and selects itself"""
	print("🎯 Hero selected via signal: ", hero.name)

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

func _on_object_clicked(object, click_position):
	"""Called when any object is clicked via ClickManager"""
	# If we have a selected hero and clicked something else (not a hero)
	if current_hero and is_instance_valid(current_hero):
		if object and object.is_in_group("hero"):
			# Clicked another hero - handled by hero_selected signal
			return
		elif object == null:
			# Clicked empty space - handle as movement command
			# (This is now handled by empty_space_clicked signal)
			pass

func _on_empty_space_clicked(click_position):
	"""Called when empty space is clicked"""
	if current_hero and is_instance_valid(current_hero) and current_hero.is_selected:
		# Command hero to move to clicked position
		current_hero.move_to_position(click_position)
		print("✓ Hero moving to: ", click_position)

func _input(event):
	"""Handle deselection with ESC or Right-click"""
	# ESC to deselect
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if current_hero and is_instance_valid(current_hero):
			current_hero.deselect()
			current_hero = null
			if hero_button:
				hero_button.set_selected(false)
			get_viewport().set_input_as_handled()
			print("Hero deselected (ESC)")
		return

	# Right-click to deselect
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_hero and is_instance_valid(current_hero):
			# Check if we right-clicked on something
			# If not, deselect
			var click_pos = get_global_mouse_position()
			var clicked_obj = ClickManager.find_clicked_object(click_pos)

			if not clicked_obj:
				current_hero.deselect()
				current_hero = null
				if hero_button:
					hero_button.set_selected(false)
				get_viewport().set_input_as_handled()
				print("Hero deselected (Right-click)")
		return
