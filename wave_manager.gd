extends Node2D

# ============================================
# WAVE MANAGER - Spawns enemies in waves
# ============================================

# REFERENCES (drag these from Scene tree in Inspector)
@export var enemy_path: Path2D  # The path enemies follow
@export var goblin_scene: PackedScene
@export var orc_scene: PackedScene
@export var wave_label: Label  # Reference to the UI label

# WAVE SETTINGS
var current_wave = 0  # Which wave we're on (starts at 0)
var enemies_to_spawn = 0  # How many enemies left to spawn this wave
var enemies_alive = 0  # How many enemies are currently on screen
var current_enemy_type = "goblin"  # Which enemy to spawn this wave
# WAVE DATA (each number = enemies in that wave)
var wave_data = [
	["goblin", 5],   # Wave 1: 5 goblins
	["goblin", 8],   # Wave 2: 8 goblins
	["orc", 6],      # Wave 3: 6 orcs
	["goblin", 10],  # Wave 4: 10 goblins
	["orc", 8],      # Wave 5: 8 orcs
]

# TIMING
var spawn_delay = 0.5  # Seconds between each enemy spawn
var wave_break_time = 3.0  # Seconds between waves

# TIMERS
var spawn_timer: Timer
var wave_break_timer: Timer

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
	
	spawn_timer.start()

func wave_completed():
	print("=== WAVE ", current_wave, " COMPLETED ===")
	
	# Check if this was the last wave FIRST
	if current_wave >= wave_data.size():
		print("🎉 ALL WAVES CLEARED! VICTORY! 🎉")
		if wave_label:
			wave_label.text = "VICTORY!"
		# TODO: Show victory screen
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
	enemy_path.add_child(path_follower)
	
	# Create the enemy
	var enemy = enemy_scene_to_use.instantiate()
	path_follower.add_child(enemy)
	
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
