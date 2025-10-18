extends Node2D
class_name LevelNode2D

# LevelNode2D - Kingdom Rush style animated level button (Node2D version)
# Much easier to position in the editor - just drag it around!

signal level_selected(level_data: LevelNodeData)

@export var level_data: LevelNodeData

# Node references
@onready var button_area: Area2D = $ButtonArea
@onready var collision_shape: CollisionShape2D = $ButtonArea/CollisionShape2D
@onready var button_sprite: ColorRect = $ButtonSprite
@onready var stars_container: Node2D = $StarsContainer
@onready var star_1: Sprite2D = $StarsContainer/Star1
@onready var star_2: Sprite2D = $StarsContainer/Star2
@onready var star_3: Sprite2D = $StarsContainer/Star3
@onready var lock_icon: Sprite2D = $LockIcon
@onready var glow_sprite: ColorRect = $GlowSprite
@onready var label: Label = $Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# State
var is_unlocked: bool = false
var earned_stars: int = 0
var is_hovered: bool = false
var is_pressed: bool = false

func _ready():
	# Connect input signals
	if button_area:
		button_area.input_event.connect(_on_area_input_event)
		button_area.mouse_entered.connect(_on_mouse_entered)
		button_area.mouse_exited.connect(_on_mouse_exited)
		print("✅ LevelNode2D: Signals connected for button_area | input_pickable: ", button_area.input_pickable)
		print("   🎯 POSITION DEBUG: global_position will be set later in update_display()")
	else:
		print("❌ LevelNode2D: button_area is NULL!")

	# Setup animations
	_setup_animations()

	# Update visual state
	if level_data:
		update_display()

func _setup_animations():
	# Create animations if AnimationPlayer doesn't have them
	if not animation_player:
		return

	# Get or create animation library
	var anim_library: AnimationLibrary
	if animation_player.has_animation_library(""):
		anim_library = animation_player.get_animation_library("")
	else:
		anim_library = AnimationLibrary.new()
		animation_player.add_animation_library("", anim_library)

	# Setup bounce animation
	if not anim_library.has_animation("bounce"):
		var bounce_anim = Animation.new()
		var track_index = bounce_anim.add_track(Animation.TYPE_VALUE)
		bounce_anim.track_set_path(track_index, ".:position:y")
		bounce_anim.length = 2.0
		bounce_anim.loop_mode = Animation.LOOP_LINEAR

		var base_y = position.y

		# Keyframes for bounce
		bounce_anim.track_insert_key(track_index, 0.0, base_y)
		bounce_anim.track_insert_key(track_index, 1.0, base_y - 10.0)
		bounce_anim.track_insert_key(track_index, 2.0, base_y)

		anim_library.add_animation("bounce", bounce_anim)

	# Setup glow pulse animation
	if not anim_library.has_animation("glow_pulse") and glow_sprite:
		var glow_anim = Animation.new()
		var glow_track = glow_anim.add_track(Animation.TYPE_VALUE)
		glow_anim.track_set_path(glow_track, "GlowSprite:modulate:a")
		glow_anim.length = 1.5
		glow_anim.loop_mode = Animation.LOOP_LINEAR

		glow_anim.track_insert_key(glow_track, 0.0, 0.3)
		glow_anim.track_insert_key(glow_track, 0.75, 0.7)
		glow_anim.track_insert_key(glow_track, 1.5, 0.3)

		anim_library.add_animation("glow_pulse", glow_anim)

func update_display():
	if not level_data:
		return

	# Check if level is unlocked
	is_unlocked = _check_unlock_status()

	# Get stars earned
	earned_stars = SaveManager.get_level_stars(level_data.level_id)

	# Update label
	if label:
		label.text = level_data.level_name

	# Update button sprite state
	if button_sprite:
		if is_unlocked:
			button_sprite.color = Color(0.4, 0.3, 0.2, 1.0)  # Brown button
		else:
			button_sprite.color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray (locked)

	# Update lock icon
	if lock_icon:
		lock_icon.visible = not is_unlocked

	# Update stars
	_update_stars()

	# DEBUG: Print actual position
	print("   🎯 ", level_data.level_name, " at global_position: ", global_position)
	print("      Clickable area: X(", global_position.x - 50, " to ", global_position.x + 50, ") Y(", global_position.y - 50, " to ", global_position.y + 50, ")")

	# Start animations if unlocked
	if is_unlocked and animation_player:
		# Gentle bounce for unlocked levels
		animation_player.play("bounce")

		# Glow effect if not yet completed
		if earned_stars == 0:
			if glow_sprite:
				glow_sprite.visible = true
			animation_player.play("glow_pulse")
		else:
			if glow_sprite:
				glow_sprite.visible = false
	else:
		if animation_player:
			animation_player.stop()
		if glow_sprite:
			glow_sprite.visible = false

func _check_unlock_status() -> bool:
	if not level_data:
		print("LevelNode2D: No level_data, locked")
		return false

	# First level is always unlocked
	if level_data.required_level_id.is_empty():
		print("LevelNode2D: ", level_data.level_name, " is first level, unlocked")
		return true

	# Check if required level is completed
	if not SaveManager.is_level_completed(level_data.required_level_id):
		print("LevelNode2D: ", level_data.level_name, " locked - required level not completed: ", level_data.required_level_id)
		return false

	# Check star requirements
	if level_data.required_stars > 0:
		var total_stars = _get_total_stars_earned()
		print("LevelNode2D: ", level_data.level_name, " checking stars - need ", level_data.required_stars, " have ", total_stars)
		return total_stars >= level_data.required_stars

	print("LevelNode2D: ", level_data.level_name, " unlocked (required level completed)")
	return true

func _get_total_stars_earned() -> int:
	var total = 0
	# Sum all stars from all completed levels
	if not level_data.required_level_id.is_empty():
		total = SaveManager.get_level_stars(level_data.required_level_id)
	return total

func _update_stars():
	if not stars_container:
		return

	# Update star sprites
	if star_1:
		star_1.modulate = Color(1.0, 0.9, 0.0, 1.0) if earned_stars >= 1 else Color(0.3, 0.3, 0.3, 1.0)
	if star_2:
		star_2.modulate = Color(1.0, 0.9, 0.0, 1.0) if earned_stars >= 2 else Color(0.3, 0.3, 0.3, 1.0)
	if star_3:
		star_3.modulate = Color(1.0, 0.9, 0.0, 1.0) if earned_stars >= 3 else Color(0.3, 0.3, 0.3, 1.0)

	# Hide stars if locked
	stars_container.visible = is_unlocked

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	print("🔵 Area2D received event: ", event.get_class(), " | Level: ", level_data.level_name if level_data else "NO DATA", " | Unlocked: ", is_unlocked)

	if not is_unlocked:
		print("  ❌ Level locked, ignoring")
		return

	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		print("  🖱️ Mouse button event - Button: ", mouse_event.button_index, " Pressed: ", mouse_event.pressed)
		# Respond to PRESS - Area2D.input_event fires before _unhandled_input
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			print("  ✅ LEFT CLICK DETECTED on ", level_data.level_name)
			_on_clicked()
			# Mark as handled so ClickManager doesn't also process it
			_viewport.set_input_as_handled()

func _on_clicked():
	if is_unlocked and level_data:
		print("LevelNode2D: Emitting level_selected signal for ", level_data.level_name)
		level_selected.emit(level_data)
	else:
		print("LevelNode2D: Cannot emit signal - unlocked: ", is_unlocked, " level_data: ", level_data != null)

func _on_mouse_entered():
	is_hovered = true
	if is_unlocked and button_sprite:
		# Scale up on hover
		var tween = create_tween()
		tween.tween_property(button_sprite, "scale", Vector2(1.1, 1.1), 0.2)

func _on_mouse_exited():
	is_hovered = false
	is_pressed = false
	if button_sprite:
		# Scale back to normal
		var tween = create_tween()
		tween.tween_property(button_sprite, "scale", Vector2(1.0, 1.0), 0.2)

func set_level_data(data: LevelNodeData):
	level_data = data
	if is_node_ready():
		update_display()
