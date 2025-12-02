extends PanelContainer
class_name SkillBar

## ============================================
## SKILL BAR - Dedicated UI for Hero Skills
## ============================================
##
## Manages the display of ability buttons for the currently selected hero.
## Dynamically creates buttons based on the hero's active skills.

# REFERENCES
@onready var container = $HBoxContainer

# STATE
var current_hero = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Hide by default until a hero is selected
	visible = false
	
	# Listen for hero selection globally
	var hero_manager = get_tree().get_first_node_in_group("hero_manager")
	if hero_manager:
		hero_manager.hero_selected.connect(_on_hero_selected)
	else:
		print("⚠️ SkillBar: HeroManager not found (check groups)")

# ============================================
# PUBLIC API
# ============================================

func set_hero(hero):
	"""Update the skill bar to show skills for the given hero"""
	current_hero = hero
	
	if not hero or not is_instance_valid(hero):
		visible = false
		return
		
	visible = true
	_refresh_skills()

# ============================================
# INTERNAL LOGIC
# ============================================

func _on_hero_selected(hero):
	"""Signal handler for global hero selection"""
	set_hero(hero)

func _refresh_skills():
	"""Rebuild the skill buttons for the current hero"""
	# Clear existing buttons
	for child in container.get_children():
		child.queue_free()
		
	if not current_hero:
		return
		
	# Get skill manager
	if not current_hero.has_node("SkillManager"):
		print("⚠️ SkillBar: Hero has no SkillManager")
		return
		
	var skill_manager = current_hero.get_node("SkillManager")
	var owned_skills = skill_manager.owned_skills
	
	if owned_skills.is_empty():
		# print("SkillBar: No owned skills")
		pass
		
	print("SkillBar: Refreshing skills for ", current_hero.name)
		
	# Load ability button scene
	var ability_btn_scene = load("res://scenes/ui/ability_button.tscn")
	if not ability_btn_scene:
		print("⚠️ SkillBar: Could not load ability_button.tscn")
		return
		
	# Create buttons for active skills
	var hotkey_index = 1
	for skill_id in owned_skills.keys():
		var skill_data = skill_manager.get_skill_data(skill_id)
		
		if not skill_data:
			continue
			
		if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE:
			var btn = ability_btn_scene.instantiate()
			container.add_child(btn)
			
			var hotkey = str(hotkey_index)
			btn.setup(skill_id, skill_manager, skill_data, hotkey)
			
			hotkey_index += 1
			
			
	# Add Targeting Button (if hero supports it)
	if current_hero.has_method("cycle_targeting_mode"):
		print("SkillBar: Adding targeting button for ", current_hero.name)
		var target_btn = Button.new()
		target_btn.custom_minimum_size = Vector2(40, 40)
		target_btn.toggle_mode = false
		target_btn.focus_mode = Control.FOCUS_NONE
		
		# Initial text
		var mode_name = current_hero.get_targeting_mode_name()
		target_btn.text = "🎯\n" + mode_name
		target_btn.add_theme_font_size_override("font_size", 10)
		target_btn.tooltip_text = "Change Targeting Priority"
		
		# Connect click
		target_btn.pressed.connect(func():
			if is_instance_valid(current_hero):
				var _new_mode = current_hero.cycle_targeting_mode()
				var new_name = current_hero.get_targeting_mode_name()
				target_btn.text = "🎯\n" + new_name
		)
		
		container.add_child(target_btn)
			
	# Adjust visibility based on whether we have skills
	visible = container.get_child_count() > 0
	print("SkillBar: Visible? ", visible, " (Children: ", container.get_child_count(), ")")
