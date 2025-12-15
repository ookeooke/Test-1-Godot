extends PanelContainer
class_name SkillTooltip

## ============================================================================
## SkillTooltip - Displays detailed skill information on hover
## ============================================================================
## Shows skill name, type, description, stats, and unlock/upgrade costs
## Used by TooltipManager for skill tooltips (matching item tooltip UX)

# UI References
@onready var vbox: VBoxContainer = $VBox
@onready var name_label: Label = $VBox/NameLabel
@onready var type_label: Label = $VBox/TypeLabel
@onready var separator1: HSeparator = $VBox/Separator1
@onready var description_label: Label = $VBox/DescriptionLabel
@onready var stats_container: VBoxContainer = $VBox/StatsContainer
@onready var separator2: HSeparator = $VBox/Separator2
@onready var cost_label: Label = $VBox/CostLabel

# Style constants
const ACTIVE_COLOR = Color("#3D7FFF")  # Blue for active skills
const PASSIVE_COLOR = Color("#4CAF50")  # Green for passive skills

# Label pool for stats (reused to prevent GC pressure)
var _stat_label_pool: Array[Label] = []
const MAX_STAT_LABELS: int = 12  # Max possible stat lines


func _ready():
	# Set initial style
	_apply_style()

	# Pre-create label pool (prevent GC pressure from dynamic creation)
	for i in range(MAX_STAT_LABELS):
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.visible = false
		stats_container.add_child(label)
		_stat_label_pool.append(label)


func set_skill(skill_data: HeroSkillData, current_level: int = 1, is_unlocked: bool = true):
	"""
	Populate tooltip with skill data

	Args:
		skill_data: The skill to display
		current_level: Current upgrade level of the skill
		is_unlocked: Whether the hero has unlocked this skill
	"""
	if not skill_data:
		push_error("[SkillTooltip] set_skill called with null skill_data")
		return

	# Skill name (with icon if available)
	name_label.text = skill_data.skill_name

	# Type and category
	var type_text = "Active" if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else "Passive"
	var category_text = _get_category_name(skill_data.category)
	type_label.text = "%s · %s" % [type_text, category_text]

	# Apply color based on type
	var accent_color = ACTIVE_COLOR if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else PASSIVE_COLOR
	name_label.add_theme_color_override("font_color", accent_color)

	# Description (with dynamic values filled in)
	description_label.text = skill_data.get_display_description(current_level)

	# Stats (show relevant stats based on skill type)
	_populate_stats(skill_data, current_level)

	# Cost/unlock status
	_populate_cost(skill_data, current_level, is_unlocked)

	# Adjust separator visibility
	separator2.visible = cost_label.visible


func _populate_stats(skill_data: HeroSkillData, level: int):
	"""Populate stats container with relevant skill statistics"""
	# Reset pool - hide all labels (reuse instead of destroy)
	for label in _stat_label_pool:
		label.visible = false

	var label_index = 0

	# Active skill stats
	if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE:
		if skill_data.cooldown > 0:
			var cooldown = skill_data.get_current_cooldown(level)
			_set_pooled_label(label_index, "Cooldown: %.1fs" % cooldown)
			label_index += 1

		if skill_data.duration > 0:
			var duration = skill_data.get_current_duration(level)
			_set_pooled_label(label_index, "Duration: %.1fs" % duration)
			label_index += 1

		if skill_data.mana_cost > 0:
			_set_pooled_label(label_index, "Mana Cost: %d" % skill_data.mana_cost)
			label_index += 1

		if skill_data.cast_range > 0:
			_set_pooled_label(label_index, "Range: %.0f" % skill_data.cast_range)
			label_index += 1

	# Passive skill bonuses
	if skill_data.skill_type == HeroSkillData.SkillType.PASSIVE:
		var dmg_mult = skill_data.get_current_damage_multiplier(level)
		if dmg_mult > 1.0:
			_set_pooled_label(label_index, "Damage: +%d%%" % int((dmg_mult - 1.0) * 100))
			label_index += 1

		if skill_data.attack_speed_multiplier > 1.0:
			_set_pooled_label(label_index, "Attack Speed: +%d%%" % int((skill_data.attack_speed_multiplier - 1.0) * 100))
			label_index += 1

		if skill_data.movement_speed_multiplier > 1.0:
			_set_pooled_label(label_index, "Move Speed: +%d%%" % int((skill_data.movement_speed_multiplier - 1.0) * 100))
			label_index += 1

		if skill_data.max_health_bonus > 0:
			_set_pooled_label(label_index, "Health: +%d" % int(skill_data.max_health_bonus))
			label_index += 1

		if skill_data.range_bonus > 0:
			_set_pooled_label(label_index, "Range: +%d" % int(skill_data.range_bonus))
			label_index += 1

		if skill_data.crit_chance > 0:
			_set_pooled_label(label_index, "Crit Chance: +%d%%" % int(skill_data.crit_chance * 100))
			label_index += 1

		if skill_data.lifesteal_percent > 0:
			_set_pooled_label(label_index, "Lifesteal: +%d%%" % int(skill_data.lifesteal_percent * 100))
			label_index += 1

		if skill_data.dodge_chance > 0:
			_set_pooled_label(label_index, "Dodge Chance: +%d%%" % int(skill_data.dodge_chance * 100))
			label_index += 1

		if skill_data.cooldown_reduction > 0:
			_set_pooled_label(label_index, "CDR: -%d%%" % int(skill_data.cooldown_reduction * 100))
			label_index += 1


func _populate_cost(skill_data: HeroSkillData, current_level: int, is_unlocked: bool):
	"""Show unlock cost or upgrade cost"""
	if not is_unlocked:
		cost_label.text = "💰 Unlock: %d gold" % skill_data.unlock_cost
		cost_label.visible = true
	elif current_level < skill_data.max_upgrade_level:
		var upgrade_cost = skill_data.get_upgrade_cost(current_level)
		if upgrade_cost > 0:
			cost_label.text = "💰 Upgrade to Lv%d: %d gold" % [current_level + 1, upgrade_cost]
			cost_label.visible = true
		else:
			cost_label.visible = false
	else:
		cost_label.text = "✅ Max Level"
		cost_label.visible = true


func _set_pooled_label(index: int, text: String):
	"""Reuse a label from the pool instead of creating new one"""
	if index >= _stat_label_pool.size():
		push_warning("[SkillTooltip] Label pool exhausted at index %d" % index)
		return

	var label = _stat_label_pool[index]
	label.text = text
	label.visible = true


func _get_category_name(category: HeroSkillData.SkillCategory) -> String:
	"""Convert category enum to display string"""
	match category:
		HeroSkillData.SkillCategory.COMBAT:
			return "Combat"
		HeroSkillData.SkillCategory.DEFENSE:
			return "Defense"
		HeroSkillData.SkillCategory.MOBILITY:
			return "Mobility"
		HeroSkillData.SkillCategory.UTILITY:
			return "Utility"
		_:
			return "Unknown"


func _apply_style():
	"""Apply visual style to tooltip panel"""
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color("#1A1A1AE6")  # Dark semi-transparent
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color("#444444")
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	stylebox.content_margin_left = 12
	stylebox.content_margin_right = 12
	stylebox.content_margin_top = 10
	stylebox.content_margin_bottom = 10

	add_theme_stylebox_override("panel", stylebox)
