extends Control

##
## XP Bar - Hero Experience Display
##
## Kingdom Rush-style XP bar positioned below health bar
## Shows current XP progress toward next level (0-100%)
## Gold fill with smooth animation on XP gain
##

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var level_label: Label = $LevelLabel

# Bar dimensions
const BAR_WIDTH = 50
const BAR_HEIGHT = 5  # 1px thinner than health bar

# Animation
var fill_tween: Tween = null

# Reference to hero
var hero: Node = null


func _ready():
	# Ensure proper size
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	# Center the bar above parent
	position = Vector2(-BAR_WIDTH / 2.0, -23)  # Below health bar (health is at -30)

	# Set z-index to render on top
	z_index = 100

	# Start at 0% (level 1, no XP)
	if fill:
		fill.size.x = 0


func setup(hero_node: Node):
	"""Connect to hero and progression manager"""
	hero = hero_node

	if not HeroProgressionManager:
		push_warning("[XPBar] HeroProgressionManager not available")
		return

	# Connect to XP gain signal
	HeroProgressionManager.hero_gained_xp.connect(_on_hero_gained_xp)
	HeroProgressionManager.hero_leveled_up.connect(_on_hero_leveled_up)

	# Initial update
	update_xp()
	update_level()


func _on_hero_gained_xp(gained_hero: Node, xp_amount: int):
	"""Called when any hero gains XP"""
	if gained_hero != hero:
		return  # Not our hero

	# Update XP bar with animation
	update_xp(true)


func _on_hero_leveled_up(leveled_hero: Node, new_level: int):
	"""Called when any hero levels up"""
	if leveled_hero != hero:
		return  # Not our hero

	# Update level display and reset XP bar
	update_level()
	update_xp(true)


func update_xp(animate: bool = false):
	"""Update XP bar fill based on current progress"""
	if not hero or not HeroProgressionManager:
		return

	# Get progress (0.0 to 1.0)
	var progress = HeroProgressionManager.get_level_progress(hero)
	var target_width = BAR_WIDTH * progress

	if not fill:
		return

	if animate:
		# Smooth animated fill
		if fill_tween:
			fill_tween.kill()

		fill_tween = create_tween()
		fill_tween.set_ease(Tween.EASE_OUT)
		fill_tween.set_trans(Tween.TRANS_CUBIC)
		fill_tween.tween_property(fill, "size:x", target_width, 0.3)

		# Optional: Pulse effect on XP gain
		_pulse_glow()
	else:
		# Instant update
		fill.size.x = target_width


func update_level():
	"""Update level label text"""
	if not hero or not HeroProgressionManager:
		return

	var level = HeroProgressionManager.get_hero_level(hero)

	if level_label:
		level_label.text = str(level)


func _pulse_glow():
	"""Quick gold pulse when gaining XP (visual feedback)"""
	if not fill:
		return

	# Create pulse tween
	var pulse = create_tween()
	pulse.set_ease(Tween.EASE_OUT)

	# Brighten then return to normal
	pulse.tween_property(fill, "modulate", Color(1.5, 1.5, 1.0), 0.1)  # Bright gold
	pulse.tween_property(fill, "modulate", Color(1.0, 1.0, 1.0), 0.2)  # Normal


func get_xp_info() -> String:
	"""Get XP info string for tooltips (e.g., '450 / 559 XP')"""
	if not hero or not HeroProgressionManager:
		return "XP: ???"

	var current_xp = HeroProgressionManager.get_hero_xp(hero)
	var required_xp = HeroProgressionManager.get_xp_to_next_level(hero)
	var level = HeroProgressionManager.get_hero_level(hero)

	if level >= 20:
		return "MAX LEVEL"

	return "%d / %d XP" % [current_xp, required_xp]


func _on_mouse_entered():
	"""Show tooltip on hover (optional)"""
	# Could show XP tooltip here if wanted
	pass
