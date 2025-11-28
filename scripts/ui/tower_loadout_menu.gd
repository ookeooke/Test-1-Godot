extends Control

# ============================================
# TOWER LOADOUT MENU - Kingdom Rush Style
# ============================================
# Three-panel layout inspired by Kingdom Rush hero equipment screen:
# - Left: EQUIPPED TOWERS sidebar (3-4 slots)
# - Center: Large tower preview with animated background
# - Right: Tower stats and description
# - Top: Scrollable bar of all available towers
# - Bottom: RESET/DONE buttons

signal loadout_changed(new_loadout: Array)
signal menu_closed

# SETTINGS
const MIN_LOADOUT_SIZE = 3
const MAX_LOADOUT_SIZE = 4

# STATE
var current_loadout: Array = [] # Array of tower_id strings currently equipped
var unlocked_towers: Array = [] # All towers player has unlocked
var selected_tower_id: String = "" # Currently previewed tower

# NODE REFERENCES (will be created programmatically or from scene)
var close_button: Button
var reset_button: Button
var done_button: Button

# Top bar - available towers
var top_bar_scroll: ScrollContainer
var top_bar_container: HBoxContainer
var top_bar_buttons: Dictionary = {} # tower_id -> Button

# Left sidebar - equipped towers
var equipped_label: Label
var equipped_slots_container: VBoxContainer
var equipped_slot_buttons: Array[Button] = [] # Fixed 4 slots

# Center panel - tower preview
var preview_panel: PanelContainer
var preview_icon_label: Label
var preview_name_label: Label

# Right panel - stats
var stats_panel: VBoxContainer
var stats_labels: Dictionary = {} # stat_name -> Label

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Create UI structure
	_create_ui_structure()

	# Load data
	_load_data()

	# Populate UI
	_create_top_bar_towers()
	_create_equipped_slots()

	# Show first tower or first in loadout
	if current_loadout.size() > 0:
		_select_tower(current_loadout[0])
	elif unlocked_towers.size() > 0:
		_select_tower(unlocked_towers[0])

	print("[TowerLoadoutMenu] Initialized (KR-style) with loadout: %s" % str(current_loadout))

# ============================================
# UI STRUCTURE CREATION
# ============================================

func _create_ui_structure():
	"""Create Kingdom Rush-style UI layout"""
	# Main VBox container (fills parent - no extra panel when embedded)
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	add_child(vbox)

	# === TOP BAR ===
	# Note: When embedded in towers_screen, the parent handles the back button
	# So we don't create our own close button here

	# === AVAILABLE TOWERS BAR ===
	var available_label = Label.new()
	available_label.text = "AVAILABLE TOWERS:"
	available_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(available_label)

	top_bar_scroll = ScrollContainer.new()
	top_bar_scroll.custom_minimum_size = Vector2(0, 100)
	top_bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_bar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(top_bar_scroll)

	top_bar_container = HBoxContainer.new()
	top_bar_container.add_theme_constant_override("separation", 10)
	top_bar_scroll.add_child(top_bar_container)

	vbox.add_child(HSeparator.new())

	# === MAIN CONTENT (3 PANELS) ===
	var content_hbox = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 20)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_hbox)

	# LEFT PANEL - Equipped Towers
	_create_equipped_panel(content_hbox)

	# CENTER PANEL - Preview
	_create_preview_panel(content_hbox)

	# RIGHT PANEL - Stats
	_create_stats_panel(content_hbox)

	vbox.add_child(HSeparator.new())

	# === BOTTOM BAR ===
	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 20)
	vbox.add_child(bottom_bar)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)

	reset_button = Button.new()
	reset_button.text = "↻ RESET"
	reset_button.custom_minimum_size = Vector2(150, 60)
	reset_button.add_theme_font_size_override("font_size", 18)
	reset_button.pressed.connect(_on_reset_pressed)
	bottom_bar.add_child(reset_button)

	done_button = Button.new()
	done_button.text = "✓ DONE"
	done_button.custom_minimum_size = Vector2(200, 60)
	done_button.add_theme_font_size_override("font_size", 20)
	done_button.pressed.connect(_on_done_pressed)
	bottom_bar.add_child(done_button)

func _create_equipped_panel(parent: HBoxContainer):
	"""Create left sidebar with equipped tower slots"""
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	left_panel.add_theme_constant_override("separation", 10)
	parent.add_child(left_panel)

	equipped_label = Label.new()
	equipped_label.text = "EQUIPPED TOWERS"
	equipped_label.add_theme_font_size_override("font_size", 16)
	equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(equipped_label)

	equipped_slots_container = VBoxContainer.new()
	equipped_slots_container.add_theme_constant_override("separation", 15)
	equipped_slots_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(equipped_slots_container)

func _create_preview_panel(parent: HBoxContainer):
	"""Create center panel with large tower preview"""
	preview_panel = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(400, 400)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(preview_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	preview_panel.add_child(vbox)

	# Large tower icon
	preview_icon_label = Label.new()
	preview_icon_label.text = "🏹"
	preview_icon_label.add_theme_font_size_override("font_size", 120)
	preview_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_icon_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(preview_icon_label)

	# Tower name
	preview_name_label = Label.new()
	preview_name_label.text = "Archer Tower"
	preview_name_label.add_theme_font_size_override("font_size", 32)
	preview_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_name_label)

func _create_stats_panel(parent: HBoxContainer):
	"""Create right panel with tower stats"""
	stats_panel = VBoxContainer.new()
	stats_panel.custom_minimum_size = Vector2(300, 0)
	stats_panel.add_theme_constant_override("separation", 15)
	parent.add_child(stats_panel)

	var stats_title = Label.new()
	stats_title.text = "TOWER STATS"
	stats_title.add_theme_font_size_override("font_size", 18)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(stats_title)

	# Create stat labels (will be populated later)
	var stat_names = ["build_cost", "damage", "attack_speed", "range", "dps", "description"]
	for stat_name in stat_names:
		var stat_label = Label.new()
		stat_label.name = stat_name + "_label"
		stat_label.add_theme_font_size_override("font_size", 14)
		stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_panel.add_child(stat_label)
		stats_labels[stat_name] = stat_label

# ============================================
# DATA LOADING
# ============================================

func _load_data():
	"""Load current loadout and unlocked towers from SaveManager"""
	current_loadout = SaveManager.get_tower_loadout().duplicate()
	unlocked_towers = SaveManager.get_unlocked_towers().duplicate()

	# Ensure minimum loadout size by adding missing towers
	for tower_id in unlocked_towers:
		if not tower_id in current_loadout:
			current_loadout.append(tower_id)
			if current_loadout.size() >= MIN_LOADOUT_SIZE:
				break

	print("[TowerLoadoutMenu] Loaded %d unlocked, loadout: %s" % [unlocked_towers.size(), str(current_loadout)])

# ============================================
# UI POPULATION
# ============================================

func _create_top_bar_towers():
	"""Create buttons for all unlocked towers in top bar"""
	for tower_id in unlocked_towers:
		var button = Button.new()
		button.custom_minimum_size = Vector2(80, 80)
		button.toggle_mode = false

		var tower_data = TowerData.get_tower_data(tower_id)
		var icon = tower_data.get("icon", "?")
		button.text = icon
		button.add_theme_font_size_override("font_size", 40)

		button.pressed.connect(_on_top_bar_tower_clicked.bind(tower_id))

		top_bar_container.add_child(button)
		top_bar_buttons[tower_id] = button

	_update_top_bar_styles()

func _create_equipped_slots():
	"""Create 4 fixed equipment slots in left sidebar"""
	equipped_slot_buttons.clear()

	for i in range(MAX_LOADOUT_SIZE):
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 120)
		button.toggle_mode = false

		# Set initial content
		if i < current_loadout.size():
			var tower_id = current_loadout[i]
			_update_slot_button(button, tower_id, i)
		else:
			_update_slot_button(button, "", i) # Empty slot with lock

		button.pressed.connect(_on_equipped_slot_clicked.bind(i))

		equipped_slots_container.add_child(button)
		equipped_slot_buttons.append(button)

func _update_slot_button(button: Button, tower_id: String, _slot_index: int):
	"""Update an equipment slot button's appearance"""
	if tower_id == "":
		# Empty slot
		button.text = "🔒\nEMPTY"
		button.add_theme_font_size_override("font_size", 20)

		# Gray locked style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.18, 0.8)
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 0.3, 0.35, 1.0)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override("normal", style)
	else:
		# Equipped tower
		var tower_data = TowerData.get_tower_data(tower_id)
		var icon = tower_data.get("icon", "?")
		var tower_name = tower_data.get("name", "???")
		button.text = "%s\n%s" % [icon, tower_name.split(" ")[0]] # First word only
		button.add_theme_font_size_override("font_size", 18)

		# Golden equipped style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.15, 0.1, 0.9)
		style.set_border_width_all(3)
		style.border_color = Color(0.9, 0.8, 0.4, 1.0) # Golden
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override("normal", style)

# ============================================
# TOWER SELECTION & PREVIEW
# ============================================

func _select_tower(tower_id: String):
	"""Select and preview a tower in center panel"""
	if tower_id == "":
		return

	selected_tower_id = tower_id

	# Update preview
	var tower_data = TowerData.get_tower_data(tower_id)
	preview_icon_label.text = tower_data.get("icon", "?")
	preview_name_label.text = tower_data.get("name", "Unknown Tower")

	# Update stats
	_update_stats_display(tower_id)

	# Update top bar button styles
	_update_top_bar_styles()

func _update_stats_display(tower_id: String):
	"""Update right panel stats for selected tower"""
	var tower_data = TowerData.get_tower_data(tower_id)
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)

	if stats_labels.has("build_cost"):
		stats_labels["build_cost"].text = "💰 Cost: %d gold" % tower_data.get("build_cost", 0)

	if stats_labels.has("damage"):
		stats_labels["damage"].text = "⚔️ Damage: %d" % level_1_stats.get("damage", 0)

	if stats_labels.has("attack_speed"):
		stats_labels["attack_speed"].text = "⚡ Attack Speed: %.1f/sec" % level_1_stats.get("attack_speed", 0.0)

	if stats_labels.has("range"):
		stats_labels["range"].text = "🎯 Range: %d" % level_1_stats.get("range", 0)

	if stats_labels.has("dps"):
		stats_labels["dps"].text = "💥 DPS: %.1f" % level_1_stats.get("dps", 0.0)

	if stats_labels.has("description"):
		stats_labels["description"].text = "\n%s" % tower_data.get("description", "")

func _update_top_bar_styles():
	"""Update visual styles for top bar tower buttons"""
	for tower_id in top_bar_buttons.keys():
		var button = top_bar_buttons[tower_id]

		if tower_id == selected_tower_id:
			# Selected tower - golden border
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.2, 0.15, 1.0)
			style.set_border_width_all(4)
			style.border_color = Color(0.95, 0.85, 0.5, 1.0)
			style.set_corner_radius_all(8)
			button.add_theme_stylebox_override("normal", style)
		elif tower_id in current_loadout:
			# Equipped but not selected - dim golden
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.15, 0.1, 0.9)
			style.set_border_width_all(2)
			style.border_color = Color(0.7, 0.6, 0.3, 1.0)
			style.set_corner_radius_all(8)
			button.add_theme_stylebox_override("normal", style)
		else:
			# Not equipped - gray
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
			style.set_border_width_all(2)
			style.border_color = Color(0.3, 0.3, 0.35, 1.0)
			style.set_corner_radius_all(8)
			button.add_theme_stylebox_override("normal", style)

# ============================================
# CALLBACKS
# ============================================

func _on_top_bar_tower_clicked(tower_id: String):
	"""Handle clicking a tower in the top bar"""
	_select_tower(tower_id)

func _on_equipped_slot_clicked(slot_index: int):
	"""Handle clicking an equipment slot"""
	if slot_index < current_loadout.size():
		# Slot has tower - remove it
		var removed_tower = current_loadout[slot_index]
		current_loadout.remove_at(slot_index)
		print("[TowerLoadoutMenu] Removed %s from slot %d" % [removed_tower, slot_index])
	else:
		# Empty slot - add selected tower if possible
		if selected_tower_id != "" and not selected_tower_id in current_loadout:
			if current_loadout.size() < MAX_LOADOUT_SIZE:
				current_loadout.append(selected_tower_id)
				print("[TowerLoadoutMenu] Added %s to loadout" % selected_tower_id)

	# Refresh UI
	_refresh_equipped_slots()
	_update_top_bar_styles()

func _on_reset_pressed():
	"""Reset loadout to minimum default"""
	current_loadout.clear()

	# Add first 3 unlocked towers
	for i in range(min(MIN_LOADOUT_SIZE, unlocked_towers.size())):
		current_loadout.append(unlocked_towers[i])

	_refresh_equipped_slots()
	_update_top_bar_styles()
	print("[TowerLoadoutMenu] Reset loadout to: %s" % str(current_loadout))

func _on_done_pressed():
	"""Save loadout and close"""
	if current_loadout.size() < MIN_LOADOUT_SIZE:
		print("[TowerLoadoutMenu] Cannot save - need at least %d towers" % MIN_LOADOUT_SIZE)
		return

	SaveManager.set_tower_loadout(current_loadout)
	loadout_changed.emit(current_loadout)
	print("[TowerLoadoutMenu] Saved loadout: %s" % str(current_loadout))

	_on_close_pressed()

func _on_close_pressed():
	"""Return to world map"""
	print("[TowerLoadoutMenu] Returning to world map")
	menu_closed.emit()

	if get_tree():
		get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")
	else:
		queue_free()

# ============================================
# UI REFRESH
# ============================================

func _refresh_equipped_slots():
	"""Refresh all equipment slot visuals"""
	for i in range(equipped_slot_buttons.size()):
		var button = equipped_slot_buttons[i]
		if i < current_loadout.size():
			_update_slot_button(button, current_loadout[i], i)
		else:
			_update_slot_button(button, "", i)
