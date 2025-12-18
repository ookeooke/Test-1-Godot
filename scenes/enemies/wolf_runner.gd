extends "res://scripts/enemies/base_enemy.gd"

## Wolf Runner Enemy
## Fast ground enemy with low HP, high speed.

@onready var sprite = $Sprite

var previous_velocity: Vector2 = Vector2.ZERO

func _init():
	# Set wolf-specific stats
	speed = 81.0 # PACING FIX: Reduced from 135 (-40% total: -25% KR pacing, -20% strategic slowdown)
	max_health = 80.0
	melee_damage = 5.0
	attack_cooldown = 0.7
	gold_reward = 7 # Increased from 6 (+17% gold rewards)
	life_damage = 1
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "None"
	armor = 0.10 # 10% damage reduction for fast enemy

	# Hit point for arrows (slightly forward/center on wolf)
	hit_point_offset = Vector2(0, -5)

func _physics_process(delta):
	# Call parent physics logic
	super._physics_process(delta)

	# Update directional animations based on movement
	_update_directional_animation()

func _continue_movement(delta):
	# Override base class to prevent "walk" animation call
	# Directional animations are handled in _update_directional_animation()
	_path2d_movement(delta)

func _update_directional_animation():
	"""Kingdom Rush style 4-directional animations with diagonal support"""
	if not sprite or not sprite.sprite_frames:
		return

	# Get movement direction
	var direction = velocity

	# If blocked and attacking, use attack animation
	if is_blocked and blocking_hero and is_instance_valid(blocking_hero):
		if sprite.sprite_frames.has_animation("attack"):
			if sprite.animation != "attack":
				sprite.play("attack")
		direction = (blocking_hero.global_position - global_position).normalized()
	else:
		# Use velocity for running animation
		if direction.length() < 0.1:
			# Not moving much, use previous direction or default to right
			direction = previous_velocity if previous_velocity.length() > 0.1 else Vector2.RIGHT
		else:
			previous_velocity = direction

		direction = direction.normalized()

		# Threshold for directional detection (0.4 ≈ 22° from axis)
		const DIAGONAL_THRESHOLD = 0.4

		# Animation selection: Check diagonal FIRST to utilize run_diagonal animation
		if abs(direction.x) > DIAGONAL_THRESHOLD and abs(direction.y) > DIAGONAL_THRESHOLD:
			# True diagonal movement - use dedicated diagonal animation
			if sprite.sprite_frames.has_animation("run_diagonal"):
				if sprite.animation != "run_diagonal":
					sprite.play("run_diagonal")
			sprite.flip_h = direction.x < 0 # Flip horizontally when moving left
		# Cardinal directions (pure horizontal/vertical)
		elif abs(direction.x) > DIAGONAL_THRESHOLD:
			# Moving horizontally - use run_side
			if sprite.sprite_frames.has_animation("run_side"):
				if sprite.animation != "run_side":
					sprite.play("run_side")
			sprite.flip_h = direction.x < 0
		elif direction.y < -DIAGONAL_THRESHOLD:
			# Moving upward (away from camera)
			if sprite.sprite_frames.has_animation("run_up"):
				if sprite.animation != "run_up":
					sprite.play("run_up")
			sprite.flip_h = false
		elif direction.y > DIAGONAL_THRESHOLD:
			# Moving downward (toward camera)
			if sprite.sprite_frames.has_animation("run_down"):
				if sprite.animation != "run_down":
					sprite.play("run_down")
			sprite.flip_h = false

func get_enemy_name() -> String:
	return "Wolf"

func _play_death_animation():
	"""Override base class death animation to use Aseprite death animation"""
	# print("[WolfRunner] 🔴 _play_death_animation() STARTED")

	# CRITICAL: Stop movement FIRST - freeze in place
	set_physics_process(false)
	velocity = Vector2.ZERO
	# print("[WolfRunner] ⏸️  Physics stopped, velocity zeroed")

	# Disable collisions so corpse is purely visual
	collision_layer = 0
	collision_mask = 0
	# print("[WolfRunner] 🚫 Collisions disabled")

	# Disable Area2D children so towers don't target corpse
	for child in get_children():
		if child is Area2D:
			child.monitoring = false
			child.monitorable = false
	# print("[WolfRunner] 🎯 Area2D children disabled")

	# Hide health bar
	if health_bar:
		health_bar.visible = false
		# print("[WolfRunner] ❤️  Health bar hidden")

	# Play death animation
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		# print("[WolfRunner] 🎬 Playing death animation...")
		sprite.play("death")

		# Wait for animation to finish
		await sprite.animation_finished
		# print("[WolfRunner] ✅ Death animation finished")

		# Linger on last frame (satisfying "defeated" moment)
		# print("[WolfRunner] ⏳ Lingering on last frame (0.6s)...")
		await get_tree().create_timer(0.6).timeout
		# print("[WolfRunner] ⏱️  Linger complete")

		# Fade out
		# print("[WolfRunner] 🌫️  Starting fade out (0.3s)...")
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		await tween.finished
		# print("[WolfRunner] 💀 Fade out complete - death animation DONE")
	else:
		# Fallback to base class behavior if no death animation
		print("[WolfRunner] ⚠️  Death animation not found, using fallback")
		await super._play_death_animation()
		print("[WolfRunner] 💀 Fallback death animation DONE")
