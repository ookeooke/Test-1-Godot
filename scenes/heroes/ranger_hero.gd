extends CharacterBody2D

# ============================================
# RANGER HERO - Ranged/Melee hybrid hero
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
var max_melee_enemies = 3
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
@onready var click_area = $ClickArea

# PROJECTILE
@export var arrow_scene: PackedScene

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Set collision layers
	collision_layer = 2  # Heroes on layer 2
	collision_mask = 0
	
	# Setup detection areas
	ranged_detection.collision_layer = 0
	ranged_detection.collision_mask = 1
	melee_detection.collision_layer = 0
	melee_detection.collision_mask = 1
	
	# Setup click detection - FIXED: Use unique layer
	if click_area:
		click_area.input_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)
		click_area.collision_layer = 16  # Layer 5 (bit 5) - unique for heroes
		click_area.collision_mask = 0
		
		# Add mouse hover detection for better feedback
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)
		
		print("✓ Hero click area configured on layer 16 (bit 5)")
	else:
		print("⚠️ WARNING: No ClickArea found on hero!")
	
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
# INPUT HANDLING - FIXED
# ============================================

func _on_click_area_input_event(viewport, event, shape_idx):
	"""Handle clicks on the hero - PRIORITY INPUT"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("🎯 HERO CLICKED DIRECTLY! Position: ", global_position)
			hero_selected.emit(self)
			# CRITICAL: Mark the event as handled immediately
			get_viewport().set_input_as_handled()

func _on_mouse_entered():
	"""Visual feedback when hovering over hero"""
	if not is_selected:
		sprite.modulate = Color(1.2, 1.2, 1.5)  # Slight blue tint
		print("Mouse over hero")

func _on_mouse_exited():
	"""Remove hover feedback"""
	if not is_selected:
		sprite.modulate = Color(1, 1, 1)

# Alternative: Direct input handling (backup method)
func _input(event):
	"""Fallback input handling if Area2D doesn't work"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is within hero's bounds
			var click_pos = get_global_mouse_position()
			var distance = global_position.distance_to(click_pos)
			
			# Use slightly larger radius than collision shape
			if distance < 40:  # Adjust based on your hero size
				print("🎯 HERO CLICKED (fallback method)! Position: ", global_position)
				hero_selected.emit(self)
				get_viewport().set_input_as_handled()

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
		if not enemies_in_ranged_range.is_empty():
			enter_ranged_combat()
		else:
			enter_returning_state()
		return
	
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
		print("Hero returned to home position")
	
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
		print("Hero arrived at new position")

# ============================================
# STATE TRANSITIONS
# ============================================

func enter_ranged_combat():
	current_state = State.RANGED_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.start()
	print("Hero entering RANGED COMBAT")

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.stop()
	melee_timer.start()
	print("Hero entering MELEE COMBAT")

func enter_returning_state():
	current_state = State.RETURNING
	ranged_timer.stop()
	melee_timer.stop()
	print("Hero RETURNING to home")

func enter_walking_state(destination: Vector2):
	current_state = State.WALKING
	target_position = destination
	ranged_timer.stop()
	melee_timer.stop()
	print("Hero WALKING to ", destination)

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
	print("Hero took ", amount, " damage! HP: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("HERO DIED!")
	var respawn_time = 10.0 + (hero_level - 1) * 5.0
	hero_died.emit(respawn_time)
	queue_free()

func update_health_bar():
	if health_bar:
		health_bar.value = (current_health / max_health) * 100

# ============================================
# SELECTION & VISUALS
# ============================================

func select():
	is_selected = true
	range_indicator.visible = true
	sprite.modulate = Color(1.3, 1.3, 1.5)  # Brighter blue when selected
	print("✓ Hero selected")

func deselect():
	is_selected = false
	range_indicator.visible = false
	sprite.modulate = Color(1, 1, 1)
	print("✓ Hero deselected")

func draw_range_circle():
	var points = []
	var num_points = 64
	
	for i in range(num_points + 1):
		var angle = (i / float(num_points)) * TAU
		var x = cos(angle) * ranged_range
		var y = sin(angle) * ranged_range
		points.append(Vector2(x, y))
	
	range_indicator.points = PackedVector2Array(points)

# ============================================
# HELPER FUNCTIONS
# ============================================

func set_home_position(pos: Vector2):
	home_position = pos
	global_position = pos
	print("Hero home position set to: ", home_position)

func move_to_position(pos: Vector2):
	enter_walking_state(pos)
