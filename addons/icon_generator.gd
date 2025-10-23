@tool
extends EditorScript

## Run this from Godot Editor: File menu -> Run (or Ctrl+Shift+X)
## Or: Select this script and click "Run" button in script editor

const ICON_SIZE = 64

func _run():
	print("="*50)
	print("[ICON GENERATOR] Starting...")

	# Create directory
	DirAccess.make_dir_recursive_absolute("res://assets/icons/items")

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

	var count = 0
	for item_id in items_colors:
		var color = items_colors[item_id]
		var img = create_simple_icon(color)
		var path = "res://assets/icons/items/%s.png" % item_id

		var err = img.save_png(path)
		if err == OK:
			print("[✓] Created: %s.png" % item_id)
			count += 1
		else:
			print("[✗] ERROR creating %s: %d" % [item_id, err])

	print("[ICON GENERATOR] Complete! Generated %d icons" % count)
	print("[IMPORTANT] Reload the project to see the icons:")
	print("  Project -> Reload Current Project")
	print("="*50)


func create_simple_icon(base_color: Color) -> Image:
	"""Create a simple colored square with border"""
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
