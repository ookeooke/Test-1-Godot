extends Node2D

@onready var base_sprite = $BaseSprite
@onready var icon_label = $IconLabel

# Token Colors
const COLOR_TANK = Color(0.8, 0.2, 0.2) # Red
const COLOR_FAST = Color(0.9, 0.8, 0.1) # Yellow
const COLOR_MAGIC = Color(0.2, 0.4, 0.9) # Blue
const COLOR_BOSS = Color(0.5, 0.0, 0.5) # Purple

# Token Icons (Unicode characters work great as placeholders)
const ICON_SWORD = "⚔"
const ICON_SHIELD = "🛡"
const ICON_SKULL = "💀"
const ICON_LIGHTNING = "⚡"

func setup(enemy_type: String):
	"""Configure the token based on enemy type"""
	var color = Color.WHITE
	var icon = ""
	
	match enemy_type.to_lower():
		"orc", "tank":
			color = COLOR_TANK
			icon = ICON_SHIELD
		"wolf", "fast", "scout":
			color = COLOR_FAST
			icon = ICON_LIGHTNING
		"mage", "shaman":
			color = COLOR_MAGIC
			icon = ICON_SWORD
		"boss", "troll":
			color = COLOR_BOSS
			icon = ICON_SKULL
		_:
			color = Color.GRAY
			icon = "?"
	
	if base_sprite:
		base_sprite.modulate = color
	
	if icon_label:
		icon_label.text = icon
