extends Node2D
class_name WorldMapSelectNode2D

# WorldMapSelect - Kingdom Rush style world map (Node2D version)
# Easier to edit in the editor - just like your level scenes!

signal level_chosen(level_data: LevelNodeData, difficulty: String)

# Export variables for easy configuration in editor
@export var level_nodes_data: Array[LevelNodeData] = []  # All level configurations
@export var map_texture: Texture2D  # Background map image

# Camera bounds for world map (adjust to fit your map art)
@export var map_bounds := Rect2(-200, -200, 2200, 1400)

# STAR COLOR CONSTANTS (Kingdom Rush style)
const STAR_COLORS = {
	3: Color("#FFD700"),  # Gold - 3 stars
	2: Color("#C0C0C0"),  # Silver - 2 stars
	1: Color("#CD7F32"),  # Bronze - 1 star
	0: Color("#404040")   # Gray - Not completed
}

# Star display constants
const STAR_EARNED_COLOR = Color("#FFD700")  # Gold for earned stars
const STAR_UNEARNED_COLOR = Color(0.3, 0.3, 0.3, 0.5)  # Gray for unearned stars
const STAR_SIZE = 10.0  # Size of star polygon (radius) - made bigger
const STAR_SPACING = 25.0  # Horizontal spacing between stars
const STAR_OFFSET_Y = 35.0  # Vertical offset BELOW button (outside the button rectangle)

# References
@onready var camera: Camera2D = $Camera2D
@onready var map_background: Sprite2D = $MapBackground
@onready var level_nodes_container: Node2D = $LevelNodes
@onready var paths_layer: Node2D = $PathsLayer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var top_bar: HBoxContainer = $UILayer/TopBar
@onready var profile_label: Label = $UILayer/TopBar/ProfileLabel
@onready var back_button: Button = $UILayer/TopBar/BackButton
@onready var progress_label: Label = $UILayer/TopBar/ProgressLabel

# Buttons created programmatically
var heroes_button: Button = null
var gear_button: Button = null
var towers_button: Button = null

var level_buttons: Array = []  # Stores visual nodes (Polygon2D) for each level
var level_button_nodes: Array[Node2D] = []  # Store button Node2D containers for zoom compensation

# Difficulty selection
var selected_level_data: LevelNodeData = null
var difficulty_dialog: AcceptDialog = null

# Panels removed - now using standalone scenes instead of overlays

func _ready():
	# Connect signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Create gear button (top-middle) if it doesn't exist
	if not gear_button:
		_create_gear_button()
	else:
		gear_button.pressed.connect(_on_gear_button_pressed)

	# Create heroes button if it doesn't exist
	if not heroes_button:
		_create_heroes_button()
	else:
		heroes_button.pressed.connect(_on_heroes_button_pressed)

	# Create towers button if it doesn't exist
	if not towers_button:
		_create_towers_button()
	else:
		towers_button.pressed.connect(_on_towers_button_pressed)

	# Panel setup removed - using standalone scenes now

	# Setup camera bounds for world map
	_setup_camera_bounds()

	# Setup map background
	_setup_map_background()

	# Setup
	_setup_level_nodes()
	_update_profile_display()
	_update_progress_display()
	_draw_paths()

func _process(_delta):
	"""Update button scales to compensate for camera zoom - keeps buttons constant visual size"""
	if camera and level_button_nodes.size() > 0:
		var inverse_zoom = Vector2.ONE / camera.zoom
		for button_node in level_button_nodes:
			if is_instance_valid(button_node):
				button_node.scale = inverse_zoom

func _get_star_polygon() -> PackedVector2Array:
	"""Create a 5-pointed star polygon shape"""
	var points = PackedVector2Array()
	var outer_radius = STAR_SIZE
	var inner_radius = STAR_SIZE * 0.4  # Inner points are 40% of outer radius

	# Create 5-pointed star (10 points total - 5 outer, 5 inner)
	for i in range(10):
		var angle = deg_to_rad(i * 36.0 - 90.0)  # Start at top (-90 degrees)
		var radius = outer_radius if i % 2 == 0 else inner_radius
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		points.append(Vector2(x, y))

	return points

func _create_star_display(parent: Node2D, stars_earned: int) -> Node2D:
	"""Create star display showing 3 stars (earned in gold, unearned in gray)

	Args:
		parent: The parent Node2D to attach stars to
		stars_earned: Number of stars earned (0-3)

	Returns:
		The container Node2D holding all star polygons
	"""
	# Create container for stars
	var star_container = Node2D.new()
	star_container.name = "StarDisplay"
	star_container.position = Vector2(0, STAR_OFFSET_Y)
	star_container.z_index = 10  # Render on top of everything else

	# Calculate starting X position to center 3 stars
	var total_width = (3 - 1) * STAR_SPACING  # Width of 3 stars with spacing
	var start_x = -total_width / 2.0

	# Create 3 star polygons
	for i in range(3):
		var star = Polygon2D.new()
		star.polygon = _get_star_polygon()
		star.name = "Star%d" % i

		# Color: gold if earned, gray if not
		if i < stars_earned:
			star.color = STAR_EARNED_COLOR
		else:
			star.color = STAR_UNEARNED_COLOR

		# Position horizontally
		star.position = Vector2(start_x + i * STAR_SPACING, 0)

		star_container.add_child(star)

	parent.add_child(star_container)

	# Debug output
	print("  └─ StarDisplay created at position: ", star_container.position, " with z_index: ", star_container.z_index)

	return star_container

func _setup_map_background():
	"""Set the background texture for the world map"""
	if map_background and map_texture:
		map_background.texture = map_texture
		print("[WorldMap] ✅ Background texture set: ", map_texture.resource_path)
	else:
		if not map_texture:
			push_warning("[WorldMap] ⚠️ No map texture assigned - map will be blank")

func _setup_camera_bounds():
	"""Setup camera bounds for the world map"""
	if camera and camera.has_method("set_level_bounds"):
		camera.set_level_bounds(map_bounds)
		print("[WorldMap] ✅ Camera bounds set to:", map_bounds)
	else:
		print("[WorldMap] ⚠️ WARNING: Camera not found or doesn't support set_level_bounds()")

func _create_gear_button():
	"""Create the Gear button programmatically - prominently placed in top-middle"""
	gear_button = Button.new()
	gear_button.name = "GearButton"
	gear_button.text = "⚙ GEAR"
	gear_button.custom_minimum_size = Vector2(160, 50)

	# IMPORTANT: Ensure button can receive clicks
	gear_button.mouse_filter = Control.MOUSE_FILTER_STOP

	gear_button.pressed.connect(_on_gear_button_pressed)

	# Add tooltip
	gear_button.tooltip_text = "Manage equipment and inventory"

	# Add hover effects
	gear_button.mouse_entered.connect(_on_gear_button_hover_enter)
	gear_button.mouse_exited.connect(_on_gear_button_hover_exit)

	# Style the button with theme overrides
	gear_button.add_theme_font_size_override("font_size", 18)

	# Add to top bar - place it prominently
	if top_bar:
		# Create a spacer to push it to center
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Insert spacer after profile label
		top_bar.add_child(spacer)
		top_bar.move_child(spacer, 1)

		# Add gear button after spacer
		top_bar.add_child(gear_button)
		top_bar.move_child(gear_button, 2)

		# Add another spacer to keep it centered
		var spacer2 = Control.new()
		spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_bar.add_child(spacer2)
		top_bar.move_child(spacer2, 3)

	print("✅ Created Gear button")


func _on_gear_button_hover_enter():
	"""Animate gear button on hover"""
	if gear_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(gear_button, "scale", Vector2(1.1, 1.1), 0.2)


func _on_gear_button_hover_exit():
	"""Animate gear button on hover exit"""
	if gear_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(gear_button, "scale", Vector2.ONE, 0.2)


func _create_heroes_button():
	"""Create the Heroes button programmatically if it doesn't exist in scene"""
	heroes_button = Button.new()
	heroes_button.name = "HeroesButton"
	heroes_button.text = "🦸 HEROES"
	heroes_button.custom_minimum_size = Vector2(120, 40)

	# IMPORTANT: Ensure button can receive clicks
	heroes_button.mouse_filter = Control.MOUSE_FILTER_STOP

	heroes_button.pressed.connect(_on_heroes_button_pressed)

	# Add to top bar
	if top_bar:
		# Insert before back button (at the end)
		top_bar.add_child(heroes_button)
		top_bar.move_child(heroes_button, top_bar.get_child_count() - 2)

	print("✅ Created Heroes button")

func _create_towers_button():
	"""Create the Towers button programmatically for tower encyclopedia"""
	towers_button = Button.new()
	towers_button.name = "TowersButton"
	towers_button.text = "🏹 TOWERS"
	towers_button.custom_minimum_size = Vector2(140, 40)

	# IMPORTANT: Ensure button can receive clicks
	towers_button.mouse_filter = Control.MOUSE_FILTER_STOP

	towers_button.pressed.connect(_on_towers_button_pressed)

	# Add to top bar
	if top_bar:
		# Insert before heroes button
		top_bar.add_child(towers_button)
		top_bar.move_child(towers_button, top_bar.get_child_count() - 3)

	print("✅ Created Towers button")

# Arsenal button and screen removed - use Gear and Heroes buttons instead

# Panel setup and overlay management functions removed - using standalone scenes now

func _on_gear_button_pressed():
	"""Navigate to standalone Gear screen"""
	print("⚙️ Opening Gear screen...")
	get_tree().change_scene_to_file("res://scenes/ui/gear_screen_standalone.tscn")


func _on_heroes_button_pressed():
	"""Navigate to standalone Heroes screen"""
	print("🦸 Opening Heroes screen...")
	get_tree().change_scene_to_file("res://scenes/ui/hero_screen_standalone.tscn")

func _on_towers_button_pressed():
	"""Navigate to standalone Tower Codex screen"""
	print("🏹 Opening Tower Codex...")
	get_tree().change_scene_to_file("res://scenes/ui/tower_codex_standalone.tscn")

func _load_ranger_skills() -> Array[HeroSkillData]:
	"""Load all available skills for the ranger hero"""
	var skills: Array[HeroSkillData] = []

	# Create example skills programmatically
	# In full implementation, these would be loaded from .tres resource files

	# ACTIVE SKILL 1: Rapid Fire
	var rapid_fire = HeroSkillData.new()
	rapid_fire.skill_id = "rapid_fire"
	rapid_fire.skill_name = "Rapid Fire"
	rapid_fire.description = "Fire 5 arrows in quick succession at random enemies"
	rapid_fire.skill_type = HeroSkillData.SkillType.ACTIVE
	rapid_fire.unlock_cost = 100
	rapid_fire.max_upgrade_level = 3
	rapid_fire.upgrade_costs.assign([50, 100])  # Level 2, Level 3
	rapid_fire.cooldown = 30.0
	skills.append(rapid_fire)

	# ACTIVE SKILL 2: Power Shot
	var power_shot = HeroSkillData.new()
	power_shot.skill_id = "power_shot"
	power_shot.skill_name = "Power Shot"
	power_shot.description = "Charge up a powerful shot that deals 300% damage and pierces enemies"
	power_shot.skill_type = HeroSkillData.SkillType.ACTIVE
	power_shot.unlock_cost = 150
	power_shot.max_upgrade_level = 3
	power_shot.upgrade_costs.assign([75, 150])  # Level 2, Level 3
	power_shot.cooldown = 45.0
	power_shot.damage_multiplier = 3.0
	skills.append(power_shot)

	# PASSIVE SKILL 1: Eagle Eye
	var eagle_eye = HeroSkillData.new()
	eagle_eye.skill_id = "eagle_eye"
	eagle_eye.skill_name = "Eagle Eye"
	eagle_eye.description = "+20% attack range per level"
	eagle_eye.skill_type = HeroSkillData.SkillType.PASSIVE
	eagle_eye.unlock_cost = 80
	eagle_eye.max_upgrade_level = 5
	eagle_eye.upgrade_costs.assign([40, 80, 120, 160])  # Costs for levels 2-5
	eagle_eye.range_bonus = 60.0
	skills.append(eagle_eye)

	# PASSIVE SKILL 2: Critical Strike
	var crit_strike = HeroSkillData.new()
	crit_strike.skill_id = "critical_strike"
	crit_strike.skill_name = "Critical Strike"
	crit_strike.description = "+5% critical hit chance per level (double damage)"
	crit_strike.skill_type = HeroSkillData.SkillType.PASSIVE
	crit_strike.unlock_cost = 120
	crit_strike.max_upgrade_level = 5
	crit_strike.upgrade_costs.assign([60, 120, 180, 240])  # Costs for levels 2-5
	crit_strike.crit_chance = 0.05  # 5% per level
	skills.append(crit_strike)

	# PASSIVE SKILL 3: Attack Speed
	var attack_speed = HeroSkillData.new()
	attack_speed.skill_id = "attack_speed"
	attack_speed.skill_name = "Quick Draw"
	attack_speed.description = "+10% attack speed per level"
	attack_speed.skill_type = HeroSkillData.SkillType.PASSIVE
	attack_speed.unlock_cost = 100
	attack_speed.max_upgrade_level = 4
	attack_speed.upgrade_costs.assign([50, 100, 150])  # Costs for levels 2-4
	attack_speed.attack_speed_multiplier = 1.1  # 10% per level
	skills.append(attack_speed)

	print("✅ Loaded %d skills for Ranger" % skills.size())

	return skills

# Panel closed handlers removed - no longer needed with standalone scenes
# Arsenal screen removed - functionality consolidated into Gear and Heroes panels

func _setup_level_nodes():
	# Clear existing buttons
	for button in level_buttons:
		button.queue_free()
	level_buttons.clear()

	# Create world-space level buttons (ColorRect + Area2D for proper visibility and clicking)
	for level_data in level_nodes_data:
		# Create container node for this level button
		var button_node = Node2D.new()
		button_node.position = level_data.position
		button_node.name = "LevelButton_" + level_data.level_id

		# Create visual representation using Polygon2D (works in Node2D hierarchy)
		var visual = Polygon2D.new()

		# Define rectangle shape centered at origin
		var rect_points = PackedVector2Array([
			Vector2(-75, -25),   # Top-left
			Vector2(75, -25),    # Top-right
			Vector2(75, 25),     # Bottom-right
			Vector2(-75, 25)     # Bottom-left
		])
		visual.polygon = rect_points

		# Check if level is unlocked
		var is_unlocked = _check_unlock_status(level_data)

		# Get star rating for color
		var stars = SaveManager.get_level_stars(level_data.level_id)
		visual.color = STAR_COLORS.get(stars, STAR_COLORS[0])

		if not is_unlocked:
			visual.modulate = Color(0.3, 0.3, 0.3, 0.7)  # Darken locked levels

		# Add label for level name
		var label = Label.new()
		label.text = level_data.level_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(150, 50)
		label.add_theme_color_override("font_color", Color.WHITE)
		visual.add_child(label)

		# Add star display (Kingdom Rush style)
		var stars_earned = SaveManager.get_level_stars(level_data.level_id)
		_create_star_display(button_node, stars_earned)
		print("⭐ Created star display for %s: %d stars" % [level_data.level_name, stars_earned])

		# Create clickable area
		var area = Area2D.new()
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(150, 50)
		collision.shape = shape
		area.add_child(collision)

		# Connect click signal
		area.input_event.connect(_on_level_area_clicked.bind(level_data, is_unlocked))

		# Assemble the button
		button_node.add_child(visual)
		button_node.add_child(area)
		visual.z_index = 0  # Button background at default layer
		area.z_index = 1  # Clickable area slightly above

		# Store reference for zoom compensation
		level_button_nodes.append(button_node)

		# Apply initial zoom compensation
		if camera:
			button_node.scale = Vector2.ONE / camera.zoom

		# Add to scene
		level_nodes_container.add_child(button_node)
		level_buttons.append(visual)  # Store visual for future updates

		print("Created button for ", level_data.level_name, " at ", level_data.position, " | Unlocked: ", is_unlocked)

func _draw_paths():
	if not paths_layer:
		return

	# Clear previous paths
	for child in paths_layer.get_children():
		child.queue_free()

	# Draw paths between connected levels
	for i in range(level_nodes_data.size()):
		var current_level = level_nodes_data[i]

		# Find the next level (the one that requires this level)
		for j in range(level_nodes_data.size()):
			var next_level = level_nodes_data[j]

			if next_level.required_level_id == current_level.level_id:
				# Draw path from current to next
				_draw_path_between_levels(current_level, next_level)

func _draw_path_between_levels(from_level: LevelNodeData, to_level: LevelNodeData):
	if not paths_layer:
		return

	# Create a Line2D node for the path
	var path_line = Line2D.new()
	path_line.width = 8.0
	path_line.default_color = Color(0.8, 0.6, 0.3, 0.8) if SaveManager.is_level_completed(from_level.level_id) else Color(0.3, 0.3, 0.3, 0.5)
	path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_line.antialiased = true

	var from_pos = from_level.position + Vector2(50, 50)  # Center of node
	var to_pos = to_level.position + Vector2(50, 50)

	# Build the path points
	var points = PackedVector2Array()
	points.append(from_pos)

	# Add custom waypoints if defined
	if from_level.path_to_next_level.size() > 0:
		for point in from_level.path_to_next_level:
			points.append(point)

	points.append(to_pos)

	path_line.points = points
	paths_layer.add_child(path_line)

func _on_level_area_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, level_data: LevelNodeData, is_unlocked: bool):
	"""Handle clicks on level button Area2D nodes"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_unlocked:
			_on_level_button_pressed(level_data)
		else:
			print("🔒 Level locked: ", level_data.level_name)

func _on_level_button_pressed(level_data: LevelNodeData):
	print("🎮 LEVEL BUTTON CLICKED: ", level_data.level_name)
	selected_level_data = level_data
	print("✅ Starting level: ", level_data.level_name)
	_start_level(level_data, level_data.recommended_difficulty)

	# Show difficulty selector if multiple difficulties available
	#if level_data.difficulty_levels.size() > 1:
	#	_show_difficulty_selector(level_data)
	#else:
	#	# Start level with default difficulty
	#	_start_level(level_data, level_data.recommended_difficulty)

func _show_difficulty_selector(level_data: LevelNodeData):
	# Create difficulty selection dialog
	if difficulty_dialog:
		difficulty_dialog.queue_free()

	difficulty_dialog = AcceptDialog.new()
	difficulty_dialog.title = "Select Difficulty"
	difficulty_dialog.dialog_text = "Choose difficulty for " + level_data.level_name + ":"
	difficulty_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN

	# Add difficulty buttons
	var vbox = VBoxContainer.new()

	for difficulty in level_data.difficulty_levels:
		var button = Button.new()
		button.text = difficulty
		button.custom_minimum_size = Vector2(200, 50)
		button.pressed.connect(_on_difficulty_selected.bind(difficulty))
		vbox.add_child(button)

	difficulty_dialog.add_child(vbox)
	add_child(difficulty_dialog)
	difficulty_dialog.popup_centered(Vector2(300, 250))

func _on_difficulty_selected(difficulty: String):
	if difficulty_dialog:
		difficulty_dialog.queue_free()
		difficulty_dialog = null

	if selected_level_data:
		_start_level(selected_level_data, difficulty)

func _start_level(level_data: LevelNodeData, difficulty: String):
	print("WorldMapSelect: Starting level ", level_data.level_name, " on ", difficulty)

	# TODO: Show hero selection screen
	# For now, just start the level directly
	if level_data.level_scene_path.is_empty():
		push_error("WorldMapSelect: Level scene path is empty for ", level_data.level_name)
		return

	# Try to load via LevelManager if level config exists
	var level_config = _get_level_config_for_level_data(level_data)
	if level_config and level_config.level_scene:
		# Use NavigationManager with full config
		NavigationManager.load_level(level_config)
	else:
		# Fallback: Load level config manually and use direct scene navigation
		# This handles cases where level_scene is not set in the .tres file
		if level_config:
			# We have a config but no scene in it - initialize manually
			LevelManager.load_level_config(level_config)

		# Navigate directly to scene
		get_tree().change_scene_to_file(level_data.level_scene_path)
		print("WorldMapSelect: Using direct scene navigation (config.level_scene not set)")

func _get_level_config_for_level_data(level_data: LevelNodeData) -> LevelConfig:
	"""Get the LevelConfig resource for a given LevelNodeData"""
	# Try to load the level config based on level_id
	var config_path = "res://data/level_configs/%s_config.tres" % level_data.level_id
	if ResourceLoader.exists(config_path):
		return load(config_path) as LevelConfig
	return null

func _update_profile_display():
	if not profile_label:
		return

	if SaveManager.has_current_profile():
		var profile_name = SaveManager.get_current_profile_name()
		profile_label.text = "Profile: " + profile_name
	else:
		profile_label.text = "No Profile"

func _update_progress_display():
	if not progress_label:
		return

	# Calculate total stars and completion
	var total_stars = 0
	var max_stars = level_nodes_data.size() * 3
	var completed_levels = 0

	for level_data in level_nodes_data:
		var stars = SaveManager.get_level_stars(level_data.level_id)
		total_stars += stars

		if SaveManager.is_level_completed(level_data.level_id):
			completed_levels += 1

	progress_label.text = "Progress: %d/%d levels | Stars: %d/%d" % [completed_levels, level_nodes_data.size(), total_stars, max_stars]

func _on_back_pressed():
	print("🎮 BACK BUTTON CLICKED!")
	print("✅ Returning to main menu...")
	NavigationManager.go_to_main_menu()

# Public method to refresh display (call after completing a level)
func refresh_display():
	_update_progress_display()
	_setup_level_nodes()
	_draw_paths()

func _check_unlock_status(level_data: LevelNodeData) -> bool:
	if not level_data:
		return false

	# First level is always unlocked
	if level_data.required_level_id.is_empty():
		return true

	# Check if required level is completed
	if not SaveManager.is_level_completed(level_data.required_level_id):
		return false

	# Check star requirements
	if level_data.required_stars > 0:
		var total_stars = SaveManager.get_level_stars(level_data.required_level_id)
		return total_stars >= level_data.required_stars

	return true

func _apply_star_color_to_button(button: Button, level_data: LevelNodeData) -> void:
	"""
	Apply color-coded border to button based on stars earned.
	Gold = 3 stars, Silver = 2 stars, Bronze = 1 star, Gray = not completed
	"""
	# Get stars earned for this level
	var stars = SaveManager.get_level_stars(level_data.level_id)
	var border_color = STAR_COLORS.get(stars, STAR_COLORS[0])

	# Create StyleBoxFlat for the button
	var style_normal = StyleBoxFlat.new()
	var style_hover = StyleBoxFlat.new()
	var style_pressed = StyleBoxFlat.new()
	var style_disabled = StyleBoxFlat.new()

	# NORMAL state
	style_normal.bg_color = Color(0.15, 0.15, 0.15, 0.95)  # Dark background
	style_normal.border_width_left = 4
	style_normal.border_width_right = 4
	style_normal.border_width_top = 4
	style_normal.border_width_bottom = 4
	style_normal.border_color = border_color  # Star-based color!
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.content_margin_left = 10
	style_normal.content_margin_right = 10
	style_normal.content_margin_top = 10
	style_normal.content_margin_bottom = 10

	# HOVER state (brighter border)
	style_hover.bg_color = Color(0.2, 0.2, 0.2, 0.95)
	style_hover.border_width_left = 5
	style_hover.border_width_right = 5
	style_hover.border_width_top = 5
	style_hover.border_width_bottom = 5
	style_hover.border_color = border_color.lightened(0.2)  # Lighter on hover
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8
	style_hover.content_margin_left = 10
	style_hover.content_margin_right = 10
	style_hover.content_margin_top = 10
	style_hover.content_margin_bottom = 10

	# PRESSED state (darker)
	style_pressed.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style_pressed.border_width_left = 4
	style_pressed.border_width_right = 4
	style_pressed.border_width_top = 4
	style_pressed.border_width_bottom = 4
	style_pressed.border_color = border_color.darkened(0.2)  # Darker when pressed
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	style_pressed.corner_radius_bottom_left = 8
	style_pressed.corner_radius_bottom_right = 8
	style_pressed.content_margin_left = 10
	style_pressed.content_margin_right = 10
	style_pressed.content_margin_top = 10
	style_pressed.content_margin_bottom = 10

	# DISABLED state (gray)
	style_disabled.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	style_disabled.border_width_left = 3
	style_disabled.border_width_right = 3
	style_disabled.border_width_top = 3
	style_disabled.border_width_bottom = 3
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.8)  # Locked = dark gray
	style_disabled.corner_radius_top_left = 8
	style_disabled.corner_radius_top_right = 8
	style_disabled.corner_radius_bottom_left = 8
	style_disabled.corner_radius_bottom_right = 8
	style_disabled.content_margin_left = 10
	style_disabled.content_margin_right = 10
	style_disabled.content_margin_top = 10
	style_disabled.content_margin_bottom = 10

	# Apply styles to button
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)

	# Add star text to button (optional visual enhancement)
	if stars > 0:
		var star_text = ""
		for i in range(stars):
			star_text += "★"
		button.text = "%s\n%s" % [level_data.level_name, star_text]
		button.add_theme_color_override("font_color", border_color)
	else:
		button.text = level_data.level_name
		button.add_theme_color_override("font_color", Color.WHITE)
