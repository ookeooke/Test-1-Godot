extends StaticBody2D

# ============================================
# ARCHER TOWER - Shoots arrows at enemies
# ============================================
#
# TARGETING SYSTEM:
# - FIRST mode: Targets enemy furthest along the path (closest to exit)
# - STRONG mode: Targets enemy with highest current health
# - Instant target switching (no persistence threshold)
# - Player can change mode via tower upgrade menu
# ============================================

# TARGETING MODES
enum TargetingMode {
	FIRST,   # Furthest on path (default)
	STRONG   # Highest current health
}

# TOWER STATS
var damage = 15
var attack_speed = 1.2  # Attacks per second
var range_radius = 300  # Detection range
var targeting_mode = TargetingMode.FIRST  # Default targeting mode

# REFERENCES
var detection_range: Area2D
var range_indicator: Polygon2D  # Changed from Line2D to Polygon2D for filled circle
var shoot_timer: Timer
var archer_weapon: Node2D  # The weapon that rotates toward enemies
var mode_label: Label  # Visual indicator for targeting mode
var debug_line: Line2D  # Visual targeting line (F4 debug)

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

	# Create mode label for visual feedback
	mode_label = Label.new()
	add_child(mode_label)
	mode_label.position = Vector2(-30, -80)  # Above tower
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_mode_label()

	# Create debug line for visual targeting (F4)
	debug_line = Line2D.new()
	add_child(debug_line)
	debug_line.width = 3.0
	debug_line.default_color = Color.RED
	debug_line.z_index = 100
	debug_line.visible = false

	# CHANGED: Register with ClickManager immediately (no await needed)
	# parent_spot is set by tower_spot.place_tower() before _ready() completes
	ClickManager.register_clickable(self, ClickManager.ClickPriority.TOWER, 50.0)

func _process(delta):
	# Rotate archer's weapon toward the current target
	if current_target and is_instance_valid(current_target):
		if archer_weapon:
			# Make weapon point at enemy
			archer_weapon.look_at(current_target.global_position)

		# Visual debug: Draw line to current target (F4)
		if DebugConfig.visual_debug_enabled and debug_line:
			debug_line.visible = true
			debug_line.points = [Vector2.ZERO, to_local(current_target.global_position)]
	else:
		if debug_line:
			debug_line.visible = false

# ============================================
# CLICK CALLBACKS - Called by ClickManager
# ============================================

func on_clicked(is_double_click: bool):
	"""Called when tower is clicked"""
	# Find the parent tower spot and emit its signal
	if parent_spot:
		parent_spot.tower_clicked.emit(parent_spot, self)
	else:
		# Fallback: try to find parent spot by going up the tree
		var spot = get_parent()
		if spot and spot.has_signal("tower_clicked"):
			spot.tower_clicked.emit(spot, self)
		else:
			print("ERROR: Could not find parent tower spot!")

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

func _on_enemy_exited_range(body):
	# An enemy left our range
	if body.is_in_group("enemy"):
		enemies_in_range.erase(body)


func _on_enemy_died(enemy):
	"""Called when an enemy dies - remove immediately and retarget"""
	# Remove from tracking list
	enemies_in_range.erase(enemy)

	# If this was our current target, immediately find new target
	if current_target == enemy:
		DebugConfig.log_targeting("Target died, retargeting...")
		current_target = get_target_by_mode()

		# If we found a new target and we're ready to shoot, shoot immediately
		# This prevents DPS downtime during intense waves
		if current_target != null and shoot_timer.time_left < 0.1:
			shoot_at(current_target)

func get_target_by_mode():
	"""Get target based on current targeting mode"""
	# Clean up dead/invalid enemies first
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))

	if enemies_in_range.is_empty():
		return null

	# Select target based on mode
	match targeting_mode:
		TargetingMode.FIRST:
			return get_first_enemy()
		TargetingMode.STRONG:
			return get_strongest_enemy()

	return null

func get_first_enemy():
	"""Target enemy furthest along the path (instant switching, no threshold)"""
	var furthest = enemies_in_range[0]
	var furthest_progress = _get_enemy_progress(furthest)

	for enemy in enemies_in_range:
		var progress = _get_enemy_progress(enemy)
		if progress > furthest_progress:
			furthest = enemy
			furthest_progress = progress

	return furthest

func get_strongest_enemy():
	"""Target enemy with highest current health"""
	var strongest = enemies_in_range[0]
	var highest_health = strongest.current_health if "current_health" in strongest else 0.0

	for enemy in enemies_in_range:
		var enemy_health = enemy.current_health if "current_health" in enemy else 0.0
		if enemy_health > highest_health:
			strongest = enemy
			highest_health = enemy_health

	return strongest

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

func set_targeting_mode(mode: TargetingMode):
	"""Change the targeting mode and update visual feedback"""
	targeting_mode = mode
	update_mode_label()
	var mode_name = "FIRST" if mode == TargetingMode.FIRST else "STRONG"
	DebugConfig.log_targeting("Mode changed to: %s" % mode_name)

func update_mode_label():
	"""Update the visual label showing current targeting mode"""
	if not mode_label:
		return

	match targeting_mode:
		TargetingMode.FIRST:
			mode_label.text = "[FIRST]"
			mode_label.modulate = Color.CYAN
		TargetingMode.STRONG:
			mode_label.text = "[STRONG]"
			mode_label.modulate = Color.RED

# ============================================
# SHOOTING FUNCTIONS
# ============================================

func _on_shoot_timer_timeout():
	# Try to shoot every X seconds
	# Get target based on current targeting mode
	var old_target = current_target
	current_target = get_target_by_mode()

	# Debug: Show when tower switches targets (F3)
	if current_target != old_target and current_target != null:
		var target_name = current_target.get_enemy_name() if current_target.has_method("get_enemy_name") else "Enemy"
		var mode_name = "FIRST" if targeting_mode == TargetingMode.FIRST else "STRONG"

		if old_target == null:
			DebugConfig.log_targeting("Tower → %s (%s mode)" % [target_name, mode_name])
		else:
			var old_name = old_target.get_enemy_name() if old_target.has_method("get_enemy_name") else "Enemy"
			DebugConfig.log_targeting("Tower switched → %s (from %s)" % [target_name, old_name])

		# Update enemy highlight (F4)
		if old_target and is_instance_valid(old_target) and old_target.has_method("set_debug_targeted"):
			old_target.set_debug_targeted(false)

		if current_target.has_method("set_debug_targeted"):
			current_target.set_debug_targeted(true)

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
	# Add small buffer (10px) to account for physics timing
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > range_radius + 10:
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

func deselect_tower():
	"""Hide range indicator when tower is deselected"""
	is_selected = false
	range_indicator.visible = false

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Unregister from ClickManager
	ClickManager.unregister_clickable(self)
