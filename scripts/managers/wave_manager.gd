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

# WAVE SETTINGS
var current_wave = 0  # Which wave we're on (starts at 0)
var enemies_to_spawn = 0  # How many enemies left to spawn this wave
var enemies_alive = 0  # How many enemies are currently on screen
var current_enemy_type = "goblin"  # Which enemy to spawn this wave
# WAVE DATA (each array = [enemy_type, count])
var wave_data = [
	["goblin", 5],    # Wave 1: 5 goblins (easy start)
	["goblin", 8],    # Wave 2: 8 goblins
	["wolf", 6],      # Wave 3: 6 wolves (fast!)
	["orc", 6],       # Wave 4: 6 orcs (tankier)
	["troll", 1],     # Wave 5: 1 troll boss (first boss)
	["bat", 8],       # Wave 6: 8 bats (flying, can't be blocked by heroes!)
	["goblin", 12],   # Wave 7: 12 goblins (horde)
	["wolf", 10],     # Wave 8: 10 wolves (fast horde)
	["orc", 10],      # Wave 9: 10 orcs (tank horde)
	["troll", 2],     # Wave 10: 2 troll bosses (final challenge!)
]

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
	print("Wave Manager initialized!")
	
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
	if current_wave >= wave_data.size():
		print("All waves completed! You win!")
		return
	
	current_wave += 1
	print("=== WAVE ", current_wave, " STARTING ===")
	
	# Get wave info (now it's [type, count])
	var wave_info = wave_data[current_wave - 1]
	current_enemy_type = wave_info[0]  # "goblin" or "orc"
	enemies_to_spawn = wave_info[1]     # count
	
	# Update UI
	if wave_label:
		wave_label.text = "Wave " + str(current_wave)

	# Start spawn timer with randomized first delay
	spawn_timer.wait_time = randf_range(spawn_delay_min, spawn_delay_max)
	spawn_timer.start()

func wave_completed():
	print("=== WAVE ", current_wave, " COMPLETED ===")

	# Camera shake for wave complete
	CameraEffects.large_shake(get_viewport().get_camera_2d())

	# Check if this was the last wave FIRST
	if current_wave >= wave_data.size():
		print("🎉 ALL WAVES CLEARED! VICTORY! 🎉")
		if wave_label:
			wave_label.text = "VICTORY!"

		# Victory camera sequence
		CameraEffects.victory_sequence(get_viewport().get_camera_2d())

		# Show victory screen
		_show_victory_screen()
		return

	# If not the last wave, show "Wave Complete!" and start break timer
	if wave_label:
		wave_label.text = "Wave Complete!"

	# Start the break timer before next wave
	print("Next wave in ", wave_break_time, " seconds...")
	wave_break_timer.start()

# ============================================
# SPAWNING FUNCTIONS
# ============================================

func spawn_enemy():
	# Decide which enemy scene to use
	var enemy_scene_to_use: PackedScene
	if current_enemy_type == "goblin":
		enemy_scene_to_use = goblin_scene
	elif current_enemy_type == "orc":
		enemy_scene_to_use = orc_scene
	elif current_enemy_type == "wolf":
		enemy_scene_to_use = wolf_scene
	elif current_enemy_type == "troll":
		enemy_scene_to_use = troll_scene
	elif current_enemy_type == "bat":
		enemy_scene_to_use = bat_scene
	else:
		print("ERROR: Unknown enemy type: ", current_enemy_type)
		return
	
	# Safety check
	if enemy_scene_to_use == null:
		print("ERROR: Enemy scene not assigned for type: ", current_enemy_type)
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
	enemies_to_spawn -= 1
	
	if enemies_to_spawn <= 0:
		spawn_timer.stop()

func _on_spawn_timer_timeout():
	# This gets called every 'spawn_delay' seconds
	if enemies_to_spawn > 0:
		spawn_enemy()

		# Randomize the next spawn delay for more natural timing
		if enemies_to_spawn > 0:  # Still more to spawn
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

	# Check if wave is complete
	if enemies_alive <= 0 and enemies_to_spawn <= 0:
		wave_completed()

# ============================================
# VICTORY HANDLING
# ============================================

func _show_victory_screen():
	# Calculate stars (simple 3-star system for now)
	var stars = _calculate_stars()

	# Get the current scene tree root
	var root = get_tree().root

	# Create a CanvasLayer to ensure victory screen is on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top of everything

	# Instantiate victory screen
	var victory_screen = victory_screen_scene.instantiate()
	victory_screen.level_id = "level_01"
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
