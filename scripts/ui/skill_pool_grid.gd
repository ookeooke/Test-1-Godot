extends Control
class_name SkillPoolGrid

## Grid container for displaying unequipped skills (Hybrid Skill System - Phase 2)
## Displays skills in a visible 8-column grid (no scrolling for <64 skills)
## Follows the same UX patterns as inventory grid for consistency

@export var columns: int = 8  # 8 columns (industry standard for skill grids)
@export var cell_size: Vector2 = Vector2(56, 56)  # Slightly larger than inventory (56 vs 48)
@export var cell_gap: float = 4.0  # 4px gap between cells
@export var show_type_colors: bool = true  # Blue border for active, green for passive

# References
var grid_container: GridContainer = null
var skill_icon_scene: PackedScene = null
var current_hero_id: String = ""

# Skill tracking
var displayed_skills: Array[HeroSkillData] = []

# Visual theme (blue-tinted to differentiate from brown inventory)
const THEME_COLOR_ACTIVE = Color(0.3, 0.5, 0.9, 0.2)  # Blue tint for active skills
const THEME_COLOR_PASSIVE = Color(0.3, 0.9, 0.5, 0.2)  # Green tint for passive skills
const THEME_COLOR_LOCKED = Color(0.3, 0.3, 0.3, 0.5)  # Gray for locked skills

func _ready():
	# Create grid container
	grid_container = GridContainer.new()
	grid_container.name = "SkillGrid"
	grid_container.columns = columns
	grid_container.add_theme_constant_override("h_separation", cell_gap)
	grid_container.add_theme_constant_override("v_separation", cell_gap)
	add_child(grid_container)

	# Load skill icon scene
	skill_icon_scene = load("res://scenes/ui/skill_icon.tscn")
	if not skill_icon_scene:
		push_error("[SkillPoolGrid] Failed to load skill_icon.tscn")

func setup(hero_id: String, skills: Array):
	"""Initialize grid with hero's available skills

	Args:
		hero_id: Hero ID (e.g., "ranger")
		skills: Array of HeroSkillData resources
	"""
	current_hero_id = hero_id
	displayed_skills.clear()

	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()

	# Filter out null skills
	var valid_skills = skills.filter(func(s): return s != null)

	print("[SkillPoolGrid] Setting up grid for hero '%s' with %d skills" % [hero_id, valid_skills.size()])

	# Create SkillIcon for each skill
	for skill_data in valid_skills:
		_create_skill_cell(skill_data)

	# Resize container to fit grid
	_update_size()

func _create_skill_cell(skill_data: HeroSkillData) -> void:
	"""Create a single skill cell in the grid

	Args:
		skill_data: HeroSkillData resource for the skill
	"""
	if not skill_icon_scene:
		push_error("[SkillPoolGrid] Cannot create cell - skill_icon scene not loaded")
		return

	# Create cell background (for visual feedback)
	var cell_bg = Panel.new()
	cell_bg.custom_minimum_size = cell_size

	# Apply theme color based on skill type
	if show_type_colors:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = _get_skill_theme_color(skill_data)
		stylebox.border_width_left = 2
		stylebox.border_width_right = 2
		stylebox.border_width_top = 2
		stylebox.border_width_bottom = 2
		stylebox.border_color = _get_skill_border_color(skill_data)
		stylebox.corner_radius_top_left = 4
		stylebox.corner_radius_top_right = 4
		stylebox.corner_radius_bottom_left = 4
		stylebox.corner_radius_bottom_right = 4
		cell_bg.add_theme_stylebox_override("panel", stylebox)

	# Create skill icon
	var skill_icon = skill_icon_scene.instantiate() as SkillIcon
	if not skill_icon:
		push_error("[SkillPoolGrid] Failed to instantiate SkillIcon for %s" % skill_data.skill_name)
		grid_container.add_child(cell_bg)  # Add empty cell
		return

	# Setup skill icon
	skill_icon.setup(skill_data.skill_id, skill_data, current_hero_id)
	skill_icon.source_slot_index = -1  # -1 indicates from pool (not equipped)
	skill_icon.source_slot_type = "active" if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else "passive"

	# Add icon to cell background
	cell_bg.add_child(skill_icon)
	skill_icon.position = Vector2.ZERO
	skill_icon.custom_minimum_size = cell_size

	# Add cell to grid
	grid_container.add_child(cell_bg)
	displayed_skills.append(skill_data)

	print("[SkillPoolGrid] ✅ Created cell for skill: %s (%s)" % [
		skill_data.skill_name,
		"ACTIVE" if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE else "PASSIVE"
	])

func _get_skill_theme_color(skill_data: HeroSkillData) -> Color:
	"""Get background color for skill based on type

	Returns:
		Color: Blue for active, green for passive, gray for locked
	"""
	# TODO: Add locked state check when skill unlock system is implemented
	# if skill_data.is_locked():
	#     return THEME_COLOR_LOCKED

	if skill_data.skill_type == HeroSkillData.SkillType.ACTIVE:
		return THEME_COLOR_ACTIVE
	else:
		return THEME_COLOR_PASSIVE

func _get_skill_border_color(skill_data: HeroSkillData) -> Color:
	"""Get border color for skill based on type

	Returns:
		Color: Brighter version of theme color
	"""
	var theme_color = _get_skill_theme_color(skill_data)
	return theme_color.lightened(0.3)

func _update_size():
	"""Update container size to fit grid content"""
	var rows_needed = ceili(float(displayed_skills.size()) / float(columns))
	var total_width = columns * cell_size.x + (columns - 1) * cell_gap
	var total_height = rows_needed * cell_size.y + (rows_needed - 1) * cell_gap

	custom_minimum_size = Vector2(total_width, total_height)
	grid_container.custom_minimum_size = Vector2(total_width, total_height)

	print("[SkillPoolGrid] Grid size: %d rows × %d cols = %s" % [
		rows_needed,
		columns,
		custom_minimum_size
	])

func refresh():
	"""Refresh the grid with current hero's skills"""
	if current_hero_id.is_empty():
		push_error("[SkillPoolGrid] Cannot refresh - no hero set")
		return

	# Get hero data first to access hero_class (int)
	var hero_data = HeroDatabase.get_hero(current_hero_id)
	if not hero_data:
		push_error("[SkillPoolGrid] No hero data found for: %s" % current_hero_id)
		return

	# Get available skills from class config using hero_class (int) instead of hero_id (String)
	# TODO: Filter out equipped skills once we have that integration
	var class_config = HeroClassDatabase.get_class_config(hero_data.hero_class)
	if class_config and class_config.has("skills"):
		setup(current_hero_id, class_config.skills)
	else:
		push_error("[SkillPoolGrid] No class config found for hero: %s" % current_hero_id)

func clear():
	"""Clear all skill cells from grid"""
	for child in grid_container.get_children():
		child.queue_free()
	displayed_skills.clear()
	custom_minimum_size = Vector2.ZERO
