extends Node
class_name SkillManager

## ============================================
## SKILL MANAGER - Handles skill activation and cooldowns
## ============================================
##
## Attach this as a child of a hero to manage their skills
## Tracks which skills are unlocked, upgrade levels, and cooldowns

signal skill_activated(skill_id: String)
signal skill_ready(skill_id: String)
signal cooldown_updated(skill_id: String, remaining: float, total: float)

# ============================================
## SKILL OWNERSHIP
# ============================================

# Dictionary: skill_id → upgrade_level (0 = not unlocked, 1+ = owned with upgrades)
var owned_skills: Dictionary = {}

# Dictionary: skill_id → HeroSkillData (cached for quick access)
var skill_data_cache: Dictionary = {}

# ============================================
# COOLDOWN TRACKING
# ============================================

# Dictionary: skill_id → remaining cooldown time
var active_cooldowns: Dictionary = {}

# Reference to the hero this manager belongs to
var hero: Node = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Get reference to parent hero
	hero = get_parent()

	if not hero:
		push_error("SkillManager: No parent hero found!")
		return

	# Start cooldown timer
	set_process(true)

func _process(delta):
	"""Update all active cooldowns"""
	var cooldowns_to_remove = []

	for skill_id in active_cooldowns.keys():
		active_cooldowns[skill_id] -= delta

		# Get total cooldown for this skill
		var skill_data = get_skill_data(skill_id)
		var total_cooldown = 0.0
		if skill_data:
			var upgrade_level = owned_skills.get(skill_id, 1)
			total_cooldown = skill_data.get_current_cooldown(upgrade_level)

		# Emit update signal
		cooldown_updated.emit(skill_id, active_cooldowns[skill_id], total_cooldown)

		# Check if cooldown finished
		if active_cooldowns[skill_id] <= 0.0:
			cooldowns_to_remove.append(skill_id)
			skill_ready.emit(skill_id)

	# Remove finished cooldowns
	for skill_id in cooldowns_to_remove:
		active_cooldowns.erase(skill_id)

# ============================================
# SKILL UNLOCKING AND UPGRADING
# ============================================

func unlock_skill(skill_id: String, skill_data: HeroSkillData) -> bool:
	"""Unlock a new skill (does NOT check cost - caller must handle that)"""
	if is_skill_owned(skill_id):
		push_warning("SkillManager: Skill already unlocked: ", skill_id)
		return false

	# Add to owned skills at level 1
	owned_skills[skill_id] = 1

	# Cache the skill data
	skill_data_cache[skill_id] = skill_data

	print("✅ SkillManager: Unlocked skill: ", skill_id, " (", skill_data.skill_name, ")")

	# Apply passive effects if it's a passive skill
	if skill_data.skill_type == HeroSkillData.SkillType.PASSIVE:
		_apply_passive_skill(skill_id, skill_data, 1)

	return true

func upgrade_skill(skill_id: String) -> bool:
	"""Upgrade an owned skill to next level (does NOT check cost)"""
	if not is_skill_owned(skill_id):
		push_error("SkillManager: Cannot upgrade unowned skill: ", skill_id)
		return false

	var current_level = owned_skills[skill_id]
	var skill_data = get_skill_data(skill_id)

	if not skill_data:
		push_error("SkillManager: No skill data found for: ", skill_id)
		return false

	if current_level >= skill_data.max_upgrade_level:
		push_warning("SkillManager: Skill already at max level: ", skill_id)
		return false

	# Increment level
	owned_skills[skill_id] = current_level + 1

	print("⬆️ SkillManager: Upgraded skill: ", skill_id, " to level ", owned_skills[skill_id])

	# Reapply passive effects if passive
	if skill_data.skill_type == HeroSkillData.SkillType.PASSIVE:
		_apply_passive_skill(skill_id, skill_data, owned_skills[skill_id])

	return true

func is_skill_owned(skill_id: String) -> bool:
	"""Check if skill is unlocked"""
	return owned_skills.has(skill_id) and owned_skills[skill_id] > 0

func get_skill_level(skill_id: String) -> int:
	"""Get current upgrade level of a skill (0 = not owned)"""
	return owned_skills.get(skill_id, 0)

func get_skill_data(skill_id: String) -> HeroSkillData:
	"""Get cached skill data"""
	return skill_data_cache.get(skill_id, null)

# ============================================
# SKILL ACTIVATION (ACTIVE SKILLS)
# ============================================

func activate_skill(skill_id: String) -> bool:
	"""Attempt to activate an active skill"""
	if not is_skill_owned(skill_id):
		push_warning("SkillManager: Cannot activate unowned skill: ", skill_id)
		return false

	if is_on_cooldown(skill_id):
		push_warning("SkillManager: Skill on cooldown: ", skill_id)
		return false

	var skill_data = get_skill_data(skill_id)
	if not skill_data:
		push_error("SkillManager: No skill data for: ", skill_id)
		return false

	if skill_data.skill_type != HeroSkillData.SkillType.ACTIVE:
		push_warning("SkillManager: Cannot activate passive skill: ", skill_id)
		return false

	# Start cooldown
	var upgrade_level = owned_skills[skill_id]
	var cooldown_time = skill_data.get_current_cooldown(upgrade_level)

	# Apply cooldown reduction from passives (if any)
	cooldown_time *= (1.0 - _get_total_cooldown_reduction())

	active_cooldowns[skill_id] = cooldown_time

	# Emit signal for hero to handle the actual skill effect
	skill_activated.emit(skill_id)

	print("🎯 SkillManager: Activated skill: ", skill_id, " (cooldown: ", cooldown_time, "s)")

	return true

func is_on_cooldown(skill_id: String) -> bool:
	"""Check if a skill is currently on cooldown"""
	return active_cooldowns.has(skill_id)

func get_cooldown_remaining(skill_id: String) -> float:
	"""Get remaining cooldown time for a skill"""
	return active_cooldowns.get(skill_id, 0.0)

func get_cooldown_progress(skill_id: String) -> float:
	"""Get cooldown progress as 0.0-1.0 (1.0 = ready)"""
	if not is_on_cooldown(skill_id):
		return 1.0

	var skill_data = get_skill_data(skill_id)
	if not skill_data:
		return 1.0

	var upgrade_level = owned_skills.get(skill_id, 1)
	var total_cooldown = skill_data.get_current_cooldown(upgrade_level)
	var remaining = get_cooldown_remaining(skill_id)

	return 1.0 - (remaining / total_cooldown)

# ============================================
## NEW UNIFIED STAT SYSTEM
# ============================================

## Get all stat modifiers from owned passive skills (NEW unified system)
## This is the primary method for the new stat system
func get_passive_skill_modifiers() -> Array[StatModifier]:
	"""Generate StatModifiers from all owned passive skills"""
	var all_modifiers: Array[StatModifier] = []

	for skill_id in owned_skills.keys():
		var skill_data = get_skill_data(skill_id)
		if not skill_data or skill_data.skill_type != HeroSkillData.SkillType.PASSIVE:
			continue

		var upgrade_level = owned_skills[skill_id]
		var skill_modifiers = _generate_modifiers_from_skill(skill_id, skill_data, upgrade_level)
		all_modifiers.append_array(skill_modifiers)

	if all_modifiers.size() > 0:
		print("[SkillManager] Generated %d stat modifiers from skills" % all_modifiers.size())

	return all_modifiers

## Helper: Generate StatModifiers from a single skill
func _generate_modifiers_from_skill(skill_id: String, skill_data: HeroSkillData, upgrade_level: int) -> Array[StatModifier]:
	"""Convert skill bonuses into StatModifier objects"""
	var modifiers: Array[StatModifier] = []
	var source_id = "skill:" + skill_id  # Namespaced to prevent collision with equipment

	# Damage multiplier
	var damage_mult = skill_data.get_current_damage_multiplier(upgrade_level)
	if damage_mult != 1.0:
		var desc = "Skill: ×%.2f Ranged Damage" % damage_mult
		modifiers.append(StatModifier.create_multiplicative(damage_mult, source_id, desc))

	# Melee damage multiplier
	if skill_data.melee_damage_multiplier != 1.0:
		var desc = "Skill: ×%.2f Melee Damage" % skill_data.melee_damage_multiplier
		modifiers.append(StatModifier.create_multiplicative(skill_data.melee_damage_multiplier, source_id, desc))

	# Attack speed multiplier
	if skill_data.attack_speed_multiplier != 1.0:
		var desc = "Skill: ×%.2f Attack Speed" % skill_data.attack_speed_multiplier
		modifiers.append(StatModifier.create_multiplicative(skill_data.attack_speed_multiplier, source_id, desc))

	# Movement speed multiplier
	if skill_data.movement_speed_multiplier != 1.0:
		var desc = "Skill: ×%.2f Movement Speed" % skill_data.movement_speed_multiplier
		modifiers.append(StatModifier.create_multiplicative(skill_data.movement_speed_multiplier, source_id, desc))

	# Health bonus (flat)
	if skill_data.max_health_bonus != 0.0:
		var desc = "Skill: +%.0f Max Health" % skill_data.max_health_bonus
		modifiers.append(StatModifier.create_flat(skill_data.max_health_bonus, source_id, desc))

	# Range bonus (flat)
	if skill_data.range_bonus != 0.0:
		var desc = "Skill: +%.0f Range" % skill_data.range_bonus
		modifiers.append(StatModifier.create_flat(skill_data.range_bonus, source_id, desc))

	return modifiers

# ============================================
## OLD SYSTEM (DEPRECATED)
# ============================================
## Kept for backward compatibility during migration
## Will be removed once all heroes use new Stat system

func _apply_passive_skill(skill_id: String, skill_data: HeroSkillData, upgrade_level: int):
	"""DEPRECATED: Apply passive skill effects to the hero
	Use get_passive_skill_modifiers() instead for new unified stat system"""
	if not hero:
		return

	print("🔧 SkillManager: Applying passive skill: ", skill_id, " (level ", upgrade_level, ")")

	# Get multiplier for this upgrade level
	var damage_mult = skill_data.get_current_damage_multiplier(upgrade_level)

	# Apply stat modifiers to hero
	if "ranged_damage" in hero and damage_mult != 1.0:
		hero.ranged_damage *= damage_mult
		print("  → Ranged damage: ", hero.ranged_damage)

	if "melee_damage" in hero and skill_data.melee_damage_multiplier != 1.0:
		hero.melee_damage *= skill_data.melee_damage_multiplier
		print("  → Melee damage: ", hero.melee_damage)

	if "ranged_attack_speed" in hero and skill_data.attack_speed_multiplier != 1.0:
		hero.ranged_attack_speed *= skill_data.attack_speed_multiplier
		print("  → Attack speed: ", hero.ranged_attack_speed)

	if "movement_speed" in hero and skill_data.movement_speed_multiplier != 1.0:
		hero.movement_speed *= skill_data.movement_speed_multiplier
		print("  → Movement speed: ", hero.movement_speed)

	if "max_health" in hero and skill_data.max_health_bonus != 0.0:
		hero.max_health += skill_data.max_health_bonus
		hero.current_health = min(hero.current_health + skill_data.max_health_bonus, hero.max_health)
		print("  → Max health: ", hero.max_health)

	if "ranged_range" in hero and skill_data.range_bonus != 0.0:
		hero.ranged_range += skill_data.range_bonus
		print("  → Range: ", hero.ranged_range)

func recalculate_all_passives():
	"""Reapply all passive skills (use after loading saved data)"""
	for skill_id in owned_skills.keys():
		var skill_data = get_skill_data(skill_id)
		if skill_data and skill_data.skill_type == HeroSkillData.SkillType.PASSIVE:
			var upgrade_level = owned_skills[skill_id]
			_apply_passive_skill(skill_id, skill_data, upgrade_level)

func _get_total_cooldown_reduction() -> float:
	"""Calculate total cooldown reduction from all sources:
	1. Passive skills (cooldown_reduction property)
	2. WISDOM attribute bonus (from hero's _attribute_cdr_bonus)
	"""
	var total_reduction = 0.0

	# CDR from passive skills
	for skill_id in owned_skills.keys():
		var skill_data = get_skill_data(skill_id)
		if skill_data and skill_data.skill_type == HeroSkillData.SkillType.PASSIVE:
			total_reduction += skill_data.cooldown_reduction

	# CDR from WISDOM attribute (if hero has it)
	if hero and "_attribute_cdr_bonus" in hero:
		total_reduction += hero._attribute_cdr_bonus

	return min(total_reduction, 0.8)  # Cap at 80% reduction

# ============================================
# SAVE/LOAD
# ============================================

func get_save_data() -> Dictionary:
	"""Get skill data for saving"""
	return {
		"owned_skills": owned_skills.duplicate()
	}

func load_save_data(data: Dictionary):
	"""Load skill data from save"""
	if data.has("owned_skills"):
		owned_skills = data["owned_skills"].duplicate()

	# Note: skill_data_cache must be rebuilt from HeroSkillData resources
	# This should be done by the hero when loading

func load_skill_definitions(skill_definitions: Array[HeroSkillData]):
	"""Load skill data definitions (call after load_save_data)"""
	skill_data_cache.clear()

	for skill_data in skill_definitions:
		skill_data_cache[skill_data.skill_id] = skill_data

	# Reapply all passive skills
	recalculate_all_passives()

# ============================================
# DEBUG
# ============================================

func get_debug_info() -> String:
	"""Get debug info about current skills"""
	var info = "=== SKILL MANAGER DEBUG ===\n"
	info += "Owned Skills: %d\n" % owned_skills.size()

	for skill_id in owned_skills.keys():
		var level = owned_skills[skill_id]
		var skill_data = get_skill_data(skill_id)
		var skill_name = skill_data.skill_name if skill_data else "UNKNOWN"
		var on_cd = is_on_cooldown(skill_id)

		info += "  - %s (Lv %d) %s\n" % [skill_name, level, "[ON COOLDOWN]" if on_cd else "[READY]"]

		if on_cd:
			info += "    Cooldown: %.1fs\n" % get_cooldown_remaining(skill_id)

	return info
