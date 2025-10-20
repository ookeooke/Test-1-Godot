extends Node

## Item Icon Generator - Creates simple pixel art icons for items
## Run this from editor to generate icons

const ICON_SIZE = 32
const PIXEL_SCALE = 4  # Each "pixel" is 4x4 actual pixels

static func create_sword_icon() -> Image:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background

	# Blade (silver/gray)
	var blade_color = Color(0.8, 0.8, 0.9)
	_draw_pixel(img, 15, 4, blade_color)
	_draw_pixel(img, 16, 5, blade_color)
	_draw_pixel(img, 17, 6, blade_color)
	_draw_pixel(img, 18, 7, blade_color)
	_draw_pixel(img, 19, 8, blade_color)
	_draw_pixel(img, 20, 9, blade_color)
	_draw_pixel(img, 21, 10, blade_color)
	_draw_pixel(img, 22, 11, blade_color)
	_draw_pixel(img, 23, 12, blade_color)
	_draw_pixel(img, 22, 13, blade_color)
	_draw_pixel(img, 21, 14, blade_color)

	# Handle (brown)
	var handle_color = Color(0.6, 0.4, 0.2)
	_draw_pixel(img, 20, 15, handle_color)
	_draw_pixel(img, 19, 16, handle_color)
	_draw_pixel(img, 18, 17, handle_color)
	_draw_pixel(img, 17, 18, handle_color)

	# Guard (gold)
	var guard_color = Color(0.9, 0.7, 0.2)
	_draw_pixel(img, 16, 14, guard_color)
	_draw_pixel(img, 17, 14, guard_color)
	_draw_pixel(img, 18, 14, guard_color)
	_draw_pixel(img, 19, 14, guard_color)
	_draw_pixel(img, 20, 14, guard_color)

	return img

static func create_bow_icon() -> Image:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Bow wood (brown)
	var wood_color = Color(0.6, 0.4, 0.2)
	# Left curve
	for y in range(6, 26):
		_draw_pixel(img, 8, y, wood_color)
	# Right curve
	for y in range(8, 24):
		_draw_pixel(img, 22, y, wood_color)

	# String (white)
	var string_color = Color(0.9, 0.9, 0.9)
	for y in range(8, 24):
		_draw_pixel(img, 20, y, string_color)

	# Arrow (gray/brown)
	_draw_pixel(img, 12, 15, Color(0.7, 0.5, 0.3))
	_draw_pixel(img, 13, 15, Color(0.7, 0.5, 0.3))
	_draw_pixel(img, 14, 15, Color(0.7, 0.5, 0.3))
	_draw_pixel(img, 15, 15, Color(0.7, 0.5, 0.3))
	_draw_pixel(img, 16, 15, Color(0.7, 0.5, 0.3))
	# Arrow head
	_draw_pixel(img, 11, 15, Color(0.6, 0.6, 0.7))
	_draw_pixel(img, 10, 14, Color(0.6, 0.6, 0.7))
	_draw_pixel(img, 10, 16, Color(0.6, 0.6, 0.7))

	return img

static func create_potion_icon() -> Image:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Bottle outline (dark gray)
	var glass_color = Color(0.7, 0.7, 0.8, 0.8)
	# Neck
	for y in range(8, 12):
		_draw_pixel(img, 14, y, glass_color)
		_draw_pixel(img, 15, y, glass_color)
		_draw_pixel(img, 16, y, glass_color)

	# Body
	for y in range(12, 24):
		_draw_pixel(img, 12, y, glass_color)
		_draw_pixel(img, 13, y, glass_color)
		_draw_pixel(img, 14, y, glass_color)
		_draw_pixel(img, 15, y, glass_color)
		_draw_pixel(img, 16, y, glass_color)
		_draw_pixel(img, 17, y, glass_color)
		_draw_pixel(img, 18, y, glass_color)

	# Liquid (red for health potion)
	var liquid_color = Color(0.9, 0.2, 0.2, 0.9)
	for y in range(14, 22):
		_draw_pixel(img, 13, y, liquid_color)
		_draw_pixel(img, 14, y, liquid_color)
		_draw_pixel(img, 15, y, liquid_color)
		_draw_pixel(img, 16, y, liquid_color)
		_draw_pixel(img, 17, y, liquid_color)

	# Cork (brown)
	var cork_color = Color(0.5, 0.3, 0.2)
	_draw_pixel(img, 14, 6, cork_color)
	_draw_pixel(img, 15, 6, cork_color)
	_draw_pixel(img, 16, 6, cork_color)
	_draw_pixel(img, 14, 7, cork_color)
	_draw_pixel(img, 15, 7, cork_color)
	_draw_pixel(img, 16, 7, cork_color)

	return img

static func create_armor_icon() -> Image:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Armor (steel gray)
	var armor_color = Color(0.6, 0.6, 0.7)

	# Chest plate
	for y in range(10, 22):
		for x in range(10, 22):
			_draw_pixel(img, x, y, armor_color)

	# Shoulder plates
	_draw_pixel(img, 8, 10, armor_color)
	_draw_pixel(img, 9, 10, armor_color)
	_draw_pixel(img, 8, 11, armor_color)
	_draw_pixel(img, 23, 10, armor_color)
	_draw_pixel(img, 22, 10, armor_color)
	_draw_pixel(img, 23, 11, armor_color)

	# Highlight (lighter)
	var highlight_color = Color(0.8, 0.8, 0.9)
	for y in range(11, 20):
		_draw_pixel(img, 11, y, highlight_color)
		_draw_pixel(img, 12, y, highlight_color)

	return img

static func create_shield_icon() -> Image:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Shield (blue/silver)
	var shield_color = Color(0.3, 0.4, 0.7)
	var metal_color = Color(0.7, 0.7, 0.8)

	# Shield body
	for y in range(6, 26):
		var width = 8 - abs(y - 16) / 3
		for x in range(int(16 - width), int(16 + width)):
			_draw_pixel(img, x, y, shield_color)

	# Metal rim
	for y in range(6, 26):
		var width = 8 - abs(y - 16) / 3
		_draw_pixel(img, int(16 - width), y, metal_color)
		_draw_pixel(img, int(16 + width - 1), y, metal_color)

	# Boss (center metal piece)
	_draw_pixel(img, 15, 15, metal_color)
	_draw_pixel(img, 16, 15, metal_color)
	_draw_pixel(img, 15, 16, metal_color)
	_draw_pixel(img, 16, 16, metal_color)

	return img

static func create_material_icon() -> Image:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Ore/Crystal (yellow-orange)
	var ore_color = Color(0.8, 0.6, 0.2)
	var highlight = Color(1.0, 0.8, 0.4)

	# Irregular crystal shape
	_draw_pixel(img, 16, 8, ore_color)
	_draw_pixel(img, 15, 9, ore_color)
	_draw_pixel(img, 16, 9, ore_color)
	_draw_pixel(img, 17, 9, ore_color)
	for x in range(14, 19):
		_draw_pixel(img, x, 10, ore_color)
	for x in range(13, 20):
		_draw_pixel(img, x, 11, ore_color)
	for y in range(12, 20):
		for x in range(12, 21):
			_draw_pixel(img, x, y, ore_color)
	for x in range(13, 20):
		_draw_pixel(img, x, 20, ore_color)
	for x in range(14, 19):
		_draw_pixel(img, x, 21, ore_color)

	# Highlights
	_draw_pixel(img, 14, 12, highlight)
	_draw_pixel(img, 15, 12, highlight)
	_draw_pixel(img, 14, 13, highlight)

	return img

static func _draw_pixel(img: Image, x: int, y: int, color: Color):
	"""Draw a single pixel (actually a 1x1 block)"""
	if x >= 0 and x < ICON_SIZE and y >= 0 and y < ICON_SIZE:
		img.set_pixel(x, y, color)

static func generate_all_icons():
	"""Generate all item icons and save to disk"""
	print("[IconGen] Generating item icons...")

	var icons = {
		"sword": create_sword_icon(),
		"bow": create_bow_icon(),
		"potion": create_potion_icon(),
		"armor": create_armor_icon(),
		"shield": create_shield_icon(),
		"material": create_material_icon()
	}

	for icon_name in icons:
		var img: Image = icons[icon_name]
		var path = "res://assets/icons/items/%s.png" % icon_name
		var err = img.save_png(path)
		if err == OK:
			print("[IconGen] Saved: ", path)
		else:
			print("[IconGen] ERROR saving ", icon_name, ": ", err)

	print("[IconGen] Icon generation complete!")
