extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D

func _ready():
	# Start emitting immediately
	if particles:
		particles.emitting = true
		
	# Auto-destroy after particle lifetime
	# Default lifetime is usually 1.0s, add a buffer
	get_tree().create_timer(1.5).timeout.connect(queue_free)
