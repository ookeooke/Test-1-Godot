extends CharacterBody2D
class_name BaseEnemy

## Base Enemy Class
## All enemy types extend this class and set their own stats via @export variables in Inspector.
## Contains all shared logic: movement, blocking, combat, health, death.

# ============================================
# SIGNALS
# ============================================

signal enemy_died

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

## Camera shake intensity when enemy dies
@export_enum("None", "Small", "Medium", "Large") var death_shake: String = "None"

## Target spot offset for projectiles (adjustable per enemy type)
## This is where arrows/projectiles will aim (relative to enemy origin)
@export var hit_point_offset: Vector2 = Vector2.ZERO

# ============================================
# RUNTIME VARIABLES
# ============================================

var current_health: float
var is_blocked := false
var blocking_hero = null
var attack_timer := 0.0
var debug_highlight: Polygon2D  # Visual target indicator (F4 debug)
var hit_point_marker: Marker2D  # Dynamic target spot for projectiles
var hit_point_visual: Polygon2D  # Visual indicator for hit point in editor

# ============================================
# REFERENCES
# ============================================

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D
@onready var health_bar = $HealthBar

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
	debug_highlight.color = Color(1, 0, 0, 0.3)  # Red, transparent
	debug_highlight.visible = false

	# Setup HitPoint marker system for projectile targeting
	_setup_hit_point_marker()

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
		Vector2(0, 0),  # Center point to connect lines
		Vector2(0, -crosshair_size), Vector2(0, crosshair_size)
	])
	hit_point_visual.polygon = crosshair_points
	hit_point_visual.color = Color(1, 1, 0, 0.8)  # Bright yellow, mostly opaque

	# Add small circle at center
	var circle_points = []
	for i in range(16):
		var angle = (i / 16.0) * TAU
		circle_points.append(Vector2(cos(angle), sin(angle)) * 3)

	# Create separate circle polygon
	var circle_visual = Polygon2D.new()
	hit_point_marker.add_child(circle_visual)
	circle_visual.polygon = PackedVector2Array(circle_points)
	circle_visual.color = Color(1, 0.5, 0, 0.6)  # Orange, semi-transparent
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

func _physics_process(delta):
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		# I am the blocked enemy - check if hero is still close
		var distance = global_position.distance_to(blocking_hero.global_position)
		if distance > melee_detection_range:
			# Hero walked away - resume movement
			unblock()
			if path_follower:
				path_follower.progress += speed * delta
				if path_follower.progress_ratio >= 1.0:
					reached_end()
		else:
			# Hero still close - I'm blocked, so fight!
			handle_hero_combat(delta)
	else:
		# I am NOT blocked - just walk the path normally (ignore hero)
		if path_follower:
			path_follower.progress += speed * delta
			if path_follower.progress_ratio >= 1.0:
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

# ============================================
# BLOCKING SYSTEM
# ============================================

func set_blocked_by_hero(hero):
	"""Called by hero when enemy enters melee range"""
	if not can_be_blocked:
		return

	is_blocked = true
	blocking_hero = hero
	attack_timer = 0.0

func unblock():
	"""Called when hero dies or moves away"""
	is_blocked = false
	blocking_hero = null

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	"""Apply damage to this enemy"""
	current_health -= amount

	# Update health bar
	_update_health_bar()

	if current_health <= 0:
		die()

func _update_health_bar():
	"""Update the health bar visual"""
	if health_bar:
		health_bar.update_health(current_health, max_health)

func die():
	"""Handle enemy death"""
	# Award gold
	GameManager.add_gold(gold_reward)

	# Camera shake based on enemy type
	var camera = get_viewport().get_camera_2d()
	if camera:
		match death_shake:
			"None":
				pass  # No shake
			"Small":
				CameraEffects.small_shake(camera)
			"Medium":
				CameraEffects.medium_shake(camera)
			"Large":
				CameraEffects.large_shake(camera)

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
	print(get_enemy_name(), " reached the end! -", life_damage, " lives")
	GameManager.lose_life(life_damage)
	enemy_died.emit()
	queue_free()

func set_path_follower(follower: PathFollow2D):
	"""Set the path follower for this enemy"""
	path_follower = follower

# ============================================
# HELPER METHODS
# ============================================

func get_enemy_name() -> String:
	"""Override this in child classes to return enemy name"""
	return "Enemy"

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Cleanup (auto-handled by Godot)
	pass
