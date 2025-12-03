extends Control
class_name SkillIcon

## ============================================
## SKILL ICON - Draggable skill icon component
## ============================================
##
## Drag source for skill loadout system (Diablo 2 style)
## Can be dragged from skill list to loadout slots
## Can be dragged between loadout slots to swap

# Visual references
@onready var background: ColorRect = $Background if has_node("Background") else null
@onready var icon: TextureRect = $Icon if has_node("Icon") else null
@onready var level_label: Label = $LevelLabel if has_node("LevelLabel") else null

# State
var skill_id: String = ""
var skill_data: HeroSkillData = null
var hero_id: String = ""
var source_slot_index: int = -1 # -1 = from skill list, 0+ = from loadout slot
var source_slot_type: String = "" # "active" or "passive"

func _ready():
	_update_display()


## ============================================
## INITIALIZATION
## ============================================

func setup(p_skill_id: String, p_skill_data: HeroSkillData, p_hero_id: String):
	"""Configure the skill icon with data"""
	skill_id = p_skill_id
	skill_data = p_skill_data
	hero_id = p_hero_id
	_update_display()

func _update_display():
	"""Update visual elements based on skill data"""
	if not skill_data:
		return

	# Update background color based on skill type
	if background:
		if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE:
			background.color = Color(0.3, 0.5, 0.7, 1.0) # Blue for active
		else:
			background.color = Color(0.5, 0.7, 0.3, 1.0) # Green for passive

	# Update icon texture
	if icon and skill_data.icon:
		icon.texture = skill_data.icon

	# Update level label
	if level_label:
		var level = SaveManager.get_hero_skill_level(hero_id, skill_id)
		level_label.text = "Lv%d" % level

## ============================================
## DRAG-AND-DROP (Diablo 2 Style)
## ============================================

func _get_drag_data(at_position: Vector2):
	"""Initiate drag operation"""
	print("[SkillIcon] >>> Drag started: %s (from slot %d)" % [skill_id, source_slot_index])

	# Create visual preview (semi-transparent)
	var preview = Control.new()
	var preview_bg = ColorRect.new()
	preview_bg.size = size
	preview_bg.color = background.color if background else Color(0.5, 0.5, 0.5, 0.7)
	preview.add_child(preview_bg)

	if icon and icon.texture:
		var preview_icon = TextureRect.new()
		preview_icon.texture = icon.texture
		preview_icon.size = icon.size
		preview_icon.position = icon.position
		preview_icon.expand_mode = icon.expand_mode
		preview_icon.stretch_mode = icon.stretch_mode
		preview.add_child(preview_icon)

	if level_label:
		var preview_label = Label.new()
		preview_label.text = level_label.text
		preview_label.position = level_label.position
		preview_label.size = level_label.size
		preview_label.horizontal_alignment = level_label.horizontal_alignment
		preview.add_child(preview_label)

	preview.modulate = Color(1, 1, 1, 0.7) # 70% opacity
	set_drag_preview(preview)

	# Apply ghost effect to source
	self.modulate.a = 0.3

	# Return drag data dictionary
	return {
		"skill_id": skill_id,
		"skill_data": skill_data,
		"hero_id": hero_id,
		"source_slot_index": source_slot_index,
		"source_slot_type": source_slot_type,
		"source_sprite": self
	}

func _notification(what):
	"""Handle drag end notification"""
	if what == NOTIFICATION_DRAG_END:
		# Restore opacity when drag ends
		self.modulate.a = 1.0
		print("[SkillIcon] <<< Drag ended: %s" % skill_id)
