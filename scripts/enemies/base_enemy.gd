extends CharacterBody2D
class_name BaseEnemy

## Base Enemy Class
## All enemy types extend this class and set their own stats via @export variables in Inspector.
## Contains all shared logic: movement, blocking, combat, health, death.

# ============================================
# SIGNALS
# ============================================

signal enemy_died
signal blocked(hero)
signal unblocked

# ============================================
# STATS (Edit these in Inspector for each enemy type)
# ============================================

## Movement speed (pixels per second)
@export var speed: float = 100.0

## Maximum health points
@export var max_health: float = 50.0

## Damage dealt to heroes in melee combat
@export var melee_damage: float = 5.0

## Time between attacks (seconds)
@export var attack_cooldown: float = 1.0

## Gold awarded to player when enemy dies
@export var gold_reward: int = 5

## How many lives the player loses if enemy reaches the end
@export var life_damage: int = 1

## Can this enemy be blocked by heroes? (Flying enemies = false)
@export var can_be_blocked: bool = true

## Detection range to check if blocking hero is still close
@export var melee_detection_range: float = 100.0

## BLOCKING WEIGHT (New)
## How much "capacity" this enemy takes up when blocked.
## 1 = Standard, 2 = Heavy, 10 = Unblockable (Boss)
@export var weight: int = 1

@export_group("Visuals")

## Camera shake intensity when enemy dies
@export_enum("None", "Small", "Medium", "Large") var death_shake: String = "None"

## Target spot offset for projectiles (adjustable per enemy type)
## This is where arrows/projectiles will aim (relative to enemy origin)
@export var hit_point_offset: Vector2 = Vector2.ZERO

## Armor percentage (0.0-1.0) - reduces incoming damage
## Example: 0.3 = 30% damage reduction
@export_range(0.0, 1.0, 0.05) var armor: float = 0.0

# ============================================
# RUNTIME VARIABLES
# ============================================

var current_health: float
var is_blocked := false
var blocking_hero: Node2D = null # The PRIMARY blocker
var attack_timer := 0.0
var debug_highlight: Polygon2D # Visual target indicator (F4 debug)
var hit_point_marker: Marker2D # Dynamic target spot for projectiles
var hit_point_visual: Polygon2D # Visual indicator for hit point in editor

# Balance tracking
var spawn_time: float = 0.0
var last_damage_source = null
var last_damage_source_type = "unknown"
var _has_died: bool = false # Guard to prevent die() from being called multiple times

# WAYPOINT NAVIGATION SYSTEM (new)
var use_waypoint_navigation: bool = false # Set by wave_manager when spawning
var current_waypoint: PathWaypoint = null
var target_position: Vector2 = Vector2.ZERO
var waypoint_reached_distance: float = 30.0
var lateral_wander: Vector2 = Vector2.ZERO # Random drift within road
var wander_timer: float = 0.0

# ============================================
# REFERENCES
# ============================================

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D
@onready var health_bar = $HealthBar
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var hit_particles: CPUParticles2D = $HitParticles if has_node("HitParticles") else null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Initialize health
	current_health = max_health

	# Set collision
	collision_layer = 1
	collision_mask = 0

	# Initialize health bar
	_update_health_bar()

	# Create debug highlight circle (F4)
	debug_highlight = Polygon2D.new()
	add_child(debug_highlight)
	debug_highlight.z_index = -1

	# Create circle points
	var points = []
	for i in range(32):
		var angle = (i / 32.0) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * 30)
	debug_highlight.polygon = PackedVector2Array(points)
	debug_highlight.color = Color(1, 0, 0, 0.3) # Red, transparent
	debug_highlight.visible = false

	# Setup HitPoint marker system for projectile targeting
	_setup_hit_point_marker()

	# Track enemy spawn
	spawn_time = Time.get_ticks_msec() / 1000.0
	if BalanceTracker:
		var enemy_type = get_enemy_name().to_lower().replace(" ", "_")
		BalanceTracker.record_enemy_spawned(enemy_type)

	# Register with EnemyManager for centralized tracking
	if EnemyManager:
		EnemyManager.register_enemy(self)

	# GRAPHICS UPGRADE: Add dynamic shadow
	_add_dynamic_shadow()

	# GRAPHICS UPGRADE: Setup hit flash shader
	_setup_hit_flash_material()


func _add_dynamic_shadow():
	"""Add a blob shadow under the unit"""
	# 1. Check if a Shadow node already exists (added in Editor)
	if has_node("Shadow"):
		var shadow = get_node("Shadow")
		# Ensure it's at the bottom
		move_child(shadow, 0)
		# If it exists, we assume the user set the scale/position in Editor.
		# We can optionally force the export scale here if desired, 
		# but usually Editor visual wins.
		return

	# 2. Fallback: Create dynamic shadow if none exists
	var shadow_scene = load("res://scenes/effects/shadow.tscn")
	if shadow_scene:
		var shadow = shadow_scene.instantiate()
		shadow.name = "Shadow" # Name it so we can find it later
		# Use the manual export for precise control
		shadow.scale = Vector2(1.0, 1.0)
		shadow.position = Vector2(0, 5) # Slightly below feet
		add_child(shadow)
		move_child(shadow, 0) # Move to bottom of draw order

func _setup_hit_flash_material():
	"""Apply the hit flash shader to the sprite"""
	var sprite_node = _get_visual_sprite()
	if sprite_node:
		var shader = load("res://assets/shaders/hit_flash.gdshader")
		if shader:
			var mat = ShaderMaterial.new()
			mat.shader = shader
			sprite_node.material = mat

func _get_visual_sprite() -> Node2D:
	"""Helper to find the main visual sprite"""
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

# ============================================
# HIT POINT MARKER SYSTEM
# ============================================

func _setup_hit_point_marker():
	"""Create or update the HitPoint marker for projectile targeting"""
	# Check if HitPoint already exists in scene (from .tscn file)
	if has_node("HitPoint"):
		hit_point_marker = get_node("HitPoint")
	else:
		# Create new HitPoint marker dynamically
		hit_point_marker = Marker2D.new()
		hit_point_marker.name = "HitPoint"
		add_child(hit_point_marker)

	# Apply the exported offset to the marker
	hit_point_marker.position = hit_point_offset

	# Create visual indicator (crosshair) for editor - always visible in editor
	hit_point_visual = Polygon2D.new()
	hit_point_marker.add_child(hit_point_visual)
	hit_point_visual.z_index = 100

	# Draw crosshair shape (horizontal and vertical lines)
	var crosshair_size = 8.0
	var crosshair_points = PackedVector2Array([
		Vector2(-crosshair_size, 0), Vector2(crosshair_size, 0),
		Vector2(0, 0), # Center point to connect lines
		Vector2(0, -crosshair_size), Vector2(0, crosshair_size)
	])
	hit_point_visual.polygon = crosshair_points
	hit_point_visual.color = Color(1, 1, 0, 0.8) # Bright yellow, mostly opaque

	# Add small circle at center
	var circle_points = []
	for i in range(16):
		var angle = (i / 16.0) * TAU
		circle_points.append(Vector2(cos(angle), sin(angle)) * 3)

	# Create separate circle polygon
	var circle_visual = Polygon2D.new()
	hit_point_marker.add_child(circle_visual)
	circle_visual.polygon = PackedVector2Array(circle_points)
	circle_visual.color = Color(1, 0.5, 0, 0.6) # Orange, semi-transparent
	circle_visual.z_index = 101

# ============================================
# DEBUG VISUALS
# ============================================

func set_debug_targeted(is_targeted: bool):
	"""Show/hide debug highlight when tower targets this enemy (F4)"""
	if debug_highlight:
		debug_highlight.visible = is_targeted and DebugConfig.visual_debug_enabled

# ============================================
# MAIN LOOP
# ============================================

func _process(_delta):
	# Dynamic Depth Sorting
	z_index = int(global_position.y)

func _physics_process(delta):
	# Stun check
	if is_stunned:
		return

	# Handle blocking state first (same for both systems)
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		# I am the blocked enemy - check if hero is still close
		var distance = global_position.distance_to(blocking_hero.global_position)
		
		# COMBAT STICKINESS: Stay engaged even if hero shifts position slightly
		# Only disengage if dragged far from where we were blocked (50px radius)
		# This prevents teleporting and enables Kingdom Rush-style mobile combat
		var distance_moved_from_block_point = global_position.distance_to(path_position)

		if distance_moved_from_block_point > 50.0:
			# Dragged too far from block point - disengage
			unblock(blocking_hero)
			_continue_movement(delta)
			return

		# LEASH CHECK (Backup)
		# If we are dragged too far from our path (100px), give up.
		if path_position != Vector2.ZERO and global_position.distance_to(path_position) > 100.0:
			unblock(blocking_hero)
			_continue_movement(delta)
			return

		if distance > melee_detection_range:
			# Hero walked away - resume movement
			unblock(blocking_hero)
			_continue_movement(delta)
		else:
			# Hero still close - I'm blocked, so fight!
			# 1. Request Slot Position
			var target_pos = blocking_hero.global_position
			if blocking_hero.has_method("request_hero_engagement_slot"):
				var slot_idx = blocking_hero.request_hero_engagement_slot(self)
				if slot_idx != -1:
					target_pos = blocking_hero.get_hero_slot_position(slot_idx)
			
			# 2. Move to Slot
			var dist_to_slot = global_position.distance_to(target_pos)
			
			# DEBUG: Why am I moving?
			if DebugConfig.visual_debug_enabled and dist_to_slot > 5.0:
				print("[%s] Moving to Slot. Dist: %.1f | Target: %s" % [name, dist_to_slot, target_pos])
				queue_redraw() # Force draw update
			
			if dist_to_slot > 5.0:
				# Move towards slot
				var direction = (target_pos - global_position).normalized()
				global_position += direction * speed * delta
			
			# 3. Combat Logic
			# ATTACK CHECK: Only attack if we have reached the slot (stopped moving)
			# This prevents "sliding attacks" while walking around the hero.
			if dist_to_slot <= 10.0:
				handle_hero_combat(delta)
	else:
		# I am NOT blocked - move normally
		_continue_movement(delta)

func _continue_movement(delta):
	"""Handle movement based on current navigation system"""
	if use_waypoint_navigation:
		_waypoint_movement(delta)
	else:
		_path2d_movement(delta)

func _path2d_movement(delta):
	"""Original Path2D movement system"""
	if path_follower:
		path_follower.progress += speed * delta
		# CRITICAL: Manual position sync to fix collision detection
		# This ensures collision shape position matches visual position
		# Fixes Godot engine bug with PathFollow2D physics desync
		global_position = path_follower.global_position
		if path_follower.progress_ratio >= 1.0:
			reached_end()

func _waypoint_movement(delta):
	"""New waypoint navigation system with natural spread"""
	if not current_waypoint:
		print("ERROR: Enemy using waypoint navigation but no current waypoint!")
		return

	# Update wander timer for natural side-to-side movement
	wander_timer -= delta
	if wander_timer <= 0:
		wander_timer = randf_range(1.0, 3.0)
		# Create new random drift within road bounds
		lateral_wander = Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)

	# Calculate direction to target
	var to_target = target_position - global_position
	var distance_to_target = to_target.length()

	# Gradually blend in the lateral wander
	var direction = to_target.normalized()
	var wander_influence = clamp(distance_to_target / 100.0, 0.0, 1.0)
	direction = (direction + lateral_wander.normalized() * wander_influence * 0.3).normalized()

	# Move toward target with wander
	velocity = direction * speed
	move_and_slide()

	# Check if reached waypoint
	if distance_to_target < waypoint_reached_distance:
		# Move to next waypoint
		if current_waypoint.next_waypoints.is_empty():
			reached_end()
		else:
			# Pick next waypoint (random if multiple branches)
			current_waypoint = current_waypoint.get_next_waypoint()
			if current_waypoint:
				target_position = current_waypoint.get_random_position_in_road()
				print(get_enemy_name(), " moving to next waypoint: ", current_waypoint.name)
			else:
				reached_end()

# ============================================
# COMBAT
# ============================================

func handle_hero_combat(delta):
	"""Attack the blocking hero periodically"""
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		if blocking_hero.has_method("take_damage"):
			blocking_hero.take_damage(melee_damage)
			# Play attack animation
			_play_animation("attack")

# ============================================
# BLOCKING SYSTEM
# ============================================

var path_position = Vector2.ZERO # Where we were when we got blocked

func block(hero):
	"""Called by a hero when they engage this enemy"""
	if not is_blocked:
		is_blocked = true
		blocking_hero = hero
		path_position = global_position # Remember where we left the road
		emit_signal("blocked", hero)
		
		# Stop movement
		if path_follower:
			path_follower.loop = false # Stop looping if enabled
		
		# Visual feedback
		_set_combat_state_visual(true)

func unblock(hero = null):
	"""Called when a hero disengages or dies"""
	if hero and hero.has_method("release_hero_engagement_slot"):
		hero.release_hero_engagement_slot(self)
		
	if is_blocked:
		is_blocked = false
		blocking_hero = null
		emit_signal("unblocked")
		
		# Resume movement logic handled in _physics_process usually, 
		# but here we just reset state
		_set_combat_state_visual(false)

func set_blocked_by_hero(hero):
	"""Legacy alias"""
	block(hero)

func _draw():
	if DebugConfig.visual_debug_enabled and is_blocked and blocking_hero:
		# Draw line to my target slot position
		var target_pos = Vector2.ZERO
		if blocking_hero.has_method("request_hero_engagement_slot"):
			var slot_idx = blocking_hero.request_hero_engagement_slot(self)
			if slot_idx != -1:
				target_pos = blocking_hero.get_hero_slot_position(slot_idx)
				draw_line(Vector2.ZERO, target_pos - global_position, Color.MAGENTA, 2.0)
				draw_circle(target_pos - global_position, 3.0, Color.MAGENTA)

func _set_combat_state_visual(in_combat: bool):
	"""Visual indicator when enemy is in melee combat"""
	# Find Sprite2D or AnimatedSprite2D child
	var sprite_node = null
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			sprite_node = child
			break

	if sprite_node:
		if in_combat:
			# Reddish tint = in combat
			sprite_node.modulate = Color(1.2, 0.8, 0.8)
		else:
			# Normal color
			sprite_node.modulate = Color(1, 1, 1)

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float, damage_source = null, damage_source_type = "unknown"):
	"""Apply damage to this enemy (reduced by armor)"""
	print("[BaseEnemy] %s taking damage: %.1f (Armor: %.1f)" % [name, amount, armor])
	# Apply armor reduction
	var actual_damage = amount * (1.0 - armor)
	current_health -= actual_damage

	# Track last damage source for kill attribution
	if damage_source:
		last_damage_source = damage_source
		last_damage_source_type = damage_source_type

	# Update health bar
	_update_health_bar()

	# VISUAL FEEDBACK 1: Hit flash (white flash on hit)
	_play_hit_flash()

	# VISUAL FEEDBACK 2: Floating damage number (show actual damage after armor)
	_spawn_damage_number(actual_damage)

	# Play hit animation and particles
	_play_animation("hit")

	if hit_particles:
		hit_particles.restart()

	# IMPACT PARTICLES: Spawn hit particles for melee combat
	if damage_source_type in ["soldier_melee", "hero_melee"]:
		_spawn_impact_particles(damage_source)

	if current_health <= 0:
		die()

func _update_health_bar():
	"""Update the health bar visual"""
	if health_bar:
		health_bar.update_health(current_health, max_health)

func die():
	"""Handle enemy death"""
	# Guard: Prevent die() from being called multiple times
	if _has_died:
		return
	_has_died = true

	# Track enemy killed
	if BalanceTracker:
		var enemy_type = get_enemy_name().to_lower().replace(" ", "_")
		var time_alive = (Time.get_ticks_msec() / 1000.0) - spawn_time
		BalanceTracker.record_enemy_killed(enemy_type, time_alive, gold_reward)

		# Record kill attribution
		if last_damage_source and is_instance_valid(last_damage_source):
			BalanceTracker.record_kill(last_damage_source, enemy_type, gold_reward, last_damage_source_type)

	# Award gold
	GameStateManager.add_gold(gold_reward)

	# Spawn gold coin visual effect
	_spawn_gold_coin_effect()

	# Play death animation before destroying
	await _play_death_animation()

	# Camera shake based on enemy type (direct call - no wrapper)
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_shake"):
		match death_shake:
			"None":
				pass # No shake
			"Small":
				camera.add_shake(5.0)
			"Medium":
				camera.add_shake(15.0)
			"Large":
				camera.add_shake(30.0)

	# Unblock from hero if blocked
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		# Hero will detect we left their melee range
		pass

	# Emit death signal
	enemy_died.emit()
	queue_free()

# ============================================
# PATH MANAGEMENT
# ============================================

func reached_end():
	"""Called when enemy reaches the end of the path"""
	# Guard: Prevent reached_end() from being called multiple times (or after death)
	if _has_died:
		return
	_has_died = true

	print(get_enemy_name(), " reached the end! -", life_damage, " lives")

	# Track enemy leaked
	if BalanceTracker:
		var enemy_type = get_enemy_name().to_lower().replace(" ", "_")
		BalanceTracker.record_enemy_leaked(enemy_type, life_damage)

	GameStateManager.lose_life(life_damage)
	enemy_died.emit()
	queue_free()

func set_path_follower(follower: PathFollow2D):
	"""Set the path follower for this enemy"""
	path_follower = follower

func set_waypoint_navigation(start_waypoint: PathWaypoint):
	"""Initialize waypoint navigation system (new way)"""
	use_waypoint_navigation = true
	current_waypoint = start_waypoint

	if current_waypoint:
		# Set initial target to random position within first waypoint's road width
		target_position = current_waypoint.get_random_position_in_road()
		global_position = target_position # Start at first waypoint
		print(get_enemy_name(), " starting waypoint navigation at: ", current_waypoint.name)
	else:
		print("ERROR: No start waypoint provided!")

# ============================================
# COMBAT ANCHOR SYSTEM (New)
# ============================================

# 4 Slots: Left, Right, Top, Bottom
var engagement_slots = [null, null, null, null]
const SLOT_OFFSET = 40.0 # Distance from enemy center

func request_engagement_slot(hero: Node2D) -> int:
	"""Hero requests a slot to attack from"""
	# 1. Check if hero already has a slot
	var existing_index = engagement_slots.find(hero)
	if existing_index != -1:
		return existing_index
		
	# 2. Find first empty slot
	for i in range(engagement_slots.size()):
		if engagement_slots[i] == null:
			engagement_slots[i] = hero
			return i
			
	# 3. No slots available (full)
	return -1

func release_engagement_slot(hero: Node2D):
	"""Hero leaves combat"""
	var index = engagement_slots.find(hero)
	if index != -1:
		engagement_slots[index] = null

func get_slot_position(slot_index: int) -> Vector2:
	"""Get global position for a specific slot"""
	var offset = Vector2.ZERO
	match slot_index:
		0: offset = Vector2(-SLOT_OFFSET, 0) # Left
		1: offset = Vector2(SLOT_OFFSET, 0) # Right
		2: offset = Vector2(0, -SLOT_OFFSET) # Top
		3: offset = Vector2(0, SLOT_OFFSET) # Bottom
	return global_position + offset


# ============================================
# HELPER METHODS
# ============================================

func get_enemy_name() -> String:
	"""Override this in child classes to return enemy name"""
	return "Enemy"

func is_dead() -> bool:
	"""Check if this enemy is dead (used by tower targeting logic)"""
	return current_health <= 0.0

func _play_animation(anim_name: String):
	"""Play animation if AnimationPlayer exists"""
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

func _spawn_impact_particles(damage_source):
	"""Create impact particles for melee hits - subtle blood splatter"""
	var particle_scene = load("res://scenes/effects/blood_splatter.tscn")
	if not particle_scene:
		return
		
	var particles = particle_scene.instantiate()
	get_parent().add_child(particles)
	particles.global_position = global_position

	# Calculate direction away from attacker
	var direction = Vector2.UP
	if damage_source and is_instance_valid(damage_source):
		direction = (global_position - damage_source.global_position).normalized()
	
	particles.direction = direction
	particles.emitting = true

func _play_hit_flash():
	"""Flash enemy white briefly when hit - instant visual feedback"""
	var sprite_node = _get_visual_sprite()
	if sprite_node and sprite_node.material:
		# Enable shader parameter
		sprite_node.material.set_shader_parameter("active", true)
		
		# Wait 0.1s
		await get_tree().create_timer(0.1).timeout
		
		# Disable shader parameter
		if is_instance_valid(sprite_node) and sprite_node.material:
			sprite_node.material.set_shader_parameter("active", false)
	else:
		# Fallback to old modulate method if no shader
		var original_modulate = modulate
		modulate = Color(2.0, 2.0, 2.0, 1.0) # Bright white flash
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self):
			modulate = original_modulate

func _spawn_damage_number(damage: float):
	"""Spawn floating damage number above enemy - satisfying feedback"""
	# Create label for damage number
	var damage_label = Label.new()
	get_parent().add_child(damage_label)

	# Position above enemy
	damage_label.global_position = global_position + Vector2(randf_range(-10, 10), -30)

	# Format damage number (round to integer for cleaner display)
	var damage_int = int(round(damage))
	damage_label.text = str(damage_int)

	# Styling - small, bold, colored
	damage_label.add_theme_font_size_override("font_size", 14)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.z_index = 100 # Above everything

	# Color based on damage amount (visual feedback for damage size)
	if damage >= 20:
		damage_label.modulate = Color(1.0, 0.3, 0.3) # Red for high damage
	elif damage >= 10:
		damage_label.modulate = Color(1.0, 0.7, 0.2) # Orange for medium damage
	else:
		damage_label.modulate = Color(1.0, 1.0, 0.5) # Yellow for low damage

	# Animate: float upward and fade out
	var tween = create_tween()
	tween.set_parallel(true)

	# Float upward
	tween.tween_property(damage_label, "global_position:y", damage_label.global_position.y - 50, 0.8).set_ease(Tween.EASE_OUT)

	# Fade out
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)

	# Scale up slightly then down (pop effect)
	tween.tween_property(damage_label, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "scale", Vector2(0.8, 0.8), 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)

	# Cleanup after animation - use tween callback instead of await
	# This ensures cleanup happens even if enemy dies during animation
	tween.finished.connect(func():
		if is_instance_valid(damage_label):
			damage_label.queue_free()
	)

func _spawn_death_particles():
	"""Create subtle death particles when enemy dies"""
	# Create particle system
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position

	# Particle burst settings - fewer, more natural
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.randomness = 0.6

	# Emission shape - small circle burst
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 8.0

	# Movement - moderate explosion
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 200)
	particles.damping_min = 3.0
	particles.damping_max = 8.0

	# Rotation - less extreme
	particles.angular_velocity_min = -120.0
	particles.angular_velocity_max = 120.0

	# Visuals - smaller, darker particles
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.5
	particles.color = Color(0.8, 0.3, 0.15, 1)

	# Natural fade out gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.4, 0.2, 1.0))
	gradient.add_point(0.4, Color(0.7, 0.25, 0.1, 0.7))
	gradient.add_point(1.0, Color(0.4, 0.15, 0.05, 0.0))
	particles.color_ramp = gradient

	# Auto-cleanup
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _spawn_gold_coin_effect():
	"""Spawn subtle gold coin particles toward UI - rewarding but not distracting"""
	# Only spawn if we actually give gold
	if gold_reward <= 0:
		return

	# Find the gold label in UI
	var gold_label = get_tree().get_first_node_in_group("gold_label")
	if not gold_label:
		return # No UI target, skip effect

	# Create small particle burst
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position

	# Subtle gold particles
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 3 # Very few particles - subtle
	particles.lifetime = 0.4 # Quick animation
	particles.explosiveness = 1.0
	particles.randomness = 0.3

	# Small upward arc
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	particles.direction = Vector2(0, -1) # Upward
	particles.spread = 30.0

	# Movement - gentle upward float
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 70.0
	particles.gravity = Vector2(0, -50) # Float up
	particles.damping_min = 3.0
	particles.damping_max = 5.0

	# Visuals - dark gold color (subtle)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 2.5
	particles.color = Color(0.7, 0.6, 0.2, 0.9) # Dark gold

	# Fade out gracefully
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.65, 0.25, 1.0))
	gradient.add_point(0.5, Color(0.7, 0.55, 0.2, 0.7))
	gradient.add_point(1.0, Color(0.5, 0.4, 0.15, 0.0))
	particles.color_ramp = gradient

	# Auto-cleanup
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _play_death_animation():
	"""Play death animation with corpse lingering - fast-paced like Kingdom Rush"""
	const DEATH_DURATION = 0.25 # Initial death animation
	const CORPSE_LINGER_TIME = 0.6 # How long corpse stays visible (fast-paced)
	const FADE_OUT_TIME = 0.4 # Final fade out duration

	# Spawn particles first
	_spawn_death_particles()

	# Hide health bar immediately
	if health_bar:
		health_bar.visible = false

	# Stop movement - FREEZE in place
	set_physics_process(false)
	velocity = Vector2.ZERO # Stop any momentum

	# CRITICAL: Disable collisions so corpse is PURELY VISUAL
	# Arrows and other attacks pass through the corpse
	collision_layer = 0 # Remove from all collision layers
	collision_mask = 0 # Don't detect any collisions

	# Disable all Area2D children (detection zones) so towers don't target corpses
	for child in get_children():
		if child is Area2D:
			child.monitoring = false
			child.monitorable = false

	# Phase 1: Initial death animation (shrink slightly + darken)
	var tween1 = create_tween()
	tween1.set_parallel(true)

	# Shrink to 70% size (not disappear completely)
	tween1.tween_property(self, "scale", scale * 0.7, DEATH_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Darken slightly (not fully transparent)
	tween1.tween_property(self, "modulate", Color(0.6, 0.5, 0.5, 0.8), DEATH_DURATION).set_ease(Tween.EASE_OUT)

	# Small rotation
	tween1.tween_property(self, "rotation", rotation + PI * 0.5, DEATH_DURATION).set_ease(Tween.EASE_OUT)

	await tween1.finished

	# Phase 2: Corpse lingers (stays visible for player satisfaction)
	await get_tree().create_timer(CORPSE_LINGER_TIME).timeout

	# Phase 3: Final fade out (slow disappearance)
	var tween2 = create_tween()
	tween2.set_parallel(true)

	# Shrink to nothing
	tween2.tween_property(self, "scale", Vector2.ZERO, FADE_OUT_TIME).set_ease(Tween.EASE_IN)

	# Fade to transparent
	tween2.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME).set_ease(Tween.EASE_IN)

	await tween2.finished

# ============================================
# STATUS EFFECTS (Slow & Knockback)
# ============================================

var current_slow: float = 0.0 # 0.0-1.0 (speed reduction percentage)
var slow_timer: Timer = null

func apply_slow(slow_percent: float, duration: float):
	"""Apply speed reduction effect from frost mage"""
	# Use strongest slow if multiple slows applied
	current_slow = max(current_slow, slow_percent)

	# Create or restart slow timer
	if slow_timer == null:
		slow_timer = Timer.new()
		add_child(slow_timer)
		slow_timer.timeout.connect(_on_slow_expired)

	slow_timer.start(duration)

	# Visual feedback (blue tint)
	modulate = Color(0.6, 0.6, 1.0)

func _on_slow_expired():
	"""Remove slow effect"""
	current_slow = 0.0
	modulate = Color.WHITE

func get_effective_speed() -> float:
	"""Get current speed with slow applied"""
	return speed * (1.0 - current_slow)

func apply_knockback(force: float, explosion_pos: Vector2):
	"""Push enemy backward from explosion (artillery cannon path)"""
	# Get direction away from explosion
	var knockback_dir = (global_position - explosion_pos).normalized()
	var knockback_distance = force / 10.0 # Scale force to pixels

	# Apply knockback by moving enemy backward
	if use_waypoint_navigation:
		# Waypoint system: just offset position
		global_position += knockback_dir * knockback_distance
	else:
		# PathFollow2D system: reduce progress
		var parent = get_parent()
		if parent is PathFollow2D:
			parent.progress -= knockback_distance
			# Clamp to prevent negative progress
			parent.progress = max(0, parent.progress)

# ============================================
# CROWD CONTROL (Stun & Taunt)
# ============================================

var is_stunned: bool = false
var stun_timer: Timer = null

func stun(duration: float):
	"""Stun the enemy, preventing movement and attacks"""
	if is_stunned:
		# Extend duration if already stunned
		if stun_timer:
			stun_timer.start(duration)
		return

	is_stunned = true
	
	# Visual feedback (yellow tint)
	modulate = Color(1.5, 1.5, 0.5)
	
	# Create timer if needed
	if stun_timer == null:
		stun_timer = Timer.new()
		add_child(stun_timer)
		stun_timer.one_shot = true
		stun_timer.timeout.connect(_on_stun_expired)
		
	stun_timer.start(duration)

func _on_stun_expired():
	is_stunned = false
	modulate = Color.WHITE
	
func set_target(new_target):
	"""Force enemy to target a specific unit (Taunt)"""
	if new_target and new_target.has_method("take_damage"):
		# If we are blocked, switch blocker?
		# Or if we are free, move towards target?
		# For now, if it's a hero, we treat it as a block
		if new_target.is_in_group("heroes"):
			set_blocked_by_hero(new_target)
			# Visual feedback
			var label = Label.new()
			label.text = "TAUNTED!"
			label.modulate = Color.RED
			label.global_position = global_position + Vector2(0, -40)
			get_parent().add_child(label)
			var tween = create_tween()
			tween.tween_property(label, "global_position:y", label.global_position.y - 30, 1.0)
			tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
			tween.tween_callback(label.queue_free)

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Cleanup (auto-handled by Godot)
	pass
