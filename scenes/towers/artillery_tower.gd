@tool
extends BaseTower

# ============================================
# ARTILLERY TOWER - High damage, slow fire, AOE
# ============================================

# PROJECTILE
@export var projectile_scene: PackedScene

# VISUAL SCENES (Defaults for Artillery)
@export_group("Visual Scenes")
@export var visual_scene_l1_default: PackedScene = preload("res://scenes/towers/visuals/artillery_visuals_l1.tscn")
@export var visual_scene_l2_default: PackedScene = preload("res://scenes/towers/visuals/artillery_visuals_l2.tscn")
# ARTILLERY SPECIFIC STATS
var stat_splash_radius: Stat
var stat_min_range: Stat # Artillery cannot shoot too close
@export var debug_force_splash_radius: float = 0.0 # Set >0 to force splash radius for testing

var splash_radius: float:
	get:
		if debug_force_splash_radius > 0.0:
			return debug_force_splash_radius
		return stat_splash_radius.get_value() if stat_splash_radius else 0.0

var min_range: float:
	get: return stat_min_range.get_value() if stat_min_range else 0.0

# REFERENCES
var artillery_weapon: Node2D

func _ready():
	# Artillery specific setup
	tower_id = "artillery"

	# Set defaults
	if not visual_scene_l1:
		visual_scene_l1 = visual_scene_l1_default
	if not visual_scene_l2:
		visual_scene_l2 = visual_scene_l2_default

	# Initialize BaseTower logic
	super._ready()

func _initialize_stats():
	super._initialize_stats()
	
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)
	if not level_1_stats.is_empty():
		stat_splash_radius = Stat.new(level_1_stats.get("splash_radius", 0.0))
		stat_min_range = Stat.new(level_1_stats.get("min_range", 0.0))
	else:
		stat_splash_radius = Stat.new(0.0)
		stat_min_range = Stat.new(0.0)
		
	print("[%s] Artillery stats initialized - Splash: %.1f, MinRange: %.1f" % [name, splash_radius, min_range])

func _process(_delta):
	if is_under_construction:
		return

	# Rotate weapon toward target
	if current_target and is_instance_valid(current_target):
		if artillery_weapon:
			var target_direction = (current_target.global_position - global_position).normalized()
			artillery_weapon.rotation = target_direction.angle()

func _on_shoot_timer_timeout():
	if is_under_construction:
		return

	if not current_target or not is_instance_valid(current_target):
		current_target = get_target_by_mode()

	# Artillery specific: Check minimum range
	if current_target:
		var distance = global_position.distance_to(current_target.global_position)
		if distance < min_range:
			# Target too close! Try to find another one
			# For now, just don't shoot (or we could implement smart retargeting here)
			return
			
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
	
	if "splash_radius" in projectile:
		projectile.splash_radius = splash_radius
		
	# Initialize projectile logic
	if projectile.has_method("setup"):
		projectile.setup(target, damage, self)

func _update_weapon_reference(visual_instance):
	if visual_instance.has_node("Artillery/Weapon"):
		artillery_weapon = visual_instance.get_node("Artillery/Weapon")
	else:
		artillery_weapon = null

# ============================================
# ARTILLERY SPECIFIC UPGRADES
# ============================================

func get_path_choices() -> Array:
	return [
		{
			"id": "cannon_path",
			"emoji": "💣", # Cannon / High Damage
			"name": "Cannon"
		},
		{
			"id": "mortar_path",
			"emoji": "💥", # Mortar / AOE
			"name": "Mortar"
		}
	]

func choose_cannon_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "cannon"
	var success = upgrade_tower()
	if success:
		current_build_time = 2.5
		_update_tower_visual()
	return success

func choose_mortar_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "mortar"
	var success = upgrade_tower()
	if success:
		current_build_time = 2.5
		_update_tower_visual()
	return success

# Override upgrade_tower to handle splash/min_range updates
func upgrade_tower():
	var old_level = tower_level
	var success = super.upgrade_tower()
	
	if success:
		var old_source = "upgrade_level_%d" % old_level
		stat_splash_radius.remove_modifiers_from_source(old_source)
		stat_min_range.remove_modifiers_from_source(old_source)
		
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
				
			var min_range_delta = target_stats.get("min_range", 0) - level_1_stats.get("min_range", 0)
			if min_range_delta != 0:
				stat_min_range.add_modifier(StatModifier.create_flat(min_range_delta, mod_source, "Level %d" % tower_level))
				
	return success
