extends Resource
class_name CampaignData

## Campaign/World Configuration Resource
## Groups multiple levels together into a campaign

# ============================================
# BASIC INFO
# ============================================

## Unique identifier for this campaign (e.g., "main", "forest_world", "bonus")
@export var campaign_id: String = "main"

## Display name shown to player
@export var campaign_name: String = "Main Campaign"

## Description/flavor text
@export_multiline var campaign_description: String = ""

# ============================================
# LEVELS
# ============================================

## All levels in this campaign (in order)
@export var levels: Array[LevelConfig] = []

# ============================================
# VISUALS
# ============================================

## Icon for campaign select screen
@export var campaign_icon: Texture2D

## Background image for campaign
@export var campaign_background: Texture2D

## Theme color for UI elements
@export var theme_color: Color = Color.WHITE

# ============================================
# PROGRESSION
# ============================================

## Is this campaign unlocked by default?
@export var unlocked_by_default: bool = true

## Stars required to unlock this campaign (if not default)
@export_range(0, 200, 1) var required_stars: int = 0

# ============================================
# HELPER METHODS
# ============================================

## Get total number of levels in this campaign
func get_level_count() -> int:
	return levels.size()

## Get level by ID
func get_level_by_id(level_id: String) -> LevelConfig:
	for level in levels:
		if level.level_id == level_id:
			return level
	return null

## Get level by index
func get_level_by_index(index: int) -> LevelConfig:
	if index >= 0 and index < levels.size():
		return levels[index]
	return null

## Get next level after the given level
func get_next_level(current_level_id: String) -> LevelConfig:
	for i in range(levels.size()):
		if levels[i].level_id == current_level_id:
			if i + 1 < levels.size():
				return levels[i + 1]
			return null
	return null

## Get total stars possible in this campaign
func get_total_stars_possible() -> int:
	return levels.size() * 3  # 3 stars per level

## Check if player has unlocked this campaign
func is_unlocked(player_stars: int) -> bool:
	return unlocked_by_default or player_stars >= required_stars
