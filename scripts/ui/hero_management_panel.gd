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
signal hero_changed(new_hero_id: String)
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
@onready var hero_portrait: ColorRect = $Panel/VBox/ContentHBox/LeftColumn/HeroInfo/Portrait
@onready var hero_name_label: Label = $Panel/VBox/ContentHBox/LeftColumn/HeroInfo/VBox/NameLabel
@onready var stats_label: Label = $Panel/VBox/ContentHBox/LeftColumn/HeroInfo/VBox/StatsLabel
@onready var currency_label: Label = $Panel/VBox/TitleBar/CurrencyLabel

# Meta Level UI
@onready var meta_level_label: Label = $Panel/VBox/ContentHBox/LeftColumn/MetaLevelSection/MetaLevelLabel
@onready var xp_progress_bar: ProgressBar = $Panel/VBox/ContentHBox/LeftColumn/MetaLevelSection/XPProgressBar
@onready var xp_label: Label = $Panel/VBox/ContentHBox/LeftColumn/MetaLevelSection/XPLabel

# Attribute UI
@onready var attribute_title_label: Label = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeTitle
@onready var might_value: Label = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/MightValue
@onready var might_plus: Button = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/MightPlus
@onready var agility_value: Label = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/AgilityValue
@onready var agility_plus: Button = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/AgilityPlus
@onready var vitality_value: Label = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/VitalityValue
@onready var vitality_plus: Button = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/VitalityPlus
@onready var wisdom_value: Label = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/WisdomValue
@onready var wisdom_plus: Button = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/AttributeGrid/WisdomPlus
@onready var respec_button: Button = $Panel/VBox/ContentHBox/LeftColumn/AttributeSection/RespecButton

# Loadout UI (NEW - Unified System)
# Loadout UI (NEW - Unified System)
@onready var unified_hero_widget = _find_unified_widget()

func _find_unified_widget() -> Control:
	if has_node("Panel/VBox/LoadoutSection/UnifiedHeroWidget"):
		return $Panel/VBox/LoadoutSection/UnifiedHeroWidget
	elif has_node("Panel/VBox/ContentHBox/RightColumn/LoadoutSection/UnifiedHeroWidget"):
		return $Panel/VBox/ContentHBox/RightColumn/LoadoutSection/UnifiedHeroWidget
	return null

# Hero switcher buttons
@onready var archer_button = $Panel/VBox/TitleBar/HeroButtonsContainer/ArcherButton if has_node("Panel/VBox/TitleBar/HeroButtonsContainer/ArcherButton") else null
@onready var warrior_button = $Panel/VBox/TitleBar/HeroButtonsContainer/WarriorButton if has_node("Panel/VBox/TitleBar/HeroButtonsContainer/WarriorButton") else null
@onready var wizard_button = $Panel/VBox/TitleBar/HeroButtonsContainer/WizardButton if has_node("Panel/VBox/TitleBar/HeroButtonsContainer/WizardButton") else null

# Skill sections
@onready var active_skills_container: VBoxContainer = $Panel/VBox/ContentHBox/RightColumn/ScrollContainer/SkillsVBox/ActiveSkillsSection/SkillsContainer
@onready var passive_skills_container: VBoxContainer = $Panel/VBox/ContentHBox/RightColumn/ScrollContainer/SkillsVBox/PassiveSkillsSection/SkillsContainer

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

	# Setup hero switcher buttons
	_setup_hero_buttons()
	
	# Connect Unified Widget signal
	if has_node("Panel/VBox/LoadoutSection/UnifiedHeroWidget"):
		var widget = $Panel/VBox/LoadoutSection/UnifiedHeroWidget
		if not widget.skill_changed.is_connected(_refresh_display):
			widget.skill_changed.connect(_refresh_display)

	# Defer layout debug to ensure sizes are calculated
	call_deferred("_debug_layout")

func _debug_layout():
	print("--- LAYOUT DEBUG ---")
	print("Panel Size: ", size)

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

func _setup_hero_buttons():
	"""Configure hero portrait buttons"""
	# Archer/Ranger button
	if archer_button:
		archer_button.pressed.connect(_on_hero_button_pressed.bind("ranger"))
		var ranger_data = HeroDatabase.get_hero("ranger")
		if ranger_data and ranger_data.portrait:
			archer_button.text = ""
			archer_button.icon = ranger_data.portrait
			archer_button.expand_icon = true

	# Warrior button
	if warrior_button:
		warrior_button.pressed.connect(_on_hero_button_pressed.bind("warrior"))
		var warrior_data = HeroDatabase.get_hero("warrior")
		if warrior_data and warrior_data.portrait:
			warrior_button.text = ""
			warrior_button.icon = warrior_data.portrait
			warrior_button.expand_icon = true

	# Wizard/Mage button
	if wizard_button:
		wizard_button.pressed.connect(_on_hero_button_pressed.bind("mage"))
		var mage_data = HeroDatabase.get_hero("mage")
		if mage_data and mage_data.portrait:
			wizard_button.text = ""
			wizard_button.icon = mage_data.portrait
			wizard_button.expand_icon = true

	print("[HeroManagementPanel] Hero switcher buttons configured")

func _on_hero_button_pressed(new_hero_id: String):
	"""Called when a hero selection button is pressed"""
	print("\n" + "=".repeat(60))
	print("[HeroManagementPanel] 🔄 HERO SWITCH TRIGGERED")
	print("=".repeat(60))
	print("  From: %s (class_type: %d)" % [hero_id, class_type])
	print("  To:   %s" % new_hero_id)

	# Update hero_id and refresh display
	if new_hero_id != hero_id:
		hero_id = new_hero_id

		# FIX: Update class_type and reload skills!
		var hero_data = HeroDatabase.get_hero(hero_id)
		if hero_data:
			var old_class = class_type
			class_type = hero_data.hero_class # Update the class type (0=Melee, 1=Ranged, etc.)
			print("  ✅ Hero data loaded: %s" % hero_data.hero_name)
			print("  📊 Class type changed: %d → %d" % [old_class, class_type])

			# Reload skills
			var old_skill_count = available_skills.size()
			_load_class_skills() # Reload available_skills for the new class
			print("  🎯 Skills reloaded: %d → %d skills" % [old_skill_count, available_skills.size()])
		else:
			print("  ❌ ERROR: Hero data not found for %s" % hero_id)
	else:
		print("  ℹ️  Already on this hero, refreshing display")

	# Emit signal for other panels to listen
	print("  📡 Emitting hero_changed signal...")
	hero_changed.emit(new_hero_id)

	# Refresh the panel display for new hero
	print("  🔄 Refreshing display...")
	_refresh_display()

	# Refresh Loadout Widget
	if unified_hero_widget and unified_hero_widget.has_method("setup"):
		unified_hero_widget.setup(hero_id, HeroCommandWidget.Mode.LOADOUT)
		print("    ✅ Unified Widget refreshed")

	print("=".repeat(60))
	print("[HeroManagementPanel] ✅ HERO SWITCH COMPLETE")
	print("=".repeat(60) + "\n")

func _initialize_standalone():
	"""Initialize panel in standalone mode with skills from class config"""
	_load_class_skills()
	open_panel(hero_id, available_skills)

func _load_class_skills():
	"""Load skills from HeroClassDatabase instead of hardcoded values"""
	print("\n" + "-".repeat(60))
	print("[HeroPanel] 📚 LOADING CLASS SKILLS")
	print("-".repeat(60))
	print("  🎯 Target class_type: %d" % class_type)
	print("  🏷️  Class name: %s" % ["Melee", "Ranged", "Magic", "Support"][class_type] if class_type < 4 else "Unknown")

	if HeroClassDatabase:
		print("  ✅ HeroClassDatabase available")
		current_class_config = HeroClassDatabase.get_class_config(class_type)

		if current_class_config:
			print("  ✅ Class config found")
			var pool_size = current_class_config.available_skill_pool.size()
			print("  📊 Skill pool size: %d" % pool_size)

			if pool_size > 0:
				available_skills = current_class_config.available_skill_pool
				print("  ✅ Skills loaded successfully!")
				print("  📋 Skill breakdown:")

				var active_count = 0
				var passive_count = 0
				for skill in available_skills:
					if skill:
						if skill.skill_type == HeroSkillData.SkillType.ACTIVE:
							active_count += 1
							print("    🗡️  [ACTIVE] %s" % skill.skill_name)
						else:
							passive_count += 1
							print("    🛡️  [PASSIVE] %s" % skill.skill_name)

				print("  📈 Summary: %d active, %d passive" % [active_count, passive_count])
				print("-".repeat(60) + "\n")
				return
			else:
				print("  ⚠️  Skill pool is empty!")
		else:
			print("  ❌ Class config not found for class_type %d" % class_type)
	else:
		print("  ❌ HeroClassDatabase not available")

	# Fallback to hardcoded skills if database not available
	print("  🔄 Using fallback skills (Ranger default)")
	available_skills = _load_ranger_skills_fallback()
	print("  📊 Loaded %d fallback skills" % available_skills.size())
	print("-".repeat(60) + "\n")

func open_panel(p_hero_id: String, skills: Array[HeroSkillData] = []):
	"""Open the panel with hero data"""
	# SAFETY CHECK: Ensure we have an active profile
	if not SaveManager.has_current_profile():
		push_error("[HeroPanel] Cannot open - no active profile loaded")
		return

	hero_id = p_hero_id

	# Emit signal for consistency
	hero_changed.emit(hero_id)

	# Use provided skills or load from class config
	if skills.is_empty():
		_load_class_skills()
	else:
		available_skills = skills

	# Update currency
	current_currency = SaveManager.get_gems()

	# Setup Unified Widget
	if unified_hero_widget and unified_hero_widget.has_method("setup"):
		unified_hero_widget.setup(hero_id, HeroCommandWidget.Mode.LOADOUT)
		print("[HeroPanel] ✅ Setup Unified Hero Widget")

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
	print("\n" + "~".repeat(60))
	print("[HeroPanel] 🎨 REFRESHING DISPLAY")
	print("~".repeat(60))
	print("  👤 Hero: %s" % hero_id)
	print("  🎓 Class type: %d (%s)" % [class_type, ["Melee", "Ranged", "Magic", "Support"][class_type] if class_type < 4 else "Unknown"])
	print("  💎 Currency: %d gems" % current_currency)
	print("  📚 Available skills: %d" % available_skills.size())

	# Update title
	if title_label:
		title_label.text = "HERO: " + hero_id.to_upper()
		print("  ✅ Title updated")
	else:
		print("  ⚠️  Title label not found")

	# Update currency
	if currency_label:
		currency_label.text = str(current_currency) + " Gems"
		print("  ✅ Currency updated")
	else:
		print("  ⚠️  Currency label not found")

	# Update meta level display
	print("  🔄 Updating meta level...")
	_update_meta_level_display()

	# Update attributes display
	print("  🔄 Updating attributes...")
	_update_attributes_display()

	# Update hero info
	print("  🔄 Updating hero info...")
	_update_hero_info()

	# Update skill lists
	print("  🔄 Updating active skills list...")
	_update_skill_list(active_skills_container, HeroSkillData.SkillType.ACTIVE)
	print("  🔄 Updating passive skills list...")
	_update_skill_list(passive_skills_container, HeroSkillData.SkillType.PASSIVE)

	print("~".repeat(60))
	print("[HeroPanel] ✅ DISPLAY REFRESH COMPLETE")
	print("~".repeat(60) + "\n")

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
		push_error("[HeroPanel] ❌ Container is NULL in _update_skill_list!")
		return

	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# Handle empty skill pool gracefully
	if available_skills.is_empty():
		print("[HeroPanel] ⚠️  available_skills is EMPTY - showing placeholder")
		var empty_label = Label.new()
		empty_label.text = "No skills available for this class"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		container.add_child(empty_label)
		return

	# Filter skills by type (with null check)
	var filtered_skills = available_skills.filter(func(skill): return skill != null and skill.skill_type == skill_type)

	print("[HeroPanel] 🔍 Filtered %d skills of type %s" % [
		filtered_skills.size(),
		"ACTIVE" if skill_type == HeroSkillData.SkillType.ACTIVE else "PASSIVE"
	])

	# Create skill rows
	for skill_data in filtered_skills:
		print("[HeroPanel] 🎯 Creating row for: %s" % skill_data.skill_name)
		if skill_data == null:
			continue
		var skill_row = _create_skill_row(skill_data)
		if skill_row:
			container.add_child(skill_row)
			print("[HeroPanel] ✅ Added skill row to container")
		else:
			print("[HeroPanel] ❌ Failed to create skill row!")

func _create_skill_row(skill_data: HeroSkillData) -> Control:
	"""Create a row UI for a single skill"""
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)

	# Icon - Make draggable using SkillIcon component (NEW - Skill Loadout System)
	var skill_icon_scene = load("res://scenes/ui/skill_icon.tscn")
	print("[HeroPanel] 📦 Loading skill_icon.tscn: %s" % ("SUCCESS" if skill_icon_scene else "FAILED"))

	if skill_icon_scene:
		var skill_icon = skill_icon_scene.instantiate() as SkillIcon
		print("[HeroPanel] 🔨 Instantiating SkillIcon: %s (type: %s)" % [
			"SUCCESS" if skill_icon else "FAILED",
			skill_icon.get_script().get_global_name() if skill_icon.get_script() else "null"
		])

		if not skill_icon:
			push_error("[HeroPanel] ❌ CRITICAL: SkillIcon instantiation FAILED for %s" % skill_data.skill_name)
			push_error("  → Skill will show as placeholder with text label")

			# Create visible error placeholder (RED to indicate error)
			var placeholder = ColorRect.new()
			placeholder.custom_minimum_size = Vector2(40, 40)
			placeholder.color = Color(0.8, 0.2, 0.2, 1.0) # Red error color
			row.add_child(placeholder)

			# Add error label so user can SEE the skill exists
			var error_info = VBoxContainer.new()
			error_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var error_name_label = Label.new()
			error_name_label.text = skill_data.skill_name + " (ERROR: Icon failed)"
			error_name_label.add_theme_color_override("font_color", Color.RED)
			error_name_label.add_theme_font_size_override("font_size", 14)
			error_info.add_child(error_name_label)

			var error_desc_label = Label.new()
			error_desc_label.text = skill_data.description
			error_desc_label.add_theme_font_size_override("font_size", 11)
			error_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			error_info.add_child(error_desc_label)

			row.add_child(error_info)

			# DON'T return early - continue to add buttons below
		else:
			skill_icon.setup(skill_data.skill_id, skill_data, hero_id)
			skill_icon.source_slot_index = -1 # -1 indicates dragging from skill list
			skill_icon.source_slot_type = "active" if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else "passive"
			skill_icon.custom_minimum_size = Vector2(50, 50)
			row.add_child(skill_icon)
	else:
		# Fallback to old placeholder if scene not found
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

# ============================================
# SKILL EQUIPPED CALLBACK (Drag-Drop Fix)
# ============================================

func _on_skill_equipped(slot_index: int, skill_id: String):
	"""Called when a skill is equipped via drag-and-drop"""
	print("[HeroPanel] 🎯 Skill equipped: %s to slot %d - refreshing display" % [skill_id, slot_index])
	# Small delay to let SaveManager complete
	await get_tree().create_timer(0.05).timeout
	_refresh_display()
