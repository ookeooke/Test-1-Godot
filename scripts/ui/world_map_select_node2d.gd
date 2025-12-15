extends Node2D
class_name WorldMapSelectNode2D

# WorldMapSelect - Kingdom Rush style world map (Node2D version)
# Easier to edit in the editor - just like your level scenes!

# signal level_chosen(level_data: LevelNodeData, difficulty: String) # Unused

# Export variables for easy configuration in editor
@export var level_nodes_data: Array[LevelNodeData] = [] # All level configurations
@export var map_texture: Texture2D # Background map image

# Camera bounds for world map (adjust to fit your map art)
@export var map_bounds := Rect2(-200, -200, 2200, 1400)

# STAR COLOR CONSTANTS (Kingdom Rush style)
const STAR_COLORS = {
	3: Color("#FFD700"), # Gold - 3 stars
	2: Color("#C0C0C0"), # Silver - 2 stars
	1: Color("#CD7F32"), # Bronze - 1 star
	0: Color("#404040") # Gray - Not completed
}

# Star display constants
const STAR_EARNED_COLOR = Color("#FFD700") # Gold for earned stars
const STAR_UNEARNED_COLOR = Color(0.3, 0.3, 0.3, 0.5) # Gray for unearned stars
const STAR_SIZE = 10.0 # Size of star polygon (radius) - made bigger
const STAR_SPACING = 25.0 # Horizontal spacing between stars
const STAR_OFFSET_Y = 35.0 # Vertical offset BELOW button (outside the button rectangle)

# 5-Star system constants (3 normal + 2 special)
const STAR_HARD_COLOR = Color("#9B30FF") # Purple for hard difficulty
const STAR_UNLIMITED_COLOR = Color("#FFA500") # Orange/Gold for unlimited difficulty
const NORMAL_STAR_SIZE = 10.0 # Size of normal stars
const SPECIAL_STAR_SIZE = 12.0 # Size of special stars (slightly larger)
const SPECIAL_STAR_SPACING = 22.0 # Spacing between special stars
const NORMAL_GROUP_OFFSET_X = -35.0 # X offset for normal stars group
const SPECIAL_GROUP_OFFSET_X = 35.0 # X offset for special stars group

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
var town_button: Button = null

var level_buttons: Array = [] # Stores visual nodes (Polygon2D) for each level
var level_button_nodes: Array[Node2D] = [] # Store button Node2D containers for zoom compensation

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

	# Create town button if it doesn't exist
	if not town_button:
		_create_town_button()
	else:
		town_button.pressed.connect(_on_town_button_pressed)

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

func _get_star_polygon(size: float = STAR_SIZE) -> PackedVector2Array:
	"""Create a 5-pointed star polygon shape with configurable size"""
	var points = PackedVector2Array()
	var outer_radius = size
	var inner_radius = size * 0.4 # Inner points are 40% of outer radius

	# Create 5-pointed star (10 points total - 5 outer, 5 inner)
	for i in range(10):
		var angle = deg_to_rad(i * 36.0 - 90.0) # Start at top (-90 degrees)
		var radius = outer_radius if i % 2 == 0 else inner_radius
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		points.append(Vector2(x, y))

	return points

func _create_star_display(parent: Node2D, level_id: String) -> Node2D:
	"""Create 5-star display (3 normal + 2 special difficulty stars)

	Args:
		parent: The parent Node2D to attach stars to
		level_id: The level ID to query star data from SaveManager

	Returns:
		The container Node2D holding all star polygons
	"""
	# Query star data for all difficulties
	var normal_stars = SaveManager.get_level_stars(level_id, "normal")
	var hard_stars = SaveManager.get_level_stars(level_id, "hard")
	var unlimited_stars = SaveManager.get_level_stars(level_id, "unlimited")

	# Create container for all stars
	var star_container = Node2D.new()
	star_container.name = "StarDisplay"
	star_container.position = Vector2(0, STAR_OFFSET_Y)
	star_container.z_index = 10 # Render on top of everything else

	# === NORMAL STARS GROUP (3 stars, left side) ===
	for i in range(3):
		var star = Polygon2D.new()
		star.polygon = _get_star_polygon(NORMAL_STAR_SIZE)
		star.name = "NormalStar%d" % i

		# Color: gold if earned, gray if not
		if i < normal_stars:
			star.color = STAR_EARNED_COLOR
		else:
			star.color = STAR_UNEARNED_COLOR

		# Position in left group
		star.position = Vector2(NORMAL_GROUP_OFFSET_X + i * STAR_SPACING, 0)
		star_container.add_child(star)

	# === SPECIAL STARS GROUP (2 stars, right side) ===

	# Hard difficulty star (purple)
	var hard_star = Polygon2D.new()
	hard_star.polygon = _get_star_polygon(SPECIAL_STAR_SIZE)
	hard_star.name = "HardStar"
	hard_star.color = STAR_HARD_COLOR if hard_stars > 0 else STAR_UNEARNED_COLOR
	hard_star.position = Vector2(SPECIAL_GROUP_OFFSET_X, 0)
	star_container.add_child(hard_star)

	# Unlimited difficulty star (orange/gold)
	var unlimited_star = Polygon2D.new()
	unlimited_star.polygon = _get_star_polygon(SPECIAL_STAR_SIZE)
	unlimited_star.name = "UnlimitedStar"
	unlimited_star.color = STAR_UNLIMITED_COLOR if unlimited_stars > 0 else STAR_UNEARNED_COLOR
	unlimited_star.position = Vector2(SPECIAL_GROUP_OFFSET_X + SPECIAL_STAR_SPACING, 0)
	star_container.add_child(unlimited_star)

	parent.add_child(star_container)

	# Debug output
	var total_stars = normal_stars
	if hard_stars > 0: total_stars += 1
	if unlimited_stars > 0: total_stars += 1
	print("  └─ StarDisplay created for %s: %d/5 stars (Normal: %d/3, Hard: %d, Unlimited: %d)" % [
		level_id, total_stars, normal_stars, 1 if hard_stars > 0 else 0, 1 if unlimited_stars > 0 else 0
	])

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
	"""Create the Gear button programmatically"""
	gear_button = Button.new()
	gear_button.name = "GearButton"
	# gear_button.text = "⚙ GEAR" # Removed text in favor of icon
	gear_button.custom_minimum_size = Vector2(100, 100) # Increased size again (80 -> 100)

	# Load icon
	var icon_texture = load("res://assets/sprites/map/UI/button_gear.png")
	if icon_texture:
		gear_button.icon = icon_texture
		gear_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gear_button.expand_icon = true
		# Make background transparent to show the nice PNG
		gear_button.flat = true
	else:
		gear_button.text = "⚙ GEAR"

	# IMPORTANT: Ensure button can receive clicks
	gear_button.mouse_filter = Control.MOUSE_FILTER_STOP

	gear_button.pressed.connect(_on_gear_button_pressed)

	# Add tooltip
	gear_button.tooltip_text = "Manage equipment and inventory"

	# Add hover effects
	gear_button.mouse_entered.connect(_on_gear_button_hover_enter)
	gear_button.mouse_exited.connect(_on_gear_button_hover_exit)

	# Add to top bar
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
	"""Create the Heroes button programmatically"""
	heroes_button = Button.new()
	heroes_button.name = "HeroesButton"
	# heroes_button.text = "🦸 HEROES"
	heroes_button.custom_minimum_size = Vector2(100, 100) # Increased size again (80 -> 100)

	# Load icon
	var icon_texture = load("res://assets/sprites/map/UI/button_heroes.png")
	if icon_texture:
		heroes_button.icon = icon_texture
		heroes_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heroes_button.expand_icon = true
		heroes_button.flat = true
	else:
		heroes_button.text = "🦸 HEROES"

	# IMPORTANT: Ensure button can receive clicks
	heroes_button.mouse_filter = Control.MOUSE_FILTER_STOP

	heroes_button.pressed.connect(_on_heroes_button_pressed)

	# Add hover effects (Missing previously!)
	heroes_button.mouse_entered.connect(_on_heroes_button_hover_enter)
	heroes_button.mouse_exited.connect(_on_heroes_button_hover_exit)

	# Add to top bar
	if top_bar:
		# Insert before back button (at the end)
		top_bar.add_child(heroes_button)
		top_bar.move_child(heroes_button, top_bar.get_child_count() - 2)

	print("✅ Created Heroes button")

func _on_heroes_button_hover_enter():
	"""Animate heroes button on hover"""
	if heroes_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(heroes_button, "scale", Vector2(1.1, 1.1), 0.2)

func _on_heroes_button_hover_exit():
	"""Animate heroes button on hover exit"""
	if heroes_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(heroes_button, "scale", Vector2.ONE, 0.2)

func _create_towers_button():
	"""Create the Towers button programmatically"""
	towers_button = Button.new()
	towers_button.name = "TowersButton"
	# towers_button.text = "🏹 TOWERS"
	towers_button.custom_minimum_size = Vector2(100, 100) # Increased size again (80 -> 100)

	# Load icon
	var icon_texture = load("res://assets/sprites/map/UI/button_towers.png")
	if icon_texture:
		towers_button.icon = icon_texture
		towers_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		towers_button.expand_icon = true
		towers_button.flat = true
	else:
		towers_button.text = "🏹 TOWERS"

	# IMPORTANT: Ensure button can receive clicks
	towers_button.mouse_filter = Control.MOUSE_FILTER_STOP

	towers_button.pressed.connect(_on_towers_button_pressed)

	# Add hover effects (Missing previously!)
	towers_button.mouse_entered.connect(_on_towers_button_hover_enter)
	towers_button.mouse_exited.connect(_on_towers_button_hover_exit)

	# Add to top bar
	if top_bar:
		# Insert before heroes button
		top_bar.add_child(towers_button)
		top_bar.move_child(towers_button, top_bar.get_child_count() - 3)

	print("✅ Created Towers button")

func _on_towers_button_hover_enter():
	"""Animate towers button on hover"""
	if towers_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(towers_button, "scale", Vector2(1.1, 1.1), 0.2)

func _on_towers_button_hover_exit():
	"""Animate towers button on hover exit"""
	if towers_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(towers_button, "scale", Vector2.ONE, 0.2)

func _create_town_button():
	"""Create the Town button programmatically"""
	town_button = Button.new()
	town_button.name = "TownButton"
	# town_button.text = "🏠 TOWN"
	town_button.custom_minimum_size = Vector2(100, 100) # Increased size again (80 -> 100)

	# Load icon
	var icon_texture = load("res://assets/sprites/map/UI/button_village.png")
	if icon_texture:
		town_button.icon = icon_texture
		town_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		town_button.expand_icon = true
		town_button.flat = true
	else:
		town_button.text = "🏠 TOWN"

	# IMPORTANT: Ensure button can receive clicks
	town_button.mouse_filter = Control.MOUSE_FILTER_STOP

	town_button.pressed.connect(_on_town_button_pressed)
	
	# Add hover effects
	town_button.mouse_entered.connect(_on_town_button_hover_enter)
	town_button.mouse_exited.connect(_on_town_button_hover_exit)

	# Add to top bar
	if top_bar:
		# Insert at the beginning (before gear/spacers) or after towers?
		# Let's put it at the start for visibility
		top_bar.add_child(town_button)
		top_bar.move_child(town_button, 0)

	print("✅ Created Town button")

func _on_town_button_pressed():
	print("🏠 Town button clicked (Placeholder)")
	# Show a simple popup or floating text
	var label = Label.new()
	label.text = "Town Coming Soon!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Add to UI layer
	if ui_layer:
		ui_layer.add_child(label)
		label.global_position = town_button.global_position + Vector2(0, 60)
		
		# Animate
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y - 50, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
		tween.tween_callback(label.queue_free)

func _on_town_button_hover_enter():
	if town_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(town_button, "scale", Vector2(1.1, 1.1), 0.2)

func _on_town_button_hover_exit():
	if town_button:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(town_button, "scale", Vector2.ONE, 0.2)

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
	"""Navigate to standalone Towers screen (Codex + Loadout)"""
	print("🏹 Opening Towers screen...")
	get_tree().change_scene_to_file("res://scenes/ui/towers_screen_standalone.tscn")

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
	rapid_fire.upgrade_costs.assign([50, 100]) # Level 2, Level 3
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
	power_shot.upgrade_costs.assign([75, 150]) # Level 2, Level 3
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
	eagle_eye.upgrade_costs.assign([40, 80, 120, 160]) # Costs for levels 2-5
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
	crit_strike.upgrade_costs.assign([60, 120, 180, 240]) # Costs for levels 2-5
	crit_strike.crit_chance = 0.05 # 5% per level
	skills.append(crit_strike)

	# PASSIVE SKILL 3: Attack Speed
	var attack_speed = HeroSkillData.new()
	attack_speed.skill_id = "attack_speed"
	attack_speed.skill_name = "Quick Draw"
	attack_speed.description = "+10% attack speed per level"
	attack_speed.skill_type = HeroSkillData.SkillType.PASSIVE
	attack_speed.unlock_cost = 100
	attack_speed.max_upgrade_level = 4
	attack_speed.upgrade_costs.assign([50, 100, 150]) # Costs for levels 2-4
	attack_speed.attack_speed_multiplier = 1.1 # 10% per level
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
	level_button_nodes.clear() # Clear zoom compensation array too

	# Create world-space level buttons with professional styling
	for level_data in level_nodes_data:
		# Create container node for this level button
		var button_node = Node2D.new()
		button_node.position = level_data.position
		button_node.name = "LevelButton_" + level_data.level_id

		# Check if level is unlocked
		var is_unlocked = _check_unlock_status(level_data)

		# Get star rating
		var stars = SaveManager.get_level_stars(level_data.level_id)

		# Create styled Button (UI element in world space)
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 50)
		button.text = level_data.level_name
		button.position = Vector2(-75, -25) # Center in parent Node2D
		button.disabled = not is_unlocked # Disable if locked

		# Apply professional styling based on stars
		var style_normal = _create_level_button_style(stars, is_unlocked, "normal")
		var style_hover = _create_level_button_style(stars, is_unlocked, "hover")
		var style_pressed = _create_level_button_style(stars, is_unlocked, "pressed")
		var style_disabled = _create_level_button_style(stars, is_unlocked, "disabled")

		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_stylebox_override("disabled", style_disabled)

		# Font styling
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_constant_override("outline_size", 2)
		button.add_theme_color_override("font_outline_color", Color.BLACK)

		# Connect click signal
		if is_unlocked:
			button.pressed.connect(_on_level_button_pressed.bind(level_data))

		# Add glow effect for unlocked levels (optional)
		if is_unlocked and stars > 0:
			button.material = _create_glow_material(STAR_COLORS.get(stars))

		# Add button to container
		button_node.add_child(button)

		# Add 5-star display (3 normal + 2 special difficulty stars)
		_create_star_display(button_node, level_data.level_id)
		# print("⭐ Created star display for %s" % level_data.level_name)

		# Store reference for zoom compensation
		level_button_nodes.append(button_node)

		# Apply initial zoom compensation
		if camera:
			button_node.scale = Vector2.ONE / camera.zoom

		# Add to scene
		level_nodes_container.add_child(button_node)
		level_buttons.append(button) # Store button for future updates

		# print("Created button for ", level_data.level_name, " at ", level_data.position, " | Unlocked: ", is_unlocked, " | Stars: ", stars)

func _create_level_button_style(stars: int, is_unlocked: bool, state: String) -> StyleBoxFlat:
	"""Create a professional StyleBoxFlat for level buttons with shadows, borders, and colors"""
	var style = StyleBoxFlat.new()
	var base_color = STAR_COLORS.get(stars, STAR_COLORS[0])

	# Background - dark with subtle tint of star color
	var bg_color = Color(0.08, 0.08, 0.12, 0.95)
	if is_unlocked:
		bg_color = bg_color.lerp(base_color, 0.08) # Subtle tint for unlocked levels
	style.bg_color = bg_color

	# Border - thicker and colored by stars
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 6 # Thicker bottom for 3D effect

	# Apply state-specific styling
	match state:
		"normal":
			style.border_color = base_color
		"hover":
			style.border_color = base_color.lightened(0.3)
			style.border_width_left = 5
			style.border_width_top = 5
			style.border_width_right = 5
			style.border_width_bottom = 7
			style.bg_color = bg_color.lightened(0.1)
		"pressed":
			style.border_color = base_color.darkened(0.2)
			style.bg_color = bg_color.darkened(0.15)
			# Pressed appears "pushed in" - thinner bottom border
			style.border_width_bottom = 4
		"disabled":
			# Locked levels - gray and darkened
			style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
			style.border_color = Color(0.3, 0.3, 0.3, 0.8)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 5

	# Rounded corners for modern look
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# Shadow effect (adds depth)
	if is_unlocked:
		style.shadow_size = 4
		style.shadow_color = Color(0, 0, 0, 0.7)
		style.shadow_offset = Vector2(2, 3)
	else:
		# Locked levels have minimal shadow
		style.shadow_size = 2
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_offset = Vector2(1, 2)

	# Padding for text
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	return style

func _create_glow_material(glow_color: Color) -> ShaderMaterial:
	"""Create a subtle glow shader effect for unlocked level buttons"""
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float glow_size : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Sample nearby pixels for glow
	float glow = 0.0;
	for(float x = -glow_size; x <= glow_size; x += glow_size/3.0) {
		for(float y = -glow_size; y <= glow_size; y += glow_size/3.0) {
			glow += texture(TEXTURE, UV + vec2(x, y)).a;
		}
	}
	glow = smoothstep(0.0, 1.0, glow * 0.05) * glow_intensity;

	COLOR = mix(color, vec4(glow_color.rgb, 1.0), glow * (1.0 - color.a));
	COLOR.a = max(color.a, glow);
}
"""

	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("glow_color", glow_color)
	mat.set_shader_parameter("glow_intensity", 0.4) # Subtle glow
	mat.set_shader_parameter("glow_size", 0.012)

	return mat

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

	var from_pos = from_level.position + Vector2(50, 50) # Center of node
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

func _start_level(level_data: LevelNodeData, _difficulty: String):
	print("WorldMapSelect: Opening Loadout for ", level_data.level_name)

	# Instantiate Level Loadout Screen
	var loadout_scene = load("res://scenes/ui/level_loadout_screen.tscn")
	if loadout_scene:
		var loadout_screen = loadout_scene.instantiate()
		ui_layer.add_child(loadout_screen)
		loadout_screen.setup(level_data.level_id)
		
		# Handle back button from loadout
		loadout_screen.back_pressed.connect(func():
			print("Back from loadout")
		)
	else:
		push_error("Failed to load LevelLoadoutScreen scene!")
		# Fallback to direct load
		_direct_load_level(level_data)

func _direct_load_level(level_data: LevelNodeData):
	# Fallback: Load level config manually and use direct scene navigation
	var level_config = _get_level_config_for_level_data(level_data)
	if level_config and level_config.level_scene:
		NavigationManager.load_level(level_config)
	else:
		if level_config:
			LevelManager.load_level_config(level_config)
		get_tree().change_scene_to_file(level_data.level_scene_path)

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
	style_normal.bg_color = Color(0.15, 0.15, 0.15, 0.95) # Dark background
	style_normal.border_width_left = 4
	style_normal.border_width_right = 4
	style_normal.border_width_top = 4
	style_normal.border_width_bottom = 4
	style_normal.border_color = border_color # Star-based color!
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
	style_hover.border_color = border_color.lightened(0.2) # Lighter on hover
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
	style_pressed.border_color = border_color.darkened(0.2) # Darker when pressed
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
	style_disabled.border_color = Color(0.3, 0.3, 0.3, 0.8) # Locked = dark gray
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
