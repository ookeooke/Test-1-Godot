extends "res://scenes/projectiles/arrow.gd"

# ============================================
# ARTILLERY SHELL PROJECTILE - Heavy AOE Damage
# ============================================
# Extends arrow projectile to add:
# - Splash damage (AOE)
# - Knockback effects (for Cannon path)
# - High arc trajectory
# ============================================

# AOE PROPERTIES
var splash_radius: float = 0.0  # AOE damage radius
var knockback: float = 0.0      # Knockback force

# ============================================
# SETUP
# ============================================

func setup(enemy, projectile_damage, projectile_source = null):
	"""Override setup to use high arc for artillery"""
	super.setup(enemy, projectile_damage, projectile_source)
	# Artillery has very high arc trajectory
	arc_height = 80.0

# ============================================
# HIT DETECTION - Override for AOE
# ============================================

func _hit_enemy(enemy):
	"""Deal damage to enemy (with AOE if splash_radius > 0)"""
	if splash_radius > 0:
		_deal_aoe_damage(enemy)
	else:
		_deal_single_damage(enemy)

	queue_free()

func _deal_single_damage(enemy):
	"""Deal damage to single target (same as arrow)"""
	var source_type = "tower"
	if source and source.has_method("get_hero_id"):
		source_type = "hero_ranged"

	if BalanceTracker and source:
		BalanceTracker.record_damage(source, enemy, damage, source_type)

	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, source, source_type)

	# Apply knockback effect
	_apply_knockback_to_enemy(enemy, enemy.global_position)

func _deal_aoe_damage(primary_target):
	"""Deal splash damage to all enemies in radius"""
	var hit_position = primary_target.global_position
	var space_state = get_world_2d().direct_space_state

	# Create circle shape for AOE detection
	var shape = CircleShape2D.new()
	shape.radius = splash_radius

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, hit_position)
	query.collision_mask = 1  # Enemy layer
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results = space_state.intersect_shape(query)

	# Track source type
	var source_type = "tower"
	if source and source.has_method("get_hero_id"):
		source_type = "hero_ranged"

	# Apply damage and knockback to all hit enemies
	for result in results:
		var enemy = result.collider
		if enemy and is_instance_valid(enemy) and enemy.is_in_group("enemy"):
			# Track damage
			if BalanceTracker and source:
				BalanceTracker.record_damage(source, enemy, damage, source_type)

			# Deal damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, source, source_type)

			# Apply knockback effect
			_apply_knockback_to_enemy(enemy, hit_position)

func _apply_knockback_to_enemy(enemy, explosion_pos: Vector2):
	"""Apply knockback effect if cannon path"""
	if knockback > 0:
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(knockback, explosion_pos)
		else:
			# Fallback: just log warning, don't crash
			print("[ArtilleryShell] Warning: Enemy doesn't have apply_knockback method")
