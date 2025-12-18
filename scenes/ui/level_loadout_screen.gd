extends Control

signal back_pressed

# Preload DifficultyConstants for 5-star rating system
# const DifficultyConstants = preload("res://scripts/constants/difficulty_constants.gd")

@onready var hero_container = $CenterContainer/HBoxContainer
@onready var level_info_label = $VBoxContainer/LevelInfoLabel
@onready var deploy_button = $VBoxContainer/DeployButton

var selected_hero_id: String = ""
var target_level_id: String = ""
var selected_difficulty: String = "normal"
var difficulty_buttons: Array[Button] = []

func setup(level_id: String):
	target_level_id = level_id
	_update_level_info()
	_setup_difficulty_selector()
	_populate_heroes()

func _ready():
	deploy_button.disabled = true
	deploy_button.pressed.connect(_on_deploy_pressed)
	
	# Back button (if exists)
	var back_btn = find_child("BackButton")
	if back_btn:
		back_btn.pressed.connect(func():
			back_pressed.emit()
			queue_free()
		)

func _update_level_info():
	if target_level_id == "": return

	# Get level data (placeholder for now, or from LevelManager if available)
	level_info_label.text = "[center][b]Level: %s[/b]\nSelect difficulty and hero![/center]" % target_level_id.capitalize()

func _setup_difficulty_selector():
	"""Create difficulty selector buttons (Normal, Hard, Unlimited)"""
	if target_level_id == "": return

	# Create container for difficulty buttons
	var difficulty_container = HBoxContainer.new()
	difficulty_container.name = "DifficultyContainer"
	difficulty_container.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_container.add_theme_constant_override("separation", 15)

	# Create button group for radio behavior
	var button_group = ButtonGroup.new()

	# Create buttons for each difficulty
	for diff in DifficultyConstants.ALL_DIFFICULTIES:
		var button = Button.new()
		button.name = "%sButton" % diff.capitalize()
		button.text = DifficultyConstants.DIFFICULTY_NAMES[diff]
		button.custom_minimum_size = Vector2(140, 60)
		button.toggle_mode = true
		button.button_group = button_group

		# Check if unlocked
		var unlocked = SaveManager.is_difficulty_unlocked(target_level_id, diff)
		button.disabled = not unlocked

		# Color code button with border and background
		var style_normal = StyleBoxFlat.new()
		var style_pressed = StyleBoxFlat.new()
		var style_disabled = StyleBoxFlat.new()

		var difficulty_color = DifficultyConstants.DIFFICULTY_COLORS[diff]

		# Normal state
		style_normal.bg_color = difficulty_color.darkened(0.8)
		style_normal.border_color = difficulty_color
		style_normal.set_border_width_all(3)
		style_normal.set_corner_radius_all(5)

		# Pressed/selected state
		style_pressed.bg_color = difficulty_color.darkened(0.5)
		style_pressed.border_color = difficulty_color.lightened(0.2)
		style_pressed.set_border_width_all(4)
		style_pressed.set_corner_radius_all(5)

		# Disabled state
		style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
		style_disabled.set_border_width_all(2)
		style_disabled.set_corner_radius_all(5)

		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_stylebox_override("disabled", style_disabled)

		# Add tooltip for locked difficulties
		if not unlocked:
			button.tooltip_text = DifficultyConstants.UNLOCK_REQUIREMENTS[diff]
		else:
			# Show stars earned on this difficulty
			var stars = SaveManager.get_level_stars(target_level_id, diff)
			if stars > 0:
				button.tooltip_text = "%d stars earned on %s" % [stars, diff.capitalize()]

		# Connect signal
		button.pressed.connect(_on_difficulty_selected.bind(diff, button))

		difficulty_container.add_child(button)
		difficulty_buttons.append(button)

		# Auto-select normal difficulty (first button)
		if diff == "normal" and unlocked:
			button.button_pressed = true
			selected_difficulty = "normal"

	# Insert difficulty container into the scene tree
	# Place it after level_info_label in VBoxContainer
	var vbox = level_info_label.get_parent()
	if vbox:
		vbox.add_child(difficulty_container)
		vbox.move_child(difficulty_container, 1) # Position after level_info_label
		print("[LevelLoadoutScreen] Difficulty selector created with %d buttons" % difficulty_buttons.size())

func _on_difficulty_selected(diff: String, _button: Button):
	"""Handle difficulty selection"""
	selected_difficulty = diff
	_update_deploy_button()
	print("[LevelLoadoutScreen] Difficulty selected: %s" % diff)

func _update_deploy_button():
	"""Update deploy button text to show selected hero and difficulty"""
	if selected_hero_id != "":
		var hero_data = HeroDatabase.get_hero(selected_hero_id)
		if hero_data:
			var difficulty_name = DifficultyConstants.DIFFICULTY_NAMES[selected_difficulty]
			deploy_button.text = "DEPLOY %s (%s)" % [hero_data.hero_name.to_upper(), difficulty_name.to_upper()]

func _populate_heroes():
	# Clear existing
	for child in hero_container.get_children():
		child.queue_free()
		
	# Get unlocked heroes
	var unlocked_heroes = SaveManager.get_unlocked_heroes()
	
	for hero_id in unlocked_heroes:
		var hero_data = HeroDatabase.get_hero(hero_id)
		if not hero_data: continue
		
		var button = Button.new()
		button.text = hero_data.hero_name
		button.custom_minimum_size = Vector2(150, 200)
		button.toggle_mode = true
		button.button_group = load("res://resources/ui/hero_selection_group.tres")
		
		# Add icon if available
		if hero_data.portrait:
			button.icon = hero_data.portrait
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.expand_icon = true
			
		button.pressed.connect(func(): _on_hero_button_pressed(hero_id, hero_data))
		hero_container.add_child(button)
		
	# Auto-select current squad leader if possible
	var current_squad = SaveManager.get_current_squad()
	if not current_squad.is_empty():
		# Find button for this hero and press it
		# (Simplified: just wait for user input)
		pass

func _on_hero_button_pressed(hero_id: String, _data):
	selected_hero_id = hero_id
	deploy_button.disabled = false
	_update_deploy_button()

func _on_deploy_pressed():
	if selected_hero_id == "": return

	# Capture tree reference EARLY, before any state changes potentially remove us from tree
	var tree = get_tree()
	if not tree:
		push_error("[LevelLoadoutScreen] CRITICAL: No SceneTree found at start of deploy!")
		return

	print("[LevelLoadoutScreen] Deploying to %s with %s on %s difficulty" % [
		target_level_id, selected_hero_id, selected_difficulty
	])

	# 1. Update Squad
	print("[LevelLoadoutScreen] Updating squad...")
	SaveManager.set_current_squad([selected_hero_id])

	# 2. Load Level with selected difficulty
	print("[LevelLoadoutScreen] Loading level with difficulty: %s" % selected_difficulty)
	var level_config = LevelManager.get_level_by_id(target_level_id)
	if level_config:
		LevelManager.load_level_config(level_config, null, selected_difficulty)
		
		# MANUAL SCENE CHANGE REQUIRED for separated architecture
		if not level_config.level_scene_path.is_empty():
			print("[LevelLoadoutScreen] Transitioning to scene: %s" % level_config.level_scene_path)
			tree.change_scene_to_file(level_config.level_scene_path)
	else:
		# Fallback to quick_load_level if available
		push_warning("[LevelLoadoutScreen] Could not find level config, using fallback")
		LevelManager.quick_load_level(target_level_id)

	queue_free()
