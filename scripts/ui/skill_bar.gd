extends PanelContainer
class_name SkillBar

## ============================================
## HERO SQUAD HUD (Formerly SkillBar)
## ============================================
## Manages the display of Hero Command Widgets for the entire squad.
## Replaces the old single-hero skill bar.

# REFERENCES
@onready var container = $HBoxContainer

# CONFIG
const WIDGET_SCENE = preload("res://scenes/ui/hero_command_widget.tscn")

func _ready():
	# Ensure container is configured for horizontal layout
	if not container:
		print("⚠️ SkillBar: HBoxContainer not found!")
		return
		
	# Initial build
	_rebuild_squad_hud()

	# POLLING: Check for new heroes every 1 second
	# This handles late spawning and dynamic reinforcements
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_for_hero_changes)
	add_child(timer)

	# Force update after first frame to catch late-spawning heroes
	# This fixes race condition where SkillBar initializes before heroes spawn
	await get_tree().process_frame
	await get_tree().process_frame  # Wait 2 frames
	_rebuild_squad_hud()

func _check_for_hero_changes():
	var heroes = get_tree().get_nodes_in_group("hero")
	var current_widgets = container.get_child_count()
	
	if heroes.size() != current_widgets:
		print("SkillBar: Hero count changed (%d -> %d). Rebuilding..." % [current_widgets, heroes.size()])
		_rebuild_squad_hud()

func _rebuild_squad_hud():
	# Clear existing
	for child in container.get_children():
		child.queue_free()
		
	# Find all heroes
	var heroes = get_tree().get_nodes_in_group("hero")
	
	if heroes.is_empty():
		# print("SkillBar: No heroes found in group 'hero'") # Too spammy for polling
		visible = false
		return
		
	visible = true
	
	for hero in heroes:
		var widget = WIDGET_SCENE.instantiate()
		container.add_child(widget)
		widget.setup(hero)
		print("SkillBar: Added widget for ", hero.name)
		
	print("SkillBar: Squad HUD active with %d widgets" % container.get_child_count())

# Keep public API for compatibility (though it might not be used)
func set_hero(_hero):
	pass # No-op, we show all heroes now

func _on_hero_selected(_hero):
	pass # No-op
