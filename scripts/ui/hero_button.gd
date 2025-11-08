extends Button

## ============================================
## HERO BUTTON - Kingdom Rush Style (Simplified Single Layer)
## ============================================
##
## Displays hero portrait, health bar, and name in bottom-left corner.
## Click to select hero, then click world to move hero.
## Always same size regardless of camera zoom (CanvasLayer).
## Single Button node handles both visuals and interaction!

# REFERENCES
@onready var portrait = $Portrait
@onready var health_bar = $HealthBar

# Ability buttons container
var abilities_container: HBoxContainer = null
var ability_buttons: Array[AbilityButton] = []

# Stats popup
var stats_popup: HeroStatsPopup = null

# STATE
var hero_reference = null  # Reference to the actual hero in the game world
var is_selected = false

## ============================================
## INITIALIZATION
## ============================================

func _ready():
	print("HeroButton ready")

	# Create abilities container
	_setup_abilities_container()

	# Create stats popup
	_setup_stats_popup()

	# Apply scale-aware sizing
	_apply_ui_scale()

	# Visual feedback setup
	_update_selection_visual()

	# Listen for scale changes
	if UIScaleManager:
		UIScaleManager.scale_changed.connect(_on_ui_scale_changed)

func _setup_abilities_container():
	"""Create container for ability buttons"""
	# Create container below the panel
	abilities_container = HBoxContainer.new()
	abilities_container.name = "AbilitiesContainer"
	abilities_container.add_theme_constant_override("separation", 4)
	add_child(abilities_container)

	# Position above the hero button panel
	abilities_container.position = Vector2(0, -70)  # Above the hero panel

	print("✅ Abilities container created")

func _setup_stats_popup():
	"""Create stats popup panel"""
	stats_popup = HeroStatsPopup.new()
	stats_popup.name = "StatsPopup"
	add_child(stats_popup)

	# Position to the right of the hero button
	stats_popup.position = Vector2(100, 0)  # To the right

	print("✅ Stats popup created")

func _apply_ui_scale():
	"""Apply UI scale factor to ensure proper touch target size"""
	if not UIScaleManager:
		return

	# Base size at 1080p: 90x120 pixels
	var base_size = Vector2(90, 120)
	var scaled_size = UIScaleManager.get_scaled_size(base_size)

	# Ensure minimum touch target size (44dp)
	var min_size = Vector2(44, 44) * UIScaleManager.ui_scale
	scaled_size.x = max(scaled_size.x, min_size.x)
	scaled_size.y = max(scaled_size.y, min_size.y)

	custom_minimum_size = scaled_size
	size = scaled_size

	print("HeroButton scaled to: ", scaled_size, " (scale factor: ", UIScaleManager.ui_scale, ")")

func _on_ui_scale_changed(new_scale: float):
	"""Handle UI scale changes (e.g., window resize)"""
	_apply_ui_scale()

## ============================================
## HERO CONNECTION
## ============================================

func set_hero(hero):
	"""Connect this button to a hero in the game world"""
	if hero_reference:
		# Disconnect from old hero
		if hero_reference.has_signal("health_changed"):
			if hero_reference.health_changed.is_connected(_on_hero_health_changed):
				hero_reference.health_changed.disconnect(_on_hero_health_changed)

	hero_reference = hero

	if hero_reference and is_instance_valid(hero_reference):
		# Update display
		_update_hero_info()

		# Setup ability buttons
		_setup_ability_buttons()

		# Set hero for stats popup
		if stats_popup:
			stats_popup.set_hero(hero_reference)

		# Connect to health changes (if signal exists, otherwise poll)
		# Note: We'll update health every frame in _process for now
		print("HeroButton connected to hero: ", hero_reference.name)

func _update_hero_info():
	"""Update button display with hero information"""
	if not hero_reference or not is_instance_valid(hero_reference):
		return

	# Update health bar
	if "current_health" in hero_reference and "max_health" in hero_reference:
		var health_percent = (hero_reference.current_health / hero_reference.max_health) * 100.0
		health_bar.value = health_percent

	# Update portrait color (could be sprite later)
	# For now, use a color that represents the hero type
	portrait.color = Color(0.4, 0.6, 0.8, 1.0)  # Blue for ranger

## ============================================
## UPDATE LOOP
## ============================================

func _process(delta):
	# Update health bar every frame (simple approach)
	if hero_reference and is_instance_valid(hero_reference):
		if "current_health" in hero_reference and "max_health" in hero_reference:
			var health_percent = (hero_reference.current_health / hero_reference.max_health) * 100.0
			health_bar.value = health_percent

## ============================================
## BUTTON INTERACTION
## ============================================

func _on_button_pressed():
	"""Called when button is clicked"""
	print("🔘 HeroButton pressed signal triggered!")

	if not hero_reference:
		print("  ⚠ No hero reference set!")
		return

	if not is_instance_valid(hero_reference):
		print("  ⚠ Hero reference is invalid!")
		return

	print("  ✓ Hero reference valid: ", hero_reference.name)

	# Try to call the hero's select method directly
	if hero_reference.has_method("select"):
		print("  ✓ Calling hero.select()")
		hero_reference.select()

	# Also emit the hero_selected signal for HeroManager
	if hero_reference.has_signal("hero_selected"):
		print("  ✓ Emitting hero_selected signal")
		hero_reference.hero_selected.emit(hero_reference)
	else:
		print("  ⚠ Hero doesn't have hero_selected signal")

	# Update visual state
	set_selected(true)
	print("  ✓ Button visual state set to selected")

func set_selected(selected: bool):
	"""Update button visual state when hero is selected/deselected"""
	is_selected = selected
	_update_selection_visual()

	# Show/hide stats popup based on selection
	if stats_popup:
		if is_selected:
			stats_popup.show_stats()
		else:
			stats_popup.hide_stats()

func _update_selection_visual():
	"""Update visual appearance based on selection state"""
	if is_selected:
		# Highlighted border or glow
		modulate = Color(1.3, 1.3, 1.0)  # Yellow tint
	else:
		# Normal appearance
		modulate = Color(1.0, 1.0, 1.0)

## ============================================
## CALLBACKS
## ============================================

func _on_hero_health_changed(current_health, max_health):
	"""Called when hero health changes (if signal exists)"""
	var health_percent = (current_health / max_health) * 100.0
	health_bar.value = health_percent

## ============================================
## ABILITY BUTTONS
## ============================================

func _setup_ability_buttons():
	"""Create ability buttons for hero's active skills"""
	if not hero_reference or not is_instance_valid(hero_reference):
		return

	# Clear existing buttons
	for btn in ability_buttons:
		btn.queue_free()
	ability_buttons.clear()

	# Get skill manager from hero
	if not hero_reference.has_node("SkillManager"):
		print("⚠️ HeroButton: Hero has no SkillManager")
		return

	var skill_manager = hero_reference.get_node("SkillManager")

	# Get all owned skills
	var owned_skills = skill_manager.owned_skills
	if owned_skills.is_empty():
		print("📝 HeroButton: No skills owned yet")
		return

	# Create button for each active skill
	var hotkey_index = 1
	for skill_id in owned_skills.keys():
		var skill_data = skill_manager.get_skill_data(skill_id)

		if not skill_data:
			continue

		# Only create buttons for active skills
		if skill_data.skill_type != HeroSkillData.SkillType.ACTIVE:
			continue

		# Create ability button
		var ability_btn = AbilityButton.new()
		abilities_container.add_child(ability_btn)

		# Setup button
		ability_btn.setup(skill_id, skill_manager, skill_data, str(hotkey_index))

		# Add to tracking array
		ability_buttons.append(ability_btn)

		hotkey_index += 1

	print("🎮 HeroButton: Created ", ability_buttons.size(), " ability buttons")
