extends Control
class_name BasePanelView

## BasePanelView - Base class for all panel content views
## Each view (Equipment, Inventory, Stats, Skills, Comparison) extends this

signal view_ready
signal view_refreshed

@export var view_name: String = "Base View"
@export var view_icon: Texture2D  # Optional icon for tab

var is_initialized: bool = false


func _ready():
	is_initialized = true
	view_ready.emit()


## Called when this view becomes visible in the panel
func on_view_shown():
	refresh_view()


## Called when this view is hidden (another tab selected)
func on_view_hidden():
	pass


## Override this in child classes to update display
func refresh_view():
	view_refreshed.emit()


## Override to return if this view is available (e.g., needs hero selected)
func is_view_available() -> bool:
	return true


## Override to clean up when panel is closed
func cleanup():
	pass
