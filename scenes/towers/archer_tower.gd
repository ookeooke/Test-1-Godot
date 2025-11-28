@tool
extends BaseTower

# ============================================
# ARCHER TOWER - Specific Implementation
# ============================================

# PROJECTILE
@export var projectile_scene: PackedScene

# VISUAL SCENES (Defaults for Archer)
@export_group("Visual Scenes")
@export var visual_scene_l1_default: PackedScene = preload("res://scenes/towers/visuals/archer_visuals_l1.tscn")
@export var visual_scene_l2_default: PackedScene = preload("res://scenes/towers/visuals/archer_visuals_l2.tscn")
@export var visual_scene_l3_default: PackedScene = preload("res://scenes/towers/visuals/archer_visuals_l3.tscn")

# REFERENCES
var archer_weapon: Node2D

func _ready():
	# Archer specific setup (MUST be before super._ready)
	tower_id = "archer"

	# Set defaults if not set in inspector
	if not visual_scene_l1:
		visual_scene_l1 = visual_scene_l1_default
	if not visual_scene_l2:
		visual_scene_l2 = visual_scene_l2_default
	if not visual_scene_l3:
		visual_scene_l3 = visual_scene_l3_default
		
	# Initialize BaseTower logic
	super._ready()

func _process(_delta):
	# Base process handles construction check
	if is_under_construction:
		return

	# Rotate archer's weapon toward the current target
	if current_target and is_instance_valid(current_target):
		if archer_weapon:
			archer_weapon.look_at(current_target.global_position)
			
		# Visual debug
		if DebugConfig.visual_debug_enabled and debug_line:
			debug_line.visible = true
			debug_line.points = [Vector2.ZERO, to_local(current_target.global_position)]
	else:
		if debug_line:
			debug_line.visible = false
			
	if DebugConfig.visual_debug_enabled:
		queue_redraw()

func _on_shoot_timer_timeout():
	if is_under_construction:
		return
		
	# Ensure we have a valid target
	if not current_target or not is_instance_valid(current_target):
		current_target = get_target_by_mode()
		
	if current_target:
		shoot_at(current_target)

func shoot_at(target):
	if not projectile_scene:
		return
		
	var projectile = projectile_scene.instantiate()
	
	# Determine spawn position (tip of weapon or center of tower)
	var spawn_pos = global_position
	if archer_weapon:
		# Try to find a "Muzzle" marker
		if archer_weapon.has_node("Muzzle"):
			spawn_pos = archer_weapon.get_node("Muzzle").global_position
		else:
			# Fallback: slightly offset in rotation direction
			var offset = Vector2.RIGHT.rotated(archer_weapon.global_rotation) * 20
			spawn_pos = archer_weapon.global_position + offset
			
	projectile.global_position = spawn_pos
	
	# Add to scene FIRST so it's in the tree
	get_tree().root.add_child(projectile)
	
	# Initialize projectile logic (trajectory, prediction, etc.)
	if projectile.has_method("setup"):
		projectile.setup(target, damage, self)
	else:
		# Fallback for simple projectiles
		projectile.target = target
		projectile.damage = damage
	
	# Play sound if available
	# if has_node("ShootSound"): $ShootSound.play()

func _update_weapon_reference(visual_instance):
	"""Override: Find the weapon node in the new visual scene"""
	if visual_instance.has_node("Archer/Weapon"):
		archer_weapon = visual_instance.get_node("Archer/Weapon")
	else:
		# Try to find recursively or by type if needed
		archer_weapon = null

# ============================================
# PATH CHOICES
# ============================================

func get_path_choices() -> Array:
	return [
		{
			"id": "damage_path",
			"emoji": "🏹", # Sniper / High Damage
			"name": "Sniper"
		},
		{
			"id": "range_path",
			"emoji": "👁️", # Longbow / High Range
			"name": "Longbow"
		}
	]

func choose_damage_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "damage"
	return upgrade_tower()

func choose_range_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "range"
	return upgrade_tower()
