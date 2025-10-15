extends CharacterBody2D
class_name BaseEnemy

## Base Enemy Class
## All enemy types extend this class and provide their own EnemyStats resource.
## Contains all shared logic: movement, blocking, combat, health, death.

# ============================================
# SIGNALS
# ============================================

signal enemy_died

# ============================================
# STATS (Assigned via Inspector)
# ============================================

## Enemy stats resource - assign a .tres file for each enemy type
@export var stats: EnemyStats

# ============================================
# RUNTIME VARIABLES
# ============================================

var current_health: float
var is_blocked := false
var blocking_hero = null
var attack_timer := 0.0

# ============================================
# REFERENCES
# ============================================

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D
@onready var health_bar = $HealthBar

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Validate stats
	if stats == null:
		push_error("BaseEnemy: No stats assigned! Please assign an EnemyStats resource in the Inspector.")
		queue_free()
		return

	# Initialize health
	current_health = stats.max_health

	# Set collision
	collision_layer = 1
	collision_mask = 0

	# Register with ClickManager for debugging
	ClickManager.register_clickable(self, ClickManager.ClickPriority.ENEMY, 30.0)

	# Initialize health bar
	_update_health_bar()

	print(get_enemy_name(), " spawned at: ", global_position)

# ============================================
# OPTIONAL: Click callbacks for debugging
# ============================================

func on_clicked(is_double_click: bool):
	"""Show enemy info when clicked"""
	print("📍 Clicked ", get_enemy_name(), " - HP: ", current_health, "/", stats.max_health)

func on_hover_start():
	"""Highlight enemy on hover"""
	if has_node("ColorRect"):
		$ColorRect.modulate = Color(1.3, 1.3, 1.3)

func on_hover_end():
	"""Remove highlight"""
	if has_node("ColorRect"):
		$ColorRect.modulate = Color(1, 1, 1)

# ============================================
# MAIN LOOP
# ============================================

func _physics_process(delta):
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		# I am the blocked enemy - check if hero is still close
		var distance = global_position.distance_to(blocking_hero.global_position)
		if distance > stats.melee_detection_range:
			# Hero walked away - resume movement
			unblock()
			if path_follower:
				path_follower.progress += stats.speed * delta
				if path_follower.progress_ratio >= 1.0:
					reached_end()
		else:
			# Hero still close - I'm blocked, so fight!
			handle_hero_combat(delta)
	else:
		# I am NOT blocked - just walk the path normally (ignore hero)
		if path_follower:
			path_follower.progress += stats.speed * delta
			if path_follower.progress_ratio >= 1.0:
				reached_end()

# ============================================
# COMBAT
# ============================================

func handle_hero_combat(delta):
	"""Attack the blocking hero periodically"""
	attack_timer += delta
	if attack_timer >= stats.attack_cooldown:
		attack_timer = 0.0
		if blocking_hero.has_method("take_damage"):
			blocking_hero.take_damage(stats.melee_damage)
			print(get_enemy_name(), " attacked hero for ", stats.melee_damage, " damage!")

# ============================================
# BLOCKING SYSTEM
# ============================================

func set_blocked_by_hero(hero):
	"""Called by hero when enemy enters melee range"""
	if not stats.can_be_blocked:
		print(get_enemy_name(), " can't be blocked - it's flying!")
		return

	is_blocked = true
	blocking_hero = hero
	attack_timer = 0.0
	print(get_enemy_name(), " is now blocked by hero!")

func unblock():
	"""Called when hero dies or moves away"""
	is_blocked = false
	blocking_hero = null
	print(get_enemy_name(), " is no longer blocked!")

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	"""Apply damage to this enemy"""
	current_health -= amount
	print(get_enemy_name(), " took ", amount, " damage! HP: ", current_health, "/", stats.max_health)

	# Update health bar
	_update_health_bar()

	if current_health <= 0:
		die()

func _update_health_bar():
	"""Update the health bar visual"""
	if health_bar:
		health_bar.update_health(current_health, stats.max_health)

func die():
	"""Handle enemy death"""
	print(get_enemy_name(), " died! +", stats.gold_reward, " gold")

	# Award gold
	GameManager.add_gold(stats.gold_reward)

	# Camera shake based on enemy type
	var camera = get_viewport().get_camera_2d()
	if camera:
		match stats.death_shake:
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
	print(get_enemy_name(), " reached the end! -", stats.life_damage, " lives")
	GameManager.lose_life(stats.life_damage)
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
	# Unregister from ClickManager
	ClickManager.unregister_clickable(self)
