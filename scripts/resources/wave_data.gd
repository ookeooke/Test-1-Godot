extends Resource
class_name WaveData

## Complete wave configuration
## Defines which enemies spawn, how many, and timing for a single wave

## Wave number (for display/reference)
@export var wave_number: int = 1

## Time to wait after this wave completes before starting next wave (seconds)
@export_range(1.0, 30.0, 0.5) var break_time: float = 3.0

## Array of enemy spawn configurations for this wave
## Each entry defines an enemy type, count, and spawn timing
@export var enemies: Array[EnemySpawnData] = []

## Optional: Display name for this wave (e.g., "Boss Wave", "Speed Rush")
@export var wave_name: String = ""

## Optional: Is this a boss wave? (for special UI treatment)
@export var is_boss_wave: bool = false

## ============================================
## PER-WAVE ENEMY STAT MODIFIERS
## ============================================

## HP multiplier for ALL enemies in this wave (1.0 = normal, 1.5 = +50% HP)
@export_range(0.5, 3.0, 0.1) var hp_multiplier: float = 1.0

## Gold multiplier for ALL enemies in this wave (1.0 = normal, 1.5 = +50% gold)
@export_range(0.5, 3.0, 0.1) var gold_multiplier: float = 1.0

## Optional: Custom HP multiplier per enemy type (overrides hp_multiplier)
## Example: {"goblin": 1.5, "orc": 2.0} makes goblins 50% stronger, orcs 100% stronger
@export var custom_hp_multipliers: Dictionary = {}

## Optional: Custom gold multiplier per enemy type (overrides gold_multiplier)
@export var custom_gold_multipliers: Dictionary = {}
