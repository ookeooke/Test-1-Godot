extends CharacterBody2D

# ============================================
# RANGER HERO - Now using ClickManager!
# ============================================

signal hero_died(respawn_time)
signal hero_selected(hero)

# STATES
enum State { IDLE, RANGED_COMBAT, MELEE_COMBAT, RETURNING, WALKING }
var current_state = State.IDLE

# STATS
var max_health = 200.0
var current_health = 200.0
var hero_level = 1

# COMBAT STATS
var ranged_damage = 25.0
var melee_damage = 12.0
var ranged_range = 300.0
var melee_range = 100.0
var ranged_attack_speed = 0.67
var melee_attack_speed = 0.5

# MOVEMENT
var movement_speed = 150.0
var max_distance_from_home = 50.0
var home_position = Vector2.ZERO
var target_position = Vector2.ZERO

# ENEMY MANAGEMENT
var max_melee_enemies = 1  # Kingdom Rush style: Block only 1 enemy at a time
var enemies_in_melee_range = []
var enemies_in_ranged_range = []
var current_ranged_target = null
var current_melee_targets = []

# TIMERS
var ranged_timer: Timer
var melee_timer: Timer

# SELECTION
var is_selected = false

# REFERENCES
@onready var ranged_detection = $RangedDetection
@onready var melee_detection = $MeleeDetection
@onready var range_indicator = $RangeIndicator
@onready var health_bar = $HealthBar
@onready var sprite = $Sprite2D

# PROJECTILE
@export var arrow_scene: PackedScene

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Set collision layers
	collision_layer = 2
	collision_mask = 0
	
	# Setup detection areas
	ranged_detection.collision_layer = 0
	ranged_detection.collision_mask = 1
	melee_detection.collision_layer = 0
	melee_detection.collision_mask = 1
	
	# CHANGED: Register with ClickManager instead of using Area2D
	ClickManager.register_clickable(self, ClickManager.ClickPriority.HERO, 40.0)
	print("✓ Hero registered with ClickManager")
	
	# Connect signals
	ranged_detection.body_entered.connect(_on_ranged_enemy_entered)
	ranged_detection.body_exited.connect(_on_ranged_enemy_exited)
	melee_detection.body_entered.connect(_on_melee_enemy_entered)
	melee_detection.body_exited.connect(_on_melee_enemy_exited)
	
	# Create timers
	ranged_timer = Timer.new()
	ranged_timer.wait_time = ranged_attack_speed
	ranged_timer.timeout.connect(_on_ranged_timer_timeout)
	add_child(ranged_timer)
	
	melee_timer = Timer.new()
	melee_timer.wait_time = melee_attack_speed
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)
	
	# Setup visuals
	draw_range_circle()
	range_indicator.visible = false
	update_health_bar()
	
	print("✓ Ranger Hero ready at: ", global_position)

# ============================================
# CLICK CALLBACKS - Called by ClickManager
# ============================================

func on_clicked(is_double_click: bool) -> void:
	"""Called when this hero is clicked"""
	print("🎯 Hero clicked! Double: ", is_double_click)
	
	if is_double_click:
		# Double-click: Center camera on hero (future feature)
		print("  ⚡ Double-clicked hero!")
		# TODO: Center camera
	else:
		# Single click: Select hero
		hero_selected.emit(self)

func on_right_clicked() -> void:
	"""Called when hero is right-clicked"""
	print("Right-clicked hero - could open hero menu here")
	# TODO: Show hero info panel

func on_hover_start() -> void:
	"""Called when mouse enters hero area"""
	if not is_selected:
		sprite.modulate = Color(1.2, 1.2, 1.5)  # Blue tint
		# Could show tooltip here

func on_hover_end() -> void:
	"""Called when mouse leaves hero area"""
	if not is_selected:
		sprite.modulate = Color(1, 1, 1)

# ============================================
# MAIN LOOP
# ============================================

func _physics_process(delta):
	match current_state:
		State.IDLE:
			handle_idle_state()
		State.RANGED_COMBAT:
			handle_ranged_combat_state()
		State.MELEE_COMBAT:
			handle_melee_combat_state()
		State.RETURNING:
			handle_returning_state(delta)
		State.WALKING:
			handle_walking_state(delta)

	clean_enemy_lists()

	# Keep health bar horizontal (enemy-style health bar handles its own rotation)
	# No need to counter-rotate - the health_bar.gd script handles positioning

# ============================================
# STATE HANDLERS
# ============================================

func handle_idle_state():
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
	elif not enemies_in_ranged_range.is_empty():
		enter_ranged_combat()
	
	if global_position.distance_to(home_position) > 5:
		enter_returning_state()

func handle_ranged_combat_state():
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
		return
	
	if enemies_in_ranged_range.is_empty():
		enter_returning_state()
		return
	
	current_ranged_target = get_closest_ranged_enemy()
	if current_ranged_target and is_instance_valid(current_ranged_target):
		look_at(current_ranged_target.global_position)

func handle_melee_combat_state():
	current_melee_targets = get_melee_targets()

	if current_melee_targets.is_empty():
		# Unblock ALL enemies when no targets
		for enemy in enemies_in_melee_range:
			if is_instance_valid(enemy) and enemy.has_method("unblock"):
				if enemy.is_blocked and enemy.blocking_hero == self:
					enemy.unblock()

		if not enemies_in_ranged_range.is_empty():
			enter_ranged_combat()
		else:
			enter_returning_state()
		return

	# Unblock enemies NOT in the target list (when hero switches targets)
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
	var direction = (home_position - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()
	
	if global_position.distance_to(home_position) < 5:
		velocity = Vector2.ZERO
		current_state = State.IDLE
	
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
	elif not enemies_in_ranged_range.is_empty():
		enter_ranged_combat()

func handle_walking_state(delta):
	var direction = (target_position - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()
	
	if global_position.distance_to(target_position) < 5:
		velocity = Vector2.ZERO
		home_position = global_position
		current_state = State.IDLE

# ============================================
# STATE TRANSITIONS
# ============================================

func enter_ranged_combat():
	current_state = State.RANGED_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.start()

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.stop()
	melee_timer.start()

func enter_returning_state():
	current_state = State.RETURNING
	ranged_timer.stop()
	melee_timer.stop()

func enter_walking_state(destination: Vector2):
	current_state = State.WALKING
	target_position = destination
	ranged_timer.stop()
	melee_timer.stop()

# ============================================
# ENEMY DETECTION
# ============================================

func _on_ranged_enemy_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_ranged_range.append(body)

func _on_ranged_enemy_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_ranged_range.erase(body)

func _on_melee_enemy_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_melee_range.append(body)

func _on_melee_enemy_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_melee_range.erase(body)

func clean_enemy_lists():
	enemies_in_ranged_range = enemies_in_ranged_range.filter(func(e): return is_instance_valid(e))
	enemies_in_melee_range = enemies_in_melee_range.filter(func(e): return is_instance_valid(e))

func get_closest_ranged_enemy():
	if enemies_in_ranged_range.is_empty():
		return null
	
	var closest = enemies_in_ranged_range[0]
	var closest_dist = global_position.distance_to(closest.global_position)
	
	for enemy in enemies_in_ranged_range:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	
	return closest

func get_melee_targets() -> Array:
	if enemies_in_melee_range.is_empty():
		return []
	
	var sorted_enemies = enemies_in_melee_range.duplicate()
	sorted_enemies.sort_custom(func(a, b): 
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	
	var targets = []
	for i in range(min(max_melee_enemies, sorted_enemies.size())):
		targets.append(sorted_enemies[i])
	
	return targets

# ============================================
# COMBAT - SHOOTING
# ============================================

func _on_ranged_timer_timeout():
	if current_state == State.RANGED_COMBAT:
		shoot_arrow()

func shoot_arrow():
	if arrow_scene == null:
		return
	
	current_ranged_target = get_closest_ranged_enemy()
	if current_ranged_target == null or not is_instance_valid(current_ranged_target):
		return
	
	if enemies_in_melee_range.has(current_ranged_target):
		return
	
	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	arrow.global_position = global_position
	arrow.setup(current_ranged_target, ranged_damage)

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
	var respawn_time = 10.0 + (hero_level - 1) * 5.0
	hero_died.emit(respawn_time)
	queue_free()

func update_health_bar():
	if health_bar:
		# Use enemy-style health bar's update_health method
		if health_bar.has_method("update_health"):
			health_bar.update_health(current_health, max_health)
		else:
			# Fallback for ProgressBar (old style)
			health_bar.value = (current_health / max_health) * 100

# ============================================
# SELECTION & VISUALS
# ============================================

func select():
	is_selected = true
	range_indicator.visible = true
	sprite.modulate = Color(1.3, 1.3, 1.5)

func deselect():
	is_selected = false
	range_indicator.visible = false
	sprite.modulate = Color(1, 1, 1)

func draw_range_circle():
	"""Draw a filled circle to show range (Kingdom Rush style)"""
	var points = []
	var num_points = 64  # More points = smoother circle

	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU  # TAU = 2*PI (full circle)
		var x = cos(angle) * ranged_range
		var y = sin(angle) * ranged_range
		points.append(Vector2(x, y))

	# Set polygon points for filled circle
	range_indicator.polygon = PackedVector2Array(points)

	# Set Kingdom Rush blue color with transparency
	range_indicator.color = Color(0.3, 0.5, 1.0, 0.3)  # Blue, 30% opacity

# ============================================
# HELPER FUNCTIONS
# ============================================

func set_home_position(pos: Vector2):
	home_position = pos
	global_position = pos

func move_to_position(pos: Vector2):
	enter_walking_state(pos)

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# IMPORTANT: Unregister from ClickManager when destroyed
	ClickManager.unregister_clickable(self)
	print("✓ Hero unregistered from ClickManager")
