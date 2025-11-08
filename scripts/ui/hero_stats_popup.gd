extends PanelContainer
class_name HeroStatsPopup

## HeroStatsPopup - Compact stats display for selected hero
## Shows real-time combat stats next to hero button

var stats_label: RichTextLabel = null
var hero_reference = null

func _ready():
	# Start hidden
	visible = false

	# Setup panel appearance
	custom_minimum_size = Vector2(200, 160)

	# Create margin container
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	add_child(margin)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	# Create stats label
	stats_label = RichTextLabel.new()
	stats_label.name = "StatsLabel"
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false

	# Make text 50% smaller
	stats_label.add_theme_font_size_override("normal_font_size", 8)
	stats_label.add_theme_font_size_override("bold_font_size", 9)

	margin.add_child(stats_label)


func set_hero(hero):
	"""Set the hero to display stats for"""
	hero_reference = hero
	if hero_reference and is_instance_valid(hero_reference):
		_update_stats()


func show_stats():
	"""Show the stats panel"""
	if hero_reference and is_instance_valid(hero_reference):
		_update_stats()
		visible = true


func hide_stats():
	"""Hide the stats panel"""
	visible = false


func _process(delta):
	# Update stats every frame while visible
	if visible and hero_reference and is_instance_valid(hero_reference):
		_update_stats()


func _update_stats():
	"""Update stats display with current hero values"""
	if not hero_reference or not is_instance_valid(hero_reference):
		return

	if not stats_label:
		return

	var text = ""

	# Ranged Combat
	text += "[b]RANGED[/b]\n"
	if "ranged_damage" in hero_reference:
		text += "  Damage: [color=yellow]%.1f[/color]\n" % hero_reference.ranged_damage
	if "ranged_range" in hero_reference:
		text += "  Range: [color=cyan]%.0f[/color]\n" % hero_reference.ranged_range
	if "ranged_attack_speed" in hero_reference:
		var attacks_per_sec = 1.0 / hero_reference.ranged_attack_speed
		text += "  Speed: [color=green]%.2f/sec[/color]\n" % attacks_per_sec
	text += "\n"

	# Melee Combat
	text += "[b]MELEE[/b]\n"
	if "melee_damage" in hero_reference:
		text += "  Damage: [color=yellow]%.1f[/color]\n" % hero_reference.melee_damage
	text += "\n"

	# Health
	text += "[b]HEALTH[/b]\n"
	if "current_health" in hero_reference and "max_health" in hero_reference:
		text += "  [color=red]%.0f[/color] / %.0f\n" % [hero_reference.current_health, hero_reference.max_health]
	text += "\n"

	# Movement
	text += "[b]MOVEMENT[/b]\n"
	if "movement_speed" in hero_reference:
		text += "  Speed: %.0f\n" % hero_reference.movement_speed

	stats_label.text = text
