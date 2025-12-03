extends PanelContainer
class_name SkillSlot

## ============================================
## SKILL SLOT - Drop target for equipped skills
## ============================================
##
## Represents a single skill slot in the loadout grid
## Handles drag-and-drop of skills with swap support

# State
var slot_index: int = 0
var slot_type: String = "active" # "active" or "passive"
var hero_id: String = ""
var equipped_skill_id: String = "" # "" = empty, "fireball" = has skill

# Visual references
@onready var icon_layer: Control = $IconLayer
@onready var empty_label: Label = $EmptyLabel

var skill_icon = null  # Will be SkillIcon instance when created

# Signals
signal skill_equipped(slot_index: int, skill_id: String)
signal skill_unequipped(slot_index: int)

## ============================================
## INITIALIZATION
## ============================================

func setup(p_slot_index: int, p_slot_type: String, p_hero_id: String):
	"""Setup the slot with configuration"""
	slot_index = p_slot_index
	slot_type = p_slot_type
	hero_id = p_hero_id
	_refresh_display()

func _refresh_display():
	"""Refresh the slot display based on equipped skill"""
	# Clear existing icon
	if skill_icon:
		skill_icon.queue_free()
		skill_icon = null

	# Get equipped skill
	var equipped = SaveManager.get_equipped_skills(hero_id)
	var skills_array = equipped.get(slot_type, [])
	if slot_index < skills_array.size():
		equipped_skill_id = skills_array[slot_index]
	else:
		equipped_skill_id = ""

	# Show/hide empty label
	if empty_label:
		empty_label.visible = (equipped_skill_id == "")

	# Create icon if skill equipped
	if equipped_skill_id != "":
		# Load skill data from class config
		var skill_data = _get_skill_data(equipped_skill_id)

		if skill_data:
			# Create skill icon
			var skill_icon_scene = load("res://scenes/ui/skill_icon.tscn")
			if skill_icon_scene:
				skill_icon = skill_icon_scene.instantiate()
				skill_icon.setup(equipped_skill_id, skill_data, hero_id)
				skill_icon.source_slot_index = slot_index
				skill_icon.source_slot_type = slot_type
				icon_layer.add_child(skill_icon)
				print("[SkillSlot] ✅ Displayed %s in %s slot %d" % [equipped_skill_id, slot_type, slot_index])

func _get_skill_data(skill_id: String) -> HeroSkillData:
	"""Get skill data from hero's class config"""
	if not HeroDatabase or not HeroClassDatabase:
		return null

	var hero_data = HeroDatabase.get_hero(hero_id)
	if not hero_data:
		return null

	var class_config = HeroClassDatabase.get_class_config(hero_data.hero_class)
	if not class_config:
		return null

	# Find skill in available_skill_pool
	for skill_data in class_config.available_skill_pool:
		if skill_data and skill_data.skill_id == skill_id:
			return skill_data

	return null

## ============================================
## DRAG-AND-DROP HANDLING
## ============================================

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	"""Validate if drop is allowed"""
	if not data is Dictionary:
		return false
	if not data.has("skill_id"):
		return false

	# Check hero match
	if data.hero_id != hero_id:
		print("[SkillSlot] ❌ Drop rejected: Hero mismatch")
		return false

	# Check skill type match (active skills to active slots only)
	var skill_data = data.skill_data as HeroSkillData
	if not skill_data:
		return false

	var expected_type = HeroSkillData.SkillType.ACTIVE if slot_type == "active" else HeroSkillData.SkillType.PASSIVE
	if skill_data.skill_type != expected_type:
		print("[SkillSlot] ❌ Drop rejected: Type mismatch (expected %s, got %s)" % [
			"active" if expected_type == HeroSkillData.SkillType.ACTIVE else "passive",
			"active" if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else "passive"
		])
		return false

	print("[SkillSlot] ✅ Drop validated: %s -> %s slot %d" % [data.skill_id, slot_type, slot_index])
	return true

func _drop_data(_at_position: Vector2, data: Variant):
	"""Execute the drop - equip or swap skills"""
	var dragged_skill_id = data.skill_id
	var source_slot_index = data.source_slot_index

	print("[SkillSlot] 📦 Dropping %s (from slot %d) onto slot %d" % [dragged_skill_id, source_slot_index, slot_index])

	# CASE 1: Dragging from skill list -> Equip to slot
	if source_slot_index == -1:
		SaveManager.equip_skill(hero_id, slot_type, slot_index, dragged_skill_id)
		skill_equipped.emit(slot_index, dragged_skill_id)
		_refresh_display()
		print("[SkillSlot] ✅ Equipped %s to slot %d" % [dragged_skill_id, slot_index])

		# Play audio feedback
		if AudioManager:
			AudioManager.play("equip")

	# CASE 2: Dragging from another slot -> Swap
	elif source_slot_index != slot_index:
		# Get current skill in this slot
		var current_skill = equipped_skill_id

		print("[SkillSlot] 🔄 Swapping: slot %d (%s) <-> slot %d (%s)" % [
			source_slot_index, dragged_skill_id,
			slot_index, current_skill if current_skill != "" else "empty"
		])

		# Swap: this slot gets dragged skill
		SaveManager.equip_skill(hero_id, slot_type, slot_index, dragged_skill_id)

		# Source slot gets current skill (or "" if empty)
		if current_skill == "":
			SaveManager.unequip_skill(hero_id, slot_type, source_slot_index)
		else:
			SaveManager.equip_skill(hero_id, slot_type, source_slot_index, current_skill)

		skill_equipped.emit(slot_index, dragged_skill_id)

		# Refresh all slots in parent grid
		var parent_grid = get_parent()
		if parent_grid and parent_grid.has_method("refresh_all_slots"):
			parent_grid.refresh_all_slots()

		print("[SkillSlot] ✅ Swap completed")

		# Play audio feedback
		if AudioManager:
			AudioManager.play("swap")

	# CASE 3: Dragging to same slot -> No-op
	else:
		print("[SkillSlot] ⚠️ Same slot, no action")
		pass
