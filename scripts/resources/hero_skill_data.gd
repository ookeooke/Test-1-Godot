extends Resource
class_name HeroSkillData

## ============================================
## HERO SKILL DATA - Resource for skill definitions
## ============================================
##
## Defines a single hero skill (active or passive)
## Used for both unlocking and upgrading skills

# ============================================
# SKILL TYPES
# ============================================

enum SkillType {
	PASSIVE,  # Auto-applies when owned (stat bonuses)
	ACTIVE    # Player-activated with cooldown
}

enum SkillCategory {
	COMBAT,      # Damage, attack speed
	DEFENSE,     # Health, armor
	MOBILITY,    # Movement speed, dodge
	UTILITY      # Special abilities
}

# ============================================
# BASIC PROPERTIES
# ============================================

@export var skill_id: String = ""  # Unique identifier (e.g., "ranger_multishot")
@export var skill_name: String = ""  # Display name (e.g., "Multishot")
@export_multiline var description: String = ""  # What the skill does
@export var icon: Texture2D  # Skill icon for UI
@export var skill_type: SkillType = SkillType.PASSIVE
@export var category: SkillCategory = SkillCategory.COMBAT

# ============================================
# UNLOCK AND UPGRADE
# ============================================

@export var unlock_cost: int = 100  # Gold cost to unlock
@export var max_upgrade_level: int = 1  # How many times can be upgraded (1 = no upgrades)
@export var upgrade_costs: Array[int] = []  # Cost for each upgrade level [level2, level3, ...]

# Requirements
@export var required_hero_level: int = 1  # Hero must be this level to use
@export var required_skills: Array[String] = []  # Other skill IDs that must be unlocked first

# ============================================
# ACTIVE SKILL PROPERTIES
# ============================================

@export_group("Active Skill Settings")
@export var cooldown: float = 30.0  # Seconds between uses
@export var duration: float = 0.0  # Duration of effect (0 = instant)
@export var mana_cost: int = 0  # Mana cost (if you add mana system later)
@export var cast_range: float = 0.0  # Range for targeted abilities (0 = self/auto)

# ============================================
# PASSIVE SKILL EFFECTS (STAT MODIFIERS)
# ============================================

@export_group("Passive Effects")
# Multipliers (1.0 = no change, 1.5 = +50%)
@export var damage_multiplier: float = 1.0  # Ranged damage
@export var melee_damage_multiplier: float = 1.0  # Melee damage
@export var attack_speed_multiplier: float = 1.0  # Attack speed
@export var movement_speed_multiplier: float = 1.0  # Movement speed
@export var cooldown_reduction: float = 0.0  # Reduces all cooldowns by % (0.2 = -20%)

# Flat bonuses
@export var max_health_bonus: float = 0.0  # +HP
@export var range_bonus: float = 0.0  # +Range
@export var armor_bonus: float = 0.0  # Damage reduction (for future)

# Special effects
@export var crit_chance: float = 0.0  # % chance to deal double damage
@export var lifesteal_percent: float = 0.0  # % of damage healed
@export var dodge_chance: float = 0.0  # % chance to avoid damage

# ============================================
# PER-LEVEL SCALING
# ============================================

# These arrays define how the skill improves with each upgrade
# Index 0 = base level, Index 1 = level 2, etc.
@export_group("Upgrade Scaling")
@export var damage_multiplier_per_level: Array[float] = []  # [1.0, 1.2, 1.5]
@export var cooldown_per_level: Array[float] = []  # [30.0, 25.0, 20.0]
@export var duration_per_level: Array[float] = []  # [5.0, 7.0, 10.0]

# ============================================
# VISUAL AND AUDIO
# ============================================

@export_group("Presentation")
@export var activation_sound: AudioStream  # Sound when activated
@export var particle_effect: PackedScene  # VFX when activated
@export var animation_name: String = ""  # Hero animation to play

# ============================================
# HELPER FUNCTIONS
# ============================================

func get_current_cooldown(upgrade_level: int) -> float:
	"""Get cooldown at specific upgrade level"""
	if cooldown_per_level.is_empty():
		return cooldown

	var index = clampi(upgrade_level - 1, 0, cooldown_per_level.size() - 1)
	return cooldown_per_level[index]

func get_current_damage_multiplier(upgrade_level: int) -> float:
	"""Get damage multiplier at specific upgrade level"""
	if damage_multiplier_per_level.is_empty():
		return damage_multiplier

	var index = clampi(upgrade_level - 1, 0, damage_multiplier_per_level.size() - 1)
	return damage_multiplier_per_level[index]

func get_current_duration(upgrade_level: int) -> float:
	"""Get duration at specific upgrade level"""
	if duration_per_level.is_empty():
		return duration

	var index = clampi(upgrade_level - 1, 0, duration_per_level.size() - 1)
	return duration_per_level[index]

func get_upgrade_cost(current_level: int) -> int:
	"""Get cost to upgrade from current_level to next level"""
	if current_level >= max_upgrade_level:
		return 0  # Already max level

	var index = current_level - 1  # current_level 1 → index 0 (cost to go to level 2)
	if index < 0 or index >= upgrade_costs.size():
		return 0

	return upgrade_costs[index]

func is_unlockable() -> bool:
	"""Check if this skill can be unlocked (ignoring cost)"""
	# Could add more complex requirements here
	return true

func get_display_description(upgrade_level: int = 1) -> String:
	"""Get description with current values filled in"""
	var desc = description

	# Replace placeholders with actual values
	if skill_type == SkillType.ACTIVE:
		desc = desc.replace("{cooldown}", str(get_current_cooldown(upgrade_level)))
		desc = desc.replace("{duration}", str(get_current_duration(upgrade_level)))

	if damage_multiplier > 1.0:
		var bonus = (get_current_damage_multiplier(upgrade_level) - 1.0) * 100.0
		desc = desc.replace("{damage_bonus}", str(int(bonus)))

	return desc
