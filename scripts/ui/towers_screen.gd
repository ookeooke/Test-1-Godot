extends Control

# ============================================
# TOWERS SCREEN - Dual Tab Screen
# ============================================
# Combines Tower Codex (view stats) and Tower Loadout (select towers)
# Tab-based interface for easy switching between views

signal screen_closed

# TABS
enum Tab { CODEX, LOADOUT }
var current_tab: Tab = Tab.LOADOUT  # Start with loadout (more important)

# NODE REFERENCES
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TopBar/BackButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TopBar/BackButton") else null
@onready var codex_tab_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabBar/CodexTabButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TabBar/CodexTabButton") else null
@onready var loadout_tab_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabBar/LoadoutTabButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TabBar/LoadoutTabButton") else null
@onready var content_container: Control = $PanelContainer/MarginContainer/VBoxContainer/ContentContainer if has_node("PanelContainer/MarginContainer/VBoxContainer/ContentContainer") else null

# EMBEDDED SCENES
var codex_scene: PackedScene = preload("res://scenes/ui/tower_codex_menu.tscn")
var loadout_scene: PackedScene = preload("res://scenes/ui/tower_loadout_menu.tscn")

var codex_instance: Control = null
var loadout_instance: Control = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Connect signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if codex_tab_button:
		codex_tab_button.pressed.connect(_on_codex_tab_pressed)

	if loadout_tab_button:
		loadout_tab_button.pressed.connect(_on_loadout_tab_pressed)

	# Load both tab scenes
	_load_tab_scenes()

	# Show initial tab
	_switch_to_tab(Tab.LOADOUT)

	print("[TowersScreen] Initialized with dual-tab view")

func _load_tab_scenes():
	"""Instantiate both tab scenes and hide them initially"""
	if not content_container:
		push_error("[TowersScreen] ContentContainer not found!")
		return

	# Load Codex
	codex_instance = codex_scene.instantiate()
	codex_instance.visible = false
	# Connect close signal to prevent it from closing standalone
	if codex_instance.has_signal("codex_closed"):
		codex_instance.codex_closed.connect(_on_codex_closed)
	content_container.add_child(codex_instance)

	# Hide codex's own close/back buttons (we have our own)
	_hide_internal_buttons(codex_instance, "CloseButton", "BackButton")

	# Load Loadout
	loadout_instance = loadout_scene.instantiate()
	loadout_instance.visible = false
	# Connect close signal
	if loadout_instance.has_signal("menu_closed"):
		loadout_instance.menu_closed.connect(_on_loadout_closed)
	if loadout_instance.has_signal("loadout_changed"):
		loadout_instance.loadout_changed.connect(_on_loadout_changed)
	content_container.add_child(loadout_instance)

	# Hide loadout's own close button (we have our own)
	_hide_internal_buttons(loadout_instance, "CloseButton")

	# Make instances fill the container
	codex_instance.anchors_preset = Control.PRESET_FULL_RECT
	codex_instance.anchor_right = 1.0
	codex_instance.anchor_bottom = 1.0

	loadout_instance.anchors_preset = Control.PRESET_FULL_RECT
	loadout_instance.anchor_right = 1.0
	loadout_instance.anchor_bottom = 1.0

	print("[TowersScreen] Loaded tab scenes")

func _hide_internal_buttons(instance: Control, button_name1: String, button_name2: String = ""):
	"""Hide internal close/back buttons from embedded scenes"""
	# Try to find and hide buttons by their common paths
	var paths = [
		"PanelContainer/MarginContainer/VBoxContainer/TopBar/%s",
		"PanelContainer/MarginContainer/VBoxContainer/BottomBar/%s"
	]

	for button_name in [button_name1, button_name2]:
		if button_name == "":
			continue

		for path_template in paths:
			var path = path_template % button_name
			if instance.has_node(path):
				var button = instance.get_node(path)
				button.visible = false
				print("[TowersScreen] Hid button: %s" % path)

# ============================================
# TAB SWITCHING
# ============================================

func _switch_to_tab(tab: Tab):
	"""Switch between Codex and Loadout views"""
	current_tab = tab

	# Show/hide appropriate scene
	if codex_instance and loadout_instance:
		codex_instance.visible = (tab == Tab.CODEX)
		loadout_instance.visible = (tab == Tab.LOADOUT)

	# Update tab button styles
	_update_tab_button_styles()

	print("[TowersScreen] Switched to %s" % ("CODEX" if tab == Tab.CODEX else "LOADOUT"))

func _update_tab_button_styles():
	"""Update visual styles for active/inactive tabs"""
	if not codex_tab_button or not loadout_tab_button:
		return

	# Active tab style (bright, highlighted)
	var active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.3, 0.6, 0.8, 1.0)  # Blue
	active_style.set_border_width_all(3)
	active_style.border_color = Color(0.5, 0.8, 1.0, 1.0)
	active_style.set_corner_radius_all(6)

	# Inactive tab style (gray, dim)
	var inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	inactive_style.set_border_width_all(2)
	inactive_style.border_color = Color(0.4, 0.4, 0.45, 1.0)
	inactive_style.set_corner_radius_all(6)

	# Apply styles
	if current_tab == Tab.CODEX:
		codex_tab_button.add_theme_stylebox_override("normal", active_style)
		loadout_tab_button.add_theme_stylebox_override("normal", inactive_style)
	else:
		codex_tab_button.add_theme_stylebox_override("normal", inactive_style)
		loadout_tab_button.add_theme_stylebox_override("normal", active_style)

# ============================================
# CALLBACKS
# ============================================

func _on_codex_tab_pressed():
	"""Switch to Codex view"""
	_switch_to_tab(Tab.CODEX)

func _on_loadout_tab_pressed():
	"""Switch to Loadout view"""
	_switch_to_tab(Tab.LOADOUT)

func _on_back_pressed():
	"""Return to world map"""
	print("[TowersScreen] Returning to world map")
	screen_closed.emit()
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")

func _on_codex_closed():
	"""Prevent codex from closing standalone - ignore signal"""
	pass

func _on_loadout_closed():
	"""Prevent loadout from closing standalone - ignore signal"""
	pass

func _on_loadout_changed(new_loadout: Array):
	"""Forward loadout changed signal"""
	print("[TowersScreen] Loadout changed: %s" % str(new_loadout))
