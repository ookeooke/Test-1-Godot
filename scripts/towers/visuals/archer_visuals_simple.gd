extends Node2D

@onready var anim_sprite = $Archer/Body
@onready var muzzle_flash = $Archer/Weapon/MuzzleFlash

var is_attacking: bool = false

func _ready():
	print("[ArcherVisuals] _ready called")
	if anim_sprite:
		var anim_names = anim_sprite.sprite_frames.get_animation_names()
		print("[ArcherVisuals] Available animations: ", anim_names)

		# Start with idle animation
		_play_idle()
	else:
		print("[ArcherVisuals] ERROR: Body (AnimatedSprite2D) not found!")

func _play_idle():
	if not anim_sprite:
		return

	if anim_sprite.sprite_frames.has_animation("idle"):
		if anim_sprite.animation != "idle":  # Only play if not already playing
			anim_sprite.play("idle")
	elif anim_sprite.sprite_frames.get_animation_names().size() > 0:
		var anim_names = anim_sprite.sprite_frames.get_animation_names()
		print("[ArcherVisuals] 'idle' not found. Defaulting to: ", anim_names[0])
		anim_sprite.play(anim_names[0])

func play_attack():
	if not anim_sprite:
		return

	is_attacking = true

	# Play attack animation if available
	if anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
		# Wait for animation to finish, then return to idle
		await anim_sprite.animation_finished
	else:
		print("[ArcherVisuals] 'attack' animation missing!")

	# Always return to idle after attack
	is_attacking = false
	_play_idle()

	# Trigger muzzle flash
	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true
