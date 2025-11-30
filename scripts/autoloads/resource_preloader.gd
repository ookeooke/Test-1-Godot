extends Node

## ResourcePreloader
## A "Hack" to force Godot to export resources that are only loaded dynamically.
## By preloading them here, Godot sees them as dependencies and includes them.

# HEROES
var _hero_1 = preload("res://resources/heroes/mage.tres")
var _hero_2 = preload("res://resources/heroes/ranger.tres")
var _hero_3 = preload("res://resources/heroes/warrior.tres")

# ITEMS - WEAPONS
var _wep_1 = preload("res://resources/items/weapons/basic_bow.tres")
var _wep_2 = preload("res://resources/items/weapons/basic_staff.tres")
var _wep_3 = preload("res://resources/items/weapons/basic_sword.tres")

# ITEMS - ARMOR
var _arm_1 = preload("res://resources/items/armor/leather_vest.tres")
var _arm_2 = preload("res://resources/items/helmets/leather_cap.tres")

# ITEMS - ACCESSORIES
var _acc_1 = preload("res://resources/items/accessories/power_ring.tres")

# HERO CLASSES
var _cls_1 = preload("res://resources/hero_classes/magic_class.tres")
var _cls_2 = preload("res://resources/hero_classes/melee_class.tres")
var _cls_3 = preload("res://resources/hero_classes/ranged_class.tres")
var _cls_4 = preload("res://resources/hero_classes/support_class.tres")

# AFFIXES
var _pfx_1 = preload("res://resources/affixes/prefixes/bronze_prefix.tres")
var _pfx_2 = preload("res://resources/affixes/prefixes/iron_prefix.tres")
var _pfx_3 = preload("res://resources/affixes/prefixes/tough_prefix.tres")
var _sfx_1 = preload("res://resources/affixes/suffixes/of_precision_suffix.tres")
var _sfx_2 = preload("res://resources/affixes/suffixes/of_strength_suffix.tres")
var _sfx_3 = preload("res://resources/affixes/suffixes/of_vitality_suffix.tres")

# SKILLS
var _skl_1 = preload("res://resources/skills/ranger/eagle_eye.tres")
var _skl_2 = preload("res://resources/skills/ranger/multishot.tres")
var _skl_3 = preload("res://resources/skills/ranger/poison_arrow.tres")
var _skl_4 = preload("res://resources/skills/ranger/rapid_fire.tres")
var _skl_5 = preload("res://resources/skills/ranger/sniper_shot.tres")

# THEMES & UI
var _thm_1 = preload("res://resources/themes/main_theme.tres")
var _ui_1 = preload("res://resources/ui/hero_selection_group.tres")

func _ready():
	print("[ResourcePreloader] ☢️ FORCE-LOADED 26 RESOURCES FOR EXPORT ☢️")
