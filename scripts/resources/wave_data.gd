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
