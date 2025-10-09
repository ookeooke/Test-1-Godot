extends CharacterBody2D

# Signal to notify when this enemy is removed
signal enemy_died

var speed := 100.0
var max_health := 50.0
var current_health := 50.0
var melee_damage := 5.0

# BLOCKING SYSTEM
var is_blocked := false
var blocking_hero = null
var attack_timer := 0.0
var attack_cooldown := 1.0

@onready var path_follower: PathFollow2D = get_parent() as PathFollow2D

func _ready():
	# Set collision
	collision_layer = 1
	collision_mask = 0
	
	# OPTIONAL: Register enemies as clickable for debugging/info
	# You can click enemies to see their health, etc.
	ClickManager.register_clickable(self, ClickManager.ClickPriority.ENEMY, 30.0)
	
	print("Goblin spawned at: ", global_position)

# ============================================
# OPTIONAL: Click callback for debugging
# ============================================

func on_clicked(is_double_click: bool):
	"""Optional: Show enemy info when clicked"""
	print("📍 Clicked Goblin - HP: ", current_health, "/", max_health)
	# Could show health bar or info popup here

func on_hover_start():
	"""Optional: Highlight enemy on hover"""
	$ColorRect.modulate = Color(1.3, 1.3, 1.3)

func on_hover_end():
	"""Optional: Remove highlight"""
	$ColorRect.modulate = Color(1, 1, 1)

# ============================================
# ENEMY BEHAVIOR (unchanged)
# ============================================

func _physics_process(delta):
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		handle_hero_combat(delta)
	elif path_follower:
		path_follower.progress += speed * delta
		if path_follower.progress_ratio >= 1.0:
			reached_end()

func handle_hero_combat(delta):
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		if blocking_hero.has_method("take_damage"):
			blocking_hero.take_damage(melee_damage)
			print("Goblin attacked hero for ", melee_damage, " damage!")

func set_blocked_by_hero(hero):
	is_blocked = true
	blocking_hero = hero
	attack_timer = 0.0
	print("Goblin is now blocked by hero!")

func unblock():
	is_blocked = false
	blocking_hero = null
	print("Goblin is no longer blocked!")

func reached_end():
	print("Goblin reached the end!")
	GameManager.lose_life(1)
	enemy_died.emit()
	queue_free()

func take_damage(amount: float):
	current_health -= amount
	print("Goblin took ", amount, " damage! HP: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("Goblin died!")
	GameManager.add_gold(5)
	
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		pass
	
	enemy_died.emit()
	queue_free()

func set_path_follower(follower: PathFollow2D):
	path_follower = follower

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Unregister from ClickManager
	ClickManager.unregister_clickable(self)
