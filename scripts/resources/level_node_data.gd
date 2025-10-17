extends Resource
class_name LevelNodeData

# LevelNodeData - Resource for storing individual level node configuration
# Used by WorldMapSelect to position and configure level buttons on the map

@export var level_id: String = ""  # Unique ID (e.g., "level_01", "level_02")
@export var level_name: String = "Level 1"  # Display name
@export var level_scene_path: String = ""  # Path to the level scene
@export var position: Vector2 = Vector2.ZERO  # Position on the world map
@export var campaign_type: String = "forest"  # Campaign category (forest, desert, mountains)

# Unlock requirements
@export var required_level_id: String = ""  # Previous level that must be completed (empty for first level)
@export var required_stars: int = 0  # Minimum stars needed from previous levels to unlock

# Path connection to next level
@export var path_to_next_level: Array[Vector2] = []  # Points for drawing path to next level node

# Level difficulty/info
@export var difficulty_levels: Array[String] = ["Normal", "Hard", "Heroic"]  # Available difficulty modes
@export var recommended_difficulty: String = "Normal"

# Description
@export_multiline var description: String = "Complete this level to progress!"
