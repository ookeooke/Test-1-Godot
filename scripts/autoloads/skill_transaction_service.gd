extends Node

## SkillTransactionService - Autoload Singleton
## Handles skill movements between pool and equipment slots.
## Mirrors ItemTransactionService architecture for consistency.
## Acts as the "Controller" in the MVC pattern.

# Debug mode
const DEBUG_TRANSACTIONS = true # Enable verbose transaction logging

# Signals for reactive UI
signal skill_moved(skill_id: String, source_type: String, target_type: String, hero_id: String)
signal skill_equipped(skill_id: String, slot_type: String, slot_index: int, hero_id: String)
signal skill_unequipped(skill_id: String, slot_type: String, slot_index: int, hero_id: String)
signal skill_swapped(skill_a_id: String, skill_b_id: String, slot_type: String, hero_id: String)

## Equip a skill from the pool to a hero's equipment slot
## Returns true if successful
func equip_skill(hero_id: String, skill_id: String, slot_type: String, slot_index: int) -> bool:
	if DEBUG_TRANSACTIONS:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("[SkillTransactionService] 🔄 Starting Equip Transaction")
		print("  Hero: %s" % hero_id)
		print("  Skill: %s" % skill_id)
		print("  Slot: %s[%d]" % [slot_type, slot_index])

	# 1. Validate inputs
	if not _validate_hero(hero_id):
		return false

	if not _validate_skill(skill_id):
		return false

	if not _validate_slot_type(slot_type):
		return false

	# 2. Get current equipped skills
	var equipped = SaveManager.get_equipped_skills(hero_id)
	var slot_list = equipped.get(slot_type, [])

	# 3. Ensure slot list is properly sized
	var slot_count = SaveManager.get_unlocked_slot_count(hero_id).get(slot_type, 0)
	while slot_list.size() < slot_count:
		slot_list.append("")

	# 4. Validate slot index
	if slot_index < 0 or slot_index >= slot_list.size():
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Invalid slot index %d (max: %d)" % [slot_index, slot_list.size() - 1])
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Invalid slot index: %d" % slot_index)
		return false

	# 5. Get skill data to validate type
	var skill_data = _get_skill_data(skill_id)
	if not skill_data:
		return false

	# 6. Validate skill type matches slot type
	if not _validate_skill_type_match(skill_data, slot_type):
		return false

	# 7. Check if slot is occupied (for swap)
	var current_skill = slot_list[slot_index]

	# 8. Equip the new skill
	slot_list[slot_index] = skill_id
	equipped[slot_type] = slot_list
	SaveManager.update_equipped_skills(hero_id, equipped)

	# 9. Mark save dirty for persistence
	SaveManager.mark_dirty()

	# 10. Emit signals
	if current_skill != "":
		# This was a swap
		skill_swapped.emit(skill_id, current_skill, slot_type, hero_id)
		if DEBUG_TRANSACTIONS:
			print("  🔄 SWAP: '%s' ↔ '%s'" % [skill_id, current_skill])
	else:
		# This was a fresh equip
		skill_equipped.emit(skill_id, slot_type, slot_index, hero_id)
		if DEBUG_TRANSACTIONS:
			print("  ✅ EQUIPPED: '%s' → %s[%d]" % [skill_id, slot_type, slot_index])

	skill_moved.emit(skill_id, "pool", slot_type, hero_id)

	if DEBUG_TRANSACTIONS:
		print("  ✅ TRANSACTION SUCCESSFUL")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return true

## Unequip a skill from a hero's equipment slot back to the pool
## Returns true if successful
func unequip_skill(hero_id: String, slot_type: String, slot_index: int) -> bool:
	if DEBUG_TRANSACTIONS:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("[SkillTransactionService] 🔄 Starting Unequip Transaction")
		print("  Hero: %s" % hero_id)
		print("  Slot: %s[%d]" % [slot_type, slot_index])

	# 1. Validate inputs
	if not _validate_hero(hero_id):
		return false

	if not _validate_slot_type(slot_type):
		return false

	# 2. Get current equipped skills
	var equipped = SaveManager.get_equipped_skills(hero_id)
	var slot_list = equipped.get(slot_type, [])

	# 3. Validate slot index
	if slot_index < 0 or slot_index >= slot_list.size():
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Invalid slot index %d" % slot_index)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Invalid slot index: %d" % slot_index)
		return false

	# 4. Get current skill
	var skill_id = slot_list[slot_index]

	if skill_id == "":
		if DEBUG_TRANSACTIONS:
			print("  ⚠️ Slot already empty")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return true # Already empty, no-op success

	# 5. Unequip (clear slot)
	slot_list[slot_index] = ""
	equipped[slot_type] = slot_list
	SaveManager.update_equipped_skills(hero_id, equipped)

	# 6. Mark save dirty for persistence
	SaveManager.mark_dirty()

	# 7. Emit signals
	skill_unequipped.emit(skill_id, slot_type, slot_index, hero_id)
	skill_moved.emit(skill_id, slot_type, "pool", hero_id)

	if DEBUG_TRANSACTIONS:
		print("  ✅ UNEQUIPPED: '%s' from %s[%d]" % [skill_id, slot_type, slot_index])
		print("  ✅ TRANSACTION SUCCESSFUL")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return true

## Swap two skills between equipped slots
## Returns true if successful
func swap_skills(hero_id: String, slot_type_a: String, slot_index_a: int, slot_type_b: String, slot_index_b: int) -> bool:
	if DEBUG_TRANSACTIONS:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("[SkillTransactionService] 🔄 Starting Swap Transaction")
		print("  Hero: %s" % hero_id)
		print("  Slot A: %s[%d]" % [slot_type_a, slot_index_a])
		print("  Slot B: %s[%d]" % [slot_type_b, slot_index_b])

	# 1. Validate inputs
	if not _validate_hero(hero_id):
		return false

	if not _validate_slot_type(slot_type_a) or not _validate_slot_type(slot_type_b):
		return false

	# 2. Get current equipped skills
	var equipped = SaveManager.get_equipped_skills(hero_id)
	var slot_list_a = equipped.get(slot_type_a, [])
	var slot_list_b = equipped.get(slot_type_b, [])

	# 3. Validate slot indices
	if slot_index_a < 0 or slot_index_a >= slot_list_a.size():
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Invalid slot index A: %d" % slot_index_a)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return false

	if slot_index_b < 0 or slot_index_b >= slot_list_b.size():
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Invalid slot index B: %d" % slot_index_b)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return false

	# 4. Get skills
	var skill_a = slot_list_a[slot_index_a]
	var skill_b = slot_list_b[slot_index_b]

	# 5. If swapping within same type, validate both skills match type
	if slot_type_a == slot_type_b:
		# Validate type compatibility if skills exist
		if skill_a != "":
			var skill_data_a = _get_skill_data(skill_a)
			if skill_data_a and not _validate_skill_type_match(skill_data_a, slot_type_b):
				return false

		if skill_b != "":
			var skill_data_b = _get_skill_data(skill_b)
			if skill_data_b and not _validate_skill_type_match(skill_data_b, slot_type_a):
				return false
	else:
		# Cross-type swap: Validate each skill matches destination type
		if skill_a != "":
			var skill_data_a = _get_skill_data(skill_a)
			if skill_data_a and not _validate_skill_type_match(skill_data_a, slot_type_b):
				return false

		if skill_b != "":
			var skill_data_b = _get_skill_data(skill_b)
			if skill_data_b and not _validate_skill_type_match(skill_data_b, slot_type_a):
				return false

	# 6. Perform atomic swap
	slot_list_a[slot_index_a] = skill_b
	slot_list_b[slot_index_b] = skill_a

	equipped[slot_type_a] = slot_list_a
	if slot_type_a != slot_type_b:
		equipped[slot_type_b] = slot_list_b

	SaveManager.update_equipped_skills(hero_id, equipped)

	# 7. Mark save dirty for persistence
	SaveManager.mark_dirty()

	# 8. Emit signals
	skill_swapped.emit(skill_a, skill_b, slot_type_a if slot_type_a == slot_type_b else "mixed", hero_id)

	if DEBUG_TRANSACTIONS:
		print("  🔄 SWAPPED: '%s' ↔ '%s'" % [skill_a if skill_a != "" else "(empty)", skill_b if skill_b != "" else "(empty)"])
		print("  ✅ TRANSACTION SUCCESSFUL")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return true

## Move a skill from source to target (generic operation)
## This is a higher-level API that wraps equip/unequip/swap
func move_skill(skill_id: String, source_type: String, source_index: int, target_type: String, target_index: int, hero_id: String) -> bool:
	if DEBUG_TRANSACTIONS:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("[SkillTransactionService] 🔄 Starting Move Transaction")
		print("  Skill: %s" % skill_id)
		print("  Route: %s[%d] → %s[%d]" % [source_type, source_index, target_type, target_index])
		print("  Hero: %s" % hero_id)

	# Determine operation type
	if source_type == "pool" and target_type in ["active", "passive"]:
		# Equip from pool
		return equip_skill(hero_id, skill_id, target_type, target_index)

	elif source_type in ["active", "passive"] and target_type == "pool":
		# Unequip to pool
		return unequip_skill(hero_id, source_type, source_index)

	elif source_type in ["active", "passive"] and target_type in ["active", "passive"]:
		# Swap between slots
		return swap_skills(hero_id, source_type, source_index, target_type, target_index)

	else:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Invalid move route: %s → %s" % [source_type, target_type])
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Invalid move route: %s → %s" % [source_type, target_type])
		return false

## VALIDATION HELPERS

func _validate_hero(hero_id: String) -> bool:
	if not HeroDatabase:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: HeroDatabase not available")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("HeroDatabase not available")
		return false

	if not HeroDatabase.has_hero(hero_id):
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Hero not found: '%s'" % hero_id)
			print("  Available heroes: %s" % HeroDatabase.get_all_hero_ids())
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Hero not found: %s" % hero_id)
		return false

	return true

func _validate_skill(skill_id: String) -> bool:
	# Check if skill exists in any class's skill pool
	# (This is a lightweight check - we'll validate type match later)
	var skill_data = _get_skill_data(skill_id)
	if not skill_data:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Skill not found in database: '%s'" % skill_id)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Skill not found: %s" % skill_id)
		return false

	return true

func _validate_slot_type(slot_type: String) -> bool:
	if slot_type not in ["active", "passive"]:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Invalid slot type: '%s' (expected 'active' or 'passive')" % slot_type)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Invalid slot type: %s" % slot_type)
		return false

	return true

func _validate_skill_type_match(skill_data: Resource, slot_type: String) -> bool:
	# skill_type enum: 0 = Passive, 1 = Active
	var is_active_skill = skill_data.skill_type == 1
	var is_passive_skill = skill_data.skill_type == 0

	if slot_type == "active" and not is_active_skill:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Cannot equip passive skill '%s' to active slot" % skill_data.skill_name)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Type mismatch: Passive skill in active slot")
		return false

	if slot_type == "passive" and not is_passive_skill:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Cannot equip active skill '%s' to passive slot" % skill_data.skill_name)
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Type mismatch: Active skill in passive slot")
		return false

	return true

func _get_skill_data(skill_id: String) -> Resource:
	# Get skill data from HeroClassDatabase
	# This searches ALL hero classes for the skill
	if not HeroClassDatabase:
		push_error("HeroClassDatabase not available")
		return null

	# Search all class configs for the skill
	for class_type in HeroClassDatabase.get_all_class_types():
		var class_config = HeroClassDatabase.get_class_config(class_type)
		if not class_config:
			continue

		for skill in class_config.available_skill_pool:
			if skill.skill_id == skill_id:
				return skill

	return null
