extends Control
class_name HeroManagementPanel

## ============================================
## HERO MANAGEMENT PANEL - Map screen hero skills UI
## ============================================
##
## Accessible from world map, allows players to:
## - View hero meta level and XP progress
## - Allocate attribute points (MIGHT/AGILITY/VITALITY/WISDOM)
## - Unlock and upgrade skills
## - Spend currency earned from completing levels

signal skill_purchased(hero_id: String, skill_id: String)
signal skill_upgraded(hero_id: String, skill_id: String)
signal attribute_spent(hero_id: String, attribute: String)
signal closed()

# ============================================
# EXPORTS
# ============================================

@export var hero_id: String = "ranger" # Which hero this panel manages
@export var class_type: int = 1 # HeroClassConfig type (1 = Ranged)

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

# Meta Level UI
@onready var meta_level_label: Label = $Panel/VBox/MetaLevelSection/MetaLevelLabel
@onready var xp_progress_bar: ProgressBar = $Panel/VBox/MetaLevelSection/XPProgressBar
@onready var xp_label: Label = $Panel/VBox/MetaLevelSection/XPLabel

# Attribute UI
@onready var attribute_title_label: Label = $Panel/VBox/AttributeSection/AttributeTitle
@onready var might_value: Label = $Panel/VBox/AttributeSection/AttributeGrid/MightValue
@onready var might_plus: Button = $Panel/VBox/AttributeSection/AttributeGrid/MightPlus
@onready var agility_value: Label = $Panel/VBox/AttributeSection/AttributeGrid/AgilityValue
@onready var agility_plus: Button = $Panel/VBox/AttributeSection/AttributeGrid/AgilityPlus
@onready var vitality_value: Label = $Panel/VBox/AttributeSection/AttributeGrid/VitalityValue
@onready var vitality_plus: Button = $Panel/VBox/AttributeSection/AttributeGrid/VitalityPlus
@onready var wisdom_value: Label = $Panel/VBox/AttributeSection/AttributeGrid/WisdomValue
@onready var wisdom_plus: Button = $Panel/VBox/AttributeSection/AttributeGrid/WisdomPlus
@onready var respec_button: Button = $Panel/VBox/AttributeSection/RespecButton

# Skill sections
@onready var active_skills_container: VBoxContainer = $Panel/VBox/ScrollContainer/SkillsVBox/ActiveSkillsSection/SkillsContainer
@onready var passive_skills_container: VBoxContainer = $Panel/VBox/ScrollContainer/SkillsVBox/PassiveSkillsSection/SkillsContainer

# ============================================
# DATA
# ============================================

var available_skills: Array[HeroSkillData] = [] # All skills for this hero
var current_currency: int = 0
var current_class_config: HeroClassConfig = null

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

	# Connect attribute buttons
	_connect_attribute_buttons()

func _connect_attribute_buttons():
	if might_plus:
		might_plus.pressed.connect(_on_attribute_plus.bind("might"))
	if agility_plus:
		agility_plus.pressed.connect(_on_attribute_plus.bind("agility"))
	if vitality_plus:
		vitality_plus.pressed.connect(_on_attribute_plus.bind("vitality"))
	if wisdom_plus:
		wisdom_plus.pressed.connect(_on_attribute_plus.bind("wisdom"))
	if respec_button:
		respec_button.pressed.connect(_on_respec_pressed)

func _initialize_standalone():
	"""Initialize panel in standalone mode with skills from class config"""
	_load_class_skills()
	open_panel(hero_id, available_skills)

func _load_class_skills():
	"""Load skills from HeroClassDatabase instead of hardcoded values"""
	if HeroClassDatabase:
		current_class_config = HeroClassDatabase.get_class_config(class_type)
		if current_class_config and current_class_config.available_skill_pool.size() > 0:
			available_skills = current_class_config.available_skill_pool
			print("[HeroPanel] Loaded %d skills from HeroClassDatabase" % available_skills.size())
			return

	# Fallback to hardcoded skills if database not available
	print("[HeroPanel] HeroClassDatabase not available, using fallback skills")
	available_skills = _load_ranger_skills_fallback()

func open_panel(p_hero_id: String, skills: Array[HeroSkillData] = []):
	"""Open the panel with hero data"""
	# SAFETY CHECK: Ensure we have an active profile
	if not SaveManager.has_current_profile():
		push_error("[HeroPanel] Cannot open - no active profile loaded")
		return

	hero_id = p_hero_id

	# Use provided skills or load from class config
	if skills.is_empty():
		_load_class_skills()
	else:
		available_skills = skills

	# Update currency
	current_currency = SaveManager.get_gems()

	# Refresh display
	_refresh_display()

	# Show panel
	show()
	print("[HeroPanel] Opened for: ", hero_id)

func _load_ranger_skills_fallback() -> Array[HeroSkillData]:
	"""Fallback hardcoded skills if HeroClassDatabase unavailable"""
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

	return skills

func _refresh_display():
	"""Update all UI elements"""
	# Update title
	if title_label:
		title_label.text = "HERO: " + hero_id.to_upper()

	# Update currency
	if currency_label:
		currency_label.text = str(current_currency) + " Gems"

	# Update meta level display
	_update_meta_level_display()

	# Update attributes display
	_update_attributes_display()

	# Update hero info
	_update_hero_info()

	# Update skill lists
	_update_skill_list(active_skills_container, HeroSkillData.SkillType.ACTIVE)
	_update_skill_list(passive_skills_container, HeroSkillData.SkillType.PASSIVE)

# ============================================
# META LEVEL DISPLAY
# ============================================

func _update_meta_level_display():
	"""Update meta level and XP progress bar"""
	var progress = SaveManager.get_meta_xp_progress(hero_id)

	if meta_level_label:
		meta_level_label.text = "Meta Level %d" % progress["level"]
		if progress["is_max_level"]:
			meta_level_label.text += " (MAX)"

	if xp_progress_bar:
		if progress["is_max_level"]:
			xp_progress_bar.value = 100
			xp_progress_bar.max_value = 100
		else:
			xp_progress_bar.max_value = progress["required_xp"]
			xp_progress_bar.value = progress["current_xp"]

	if xp_label:
		if progress["is_max_level"]:
			xp_label.text = "MAX LEVEL"
		else:
			xp_label.text = "%d / %d XP" % [progress["current_xp"], progress["required_xp"]]

# ============================================
# ATTRIBUTE DISPLAY
# ============================================

func _update_attributes_display():
	"""Update attribute values and buttons"""
	var attrs = SaveManager.get_hero_attributes(hero_id)
	var unspent = SaveManager.get_unspent_attribute_points(hero_id)

	# Update title with available points
	if attribute_title_label:
		attribute_title_label.text = "ATTRIBUTES (%d points available)" % unspent
		if unspent > 0:
			attribute_title_label.add_theme_color_override("font_color", Color.GOLD)
		else:
			attribute_title_label.remove_theme_color_override("font_color")

	# Update attribute values
	if might_value:
		might_value.text = str(attrs.get("might", 0))
	if agility_value:
		agility_value.text = str(attrs.get("agility", 0))
	if vitality_value:
		vitality_value.text = str(attrs.get("vitality", 0))
	if wisdom_value:
		wisdom_value.text = str(attrs.get("wisdom", 0))

	# Enable/disable plus buttons based on available points
	var can_spend = unspent > 0
	if might_plus:
		might_plus.disabled = not can_spend
	if agility_plus:
		agility_plus.disabled = not can_spend
	if vitality_plus:
		vitality_plus.disabled = not can_spend
	if wisdom_plus:
		wisdom_plus.disabled = not can_spend

	# Update respec button
	_update_respec_button()

func _update_respec_button():
	"""Update respec button text and enabled state"""
	if not respec_button:
		return

	var meta_level = SaveManager.get_meta_level(hero_id)
	var spent = SaveManager.get_spent_attribute_points(hero_id)

	if meta_level < 10:
		respec_button.text = "Respec (Free)"
		respec_button.disabled = spent == 0
	else:
		respec_button.text = "Respec (Free)" # Always free now
		respec_button.disabled = spent == 0

func _update_hero_info():
	"""Update hero portrait and stats"""
	if hero_name_label:
		hero_name_label.text = hero_id.capitalize()

	if stats_label:
		# Show computed stats based on attributes
		var attrs = SaveManager.get_hero_attributes(hero_id)
		var base_hp = 200
		var base_dmg = 25

		# Apply attribute bonuses (simplified display)
		var hp_bonus = attrs.get("might", 0) * 5 + attrs.get("vitality", 0) * 10
		var dmg_bonus = attrs.get("might", 0) * 2
		var as_bonus = attrs.get("agility", 0) * 0.5

		stats_label.text = "HP: %d  |  DMG: %d  |  AS: +%.0f%%" % [
			base_hp + hp_bonus,
			base_dmg + dmg_bonus,
			as_bonus
		]

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

	# Handle empty skill pool gracefully
	if available_skills.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No skills available for this class"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		container.add_child(empty_label)
		return

	# Filter skills by type (with null check)
	var filtered_skills = available_skills.filter(func(skill): return skill != null and skill.skill_type == skill_type)

	# Create skill rows
	for skill_data in filtered_skills:
		if skill_data == null:
			continue
		var skill_row = _create_skill_row(skill_data)
		if skill_row:
			container.add_child(skill_row)

func _create_skill_row(skill_data: HeroSkillData) -> Control:
	"""Create a row UI for a single skill"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)

	# Icon placeholder
	var placeholder = ColorRect.new()
	placeholder.custom_minimum_size = Vector2(40, 40)
	placeholder.color = Color(0.3, 0.5, 0.7) if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else Color(0.5, 0.7, 0.3)
	row.add_child(placeholder)

	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = skill_data.skill_name
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = skill_data.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(200, 0)
	info_vbox.add_child(desc_label)

	row.add_child(info_vbox)

	# Button section
	var button_vbox = VBoxContainer.new()

	# Check if skill is owned
	var skill_level = SaveManager.get_hero_skill_level(hero_id, skill_data.skill_id)
	var is_owned = skill_level > 0

	# Check meta level requirement
	var meta_level = SaveManager.get_meta_level(hero_id)
	var meets_level_req = meta_level >= skill_data.required_hero_level

	if not is_owned:
		# Show unlock button
		var unlock_button = Button.new()
		unlock_button.custom_minimum_size = Vector2(100, 28)

		if skill_data.unlock_cost == 0:
			unlock_button.text = "Unlock Free"
		else:
			unlock_button.text = "Unlock: %d" % skill_data.unlock_cost

		# Check requirements
		var can_unlock = meets_level_req and current_currency >= skill_data.unlock_cost
		unlock_button.disabled = not can_unlock

		if not meets_level_req:
			unlock_button.text = "Lv %d Req" % skill_data.required_hero_level
			unlock_button.modulate = Color(0.5, 0.5, 0.5)
		elif not can_unlock:
			unlock_button.modulate = Color(0.6, 0.6, 0.6)

		unlock_button.pressed.connect(_on_unlock_skill_pressed.bind(skill_data))
		button_vbox.add_child(unlock_button)
	else:
		# Show current level and upgrade button
		var level_label = Label.new()
		level_label.text = "Lv %d/%d" % [skill_level, skill_data.max_upgrade_level]
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.add_theme_color_override("font_color", Color.GREEN)
		button_vbox.add_child(level_label)

		if skill_level < skill_data.max_upgrade_level:
			var upgrade_cost = skill_data.get_upgrade_cost(skill_level)
			var upgrade_button = Button.new()
			upgrade_button.text = "+" + str(upgrade_cost)
			upgrade_button.custom_minimum_size = Vector2(80, 26)

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
			max_label.text = "MAX"
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			max_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			button_vbox.add_child(max_label)

	row.add_child(button_vbox)

	return row

# ============================================
# ATTRIBUTE HANDLERS
# ============================================

func _on_attribute_plus(attribute: String):
	"""Handle attribute + button press"""
	if HeroMetaManager.spend_attribute_point(hero_id, attribute):
		attribute_spent.emit(hero_id, attribute)
		_refresh_display()
		_show_purchase_feedback()
		print("[HeroPanel] Spent point on %s" % attribute)

func _on_respec_pressed():
	"""Handle respec button press"""
	# Free respec (Proposal 2)
	if HeroMetaManager.respec_attributes(hero_id):
		current_currency = SaveManager.get_gems()
		_refresh_display()
		print("[HeroPanel] Respecced attributes (Free)")

# ============================================
# SKILL BUTTON HANDLERS
# ============================================

func _on_unlock_skill_pressed(skill_data: HeroSkillData):
	"""Handle unlock skill button press"""
	
	# HeroMetaManager handles cost check and deduction
	if HeroMetaManager.unlock_hero_skill(hero_id, skill_data):
		current_currency = SaveManager.get_gems()
		
		# Handle branch choice for multishot/sniper (Legacy check - should be moved to manager eventually)
		if skill_data.skill_id == "ranger_multishot":
			SaveManager.set_branch_choice(hero_id, "multishot")
		elif skill_data.skill_id == "ranger_sniper_shot":
			SaveManager.set_branch_choice(hero_id, "sniper")

		# Emit signal
		skill_purchased.emit(hero_id, skill_data.skill_id)

		print("[HeroPanel] Unlocked skill: ", skill_data.skill_name)

		# Refresh display
		_refresh_display()

		# Visual feedback
		_show_purchase_feedback()
	else:
		print("[HeroPanel] Failed to unlock ", skill_data.skill_name)
		_show_error_feedback("Cannot unlock!")

func _on_upgrade_skill_pressed(skill_data: HeroSkillData):
	"""Handle upgrade skill button press"""
	
	# HeroMetaManager handles cost check and deduction
	if HeroMetaManager.upgrade_hero_skill(hero_id, skill_data):
		current_currency = SaveManager.get_gems()

		# Emit signal
		skill_upgraded.emit(hero_id, skill_data.skill_id)

		var current_level = SaveManager.get_hero_skill_level(hero_id, skill_data.skill_id)
		print("[HeroPanel] Upgraded skill: ", skill_data.skill_name, " to level ", current_level)

		# Refresh display
		_refresh_display()

		# Visual feedback
		_show_purchase_feedback()
	else:
		print("[HeroPanel] Failed to upgrade ", skill_data.skill_name)
		_show_error_feedback("Cannot upgrade!")

func _on_close_pressed():
	"""Handle close button press"""
	hide()
	closed.emit()

func _on_back_button_pressed():
	"""Return to world map (used in standalone scene mode)"""
	print("[HeroPanel] Back button pressed - returning to world map")
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

func _show_error_feedback(message: String):
	"""Show error message to player"""
	print("[HeroPanel] Error: ", message)

	# Shake animation
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
