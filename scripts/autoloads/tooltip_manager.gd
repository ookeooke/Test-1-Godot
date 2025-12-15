## ============================================================================
## TooltipManager.gd
## ============================================================================
## Centralized manager for advanced item tooltips with stat comparison.
##
## Features:
## - Single tooltip instance (efficient, no per-item overhead)
## - Smart positioning (keeps tooltip on screen)
## - Desktop: Show on hover, hide on exit
## - Mobile: Show on tap, hide on click-outside
## - Stat comparison with equipped items (green/red arrows)
##
## Architecture:
## - Manages single ItemTooltip instance
## - Integrates with HeroEquipmentRegistry for comparison
## - Handles cross-platform input (mouse + touch)
##
## Usage:
##   TooltipManager.show_tooltip(item_instance, anchor_node, hero_id)
##   TooltipManager.hide_tooltip()
## ============================================================================

extends CanvasLayer

## Reference to the item tooltip instance
var _tooltip_instance: Control = null

## Reference to the skill tooltip instance
var _skill_tooltip_instance: Control = null

## Currently displayed item (for click-outside detection)
var _current_item: ItemInstance = null

## Currently displayed skill (for click-outside detection)
var _current_skill: HeroSkillData = null

## Node that triggered tooltip (for positioning)
var _anchor_node: Control = null

## Hero ID for equipment comparison
var _current_hero_id: String = ""

## Tooltip visibility state
var _is_visible: bool = false

## Margin from screen edges (px)
const SCREEN_MARGIN: int = 16

## Offset from anchor node (px)
const ANCHOR_OFFSET: Vector2 = Vector2(20, 20)

## Hover delay before showing tooltip (industry standard: 100-200ms)
const HOVER_DELAY: float = 0.15 # 150ms - prevents tooltip flicker during rapid mouse scanning

## Timer for hover delay
var _hover_timer: SceneTreeTimer = null

## Cancellation token - incremented each show_tooltip() call to cancel outdated async operations
var _show_request_id: int = 0


func _ready() -> void:
	# Set as top layer for tooltips (above all modal screens)
	layer = 101

	# Ensure tooltips still work when the game tree is paused (e.g., victory/loot screens)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Load item tooltip scene
	var tooltip_scene = preload("res://scenes/ui/tooltips/item_tooltip.tscn")
	_tooltip_instance = tooltip_scene.instantiate()
	_tooltip_instance.visible = false
	add_child(_tooltip_instance)

	# Load skill tooltip scene
	var skill_tooltip_scene = preload("res://scenes/ui/tooltips/skill_tooltip.tscn")
	_skill_tooltip_instance = skill_tooltip_scene.instantiate()
	_skill_tooltip_instance.visible = false
	add_child(_skill_tooltip_instance)

	# Connect input for click-outside detection
	set_process_input(true)


func _unhandled_input(event: InputEvent) -> void:
	# Use _unhandled_input() instead of _input() to allow GUI controls
	# (like EquipmentSlot drag-drop) to handle events first
	# This follows the project's 4-stage input system (see INPUT_SYSTEM.md)
	if not _is_visible:
		return

	# Click-outside to close (both mouse and touch)
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_check_click_outside(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_check_click_outside(event.position)


func _check_click_outside(click_pos: Vector2) -> void:
	"""Check if click is outside tooltip bounds, hide if so."""
	if not _tooltip_instance or not _anchor_node:
		return

	var tooltip_rect = Rect2(
		_tooltip_instance.global_position,
		_tooltip_instance.size
	)

	# Check if click is on the anchor node (the item itself)
	# Don't hide tooltip when clicking on the item to start dragging
	if is_instance_valid(_anchor_node) and _anchor_node.is_inside_tree():
		var anchor_rect = Rect2(
			_anchor_node.global_position,
			_anchor_node.size
		)
		if anchor_rect.has_point(click_pos):
			# Click is on the item itself - don't hide tooltip (allow drag to start)
			return

	# If click is outside both tooltip and anchor, hide it
	if not tooltip_rect.has_point(click_pos):
		hide_tooltip()
		# Don't consume the event - allow it to propagate for drag-drop
		# and other interactions with items below the tooltip


## ============================================================================
## PUBLIC API
## ============================================================================

func show_tooltip(data: Variant, anchor_node: Control, hero_id: String = "") -> void:
	"""
	Show tooltip for an item or skill.

	Args:
	    data: The data to display (ItemInstance or HeroSkillData)
	    anchor_node: Control node to position tooltip near
	    hero_id: Hero ID for equipment comparison (empty = no comparison)
	"""
	# Detect type and delegate to appropriate handler
	if data is ItemInstance:
		_show_item_tooltip(data, anchor_node, hero_id)
	elif data is HeroSkillData:
		_show_skill_tooltip(data, anchor_node, hero_id)
	else:
		push_warning("TooltipManager: Invalid data type: %s" % str(data))


func _show_item_tooltip(item: ItemInstance, anchor_node: Control, hero_id: String = "") -> void:
	"""
	Show tooltip for an item with optional comparison to equipped item.

	Args:
	    item: The item to display
	    anchor_node: Control node to position tooltip near
	    hero_id: Hero ID for equipment comparison (empty = no comparison)
	"""
	# Validate inputs
	if not item or not anchor_node:
		push_warning("TooltipManager: Invalid item or anchor_node")
		return

	# Validate anchor node is in scene tree and visible
	if not anchor_node.is_inside_tree() or not anchor_node.visible:
		return

	# Increment request ID to cancel any previous async show operations
	_show_request_id += 1
	var my_request_id = _show_request_id

	# Cancel any existing hover timer (just discard reference, SceneTreeTimer will auto-complete)
	_hover_timer = null

	# Hide existing tooltip if showing (prevents competing tooltips)
	if _is_visible:
		hide_tooltip()

	# Apply hover delay to prevent tooltip flicker during rapid mouse scanning
	# NOTE: When the game tree is paused (victory/loot screens), SceneTreeTimers
	#       will never time out. Skip the delay so tooltips still appear.
	if get_tree().paused:
		_hover_timer = null
	else:
		_hover_timer = get_tree().create_timer(HOVER_DELAY)
		await _hover_timer.timeout
		_hover_timer = null

	# Check if this request was cancelled by a newer show_tooltip() call or hide_tooltip()
	if _show_request_id != my_request_id:
		return # Cancelled - don't show tooltip

	# Revalidate anchor is still valid after delay (user might have moved mouse)
	if not is_instance_valid(anchor_node) or not anchor_node.is_inside_tree():
		return

	# Check if mouse is still over the anchor node (prevents showing after mouse exits)
	var mouse_pos = anchor_node.get_local_mouse_position()
	var anchor_rect = Rect2(Vector2.ZERO, anchor_node.size)
	if not anchor_rect.has_point(mouse_pos):
		return # Mouse has moved away - don't show tooltip

	_current_item = item
	_anchor_node = anchor_node
	_current_hero_id = hero_id

	# Get equipped item for comparison (if hero_id provided)
	var equipped_item: ItemInstance = null
	if hero_id != "":
		var item_data = item.get_data()
		if item_data.equip_slot != ItemData.EquipSlot.NONE:
			# Get equipped item in same slot
			var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
			if equipped_items.has("equipped_items"):
				var slot_name = _get_slot_name_from_enum(item_data.equip_slot)
				if equipped_items.equipped_items.has(slot_name):
					equipped_item = equipped_items.equipped_items[slot_name]

	# Populate tooltip with item data
	if _tooltip_instance.has_method("set_item"):
		_tooltip_instance.set_item(item, equipped_item)

	# Position tooltip (await to prevent race condition)
	await _position_tooltip(_tooltip_instance)

	# Final cancellation check after positioning (in case hide was called during positioning)
	if _show_request_id != my_request_id:
		return # Cancelled - don't show tooltip

	# Show with fade-in
	_tooltip_instance.visible = true
	_tooltip_instance.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(_tooltip_instance, "modulate:a", 1.0, 0.15)

	_is_visible = true


func _show_skill_tooltip(skill_data: HeroSkillData, anchor_node: Control, hero_id: String = "") -> void:
	"""
	Show tooltip for a skill.

	Args:
	    skill_data: The skill to display
	    anchor_node: Control node to position tooltip near
	    hero_id: Hero ID for skill level/unlock status (empty = show base level)
	"""
	# Validate inputs
	if not skill_data or not anchor_node:
		push_warning("TooltipManager: Invalid skill_data or anchor_node")
		return

	# Validate anchor node is in scene tree and visible
	if not anchor_node.is_inside_tree() or not anchor_node.visible:
		return

	# Increment request ID to cancel any previous async show operations
	_show_request_id += 1
	var my_request_id = _show_request_id

	# Cancel any existing hover timer
	_hover_timer = null

	# Hide existing tooltip if showing (prevents competing tooltips)
	if _is_visible:
		hide_tooltip()

	# Apply hover delay to prevent tooltip flicker during rapid mouse scanning
	# NOTE: When the game tree is paused (victory/loot screens), SceneTreeTimers
	#       will never time out. Skip the delay so tooltips still appear.
	if get_tree().paused:
		_hover_timer = null
	else:
		_hover_timer = get_tree().create_timer(HOVER_DELAY)
		await _hover_timer.timeout
		_hover_timer = null

	# Check if this request was cancelled by a newer show_tooltip() call or hide_tooltip()
	if _show_request_id != my_request_id:
		return # Cancelled - don't show tooltip

	# Revalidate anchor is still valid after delay (user might have moved mouse)
	if not is_instance_valid(anchor_node) or not anchor_node.is_inside_tree():
		return

	# Check if mouse is still over the anchor node (prevents showing after mouse exits)
	var mouse_pos = anchor_node.get_local_mouse_position()
	var anchor_rect = Rect2(Vector2.ZERO, anchor_node.size)
	if not anchor_rect.has_point(mouse_pos):
		return # Mouse has moved away - don't show tooltip

	_current_skill = skill_data
	_anchor_node = anchor_node
	_current_hero_id = hero_id

	# Get skill level and unlock status from SaveManager
	var progression = _get_skill_progression(hero_id, skill_data)
	var skill_level = progression.level
	var is_unlocked = progression.is_unlocked

	# Populate tooltip with skill data
	if _skill_tooltip_instance.has_method("set_skill"):
		_skill_tooltip_instance.set_skill(skill_data, skill_level, is_unlocked)

	# Position tooltip (await to prevent race condition)
	await _position_tooltip(_skill_tooltip_instance)

	# Final cancellation check after positioning (in case hide was called during positioning)
	if _show_request_id != my_request_id:
		return # Cancelled - don't show tooltip

	# Show with fade-in
	_skill_tooltip_instance.visible = true
	_skill_tooltip_instance.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()
	tween.tween_property(_skill_tooltip_instance, "modulate:a", 1.0, 0.15)

	_is_visible = true


func hide_tooltip() -> void:
	"""Hide all tooltips with fade-out animation."""
	if not _is_visible:
		return

	# Increment request ID to cancel any pending show_tooltip() async operations
	_show_request_id += 1

	_is_visible = false

	# Fade out item tooltip
	if _tooltip_instance.visible:
		var tween = create_tween()
		tween.tween_property(_tooltip_instance, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			_tooltip_instance.visible = false
		)

	# Fade out skill tooltip
	if _skill_tooltip_instance.visible:
		var tween = create_tween()
		tween.tween_property(_skill_tooltip_instance, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			_skill_tooltip_instance.visible = false
		)

	# Clear state
	_current_item = null
	_current_skill = null
	_anchor_node = null
	_current_hero_id = ""


func is_tooltip_visible() -> bool:
	"""Check if tooltip is currently visible."""
	return _is_visible


## ============================================================================
## POSITIONING
## ============================================================================

func _position_tooltip(tooltip_instance: Control) -> void:
	"""Position tooltip near anchor node, keeping it on screen."""
	if not _anchor_node or not tooltip_instance:
		return

	# Wait for tooltip to calculate its size
	await get_tree().process_frame

	# Get anchor position in screen space
	var anchor_global_pos = _anchor_node.global_position
	var anchor_size = _anchor_node.size

	# Default position: bottom-right of anchor
	var tooltip_pos = anchor_global_pos + Vector2(anchor_size.x, 0) + ANCHOR_OFFSET

	# Get screen bounds
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = tooltip_instance.size

	# Adjust X if tooltip would overflow right edge
	if tooltip_pos.x + tooltip_size.x > screen_size.x - SCREEN_MARGIN:
		# Try left side of anchor
		tooltip_pos.x = anchor_global_pos.x - tooltip_size.x - ANCHOR_OFFSET.x

		# If still overflows, clamp to screen
		if tooltip_pos.x < SCREEN_MARGIN:
			tooltip_pos.x = SCREEN_MARGIN

	# Adjust Y if tooltip would overflow bottom edge
	if tooltip_pos.y + tooltip_size.y > screen_size.y - SCREEN_MARGIN:
		# Position above anchor instead
		tooltip_pos.y = anchor_global_pos.y - tooltip_size.y - ANCHOR_OFFSET.y

		# If still overflows top, clamp to screen
		if tooltip_pos.y < SCREEN_MARGIN:
			tooltip_pos.y = SCREEN_MARGIN

	# Apply final position
	tooltip_instance.global_position = tooltip_pos


## ============================================================================
## HELPERS
## ============================================================================

func _get_slot_name_from_enum(equip_slot: ItemData.EquipSlot) -> String:
	"""Convert EquipSlot enum to string name used by HeroEquipmentRegistry."""
	match equip_slot:
		ItemData.EquipSlot.WEAPON:
			return "weapon"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY:
			return "accessory"
		ItemData.EquipSlot.HELMET:
			return "helmet"
		_:
			return ""


## ============================================================================
## SKILL PROGRESSION HELPERS
## ============================================================================

func _get_skill_progression(hero_id: String, skill_data: HeroSkillData) -> Dictionary:
	"""
	Get skill level and unlock status for a hero.

	Returns: {level: int, is_unlocked: bool}
	- level: Current skill level (0 = not owned)
	- is_unlocked: Whether hero has unlocked this skill
	"""
	if hero_id.is_empty() or not skill_data:
		return {"level": 1, "is_unlocked": true} # Default for preview mode

	# Integration point - ready for SaveManager
	if SaveManager:
		var skill_id = skill_data.skill_id
		var level = SaveManager.get_hero_skill_level(hero_id, skill_id)
		var is_unlocked = SaveManager.has_hero_skill(hero_id, skill_id)

		# Return actual progression data
		return {"level": max(1, level), "is_unlocked": is_unlocked}
	else:
		# Fallback if SaveManager not available (shouldn't happen)
		push_warning("[TooltipManager] SaveManager not found - using defaults")
		return {"level": 1, "is_unlocked": true}
