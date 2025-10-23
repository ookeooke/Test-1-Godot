@tool
extends EditorScript

## Simple Icon Generator - Creates clear, readable colored icons for items
## Run this from Godot Editor: Script menu -> Run

const ICON_SIZE = 64
const BORDER_SIZE = 4

static func create_colored_icon(bg_color: Color, text: String, text_color: Color = Color.WHITE) -> Image:
	"""Create a simple colored rectangle with text"""
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)

	# Fill background
	img.fill(bg_color)

	# Draw border (darker shade)
	var border_color = bg_color.darkened(0.3)
	# Top border
	for y in range(BORDER_SIZE):
		for x in range(ICON_SIZE):
			img.set_pixel(x, y, border_color)
	# Bottom border
	for y in range(ICON_SIZE - BORDER_SIZE, ICON_SIZE):
		for x in range(ICON_SIZE):
			img.set_pixel(x, y, border_color)
	# Left border
	for x in range(BORDER_SIZE):
		for y in range(ICON_SIZE):
			img.set_pixel(x, y, border_color)
	# Right border
	for x in range(ICON_SIZE - BORDER_SIZE, ICON_SIZE):
		for y in range(ICON_SIZE):
			img.set_pixel(x, y, border_color)

	return img


static func create_weapon_icon(weapon_name: String) -> Image:
	"""Red background for weapons"""
	return create_colored_icon(Color(0.8, 0.2, 0.2), "W", Color.WHITE)


static func create_armor_icon(armor_name: String) -> Image:
	"""Blue background for armor"""
	return create_colored_icon(Color(0.2, 0.4, 0.8), "A", Color.WHITE)


static func create_accessory_icon(accessory_name: String) -> Image:
	"""Purple background for accessories"""
	return create_colored_icon(Color(0.6, 0.3, 0.8), "ACC", Color.WHITE)


static func create_potion_icon(potion_name: String) -> Image:
	"""Green background for potions"""
	if "health" in potion_name.to_lower():
		return create_colored_icon(Color(0.2, 0.8, 0.3), "HP", Color.WHITE)
	else:
		return create_colored_icon(Color(0.9, 0.6, 0.2), "STR", Color.WHITE)


static func create_material_icon(material_name: String) -> Image:
	"""Orange/brown background for materials"""
	if "dragon" in material_name.to_lower():
		return create_colored_icon(Color(0.9, 0.5, 0.1), "DS", Color.WHITE)
	elif "iron" in material_name.to_lower():
		return create_colored_icon(Color(0.5, 0.5, 0.5), "IR", Color.WHITE)
	else:
		return create_colored_icon(Color(0.4, 0.7, 0.9), "ME", Color.WHITE)


func _run():
	"""Run this from Godot Editor to generate all icons"""
	print("[SimpleIconGen] Starting icon generation...")

	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")
	dir = DirAccess.open("res://assets")
	if not dir.dir_exists("icons"):
		dir.make_dir("icons")
	dir = DirAccess.open("res://assets/icons")
	if not dir.dir_exists("items"):
		dir.make_dir("items")

	# Define all items to generate
	var items_to_generate = {
		# Weapons
		"basic_bow": {"type": "weapon", "name": "Basic Bow"},
		"fire_bow": {"type": "weapon", "name": "Fire Bow"},
		"elven_longbow": {"type": "weapon", "name": "Elven Longbow"},

		# Armor
		"leather_vest": {"type": "armor", "name": "Leather Vest"},

		# Accessories
		"power_ring": {"type": "accessory", "name": "Power Ring"},

		# Consumables
		"health_potion": {"type": "potion", "name": "Health Potion"},
		"damage_buff_potion": {"type": "potion", "name": "Strength Elixir"},

		# Materials
		"dragon_scale": {"type": "material", "name": "Dragon Scale"},
		"iron_ore": {"type": "material", "name": "Iron Ore"},
		"magic_essence": {"type": "material", "name": "Magic Essence"}
	}

	var success_count = 0
	var fail_count = 0

	for item_id in items_to_generate:
		var item_info = items_to_generate[item_id]
		var img: Image = null

		match item_info.type:
			"weapon":
				img = create_weapon_icon(item_info.name)
			"armor":
				img = create_armor_icon(item_info.name)
			"accessory":
				img = create_accessory_icon(item_info.name)
			"potion":
				img = create_potion_icon(item_info.name)
			"material":
				img = create_material_icon(item_info.name)

		if img:
			var path = "res://assets/icons/items/%s.png" % item_id
			var err = img.save_png(path)
			if err == OK:
				print("[SimpleIconGen] ✓ Created: %s" % path)
				success_count += 1
			else:
				print("[SimpleIconGen] ✗ ERROR saving %s: %s" % [item_id, err])
				fail_count += 1

	print("[SimpleIconGen] Generation complete! Success: %d, Failed: %d" % [success_count, fail_count])
	print("[SimpleIconGen] IMPORTANT: Click 'Project -> Reload Current Project' or restart Godot to see the new icons!")
