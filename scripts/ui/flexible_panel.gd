extends PanelContainer
class_name FlexiblePanel

## FlexiblePanel - Container with switchable view tabs
## Allows player to choose which content to display (Equipment, Inventory, Stats, Skills, Comparison)

signal tab_changed(new_view_id: String)
signal view_content_changed

enum ViewType {
	EQUIPMENT,
	INVENTORY,
	STATS,
	SKILLS,
	COMPARISON
}

# Packed scenes for each view
@export var equipment_view_scene: PackedScene
@export var inventory_view_scene: PackedScene
@export var stats_view_scene: PackedScene
@export var skills_view_scene: PackedScene
@export var comparison_view_scene: PackedScene

# UI References
@onready var tab_container: HBoxContainer = $VBoxContainer/TabBar if has_node("VBoxContainer/TabBar") else null
@onready var content_container: Control = $VBoxContainer/ContentContainer if has_node("VBoxContainer/ContentContainer") else null
@onready var panel_title: Label = $VBoxContainer/Header/PanelTitle if has_node("VBoxContainer/Header/PanelTitle") else null

# Tab buttons
var tab_buttons: Dictionary = {}  # {ViewType: Button}

# View instances (lazy loaded)
var view_instances: Dictionary = {}  # {ViewType: BasePanelView}
var current_view_type: ViewType = ViewType.EQUIPMENT
var current_view: BasePanelView = null

# Settings
@export var panel_side: String = "left"  # "left" or "right" for saving preferences
@export var default_view: ViewType = ViewType.EQUIPMENT


func _ready():
	_create_tab_buttons()
	_load_saved_preference()
	_switch_to_view(current_view_type)


func _create_tab_buttons():
	"""Create tab buttons for each view type"""
	if not tab_container:
		return

	# Clear existing children
	for child in tab_container.get_children():
		child.queue_free()

	# Create button for each view type
	var view_configs = [
		{"type": ViewType.EQUIPMENT, "label": "Equipment", "icon": null},
		{"type": ViewType.INVENTORY, "label": "Inventory", "icon": null},
		{"type": ViewType.STATS, "label": "Stats", "icon": null},
		{"type": ViewType.SKILLS, "label": "Skills", "icon": null},
		{"type": ViewType.COMPARISON, "label": "Compare", "icon": null},
	]

	for config in view_configs:
		var button = Button.new()
		button.text = config.label
		button.toggle_mode = true
		button.button_group = _get_or_create_button_group()
		button.custom_minimum_size = Vector2(100, 40)

		# Style
		button.add_theme_font_size_override("font_size", 14)

		# Connect signal
		var view_type = config.type
		button.pressed.connect(_on_tab_button_pressed.bind(view_type))

		tab_container.add_child(button)
		tab_buttons[view_type] = button


func _get_or_create_button_group() -> ButtonGroup:
	"""Get or create button group for tab buttons"""
	if not has_meta("tab_button_group"):
		var group = ButtonGroup.new()
		set_meta("tab_button_group", group)
		return group
	return get_meta("tab_button_group")


func _switch_to_view(view_type: ViewType):
	"""Switch to a different view"""
	# Hide current view
	if current_view:
		current_view.visible = false
		current_view.on_view_hidden()

	# Load or get view instance
	var view = _get_or_create_view(view_type)
	if not view:
		print("[FlexiblePanel] Error: Could not create view: ", view_type)
		return

	# Update current view
	current_view_type = view_type
	current_view = view

	# Show new view
	current_view.visible = true
	current_view.on_view_shown()

	# Update tab button states
	_update_tab_button_states()

	# Update panel title
	if panel_title:
		panel_title.text = _get_view_title(view_type)

	# Save preference
	_save_preference()

	# Emit signal
	tab_changed.emit(_view_type_to_string(view_type))

	print("[FlexiblePanel:%s] Switched to view: %s" % [panel_side, _view_type_to_string(view_type)])


func _get_or_create_view(view_type: ViewType) -> BasePanelView:
	"""Get existing view instance or create new one"""
	# Check if already exists
	if view_instances.has(view_type):
		return view_instances[view_type]

	# Create new instance
	var scene = _get_view_scene(view_type)
	if not scene:
		return null

	var instance = scene.instantiate() as BasePanelView
	if not instance:
		return null

	# Add to content container
	if content_container:
		content_container.add_child(instance)
		instance.visible = false

	# Store instance
	view_instances[view_type] = instance

	return instance


func _get_view_scene(view_type: ViewType) -> PackedScene:
	"""Get packed scene for view type"""
	match view_type:
		ViewType.EQUIPMENT:
			return equipment_view_scene
		ViewType.INVENTORY:
			return inventory_view_scene
		ViewType.STATS:
			return stats_view_scene
		ViewType.SKILLS:
			return skills_view_scene
		ViewType.COMPARISON:
			return comparison_view_scene
	return null


func _get_view_title(view_type: ViewType) -> String:
	"""Get display title for view"""
	match view_type:
		ViewType.EQUIPMENT:
			return "Equipment"
		ViewType.INVENTORY:
			return "Inventory"
		ViewType.STATS:
			return "Hero Stats"
		ViewType.SKILLS:
			return "Skills & Abilities"
		ViewType.COMPARISON:
			return "Item Comparison"
	return "Unknown"


func _update_tab_button_states():
	"""Update which tab button is pressed"""
	for view_type in tab_buttons.keys():
		var button = tab_buttons[view_type]
		button.button_pressed = (view_type == current_view_type)


func _on_tab_button_pressed(view_type: ViewType):
	"""Called when a tab button is pressed"""
	_switch_to_view(view_type)


## Public API

func refresh_current_view():
	"""Refresh the currently visible view"""
	if current_view:
		current_view.refresh_view()


func get_current_view() -> BasePanelView:
	"""Get the currently active view"""
	return current_view


func set_hero_id(hero_id: String):
	"""Set hero ID for views that need it"""
	for view in view_instances.values():
		if view.has_method("set_hero_id"):
			view.set_hero_id(hero_id)


## Save/Load Preferences

func _save_preference():
	"""Save current tab selection to SaveManager"""
	var pref_key = "ui_panel_%s_view" % panel_side
	SaveManager.set_user_preference(pref_key, _view_type_to_string(current_view_type))


func _load_saved_preference():
	"""Load saved tab preference"""
	var pref_key = "ui_panel_%s_view" % panel_side
	var saved_view = SaveManager.get_user_preference(pref_key, "")

	if saved_view != "":
		var view_type = _string_to_view_type(saved_view)
		if view_type != null:
			current_view_type = view_type


func _view_type_to_string(view_type: ViewType) -> String:
	"""Convert ViewType enum to string"""
	match view_type:
		ViewType.EQUIPMENT: return "equipment"
		ViewType.INVENTORY: return "inventory"
		ViewType.STATS: return "stats"
		ViewType.SKILLS: return "skills"
		ViewType.COMPARISON: return "comparison"
	return "equipment"


func _string_to_view_type(view_str: String) -> ViewType:
	"""Convert string to ViewType enum"""
	match view_str:
		"equipment": return ViewType.EQUIPMENT
		"inventory": return ViewType.INVENTORY
		"stats": return ViewType.STATS
		"skills": return ViewType.SKILLS
		"comparison": return ViewType.COMPARISON
	return ViewType.EQUIPMENT
