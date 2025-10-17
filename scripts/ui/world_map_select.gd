extends Control
class_name WorldMapSelect

# WorldMapSelect - Kingdom Rush style world map with all campaigns and levels
# Features: scrollable map, animated level nodes, path connections, campaign progress

signal level_chosen(level_data: LevelNodeData, difficulty: String)

# Export variables for easy configuration in editor
@export var map_texture: Texture2D  # Background map image
@export var level_nodes_data: Array[LevelNodeData] = []  # All level configurations

# UI References
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var map_background: TextureRect = $ScrollContainer/MapContainer/MapBackground
@onready var level_nodes_container: Control = $ScrollContainer/MapContainer/LevelNodesContainer
@onready var paths_canvas: Control = $ScrollContainer/MapContainer/PathsCanvas
@onready var top_bar: HBoxContainer = $TopBar
@onready var profile_label: Label = $TopBar/ProfileLabel
@onready var back_button: Button = $TopBar/BackButton
@onready var progress_label: Label = $TopBar/ProgressLabel

# Camera/Scrolling
@onready var map_container: Control = $ScrollContainer/MapContainer

var level_node_scene: PackedScene = preload("res://scenes/ui/level_node.tscn")
var level_nodes: Array[LevelNode] = []

# Difficulty selection
var selected_level_data: LevelNodeData = null
var difficulty_dialog: AcceptDialog = null

# Panning/dragging
var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var scroll_start_h: float = 0.0
var scroll_start_v: float = 0.0

func _ready():
	# Connect signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Setup map
	_setup_map_background()
	_setup_level_nodes()
	_update_profile_display()
	_update_progress_display()

	# Enable panning
	_setup_panning()

func _setup_map_background():
	if map_background and map_texture:
		map_background.texture = map_texture
		# Set the map container size to the texture size
		if map_container:
			map_container.custom_minimum_size = map_texture.get_size()
			map_background.custom_minimum_size = map_texture.get_size()

func _setup_level_nodes():
	# Clear existing nodes
	for node in level_nodes:
		node.queue_free()
	level_nodes.clear()

	# Create level nodes from data
	for level_data in level_nodes_data:
		var level_node = level_node_scene.instantiate() as LevelNode
		level_node.level_data = level_data
		level_node.position = level_data.position
		level_node.level_selected.connect(_on_level_node_selected)

		level_nodes_container.add_child(level_node)
		level_nodes.append(level_node)

	# Draw paths between levels
	_draw_level_paths()

	# Update all node displays
	for node in level_nodes:
		node.update_display()

func _draw_level_paths():
	if not paths_canvas:
		return

	# Clear previous paths
	paths_canvas.queue_redraw()

	# We'll use _draw callback
	if not paths_canvas.is_connected("draw", _on_paths_canvas_draw):
		paths_canvas.draw.connect(_on_paths_canvas_draw)

	paths_canvas.queue_redraw()

func _on_paths_canvas_draw():
	if not paths_canvas:
		return

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
	if not paths_canvas:
		return

	var from_pos = from_level.position + Vector2(50, 50)  # Center of node (assuming 100x100 node)
	var to_pos = to_level.position + Vector2(50, 50)

	# Check if the path to next level has custom points
	if from_level.path_to_next_level.size() > 0:
		# Draw curved path through custom points
		var points = PackedVector2Array()
		points.append(from_pos)
		for point in from_level.path_to_next_level:
			points.append(point)
		points.append(to_pos)

		# Draw the path as connected lines
		for i in range(points.size() - 1):
			var start = points[i]
			var end = points[i + 1]

			# Determine color based on unlock status
			var is_unlocked = SaveManager.is_level_completed(from_level.level_id)
			var path_color = Color(0.8, 0.6, 0.3, 0.8) if is_unlocked else Color(0.3, 0.3, 0.3, 0.5)

			paths_canvas.draw_line(start, end, path_color, 5.0)
	else:
		# Simple direct line
		var is_unlocked = SaveManager.is_level_completed(from_level.level_id)
		var path_color = Color(0.8, 0.6, 0.3, 0.8) if is_unlocked else Color(0.3, 0.3, 0.3, 0.5)

		paths_canvas.draw_line(from_pos, to_pos, path_color, 5.0)

func _setup_panning():
	# Enable mouse panning for large maps
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_container_input)

func _on_scroll_container_input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		# Middle mouse button or right click for panning
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				is_panning = true
				pan_start_pos = mouse_event.position
				scroll_start_h = scroll_container.scroll_horizontal
				scroll_start_v = scroll_container.scroll_vertical
			else:
				is_panning = false

	elif event is InputEventMouseMotion and is_panning:
		var mouse_motion = event as InputEventMouseMotion
		var delta = pan_start_pos - mouse_motion.position

		scroll_container.scroll_horizontal = int(scroll_start_h + delta.x)
		scroll_container.scroll_vertical = int(scroll_start_v + delta.y)

func _on_level_node_selected(level_data: LevelNodeData):
	print("WorldMapSelect: Level selected: ", level_data.level_name)

	selected_level_data = level_data

	# Show difficulty selector if multiple difficulties available
	if level_data.difficulty_levels.size() > 1:
		_show_difficulty_selector(level_data)
	else:
		# Start level with default difficulty
		_start_level(level_data, level_data.recommended_difficulty)

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
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	for difficulty in level_data.difficulty_levels:
		var button = Button.new()
		button.text = difficulty
		button.pressed.connect(_on_difficulty_selected.bind(difficulty))
		vbox.add_child(button)

	difficulty_dialog.add_child(vbox)
	add_child(difficulty_dialog)
	difficulty_dialog.popup_centered(Vector2(300, 200))

func _on_difficulty_selected(difficulty: String):
	if difficulty_dialog:
		difficulty_dialog.queue_free()
		difficulty_dialog = null

	if selected_level_data:
		_start_level(selected_level_data, difficulty)

func _start_level(level_data: LevelNodeData, difficulty: String):
	print("WorldMapSelect: Starting level ", level_data.level_name, " on ", difficulty)

	# Emit signal for potential hero selection or just load level
	# For now, we'll show hero selection screen before loading level
	_show_hero_selection(level_data, difficulty)

func _show_hero_selection(level_data: LevelNodeData, difficulty: String):
	# TODO: Implement hero selection screen
	# For now, just start the level directly
	print("WorldMapSelect: Hero selection not implemented yet, starting level directly")

	# Load the level scene
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
	paths_canvas.queue_redraw()
