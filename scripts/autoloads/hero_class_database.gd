extends Node

## HeroClassDatabase - Centralized management of hero class configurations
## Implements the Type Object pattern for scalable hero class management
## Preloads all class configs for fast runtime access

const CLASSES_PATH = "res://resources/hero_classes/"

# Preload all class configurations
const MELEE_CLASS = preload("res://resources/hero_classes/melee_class.tres")
const RANGED_CLASS = preload("res://resources/hero_classes/ranged_class.tres")
const MAGIC_CLASS = preload("res://resources/hero_classes/magic_class.tres")
const SUPPORT_CLASS = preload("res://resources/hero_classes/support_class.tres")

# Class config dictionary for fast lookup
var classes: Dictionary = {}


func _ready():
	_initialize_classes()
	print("[HeroClassDatabase] Initialized with %d class configurations" % classes.size())


## Initialize the class configuration dictionary
func _initialize_classes() -> void:
	classes[0] = MELEE_CLASS # MELEE
	classes[1] = RANGED_CLASS # RANGED
	classes[2] = MAGIC_CLASS # MAGIC
	classes[3] = SUPPORT_CLASS # SUPPORT


## Get class configuration for a specific class type
func get_class_config(class_type: int) -> HeroClassConfig:
	if classes.has(class_type):
		return classes[class_type] as HeroClassConfig

	push_error("[HeroClassDatabase] No configuration found for class type: %d" % class_type)
	return null


## Get allowed weapon types for a class
func get_allowed_weapons(class_type: int) -> Array[String]:
	var config = get_class_config(class_type)
	if config:
		return config.get_allowed_weapons()
	return []


## Get allowed armor types for a class
func get_allowed_armor(class_type: int) -> Array[String]:
	var config = get_class_config(class_type)
	if config:
		return config.get_allowed_armor()
	return []


## Get skill pool for a class
func get_skills_for_class(class_type: int) -> Array[HeroSkillData]:
	var config = get_class_config(class_type)
	if config:
		return config.available_skill_pool
	return []


## Get class display name
func get_class_name(class_type: int) -> String:
	var config = get_class_config(class_type)
	if config:
		return config.get_display_name()
	return "Unknown"


## Get class color for UI
func get_class_color(class_type: int) -> Color:
	var config = get_class_config(class_type)
	if config:
		return config.class_color
	return Color.WHITE


## Get all class types
func get_all_class_types() -> Array:
	return classes.keys()


## Debug: Print all class configurations
func debug_print_classes() -> void:
	print("=== Hero Class Database ===")
	for class_type in classes.keys():
		var config: HeroClassConfig = classes[class_type]
		print("Class: %s" % config.get_display_name())
		print("  Weapons: %s" % str(config.allowed_weapon_types))
		print("  Armor: %s" % str(config.allowed_armor_types))
		print("  Health Range: %s" % str(config.base_health_range))
		print("  Damage Mult: %.2f" % config.base_damage_multiplier)
		print("  Defense Mult: %.2f" % config.base_defense_multiplier)
