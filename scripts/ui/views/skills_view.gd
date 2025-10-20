extends BasePanelView
class_name SkillsView

## SkillsView - Hero skills and abilities management
## Shows active and passive skills with unlock/upgrade options

signal skill_purchased(hero_id: String, skill_id: String)
signal skill_upgraded(hero_id: String, skill_id: String)

@export var hero_id: String = "ranger"

# UI References
@onready var currency_label: Label = $MarginContainer/VBoxContainer/Header/CurrencyLabel if has_node("MarginContainer/VBoxContainer/Header/CurrencyLabel") else null
@onready var active_skills_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SkillsVBox/ActiveSkillsSection/SkillsContainer if has_node("MarginContainer/VBoxContainer/ScrollContainer/SkillsVBox/ActiveSkillsSection/SkillsContainer") else null
@onready var passive_skills_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SkillsVBox/PassiveSkillsSection/SkillsContainer if has_node("MarginContainer/VBoxContainer/ScrollContainer/SkillsVBox/PassiveSkillsSection/SkillsContainer") else null

# Data
var available_skills: Array[HeroSkillData] = []
var current_currency: int = 0


func _ready():
	super._ready()
	view_name = "Skills"


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	_load_hero_skills()
	_refresh_display()


func set_hero_id(p_hero_id: String):
	"""Set which hero's skills to show"""
	hero_id = p_hero_id
	_load_hero_skills()
	_refresh_display()


func _load_hero_skills():
	"""Load available skills for this hero"""
	# TODO: Load from resources directory
	# For now, create placeholder skills
	available_skills.clear()

	# Example active skill
	var multishot = HeroSkillData.new()
	multishot.skill_id = "ranger_multishot"
	multishot.skill_name = "Multishot"
	multishot.description = "Fire 3 arrows at once"
	multishot.skill_type = HeroSkillData.SkillType.ACTIVE
	multishot.unlock_cost = 100
	multishot.max_upgrade_level = 3
	var multishot_costs: Array[int] = [150, 250]
	multishot.upgrade_costs = multishot_costs
	multishot.cooldown = 10.0
	available_skills.append(multishot)

	# Example passive skill
	var sharp_eye = HeroSkillData.new()
	sharp_eye.skill_id = "ranger_sharp_eye"
	sharp_eye.skill_name = "Sharp Eye"
	sharp_eye.description = "+20% damage"
	sharp_eye.skill_type = HeroSkillData.SkillType.PASSIVE
	sharp_eye.unlock_cost = 75
	sharp_eye.max_upgrade_level = 3
	var sharp_eye_costs: Array[int] = [100, 200]
	sharp_eye.upgrade_costs = sharp_eye_costs
	sharp_eye.damage_multiplier = 1.2
	available_skills.append(sharp_eye)


func _refresh_display():
	"""Update all UI elements"""
	# Update currency
	current_currency = SaveManager.get_currency()
	if currency_label:
		currency_label.text = "Gold: %d" % current_currency

	# Update skill lists
	_update_skill_list(active_skills_container, HeroSkillData.SkillType.ACTIVE)
	_update_skill_list(passive_skills_container, HeroSkillData.SkillType.PASSIVE)


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

	# Icon placeholder
	var placeholder = ColorRect.new()
	placeholder.custom_minimum_size = Vector2(50, 50)
	placeholder.color = Color(0.3, 0.5, 0.7)
	row.add_child(placeholder)

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
		unlock_button.text = "Unlock: %d Gold" % skill_data.unlock_cost
		unlock_button.custom_minimum_size = Vector2(120, 30)

		# Check if player can afford
		unlock_button.disabled = current_currency < skill_data.unlock_cost

		unlock_button.pressed.connect(_on_unlock_skill_pressed.bind(skill_data))
		button_vbox.add_child(unlock_button)
	else:
		# Show current level and upgrade button
		var level_label = Label.new()
		level_label.text = "Level: %d/%d" % [skill_level, skill_data.max_upgrade_level]
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button_vbox.add_child(level_label)

		if skill_level < skill_data.max_upgrade_level:
			var upgrade_cost = skill_data.get_upgrade_cost(skill_level)
			var upgrade_button = Button.new()
			upgrade_button.text = "Upgrade: %d Gold" % upgrade_cost
			upgrade_button.custom_minimum_size = Vector2(120, 30)

			# Check if player can afford
			upgrade_button.disabled = current_currency < upgrade_cost

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


func _on_unlock_skill_pressed(skill_data: HeroSkillData):
	"""Handle unlock skill button press"""
	var cost = skill_data.unlock_cost

	# Check if player can afford
	if current_currency < cost:
		print("Not enough currency to unlock ", skill_data.skill_name)
		return

	# Deduct currency
	SaveManager.add_currency(-cost)

	# Unlock skill in save data
	SaveManager.unlock_hero_skill(hero_id, skill_data.skill_id)

	# Emit signal
	skill_purchased.emit(hero_id, skill_data.skill_id)

	print("Unlocked skill: ", skill_data.skill_name, " for ", cost, " gold")

	# Refresh display
	_refresh_display()


func _on_upgrade_skill_pressed(skill_data: HeroSkillData):
	"""Handle upgrade skill button press"""
	var current_level = SaveManager.get_hero_skill_level(hero_id, skill_data.skill_id)
	var cost = skill_data.get_upgrade_cost(current_level)

	# Check if player can afford
	if current_currency < cost:
		print("Not enough currency to upgrade ", skill_data.skill_name)
		return

	# Deduct currency
	SaveManager.add_currency(-cost)

	# Upgrade skill in save data
	SaveManager.upgrade_hero_skill(hero_id, skill_data.skill_id)

	# Emit signal
	skill_upgraded.emit(hero_id, skill_data.skill_id)

	print("Upgraded skill: ", skill_data.skill_name, " to level ", current_level + 1)

	# Refresh display
	_refresh_display()
