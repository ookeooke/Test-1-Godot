extends PanelContainer
class_name SkillSlot

## ============================================
## SKILL SLOT - Drop target for equipped skills
## ============================================
##
## Represents a single skill slot in the loadout grid
## Handles drag-and-drop of skills with swap support
## Features real-time highlighting during drag (Phase 3)

# State
var slot_index: int = 0
var slot_type: String = "active" # "active" or "passive"
var hero_id: String = ""
var equipped_skill_id: String = "" # "" = empty, "fireball" = has skill

# Visual references
@onready var icon_layer: Control = $IconLayer
@onready var empty_label: Label = $EmptyLabel

var skill_icon = null # Will be SkillIcon instance when created

# Signals
signal skill_equipped(slot_index: int, skill_id: String)

# Real-time highlighting (Phase 3 - Hybrid System)
enum HighlightState {NONE, VALID, SWAP, INVALID}
var current_highlight_state: int = HighlightState.NONE
var is_dragging: bool = false


## ============================================
## INITIALIZATION
## ============================================

func setup(p_slot_index: int, p_slot_type: String, p_hero_id: String):
	"""Setup the slot with configuration"""
	slot_index = p_slot_index
	slot_type = p_slot_type
	hero_id = p_hero_id
	if is_node_ready():
		_refresh_display()

func _ready():
	_refresh_display()

## ============================================
## REAL-TIME HIGHLIGHTING (Phase 3)
## ============================================

func _notification(what: int):
	"""Track drag lifecycle for highlighting"""
	if what == NOTIFICATION_DRAG_BEGIN:
		is_dragging = true
	elif what == NOTIFICATION_DRAG_END:
		is_dragging = false
		current_highlight_state = HighlightState.NONE
		queue_redraw()

func _process(_delta: float):
	"""Update highlight state in real-time during drag"""
	if not is_dragging or not get_viewport().gui_is_dragging():
		if current_highlight_state != HighlightState.NONE:
			current_highlight_state = HighlightState.NONE
			queue_redraw()
		return

	# Check if mouse is over this slot
	var mouse_pos = get_global_mouse_position()
	var slot_rect = Rect2(global_position, size)
	if not slot_rect.has_point(mouse_pos):
		if current_highlight_state != HighlightState.NONE:
			current_highlight_state = HighlightState.NONE
			queue_redraw()
		return

	# Get drag data and determine highlight state
	var drag_data = get_viewport().gui_get_drag_data()
	_update_highlight_state(drag_data)

func _update_highlight_state(data: Variant):
	"""Determine if drop is valid/swap/invalid and update highlight"""
	var new_state = HighlightState.NONE

	# Validate drag data
	if not data is Dictionary or not data.has("skill_id"):
		new_state = HighlightState.NONE
	elif data.hero_id != hero_id:
		new_state = HighlightState.INVALID
	else:
		# Check skill type match
		var skill_data = data.skill_data as HeroSkillData
		if not skill_data:
			new_state = HighlightState.INVALID
		else:
			var expected_type = HeroSkillData.SkillType.ACTIVE if slot_type == "active" else HeroSkillData.SkillType.PASSIVE
			if skill_data.skill_type != expected_type:
				new_state = HighlightState.INVALID
			elif equipped_skill_id != "":
				# Slot has a skill - drop would swap
				new_state = HighlightState.SWAP
			else:
				# Empty slot - drop would equip
				new_state = HighlightState.VALID

	# Update state and redraw if changed
	if new_state != current_highlight_state:
		current_highlight_state = new_state
		queue_redraw()

func _draw():
	"""Draw highlight overlay based on current state"""
	if current_highlight_state == HighlightState.NONE:
		return

	var highlight_color: Color
	match current_highlight_state:
		HighlightState.VALID:
			highlight_color = Color(0.0, 1.0, 0.0, 0.3)  # GREEN
		HighlightState.SWAP:
			highlight_color = Color(1.0, 0.6, 0.0, 0.3)  # ORANGE
		HighlightState.INVALID:
			highlight_color = Color(1.0, 0.0, 0.0, 0.3)  # RED
		_:
			return

	# Draw highlight rect over entire slot
	draw_rect(Rect2(Vector2.ZERO, size), highlight_color)

	# Draw border for emphasis
	var border_color = highlight_color.lightened(0.3)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)

func _refresh_display():
	"""Refresh the slot display based on equipped skill"""
	# Clear existing icon
	if skill_icon:
		skill_icon.queue_free()
		skill_icon = null

	# Get equipped skill
	var equipped = SaveManager.get_equipped_skills(hero_id)
	var skills_array = equipped.get(slot_type, [])
	if slot_index < skills_array.size():
		equipped_skill_id = skills_array[slot_index]
	else:
		equipped_skill_id = ""

	# Show/hide empty label
	if empty_label:
		empty_label.visible = (equipped_skill_id == "")

	# Create icon if skill equipped
	if equipped_skill_id != "":
		# Load skill data from class config
		var skill_data = _get_skill_data(equipped_skill_id)

		if skill_data:
			# Create skill icon
			var skill_icon_scene = load("res://scenes/ui/skill_icon.tscn")
			if skill_icon_scene:
				skill_icon = skill_icon_scene.instantiate()
				skill_icon.setup(equipped_skill_id, skill_data, hero_id)
				skill_icon.source_slot_index = slot_index
				skill_icon.source_slot_type = slot_type
				icon_layer.add_child(skill_icon)

				# Phase 4: Fade-in animation for polish
				skill_icon.modulate.a = 0.0
				var tween = create_tween()
				tween.set_ease(Tween.EASE_OUT)
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.tween_property(skill_icon, "modulate:a", 1.0, 0.2)

				print("[SkillSlot] ✅ Displayed %s in %s slot %d" % [equipped_skill_id, slot_type, slot_index])

func _get_skill_data(skill_id: String) -> HeroSkillData:
	"""Get skill data from hero's class config"""
	if not HeroDatabase or not HeroClassDatabase:
		return null

	var hero_data = HeroDatabase.get_hero(hero_id)
	if not hero_data:
		return null

	var class_config = HeroClassDatabase.get_class_config(hero_data.hero_class)
	if not class_config:
		return null

	# Find skill in available_skill_pool
	for skill_data in class_config.available_skill_pool:
		if skill_data and skill_data.skill_id == skill_id:
			return skill_data

	return null

## ============================================
## DRAG-AND-DROP HANDLING
## ============================================

func _gui_input(event):
	if event is InputEventMouseButton and not event.pressed:
		print("[SkillSlot:%d] Input received: %s" % [slot_index, event.as_text()])

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	"""Validate if drop is allowed"""
	if not data is Dictionary:
		return false
	if not data.has("skill_id"):
		return false

	# Check hero match
	if data.hero_id != hero_id:
		print("[SkillSlot] ❌ Drop rejected: Hero mismatch")
		return false

	# Check skill type match (active skills to active slots only)
	var skill_data = data.skill_data as HeroSkillData
	if not skill_data:
		return false

	var expected_type = HeroSkillData.SkillType.ACTIVE if slot_type == "active" else HeroSkillData.SkillType.PASSIVE
	if skill_data.skill_type != expected_type:
		print("[SkillSlot] ❌ Drop rejected: Type mismatch (expected %s, got %s)" % [
			"active" if expected_type == HeroSkillData.SkillType.ACTIVE else "passive",
			"active" if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else "passive"
		])
		return false

	print("[SkillSlot] ✅ Drop validated: %s -> %s slot %d" % [data.skill_id, slot_type, slot_index])
	return true

func _drop_data(_at_position: Vector2, data: Variant):
	"""Execute the drop - equip or swap skills"""
	print("[SkillSlot:%d] 🟢 _drop_data triggered!" % slot_index)
	
	var dragged_skill_id = data.skill_id
	var source_slot_index = data.source_slot_index

	print("[SkillSlot] 📦 Dropping %s (from slot %d) onto slot %d" % [dragged_skill_id, source_slot_index, slot_index])

	# CASE 1: Dragging from skill list -> Equip to slot
	if source_slot_index == -1:
		SaveManager.equip_skill(hero_id, slot_type, slot_index, dragged_skill_id)
		skill_equipped.emit(slot_index, dragged_skill_id)
		_refresh_display()
		print("[SkillSlot] ✅ Equipped %s to slot %d" % [dragged_skill_id, slot_index])

		# Play audio feedback
		if AudioManager:
			AudioManager.play("equip")

	# CASE 2: Dragging from another slot -> Swap
	elif source_slot_index != slot_index:
		# Get current skill in this slot
		var current_skill = equipped_skill_id

		print("[SkillSlot] 🔄 Swapping: slot %d (%s) <-> slot %d (%s)" % [
			source_slot_index, dragged_skill_id,
			slot_index, current_skill if current_skill != "" else "empty"
		])

		# Swap: this slot gets dragged skill
		SaveManager.equip_skill(hero_id, slot_type, slot_index, dragged_skill_id)

		# Source slot gets current skill (or "" if empty)
		if current_skill == "":
			SaveManager.unequip_skill(hero_id, slot_type, source_slot_index)
		else:
			SaveManager.equip_skill(hero_id, slot_type, source_slot_index, current_skill)

		skill_equipped.emit(slot_index, dragged_skill_id)

		# Refresh all slots in parent grid
		var parent_grid = get_parent()
		if parent_grid and parent_grid.has_method("refresh_all_slots"):
			parent_grid.refresh_all_slots()

		print("[SkillSlot] ✅ Swap completed")

		# Play audio feedback
		if AudioManager:
			AudioManager.play("swap")

	# CASE 3: Dragging to same slot -> No-op
	else:
		print("[SkillSlot] ⚠️ Same slot, no action")
		pass
