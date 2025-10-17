extends Resource
class_name EnemySpawnData

## Individual enemy spawn configuration
## Used within WaveData to define what enemies spawn in a wave

## Type of enemy to spawn
@export_enum("goblin", "orc", "wolf", "troll", "bat") var enemy_type: String = "goblin"

## How many of this enemy type to spawn
@export_range(1, 50, 1) var count: int = 5

## Delay between spawning each enemy of this type (seconds)
## Note: This is overridden by wave_manager's random spawn timing
@export_range(0.1, 5.0, 0.1) var spawn_delay: float = 0.5

## Optional: Which path/spawn point to use (for future multiple path support)
@export var spawn_point_index: int = 0
