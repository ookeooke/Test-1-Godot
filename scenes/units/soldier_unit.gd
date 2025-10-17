extends CharacterBody2D

# ============================================
# SOLDIER UNIT - Melee combat unit for Garrison Tower
# ============================================
# Stripped-down version of ranger_hero.gd focused on melee combat only
# - No ranged attacks
# - Not clickable (controlled by tower)
# - Marches to rally flag and fights enemies

signal soldier_died(respawn_time)

# STATES
enum State { IDLE, MELEE_COMBAT, RETURNING, WALKING }
var current_state = State.IDLE

# STATS
var max_health = 100.0
var current_health = 100.0

# COMBAT STATS
var melee_damage = 10.0
var melee_range = 100.0
var melee_attack_speed = 1.0

# MOVEMENT
var movement_speed = 120.0
var home_position = Vector2.ZERO  # Tower spawn location
var flag_position = Vector2.ZERO  # Rally point to march to
var home_offset = Vector2.ZERO    # Unique offset for formation

# ENEMY MANAGEMENT
var max_melee_enemies = 1  # Block only 1 enemy at a time (Kingdom Rush style)
var enemies_in_melee_range = []
var current_melee_targets = []

# TIMERS
var melee_timer: Timer
var respawn_delay = 5.0  # Set by tower

# REFERENCES
@onready var melee_detection = $MeleeDetection
@onready var health_bar = $HealthBar
@onready var sprite = $Sprite2D

# PARENT TOWER
var parent_tower = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Set collision layers
	collision_layer = 2
	collision_mask = 0

	# Setup detection area
	melee_detection.collision_layer = 0
	melee_detection.collision_mask = 1

	# NOTE: Soldiers are NOT registered with ClickManager (not clickable)
	# Only the parent tower is clickable

	# Connect signals
	melee_detection.body_entered.connect(_on_melee_enemy_entered)
	melee_detection.body_exited.connect(_on_melee_enemy_exited)

	# Create melee timer
	melee_timer = Timer.new()
	melee_timer.wait_time = melee_attack_speed
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)

	# Setup visuals
	update_health_bar()

# ============================================
# MAIN LOOP
# ============================================

func _physics_process(delta):
	match current_state:
		State.IDLE:
			handle_idle_state()
		State.MELEE_COMBAT:
			handle_melee_combat_state()
		State.RETURNING:
			handle_returning_state(delta)
		State.WALKING:
			handle_walking_state(delta)

	clean_enemy_lists()

# ============================================
# STATE HANDLERS
# ============================================

func handle_idle_state():
	# Check for enemies in melee range
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
		return

	# If not at flag position, walk there
	var target_pos = flag_position if flag_position != Vector2.ZERO else home_position
	if global_position.distance_to(target_pos) > 5:
		enter_walking_state(target_pos)

func handle_melee_combat_state():
	current_melee_targets = get_melee_targets()

	if current_melee_targets.is_empty():
		# Unblock ALL enemies when no targets
		for enemy in enemies_in_melee_range:
			if is_instance_valid(enemy) and enemy.has_method("unblock"):
				if enemy.is_blocked and enemy.blocking_hero == self:
					enemy.unblock()

		# Return to flag position
		enter_returning_state()
		return

	# Unblock enemies NOT in the target list (when soldier switches targets)
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and not current_melee_targets.has(enemy):
			if enemy.has_method("unblock") and enemy.is_blocked and enemy.blocking_hero == self:
				enemy.unblock()

	# Block only the target enemy
	var closest = current_melee_targets[0]
	if is_instance_valid(closest):
		look_at(closest.global_position)

		for enemy in current_melee_targets:
			if enemy.has_method("set_blocked_by_hero"):
				if not enemy.is_blocked or enemy.blocking_hero != self:
					enemy.set_blocked_by_hero(self)

func handle_returning_state(delta):
	var target_pos = flag_position if flag_position != Vector2.ZERO else (home_position + home_offset)
	var direction = (target_pos - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()

	if global_position.distance_to(target_pos) < 5:
		velocity = Vector2.ZERO
		current_state = State.IDLE

	# Always prioritize combat
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()

func handle_walking_state(delta):
	var direction = (flag_position - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()

	if global_position.distance_to(flag_position) < 5:
		velocity = Vector2.ZERO
		current_state = State.IDLE

	# Engage enemies while marching
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()

# ============================================
# STATE TRANSITIONS
# ============================================

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	velocity = Vector2.ZERO
	melee_timer.start()

func enter_returning_state():
	current_state = State.RETURNING
	melee_timer.stop()

func enter_walking_state(destination: Vector2):
	current_state = State.WALKING
	flag_position = destination
	melee_timer.stop()

# ============================================
# ENEMY DETECTION
# ============================================

func _on_melee_enemy_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_melee_range.append(body)

func _on_melee_enemy_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_melee_range.erase(body)

func clean_enemy_lists():
	enemies_in_melee_range = enemies_in_melee_range.filter(func(e): return is_instance_valid(e))

func get_melee_targets() -> Array:
	if enemies_in_melee_range.is_empty():
		return []

	# Filter out already-blocked enemies (by other soldiers)
	var available_enemies = enemies_in_melee_range.filter(
		func(e): return not e.is_blocked or e.blocking_hero == self
	)

	if available_enemies.is_empty():
		return []

	# Sort by distance
	var sorted_enemies = available_enemies.duplicate()
	sorted_enemies.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)

	# Return closest enemies (up to max)
	var targets = []
	for i in range(min(max_melee_enemies, sorted_enemies.size())):
		targets.append(sorted_enemies[i])

	return targets

# ============================================
# COMBAT - MELEE
# ============================================

func _on_melee_timer_timeout():
	if current_state == State.MELEE_COMBAT:
		melee_attack()

func melee_attack():
	current_melee_targets = get_melee_targets()

	if current_melee_targets.is_empty():
		return

	for enemy in current_melee_targets:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(melee_damage)

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	current_health -= amount
	update_health_bar()

	if current_health <= 0:
		die()

func die():
	# CRITICAL: Unblock all enemies this soldier was fighting
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and enemy.has_method("unblock"):
			if enemy.is_blocked and enemy.blocking_hero == self:
				enemy.unblock()

	# Notify tower to respawn
	soldier_died.emit(respawn_delay)
	queue_free()

func update_health_bar():
	if health_bar:
		# Use enemy-style health bar's update_health method
		if health_bar.has_method("update_health"):
			health_bar.update_health(current_health, max_health)
		else:
			# Fallback for ProgressBar
			health_bar.value = (current_health / max_health) * 100

# ============================================
# HELPER FUNCTIONS
# ============================================

func set_home_position(pos: Vector2, offset: Vector2 = Vector2.ZERO):
	"""Set tower spawn location with unique formation offset"""
	home_position = pos
	home_offset = offset
	global_position = pos + offset

func set_flag_position(pos: Vector2):
	"""Update rally point - soldier will march here when idle"""
	flag_position = pos

	# If currently idle or returning, start walking to new position
	if current_state == State.IDLE or current_state == State.RETURNING:
		enter_walking_state(pos)
