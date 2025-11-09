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

# equipment_manager removed - now using HeroEquipmentRegistry


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
	"""Setup registry integration (renamed for compatibility)"""
	# Register hero if needed
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)


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
	"""Show detailed stat breakdown using NEW unified Stat system"""
	if not stats_text:
		return

	var text = "[center][b]DETAILED STATISTICS[/b][/center]\n\n"

	# Try to find hero in scene to read actual stats
	var hero = _find_hero()

	if hero:
		# HERO FOUND: Display actual stats from hero's Stat objects
		text += "[b]RANGED DAMAGE[/b]\n"
		text += "  Base: %.1f\n" % hero.BASE_RANGED_DAMAGE
		text += "  [b]Total: %.1f[/b]\n\n" % hero.ranged_damage

		text += "[b]HEALTH[/b]\n"
		text += "  Base: %.0f\n" % hero.BASE_MAX_HEALTH
		text += "  [b]Total: %.0f[/b]\n" % hero.max_health
		text += "  Current: %.0f\n\n" % hero.current_health

		text += "[b]ATTACK SPEED[/b]\n"
		text += "  Base: %.2f cooldown\n" % hero.BASE_RANGED_ATTACK_SPEED
		text += "  [b]Total: %.2f cooldown[/b]\n" % hero.ranged_attack_speed
		text += "  (%.1f attacks/sec)\n\n" % (1.0 / hero.ranged_attack_speed)

		text += "[b]RANGE[/b]\n"
		text += "  Base: %.0f\n" % hero.BASE_RANGED_RANGE
		text += "  [b]Total: %.0f[/b]\n\n" % hero.ranged_range

		text += "[b]MELEE DAMAGE[/b]\n"
		text += "  Base: %.1f\n" % hero.BASE_MELEE_DAMAGE
		text += "  [b]Total: %.1f[/b]\n\n" % hero.melee_damage

		text += "[b]MOVEMENT SPEED[/b]\n"
		text += "  Base: %.0f\n" % hero.BASE_MOVEMENT_SPEED
		text += "  [b]Total: %.0f[/b]\n\n" % hero.movement_speed

		# Show equipment modifiers
		# Get equipment modifiers from registry
		var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
		var modifiers: Array[StatModifier] = []
		for item_id in equipped_items.values():
			if item_id != "":
				var item_data = ItemDatabase.get_item(item_id)
				if item_data:
					var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)
					modifiers.append_array(item_data.get_stat_modifiers(upgrade_level))
		if not modifiers.is_empty():
			text += "[color=green][b]EQUIPMENT MODIFIERS[/b][/color]\n"
			for mod in modifiers:
				text += "  • %s\n" % _format_modifier(mod)
			text += "\n"

		# Show skill modifiers (if skill manager exists)
		if hero.has_node("SkillManager"):
			var skill_manager = hero.get_node("SkillManager")
			var skill_mods = skill_manager.get_passive_skill_modifiers()
			if not skill_mods.is_empty():
				text += "[color=cyan][b]SKILL MODIFIERS[/b][/color]\n"
				for mod in skill_mods:
					text += "  • %s\n" % _format_modifier(mod)
				text += "\n"

	else:
		# HERO NOT IN SCENE: Display placeholder message
		text += "[color=gray]Hero not currently deployed[/color]\n\n"
		text += "Equipment bonuses will apply when hero is deployed.\n\n"

		# Get equipment modifiers from registry
		var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
		var modifiers: Array[StatModifier] = []
		for item_id in equipped_items.values():
			if item_id != "":
				var item_data = ItemDatabase.get_item(item_id)
				if item_data:
					var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)
					modifiers.append_array(item_data.get_stat_modifiers(upgrade_level))
		if not modifiers.is_empty():
			text += "[color=green][b]EQUIPPED MODIFIERS[/b][/color]\n"
			for mod in modifiers:
				text += "  • %s\n" % _format_modifier(mod)

	stats_text.text = text


func _find_hero():
	"""Find the hero in the scene tree"""
	var heroes = get_tree().get_nodes_in_group("hero")
	for hero in heroes:
		if hero.has_method("get_hero_id") and hero.get_hero_id() == hero_id:
			return hero
	return null


func _format_modifier(mod: StatModifier) -> String:
	"""Format a modifier for display"""
	match mod.type:
		StatModifier.ModifierType.FLAT:
			return "+%.0f %s" % [mod.value, mod.description]
		StatModifier.ModifierType.ADDITIVE:
			return "+%.0f%% %s" % [mod.value * 100, mod.description]
		StatModifier.ModifierType.MULTIPLICATIVE:
			return "×%.2f %s" % [mod.value, mod.description]
	return mod.description
