class_name HeroClassConfig
extends Resource

## HeroClassConfig defines class-level templates and restrictions
## This implements the Type Object pattern for scalable hero management
## All heroes of a class inherit from this config, reducing duplication

@export_enum("MELEE", "RANGED", "MAGIC", "SUPPORT") var class_type = 1 # 0=MELEE, 1=RANGED, 2=MAGIC, 3=SUPPORT
@export var display_name: String = "" # Display name for this class (e.g. "Warrior", "Archer")
@export_multiline var class_description: String = ""

# Equipment Restrictions (Class-Wide)
@export_group("Equipment")
@export var allowed_weapon_types: Array[String] = [] ## e.g. ["sword", "axe", "mace", "spear"]
@export var allowed_armor_types: Array[String] = [] ## e.g. ["plate", "mail", "leather"]

# Base Stat Templates (Applied to all heroes of this class)
@export_group("Base Stats")
@export var base_health_range: Vector2i = Vector2i(200, 400) ## Min/Max health for this class
@export var base_damage_multiplier: float = 1.0 ## Class damage scaling (1.0 = normal, 1.5 = high damage class)
@export var base_range_default: int = 240 ## Default attack range for this class
@export var base_attack_speed_default: float = 0.6 ## Default attack speed for this class
@export var base_movement_speed_default: float = 150.0 ## Default movement speed
@export var base_defense_multiplier: float = 1.0 ## Class defense scaling (1.0 = normal, 1.5 = tanky class)

# Stat Scaling Per Level
@export_group("Level Scaling")
@export var health_per_level: float = 20.0 ## How much health gained per level
@export var damage_per_level: float = 2.0 ## How much damage gained per level
@export var defense_per_level: float = 1.0 ## How much defense gained per level

# Attribute Scaling Multipliers (for Hero Progression System)
# Each class benefits differently from attributes
# Default 1.0x = normal, higher = better scaling, lower = diminished
@export_group("Attribute Scaling")
@export var might_scaling: float = 1.0 ## MELEE: 1.4, RANGED: 1.0, MAGIC: 0.6, SUPPORT: 0.8
@export var agility_scaling: float = 1.0 ## MELEE: 0.8, RANGED: 1.3, MAGIC: 1.0, SUPPORT: 0.8
@export var vitality_scaling: float = 1.0 ## MELEE: 1.2, RANGED: 0.9, MAGIC: 0.8, SUPPORT: 1.2
@export var wisdom_scaling: float = 1.0 ## MELEE: 0.6, RANGED: 1.0, MAGIC: 1.5, SUPPORT: 1.2

# Skill Pool (All skills available to this class)
@export_group("Skills")
@export var available_skill_pool: Array[HeroSkillData] = [] ## Pool of skills this class can learn

# Skill Loadout Slots (How many skills can be equipped)
@export_group("Skill Loadout Slots")
@export var max_active_ability_slots: int = 2 ## Max active skills in battle (shown on HUD)
@export var max_passive_ability_slots: int = 4 ## Max passive skills (always-on, inspectable in management UI)

# Visual Defaults
@export_group("Presentation")
@export var class_color: Color = Color.WHITE
@export var class_icon: Texture2D


## Get display name for this class
func get_display_name() -> String:
	if display_name != "":
		return display_name
	# Fallback to type index
	match class_type:
		0: # MELEE
			return "Melee"
		1: # RANGED
			return "Ranged"
		2: # MAGIC
			return "Magic"
		3: # SUPPORT
			return "Support"
	return "Unknown"


## Get all allowed weapon types for this class
func get_allowed_weapons() -> Array[String]:
	return allowed_weapon_types


## Get all allowed armor types for this class
func get_allowed_armor() -> Array[String]:
	return allowed_armor_types


## Get class-specific stat multiplier
func get_stat_multiplier(stat_name: String) -> float:
	match stat_name:
		"damage":
			return base_damage_multiplier
		"defense":
			return base_defense_multiplier
		_:
			return 1.0


## Get recommended starting health for a hero of this class
func get_recommended_health() -> int:
	return int((base_health_range.x + base_health_range.y) / 2.0)


## Get attribute scaling multiplier for a specific attribute
func get_attribute_scaling(attribute: String) -> float:
	match attribute.to_lower():
		"might":
			return might_scaling
		"agility":
			return agility_scaling
		"vitality":
			return vitality_scaling
		"wisdom":
			return wisdom_scaling
		_:
			return 1.0


## Get all attribute scaling values as a dictionary
func get_all_attribute_scaling() -> Dictionary:
	return {
		"might": might_scaling,
		"agility": agility_scaling,
		"vitality": vitality_scaling,
		"wisdom": wisdom_scaling
	}


## Calculate scaled attribute bonus (applies class multiplier)
## attribute_points: Number of points in the attribute
## base_bonus_per_point: The base bonus per point (before class scaling)
## soft_cap: Point threshold where diminishing returns begin (default 30)
func calculate_scaled_attribute_bonus(attribute: String, attribute_points: int, base_bonus_per_point: float, soft_cap: int = 30) -> float:
	var scaling = get_attribute_scaling(attribute)

	# Apply soft cap (50% effectiveness after cap)
	var effective_bonus: float
	if attribute_points <= soft_cap:
		effective_bonus = attribute_points * base_bonus_per_point
	else:
		var over = attribute_points - soft_cap
		effective_bonus = (soft_cap * base_bonus_per_point) + (over * base_bonus_per_point * 0.5)

	# Apply class scaling
	return effective_bonus * scaling
