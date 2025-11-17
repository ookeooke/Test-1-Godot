class_name HeroClassConfig
extends Resource

## HeroClassConfig defines class-level templates and restrictions
## This implements the Type Object pattern for scalable hero management
## All heroes of a class inherit from this config, reducing duplication

@export_enum("MELEE", "RANGED", "MAGIC", "SUPPORT") var class_type = 1  # 0=MELEE, 1=RANGED, 2=MAGIC, 3=SUPPORT
@export var display_name: String = ""  # Display name for this class (e.g. "Warrior", "Archer")
@export_multiline var class_description: String = ""

# Equipment Restrictions (Class-Wide)
@export_group("Equipment")
@export var allowed_weapon_types: Array[String] = []  ## e.g. ["sword", "axe", "mace", "spear"]
@export var allowed_armor_types: Array[String] = []  ## e.g. ["plate", "mail", "leather"]

# Base Stat Templates (Applied to all heroes of this class)
@export_group("Base Stats")
@export var base_health_range: Vector2i = Vector2i(200, 400)  ## Min/Max health for this class
@export var base_damage_multiplier: float = 1.0  ## Class damage scaling (1.0 = normal, 1.5 = high damage class)
@export var base_range_default: int = 240  ## Default attack range for this class
@export var base_attack_speed_default: float = 0.6  ## Default attack speed for this class
@export var base_movement_speed_default: float = 150.0  ## Default movement speed
@export var base_defense_multiplier: float = 1.0  ## Class defense scaling (1.0 = normal, 1.5 = tanky class)

# Stat Scaling Per Level
@export_group("Level Scaling")
@export var health_per_level: float = 20.0  ## How much health gained per level
@export var damage_per_level: float = 2.0  ## How much damage gained per level
@export var defense_per_level: float = 1.0  ## How much defense gained per level

# Skill Pool (All skills available to this class)
@export_group("Skills")
@export var available_skill_pool: Array[HeroSkillData] = []  ## Pool of skills this class can learn

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
		0:  # MELEE
			return "Melee"
		1:  # RANGED
			return "Ranged"
		2:  # MAGIC
			return "Magic"
		3:  # SUPPORT
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
	return (base_health_range.x + base_health_range.y) / 2
