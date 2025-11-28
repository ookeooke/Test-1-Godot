extends PanelContainer
class_name FlexiblePanel

## FlexiblePanel - Simplified panel showing single fixed view (Equipment or Inventory)
## Mobile-first design without tab switching complexity

# signal view_content_changed

enum ViewType {
	EQUIPMENT,
	INVENTORY
}

# Packed scenes for views
@export var equipment_view_scene: PackedScene
@export var inventory_view_scene: PackedScene

# UI References
@onready var content_container: Control = $VBoxContainer/ContentContainer if has_node("VBoxContainer/ContentContainer") else null
@onready var panel_title: Label = $VBoxContainer/Header/PanelTitle if has_node("VBoxContainer/Header/PanelTitle") else null

# View instance (single view only)
var current_view_type: ViewType = ViewType.EQUIPMENT
var current_view: BasePanelView = null

# Settings
@export var panel_side: String = "left" # "left" or "right"
@export var default_view: ViewType = ViewType.EQUIPMENT


func _ready():
	_load_view(default_view)


func _load_view(view_type: ViewType):
	"""Load the single fixed view for this panel"""
	current_view_type = view_type

	# Get the scene for this view type
	var scene = _get_view_scene(view_type)
	if not scene:
		print("[FlexiblePanel] Error: No scene for view type: ", view_type)
		return

	# Instantiate the view
	var instance = scene.instantiate() as BasePanelView
	if not instance:
		print("[FlexiblePanel] Error: Could not instantiate view")
		return

	# Add to content container
	if content_container:
		content_container.add_child(instance)
		instance.visible = true
		instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Store reference
	current_view = instance

	# Update panel title
	if panel_title:
		panel_title.text = _get_view_title(view_type)

	# Show the view
	current_view.on_view_shown()

	print("[FlexiblePanel:%s] Loaded view: %s" % [panel_side, _view_type_to_string(view_type)])


func _get_view_scene(view_type: ViewType) -> PackedScene:
	"""Get packed scene for view type"""
	match view_type:
		ViewType.EQUIPMENT:
			return equipment_view_scene
		ViewType.INVENTORY:
			return inventory_view_scene
	return null


func _get_view_title(view_type: ViewType) -> String:
	"""Get display title for view"""
	match view_type:
		ViewType.EQUIPMENT:
			return "Equipment"
		ViewType.INVENTORY:
			return "Inventory"
	return "Unknown"


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
	if current_view and current_view.has_method("set_hero_id"):
		current_view.set_hero_id(hero_id)


## Helper Functions

func _view_type_to_string(view_type: ViewType) -> String:
	"""Convert ViewType enum to string"""
	match view_type:
		ViewType.EQUIPMENT: return "equipment"
		ViewType.INVENTORY: return "inventory"
	return "equipment"
