extends Resource
class_name LevelNodeData

## LevelNodeData - UI/WORLD MAP AUTHORITY
##
## ARCHITECTURE: SEPARATED PATTERN (Recommended for Kingdom Rush-style games)
##
## This resource focuses on UI/DISPLAY DATA ONLY:
##   - Position on world map (Vector2)
##   - Scene file path (String, not PackedScene)
##   - Visual presentation (name, description)
##   - Unlock requirements for UI display
##   - Path connections between level nodes
##
## Gameplay data is in LevelConfig (separate resource):
##   - Waves, enemies, balance
##   - Gold, lives, difficulty
##   - Rewards and progression
##
## WHY SEPARATED?
##   ✓ World map loads THIS (~0.7 KB) not LevelConfig (~14.7 KB)
##   ✓ 25 level buttons = 17.5 KB instead of 368 KB (21x smaller!)
##   ✓ Difficulty variants can share one LevelNodeData
##   ✓ Daily challenges don't need world map positions
##   ✓ Kingdom Rush industry standard pattern
##
## USAGE PATTERN:
##   WorldMapSelectNode2D displays these as buttons on the map
##   When clicked, it loads matching LevelConfig from CampaignData
##   Then uses level_scene_path (String) to load the actual scene
##
## WHY STRING PATH INSTEAD OF PACKEDSCENE?
##   PackedScene loads the entire scene into memory immediately
##   String path = lazy loading only when needed
##   Scales to 100+ levels without memory issues

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
