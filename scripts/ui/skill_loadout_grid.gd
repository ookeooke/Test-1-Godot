extends GridContainer
class_name SkillLoadoutGrid

## ============================================
## SKILL LOADOUT GRID - Grid manager for skill slots
## ============================================
##
## Manages a grid of SkillSlot nodes
## Dynamically creates slots based on hero's max_active/passive_ability_slots

@export var slot_type: String = "active" # "active" or "passive"
@export var hero_id: String = ""

var slots: Array[SkillSlot] = []

## ============================================
## INITIALIZATION
## ============================================

func setup(p_hero_id: String, p_slot_type: String):
	"""Setup the grid with hero and slot type"""
	hero_id = p_hero_id
	slot_type = p_slot_type
	_create_slots()

func _create_slots():
	"""Create skill slots dynamically based on hero's class config"""
	# Clear existing slots
	for child in get_children():
		child.queue_free()
	slots.clear()

	# Get max slots for this hero
	var max_slots = SaveManager.get_max_skill_slots(hero_id)
	var num_slots = max_slots.get(slot_type, 2)

	print("[SkillLoadoutGrid] Creating %d %s slots for %s" % [num_slots, slot_type, hero_id])

	# Set columns based on slot type
	if slot_type == "active":
		columns = mini(num_slots, 4) # Max 4 columns for active skills
	else:
		columns = mini(num_slots, 6) # Max 6 columns for passive skills

	# Create slots
	for i in num_slots:
		var slot_scene = load("res://scenes/ui/skill_slot.tscn")
		if slot_scene:
			var slot = slot_scene.instantiate()
			slot.setup(i, slot_type, hero_id)
			slot.skill_equipped.connect(_on_skill_equipped)
			slot.skill_unequipped.connect(_on_skill_unequipped)
			add_child(slot)
			slots.append(slot)

	print("[SkillLoadoutGrid] ✅ Created %d skill slots" % slots.size())

## ============================================
## PUBLIC API
## ============================================

func refresh_all_slots():
	"""Refresh all slot displays (call after swap)"""
	for slot in slots:
		slot._refresh_display()
	print("[SkillLoadoutGrid] 🔄 Refreshed all slots")

## ============================================
## SIGNAL HANDLERS
## ============================================

func _on_skill_equipped(slot_index: int, skill_id: String):
	"""Called when a skill is equipped to a slot"""
	print("[SkillLoadoutGrid] ✅ Equipped %s to %s slot %d" % [skill_id, slot_type, slot_index])

func _on_skill_unequipped(slot_index: int):
	"""Called when a skill is unequipped from a slot"""
	print("[SkillLoadoutGrid] ❌ Unequipped %s slot %d" % [slot_type, slot_index])
