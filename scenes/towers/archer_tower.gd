extends StaticBody2D

# ============================================
# ARCHER TOWER - Shoots arrows at enemies
# ============================================
#
# TARGETING SYSTEM (Kingdom Rush Style):
# - Targets the enemy FURTHEST along the path (closest to exit)
# - Uses path progress_ratio, NOT distance to tower
# - Once locked onto a target, keeps shooting until it dies or leaves range
# - Only switches targets when necessary (target persistence)
# ============================================

# TOWER STATS
var damage = 15
var attack_speed = 1.2  # Attacks per second
var range_radius = 300  # Detection range

# REFERENCES
var detection_range: Area2D
var range_indicator: Polygon2D  # Changed from Line2D to Polygon2D for filled circle
var shoot_timer: Timer
var archer_weapon: Node2D  # The weapon that rotates toward enemies

# SELECTION STATE
var is_selected = false

# TARGETING
var enemies_in_range = []  # List of enemies we can shoot
var current_target = null  # Enemy we're currently aiming at

# PROJECTILE
@export var projectile_scene: PackedScene

# TOWER SPOT reference (set by tower_spot when placing)
var parent_spot = null

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Get references to child nodes
	detection_range = $DetectionRange
	range_indicator = $RangeIndicator

	# Get archer weapon reference
	if has_node("Archer/Weapon"):
		archer_weapon = $Archer/Weapon

	# IMPORTANT: Set collision mask to detect enemies (layer 1)
	detection_range.collision_layer = 8  # Tower range is layer 4
	detection_range.collision_mask = 1   # Detect enemies on layer 1

	# Connect detection signals
	detection_range.body_entered.connect(_on_enemy_entered_range)
	detection_range.body_exited.connect(_on_enemy_exited_range)

	# Create shoot timer
	shoot_timer = Timer.new()
	shoot_timer.wait_time = 1.0 / attack_speed  # Convert attacks/sec to seconds
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	shoot_timer.start()

	# Draw range indicator (filled circle)
	draw_range_circle()

	# Hide range by default (show only when selected)
	range_indicator.visible = false

	# CHANGED: Register with ClickManager
	# Wait a frame for parent_spot to be set
	await get_tree().process_frame
	ClickManager.register_clickable(self, ClickManager.ClickPriority.TOWER, 50.0)
	print("✓ Archer tower registered with ClickManager at: ", global_position)

func _process(delta):
	# Rotate archer's weapon toward the current target
	if current_target and is_instance_valid(current_target):
		if archer_weapon:
			# Make weapon point at enemy
			archer_weapon.look_at(current_target.global_position)

# ============================================
# CLICK CALLBACKS - Called by ClickManager
# ============================================

func on_clicked(is_double_click: bool):
	"""Called when tower is clicked"""
	print("🎯 Tower clicked!")
	
	# Find the parent tower spot and emit its signal
	if parent_spot:
		print("  Parent spot found: ", parent_spot.name)
		print("  Emitting tower_clicked signal")
		parent_spot.tower_clicked.emit(parent_spot, self)
	else:
		# Fallback: try to find parent spot by going up the tree
		print("  WARNING: parent_spot not set, trying to find via parent")
		var spot = get_parent()
		if spot and spot.has_signal("tower_clicked"):
			print("  Found parent spot via get_parent(): ", spot.name)
			spot.tower_clicked.emit(spot, self)
		else:
			print("  ERROR: Could not find parent tower spot!")

func on_hover_start():
	"""Called when mouse enters tower area"""
	# Brighten the tower visual
	if $TowerVisual:
		$TowerVisual.modulate = Color(1.3, 1.3, 1.3)

func on_hover_end():
	"""Called when mouse leaves tower area"""
	# Reset tower visual
	if $TowerVisual:
		$TowerVisual.modulate = Color(1, 1, 1)

# ============================================
# TARGETING FUNCTIONS
# ============================================

func _on_enemy_entered_range(body):
	# An enemy entered our range
	if body.is_in_group("enemy"):
		# Add enemy to tracking list
		# Note: We trust Godot's physics - if collision shapes overlapped, enemy is in range
		enemies_in_range.append(body)

		# Connect to enemy death signal for immediate cleanup
		if body.has_signal("enemy_died") and not body.enemy_died.is_connected(_on_enemy_died):
			body.enemy_died.connect(_on_enemy_died.bind(body))

		# Debug output
		var distance = global_position.distance_to(body.global_position)
		print("  ✓ Enemy entered range: ", body.get_enemy_name() if body.has_method("get_enemy_name") else "Enemy", " (distance: %.1f px)" % distance)

func _on_enemy_exited_range(body):
	# An enemy left our range
	if body.is_in_group("enemy"):
		enemies_in_range.erase(body)
		print("  ← Enemy left range: ", body.get_enemy_name() if body.has_method("get_enemy_name") else "Unknown")


func _on_enemy_died(enemy):
	"""Called when an enemy dies - remove immediately and retarget"""
	# Remove from tracking list
	enemies_in_range.erase(enemy)

	# If this was our current target, immediately find new target
	if current_target == enemy:
		print("⚠ Current target died! Retargeting immediately...")
		current_target = get_furthest_enemy()

		# If we found a new target and we're ready to shoot, shoot immediately
		# This prevents DPS downtime during intense waves
		if current_target != null and shoot_timer.time_left < 0.1:
			shoot_at(current_target)

func get_furthest_enemy():
	"""Find the enemy furthest along the path (Kingdom Rush style)"""
	# Clean up dead/invalid enemies first
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))

	if enemies_in_range.is_empty():
		return null

	# TARGET PERSISTENCE: If we have a current target that's still valid and in range, keep it
	# BUT check if there's a significantly better target (5%+ further on path)
	if current_target and is_instance_valid(current_target):
		if enemies_in_range.has(current_target):
			# Get current target's progress
			var current_progress = _get_enemy_progress(current_target)
			var should_switch = false

			# Check if any enemy is significantly further along the path (5%+ threshold)
			for enemy in enemies_in_range:
				var enemy_progress = _get_enemy_progress(enemy)
				# If new enemy is 5% or more further, we should switch to it
				if enemy_progress > current_progress + 0.05:
					should_switch = true
					print("  ⚡ Better target found! Current: %.1f%%, New: %.1f%%" % [current_progress * 100, enemy_progress * 100])
					break

			if not should_switch:
				# No significantly better target - stick with current for smooth aiming
				return current_target
			# Otherwise fall through and find the furthest enemy

	# Need a new target - find the enemy furthest along the path
	var furthest = enemies_in_range[0]
	var furthest_progress = _get_enemy_progress(furthest)
	var furthest_distance = global_position.distance_to(furthest.global_position)

	for enemy in enemies_in_range:
		var progress = _get_enemy_progress(enemy)
		var distance = global_position.distance_to(enemy.global_position)

		# Primary sort: furthest along path
		if progress > furthest_progress:
			furthest = enemy
			furthest_progress = progress
			furthest_distance = distance
		# Secondary sort: if tied on progress, pick closer enemy (tiebreaker)
		elif progress == furthest_progress and distance < furthest_distance:
			furthest = enemy
			furthest_distance = distance

	return furthest

func _get_enemy_progress(enemy) -> float:
	"""Get how far along the path an enemy is (0.0 = start, 1.0 = end)"""
	if not enemy or not is_instance_valid(enemy):
		return 0.0

	# Enemy is a child of PathFollow2D
	var path_follower = enemy.get_parent()
	if path_follower and path_follower is PathFollow2D:
		return path_follower.progress_ratio

	# Fallback: if no path follower found, use distance as approximation
	# (should not happen in normal gameplay)
	return 0.0

# ============================================
# SHOOTING FUNCTIONS
# ============================================

func _on_shoot_timer_timeout():
	# Try to shoot every X seconds
	# Use Kingdom Rush-style targeting: furthest along path + target persistence
	var old_target = current_target
	current_target = get_furthest_enemy()

	# Debug: Show when tower switches targets
	if current_target != old_target and current_target != null:
		if old_target == null:
			print("Tower acquired target: ", current_target.get_enemy_name() if current_target.has_method("get_enemy_name") else "Enemy")
		else:
			print("Tower switched target to: ", current_target.get_enemy_name() if current_target.has_method("get_enemy_name") else "Enemy")

	if current_target != null:
		shoot_at(current_target)

func shoot_at(target):
	if projectile_scene == null:
		print("ERROR: No projectile scene assigned!")
		return

	# Validate target is alive
	if not is_instance_valid(target):
		print("⚠ Target is dead/invalid, aborting shot")
		current_target = null
		return

	# Double-check: Only shoot if target is actually in range
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > range_radius:
		print("⚠ Target out of range (", distance_to_target, " > ", range_radius, "), skipping shot")
		# Remove from enemies_in_range since it's unreachable
		enemies_in_range.erase(target)
		current_target = null
		return

	# Create projectile
	var arrow = projectile_scene.instantiate()
	get_tree().root.add_child(arrow)  # Add to scene root (not as child of tower)

	# Position arrow at tower's position
	arrow.global_position = global_position

	# Tell arrow where to go
	arrow.setup(target, damage)

# ============================================
# VISUAL FUNCTIONS
# ============================================

func draw_range_circle():
	"""Draw a filled circle to show range (Kingdom Rush style)"""
	var points = []
	var num_points = 64  # More points = smoother circle

	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU  # TAU = 2*PI (full circle)
		var x = cos(angle) * range_radius
		var y = sin(angle) * range_radius
		points.append(Vector2(x, y))

	# Set polygon points for filled circle
	range_indicator.polygon = PackedVector2Array(points)

	# Set Kingdom Rush blue color with transparency
	range_indicator.color = Color(0.3, 0.5, 1.0, 0.3)  # Blue, 30% opacity

func select_tower():
	"""Show range indicator when tower is selected"""
	is_selected = true
	range_indicator.visible = true
	print("Tower selected - range indicator shown")

func deselect_tower():
	"""Hide range indicator when tower is deselected"""
	is_selected = false
	range_indicator.visible = false
	print("Tower deselected - range indicator hidden")

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Unregister from ClickManager
	ClickManager.unregister_clickable(self)
	print("✓ Tower unregistered from ClickManager")
