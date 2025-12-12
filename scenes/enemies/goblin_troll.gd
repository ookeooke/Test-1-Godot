extends "res://scripts/enemies/base_enemy.gd"

## Goblin Troll Boss
## BOSS ENEMY - Massive HP, high armor, devastating attacks
## Uses Aseprite AnimatedSprite2D for walk, attack, and death animations.

@onready var sprite = $Sprite

var previous_velocity: Vector2 = Vector2.ZERO

func _init():
	# BOSS STATS - Much more powerful than regular enemies
	speed = 25.0 # Very slow - bosses are imposing and methodical
	max_health = 800.0 # BOSS HP - takes sustained fire to kill
	melee_damage = 25.0 # Devastating melee attacks - can kill heroes quickly
	attack_cooldown = 2.0 # Heavy, powerful swings
	gold_reward = 50 # Big gold reward for defeating a boss
	life_damage = 5 # HUGE penalty if boss reaches the end
	can_be_blocked = true
	melee_detection_range = 120.0 # Larger aggro range
	death_shake = "Medium" # Boss death should shake the screen
	armor = 0.35 # 35% damage reduction - very tough

	# Hit point for arrows (center of troll boss)
	hit_point_offset = Vector2(0, -15)

func _physics_process(delta):
	# Call parent physics logic
	super._physics_process(delta)

	# Update animations based on movement and combat state
	_update_animation()

func _update_animation():
	"""Update sprite animation based on state"""
	if not sprite or not sprite.sprite_frames:
		return

	# If blocked and attacking, use attack animation
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		if sprite.sprite_frames.has_animation("attack"):
			if sprite.animation != "attack":
				sprite.play("attack")
		# Flip to face the hero
		var direction_to_hero = blocking_hero.global_position - global_position
		sprite.flip_h = direction_to_hero.x < 0
	else:
		# Use walk animation when moving
		if sprite.sprite_frames.has_animation("walk_side"):
			if sprite.animation != "walk_side":
				sprite.play("walk_side")

		# Flip based on movement direction
		if velocity.length() > 1.0:
			sprite.flip_h = velocity.x < 0
			previous_velocity = velocity
		elif previous_velocity.length() > 1.0:
			# Not moving much, use previous direction
			sprite.flip_h = previous_velocity.x < 0

func get_enemy_name() -> String:
	return "Troll"

func _play_death_animation():
	"""Override base class death animation to use Aseprite death animation"""
	print("[GoblinTroll] 🔴 _play_death_animation() STARTED")

	# CRITICAL: Stop movement FIRST - freeze in place
	set_physics_process(false)
	velocity = Vector2.ZERO
	print("[GoblinTroll] ⏸️  Physics stopped, velocity zeroed")

	# Disable collisions so corpse is purely visual
	collision_layer = 0
	collision_mask = 0
	print("[GoblinTroll] 🚫 Collisions disabled")

	# Disable Area2D children so towers don't target corpse
	for child in get_children():
		if child is Area2D:
			child.monitoring = false
			child.monitorable = false
	print("[GoblinTroll] 🎯 Area2D children disabled")

	# Hide health bar
	if health_bar:
		health_bar.visible = false
		print("[GoblinTroll] ❤️  Health bar hidden")

	# Play death animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		print("[GoblinTroll] 🎬 Playing death animation...")
		
		# CRITICAL FIX: Force disable looping for death animation
		# Aseprite imports often default to looping, which breaks the await below.
		sprite.sprite_frames.set_animation_loop("death", false)
		
		sprite.play("death")

		# Wait for animation to finish
		await sprite.animation_finished
		print("[GoblinTroll] ✅ Death animation finished")

		# BOSS: Linger longer on death (epic defeat moment)
		print("[GoblinTroll] ⏳ Lingering on last frame (1.2s - BOSS)...")
		await get_tree().create_timer(1.2).timeout
		print("[GoblinTroll] ⏱️  Linger complete")

		# Fade out slower for boss
		print("[GoblinTroll] 🌫️  Starting fade out (0.6s - BOSS)...")
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
		await tween.finished
		print("[GoblinTroll] 💀 Fade out complete - BOSS DEFEATED!")
	else:
		# Fallback to base class behavior if no death animation
		print("[GoblinTroll] ⚠️  Death animation not found, using fallback")
		await super._play_death_animation()
		print("[GoblinTroll] 💀 Fallback death animation DONE")
