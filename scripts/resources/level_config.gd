extends Resource
class_name LevelConfig

## Level Configuration Resource - GAMEPLAY AUTHORITY
##
## ARCHITECTURE: SEPARATED PATTERN (Recommended for Kingdom Rush-style games)
##
## This resource focuses on GAMEPLAY DATA ONLY:
##   - Waves, enemies, difficulty
##   - Starting resources (gold, lives)
##   - Progression and rewards
##
## UI/World Map data is in LevelNodeData (separate resource):
##   - Position on world map
##   - Scene file path (as string)
##   - Unlock requirements display
##
## WHY SEPARATED?
##   ✓ World map loads minimal data (not 16 waves per button)
##   ✓ Daily challenges can skip UI metadata
##   ✓ Difficulty variants share UI, vary gameplay
##   ✓ Level editor only needs gameplay fields
##   ✓ Scales to 100+ levels without issues
##
## USAGE PATTERNS:
##
## Pattern 1: Unified Loading (if level_scene_path is set)
##   NavigationManager.load_level(level_config)
##   └─ Loads scene from level_config.level_scene_path (String)
##
## Pattern 2: Separated Loading (current - level_scene_path is empty)
##   LevelManager.load_level_config(level_config)  # Init game state
##   get_tree().change_scene_to_file(node_data.level_scene_path)  # Load scene
##   └─ WorldMapSelectNode2D uses this pattern automatically
##
## Both patterns work! Use whichever fits your workflow.

# ============================================
# BASIC INFO
# ============================================

## Unique identifier for this level (e.g., "forest_01", "desert_02")
@export var level_id: String = "level_01"

## Display name shown to player
@export var level_name: String = "Level 1"

## Optional description/flavor text
@export_multiline var level_description: String = ""

# ============================================
# GAMEPLAY SETTINGS
# ============================================

## Starting gold for this level
@export_range(0, 1000, 10) var starting_gold: int = 100

## Starting lives for this level
@export_range(1, 100, 1) var starting_lives: int = 20

## Wave configurations for this level
@export var waves: Array[WaveData] = []

# ============================================
# DIFFICULTY & PROGRESSION
# ============================================

## Difficulty rating (1-5 stars, or 1-10 scale)
@export_range(1, 10, 1) var difficulty: int = 1

## Number of stars required to unlock this level (0 = always unlocked)
@export_range(0, 100, 1) var required_stars: int = 0

## Which campaign this level belongs to
@export var campaign_id: String = "main"

## Order within the campaign (for level select screen)
@export var level_index: int = 1

# ============================================
# SCENE REFERENCES
# ============================================

## The actual level scene to load (File Path String to avoid cyclic ref)
@export_file("*.tscn") var level_scene_path: String

# ============================================
# CAMERA BOUNDS
# ============================================

## Playable area bounds for camera (auto-calculated from level content if not set)
## Format: Rect2(left_x, top_y, width, height)
## Example: Rect2(-200, 200, 2000, 800) means playable area from (-200,200) to (1800,1000)
@export var camera_bounds: Rect2 = Rect2(0, 0, 0, 0) # Zero rect = auto-calculate

## Should camera bounds be auto-calculated from tower spots and paths?
@export var auto_calculate_bounds: bool = true

## Padding to add when auto-calculating bounds (extra space around content)
@export var bounds_padding: float = 200.0

## Optional: Custom background music for this level
@export var music: AudioStream

## Optional: Custom environment/background
@export var background_scene: PackedScene

# ============================================
# REWARDS & COMPLETION
# ============================================

## Gold reward for completing with 3 stars
@export var three_star_gold_bonus: int = 50

## Gold reward for completing with 2 stars
@export var two_star_gold_bonus: int = 30

## Gold reward for completing with 1 star
@export var one_star_gold_bonus: int = 10

# ============================================
# HELPER METHODS
# ============================================

## Get total number of waves in this level
func get_wave_count() -> int:
	return waves.size()

## Get total number of enemies across all waves
func get_total_enemy_count() -> int:
	var total = 0
	for wave in waves:
		for enemy_group in wave.enemies:
			total += enemy_group.count
	return total

## Check if player has enough stars to unlock this level
func is_unlocked(player_stars: int) -> bool:
	return player_stars >= required_stars
