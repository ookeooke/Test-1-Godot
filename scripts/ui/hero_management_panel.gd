extends Control
class_name HeroManagementPanel

## ============================================
## HERO MANAGEMENT PANEL - Map screen hero skills UI
## ============================================
##
## Accessible from world map, allows players to:
## - View hero stats
## - Unlock and upgrade skills
## - Spend currency earned from completing levels

signal skill_purchased(hero_id: String, skill_id: String)
signal skill_upgraded(hero_id: String, skill_id: String)
signal closed()

# ============================================
# EXPORTS
# ============================================

@export var hero_id: String = "ranger"  # Which hero this panel manages

# ============================================
# UI REFERENCES
# ============================================

@onready var title_label: Label = $Panel/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $Panel/VBox/TitleBar/CloseButton if has_node("Panel/VBox/TitleBar/CloseButton") else null
@onready var back_button: Button = $Panel/VBox/TitleBar/BackButton if has_node("Panel/VBox/TitleBar/BackButton") else null
@onready var hero_portrait: ColorRect = $Panel/VBox/HeroInfo/Portrait
@onready var hero_name_label: Label = $Panel/VBox/HeroInfo/VBox/NameLabel
@onready var stats_label: Label = $Panel/VBox/HeroInfo/VBox/StatsLabel
@onready var currency_label: Label = $Panel/VBox/TitleBar/CurrencyLabel

# Skill sections
@onready var active_skills_container: VBoxContainer = $Panel/VBox/ScrollContainer/SkillsVBox/ActiveSkillsSection/SkillsContainer
@onready var passive_skills_container: VBoxContainer = $Panel/VBox/ScrollContainer/SkillsVBox/PassiveSkillsSection/SkillsContainer

# ============================================
# DATA
# ============================================

var available_skills: Array[HeroSkillData] = []  # All skills for this hero
var current_currency: int = 0

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Connect signals
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		# Standalone mode - auto-initialize with skills
		print("[HeroPanel] Standalone mode - auto-loading skills")
		_initialize_standalone()
	else:
		# Overlay mode - hide and wait for open_panel() call
		hide()

func _initialize_standalone():
	"""Initialize panel in standalone mode with default skills"""
	var ranger_skills = _load_ranger_skills()
	open_panel("ranger", ranger_skills)

func open_panel(p_hero_id: String, skills: Array[HeroSkillData]):
	"""Open the panel with hero data"""
	hero_id = p_hero_id
	available_skills = skills

	# Update currency
	current_currency = SaveManager.get_gems()

	# Refresh display
	_refresh_display()

	# Show panel
	show()
	print("📋 HeroManagementPanel opened for: ", hero_id)

func _load_ranger_skills() -> Array[HeroSkillData]:
	"""Load all available skills for the ranger hero"""
	var skills: Array[HeroSkillData] = []

	# ACTIVE SKILL 1: Rapid Fire
	var rapid_fire = HeroSkillData.new()
	rapid_fire.skill_id = "rapid_fire"
	rapid_fire.skill_name = "Rapid Fire"
	rapid_fire.description = "Fire multiple arrows in quick succession"
	rapid_fire.skill_type = HeroSkillData.SkillType.ACTIVE
	rapid_fire.unlock_cost = 100
	rapid_fire.max_upgrade_level = 3
	rapid_fire.upgrade_costs.assign([50, 100])
	rapid_fire.cooldown = 30.0
	skills.append(rapid_fire)

	# ACTIVE SKILL 2: Power Shot
	var power_shot = HeroSkillData.new()
	power_shot.skill_id = "power_shot"
	power_shot.skill_name = "Power Shot"
	power_shot.description = "Charge up a powerful shot that deals 300% damage and pierces enemies"
	power_shot.skill_type = HeroSkillData.SkillType.ACTIVE
	power_shot.unlock_cost = 150
	power_shot.max_upgrade_level = 3
	power_shot.upgrade_costs.assign([75, 150])
	power_shot.cooldown = 45.0
	power_shot.damage_multiplier = 3.0
	skills.append(power_shot)

	# PASSIVE SKILL 1: Eagle Eye
	var eagle_eye = HeroSkillData.new()
	eagle_eye.skill_id = "eagle_eye"
	eagle_eye.skill_name = "Eagle Eye"
	eagle_eye.description = "+20% attack range per level"
	eagle_eye.skill_type = HeroSkillData.SkillType.PASSIVE
	eagle_eye.unlock_cost = 80
	eagle_eye.max_upgrade_level = 5
	eagle_eye.upgrade_costs.assign([40, 80, 120, 160])
	eagle_eye.range_bonus = 60.0
	skills.append(eagle_eye)

	# PASSIVE SKILL 2: Critical Strike
	var crit_strike = HeroSkillData.new()
	crit_strike.skill_id = "critical_strike"
	crit_strike.skill_name = "Critical Strike"
	crit_strike.description = "+5% critical hit chance per level (double damage)"
	crit_strike.skill_type = HeroSkillData.SkillType.PASSIVE
	crit_strike.unlock_cost = 120
	crit_strike.max_upgrade_level = 5
	crit_strike.upgrade_costs.assign([60, 120, 180, 240])
	crit_strike.crit_chance = 0.05
	skills.append(crit_strike)

	# PASSIVE SKILL 3: Attack Speed
	var attack_speed = HeroSkillData.new()
	attack_speed.skill_id = "attack_speed"
	attack_speed.skill_name = "Quick Draw"
	attack_speed.description = "+10% attack speed per level"
	attack_speed.skill_type = HeroSkillData.SkillType.PASSIVE
	attack_speed.unlock_cost = 100
	attack_speed.max_upgrade_level = 4
	attack_speed.upgrade_costs.assign([50, 100, 150])
	attack_speed.attack_speed_multiplier = 1.1
	skills.append(attack_speed)

	print("✅ Loaded %d skills for Ranger" % skills.size())
	return skills

func _refresh_display():
	"""Update all UI elements"""
	# Update title
	if title_label:
		title_label.text = "HERO: " + hero_id.to_upper()

	# Update currency
	if currency_label:
		currency_label.text = "💰 " + str(current_currency)

	# Update hero info
	_update_hero_info()

	# Update skill lists
	_update_skill_list(active_skills_container, HeroSkillData.SkillType.ACTIVE)
	_update_skill_list(passive_skills_container, HeroSkillData.SkillType.PASSIVE)

func _update_hero_info():
	"""Update hero portrait and stats"""
	# TODO: Get actual hero stats from save data or hero definition
	if hero_name_label:
		hero_name_label.text = hero_id.capitalize()

	if stats_label:
		# For now, show placeholder stats
		# In full implementation, load from HeroData resource
		stats_label.text = "Level: 1\nHealth: 200\nDamage: 25\nRange: 300"

	if hero_portrait:
		# Set color based on hero type
		match hero_id:
			"ranger":
				hero_portrait.color = Color(0.4, 0.6, 0.8)
			_:
				hero_portrait.color = Color(0.5, 0.5, 0.5)

func _update_skill_list(container: VBoxContainer, skill_type: HeroSkillData.SkillType):
	"""Populate a skill list container"""
	if not container:
		return

	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# Filter skills by type
	var filtered_skills = available_skills.filter(func(skill): return skill.skill_type == skill_type)

	# Create skill rows
	for skill_data in filtered_skills:
		var skill_row = _create_skill_row(skill_data)
		container.add_child(skill_row)

func _create_skill_row(skill_data: HeroSkillData) -> Control:
	"""Create a row UI for a single skill"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)

	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(50, 50)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	if skill_data.icon:
		icon.texture = skill_data.icon
	else:
		# Placeholder colored rectangle
		var placeholder = ColorRect.new()
		placeholder.custom_minimum_size = Vector2(50, 50)
		placeholder.color = Color(0.3, 0.5, 0.7)
		row.add_child(placeholder)
		icon.queue_free()
		icon = null

	if icon:
		row.add_child(icon)

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = skill_data.skill_name
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = skill_data.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(200, 0)
	info_vbox.add_child(desc_label)

	row.add_child(info_vbox)

	# Button section
	var button_vbox = VBoxContainer.new()

	# Check if skill is owned
	var skill_level = SaveManager.get_hero_skill_level(hero_id, skill_data.skill_id)
	var is_owned = skill_level > 0

	if not is_owned:
		# Show unlock button
		var unlock_button = Button.new()
		unlock_button.text = "Unlock: " + str(skill_data.unlock_cost) + " 💰"
		unlock_button.custom_minimum_size = Vector2(120, 30)

		# Check if player can afford
		if current_currency >= skill_data.unlock_cost:
			unlock_button.disabled = false
		else:
			unlock_button.disabled = true
			unlock_button.modulate = Color(0.6, 0.6, 0.6)

		unlock_button.pressed.connect(_on_unlock_skill_pressed.bind(skill_data))
		button_vbox.add_child(unlock_button)
	else:
		# Show current level and upgrade button
		var level_label = Label.new()
		level_label.text = "Level: " + str(skill_level) + "/" + str(skill_data.max_upgrade_level)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_vbox.add_child(level_label)

		if skill_level < skill_data.max_upgrade_level:
			var upgrade_cost = skill_data.get_upgrade_cost(skill_level)
			var upgrade_button = Button.new()
			upgrade_button.text = "Upgrade: " + str(upgrade_cost) + " 💰"
			upgrade_button.custom_minimum_size = Vector2(120, 30)

			# Check if player can afford
			if current_currency >= upgrade_cost:
				upgrade_button.disabled = false
			else:
				upgrade_button.disabled = true
				upgrade_button.modulate = Color(0.6, 0.6, 0.6)

			upgrade_button.pressed.connect(_on_upgrade_skill_pressed.bind(skill_data))
			button_vbox.add_child(upgrade_button)
		else:
			var max_label = Label.new()
			max_label.text = "MAX LEVEL"
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			button_vbox.add_child(max_label)

	row.add_child(button_vbox)

	return row

# ============================================
# BUTTON HANDLERS
# ============================================

func _on_unlock_skill_pressed(skill_data: HeroSkillData):
	"""Handle unlock skill button press"""
	var cost = skill_data.unlock_cost

	# Check if player can afford
	if current_currency < cost:
		print("❌ Not enough currency to unlock ", skill_data.skill_name)
		_show_error_feedback("Not enough gold!")
		return

	# Deduct currency
	SaveManager.add_gems(-cost)
	current_currency = SaveManager.get_gems()

	# Unlock skill in save data
	SaveManager.unlock_hero_skill(hero_id, skill_data.skill_id)

	# Emit signal
	skill_purchased.emit(hero_id, skill_data.skill_id)

	print("✅ Unlocked skill: ", skill_data.skill_name, " for ", cost, " gold")

	# Refresh display
	_refresh_display()

	# Visual feedback
	_show_purchase_feedback()

func _on_upgrade_skill_pressed(skill_data: HeroSkillData):
	"""Handle upgrade skill button press"""
	var current_level = SaveManager.get_hero_skill_level(hero_id, skill_data.skill_id)
	var cost = skill_data.get_upgrade_cost(current_level)

	# Check if player can afford
	if current_currency < cost:
		print("❌ Not enough currency to upgrade ", skill_data.skill_name)
		_show_error_feedback("Not enough gold!")
		return

	# Deduct currency
	SaveManager.add_gems(-cost)
	current_currency = SaveManager.get_gems()

	# Upgrade skill in save data
	SaveManager.upgrade_hero_skill(hero_id, skill_data.skill_id)

	# Emit signal
	skill_upgraded.emit(hero_id, skill_data.skill_id)

	print("⬆️ Upgraded skill: ", skill_data.skill_name, " to level ", current_level + 1)

	# Refresh display
	_refresh_display()

	# Visual feedback
	_show_purchase_feedback()

func _on_close_pressed():
	"""Handle close button press"""
	hide()
	closed.emit()

func _on_back_button_pressed():
	"""Return to world map (used in standalone scene mode)"""
	print("⬅️ [HeroScreen] Back button pressed - returning to world map")
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")

# ============================================
# VISUAL FEEDBACK
# ============================================

func _show_purchase_feedback():
	"""Play animation when skill is purchased/upgraded"""
	# Flash effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.0), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

	# Could also play a sound here
	print("💫 Purchase successful!")

func _show_error_feedback(message: String):
	"""Show error message to player"""
	# For now, just print
	# In full implementation, could show a popup or toast
	print("⚠️ ", message)

	# Shake animation
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
