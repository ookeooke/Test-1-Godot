extends Node2D

signal construction_finished

@export var build_time: float = 2.0
@onready var progress_bar = $ProgressBar
@onready var sprite = $Sprite2D
@onready var particles = $DustParticles

var current_time: float = 0.0
var is_building: bool = false

func _ready():
	# Hide progress bar initially
	if progress_bar:
		progress_bar.visible = false
		progress_bar.value = 0
		progress_bar.max_value = 100

func start_construction(time: float = 2.0):
	build_time = time
	current_time = 0.0
	is_building = true
	
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = 0
		
	# Play start effect
	if particles:
		particles.emitting = true
		
	# print("🏗️ Construction started (%.1fs)" % build_time)

func _process(delta):
	if not is_building:
		return
		
	current_time += delta
	
	# Update progress bar
	if progress_bar:
		var progress_pct = (current_time / build_time) * 100.0
		progress_bar.value = progress_pct
		
	# Check for completion
	if current_time >= build_time:
		_finish()

func _finish():
	is_building = false
	if progress_bar:
		progress_bar.visible = false
		
	# Play finish effect (optional: could spawn a different particle here)
	if particles:
		particles.emitting = true
		
	# print("🏗️ Construction complete!")
	construction_finished.emit()
	
	# Auto-remove self after a moment (or let the tower remove us)
	# We'll let the tower remove us to ensure smooth transition
