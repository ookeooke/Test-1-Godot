extends Node
class_name DifficultyConstants

## Difficulty Constants for 5-Star Rating System
##
## This class defines constants for the three difficulty modes:
## - Normal: Always available, 3 stars based on lives remaining
## - Hard: Unlocks after 3 stars on Normal, awards purple star
## - Unlimited: Unlocks after 3 stars on Normal, awards gold star

# Difficulty identifiers
const NORMAL = "normal"
const HARD = "hard"
const UNLIMITED = "unlimited"

# Array of all difficulties (for iteration)
const ALL_DIFFICULTIES = [NORMAL, HARD, UNLIMITED]

# Human-readable difficulty names
const DIFFICULTY_NAMES = {
	NORMAL: "Normal",
	HARD: "Hard",
	UNLIMITED: "Unlimited"
}

# Difficulty colors for UI display
const DIFFICULTY_COLORS = {
	NORMAL: Color("#FFD700"),    # Gold/Yellow for normal stars
	HARD: Color("#9B30FF"),      # Purple for hard difficulty star
	UNLIMITED: Color("#FFA500")  # Orange/Gold for unlimited difficulty star
}

# Unlock requirement descriptions for tooltips
const UNLOCK_REQUIREMENTS = {
	NORMAL: "Always available",
	HARD: "Get 3 stars on Normal to unlock",
	UNLIMITED: "Get 3 stars on Normal to unlock"
}

# Helper function to validate difficulty string
static func is_valid_difficulty(difficulty: String) -> bool:
	return difficulty in ALL_DIFFICULTIES

# Helper function to get difficulty color
static func get_difficulty_color(difficulty: String) -> Color:
	if difficulty in DIFFICULTY_COLORS:
		return DIFFICULTY_COLORS[difficulty]
	return Color.WHITE

# Helper function to get difficulty name
static func get_difficulty_name(difficulty: String) -> String:
	if difficulty in DIFFICULTY_NAMES:
		return DIFFICULTY_NAMES[difficulty]
	return "Unknown"
