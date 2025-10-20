extends Node

## Enemy Sprite Generator - Creates simple 32x32 pixel art sprites
## Run this to generate placeholder sprites for enemies

const SPRITE_SIZE = 32

static func create_goblin_sprite() -> Image:
	var img = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background

	# Color palette
	var skin_color = Color(0.4, 0.6, 0.2)  # Green skin
	var skin_dark = Color(0.3, 0.45, 0.15)  # Dark green
	var cloth_color = Color(0.4, 0.3, 0.2)  # Brown cloth
	var eye_color = Color(1.0, 0.9, 0.2)  # Yellow eyes
	var weapon_color = Color(0.6, 0.6, 0.7)  # Gray weapon
	var black = Color(0.1, 0.1, 0.1)

	# Head (centered)
	_draw_rect(img, 10, 8, 12, 10, skin_color)  # Main head
	_draw_rect(img, 9, 10, 14, 2, skin_dark)  # Jaw shadow

	# Ears (pointy)
	_draw_pixel(img, 9, 10, skin_color)
	_draw_pixel(img, 8, 11, skin_color)
	_draw_pixel(img, 22, 10, skin_color)
	_draw_pixel(img, 23, 11, skin_color)

	# Eyes
	_draw_pixel(img, 13, 12, eye_color)
	_draw_pixel(img, 18, 12, eye_color)
	_draw_pixel(img, 13, 13, black)  # Pupils
	_draw_pixel(img, 18, 13, black)

	# Nose
	_draw_pixel(img, 16, 14, skin_dark)

	# Mouth (grimace)
	_draw_rect(img, 14, 16, 4, 1, black)

	# Body (smaller, hunched)
	_draw_rect(img, 11, 18, 10, 8, cloth_color)

	# Arms
	_draw_rect(img, 9, 19, 2, 6, skin_color)  # Left arm
	_draw_rect(img, 21, 19, 2, 6, skin_color)  # Right arm

	# Weapon in right hand (crude blade)
	_draw_rect(img, 23, 17, 2, 8, weapon_color)
	_draw_pixel(img, 24, 16, weapon_color)  # Blade tip
	_draw_rect(img, 23, 25, 2, 2, cloth_color)  # Handle

	# Legs (short)
	_draw_rect(img, 12, 26, 3, 5, skin_color)  # Left leg
	_draw_rect(img, 17, 26, 3, 5, skin_color)  # Right leg

	# Feet
	_draw_rect(img, 11, 30, 4, 2, cloth_color)
	_draw_rect(img, 17, 30, 4, 2, cloth_color)

	return img


static func create_goblin_attack_sprite() -> Image:
	"""Slightly modified attack pose - weapon raised"""
	var img = create_goblin_sprite()

	# Clear weapon area and redraw in raised position
	var weapon_color = Color(0.6, 0.6, 0.7)
	var cloth_color = Color(0.4, 0.3, 0.2)

	# Clear old weapon
	_draw_rect(img, 23, 17, 2, 10, Color(0, 0, 0, 0))

	# Draw raised weapon
	_draw_rect(img, 24, 12, 2, 7, weapon_color)  # Blade raised
	_draw_pixel(img, 25, 11, weapon_color)  # Tip
	_draw_rect(img, 24, 19, 2, 2, cloth_color)  # Handle

	return img


static func _draw_rect(img: Image, x: int, y: int, w: int, h: int, color: Color):
	"""Draw a filled rectangle"""
	for py in range(h):
		for px in range(w):
			_draw_pixel(img, x + px, y + py, color)


static func _draw_pixel(img: Image, x: int, y: int, color: Color):
	"""Draw a single pixel with bounds checking"""
	if x >= 0 and x < SPRITE_SIZE and y >= 0 and y < SPRITE_SIZE:
		img.set_pixel(x, y, color)


static func generate_goblin_sprites():
	"""Generate and save goblin sprite images"""
	print("[SpriteGen] Generating Goblin Scout sprites...")

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/enemies")

	# Generate idle sprite
	var idle_img = create_goblin_sprite()
	var idle_path = "res://assets/sprites/enemies/goblin_idle.png"
	var err = idle_img.save_png(idle_path)
	if err == OK:
		print("[SpriteGen] Saved: ", idle_path)
	else:
		print("[SpriteGen] ERROR saving idle sprite: ", err)

	# Generate attack sprite
	var attack_img = create_goblin_attack_sprite()
	var attack_path = "res://assets/sprites/enemies/goblin_attack.png"
	err = attack_img.save_png(attack_path)
	if err == OK:
		print("[SpriteGen] Saved: ", attack_path)
	else:
		print("[SpriteGen] ERROR saving attack sprite: ", err)

	print("[SpriteGen] Goblin sprite generation complete!")
	print("[SpriteGen] To replace: Put your own 32x32 PNG sprites at these paths")
