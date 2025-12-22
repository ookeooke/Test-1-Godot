@tool
extends BaseTower

# ============================================
# MAGE TOWER - Shoots magical projectiles with AOE damage
# ============================================

# PROJECTILE
@export var projectile_scene: PackedScene

# VISUAL SCENES (Defaults for Mage)
@export_group("Visual Scenes")
@export var visual_scene_l1_default: PackedScene = preload("res://scenes/towers/visuals/mage_visuals_l1.tscn")
@export var visual_scene_l2_default: PackedScene = preload("res://scenes/towers/visuals/mage_visuals_l2.tscn")

# MAGE SPECIFIC STATS
var stat_splash_radius: Stat

var splash_radius: float:
	get: return stat_splash_radius.get_value() if stat_splash_radius else 0.0

# REFERENCES
var mage_weapon: Node2D

func _ready():
	# Mage specific setup (MUST be before super._ready)
	tower_id = "mage"
	cost = 130 # Premium Unit (Armor Pen)

	# Set defaults if not set in inspector
	if not visual_scene_l1:
		visual_scene_l1 = visual_scene_l1_default
	if not visual_scene_l2:
		visual_scene_l2 = visual_scene_l2_default

	# Initialize BaseTower logic
	super._ready()

func _initialize_stats():
	# Call base to init damage, speed, range
	super._initialize_stats()
	
	# Init mage-specific stats
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	if not level_1_stats.is_empty():
		stat_splash_radius = Stat.new(level_1_stats.get("splash_radius", 0.0))
	else:
		stat_splash_radius = Stat.new(0.0)
		
	# print("[%s] Mage stats initialized - Splash: %.1f" % [name, splash_radius])

func _process(_delta):
	if is_under_construction:
		return

	# Rotate weapon toward target
	if current_target and is_instance_valid(current_target):
		if mage_weapon:
			var target_direction = (current_target.global_position - global_position).normalized()
			mage_weapon.rotation = target_direction.angle()

func _on_shoot_timer_timeout():
	if is_under_construction:
		return

	if not current_target or not is_instance_valid(current_target):
		current_target = get_target_by_mode()

	if current_target:
		shoot_at(current_target)

func shoot_at(target):
	if not projectile_scene:
		return

	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	
	projectile.global_position = global_position
	
	# Configure projectile
	projectile.damage = damage
	projectile.target = target
	
	# Mage specific: AOE and Slow
	if "splash_radius" in projectile:
		projectile.splash_radius = splash_radius
		
	if upgrade_path == "frost" and tower_level >= 4:
		var frost_stats = TowerData.get_tower_stats(tower_id, tower_level, "frost_path")
		if not frost_stats.is_empty():
			if "slow_amount" in projectile:
				projectile.slow_amount = frost_stats.get("slow_amount", 0.5)
			if "slow_duration" in projectile:
				projectile.slow_duration = frost_stats.get("slow_duration", 2.0)

	# Initialize projectile logic
	if projectile.has_method("setup"):
		projectile.setup(target, damage, self)

# ============================================
# PATH CHOICES
# ============================================

func get_path_choices() -> Array:
	return [
		{
			"id": "inferno_path",
			"emoji": "🔥", # Inferno / High Damage
			"name": "Inferno"
		},
		{
			"id": "frost_path",
			"emoji": "❄️", # Frost / Slow
			"name": "Frost"
		}
	]

func choose_inferno_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "inferno"
	var success = upgrade_tower()
	if success:
		current_build_time = 2.5
		_update_tower_visual()
	return success

func choose_frost_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "frost"
	var success = upgrade_tower()
	if success:
		current_build_time = 2.5
		_update_tower_visual()
	return success

func _update_weapon_reference(visual_instance):
	"""Override: Find the weapon node in the new visual scene"""
	if visual_instance.has_node("Mage/Weapon"):
		mage_weapon = visual_instance.get_node("Mage/Weapon")
	else:
		mage_weapon = null

# ============================================
# MAGE SPECIFIC UPGRADES
# ============================================

# Override upgrade_tower to handle splash radius updates
func upgrade_tower():
	var old_level = tower_level
	var success = super.upgrade_tower()
	
	if success:
		# Handle splash radius upgrade
		var old_source = "upgrade_level_%d" % old_level
		stat_splash_radius.remove_modifiers_from_source(old_source)
		
		var mod_source = "upgrade_level_%d" % tower_level
		var target_stats: Dictionary
		var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
		
		if tower_level <= MAX_LEVEL_BEFORE_CHOICE:
			target_stats = TowerData.get_tower_stats(tower_id, tower_level)
		else:
			var path_key = upgrade_path + "_path"
			target_stats = TowerData.get_tower_stats(tower_id, tower_level, path_key)
			
		if not target_stats.is_empty():
			var splash_delta = target_stats.get("splash_radius", 0) - level_1_stats.get("splash_radius", 0)
			if splash_delta != 0:
				stat_splash_radius.add_modifier(StatModifier.create_flat(splash_delta, mod_source, "Level %d" % tower_level))
				
	return success
