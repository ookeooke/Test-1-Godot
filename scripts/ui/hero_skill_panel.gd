extends Control
class_name HeroSkillPanel

## ============================================
## HERO SKILL PANEL (Diablo Immortal Style)
## ============================================
## Displays a single hero's portrait, health/XP, and skills
## Positioned in bottom-right corner for mobile-friendly access
## Uses 2x2 grid layout for skill buttons

# REFERENCES
@onready var hero_portrait: TextureRect = $MarginContainer/VBoxContainer/HeroPortrait
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var xp_bar: ProgressBar = $MarginContainer/VBoxContainer/XPBar
@onready var skill_grid: GridContainer = $MarginContainer/VBoxContainer/SkillGrid

# STATE
var current_hero: Node = null
var hero_id: String = ""
var ability_buttons: Array[Node] = []

func _ready():
	# Initialize with empty state
	visible = false

func setup(hero_node: Node):
	if not is_instance_valid(hero_node):
		print("⚠️ [HeroSkillPanel] Invalid hero node!")
		visible = false
		return

	current_hero = hero_node

	# Determine Hero ID
	if "hero_id" in current_hero and current_hero.hero_id != "":
		hero_id = current_hero.hero_id
	elif current_hero.has_meta("hero_id"):
		hero_id = current_hero.get_meta("hero_id")
	else:
		hero_id = current_hero.name.to_lower().replace("hero", "")

	print("[HeroSkillPanel] Setup for: %s (ID: %s)" % [current_hero.name, hero_id])

	_update_portrait()
	_refresh_skills()

	visible = true

func _process(_delta):
	if not is_instance_valid(current_hero):
		visible = false
		return

	_update_status_bars()

func _update_portrait():
	if not is_instance_valid(current_hero) or not hero_portrait:
		return

	# Set Portrait
	var hero_data = HeroDatabase.get_hero(hero_id)
	if hero_data and hero_data.portrait:
		hero_portrait.texture = hero_data.portrait
		hero_portrait.tooltip_text = hero_data.hero_name if hero_data else current_hero.name

func _update_status_bars():
	if not is_instance_valid(current_hero):
		return

	# Update Health
	if health_bar and "current_health" in current_hero and "max_health" in current_hero:
		health_bar.max_value = current_hero.max_health
		health_bar.value = current_hero.current_health

	# Update XP (if available)
	if xp_bar and "current_xp" in current_hero and "max_xp" in current_hero:
		xp_bar.max_value = current_hero.max_xp
		xp_bar.value = current_hero.current_xp

func _refresh_skills():
	# Clear existing buttons
	for btn in ability_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	ability_buttons.clear()

	# Clear skill grid
	if skill_grid:
		for child in skill_grid.get_children():
			child.queue_free()

	if not current_hero.has_node("SkillManager"):
		print("⚠️ [HeroSkillPanel] No SkillManager found for %s" % current_hero.name)
		return

	var skill_manager = current_hero.get_node("SkillManager")
	var equipped = SaveManager.get_equipped_skills(hero_id)

	# Create Active Skills (up to 4 in 2x2 grid)
	var active_ids = equipped.get("active", [])
	var ability_btn_scene = load("res://scenes/ui/ability_button.tscn")

	var count = 0
	for skill_id in active_ids:
		if skill_id == "" or count >= 4:  # Max 4 skills in 2x2 grid
			continue

		var skill_data = skill_manager.get_skill_data(skill_id)
		if not skill_data:
			continue

		# Create ability button
		var btn = ability_btn_scene.instantiate()
		skill_grid.add_child(btn)

		# Setup hotkey (1-4 for skill slots)
		var hotkey = str(count + 1)
		btn.setup(skill_id, skill_manager, skill_data, hotkey)

		ability_buttons.append(btn)
		count += 1

	print("[HeroSkillPanel] Created %d skill buttons for %s" % [count, hero_id])
