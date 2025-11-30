extends "res://scenes/heroes/base_hero.gd"

# ============================================
# MAGE HERO - Inherits from BaseHero
# ============================================

# CLASS TYPE (for attribute scaling)
const CLASS_TYPE_MAGIC: int = 2 # Matches HeroClassConfig.class_type

# PROJECTILE
@export var projectile_scene: PackedScene

# ============================================
# INITIALIZATION OVERRIDES
# ============================================

func _ready():
	# Set base stats before calling super._ready()
	BASE_MAX_HEALTH = 200.0
	BASE_RANGED_DAMAGE = 0.0
	BASE_MELEE_DAMAGE = 0.0
	BASE_RANGED_RANGE = 350.0
	BASE_RANGED_ATTACK_SPEED = 0.8
	BASE_MOVEMENT_SPEED = 130.0
	
	super._ready()
	
	set_meta("hero_name", "Mage")
	set_meta("hero_class", "mage")

func _generate_unique_hero_id() -> String:
	return "mage"

func _get_class_type() -> int:
	return CLASS_TYPE_MAGIC

func _equip_starter_gear() -> void:
	# TODO: Equip starter staff
	pass

# ============================================
# COMBAT OVERRIDES
# ============================================

func perform_ranged_attack(target):
	if projectile_scene == null:
		push_error("Cannot execute ranged attack: projectile_scene is null")
		return
		
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	if projectile_spawn_node:
		projectile.global_position = projectile_spawn_node.global_position
	else:
		projectile.global_position = global_position
		
	# Assuming arrow.gd has setup(target, damage, source)
	if projectile.has_method("setup"):
		projectile.setup(target, ranged_damage, self)
