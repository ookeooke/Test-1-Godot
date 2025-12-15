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
@export var troll_scene: PackedScene
@export var wave_label: Label # Reference to the UI label

# WAVE CONFIGURATION (using Custom Resources)
@export var waves: Array[WaveData] = [] # Drag wave .tres files here in Inspector

# WAVE SETTINGS
var current_wave = 0 # Which wave we're on (starts at 0)
var tracked_enemies: Dictionary = {} # Dictionary of all living enemies (enemy_instance: true)
var is_combat_active: bool = false # Whether a wave is currently active
var victory_screen_shown: bool = false # Guard to prevent showing victory twice

# COMBAT STATE SIGNALS
signal combat_started()
signal combat_ended()

# Current wave spawn state
var current_wave_data: WaveData = null
var current_enemy_groups: Array = [] # Flattened list of enemies to spawn
var current_spawn_index: int = 0 # Which enemy in the list we're spawning next

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
	elif waves.size() < 5:
		push_warning("[WaveManager] ⚠️ Only %d waves loaded - expected at least 5!" % waves.size())
	elif waves.size() != 10:
		push_warning("[WaveManager] ⚠️ Loaded %d waves - expected 10 for level_01!" % waves.size())
	else:
		print("[WaveManager] ✅ Wave count validated: 16 waves ready!")

	# Create the spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_delay
	spawn_timer.one_shot = false # Repeats automatically
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

	# Create the wave break timer
	wave_break_timer = Timer.new()
	wave_break_timer.wait_time = wave_break_time
	wave_break_timer.one_shot = true # Only triggers once
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

	# Set combat state and emit signal
	is_combat_active = true
	combat_started.emit()
	# print("[WaveManager] Combat started - Wave ", current_wave)

	# Clear any call wave buttons (in case wave was started early)
	clear_call_wave_buttons()

	# Track wave start
	if BalanceTracker:
		BalanceTracker.start_wave(current_wave)

	# Start spawn timer with randomized first delay
	spawn_timer.wait_time = randf_range(spawn_delay_min, spawn_delay_max)
	spawn_timer.start()

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

	# If not the last wave, show "Wave Complete!" and start break timer
	if wave_label:
		wave_label.text = "Wave Complete!"

	# Use break_time from the current wave data
	var break_time = current_wave_data.break_time if current_wave_data else wave_break_time
	print("Next wave in ", break_time, " seconds...")
	wave_break_timer.wait_time = break_time
	wave_break_timer.start()

	# Create call wave buttons during break (Kingdom Rush style)
	create_call_wave_buttons()


## Helper function to check if combat is active
func is_wave_active() -> bool:
	return is_combat_active

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
	elif enemy_type == "wolf":
		enemy_scene_to_use = wolf_scene
	elif enemy_type == "troll":
		enemy_scene_to_use = troll_scene
	else:
		print("ERROR: Unknown enemy type: ", enemy_type)
		return
	
	# Safety check
	if enemy_scene_to_use == null:
		print("ERROR: Enemy scene not assigned for type: ", enemy_type)
		return

	# Create the enemy based on navigation system
	var enemy

	if use_waypoint_system:
		# NEW WAYPOINT SYSTEM
		if start_waypoint == null:
			print("ERROR: No start waypoint assigned! Please assign a start_waypoint in inspector.")
			return

		# Create enemy directly in scene root (no PathFollow2D needed)
		enemy = enemy_scene_to_use.instantiate()
		get_tree().root.add_child(enemy)

		# Initialize waypoint navigation
		if enemy.has_method("set_waypoint_navigation"):
			enemy.set_waypoint_navigation(start_waypoint)
		else:
			print("ERROR: Enemy doesn't support waypoint navigation!")
			enemy.queue_free()
			return

		# print("[WaveManager] Spawned ", enemy_type, " using WAYPOINT system")

	else:
		# OLD PATH2D SYSTEM
		var selected_path = enemy_path
		
		# Check for custom spawn point (Multi-Path Support)
		var spawn_index = enemy_info.get("spawn_point", 0)
		if spawn_index > 0:
			if spawn_index <= extra_paths.size():
				selected_path = extra_paths[spawn_index - 1]
				# print("Spawning on Extra Path ", spawn_index)
			else:
				print("WARNING: Spawn index ", spawn_index, " requested but only ", extra_paths.size(), " extra paths defined!")
		
		# DEBUG
		# print("Spawn Logic: Index=", spawn_index, " SelectedPath=", selected_path)
		if selected_path == null:
			print("ERROR: selected_path is NULL! enemy_path=", enemy_path, " extra_paths=", extra_paths)
			return
		if typeof(selected_path) != TYPE_OBJECT or not selected_path is Node:
			print("ERROR: selected_path is NOT a Node! It is: ", selected_path)
			return

		if selected_path == null:
			print("ERROR: No enemy path assigned!")
			return

		# Create PathFollow2D
		var path_follower = PathFollow2D.new()
		path_follower.loop = false
		path_follower.rotates = false # Don't rotate enemy to follow path direction
		selected_path.add_child(path_follower)

		# Create the enemy
		enemy = enemy_scene_to_use.instantiate()
		path_follower.add_child(enemy)

		# LANE SYSTEM: Assign enemy to a lane (perpendicular offset from path)
		if use_lane_system:
			# Pick a random lane and apply h_offset for perpendicular positioning
			var chosen_lane = lane_offsets[randi() % lane_offsets.size()]
			path_follower.h_offset = chosen_lane

		# Apply random position offset (makes enemies spread out instead of following in a line)
		var random_offset = Vector2(
			randf_range(-position_offset_x, position_offset_x),
			randf_range(-position_offset_y, position_offset_y)
		)
		enemy.position = random_offset

		# Connect to path
		if enemy.has_method("set_path_follower"):
			enemy.set_path_follower(path_follower)
		else:
			enemy.path_follower = path_follower

		print("[WaveManager] Spawned ", enemy_type, " on ", selected_path.name, " (Index: ", spawn_index, ")")
	
	# Connect death signal with enemy reference binding
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

	# Apply per-wave stat modifiers from WaveData
	if current_wave_data:
		_apply_wave_modifiers(enemy, enemy_type)

	# Add enemy to tracking dictionary
	tracked_enemies[enemy] = true
	# print("Enemy spawned. Tracked count: ", tracked_enemies.size())

	# Check if all enemies have been spawned
	if current_spawn_index >= current_enemy_groups.size():
		spawn_timer.stop()
		print("All enemies spawned for wave ", current_wave)

func _on_spawn_timer_timeout():
	# This gets called every 'spawn_delay' seconds
	if current_spawn_index < current_enemy_groups.size():
		spawn_enemy()

		# Randomize the next spawn delay for more natural timing
		if current_spawn_index < current_enemy_groups.size(): # Still more to spawn
			spawn_timer.wait_time = randf_range(spawn_delay_min, spawn_delay_max)

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
		print("Enemy removed. Tracked count: ", tracked_enemies.size())
	else:
		print("WARNING: Enemy died but was not being tracked!")

	# Check if wave is complete (all spawned and all dead)
	if tracked_enemies.is_empty() and current_spawn_index >= current_enemy_groups.size():
		wave_completed()

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
		print("[WaveManager] Wave %d: %s HP scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_hp, new_hp, hp_mult])
	elif hp_mult != 1.0 and "max_health" in enemy:
		var original_hp = enemy.max_health
		var new_hp = int(original_hp * hp_mult)
		enemy.max_health = new_hp
		enemy.current_health = new_hp # Also update current health
		print("[WaveManager] Wave %d: %s HP scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_hp, new_hp, hp_mult])

	# Apply gold multiplier
	if gold_mult != 1.0 and "gold_reward" in enemy:
		var original_gold = enemy.gold_reward
		var new_gold = int(original_gold * gold_mult)
		enemy.gold_reward = new_gold
		print("[WaveManager] Wave %d: %s gold scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_gold, new_gold, gold_mult])

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

	# Get break time for this wave
	var break_time = current_wave_data.break_time if current_wave_data else wave_break_time

	# Create button at each spawn point
	for spawn_pos in spawn_point_positions:
		var button = call_wave_button_scene.instantiate()
		ui_layer.add_child(button)

		# Setup button with spawn position and timing
		button.setup(spawn_pos, break_time, 5) # 5 gold base bonus

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
	if not early_call_enabled:
		print("[WaveManager] Early call not allowed right now")
		return

	# Get gold bonus from first button (they should all have same bonus)
	var gold_bonus = 0
	if active_call_wave_buttons.size() > 0 and is_instance_valid(active_call_wave_buttons[0]):
		gold_bonus = active_call_wave_buttons[0].get_current_bonus()

	print("[WaveManager] Wave called early! Bonus: +%dg" % gold_bonus)

	# Award gold bonus
	GameStateManager.add_gold(gold_bonus)

	# Clear buttons and stop wave break timer
	clear_call_wave_buttons()
	wave_break_timer.stop()

	# Start next wave immediately
	start_next_wave()

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
