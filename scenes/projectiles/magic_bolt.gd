extends "res://scenes/projectiles/arrow.gd"

# ============================================
# MAGIC BOLT PROJECTILE - AOE Magic Damage
# ============================================
# Extends arrow projectile to add:
# - Splash damage (AOE)
# - Slow effects (for Frost path)
# ============================================

# AOE PROPERTIES
var splash_radius: float = 70.0  # AOE damage radius
var slow_amount: float = 0.0     # Speed reduction (0.0-1.0, where 0.5 = 50% slow)
var slow_duration: float = 0.0   # Slow duration in seconds

# ============================================
# SETUP
# ============================================

func setup(enemy, projectile_damage, projectile_source = null):
	"""Override setup to use flatter arc for magic"""
	super.setup(enemy, projectile_damage, projectile_source)
	# Magic bolts have flatter trajectory than arrows
	arc_height = 30.0

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

	# Apply slow effect
	_apply_slow_to_enemy(enemy)

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

	# Apply damage to all hit enemies
	for result in results:
		var enemy = result.collider
		if enemy and is_instance_valid(enemy) and enemy.is_in_group("enemy"):
			# Track damage
			if BalanceTracker and source:
				BalanceTracker.record_damage(source, enemy, damage, source_type)

			# Deal damage
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, source, source_type)

			# Apply slow effect
			_apply_slow_to_enemy(enemy)

func _apply_slow_to_enemy(enemy):
	"""Apply slow effect if frost path"""
	if slow_amount > 0 and slow_duration > 0:
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_amount, slow_duration)
		else:
			# Fallback: just log warning, don't crash
			print("[MagicBolt] Warning: Enemy doesn't have apply_slow method")
