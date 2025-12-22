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
enum State {IDLE, INTERCEPT, MELEE_COMBAT, RETURNING, WALKING}
var current_state = State.IDLE

# STATS
var max_health = 100.0
var current_health = 100.0

# COMBAT STATS
var melee_damage = 10.0
var melee_range = 100.0
var melee_attack_speed = 1.0
var combat_distance = 10.0 # Close combat range
var intercept_speed_multiplier = 1.5 # Reduced from 3.0 (Too fast!)

# MOVEMENT
var movement_speed = 100.0 # Slightly slower base walk
var home_position = Vector2.ZERO # Tower spawn location
var flag_position = Vector2.ZERO # Rally point to march to
var home_offset = Vector2.ZERO # Unique offset for formation

# ENEMY MANAGEMENT
var max_melee_enemies = 1
var enemies_in_melee_range = []
var target_enemy: Node2D = null
var current_slot_index: int = -1

# TIMERS
var melee_timer: Timer
var respawn_delay = 5.0 # Set by tower

# REGENERATION SYSTEM (Kingdom Rush style)
var time_since_last_damage: float = 0.0
var is_regenerating: bool = false
var regen_delay: float = 1.0 # 1 second delay for soldiers
var regen_rate: float = 5.0 # 5 HP per second

# REFERENCES
@onready var melee_detection = $MeleeDetection
@onready var health_bar = $HealthBar
@onready var sprite = $AnimatedSprite2D

# PARENT TOWER
var parent_tower = null

# ANIMATION STATE
var current_anim = ""

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

	# Connect signals
	melee_detection.body_entered.connect(_on_melee_enemy_entered)
	melee_detection.body_exited.connect(_on_melee_enemy_exited)
	
	# Ensure upright (no rotation)
	rotation = 0

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

	# Handle Facing (Default Sprite faces LEFT)
	# flip_h = FALSE -> Left
	# flip_h = TRUE -> Right
	if abs(velocity.x) > 1.0:
		sprite.flip_h = velocity.x > 0

	match current_state:
		State.IDLE:
			handle_idle_state()
			_play_animation("idle")
		State.INTERCEPT:
			handle_intercept_state(delta)
			_play_animation("walk")
		State.MELEE_COMBAT:
			handle_melee_combat_state()
			# Attack animation handled in attack timing, or idle if waiting
		State.RETURNING:
			handle_returning_state(delta)
			_play_animation("walk")
		State.WALKING:
			handle_walking_state(delta)
			_play_animation("walk")

	clean_enemy_lists()

# ============================================
# STATE HANDLERS
# ============================================

func handle_idle_state():
	# 1. Look for a target to engage
	var target = find_best_target()
	if target:
		# Try to reserve a slot
		if try_engage_enemy(target):
			return

	# 2. If no target, go to rally point
	var target_pos = flag_position if flag_position != Vector2.ZERO else home_position
	if global_position.distance_to(target_pos) > 5:
		enter_walking_state(target_pos)
	else:
		# We are idle at rally point. 
		# OPTIONAL: Face heavy traffic direction?
		pass

func handle_intercept_state(_delta):
	# We have a target and a slot. Charge there!
	if not is_instance_valid(target_enemy):
		_disengage_from_combat()
		return

	var slot_pos = target_enemy.get_slot_position(current_slot_index) if target_enemy.has_method("get_slot_position") else target_enemy.global_position
	
	# Move towards slot
	var direction = (slot_pos - global_position).normalized()
	velocity = direction * (movement_speed * intercept_speed_multiplier)
	move_and_slide()
	
	# Face enemy (Sprite Flip only, no rotation)
	# Default Left: flip if target is to the RIGHT
	var x_diff = target_enemy.global_position.x - global_position.x
	if x_diff != 0:
		sprite.flip_h = x_diff > 0
	
	# Check arrival
	if global_position.distance_to(slot_pos) < 10.0:
		enter_melee_combat()

func handle_melee_combat_state():
	if not is_instance_valid(target_enemy):
		_disengage_from_combat()
		return
		
	# PEEL OFF CHECK (Kingdom Rush Style)
	# If a new UNBLOCKED enemy appears, leave this fight to engage them!
	var potential_target = find_best_target()
	if potential_target and potential_target != target_enemy:
		# Only switch if the new target is UNBLOCKED (Priority target)
		if "is_blocked" in potential_target and not potential_target.is_blocked:
			# CRITICAL FIX: Only switch if I am NOT the primary blocker for my current target.
			# If I am the primary blocker, leaving will unblock them, causing an infinite loop.
			var am_i_primary_blocker = (target_enemy.has_method("block") and target_enemy.blocking_hero == self)
			
			if not am_i_primary_blocker:
				# print("⚔️ [Soldier] PEEL REQUEST: Switching from %s to UNBLOCKED %s" % [target_enemy.name, potential_target.name])
				_disengage_from_combat()
				if try_engage_enemy(potential_target):
					return
				else:
					# print("⚔️ [Soldier] PEEL FAILED: Could not engage new target.")
					pass
			else:
				# I am holding the line. I cannot leave.
				pass

	# Ensure we stay at the slot (teleport snapping or micro-adjust)
	# Kingdom Rush units stick to the slot perfectly
	var slot_pos = target_enemy.get_slot_position(current_slot_index) if target_enemy.has_method("get_slot_position") else target_enemy.global_position
	
	if global_position.distance_to(slot_pos) > 5.0:
		# Micro-adjust to stay in formation (e.g. if enemy was nudged)
		var direction = (slot_pos - global_position).normalized()
		velocity = direction * movement_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		
	# Ensure enemy stays blocked
	if target_enemy.has_method("block") and (not target_enemy.is_blocked or target_enemy.blocking_hero != self):
		target_enemy.block(self)
		
	# Face enemy (Sprite Flip only)
	# Default Left: flip if target is to the RIGHT
	var x_diff = target_enemy.global_position.x - global_position.x
	if x_diff != 0:
		sprite.flip_h = x_diff > 0

func handle_returning_state(_delta):
	# Calculate MY formation position at rally flag (spread out, not stacked!)
	var target_pos = get_rally_formation_position()

	var direction = (target_pos - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()

	if global_position.distance_to(target_pos) < 5:
		velocity = Vector2.ZERO
		current_state = State.IDLE
		
	# Check for targets while returning
	var target = find_best_target()
	if target:
		try_engage_enemy(target)

func handle_walking_state(_delta):
	# Walking to rally point
	var target_pos = get_rally_formation_position()

	var direction = (target_pos - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()

	if global_position.distance_to(target_pos) < 5:
		velocity = Vector2.ZERO
		current_state = State.IDLE

	# Check for targets while walking
	var target = find_best_target()
	if target:
		try_engage_enemy(target)

# ============================================
# TACTICAL LOGIC
# ============================================

func find_best_target() -> Node2D:
	"""Find visual best target (Prioritize UNBLOCKED > Closest)"""
	if enemies_in_melee_range.is_empty():
		return null
		
	var best_target = null
	var best_score = - INF
	
	# Anchor to Flag Position (or Home if no flag)
	var anchor_pos = flag_position if flag_position != Vector2.ZERO else home_position
	
	for enemy in enemies_in_melee_range:
		if not is_instance_valid(enemy): continue
		if enemy.current_health <= 0: continue
		
		# COMBAT LEASH: Ignore enemies too far from the flag/post
		if anchor_pos.distance_to(enemy.global_position) > 180.0:
			continue
		
		var score = 0.0
		
		# PRIORITY 1: Unblocked Enemies (The "Peel Off" Rule)
		if "is_blocked" in enemy and not enemy.is_blocked:
			score += 1000.0
			
		# PRIORITY 2: Distance to FLAG (Not distance to Self!)
		# This prevents "Creep" where soldiers chase enemies further and further away.
		# They will always prioritize enemies closest to the protection point.
		var dist_to_flag = anchor_pos.distance_to(enemy.global_position)
		score -= dist_to_flag
		
		# TIE BREAKER: If scores are similar, pick the one closer to self (less travel time)
		var dist_to_self = global_position.distance_to(enemy.global_position)
		score -= (dist_to_self * 0.1) # Small weight for travel convenience
		
		if score > best_score:
			best_score = score
			best_target = enemy
			
	return best_target

func try_engage_enemy(enemy: Node2D) -> bool:
	"""Attempt to reserve a slot and charge"""
	if not is_instance_valid(enemy): return false
	if not enemy.has_method("request_engagement_slot"): return false
	
	var slot = enemy.request_engagement_slot(self)
	if slot != -1:
		# Success! We got a slot.
		target_enemy = enemy
		current_slot_index = slot
		enter_intercept_state()
		return true
		
	return false

# ============================================
# STATE TRANSITIONS
# ============================================

func enter_intercept_state():
	current_state = State.INTERCEPT
	melee_timer.stop()
	_set_combat_state_visual(true) # Red tint to show aggression
	# Play 'charge' sound?

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	velocity = Vector2.ZERO
	melee_timer.start()
	_set_combat_state_visual(true)

	if is_instance_valid(target_enemy):
		# BLOCK THE ENEMY
		if target_enemy.has_method("block"):
			target_enemy.block(self)
			
		# IMPACT FX (The "Weight")
		_spawn_impact_fx()

func enter_returning_state():
	current_state = State.RETURNING
	melee_timer.stop()
	_set_combat_state_visual(false)

func enter_walking_state(destination: Vector2):
	if current_state != State.WALKING:
		debug_log("State: WALKING")
	current_state = State.WALKING
	flag_position = destination
	melee_timer.stop()

# ============================================
# ENEMY DETECTION
# ============================================

func _on_melee_enemy_entered(body):
	if body.is_in_group("enemies"):
		enemies_in_melee_range.append(body)

func _on_melee_enemy_exited(body):
	if body.is_in_group("enemies"):
		enemies_in_melee_range.erase(body)

func clean_enemy_lists():
	enemies_in_melee_range = enemies_in_melee_range.filter(func(e): return is_instance_valid(e))

# ============================================
# COMBAT - MELEE
# ============================================

func _on_melee_timer_timeout():
	if current_state == State.MELEE_COMBAT:
		melee_attack()

func melee_attack():
	if not is_instance_valid(target_enemy):
		_disengage_from_combat()
		return

	# LEASH CHECK: If we are dragged too far from post, RETREAT!
	var anchor_pos = flag_position if flag_position != Vector2.ZERO else home_position
	if global_position.distance_to(anchor_pos) > 200.0:
		# print("⚔️ [Soldier] LEASH BROKEN! Too far from post. Retreating!")
		_disengage_from_combat()
		return

	# ATTACK FLASH
	_play_attack_flash()

	# Record damage
	if BalanceTracker and parent_tower:
		BalanceTracker.record_damage(parent_tower, target_enemy, melee_damage, "tower")
	
	target_enemy.take_damage(melee_damage, self, "soldier_melee")
	
	target_enemy.take_damage(melee_damage, self, "soldier_melee")
	
	# Play attack animation (handles speed scaling)
	_play_animation("attack")
	
	if target_enemy.current_health <= 0:
		_disengage_from_combat()

func _play_attack_flash():
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate

func _spawn_impact_fx():
	# Screen shake or dust effect when blocking logic kicks in
	pass # TODO: Add dust

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	current_health -= amount
	time_since_last_damage = 0.0
	if is_regenerating:
		is_regenerating = false
		show_regen_visual(false)
	update_health_bar()
	if current_health <= 0:
		die()

func die():
	_disengage_from_combat()
	soldier_died.emit(respawn_delay)
	queue_free()

func update_health_bar():
	if health_bar:
		if health_bar.has_method("update_health"):
			health_bar.update_health(current_health, max_health)
		else:
			health_bar.value = (current_health / max_health) * 100

# ============================================
# REGENERATION SYSTEM
# ============================================

func update_regeneration(delta):
	time_since_last_damage += delta
	if current_health < max_health:
		if time_since_last_damage >= regen_delay:
			if not is_regenerating:
				is_regenerating = true
				show_regen_visual(true)
			current_health += regen_rate * delta
			if current_health > max_health:
				current_health = max_health
				is_regenerating = false
				show_regen_visual(false)
			update_health_bar()
	else:
		if is_regenerating:
			is_regenerating = false
			show_regen_visual(false)

func show_regen_visual(enabled: bool):
	if health_bar and health_bar.has_method("show_regeneration"):
		health_bar.show_regeneration(enabled)

# ============================================
# HELPER FUNCTIONS
# ============================================

func set_home_position(pos: Vector2, offset: Vector2 = Vector2.ZERO):
	home_position = pos
	home_offset = offset
	global_position = pos + offset

# ============================================
# DEBUGGING
# ============================================

func _process(_delta):
	queue_redraw()

func _draw():
	# if not visible: return # Always draw debug if enabled
	# Draw line to current target
	if is_instance_valid(target_enemy):
		var color = Color.RED if current_state == State.INTERCEPT else Color.ORANGE
		# draw_line(Vector2.ZERO, to_local(target_enemy.global_position), color, 2.0)
		
		# Draw circle at assigned slot
		if current_slot_index != -1 and target_enemy.has_method("get_slot_position"):
			var slot_pos = target_enemy.get_slot_position(current_slot_index)
			draw_line(Vector2.ZERO, to_local(slot_pos), Color.CYAN, 1.0)
			draw_circle(to_local(slot_pos), 3.0, Color.CYAN)
			
	# Draw state label
	# var font = ThemeDB.fallback_font
	# draw_string(font, Vector2(0, -20), State.keys()[current_state], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func debug_log(msg: String):
	print("[Soldier %s] %s" % [get_instance_id(), msg])

func set_flag_position(pos: Vector2):
	# print("⚔️ [SoldierUnit] Received new flag position: ", pos)
	flag_position = pos
	if current_state == State.MELEE_COMBAT or current_state == State.INTERCEPT:
		_disengage_from_combat()
	enter_walking_state(pos)

func _disengage_from_combat():
	if is_instance_valid(target_enemy):
		if target_enemy.has_method("release_engagement_slot"):
			target_enemy.release_engagement_slot(self)
		if target_enemy.has_method("unblock") and target_enemy.blocking_hero == self:
			target_enemy.unblock()
	
	target_enemy = null
	current_slot_index = -1
	melee_timer.stop()
	
	# If we are alive, return to rally point
	if current_health > 0:
		enter_returning_state()

func _set_combat_state_visual(in_combat: bool):
	if sprite:
		if in_combat:
			sprite.modulate = Color(1.2, 0.8, 0.8)
		else:
			sprite.modulate = Color(1, 1, 1)

# ============================================
# FORMATION POSITIONING SYSTEM
# ============================================

func get_tower_soldiers() -> Array:
	if not parent_tower: return [self]
	var soldiers = []
	for soldier in parent_tower.active_soldiers:
		if is_instance_valid(soldier):
			soldiers.append(soldier)
	return soldiers

func get_rally_formation_position() -> Vector2:
	var rally_pos = flag_position if flag_position != Vector2.ZERO else home_position
	var tower_soldiers = get_tower_soldiers()
	var num_soldiers = tower_soldiers.size()
	var my_index = tower_soldiers.find(self)
	
	if my_index < 0: return rally_pos
	if num_soldiers == 1: return rally_pos

	var formation_radius = 40.0
	var angle_step = TAU / num_soldiers
	var my_angle = my_index * angle_step
	var offset = Vector2(cos(my_angle), sin(my_angle)) * formation_radius
	return rally_pos + offset
