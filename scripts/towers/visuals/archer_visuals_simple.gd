extends Node2D

@onready var body = $Archer/Body
@onready var weapon = $Archer/Weapon/Bow

# Animation Config
const FRAME_COUNT = 6
const ANIM_SPEED = 10.0
const IDLE_FRAME = 0 # Changed back to 0 for single-frame texture

var is_attacking = false
var anim_time = 0.0

func _ready():
	print("[ArcherVisuals] _ready called")
	
	if body:
		var tex = body.texture
		if tex:
			print("[ArcherVisuals] Body Texture: ", tex.resource_path)
			print("[ArcherVisuals] Body Size: ", tex.get_size(), " | hframes: ", body.hframes)
		
		body.frame = IDLE_FRAME
		body.visible = true
	else:
		print("[ArcherVisuals] ERROR: Body node not found!")

	if weapon:
		var tex = weapon.texture
		if tex:
			print("[ArcherVisuals] Weapon Texture: ", tex.resource_path)
			print("[ArcherVisuals] Weapon Size: ", tex.get_size(), " | hframes: ", weapon.hframes)
			
		weapon.frame = IDLE_FRAME
		weapon.visible = true
	else:
		print("[ArcherVisuals] ERROR: Weapon node not found!")

func _process(delta):
	# DEBUG: Cycle frames continuously to see ALL content
	# Uncomment the next 3 lines to force a debug loop
	# anim_time += delta * 5.0
	# var debug_frame = int(anim_time) % FRAME_COUNT
	# if body: body.frame = debug_frame
	# if weapon: weapon.frame = debug_frame
	# return 
	if is_attacking:
		anim_time += delta * ANIM_SPEED
		var frame = int(anim_time)
		
		if frame < FRAME_COUNT:
			if weapon: weapon.frame = frame
			# if body: body.frame = frame # Optional: Animate body too
		else:
			# Animation finished
			is_attacking = false
			if weapon: weapon.frame = IDLE_FRAME
			# if body: body.frame = IDLE_FRAME
	else:
		# Idle state
		if weapon: weapon.frame = IDLE_FRAME
		# if body: body.frame = IDLE_FRAME

func play_attack():
	print("[ArcherVisuals] play_attack() called")
	is_attacking = true
	anim_time = 0.0
	if weapon: weapon.frame = 0 # Start from 0 (even if empty) for animation flow
