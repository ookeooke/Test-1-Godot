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
var combat_distance = 50.0  # How close to get before attacking (visual improvement)

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

# REGENERATION SYSTEM (Kingdom Rush style)
var time_since_last_damage: float = 0.0
var is_regenerating: bool = false
var regen_delay: float = 1.0  # 1 second delay for soldiers
var regen_rate: float = 5.0   # 5 HP per second

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
	# Update regeneration FIRST (Kingdom Rush style)
	update_regeneration(delta)

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

		# COMBAT POSITIONING: Move to combat distance before attacking
		var distance_to_enemy = global_position.distance_to(closest.global_position)
		if distance_to_enemy > combat_distance:
			# Move closer
			var direction = (closest.global_position - global_position).normalized()
			velocity = direction * movement_speed
			move_and_slide()
		else:
			# In position - stop moving
			velocity = Vector2.ZERO

		for enemy in current_melee_targets:
			if enemy.has_method("set_blocked_by_hero"):
				if not enemy.is_blocked or enemy.blocking_hero != self:
					enemy.set_blocked_by_hero(self)

func handle_returning_state(delta):
	# Calculate MY formation position at rally flag (spread out, not stacked!)
	var target_pos = get_rally_formation_position()

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
	# Calculate MY formation position at rally flag (spread out, not stacked!)
	var target_pos = get_rally_formation_position()

	var direction = (target_pos - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()

	if global_position.distance_to(target_pos) < 5:
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
	_set_combat_state_visual(true)

	# NEW: Align to formation position around enemy (isometric-friendly)
	align_to_formation_position()

func enter_returning_state():
	current_state = State.RETURNING
	melee_timer.stop()
	_set_combat_state_visual(false)

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

	# SMART ASSIGNMENT SYSTEM (Kingdom Rush + dynamic gang-up)
	var tower_soldiers = get_tower_soldiers()
	var available_enemies = enemies_in_melee_range.duplicate()

	var num_soldiers = tower_soldiers.size()
	var num_enemies = available_enemies.size()

	if num_enemies >= num_soldiers:
		# MORE ENEMIES THAN SOLDIERS: 1v1 assignment
		# Each soldier gets unique enemy (no gang-up)
		return assign_unique_enemy(tower_soldiers, available_enemies)
	else:
		# MORE SOLDIERS THAN ENEMIES: Gang-up mode
		# All soldiers attack same enemies (distribute evenly)
		return assign_gang_up_targets(tower_soldiers, available_enemies)

func assign_unique_enemy(soldiers: Array, enemies: Array) -> Array:
	"""Each soldier gets a unique enemy (1v1 mode)"""
	# Find which enemy THIS soldier should fight
	var my_index = soldiers.find(self)
	if my_index < 0 or my_index >= enemies.size():
		return []

	# Sort enemies by distance to tower (prioritize closest threats)
	enemies.sort_custom(func(a, b):
		return home_position.distance_to(a.global_position) < home_position.distance_to(b.global_position)
	)

	# This soldier fights enemy at their index
	return [enemies[my_index]]

func assign_gang_up_targets(soldiers: Array, enemies: Array) -> Array:
	"""All soldiers gang up on closest enemy (or distribute if multiple enemies)"""
	# Find closest enemy to tower
	var closest_enemy = enemies[0]
	var closest_dist = home_position.distance_to(closest_enemy.global_position)

	for enemy in enemies:
		var dist = home_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_enemy = enemy
			closest_dist = dist

	return [closest_enemy]

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

	# ATTACK FLASH: Visual feedback when attacking
	_play_attack_flash()

	for enemy in current_melee_targets:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(melee_damage, self, "soldier_melee")

func _play_attack_flash():
	"""Visual feedback for attack - flash white"""
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.5)  # Flash bright white

		# Reset after 0.1 seconds
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	current_health -= amount

	# CRITICAL: Reset regeneration timer! (Kingdom Rush style)
	time_since_last_damage = 0.0

	# Stop regeneration visual
	if is_regenerating:
		is_regenerating = false
		show_regen_visual(false)

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
# REGENERATION SYSTEM (Kingdom Rush)
# ============================================

func update_regeneration(delta):
	"""Kingdom Rush style health regeneration - 5 HP/sec after 1s out of combat"""
	# Count time since last hit
	time_since_last_damage += delta

	# Can only regen if not at full health
	if current_health < max_health:
		# Check if enough time passed (1 second out of combat)
		if time_since_last_damage >= regen_delay:
			# Start regenerating
			if not is_regenerating:
				is_regenerating = true
				show_regen_visual(true)

			# Heal over time
			current_health += regen_rate * delta

			# Cap at max health
			if current_health > max_health:
				current_health = max_health
				is_regenerating = false
				show_regen_visual(false)

			update_health_bar()
	else:
		# Already at full health
		if is_regenerating:
			is_regenerating = false
			show_regen_visual(false)

func show_regen_visual(enabled: bool):
	"""Show/hide green pulse on health bar during regeneration"""
	if health_bar and health_bar.has_method("show_regeneration"):
		health_bar.show_regeneration(enabled)

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

func _set_combat_state_visual(in_combat: bool):
	"""Visual indicator when soldier is in melee combat"""
	if sprite:
		if in_combat:
			# Reddish tint = in combat
			sprite.modulate = Color(1.2, 0.8, 0.8)
		else:
			# Normal color
			sprite.modulate = Color(1, 1, 1)

# ============================================
# FORMATION POSITIONING SYSTEM (Isometric-friendly)
# ============================================

func align_to_formation_position():
	"""Position soldier in semi-circle formation around enemy (Kingdom Rush style)"""
	if current_melee_targets.is_empty():
		return

	var target_enemy = current_melee_targets[0]
	if not is_instance_valid(target_enemy):
		return

	# Get all soldiers fighting same enemy
	var tower_soldiers = get_tower_soldiers()
	var soldiers_on_this_enemy = []

	for soldier in tower_soldiers:
		if is_instance_valid(soldier) and soldier.current_melee_targets.size() > 0:
			if soldier.current_melee_targets[0] == target_enemy:
				soldiers_on_this_enemy.append(soldier)

	# Find MY position in the formation
	var my_index = soldiers_on_this_enemy.find(self)
	if my_index < 0:
		my_index = 0

	var num_soldiers = soldiers_on_this_enemy.size()

	# Calculate formation position
	var formation_pos = calculate_formation_position(
		target_enemy.global_position,
		my_index,
		num_soldiers
	)

	# Move to formation position
	global_position = formation_pos
	velocity = Vector2.ZERO

	# Face the enemy
	look_at(target_enemy.global_position)

func calculate_formation_position(enemy_pos: Vector2, soldier_index: int, total_soldiers: int) -> Vector2:
	"""Calculate position in semi-circle formation (soldiers spread out, not stacked)"""
	var formation_radius = 60.0  # Increased from 50 to 60 (more space in combat!)

	if total_soldiers == 1:
		# Solo soldier: face enemy from tower direction
		var direction = (home_position - enemy_pos).normalized()
		return enemy_pos + (direction * formation_radius)

	# Multiple soldiers: spread in semi-circle
	# Calculate angle for this soldier
	var arc_width = PI * 0.8  # 144° arc (not full circle, looks better in isometric)
	var start_angle = -arc_width / 2.0

	# Angle step between soldiers
	var angle_step = arc_width / max(1, total_soldiers - 1)
	var my_angle = start_angle + (soldier_index * angle_step)

	# Calculate direction facing toward tower (soldiers attack from tower side)
	var tower_direction = (home_position - enemy_pos).normalized()
	var tower_angle = atan2(tower_direction.y, tower_direction.x)

	# Combine formation angle with tower direction
	var final_angle = tower_angle + my_angle

	# Calculate position on the arc
	var offset = Vector2(cos(final_angle), sin(final_angle)) * formation_radius
	return enemy_pos + offset

func get_tower_soldiers() -> Array:
	"""Get all soldiers from same tower"""
	if not parent_tower:
		return [self]

	var soldiers = []
	for soldier in parent_tower.active_soldiers:
		if is_instance_valid(soldier):
			soldiers.append(soldier)

	return soldiers

func get_rally_formation_position() -> Vector2:
	"""Calculate MY unique position at rally flag (soldiers spread in circle, not stacked)"""
	# Get rally flag position (or home if no flag set)
	var rally_pos = flag_position if flag_position != Vector2.ZERO else home_position

	# Get all soldiers from tower
	var tower_soldiers = get_tower_soldiers()
	var num_soldiers = tower_soldiers.size()

	# Find my index
	var my_index = tower_soldiers.find(self)
	if my_index < 0:
		return rally_pos  # Fallback: just use rally position

	# Spread soldiers in circle formation (Kingdom Rush style)
	if num_soldiers == 1:
		# Solo soldier: stay at flag center
		return rally_pos

	# Multiple soldiers: spread in ring (INCREASED spacing to prevent shaking)
	var formation_radius = 40.0  # Increased from 30 to 40 (more space!)
	var angle_step = TAU / num_soldiers  # TAU = 2*PI (full circle)
	var my_angle = my_index * angle_step

	# Calculate offset from flag center
	var offset = Vector2(cos(my_angle), sin(my_angle)) * formation_radius

	return rally_pos + offset
