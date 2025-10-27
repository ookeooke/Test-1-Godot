extends Control

# ============================================
# TOWER CODEX MENU - Encyclopedia of all towers
# ============================================
# Shows detailed information about all towers:
# - Stats at each level
# - Upgrade costs
# - Path choices
# - Total upgrade costs

signal codex_closed

# Current display state
var current_tower_id: String = "archer"

# Node references
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/CloseButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TopBar/CloseButton") else null
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/BackButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TopBar/BackButton") else null
@onready var tower_name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TopBar/TowerNameLabel
@onready var tower_selector_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ContentHBox/TowerSelector/ScrollContainer/TowerList
@onready var stats_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ContentHBox/StatsPanel/StatsContainer
@onready var description_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ContentHBox/StatsPanel/StatsContainer/DescriptionPanel/DescriptionLabel

# Tower selector buttons
var tower_buttons: Dictionary = {}  # tower_id -> Button

func _ready():
	# Connect signals
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	# Create tower selector buttons
	_create_tower_selector_buttons()

	# Display first tower
	_display_tower(current_tower_id)

func _create_tower_selector_buttons():
	"""Create buttons for each tower in the selector"""
	var tower_ids = TowerData.get_all_tower_ids()

	for tower_id in tower_ids:
		var button = Button.new()
		button.name = tower_id + "_button"
		button.custom_minimum_size = Vector2(180, 60)

		# Button text with icon and name
		var icon = TowerData.get_tower_icon(tower_id)
		var tower_name = TowerData.get_tower_name(tower_id)
		var cost = TowerData.get_build_cost(tower_id)
		button.text = "%s %s\n%dg" % [icon, tower_name, cost]

		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_tower_button_pressed.bind(tower_id))

		tower_selector_container.add_child(button)
		tower_buttons[tower_id] = button

	print("[TowerCodex] Created %d tower selector buttons" % tower_ids.size())

func _on_tower_button_pressed(tower_id: String):
	"""Handle tower selector button click"""
	print("[TowerCodex] Tower selected: %s" % tower_id)
	current_tower_id = tower_id
	_display_tower(tower_id)
	_update_button_states()

func _display_tower(tower_id: String):
	"""Display complete information for a tower"""
	print("[TowerCodex] Displaying tower: %s" % tower_id)

	var tower_data = TowerData.get_tower_data(tower_id)
	if tower_data.is_empty():
		push_error("[TowerCodex] Tower data not found: %s" % tower_id)
		return

	# Update header
	var icon = tower_data.get("icon", "❓")
	var tower_name = tower_data.get("name", "Unknown")
	var cost = tower_data.get("build_cost", 0)
	var tower_type = tower_data.get("type", "unknown")

	tower_name_label.text = "%s %s - %dg (%s)" % [icon, tower_name, cost, tower_type]

	# Update description
	if description_label:
		description_label.text = tower_data.get("description", "")

	# Clear previous stats display
	for child in stats_container.get_children():
		if child != description_label.get_parent():  # Keep description panel
			child.queue_free()

	# Display stats based on tower type
	if tower_type == "ranged_single" or tower_type == "ranged_aoe":
		_display_ranged_tower_stats(tower_id, tower_data)
	elif tower_type == "garrison":
		_display_garrison_tower_stats(tower_id, tower_data)
	else:
		_display_generic_tower_stats(tower_id, tower_data)

func _display_ranged_tower_stats(tower_id: String, tower_data: Dictionary):
	"""Display stats for ranged towers (archer, mage, etc)"""
	var levels = tower_data.get("levels", {})

	# Title
	var title = Label.new()
	title.text = "UPGRADE PROGRESSION"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	stats_container.add_child(title)

	# Display each level
	for level in range(1, 6):  # Levels 1-5
		if not levels.has(level):
			continue

		var level_data = levels[level]

		# Check if this level has path choices
		if level_data.has("damage_path"):
			# Path choice level - show both paths
			_add_path_choice_display(level, level_data)
		else:
			# Normal level - show stats
			_add_level_display(level, level_data)

func _add_level_display(level: int, stats: Dictionary):
	"""Add display for a single tower level"""
	var level_panel = PanelContainer.new()
	level_panel.custom_minimum_size = Vector2(0, 80)

	var vbox = VBoxContainer.new()
	level_panel.add_child(vbox)

	# Level header
	var header = Label.new()
	var cost_text = ""
	if stats.get("cost_to_next", 0) > 0:
		cost_text = " → %dg →" % stats.cost_to_next
	header.text = "LEVEL %d%s" % [level, cost_text]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	vbox.add_child(header)

	# Stats
	var stats_label = Label.new()
	var stats_text = ""

	if stats.has("damage"):
		stats_text += "Damage: %d | " % stats.damage
	if stats.has("attack_speed"):
		stats_text += "Attack Speed: %.1f/s | " % stats.attack_speed
	if stats.has("range"):
		stats_text += "Range: %d" % stats.range
	if stats.has("dps"):
		stats_text += "\nDPS: %.1f" % stats.dps

	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stats_label)

	stats_container.add_child(level_panel)

func _add_path_choice_display(level: int, level_data: Dictionary):
	"""Add display for path choice levels (Level 4+)"""
	# Add "CHOOSE PATH" label
	var choice_label = Label.new()
	choice_label.text = "─── CHOOSE SPECIALIZATION PATH ───"
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.add_theme_font_size_override("font_size", 14)
	choice_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	stats_container.add_child(choice_label)

	# Horizontal container for both paths
	var paths_hbox = HBoxContainer.new()
	paths_hbox.add_theme_constant_override("separation", 20)

	# Damage path
	if level_data.has("damage_path"):
		var damage_panel = _create_path_panel("🔥 DAMAGE PATH", level, level_data.damage_path, Color(1.0, 0.5, 0.3))
		paths_hbox.add_child(damage_panel)

	# Range path
	if level_data.has("range_path"):
		var range_panel = _create_path_panel("🎯 RANGE PATH", level, level_data.range_path, Color(0.3, 0.7, 1.0))
		paths_hbox.add_child(range_panel)

	stats_container.add_child(paths_hbox)

func _create_path_panel(path_title: String, level: int, stats: Dictionary, color: Color) -> PanelContainer:
	"""Create a panel showing one path choice"""
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(250, 120)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Path name
	var title_label = Label.new()
	title_label.text = path_title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", color)
	vbox.add_child(title_label)

	# Level
	var level_label = Label.new()
	var cost = stats.get("cost_to_next", 0)
	var cost_text = " (%dg)" % cost if cost > 0 else " (MAX)"
	level_label.text = "Level %d%s" % [level, cost_text]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(level_label)

	# Path name subtitle
	if stats.has("path_name"):
		var subtitle = Label.new()
		subtitle.text = stats.path_name
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 10)
		subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(subtitle)

	# Stats
	var stats_label = Label.new()
	var stats_text = ""

	if stats.has("damage"):
		stats_text += "DMG: %d\n" % stats.damage
	if stats.has("attack_speed"):
		stats_text += "AS: %.1f/s\n" % stats.attack_speed
	if stats.has("range"):
		stats_text += "RNG: %d\n" % stats.range
	if stats.has("dps"):
		stats_text += "DPS: %.1f" % stats.dps

	stats_label.text = stats_text
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(stats_label)

	return panel

func _display_garrison_tower_stats(tower_id: String, tower_data: Dictionary):
	"""Display stats for garrison towers (barracks)"""
	var levels = tower_data.get("levels", {})

	# Title
	var title = Label.new()
	title.text = "GARRISON UPGRADES"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	stats_container.add_child(title)

	# Display each level
	for level in range(1, 10):  # Up to 10 levels for garrison
		if not levels.has(level):
			break

		var stats = levels[level]
		_add_garrison_level_display(level, stats)

func _add_garrison_level_display(level: int, stats: Dictionary):
	"""Add display for garrison level"""
	var level_panel = PanelContainer.new()
	level_panel.custom_minimum_size = Vector2(0, 100)

	var vbox = VBoxContainer.new()
	level_panel.add_child(vbox)

	# Level header
	var header = Label.new()
	var cost_text = ""
	if stats.get("cost_to_next", 0) > 0:
		cost_text = " → %dg →" % stats.cost_to_next
	header.text = "LEVEL %d%s" % [level, cost_text]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	vbox.add_child(header)

	# Soldier stats
	var stats_label = Label.new()
	var stats_text = ""

	if stats.has("soldier_count"):
		stats_text += "Soldiers: %d\n" % stats.soldier_count
	if stats.has("soldier_health"):
		stats_text += "Health: %d | " % stats.soldier_health
	if stats.has("soldier_damage"):
		stats_text += "Damage: %d | " % stats.soldier_damage
	if stats.has("soldier_attack_speed"):
		stats_text += "AS: %.1f/s\n" % stats.soldier_attack_speed
	if stats.has("respawn_time"):
		stats_text += "Respawn: %.1fs" % stats.respawn_time

	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stats_label)

	stats_container.add_child(level_panel)

func _display_generic_tower_stats(tower_id: String, tower_data: Dictionary):
	"""Fallback for unknown tower types"""
	var label = Label.new()
	label.text = "Tower type not yet implemented in codex"
	stats_container.add_child(label)

func _update_button_states():
	"""Highlight the currently selected tower button"""
	for tower_id in tower_buttons:
		var button = tower_buttons[tower_id]
		if tower_id == current_tower_id:
			button.modulate = Color(1.2, 1.2, 1.0)  # Highlight
		else:
			button.modulate = Color(1.0, 1.0, 1.0)  # Normal

func _on_close_pressed():
	"""Close the codex"""
	print("[TowerCodex] Close button pressed")
	codex_closed.emit()
	hide()

func _on_back_button_pressed():
	"""Return to world map (used in standalone scene mode)"""
	print("⬅️ [TowerCodex] Back button pressed - returning to world map")
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")
