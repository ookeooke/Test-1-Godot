extends Resource
class_name EnemyStats

## Enemy Stats Resource
## This resource defines all stats for an enemy type.
## Create separate .tres files for each enemy variant (goblin, orc, wolf, etc.)

# ============================================
# MOVEMENT
# ============================================

@export_group("Movement")

## How fast the enemy moves along the path (pixels per second)
@export var speed: float = 100.0

## Can this enemy be blocked by heroes? (Flying enemies = false)
@export var can_be_blocked: bool = true

## Detection range to check if blocking hero is still close
@export var melee_detection_range: float = 100.0

# ============================================
# COMBAT
# ============================================

@export_group("Combat")

## Maximum health points
@export var max_health: float = 50.0

## Damage dealt to heroes in melee combat
@export var melee_damage: float = 5.0

## Time between attacks (seconds)
@export var attack_cooldown: float = 1.0

# ============================================
# REWARDS & PENALTIES
# ============================================

@export_group("Rewards & Penalties")

## Gold awarded to player when enemy dies
@export var gold_reward: int = 5

## How many lives the player loses if enemy reaches the end
@export var life_damage: int = 1

# ============================================
# VISUAL EFFECTS
# ============================================

@export_group("Visual Effects")

## Camera shake intensity when enemy dies
@export_enum("Small", "Medium", "Large") var death_shake: String = "Small"
