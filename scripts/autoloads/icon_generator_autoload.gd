extends Node

## Auto Icon Generator - Runs BEFORE ItemDatabase loads
## Creates ImageTextures dynamically and assigns them to items at runtime

const ICON_SIZE = 64
var icon_cache: Dictionary = {}  # {item_id: ImageTexture}

func _ready():
	# Generate icons BEFORE ItemDatabase loads
	generate_all_icons()

	# Wait for ItemDatabase to load, then assign icons
	if ItemDatabase.items_loaded.is_connected(_assign_icons_to_items):
		ItemDatabase.items_loaded.connect(_assign_icons_to_items)
	else:
		# If ItemDatabase already loaded, assign now
		call_deferred("_assign_icons_to_items")


func generate_all_icons():
	print("[AutoIconGen] Generating item icon textures...")

	var items_colors = {
		"basic_bow": Color(0.78, 0.20, 0.20),          # Red
		"fire_bow": Color(0.90, 0.31, 0.12),           # Orange-red
		"elven_longbow": Color(0.59, 0.78, 0.31),      # Green
		"leather_vest": Color(0.59, 0.39, 0.20),       # Brown
		"power_ring": Color(0.59, 0.31, 0.78),         # Purple
		"health_potion": Color(0.78, 0.20, 0.31),      # Red
		"damage_buff_potion": Color(0.90, 0.59, 0.20), # Orange
		"dragon_scale": Color(0.90, 0.51, 0.12),       # Orange
		"iron_ore": Color(0.51, 0.51, 0.51),           # Gray
		"magic_essence": Color(0.39, 0.71, 0.90)       # Cyan
	}

	for item_id in items_colors:
		var color = items_colors[item_id]
		var img = create_simple_icon(color)
		var texture = ImageTexture.create_from_image(img)
		icon_cache[item_id] = texture

	print("[AutoIconGen] Generated %d icon textures!" % icon_cache.size())


func _assign_icons_to_items():
	"""Assign generated textures to ItemData resources (only if no icon already exists)"""
	print("[AutoIconGen] Assigning icons to items...")

	var assigned = 0
	for item_id in icon_cache:
		if ItemDatabase.has_item(item_id):
			var item_data = ItemDatabase.get_item(item_id)
			if item_data:
				# Only assign if item doesn't already have an icon (respects PNG icons from .tres files)
				if item_data.icon == null:
					item_data.icon = icon_cache[item_id]
					assigned += 1
				else:
					print("[AutoIconGen] Skipping '%s' - already has icon texture" % item_id)

	print("[AutoIconGen] Assigned %d icons to items!" % assigned)


func create_simple_icon(base_color: Color) -> Image:
	"""Create a simple colored square with darker border"""
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)

	var border_color = base_color.darkened(0.4)
	var border_size = 6

	# Fill with base color
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			img.set_pixel(x, y, base_color)

	# Draw border
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			if x < border_size or x >= ICON_SIZE - border_size or y < border_size or y >= ICON_SIZE - border_size:
				img.set_pixel(x, y, border_color)

	return img
