extends Node2D

# ============================================
# WAVE MANAGER - Spawns enemies in waves
# ============================================
#
# NEW FEATURE: Kingdom Rush-style "Call Next Wave" buttons
# - Floating buttons appear at spawn points during wave breaks
# - Players can call the next wave early for a gold bonus
# - Bonus decays over break time (5g instant → 1g near end)
# - Buttons auto-position to follow spawn points on screen

# REFERENCES (drag these from Scene tree in Inspector)
@export var enemy_path: Path2D # The path enemies follow (OLD SYSTEM - Optional if using waypoints)
@export var extra_paths: Array[Path2D] = [] # Additional paths for multi-spawn setups (Index 1+)
@export var start_waypoint: PathWaypoint # Starting waypoint (NEW SYSTEM - optional)
@export var use_waypoint_system: bool = false # Toggle between old Path2D and new waypoint system
@export var goblin_scene: PackedScene
@export var wolf_scene: PackedScene
@export var orc_scene: PackedScene
@export var ogre_scene: PackedScene
@export var troll_scene: PackedScene
@export var wave_label: Label # Reference to the UI label

# WAVE CONFIGURATION (using Custom Resources)
@export var waves: Array[WaveData] = [] # Drag wave .tres files here in Inspector

# WAVE SETTINGS
var current_wave = 0 # Which wave we're on (starts at 0)
var tracked_enemies: Dictionary = {} # Dictionary of all living enemies (enemy_instance: true)
var active_waves_enemy_count: Dictionary = {} # Living enemies per wave {wave_num: count}
var completed_waves: Dictionary = {} # Which waves have fully finished {wave_num: true}
var is_combat_active: bool = false # Whether a wave is currently active
var victory_screen_shown: bool = false # Guard to prevent showing victory twice

# COMBAT STATE SIGNALS
signal combat_started()
signal combat_ended()

# Current wave spawn state
var current_wave_data: WaveData = null
var current_enemy_groups: Array = [] # Flattened list of enemies to spawn (DEPRECATED - REMOVE IF UNUSED)
var current_spawn_index: int = 0 # Which enemy in the list we're spawning next (DEPRECATED)

# Inner class to manage a single active wave's spawning
class ActiveWaveSpawner:
	var wave_number: int
	var spawn_queue: Array[Dictionary]
	var current_index: int = 0
	var timer: Timer
	var manager: Node # Reference to WaveManager for callbacks
	
	func _init(p_wave_number: int, p_queue: Array[Dictionary], p_manager: Node):
		wave_number = p_wave_number
		spawn_queue = p_queue
		manager = p_manager
		
		# Create dedicated timer
		timer = Timer.new()
		timer.one_shot = true
		manager.add_child(timer)
		timer.timeout.connect(_on_timeout)
		
	func start(delay: float):
		timer.wait_time = delay
		timer.start()
		
	func _on_timeout():
		manager.process_spawner(self)
		
	func cleanup():
		if is_instance_valid(timer):
			timer.queue_free()

var active_spawners: Array[ActiveWaveSpawner] = [] # List of currently active spawners

# TIMING
var spawn_delay = 0.5 # Base seconds between each enemy spawn (will be randomized)
var wave_break_time = 3.0 # Seconds between waves

# SPAWN VARIATION SETTINGS (for more interesting movement)
var spawn_delay_min = 0.3 # Minimum time between spawns
var spawn_delay_max = 0.8 # Maximum time between spawns
var position_offset_x = 60.0 # Random X offset range (-60 to +60) - increased for more spread
var position_offset_y = 50.0 # Random Y offset range (-50 to +50) - increased for more spread
var speed_variation_min = 0.7 # Minimum speed multiplier (70% of base speed) - increased range
var speed_variation_max = 1.3 # Maximum speed multiplier (130% of base speed) - increased range

# LANE SYSTEM SETTINGS (creates parallel "traffic lanes")
var lane_offsets = [-40.0, 0.0, 40.0] # Perpendicular offsets for 3 lanes
var use_lane_system = true # Enable/disable lane-based spawning

# TIMERS
var spawn_timer: Timer
var wave_break_timer: Timer

# LOOT DISTRIBUTION SCREEN
var loot_distribution_scene = preload("res://scenes/ui/loot_distribution_screen.tscn")

# CALL WAVE BUTTON SYSTEM (Kingdom Rush style)
var call_wave_button_scene = preload("res://scenes/ui/call_wave_button.tscn")
var active_call_wave_buttons: Array = [] # Currently visible buttons
var spawn_point_positions: Array[Vector2] = [] # World positions of spawn points
var early_call_enabled: bool = false # Whether early call is currently allowed

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# This runs once when the level starts
	# Load waves from LevelManager if available
	if LevelManager.current_level:
		waves = LevelManager.current_level.waves.duplicate()
		print("[WaveManager] ✅ Loaded %d waves from LevelManager.current_level" % waves.size())
	else:
		# EDITOR TESTING MODE: If testing directly from F5, initialize GameStateManager manually
		push_warning("[WaveManager] No current_level found - you're testing from editor!")
		push_warning("[WaveManager] Loading default level config for testing...")

		# Try to load level_01_config for testing
		var test_config = load("res://data/level_configs/level_01_config.tres") as LevelConfig
		if test_config:
			GameStateManager.initialize_level(test_config)
			waves = test_config.waves.duplicate()
			print("[WaveManager] ✅ Loaded %d waves from test config (starting gold: %d)" % [waves.size(), GameStateManager.gold])

	# VALIDATION: Warn if wave count seems wrong
	if waves.size() == 0:
		push_error("[WaveManager] ❌ NO WAVES LOADED! Check level configuration!")
	elif waves.size() < 3:
		push_warning("[WaveManager] ⚠️ Only %d waves loaded - Is this intentional?" % waves.size())
	else:
		print("[WaveManager] ✅ Wave count validated: %d waves ready!" % waves.size())

	# NEW: Calculate level gold budget
	_calculate_level_gold_distribution()

	# Create the wave interval timer (formerly break timer)
	wave_break_timer = Timer.new()
	wave_break_timer.name = "WaveIntervalTimer"
	wave_break_timer.one_shot = true # Triggers once per wave
	wave_break_timer.timeout.connect(_on_wave_break_timer_timeout)
	add_child(wave_break_timer)

	# Start balance tracking
	if BalanceTracker:
		var level_id = LevelManager.current_level.level_id if LevelManager.current_level else "unknown"
		BalanceTracker.start_run(level_id)

	# SELF-HEALING: If start_waypoint is missing (common in migration), try to find it dynamically
	if use_waypoint_system and start_waypoint == null:
		print("[WaveManager] ⚠️ start_waypoint is null! Attempting to find it dynamically...")
		var potential_waypoint = get_node_or_null("../Waypoints/Waypoint_0")
		if potential_waypoint:
			start_waypoint = potential_waypoint
			print("[WaveManager] ✅ FIXED: Found start_waypoint at ../Waypoints/Waypoint_0")
		else:
			# Try searching by group
			var waypoints = get_tree().get_nodes_in_group("waypoints")
			if waypoints.size() > 0:
				# Sort by name to hopefully get Waypoint_0
				waypoints.sort_custom(func(a, b): return a.name < b.name)
				start_waypoint = waypoints[0]
				print("[WaveManager] ✅ FIXED: Found start_waypoint via group: ", start_waypoint.name)

	# Detect spawn point positions for call wave buttons
	detect_spawn_points()

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

	# print("=== WAVE ", current_wave, " STARTING ===")
	if current_wave_data.wave_name and current_wave_data.wave_name != "":
		print("Wave Name: ", current_wave_data.wave_name)

	# Build flattened list of enemies for THIS wave
	var wave_queue: Array[Dictionary] = []

	for enemy_group in current_wave_data.enemies:
		for i in enemy_group.count:
			wave_queue.append({
				"type": enemy_group.enemy_type,
				"spawn_point": enemy_group.spawn_point_index,
				"delay": enemy_group.spawn_delay # Store custom delay
			})

	# Create and start new spawner for this wave
	var spawner = ActiveWaveSpawner.new(current_wave, wave_queue, self)
	active_spawners.append(spawner)
	
	# Start first spawn with random small delay
	spawner.start(randf_range(spawn_delay_min, spawn_delay_max))
	
	print("[WaveManager] Started spawner for Wave %d with %d enemies" % [current_wave, wave_queue.size()])

	# Update UI
	if wave_label:
		if current_wave_data.wave_name:
			wave_label.text = "Wave " + str(current_wave) + ": " + current_wave_data.wave_name
		else:
			wave_label.text = "Wave " + str(current_wave)

	# Set combat state and emit signal
	is_combat_active = true
	combat_started.emit()
	# print("[WaveManager] Combat started - Wave ", current_wave)

	# Clear any call wave buttons (in case wave was started early)
	clear_call_wave_buttons()

	# Track wave start
	if BalanceTracker:
		BalanceTracker.start_wave(current_wave)

	# FIXED INTERVAL LOGIC: Start timer for NEXT wave immediately
	if current_wave < waves.size():
		var interval = current_wave_data.break_time
		if interval <= 0: interval = 30.0 # Default fallback
		
		print("[WaveManager] Next wave in %.1f seconds (Fixed Interval)" % interval)
		wave_break_timer.wait_time = interval
		wave_break_timer.start()
		
		
		# Show Call Wave buttons after a delay (15% of interval)
		# This prevents "instant" spam at usage and creates a lockout period
		var button_delay = interval * 0.15
		
		# Clamp delay to reasonable limits (e.g., minimum 2s, max 10s)
		if button_delay < 2.0: button_delay = 2.0
		
		print("[WaveManager] Next wave in %.1f seconds. Button appearing in %.1fs." % [interval, button_delay])
		
		# Create a one-shot timer for the button appearance
		get_tree().create_timer(button_delay).timeout.connect(create_call_wave_buttons)
	else:
		print("[WaveManager] Final wave started! No next wave timer.")

func wave_completed():
	# Guard against duplicate calls (can happen when multiple enemies die simultaneously)
	if current_wave >= waves.size() and victory_screen_shown:
		print("[WaveManager] Victory already processed, ignoring duplicate wave_completed() call")
		return

	print("=== WAVE ", current_wave, " COMPLETED ===")

	# Track wave end
	if BalanceTracker:
		BalanceTracker.end_wave(current_wave)

	# Award wave completion bonus (progressive: 12g/13g/15g based on wave)
	var wave_bonus = 12
	if current_wave >= 7:
		wave_bonus = 13 # Mid-game bonus
	if current_wave >= 13:
		wave_bonus = 15 # Late-game bonus
	GameStateManager.add_gold(wave_bonus)
	print("[WaveManager] Wave completion bonus: +%dg (wave %d)" % [wave_bonus, current_wave])

	# Track wave bonus in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_wave_bonus(current_wave, wave_bonus)

	# Award XP completion bonus to all heroes
	if HeroProgressionManager:
		var xp_bonus = HeroProgressionManager.get_wave_completion_xp(current_wave)
		var heroes = _get_active_hero_nodes()
		for hero in heroes:
			if is_instance_valid(hero):
				HeroProgressionManager.award_xp(hero, xp_bonus)
		if heroes.size() > 0:
			print("[WaveManager] Wave completion XP: +%d to %d heroes" % [xp_bonus, heroes.size()])

	# Set combat state to inactive
	is_combat_active = false
	combat_ended.emit()
	print("[WaveManager] Combat ended - Wave ", current_wave, " complete")

	# NEW: Auto-collect all pending loot from the wave (Dungeon Defenders pattern)
	LootManager.collect_wave_loot()

	# Camera shake for wave complete (disabled - adjust in inspector if needed)
	# CameraEffects.large_shake(get_viewport().get_camera_2d())

	# Check if this was the last wave FIRST
	if current_wave >= waves.size():
		# Set guard flag IMMEDIATELY to prevent duplicate execution
		victory_screen_shown = true

		print("ALL WAVES CLEARED! Verifying all enemies are dead...")

		# Wait 1 frame for queue_free() to process, then verify
		await get_tree().process_frame

		# Double-check that all enemies are truly gone (Kingdom Rush style)
		if not _verify_all_enemies_dead():
			print("ERROR: Victory check failed - enemies still on screen!")
			print("Waiting for remaining enemies to be eliminated...")
			victory_screen_shown = false # Reset flag if verification failed
			return # Don't show victory yet

		if wave_label:
			wave_label.text = "VICTORY!"

		# End balance tracking with victory
		if BalanceTracker:
			BalanceTracker.end_run("victory", _calculate_stars())
			# Auto-save data on victory
			if BalanceExporter:
				BalanceExporter.export_current_run()

		# Victory camera sequence (shake disabled)
		# CameraEffects.victory_sequence(get_viewport().get_camera_2d())

		# Show victory screen
		_show_victory_screen()
		return

	# If not the last wave, just log completion (Timer is already running!)
	if wave_label:
		wave_label.text = "Wave Complete!"

	# DO NOT start timer here. It started at beginning of wave.
	# DO NOT create buttons here. They exist since start of wave.


## Helper function to check if combat is active
func is_wave_active() -> bool:
	return is_combat_active

# ============================================
# SPAWNING FUNCTIONS
# ============================================

func process_spawner(spawner: ActiveWaveSpawner):
	"""Process the next spawn for a specific active wave"""
	if spawner.current_index < spawner.spawn_queue.size():
		# Get enemy data
		var enemy_data = spawner.spawn_queue[spawner.current_index]
		
		# Spawn the enemy
		spawn_single_enemy(enemy_data, spawner.wave_number)
		
		# Increment index
		spawner.current_index += 1
		
		# Schedule next spawn
		if spawner.current_index < spawner.spawn_queue.size():
			var next_enemy_data = spawner.spawn_queue[spawner.current_index]
			var custom_delay = next_enemy_data.get("delay", 0.0)
			
			var wait_time = 0.0
			if custom_delay > 0:
				wait_time = custom_delay * randf_range(0.9, 1.1)
			else:
				wait_time = randf_range(spawn_delay_min, spawn_delay_max)
				
			spawner.start(wait_time)
		else:
			# This spawner is finished
			print("[WaveManager] Active Spawner for Wave %d finished spawning." % spawner.wave_number)
			spawner.cleanup()
			active_spawners.erase(spawner)
			
	else:
		# Should stick here usually, but just in case
		spawner.cleanup()
		active_spawners.erase(spawner)

func spawn_single_enemy(enemy_data: Dictionary, wave_num: int):
	var enemy_type = enemy_data.type
	var spawn_index = enemy_data.spawn_point
	
	var scene_to_spawn = null
	match enemy_type:
		"goblin": scene_to_spawn = goblin_scene
		"wolf": scene_to_spawn = wolf_scene
		"orc": scene_to_spawn = orc_scene
		"ogre": scene_to_spawn = ogre_scene
		"troll": scene_to_spawn = troll_scene
		_:
			push_error("Unknown enemy type: " + str(enemy_type))
			return

	if not scene_to_spawn:
		push_error("Scene for enemy type " + str(enemy_type) + " is not assigned!")
		return

	var enemy = scene_to_spawn.instantiate()
	enemy_path.add_child(enemy)
	
	# Pass wave number to enemy (for scaling if needed)
	if "wave_number" in enemy:
		enemy.wave_number = wave_num

	# Choose spawn path
	var selected_path = enemy_path
	if spawn_index > 0 and spawn_index <= extra_paths.size():
		selected_path = extra_paths[spawn_index - 1]

	var path_follower = PathFollow2D.new()
	path_follower.loop = false
	selected_path.add_child(path_follower)
	# path_follower.add_child(enemy) 	# Add to wave group for easier management
	enemy.add_to_group("wave_%d_enemies" % wave_num)
	if "wave_number" in enemy:
		enemy.wave_number = wave_num
	else:
		print("WARNING: Enemy %s missing wave_number property" % enemy.name)

	# Connect to path
	if enemy.has_method("set_path_follower"):
		enemy.set_path_follower(path_follower)
	else:
		enemy.path_follower = path_follower
		
	# Connect death signal with enemy reference binding
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

	# Apply per-wave stat modifiers
	if wave_num > 0 and wave_num <= waves.size():
		_apply_wave_modifiers(enemy, enemy_type)

	# Add enemy to tracking dictionary
	tracked_enemies[enemy] = true
	
	# Increment per-wave active count
	if not active_waves_enemy_count.has(wave_num):
		active_waves_enemy_count[wave_num] = 0
	active_waves_enemy_count[wave_num] += 1

func _on_wave_break_timer_timeout():
	# This gets called after the break between waves
	start_next_wave()

# ============================================
# ENEMY CALLBACKS
# ============================================

func _on_enemy_died(enemy):
	# Called when an enemy dies or reaches the end
	# NEW: Roll loot for the enemy
	if is_instance_valid(enemy):
		_roll_loot_for_enemy(enemy)

		# Award XP to participating heroes
		_award_xp_for_enemy_kill(enemy)

	# Remove enemy from tracking dictionary
	if tracked_enemies.has(enemy):
		tracked_enemies.erase(enemy)
		# print("Enemy removed. Tracked count: ", tracked_enemies.size())
	else:
		print("WARNING: Enemy died but was not being tracked!")

	# Handle per-wave completion
	var wave_num = -1
	if "wave_number" in enemy:
		wave_num = enemy.wave_number
		
	if wave_num != -1:
		if active_waves_enemy_count.has(wave_num):
			active_waves_enemy_count[wave_num] -= 1
			# print("Wave %d enemy count: %d" % [wave_num, active_waves_enemy_count[wave_num]])
			
			if active_waves_enemy_count[wave_num] <= 0:
				# Check if spawning for this wave is also complete
				var spawner_active = false
				for spawner in active_spawners:
					if spawner.wave_number == wave_num:
						spawner_active = true
						break
				
				if not spawner_active:
					# Wave fully complete!
					_mark_wave_as_complete(wave_num)

	# Check for LEVEL completion (all waves done)
	if completed_waves.size() >= waves.size():
		wave_completed() # This function name is legacy, implies "Level Completed" now
	
func _mark_wave_as_complete(wave_num):
	"""Mark a specific wave as fully completed (spawned & killed)"""
	if completed_waves.has(wave_num):
		return # Already marked
		
	print("✅ Wave %d FULLY COMPLETED!" % wave_num)
	completed_waves[wave_num] = true
	
	if BalanceTracker:
		BalanceTracker.end_wave(wave_num)

# ============================================
# VICTORY HANDLING
# ============================================

func _verify_all_enemies_dead() -> bool:
	"""Double-check that all enemies are truly gone from the scene tree"""
	var actual_enemies = get_tree().get_nodes_in_group("enemy")

	# Log discrepancy if any
	if actual_enemies.size() > 0:
		print("WARNING: Tracked enemies empty but ", actual_enemies.size(), " enemies still in scene!")
		for enemy in actual_enemies:
			if is_instance_valid(enemy):
				print("  - Remaining enemy: ", enemy.name, " at ", enemy.global_position)
		return false

	print("Verification passed: All enemies confirmed dead")
	return true

func _show_victory_screen():
	# Calculate stars (simple 3-star system for now)
	var stars = _calculate_stars()

	# Get level ID from LevelManager or use default
	var level_id = "level_01" # Default
	if LevelManager.current_level:
		level_id = LevelManager.current_level.level_id

	# Award gems based on stars earned!
	var gems_earned = _award_star_gems(stars)
	print("💎 [WaveManager] Earned %d gems for %d stars!" % [gems_earned, stars])

	# Notify LevelManager of completion
	if LevelManager.current_level:
		LevelManager.complete_level(stars)

	# Pause the game tree so gameplay stops
	get_tree().paused = true

	# Show loot distribution screen FIRST
	# Check if there's any loot to distribute
	var loot_count = LootManager.get_pending_loot_count()

	if loot_count > 0:
		print("[WaveManager] Showing loot distribution screen (%d items pending)" % loot_count)
		await _show_loot_distribution_screen(gems_earned, stars)
	else:
		print("[WaveManager] No loot to distribute, skipping loot screen")

	# NEW: Skip victory screen, go directly to world map (user's requested flow)
	print("[WaveManager] Loot complete, returning to world map...")

	# Unpause the game before changing scenes
	get_tree().paused = false

	# 🔧 FIX CRITICAL: Save before scene change to prevent data loss
	# Ensures all item movements, equipment changes, and loot distribution are persisted
	SaveManager.save_current_profile()
	print("[WaveManager] Profile saved before scene transition")

	# Change to world map scene
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")

	print("[WaveManager] Scene change to world map initiated")


func _show_loot_distribution_screen(gems_earned: int, stars_earned: int = 0):
	"""Show loot distribution screen and wait for user to continue"""
	# Get heroes who participated in this level
	var participating_heroes = _get_participating_heroes()

	if participating_heroes.is_empty():
		print("[WaveManager] WARNING: No heroes found in level! Skipping loot distribution.")
		return

	# Create canvas layer for loot screen
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # Modal loot screen above gameplay
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	# Instantiate loot distribution screen
	var loot_screen = loot_distribution_scene.instantiate()

	# Set gems earned (must set BEFORE adding to tree)
	if loot_screen.has_method("set_gems_earned") or "gems_earned" in loot_screen:
		loot_screen.gems_earned = gems_earned

	# NEW: Pass star and level data for victory star display
	loot_screen.stars_earned = stars_earned
	if LevelManager.current_level:
		loot_screen.level_id = LevelManager.current_level.level_id
	loot_screen.difficulty = GameStateManager.current_difficulty

	# CRITICAL: Pass hero data to loot screen
	loot_screen.participating_heroes = participating_heroes

	# Add to scene tree
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(loot_screen)

	# Wait for user to finish distributing loot
	await loot_screen.continue_to_victory

	print("[WaveManager] Loot distribution complete, continuing to results screen")


func _get_participating_heroes() -> Array:
	"""Get all heroes who participated in this level

	Returns Array of hero data: [{hero_id: String, hero_name: String, hero_class: String}]
	"""
	var hero_data_list: Array = []

	# Try to find HeroManager in the level
	var hero_manager = get_tree().get_first_node_in_group("hero_manager")
	if hero_manager and "spawned_heroes" in hero_manager:
		for hero in hero_manager.spawned_heroes:
			if is_instance_valid(hero):
				var hero_info = {
					"hero_id": hero.get_meta("hero_id", "hero_" + str(hero.get_instance_id())),
					"hero_name": hero.get_meta("hero_name", "Hero"),
					"hero_class": hero.get_meta("hero_class", "warrior")
				}
				hero_data_list.append(hero_info)
				print("[WaveManager] Found hero: %s (%s)" % [hero_info.hero_name, hero_info.hero_id])

	# Fallback: Search for all heroes in "hero" group
	if hero_data_list.is_empty():
		var heroes = get_tree().get_nodes_in_group("hero")
		for hero in heroes:
			if is_instance_valid(hero):
				var hero_info = {
					"hero_id": hero.get_meta("hero_id", "hero_" + str(hero.get_instance_id())),
					"hero_name": hero.get_meta("hero_name", "Hero"),
					"hero_class": hero.get_meta("hero_class", "warrior")
				}
				hero_data_list.append(hero_info)
				print("[WaveManager] Found hero (fallback): %s (%s)" % [hero_info.hero_name, hero_info.hero_id])

	return hero_data_list

func _calculate_stars() -> int:
	# Use centralized star calculation from GameStateManager
	# This ensures consistent star calculation across the game
	return GameStateManager.get_current_star_rating()

func _award_star_gems(stars: int) -> int:
	"""Award gems based on stars earned (from level_config)"""
	if not LevelManager.current_level:
		print("[WaveManager] No level config, cannot award gems")
		return 0

	var level_config = LevelManager.current_level
	var gems_to_award = 0

	# Get gem reward based on stars from level config
	match stars:
		3:
			gems_to_award = level_config.three_star_gold_bonus # TODO: Rename to three_star_gem_reward
		2:
			gems_to_award = level_config.two_star_gold_bonus # TODO: Rename to two_star_gem_reward
		1:
			gems_to_award = level_config.one_star_gold_bonus # TODO: Rename to one_star_gem_reward
		_:
			print("[WaveManager] Invalid star count: ", stars)
			return 0

	# Award gems to player
	if SaveManager and gems_to_award > 0:
		SaveManager.add_gems(gems_to_award)
		print("💎 [WaveManager] Awarded %d gems for completing with %d stars!" % [gems_to_award, stars])

	return gems_to_award

# ============================================
# PER-WAVE STAT MODIFIERS
# ============================================

func _apply_wave_modifiers(enemy, enemy_type: String):
	"""Apply per-wave HP and gold multipliers to spawned enemy"""
	if not current_wave_data:
		return

	# DYNAMIC GOLD: Override base gold reward if level budget is active
	# DISABLED for Kingdom Rush Balance (We want precise 3g/7g values)
	# if calculated_gold_per_enemy > 0 and "gold_reward" in enemy:
	# 	enemy.gold_reward = calculated_gold_per_enemy
	# 	# print("[WaveManager] Applied dynamic gold: %d" % calculated_gold_per_enemy)

	# Get HP multiplier (check custom first, then global)
	var hp_mult = 1.0
	if current_wave_data.custom_hp_multipliers.has(enemy_type):
		hp_mult = current_wave_data.custom_hp_multipliers[enemy_type]
	else:
		hp_mult = current_wave_data.hp_multiplier

	# Get gold multiplier (check custom first, then global)
	var gold_mult = 1.0
	if current_wave_data.custom_gold_multipliers.has(enemy_type):
		gold_mult = current_wave_data.custom_gold_multipliers[enemy_type]
	else:
		gold_mult = current_wave_data.gold_multiplier

	# Apply HP multiplier
	if hp_mult != 1.0 and enemy.has_method("set_max_health"):
		var original_hp = enemy.max_health
		var new_hp = int(original_hp * hp_mult)
		enemy.set_max_health(new_hp)
		# print("[WaveManager] Wave %d: %s HP scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_hp, new_hp, hp_mult])
	elif hp_mult != 1.0 and "max_health" in enemy:
		var original_hp = enemy.max_health
		var new_hp = int(original_hp * hp_mult)
		enemy.max_health = new_hp
		enemy.current_health = new_hp # Also update current health
		# print("[WaveManager] Wave %d: %s HP scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_hp, new_hp, hp_mult])

	# Apply gold multiplier
	if gold_mult != 1.0 and "gold_reward" in enemy:
		var original_gold = enemy.gold_reward
		var new_gold = int(original_gold * gold_mult)
		enemy.gold_reward = new_gold
		# print("[WaveManager] Wave %d: %s gold scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_gold, new_gold, gold_mult])

# ============================================
# CALL WAVE BUTTON SYSTEM
# ============================================

func detect_spawn_points():
	"""Detect spawn point positions from the level"""
	spawn_point_positions.clear()

	if use_waypoint_system:
		# NEW WAYPOINT SYSTEM: Use waypoint position
		if start_waypoint:
			spawn_point_positions.append(start_waypoint.global_position)
			print("[WaveManager] Detected spawn point (waypoint): ", start_waypoint.global_position)
	else:
		# OLD PATH2D SYSTEM: Use first point of path curve
		if enemy_path and enemy_path.curve and enemy_path.curve.point_count > 0:
			var first_point = enemy_path.curve.get_point_position(0)
			var spawn_pos = enemy_path.global_position + first_point
			spawn_point_positions.append(spawn_pos)
			print("[WaveManager] Detected spawn point (path): ", spawn_pos)

	# If we have wave data with multiple spawn points, detect those too
	if current_wave_data and current_wave_data.enemies.size() > 0:
		var unique_spawn_indices = []
		for enemy_group in current_wave_data.enemies:
			if enemy_group.spawn_point_index not in unique_spawn_indices:
				unique_spawn_indices.append(enemy_group.spawn_point_index)

		# If multiple spawn indices found, we might need to add more spawn positions
		# For now, just log the info (future enhancement: support multiple paths)
		if unique_spawn_indices.size() > 1:
			print("[WaveManager] Wave uses %d different spawn points (indices: %s)" % [unique_spawn_indices.size(), unique_spawn_indices])

	if spawn_point_positions.is_empty():
		push_warning("[WaveManager] No spawn points detected! Call wave buttons will not appear.")

func create_call_wave_buttons():
	"""Create call wave buttons at each spawn point"""
	# Clear any existing buttons
	clear_call_wave_buttons()

	# Get UI canvas layer (find the camera's UI layer)
	var ui_layer = get_tree().root.get_node_or_null("TestLevel/UI")
	if not ui_layer:
		# Try to find any CanvasLayer in the scene
		var canvas_layers = get_tree().get_nodes_in_group("ui_layer")
		if canvas_layers.size() > 0:
			ui_layer = canvas_layers[0]
		else:
			push_warning("[WaveManager] No UI CanvasLayer found - buttons will not appear!")
			return

	# Create button at each spawn point
	for spawn_pos in spawn_point_positions:
		var button = call_wave_button_scene.instantiate()
		ui_layer.add_child(button)

		# Setup button with spawn position and timing
		# Calculate dynamic bonus (1g per second remaining - Pure KR Style)
		var time_left = wave_break_timer.time_left
		var bonus = int(time_left * 1.0) # Removed +20g flat bonus to prevent inflation
		button.setup(spawn_pos, time_left, bonus)

		# Connect signal
		button.wave_called.connect(_on_call_wave_button_pressed)

		# Add to tracking array
		active_call_wave_buttons.append(button)

	early_call_enabled = true
	print("[WaveManager] Created %d call wave button(s)" % active_call_wave_buttons.size())

func clear_call_wave_buttons():
	"""Remove all active call wave buttons"""
	for button in active_call_wave_buttons:
		if is_instance_valid(button):
			button.queue_free()

	active_call_wave_buttons.clear()
	early_call_enabled = false

func _on_call_wave_button_pressed():
	"""Handle call wave button click - start wave early"""
	# 1. IMMEDIATE GUARD: Disable early call to prevent spam clicks
	early_call_enabled = false
	
	# Get gold bonus from first button (they should all have same bonus)
	var gold_bonus = 0
	if active_call_wave_buttons.size() > 0 and is_instance_valid(active_call_wave_buttons[0]):
		gold_bonus = active_call_wave_buttons[0].get_current_bonus()

	print("[WaveManager] Wave called early! Bonus: +%dg" % gold_bonus)
	
	# 2. EXECUTE ONCE: Award gold and stop timer
	GameStateManager.add_gold(gold_bonus)
	wave_break_timer.stop()
	
	# 3. CLEANUP: Remove buttons
	clear_call_wave_buttons()
	
	# 4. ACTION: Start next wave
	start_next_wave()

# ============================================
# DYNAMIC GOLD DISTRIBUTION (LEVEL BUDGET)
# ============================================

var calculated_gold_per_enemy: int = 0 # Calculated average gold per enemy

func _calculate_level_gold_distribution():
	"""Calculate gold per enemy based on LevelConfig.total_level_gold"""
	if not LevelManager.current_level or LevelManager.current_level.total_level_gold <= 0:
		return # Use default per-enemy gold values

	var target_total_gold = LevelManager.current_level.total_level_gold
	var total_enemy_count = 0

	# Count total enemies across all waves
	for wave in waves:
		if wave and wave.enemies:
			for group in wave.enemies:
				total_enemy_count += group.count

	if total_enemy_count == 0:
		print("[WaveManager] Warning: No enemies found in level config!")
		return

	# Calculate gold per enemy (simple flat distribution for now)
	# Future enhancement: Weighted distribution based on enemy HP/Type
	calculated_gold_per_enemy = int(float(target_total_gold) / total_enemy_count)
	
	# Clamp minimum gold to 1 to avoid frustration
	if calculated_gold_per_enemy < 1:
		calculated_gold_per_enemy = 1

	print("[WaveManager] 💰 LEVEL BUDGET ACTIVE: %d Gold / %d Enemies = ~%d Gold/Kill" %
		[target_total_gold, total_enemy_count, calculated_gold_per_enemy])


# ============================================
# LOOT SYSTEM INTEGRATION
# ============================================

func _roll_loot_for_enemy(enemy):
	"""Roll loot drops for a defeated enemy"""
	# Determine enemy tier based on type
	var enemy_tier = _get_enemy_tier(enemy)

	# Get enemy position for loot drop location
	var loot_position = enemy.global_position

	# Check if this is a boss enemy (for guaranteed drops)
	var is_boss = _is_boss_enemy(enemy)
	var guaranteed_item = ""

	if is_boss:
		enemy_tier = "boss"
		# Bosses could have guaranteed unique drops
		# guaranteed_item = "legendary_bow"  # Example

	# Roll loot through LootManager
	LootManager.roll_loot_for_enemy(enemy_tier, loot_position, guaranteed_item)


func _get_enemy_tier(enemy) -> String:
	"""Determine enemy tier based on enemy type or properties"""
	# Get enemy name/type
	var enemy_name = enemy.name.to_lower()

	# Tier 1: Weak enemies (goblins)
	if "goblin" in enemy_name:
		return "tier1"

	# Tier 2: Medium enemies (wolves)
	elif "wolf" in enemy_name:
		return "tier2"

	# Tier 3: Strong enemies (trolls, bosses)
	elif "troll" in enemy_name or "boss" in enemy_name:
		return "tier3"

	# Default to tier 1
	return "tier1"


func _is_boss_enemy(enemy) -> bool:
	"""Check if an enemy is a boss"""
	var enemy_name = enemy.name.to_lower()
	return "boss" in enemy_name or (enemy.has_method("is_boss") and enemy.is_boss())


func _award_xp_for_enemy_kill(enemy):
	"""Award XP to heroes when an enemy is killed"""
	if not HeroProgressionManager:
		return # Progression system not available

	# Get enemy tier to determine XP amount
	var enemy_tier = _get_enemy_tier(enemy)
	if _is_boss_enemy(enemy):
		enemy_tier = "boss"

	# Get XP amount for this tier
	var xp_amount = HeroProgressionManager.get_recommended_xp_for_tier(enemy_tier)

	# Get all active heroes in the level
	var heroes = _get_active_hero_nodes()

	if heroes.is_empty():
		return # No heroes to award XP to

	# Award XP to all participating heroes (Bloons TD 6 style)
	# All heroes in level get XP regardless of proximity
	for hero in heroes:
		if is_instance_valid(hero):
			HeroProgressionManager.award_xp(hero, xp_amount)

	print("[WaveManager] Awarded %d XP to %d heroes for killing %s" % [xp_amount, heroes.size(), enemy_tier])


func _get_active_hero_nodes() -> Array:
	"""Get all active hero nodes in the level (actual Node references, not metadata)"""
	var hero_nodes: Array = []

	# Try to find HeroManager in the level
	var hero_manager = get_tree().get_first_node_in_group("hero_manager")
	if hero_manager and "spawned_heroes" in hero_manager:
		for hero in hero_manager.spawned_heroes:
			if is_instance_valid(hero):
				hero_nodes.append(hero)
		return hero_nodes

	# Fallback: Search for all heroes in "hero" group
	var heroes = get_tree().get_nodes_in_group("hero")
	for hero in heroes:
		if is_instance_valid(hero):
			hero_nodes.append(hero)

	return hero_nodes
