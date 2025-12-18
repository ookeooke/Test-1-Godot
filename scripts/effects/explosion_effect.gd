extends Node2D

# ============================================
# PROCEDURAL EXPLOSION EFFECT
# ============================================
# Creates a visual explosion using:
# 1. Expanding ring (shockwave)
# 2. Central flash
# 3. Particle debris
# ============================================

@export var radius: float = 100.0:
	set(value):
		radius = value
		_update_particles()

@export var color: Color = Color(1.0, 0.6, 0.2) # Orange-ish fire
@export var duration: float = 0.5
@export var flash_color: Color = Color.WHITE

var _current_time: float = 0.0
var _particles: CPUParticles2D

func _ready():
	z_index = 100 # Ensure it renders on top of the map
	
	if DebugConfig.visual_debug_enabled:
		print("[ExplosionEffect] 💥 Visual explosion spawned at ", global_position, " radius: ", radius)

	# Create particles
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.lifetime = duration * 1.5
	_particles.amount = 16
	_particles.direction = Vector2(0, -1)
	_particles.spread = 180.0
	_particles.gravity = Vector2(0, 0)
	_particles.initial_velocity_min = radius * 2.0
	_particles.initial_velocity_max = radius * 3.0
	_particles.damping_min = 50.0
	_particles.damping_max = 100.0
	_particles.scale_amount_min = 3.0
	_particles.scale_amount_max = 6.0
	_particles.color = color
	
	# Create a simple square texture for particles (1x1 pixel expanded)
	# This avoids needing an external texture resource
	# Ideally we'd use a localized resource or create an ImageTexture on the fly if needed
	# For now, default square particles are fine (default texture is null = square)
	
	add_child(_particles)
	_particles.emitting = true
	
	# Play sound if we had an AudioManager, but projectile usually handles impact sound
	# AudioManager.play("explosion", 0.5)

func _process(delta):
	_current_time += delta
	queue_redraw() # Request redraw for the shockwave
	
	if _current_time >= duration:
		# Wait for particles to finish before freeing
		if not _particles.emitting:
			queue_free()

func _draw():
	var progress = _current_time / duration
	var ease_out = 1.0 - pow(1.0 - progress, 3.0) # Cubic ease out
	
	# 1. Central Flash (fades out quickly)
	if progress < 0.3:
		var flash_alpha = 1.0 - (progress / 0.3)
		# Slightly larger flash relative to radius for impact
		draw_circle(Vector2.ZERO, radius * 0.9 * ease_out, flash_color * flash_alpha)
	
	# 2. Expanding Shockwave (Ring)
	var ring_radius = radius * ease_out
	# Thicker ring for better visibility on small explosions
	var ring_width = max(2.0, radius * 0.25) * (1.0 - progress)
	var ring_color = color
	ring_color.a = 1.0 - progress # Fade out
	
	if ring_width > 0.5:
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 32, ring_color, ring_width, true)
	
	# 3. Inner Fire (Solid Circle)
	var inner_radius = radius * 0.6 * (1.0 - progress) # Shrinks
	if inner_radius > 1.0:
		var inner_color = color.darkened(0.2)
		inner_color.a = 0.8 * (1.0 - progress)
		draw_circle(Vector2.ZERO, inner_radius, inner_color)

func _update_particles():
	if _particles:
		_particles.initial_velocity_min = radius * 1.5
		_particles.initial_velocity_max = radius * 2.5
