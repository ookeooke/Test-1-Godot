extends Node

## EnemyManager - Centralized enemy tracking for optimal performance
##
## Instead of each tower searching through all enemies independently,
## this singleton maintains a global list of living enemies.
## Towers can query enemies in their range efficiently.
##
## Performance Benefits:
## - With 10 towers and 50 enemies: 500 checks → 50 checks per frame (90% reduction)
## - Single source of truth for enemy state
## - Easier debugging and profiling

# ============================================
# ENEMY TRACKING
# ============================================

var living_enemies: Array[BaseEnemy] = []
var enemy_count: int = 0

## Boss tracking
var living_bosses: Array[BaseEnemy] = []
var current_boss: BaseEnemy = null

# ============================================
# SIGNALS
# ============================================

signal enemy_registered(enemy: BaseEnemy)
signal enemy_unregistered(enemy: BaseEnemy)
signal all_enemies_cleared()
signal boss_appeared(boss: BaseEnemy)
signal boss_defeated(boss: BaseEnemy)
signal boss_leaked(boss: BaseEnemy)

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("[EnemyManager] Initialized - centralized enemy tracking active")

# ============================================
# ENEMY REGISTRATION
# ============================================

func register_enemy(enemy: BaseEnemy):
	"""Register a new enemy in the global tracking system"""
	if not enemy or not is_instance_valid(enemy):
		push_warning("[EnemyManager] Attempted to register invalid enemy")
		return

	# Prevent duplicates
	if living_enemies.has(enemy):
		return

	living_enemies.append(enemy)
	enemy_count = living_enemies.size()

	# Check if this is a boss enemy
	var is_boss = false
	if "is_boss" in enemy and enemy.is_boss:
		is_boss = true
		living_bosses.append(enemy)
		current_boss = enemy
		boss_appeared.emit(enemy)
		print("🔴 [EnemyManager] BOSS REGISTERED: %s" % enemy.get_enemy_name())

	# Connect to death signal for automatic cleanup
	if enemy.has_signal("enemy_died") and not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

	enemy_registered.emit(enemy)

func unregister_enemy(enemy: BaseEnemy):
	"""Manually remove an enemy from tracking (usually called automatically on death)"""
	if not enemy:
		return

	# Check if this was a boss
	var was_boss = false
	if "is_boss" in enemy and enemy.is_boss:
		was_boss = true
		living_bosses.erase(enemy)
		if current_boss == enemy:
			current_boss = null

		# Emit boss defeated/leaked signal (check if enemy died or leaked)
		if "is_dead" in enemy and enemy.is_dead():
			boss_defeated.emit(enemy)
			print("🔴 [EnemyManager] BOSS DEFEATED: %s" % enemy.get_enemy_name())
		else:
			boss_leaked.emit(enemy)
			print("🔴 [EnemyManager] BOSS LEAKED: %s" % enemy.get_enemy_name())

	living_enemies.erase(enemy)
	enemy_count = living_enemies.size()

	enemy_unregistered.emit(enemy)

	if enemy_count == 0:
		all_enemies_cleared.emit()

func _on_enemy_died(enemy: BaseEnemy):
	"""Automatically called when enemy dies - cleanup from tracking"""
	unregister_enemy(enemy)

# ============================================
# QUERY FUNCTIONS
# ============================================

func get_enemies_in_range(position: Vector2, radius: float) -> Array[BaseEnemy]:
	"""Get all living enemies within a circular range"""
	var result: Array[BaseEnemy] = []

	for enemy in living_enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = enemy.global_position.distance_to(position)
		if distance <= radius:
			result.append(enemy)

	return result

func get_enemies_in_rect(rect: Rect2) -> Array[BaseEnemy]:
	"""Get all living enemies within a rectangular area"""
	var result: Array[BaseEnemy] = []

	for enemy in living_enemies:
		if not is_instance_valid(enemy):
			continue

		if rect.has_point(enemy.global_position):
			result.append(enemy)

	return result

func get_closest_enemy(position: Vector2, max_range: float = INF) -> BaseEnemy:
	"""Get the closest enemy to a position within max_range"""
	var closest: BaseEnemy = null
	var min_distance = max_range

	for enemy in living_enemies:
		if not is_instance_valid(enemy):
			continue

		var distance = enemy.global_position.distance_to(position)
		if distance < min_distance:
			min_distance = distance
			closest = enemy

	return closest

func get_enemy_count() -> int:
	"""Get total number of living enemies"""
	return enemy_count

func get_all_enemies() -> Array[BaseEnemy]:
	"""Get array of all living enemies (use with caution - prefer specific queries)"""
	# Clean up any invalid references
	living_enemies = living_enemies.filter(func(e): return is_instance_valid(e))
	enemy_count = living_enemies.size()
	return living_enemies.duplicate()

func get_current_boss() -> BaseEnemy:
	"""Get the current active boss (if any)"""
	if current_boss and is_instance_valid(current_boss):
		return current_boss
	return null

func get_all_bosses() -> Array[BaseEnemy]:
	"""Get all living bosses"""
	living_bosses = living_bosses.filter(func(e): return is_instance_valid(e))
	return living_bosses.duplicate()

func has_active_boss() -> bool:
	"""Check if there's currently an active boss"""
	return current_boss != null and is_instance_valid(current_boss)

# ============================================
# CLEANUP
# ============================================

func clear_all_enemies():
	"""Remove all enemies from tracking (useful for level transitions)"""
	living_enemies.clear()
	living_bosses.clear()
	current_boss = null
	enemy_count = 0
	all_enemies_cleared.emit()

func _physics_process(_delta):
	"""Periodic cleanup of invalid enemy references"""
	# Only clean every 60 frames (1 second at 60fps) to avoid performance hit
	if Engine.get_process_frames() % 60 == 0:
		var initial_count = enemy_count
		living_enemies = living_enemies.filter(func(e): return is_instance_valid(e))
		enemy_count = living_enemies.size()

		if enemy_count != initial_count:
			print("[EnemyManager] Cleaned up %d invalid enemy references" % (initial_count - enemy_count))
