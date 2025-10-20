extends BasePanelView
class_name HeroStatsView

## HeroStatsView - Detailed hero statistics display
## Shows base stats, equipment bonuses, skill bonuses, and total stats

@export var hero_id: String = "ranger"

# UI References
@onready var hero_portrait: ColorRect = $MarginContainer/VBoxContainer/HeroHeader/Portrait if has_node("MarginContainer/VBoxContainer/HeroHeader/Portrait") else null
@onready var hero_name_label: Label = $MarginContainer/VBoxContainer/HeroHeader/NameLabel if has_node("MarginContainer/VBoxContainer/HeroHeader/NameLabel") else null
@onready var hero_level_label: Label = $MarginContainer/VBoxContainer/HeroHeader/LevelLabel if has_node("MarginContainer/VBoxContainer/HeroHeader/LevelLabel") else null

@onready var stats_text: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/StatsLabel if has_node("MarginContainer/VBoxContainer/ScrollContainer/StatsLabel") else null

var equipment_manager: EquipmentManager = null


func _ready():
	super._ready()
	view_name = "Hero Stats"


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	_find_equipment_manager()
	_update_display()


func set_hero_id(p_hero_id: String):
	"""Set which hero's stats to show"""
	hero_id = p_hero_id
	_find_equipment_manager()
	_update_display()


func _find_equipment_manager():
	"""Find the hero's equipment manager"""
	var heroes = get_tree().get_nodes_in_group("hero")
	for hero in heroes:
		if hero.has_method("get_hero_id") and hero.get_hero_id() == hero_id:
			if hero.has_node("EquipmentManager"):
				equipment_manager = hero.get_node("EquipmentManager")
				return


func _update_display():
	"""Update all stats display"""
	_update_hero_header()
	_update_stats_breakdown()


func _update_hero_header():
	"""Update hero portrait and name"""
	if hero_name_label:
		hero_name_label.text = hero_id.capitalize()

	if hero_level_label:
		hero_level_label.text = "Level 1"  # TODO: Implement hero leveling

	if hero_portrait:
		match hero_id:
			"ranger":
				hero_portrait.color = Color(0.4, 0.6, 0.8)
			"warrior":
				hero_portrait.color = Color(0.8, 0.4, 0.4)
			"mage":
				hero_portrait.color = Color(0.6, 0.4, 0.8)
			_:
				hero_portrait.color = Color(0.5, 0.5, 0.5)


func _update_stats_breakdown():
	"""Show detailed stat breakdown"""
	if not stats_text:
		return

	var text = "[center][b]DETAILED STATISTICS[/b][/center]\n\n"

	# Get base stats (hardcoded for now, should come from hero data)
	var base_stats = _get_base_stats()

	# Get equipment bonuses
	var equipment_bonuses = _get_equipment_bonuses()

	# Get skill bonuses (TODO: implement when skill system ready)
	var skill_bonuses = _get_skill_bonuses()

	# Damage
	text += "[b]DAMAGE[/b]\n"
	text += "  Base: %d\n" % base_stats.damage
	if equipment_bonuses.damage > 0:
		text += "  Equipment: [color=green]+%d[/color]\n" % equipment_bonuses.damage
	if skill_bonuses.damage > 0:
		text += "  Skills: [color=cyan]+%d[/color]\n" % skill_bonuses.damage
	var total_damage = base_stats.damage + equipment_bonuses.damage + skill_bonuses.damage
	text += "  [b]Total: %d[/b]\n\n" % total_damage

	# Health
	text += "[b]HEALTH[/b]\n"
	text += "  Base: %d\n" % base_stats.health
	if equipment_bonuses.health > 0:
		text += "  Equipment: [color=green]+%d[/color]\n" % equipment_bonuses.health
	if skill_bonuses.health > 0:
		text += "  Skills: [color=cyan]+%d[/color]\n" % skill_bonuses.health
	var total_health = base_stats.health + equipment_bonuses.health + skill_bonuses.health
	text += "  [b]Total: %d[/b]\n\n" % total_health

	# Attack Speed
	text += "[b]ATTACK SPEED[/b]\n"
	text += "  Base: %.2f/sec\n" % base_stats.attack_speed
	if equipment_bonuses.attack_speed_mult > 1.0:
		text += "  Equipment: [color=green]x%.2f[/color]\n" % equipment_bonuses.attack_speed_mult
	if skill_bonuses.attack_speed_mult > 1.0:
		text += "  Skills: [color=cyan]x%.2f[/color]\n" % skill_bonuses.attack_speed_mult
	var total_attack_speed = base_stats.attack_speed * equipment_bonuses.attack_speed_mult * skill_bonuses.attack_speed_mult
	text += "  [b]Total: %.2f/sec[/b]\n\n" % total_attack_speed

	# Range
	text += "[b]RANGE[/b]\n"
	text += "  Base: %d\n" % base_stats.range
	if equipment_bonuses.range > 0:
		text += "  Equipment: [color=green]+%d[/color]\n" % equipment_bonuses.range
	if skill_bonuses.range > 0:
		text += "  Skills: [color=cyan]+%d[/color]\n" % skill_bonuses.range
	var total_range = base_stats.range + equipment_bonuses.range + skill_bonuses.range
	text += "  [b]Total: %d[/b]\n\n" % total_range

	# Defense
	if equipment_bonuses.defense > 0 or skill_bonuses.defense > 0:
		text += "[b]DEFENSE[/b]\n"
		text += "  Base: 0\n"
		if equipment_bonuses.defense > 0:
			text += "  Equipment: [color=green]+%d[/color]\n" % equipment_bonuses.defense
		if skill_bonuses.defense > 0:
			text += "  Skills: [color=cyan]+%d[/color]\n" % skill_bonuses.defense
		var total_defense = equipment_bonuses.defense + skill_bonuses.defense
		text += "  [b]Total: %d[/b]\n\n" % total_defense

	# Critical Chance
	if equipment_bonuses.crit_chance > 0 or skill_bonuses.crit_chance > 0:
		text += "[b]CRITICAL CHANCE[/b]\n"
		text += "  Base: 0%\n"
		if equipment_bonuses.crit_chance > 0:
			text += "  Equipment: [color=green]+%.1f%%[/color]\n" % (equipment_bonuses.crit_chance * 100)
		if skill_bonuses.crit_chance > 0:
			text += "  Skills: [color=cyan]+%.1f%%[/color]\n" % (skill_bonuses.crit_chance * 100)
		var total_crit = equipment_bonuses.crit_chance + skill_bonuses.crit_chance
		text += "  [b]Total: %.1f%%[/b]\n\n" % (total_crit * 100)

	stats_text.text = text


func _get_base_stats() -> Dictionary:
	"""Get hero's base stats (should come from hero data resource)"""
	# TODO: Load from HeroData resource
	match hero_id:
		"ranger":
			return {
				"damage": 25,
				"health": 200,
				"attack_speed": 1.5,  # attacks per second
				"range": 300,
				"defense": 0
			}
		_:
			return {
				"damage": 20,
				"health": 150,
				"attack_speed": 1.0,
				"range": 250,
				"defense": 0
			}


func _get_equipment_bonuses() -> Dictionary:
	"""Get bonuses from equipped items"""
	if not equipment_manager:
		return {
			"damage": 0,
			"health": 0,
			"attack_speed_mult": 1.0,
			"range": 0,
			"defense": 0,
			"crit_chance": 0.0
		}

	return {
		"damage": equipment_manager.get_damage_bonus(),
		"health": equipment_manager.get_health_bonus(),
		"attack_speed_mult": equipment_manager.get_attack_speed_multiplier(),
		"range": equipment_manager.get_range_bonus(),
		"defense": equipment_manager.get_defense_bonus(),
		"crit_chance": equipment_manager.get_crit_chance_bonus()
	}


func _get_skill_bonuses() -> Dictionary:
	"""Get bonuses from hero skills"""
	# TODO: Implement when skill system is integrated
	return {
		"damage": 0,
		"health": 0,
		"attack_speed_mult": 1.0,
		"range": 0,
		"defense": 0,
		"crit_chance": 0.0
	}
