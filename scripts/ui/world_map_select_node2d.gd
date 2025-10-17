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

var level_node_scene: PackedScene = preload("res://scenes/ui/level_node_2d.tscn")
var level_nodes: Array[LevelNode2D] = []

# Difficulty selection
var selected_level_data: LevelNodeData = null
var difficulty_dialog: AcceptDialog = null

func _ready():
	# Connect signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Setup
	_setup_level_nodes()
	_update_profile_display()
	_update_progress_display()
	_draw_paths()

func _setup_level_nodes():
	# Clear existing nodes
	for node in level_nodes:
		node.queue_free()
	level_nodes.clear()

	# Create level nodes from data
	for level_data in level_nodes_data:
		var level_node = level_node_scene.instantiate() as LevelNode2D
		level_node.level_data = level_data
		level_node.position = level_data.position
		level_node.level_selected.connect(_on_level_node_selected)

		level_nodes_container.add_child(level_node)
		level_nodes.append(level_node)

	# Update all node displays
	for node in level_nodes:
		node.update_display()

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

func _on_level_node_selected(level_data: LevelNodeData):
	print("WorldMapSelect: Level selected: ", level_data.level_name)

	selected_level_data = level_data

	# For now, skip difficulty selector and start level directly
	# TODO: Re-enable difficulty selector later
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
	print("WorldMapSelect: Back to main menu")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# Public method to refresh display (call after completing a level)
func refresh_display():
	_update_progress_display()
	for node in level_nodes:
		node.update_display()
	_draw_paths()
