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
@onready var xp_bar = $XPBar
@onready var level_label = $LevelLabel

# Ability buttons container
var abilities_container: HBoxContainer = null
var ability_buttons: Array[AbilityButton] = []

# Stats popup
var stats_popup: HeroStatsPopup = null

# STATE
var hero_reference = null # Reference to the actual hero in the game world
var is_selected = false

# DEBUG STATE
var last_printed_health = -1.0


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
	abilities_container.position = Vector2(0, -70) # Above the hero panel

	print("✅ Abilities container created")

func _setup_stats_popup():
	"""Create stats popup panel"""
	stats_popup = HeroStatsPopup.new()
	stats_popup.name = "StatsPopup"
	add_child(stats_popup)

	# Position to the right of the hero button
	stats_popup.position = Vector2(100, 0) # To the right

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

func _on_ui_scale_changed(_new_scale: float):
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
	# _setup_active_ability_button() # MOVED TO SKILL BAR

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

	# Update level and XP
	_update_level_display()
	_update_xp_display()
	
	# Update portrait
	if "hero_id" in hero_reference:
		var data = HeroDatabase.get_hero(hero_reference.hero_id)
		if data and data.portrait and portrait:
			portrait.texture = data.portrait

## ============================================
## UPDATE LOOP
## ============================================

func _process(_delta):
	# Update health bar every frame (simple approach)
	if hero_reference and is_instance_valid(hero_reference):
		if "current_health" in hero_reference and "max_health" in hero_reference:
			var health_percent = (hero_reference.current_health / hero_reference.max_health) * 100.0
			health_bar.value = health_percent
			
			# DEBUG: Log health changes only
			if abs(hero_reference.current_health - last_printed_health) > 0.1:
				last_printed_health = hero_reference.current_health
				print("❤️ [HeroButton] Health updated: %.1f / %.1f (%.1f%%)" % [hero_reference.current_health, hero_reference.max_health, health_percent])

		# Update XP and level
		_update_xp_display()
		_update_level_display()


func _update_level_display():
	"""Update level label with current hero level"""
	if not hero_reference or not is_instance_valid(hero_reference) or not level_label:
		return

	if not HeroProgressionManager:
		return

	var level = HeroProgressionManager.get_hero_level(hero_reference)
	level_label.text = str(level)


func _update_xp_display():
	"""Update XP bar with current hero XP progress"""
	if not hero_reference or not is_instance_valid(hero_reference) or not xp_bar:
		return

	if not HeroProgressionManager:
		return

	# Get XP progress (0.0 to 1.0)
	var progress = HeroProgressionManager.get_level_progress(hero_reference)

	# Convert to percentage (0-100)
	xp_bar.value = progress * 100.0

## ============================================
## BUTTON INTERACTION
## ============================================

func _on_button_pressed():
	"""Called when button is clicked"""
	print("\n🔘 [HeroButton] CLICKED!")

	if not hero_reference:
		print("  ❌ [HeroButton] No hero linked!")
		return

	if not is_instance_valid(hero_reference):
		print("  ❌ [HeroButton] Linked hero is invalid (freed)!")
		return

	print("  ✅ [HeroButton] Selecting connected hero: %s" % hero_reference.name)

	# Try to call the hero's select method directly
	if hero_reference.has_method("select"):
		hero_reference.select()
		print("  -> called hero.select()")

	# Also emit the hero_selected signal for HeroManager
	if hero_reference.has_signal("hero_selected"):
		hero_reference.hero_selected.emit(hero_reference)
		print("  -> emitted hero_selected signal")
	
	# Update visual state
	set_selected(true)


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
		self_modulate = Color(1.3, 1.3, 1.0) # Yellow tint
	else:
		# Normal appearance
		self_modulate = Color(1.0, 1.0, 1.0)

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

func _setup_active_ability_button():
	"""Configure ability buttons for all active skills"""
	# Clear existing buttons
	for child in abilities_container.get_children():
		child.queue_free()
	
	# Also hide/remove the old static button if it exists
	if has_node("ActiveAbilityButton"):
		$ActiveAbilityButton.visible = false
	
	if not hero_reference or not is_instance_valid(hero_reference):
		return

	# Get skill manager from hero
	if not hero_reference.has_node("SkillManager"):
		print("⚠️ HeroButton: Hero has no SkillManager")
		return

	var skill_manager = hero_reference.get_node("SkillManager")

	# Get all owned skills
	var owned_skills = skill_manager.owned_skills
	if owned_skills.is_empty():
		return

	# Load ability button scene
	var ability_btn_scene = load("res://scenes/ui/ability_button.tscn")
	if not ability_btn_scene:
		print("⚠️ HeroButton: Could not load ability_button.tscn")
		return

	# Find ALL active skills
	var hotkey_index = 1
	for skill_id in owned_skills.keys():
		var skill_data = skill_manager.get_skill_data(skill_id)

		if not skill_data:
			continue

		# Only care about ACTIVE skills
		if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE:
			# Instantiate button
			var btn = ability_btn_scene.instantiate()
			abilities_container.add_child(btn)
			
			# Setup button
			var hotkey = str(hotkey_index)
			btn.setup(skill_id, skill_manager, skill_data, hotkey)
			print("🎮 HeroButton: Bound active skill button to: ", skill_id, " (Hotkey: ", hotkey, ")")
			
			hotkey_index += 1
