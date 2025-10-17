extends Node2D

# ============================================
# WAVE MANAGER - Spawns enemies in waves
# ============================================

# REFERENCES (drag these from Scene tree in Inspector)
@export var enemy_path: Path2D  # The path enemies follow
@export var goblin_scene: PackedScene
@export var orc_scene: PackedScene
@export var wolf_scene: PackedScene
@export var troll_scene: PackedScene
@export var bat_scene: PackedScene
@export var wave_label: Label  # Reference to the UI label

# WAVE CONFIGURATION (using Custom Resources)
@export var waves: Array[WaveData] = []  # Drag wave .tres files here in Inspector

# WAVE SETTINGS
var current_wave = 0  # Which wave we're on (starts at 0)
var enemies_alive = 0  # How many enemies are currently on screen

# Current wave spawn state
var current_wave_data: WaveData = null
var current_enemy_groups: Array = []  # Flattened list of enemies to spawn
var current_spawn_index: int = 0  # Which enemy in the list we're spawning next

# TIMING
var spawn_delay = 0.5  # Base seconds between each enemy spawn (will be randomized)
var wave_break_time = 3.0  # Seconds between waves

# SPAWN VARIATION SETTINGS (for more interesting movement)
var spawn_delay_min = 0.3  # Minimum time between spawns
var spawn_delay_max = 0.8  # Maximum time between spawns
var position_offset_x = 20.0  # Random X offset range (-20 to +20)
var position_offset_y = 15.0  # Random Y offset range (-15 to +15)
var speed_variation_min = 0.85  # Minimum speed multiplier (85% of base speed)
var speed_variation_max = 1.15  # Maximum speed multiplier (115% of base speed)

# TIMERS
var spawn_timer: Timer
var wave_break_timer: Timer

# VICTORY SCREEN
var victory_screen_scene = preload("res://scenes/ui/victory_screen.tscn")

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# This runs once when the level starts
	# Load waves from LevelManager if available
	if LevelManager.current_level:
		waves = LevelManager.current_level.waves.duplicate()

	# Create the spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_delay
	spawn_timer.one_shot = false  # Repeats automatically
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	# Create the wave break timer
	wave_break_timer = Timer.new()
	wave_break_timer.wait_time = wave_break_time
	wave_break_timer.one_shot = true  # Only triggers once
	wave_break_timer.timeout.connect(_on_wave_break_timer_timeout)
	add_child(wave_break_timer)

	# Start the first wave after 2 seconds (gives player time to prepare)
	await get_tree().create_timer(2.0).timeout
	start_next_wave()

# ============================================
# WAVE CONTROL FUNCTIONS
# ============================================

func start_next_wave():
	# Safety check: make sure waves are assigned
	if waves.is_empty():
		push_error("WaveManager: No waves assigned! Please assign wave .tres files in the Inspector.")
		return

	if current_wave >= waves.size():
		print("All waves completed! You win!")
		return

	# Get the wave data resource
	current_wave_data = waves[current_wave]

	# Safety check: make sure the wave data is valid
	if current_wave_data == null:
		push_error("WaveManager: Wave ", current_wave, " is null! Please assign a valid wave .tres file.")
		return

	current_wave += 1

	print("=== WAVE ", current_wave, " STARTING ===")
	if current_wave_data.wave_name and current_wave_data.wave_name != "":
		print("Wave Name: ", current_wave_data.wave_name)

	# Build flattened list of enemies to spawn from all enemy groups
	current_enemy_groups.clear()
	current_spawn_index = 0

	for enemy_group in current_wave_data.enemies:
		for i in enemy_group.count:
			current_enemy_groups.append({
				"type": enemy_group.enemy_type,
				"spawn_point": enemy_group.spawn_point_index
			})

	print("Total enemies to spawn: ", current_enemy_groups.size())

	# Update UI
	if wave_label:
		if current_wave_data.wave_name:
			wave_label.text = "Wave " + str(current_wave) + ": " + current_wave_data.wave_name
		else:
			wave_label.text = "Wave " + str(current_wave)

	# Start spawn timer with randomized first delay
	spawn_timer.wait_time = randf_range(spawn_delay_min, spawn_delay_max)
	spawn_timer.start()

func wave_completed():
	print("=== WAVE ", current_wave, " COMPLETED ===")

	# Camera shake for wave complete (disabled - adjust in inspector if needed)
	# CameraEffects.large_shake(get_viewport().get_camera_2d())

	# Check if this was the last wave FIRST
	if current_wave >= waves.size():
		print("ALL WAVES CLEARED! VICTORY!")
		if wave_label:
			wave_label.text = "VICTORY!"

		# Victory camera sequence (shake disabled)
		# CameraEffects.victory_sequence(get_viewport().get_camera_2d())

		# Show victory screen
		_show_victory_screen()
		return

	# If not the last wave, show "Wave Complete!" and start break timer
	if wave_label:
		wave_label.text = "Wave Complete!"

	# Use break_time from the current wave data
	var break_time = current_wave_data.break_time if current_wave_data else wave_break_time
	print("Next wave in ", break_time, " seconds...")
	wave_break_timer.wait_time = break_time
	wave_break_timer.start()

# ============================================
# SPAWNING FUNCTIONS
# ============================================

func spawn_enemy():
	# Check if we have more enemies to spawn
	if current_spawn_index >= current_enemy_groups.size():
		spawn_timer.stop()
		return

	# Get the next enemy to spawn
	var enemy_info = current_enemy_groups[current_spawn_index]
	current_spawn_index += 1

	# Decide which enemy scene to use
	var enemy_scene_to_use: PackedScene
	var enemy_type = enemy_info["type"]

	if enemy_type == "goblin":
		enemy_scene_to_use = goblin_scene
	elif enemy_type == "orc":
		enemy_scene_to_use = orc_scene
	elif enemy_type == "wolf":
		enemy_scene_to_use = wolf_scene
	elif enemy_type == "troll":
		enemy_scene_to_use = troll_scene
	elif enemy_type == "bat":
		enemy_scene_to_use = bat_scene
	else:
		print("ERROR: Unknown enemy type: ", enemy_type)
		return
	
	# Safety check
	if enemy_scene_to_use == null:
		print("ERROR: Enemy scene not assigned for type: ", enemy_type)
		return
	
	if enemy_path == null:
		print("ERROR: No enemy path assigned!")
		return
	
	# Create PathFollow2D
	var path_follower = PathFollow2D.new()
	path_follower.loop = false
	path_follower.rotates = false  # Don't rotate enemy to follow path direction
	enemy_path.add_child(path_follower)
	
	# Create the enemy
	var enemy = enemy_scene_to_use.instantiate()
	path_follower.add_child(enemy)

	# Apply random position offset (makes enemies spread out instead of following in a line)
	var random_offset = Vector2(
		randf_range(-position_offset_x, position_offset_x),
		randf_range(-position_offset_y, position_offset_y)
	)
	enemy.position = random_offset

	# Apply random speed variation (makes enemies naturally space out over time)
	var speed_multiplier = randf_range(speed_variation_min, speed_variation_max)
	enemy.speed *= speed_multiplier

	# Connect to path
	if enemy.has_method("set_path_follower"):
		enemy.set_path_follower(path_follower)
	else:
		enemy.path_follower = path_follower
	
	# Connect death signal
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)

	enemies_alive += 1

	# Check if all enemies have been spawned
	if current_spawn_index >= current_enemy_groups.size():
		spawn_timer.stop()
		print("All enemies spawned for wave ", current_wave)

func _on_spawn_timer_timeout():
	# This gets called every 'spawn_delay' seconds
	if current_spawn_index < current_enemy_groups.size():
		spawn_enemy()

		# Randomize the next spawn delay for more natural timing
		if current_spawn_index < current_enemy_groups.size():  # Still more to spawn
			spawn_timer.wait_time = randf_range(spawn_delay_min, spawn_delay_max)

func _on_wave_break_timer_timeout():
	# This gets called after the break between waves
	start_next_wave()

# ============================================
# ENEMY CALLBACKS
# ============================================

func _on_enemy_died():
	# Called when an enemy dies or reaches the end
	enemies_alive -= 1
	print("Enemy removed. Alive: ", enemies_alive)

	# Check if wave is complete (all spawned and all dead)
	if enemies_alive <= 0 and current_spawn_index >= current_enemy_groups.size():
		wave_completed()

# ============================================
# VICTORY HANDLING
# ============================================

func _show_victory_screen():
	# Calculate stars (simple 3-star system for now)
	var stars = _calculate_stars()

	# Get level ID from LevelManager or use default
	var level_id = "level_01"  # Default
	if LevelManager.current_level:
		level_id = LevelManager.current_level.level_id

	# Notify LevelManager of completion
	if LevelManager.current_level:
		LevelManager.complete_level(stars)

	# Get the current scene tree root
	var root = get_tree().root

	# Create a CanvasLayer to ensure victory screen is on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top of everything

	# Instantiate victory screen
	var victory_screen = victory_screen_scene.instantiate()
	victory_screen.level_id = level_id
	victory_screen.stars_earned = stars

	# Add canvas layer to root, then victory screen to canvas layer
	root.add_child(canvas_layer)
	canvas_layer.add_child(victory_screen)

	print("WaveManager: Victory screen shown with ", stars, " stars on canvas layer ", canvas_layer.layer)

func _calculate_stars() -> int:
	# Star calculation based on lives remaining (10 waves is harder!)
	# 3 stars: 16+ lives (80%+ health)
	# 2 stars: 10-15 lives (50-75% health)
	# 1 star: 1-9 lives (survived but barely)
	var lives_left = GameManager.lives

	if lives_left >= 16:
		return 3
	elif lives_left >= 10:
		return 2
	else:
		return 1
