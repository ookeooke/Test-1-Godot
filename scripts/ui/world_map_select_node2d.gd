extends Node2D
class_name WorldMapSelectNode2D

# WorldMapSelect - Kingdom Rush style world map (Node2D version)
# Easier to edit in the editor - just like your level scenes!

signal level_chosen(level_data: LevelNodeData, difficulty: String)

# Export variables for easy configuration in editor
@export var level_nodes_data: Array[LevelNodeData] = []  # All level configurations

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
var arsenal_button: Button = null

var level_buttons: Array[Button] = []

# Difficulty selection
var selected_level_data: LevelNodeData = null
var difficulty_dialog: AcceptDialog = null

# Hero management panel
var hero_management_panel: HeroManagementPanel = null

# Dual panel screen (gear management)
var dual_panel_screen: DualPanelScreen = null

# Arsenal screen
var arsenal_screen: ArsenalScreen = null

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

	# Create arsenal button if it doesn't exist
	if not arsenal_button:
		_create_arsenal_button()
	else:
		arsenal_button.pressed.connect(_on_arsenal_button_pressed)

	# Create hero management panel
	_setup_hero_management_panel()

	# Create dual panel screen
	_setup_dual_panel_screen()

	# Create arsenal screen
	_setup_arsenal_screen()

	# Setup
	_setup_level_nodes()
	_update_profile_display()
	_update_progress_display()
	_draw_paths()

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

func _create_arsenal_button():
	"""Create the Arsenal button programmatically"""
	arsenal_button = Button.new()
	arsenal_button.name = "ArsenalButton"
	arsenal_button.text = "⚔ ARSENAL"
	arsenal_button.custom_minimum_size = Vector2(140, 40)

	# IMPORTANT: Ensure button can receive clicks
	arsenal_button.mouse_filter = Control.MOUSE_FILTER_STOP

	arsenal_button.pressed.connect(_on_arsenal_button_pressed)

	# Add tooltip
	arsenal_button.tooltip_text = "Manage heroes, equipment, and loadouts"

	# Add to top bar (before progress label)
	if top_bar:
		top_bar.add_child(arsenal_button)
		top_bar.move_child(arsenal_button, top_bar.get_child_count() - 2)

	print("✅ Created Arsenal button")

func _setup_dual_panel_screen():
	"""Create the dual panel screen for gear management"""
	# Load the dual panel screen scene
	var panel_scene = load("res://scenes/ui/dual_panel_screen.tscn")
	if panel_scene:
		dual_panel_screen = panel_scene.instantiate()
		ui_layer.add_child(dual_panel_screen)

		# IMPORTANT: Ensure it's hidden on start
		dual_panel_screen.visible = false
		dual_panel_screen.hide()

		# Set hero ID
		dual_panel_screen.set_hero_id("ranger")

		# Connect signals
		dual_panel_screen.screen_closed.connect(_on_gear_screen_closed)

		print("✅ Dual panel screen created (hidden)")
	else:
		push_error("Failed to load dual panel screen scene")


func _setup_hero_management_panel():
	"""Create the hero management panel"""
	# Load the hero management panel scene
	var panel_scene = load("res://scenes/ui/hero_management_panel.tscn")
	if panel_scene:
		hero_management_panel = panel_scene.instantiate()
		ui_layer.add_child(hero_management_panel)
		hero_management_panel.hide()

		# Connect signals
		hero_management_panel.closed.connect(_on_hero_panel_closed)
		hero_management_panel.skill_purchased.connect(_on_skill_purchased)
		hero_management_panel.skill_upgraded.connect(_on_skill_upgraded)

		print("✅ Hero management panel created")
	else:
		push_error("Failed to load hero management panel scene")

func _on_gear_button_pressed():
	"""Open the gear management screen (dual panel)"""
	print("🎮 GEAR BUTTON CLICKED!")

	if not dual_panel_screen:
		push_error("❌ Dual panel screen not initialized")
		return

	print("✅ Opening dual panel screen...")

	# Button press animation
	if gear_button:
		var press_tween = create_tween()
		press_tween.tween_property(gear_button, "scale", Vector2(0.95, 0.95), 0.05)
		press_tween.tween_property(gear_button, "scale", Vector2.ONE, 0.1)

	# Open the screen
	dual_panel_screen.show_screen()


func _on_gear_screen_closed():
	"""Called when gear screen is closed"""
	# Refresh display in case items were equipped
	_update_progress_display()


func _on_heroes_button_pressed():
	"""Open the hero management panel"""
	print("🎮 HEROES BUTTON CLICKED!")

	if not hero_management_panel:
		push_error("❌ Hero management panel not initialized")
		return

	print("✅ Opening hero management panel...")

	# Load ranger hero skills
	var ranger_skills = _load_ranger_skills()

	# Open panel
	hero_management_panel.open_panel("ranger", ranger_skills)

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

func _on_hero_panel_closed():
	"""Called when hero management panel is closed"""
	# Refresh display in case skills were purchased
	_update_progress_display()

func _on_skill_purchased(hero_id: String, skill_id: String):
	"""Called when a skill is purchased"""
	print("💫 Skill purchased: ", skill_id, " for ", hero_id)

func _on_skill_upgraded(hero_id: String, skill_id: String):
	"""Called when a skill is upgraded"""
	print("⬆️ Skill upgraded: ", skill_id, " for ", hero_id)

func _setup_arsenal_screen():
	"""Create and setup the arsenal screen"""
	arsenal_screen = ArsenalScreen.new()
	arsenal_screen.name = "ArsenalScreen"
	ui_layer.add_child(arsenal_screen)

	# Connect close signal to update displays
	arsenal_screen.closed.connect(_on_arsenal_closed)

	print("✅ Arsenal screen initialized")

func _on_arsenal_button_pressed():
	"""Open the arsenal screen"""
	print("🎮 ARSENAL BUTTON CLICKED!")

	if not arsenal_screen:
		push_error("❌ Arsenal screen not initialized")
		return

	print("✅ Opening Arsenal screen...")

	# Button press animation
	if arsenal_button:
		var press_tween = create_tween()
		press_tween.tween_property(arsenal_button, "scale", Vector2(0.95, 0.95), 0.05)
		press_tween.tween_property(arsenal_button, "scale", Vector2.ONE, 0.1)

	# Open the screen
	arsenal_screen.show_screen()

func _on_arsenal_closed():
	"""Handle arsenal screen closing"""
	# Refresh displays in case equipment/heroes changed
	_update_profile_display()
	_update_progress_display()
	print("✅ Arsenal closed, displays refreshed")

func _setup_level_nodes():
	# Clear existing buttons
	for button in level_buttons:
		button.queue_free()
	level_buttons.clear()

	# Create simple buttons for each level
	for level_data in level_nodes_data:
		# Create a simple Button control
		var button = Button.new()
		button.text = level_data.level_name
		button.custom_minimum_size = Vector2(150, 50)
		button.position = level_data.position

		# IMPORTANT: Ensure button can receive clicks
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		# Check if level is unlocked
		var is_unlocked = _check_unlock_status(level_data)
		button.disabled = not is_unlocked

		# Connect the pressed signal
		button.pressed.connect(_on_level_button_pressed.bind(level_data))

		# Add to scene
		level_nodes_container.add_child(button)
		level_buttons.append(button)

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

	get_tree().change_scene_to_file(level_data.level_scene_path)

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
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

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
