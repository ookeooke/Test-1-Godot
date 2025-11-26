extends "res://scripts/enemies/base_enemy.gd"

## Goblin Scout Enemy
## Basic ground enemy with low HP and speed.
## Uses frame-based AnimatedSprite2D for walk, attack, and death animations.

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite

func _init():
	# Set goblin-specific stats
	speed = 45.0  # PACING FIX: Reduced from 75 (-40% total: -25% KR pacing, -20% strategic slowdown)
	max_health = 35.0  # BALANCE FIX: Was 50 (4.2s TTK), now 35 (2.9s TTK - matches KR1's 3.2s)
	melee_damage = 5.0
	attack_cooldown = 1.0
	gold_reward = 5  # Increased from 4 (+25% gold rewards)
	life_damage = 1
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"

	# Hit point for arrows (center/chest of goblin)
	hit_point_offset = Vector2(0, 0)

func _ready():
	super._ready()
	# Start with walk animation
	if animated_sprite:
		animated_sprite.play("walk")
		animated_sprite.animation_finished.connect(_on_animation_finished)

func get_enemy_name() -> String:
	return "Goblin"

func _play_animation(anim_name: String):
	"""Override base class to use AnimatedSprite2D frame animations"""
	if not animated_sprite:
		return

	match anim_name:
		"attack":
			animated_sprite.play("attack")
		"death":
			animated_sprite.play("death")
		"hit":
			# For hit, just do a white flash (no dedicated hit animation frames)
			_play_hit_flash()
		"idle", "walk":
			# Both idle and walk use walk animation
			if animated_sprite.animation != "attack" and animated_sprite.animation != "death":
				animated_sprite.play("walk")

func _on_animation_finished():
	"""Called when any animation finishes - return to walk after attack"""
	if animated_sprite and animated_sprite.animation == "attack":
		animated_sprite.play("walk")

func _set_combat_state_visual(in_combat: bool):
	"""Visual indicator when enemy is in melee combat"""
	if animated_sprite:
		if in_combat:
			# Reddish tint = in combat
			animated_sprite.modulate = Color(1.2, 0.8, 0.8)
		else:
			# Normal color
			animated_sprite.modulate = Color(1, 1, 1)

func _play_death_animation():
	"""Override base class death animation to use sprite frames"""
	# CRITICAL: Stop movement FIRST - freeze in place
	set_physics_process(false)
	velocity = Vector2.ZERO

	# Disable collisions so corpse is purely visual
	collision_layer = 0
	collision_mask = 0

	# Disable Area2D children so towers don't target corpse
	for child in get_children():
		if child is Area2D:
			child.monitoring = false
			child.monitorable = false

	# Hide health bar
	if health_bar:
		health_bar.visible = false

	# Play death animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

		# Brief pause on final frame (corpse linger)
		await get_tree().create_timer(0.4).timeout

		# Fade out
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		await tween.finished
	else:
		# Fallback to base class behavior if no death animation
		await super._play_death_animation()
