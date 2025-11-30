class_name HeroData
extends Resource

## HeroData defines the blueprint for all heroes in the game
## Contains base stats, class info, equipment restrictions, and available skills

enum HeroClass {
	MELEE,     # Warrior, Tank - close combat
	RANGED,    # Ranger, Archer - distance attacks
	MAGIC,     # Mage, Wizard - spell casters
	SUPPORT    # Healer, Buffer - team support
}

# Core Identification
@export var hero_id: String = "ranger"
@export var hero_name: String = "Ranger"
@export_multiline var description: String = "A skilled archer who strikes from afar."
@export var hero_class: HeroClass = HeroClass.RANGED
@export var class_config: HeroClassConfig  # Reference to class template (Type Object pattern)

# Visuals
@export_group("Visuals")
@export var portrait: Texture2D
@export var hero_color: Color = Color.WHITE  # Fallback color if no portrait
@export var hero_scene: PackedScene  # The actual hero scene (e.g., ranger_hero.tscn)

# Base Stats
@export_group("Base Stats")
@export var base_health: int = 200
@export var base_damage: int = 0  ## All damage comes from equipment
@export var base_range: int = 300
@export var base_attack_speed: float = 0.6  # Seconds between attacks
@export var base_movement_speed: float = 150.0
@export var base_crit_chance: float = 0.0  # Critical hit chance (0.0 to 1.0, display as 0% to 100%)
@export var base_defense: int = 0  # Defense/armor value (reduces incoming damage)

# Progression
@export_group("Progression")
@export var unlock_cost: int = 0  # 0 = unlocked by default, >0 = must purchase
@export var starting_level: int = 1
@export var max_level: int = 20

# Equipment Restrictions (Inherited from class_config, can override per-hero)
@export_group("Equipment Restrictions")
@export var override_allowed_weapon_types: Array[String] = []  # Empty = inherit from class_config, non-empty = override
@export var override_allowed_armor_types: Array[String] = []   # Empty = inherit from class_config, non-empty = override
# Note: Accessories are always universal (rings, amulets work for everyone)
# Legacy fields (deprecated, kept for backwards compatibility)
@export var allowed_weapon_types: Array[String] = []  # DEPRECATED: Use class_config instead
@export var allowed_armor_types: Array[String] = []   # DEPRECATED: Use class_config instead

# Skills
@export_group("Skills")
@export var available_skills: Array[HeroSkillData] = []  # Skills this hero can learn

# Lore
@export_group("Presentation")
@export_multiline var lore_text: String = ""  # Backstory, flavor text


## Get effective allowed weapon types (checks override first, then class config, then legacy)
func get_allowed_weapon_types() -> Array[String]:
	# Priority 1: Override array (per-hero customization)
	if not override_allowed_weapon_types.is_empty():
		return override_allowed_weapon_types

	# Priority 2: Class config (inherited from class template)
	if class_config:
		return class_config.get_allowed_weapons()

	# Priority 3: Legacy field (backwards compatibility)
	if not allowed_weapon_types.is_empty():
		return allowed_weapon_types

	# Default: All weapons allowed
	return []


## Get effective allowed armor types (checks override first, then class config, then legacy)
func get_allowed_armor_types() -> Array[String]:
	# Priority 1: Override array (per-hero customization)
	if not override_allowed_armor_types.is_empty():
		return override_allowed_armor_types

	# Priority 2: Class config (inherited from class template)
	if class_config:
		return class_config.get_allowed_armor()

	# Priority 3: Legacy field (backwards compatibility)
	if not allowed_armor_types.is_empty():
		return allowed_armor_types

	# Default: All armor allowed
	return []


## Check if this hero can equip a specific item
func is_item_compatible(item_data: ItemData) -> bool:
	"""Check if hero can equip this item based on class restrictions"""
	if not item_data:
		return false

	# DISABLED: Allow all heroes to equip all items (no class restrictions)
	return true

	# OLD CODE (commented out for reference - can be re-enabled if needed):
	## Check weapon type restrictions
	#if item_data.equip_slot == ItemData.EquipSlot.WEAPON:
	#	var allowed_weapons = get_allowed_weapon_types()
	#	# If allowed_weapons is empty, all weapons are allowed
	#	if allowed_weapons.is_empty():
	#		return true
	#	# Check if item has weapon_type and it's in allowed list
	#	if item_data.weapon_type != "":
	#		return allowed_weapons.has(item_data.weapon_type)
	#	return false
	#
	## Check armor type restrictions
	#if item_data.equip_slot == ItemData.EquipSlot.ARMOR:
	#	var allowed_armor = get_allowed_armor_types()
	#	# If allowed_armor is empty, all armor is allowed
	#	if allowed_armor.is_empty():
	#		return true
	#	# Check if item has armor_type and it's in allowed list
	#	if item_data.armor_type != "":
	#		return allowed_armor.has(item_data.armor_type)
	#	return false
	#
	## Helmets are universal (all heroes can equip)
	#if item_data.equip_slot == ItemData.EquipSlot.HELMET:
	#	return true
	#
	## Accessories are universal (all heroes can equip)
	#if item_data.equip_slot == ItemData.EquipSlot.ACCESSORY:
	#	return true
	#
	#return false


## Get hero class as string
func get_class_name() -> String:
	match hero_class:
		HeroClass.MELEE:
			return "Melee"
		HeroClass.RANGED:
			return "Ranged"
		HeroClass.MAGIC:
			return "Magic"
		HeroClass.SUPPORT:
			return "Support"
	return "Unknown"


## Get class color for UI
func get_class_color() -> Color:
	match hero_class:
		HeroClass.MELEE:
			return Color(0.8, 0.4, 0.4)  # Red
		HeroClass.RANGED:
			return Color(0.4, 0.8, 0.4)  # Green
		HeroClass.MAGIC:
			return Color(0.6, 0.4, 0.8)  # Purple
		HeroClass.SUPPORT:
			return Color(0.4, 0.6, 0.8)  # Blue
	return Color.WHITE


## Check if hero is unlocked (free hero)
func is_free_hero() -> bool:
	return unlock_cost == 0


## Get hero level from save data (or return starting level)
func get_current_level() -> int:
	# TODO: Implement hero leveling system
	# For now, return starting level
	return starting_level
