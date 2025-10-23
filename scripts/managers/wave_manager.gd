extends Node2D

# ============================================
# WAVE MANAGER - Spawns enemies in waves
# ============================================

# REFERENCES (drag these from Scene tree in Inspector)
@export var enemy_path: Path2D  # The path enemies follow (OLD SYSTEM)
@export var start_waypoint: PathWaypoint  # Starting waypoint (NEW SYSTEM - optional)
@export var use_waypoint_system: bool = false  # Toggle between old Path2D and new waypoint system
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
var tracked_enemies: Dictionary = {}  # Dictionary of all living enemies (enemy_instance: true)
var is_combat_active: bool = false  # Whether a wave is currently active
var victory_screen_shown: bool = false  # Guard to prevent showing victory twice

# COMBAT STATE SIGNALS
signal combat_started()
signal combat_ended()

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
var position_offset_x = 60.0  # Random X offset range (-60 to +60) - increased for more spread
var position_offset_y = 50.0  # Random Y offset range (-50 to +50) - increased for more spread
var speed_variation_min = 0.7  # Minimum speed multiplier (70% of base speed) - increased range
var speed_variation_max = 1.3  # Maximum speed multiplier (130% of base speed) - increased range

# LANE SYSTEM SETTINGS (creates parallel "traffic lanes")
var lane_offsets = [-40.0, 0.0, 40.0]  # Perpendicular offsets for 3 lanes
var use_lane_system = true  # Enable/disable lane-based spawning

# TIMERS
var spawn_timer: Timer
var wave_break_timer: Timer

# VICTORY SCREENS
var loot_distribution_scene = preload("res://scenes/ui/loot_distribution_screen.tscn")
var victory_screen_scene = preload("res://scenes/ui/victory_screen.tscn")

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# This runs once when the level starts
	# Load waves from LevelManager if available
	if LevelManager.current_level:
		waves = LevelManager.current_level.waves.duplicate()
	else:
		# EDITOR TESTING MODE: If testing directly from F5, initialize GameStateManager manually
		push_warning("[WaveManager] No current_level found - you're testing from editor!")
		push_warning("[WaveManager] Loading default level config for testing...")

		# Try to load level_01_config for testing
		var test_config = load("res://data/level_configs/level_01_config.tres") as LevelConfig
		if test_config:
			GameStateManager.initialize_level(test_config)
			print("[WaveManager] GameStateManager initialized with test config (starting gold: %d)" % GameStateManager.gold)

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

	# Start balance tracking
	if BalanceTracker:
		var level_id = LevelManager.current_level.level_id if LevelManager.current_level else "unknown"
		BalanceTracker.start_run(level_id)

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
	print("[WaveManager] Combat started - Wave ", current_wave)

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

	# Award wave completion bonus (20g per wave)
	var wave_bonus = 20
	GameStateManager.add_gold(wave_bonus)
	print("[WaveManager] Wave completion bonus: +%dg" % wave_bonus)

	# Track wave bonus in BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_wave_bonus(current_wave, wave_bonus)

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
			victory_screen_shown = false  # Reset flag if verification failed
			return  # Don't show victory yet

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

		print("[WaveManager] Spawned ", enemy_type, " using WAYPOINT system")

	else:
		# OLD PATH2D SYSTEM
		if enemy_path == null:
			print("ERROR: No enemy path assigned!")
			return

		# Create PathFollow2D
		var path_follower = PathFollow2D.new()
		path_follower.loop = false
		path_follower.rotates = false  # Don't rotate enemy to follow path direction
		enemy_path.add_child(path_follower)

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

		print("[WaveManager] Spawned ", enemy_type, " using PATH2D system")
	
	# Connect death signal with enemy reference binding
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

	# Apply per-wave stat modifiers from WaveData
	if current_wave_data:
		_apply_wave_modifiers(enemy, enemy_type)

	# Add enemy to tracking dictionary
	tracked_enemies[enemy] = true
	print("Enemy spawned. Tracked count: ", tracked_enemies.size())

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

func _on_enemy_died(enemy):
	# Called when an enemy dies or reaches the end
	# NEW: Roll loot for the enemy
	if is_instance_valid(enemy):
		_roll_loot_for_enemy(enemy)

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
	var level_id = "level_01"  # Default
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
		await _show_loot_distribution_screen(stars, gems_earned)
	else:
		print("[WaveManager] No loot to distribute, skipping loot screen")

	# NEW: Skip victory screen, go directly to world map (user's requested flow)
	print("[WaveManager] Loot complete, returning to world map...")

	# Unpause the game before changing scenes
	get_tree().paused = false

	# Change to world map scene
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")

	print("[WaveManager] Scene change to world map initiated")


func _show_loot_distribution_screen(stars: int, gems_earned: int):
	"""Show loot distribution screen and wait for user to continue"""
	# Create canvas layer for loot screen
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 99  # Below victory screen but above gameplay
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	# Instantiate loot distribution screen
	var loot_screen = loot_distribution_scene.instantiate()

	# Set stars earned and gems (must set BEFORE adding to tree)
	loot_screen.stars_earned = stars
	if loot_screen.has_method("set_gems_earned") or "gems_earned" in loot_screen:
		loot_screen.gems_earned = gems_earned

	# Add to scene tree
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(loot_screen)

	# Wait for user to finish distributing loot
	await loot_screen.continue_to_victory

	print("[WaveManager] Loot distribution complete, continuing to results screen")

func _calculate_stars() -> int:
	# Star calculation based on lives remaining (10 waves is harder!)
	# 3 stars: 16+ lives (80%+ health)
	# 2 stars: 10-15 lives (50-75% health)
	# 1 star: 1-9 lives (survived but barely)
	var lives_left = GameStateManager.lives

	if lives_left >= 16:
		return 3
	elif lives_left >= 10:
		return 2
	else:
		return 1

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
			gems_to_award = level_config.three_star_gold_bonus  # TODO: Rename to three_star_gem_reward
		2:
			gems_to_award = level_config.two_star_gold_bonus    # TODO: Rename to two_star_gem_reward
		1:
			gems_to_award = level_config.one_star_gold_bonus    # TODO: Rename to one_star_gem_reward
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
		enemy.current_health = new_hp  # Also update current health
		print("[WaveManager] Wave %d: %s HP scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_hp, new_hp, hp_mult])

	# Apply gold multiplier
	if gold_mult != 1.0 and "gold_reward" in enemy:
		var original_gold = enemy.gold_reward
		var new_gold = int(original_gold * gold_mult)
		enemy.gold_reward = new_gold
		print("[WaveManager] Wave %d: %s gold scaled %d → %d (×%.1f)" % [current_wave, enemy_type, original_gold, new_gold, gold_mult])

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

	# Tier 1: Weak enemies (goblins, bats)
	if "goblin" in enemy_name or "bat" in enemy_name:
		return "tier1"

	# Tier 2: Medium enemies (wolves, orcs)
	elif "wolf" in enemy_name or "orc" in enemy_name:
		return "tier2"

	# Tier 3: Strong enemies (trolls, elites)
	elif "troll" in enemy_name or "elite" in enemy_name:
		return "tier3"

	# Default to tier 1
	return "tier1"


func _is_boss_enemy(enemy) -> bool:
	"""Check if an enemy is a boss"""
	var enemy_name = enemy.name.to_lower()
	return "boss" in enemy_name or (enemy.has_method("is_boss") and enemy.is_boss())
