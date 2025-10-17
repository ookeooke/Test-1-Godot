extends Resource
class_name LevelConfig

## Level Configuration Resource
## Contains all metadata and settings for a single level

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

## The actual level scene to load
@export var level_scene: PackedScene

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
