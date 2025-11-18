class_name AffixData
extends Resource

## AffixData defines a single prefix or suffix that can appear on magic/rare items
## Based on Diablo 2's affix system

enum AffixType {
	PREFIX,  # Appears before item name ("Bronze Sword")
	SUFFIX   # Appears after item name ("Sword of Strength")
}

enum StatType {
	DAMAGE,         # Adds flat damage
	HEALTH,         # Adds flat health
	DEFENSE,        # Adds flat defense
	CRIT_CHANCE,    # Adds crit chance percentage
	ATTACK_SPEED    # Multiplies attack speed
}

# Core Properties
@export var affix_id: String = ""  ## Unique identifier (e.g., "bronze_prefix", "of_strength_suffix")
@export var affix_name: String = ""  ## Display name (e.g., "Bronze", "of Strength")
@export var affix_type: AffixType = AffixType.PREFIX

# Stat Modification
@export var stat_type: StatType = StatType.DAMAGE
@export var min_value: float = 0.0  ## Minimum rolled value
@export var max_value: float = 0.0  ## Maximum rolled value

# Requirements
@export var required_item_level: int = 1  ## Minimum item level to roll this affix
@export var affix_level: int = 1  ## Affix level (affects character level requirement)

# Family System (prevents duplicate affix types)
@export var affix_family: String = ""  ## e.g., "damage_prefix", "resist_suffix" - only one affix per family


## Roll a random value for this affix within its range
func roll_value() -> float:
	if max_value <= min_value:
		return min_value

	# Integer stats (damage, health, defense)
	if stat_type in [StatType.DAMAGE, StatType.HEALTH, StatType.DEFENSE]:
		return float(randi_range(int(min_value), int(max_value)))

	# Float stats (crit chance, attack speed)
	return randf_range(min_value, max_value)


## Get a formatted stat description
func get_stat_description(rolled_value: float) -> String:
	match stat_type:
		StatType.DAMAGE:
			return "+%d Damage" % int(rolled_value)
		StatType.HEALTH:
			return "+%d Health" % int(rolled_value)
		StatType.DEFENSE:
			return "+%d Defense" % int(rolled_value)
		StatType.CRIT_CHANCE:
			return "+%.1f%% Critical Strike" % (rolled_value * 100)
		StatType.ATTACK_SPEED:
			var bonus_pct = (rolled_value - 1.0) * 100
			return "%+.0f%% Attack Speed" % bonus_pct

	return ""


## Convert affix to StatModifier for equipment system
func to_stat_modifier(rolled_value: float, source_id: String) -> StatModifier:
	var description = get_stat_description(rolled_value)

	match stat_type:
		StatType.DAMAGE, StatType.HEALTH, StatType.DEFENSE:
			return StatModifier.create_flat(int(rolled_value), source_id, description)

		StatType.CRIT_CHANCE:
			# Crit chance uses additive modifier (percentage)
			return StatModifier.create_additive(rolled_value * 100, source_id, description)

		StatType.ATTACK_SPEED:
			# Attack speed uses multiplicative modifier
			return StatModifier.create_multiplicative(rolled_value, source_id, description)

	# Fallback
	return StatModifier.create_flat(0, source_id, "Unknown")
