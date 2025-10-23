extends Node
class_name AIController

## ============================================
## AI CONTROLLER - Autonomous game player
## ============================================
##
## This AI controller plays the tower defense game automatically
## using rule-based strategies to test game balance.
##
## Usage:
##   var ai = AIController.new()
##   ai.set_strategy("Archer Rush")
##   ai.initialize()
##   # AI will play automatically
## ============================================

# ============================================
# STRATEGY CONFIGURATION
# ============================================

enum Strategy {
	ARCHER_RUSH,      # Aggressive archer spam
	SOLDIER_WALL,     # Defensive soldier blocking
	GREEDY_ECONOMY    # Save gold, heavy upgrades
}

var current_strategy: Strategy = Strategy.ARCHER_RUSH
var strategy_name: String = "Archer Rush"

# ============================================
# GAME STATE REFERENCES
# ============================================

var wave_manager: Node = null
var placement_manager: Node = null
var camera: Camera2D = null
var hero_manager: Node = null

# Map analysis cache
var map_data: Dictionary = {}
var tower_spots: Array = []
var enemy_path: Path2D = null

# Hero tracking
var heroes: Array = []
var hero_spots: Array = []

# ============================================
# AI STATE
# ============================================

var is_active: bool = false
var decision_cooldown: float = 0.5  # Seconds between decisions
var last_decision_time: float = 0.0
var hero_positioned_this_level: bool = false  # Track if hero was positioned yet

# Decision history (for analytics)
var decisions_made: Array = []

# ============================================
# LEARNING SYSTEM PARAMETERS
# ============================================

# These can be set by AILearningSystem to modify AI behavior
var hero_position_multiplier: float = 0.6  # 0.0-1.0, where along path to position hero
var tower_focus_strategy: String = "balanced"  # "frontload", "backload", "center_focus", "balanced"
var upgrade_priority: String = "balanced"  # "rush_to_4", "balanced", "save_for_quality"

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Add to group so loot screen can detect AI
	add_to_group("ai_controller")
	print("🤖 AIController initialized")

func initialize():
	"""Initialize AI for current level"""
	print("\n=== 🤖 AI CONTROLLER INITIALIZING ===")

	# Wait for scene to be ready
	await get_tree().process_frame

	# Find game managers
	_find_managers()

	# Analyze the map
	_analyze_map()

	# Connect to victory/defeat detection
	if wave_manager:
		# Monitor when all waves complete
		if not wave_manager.is_connected("combat_ended", _on_wave_manager_combat_ended):
			wave_manager.combat_ended.connect(_on_wave_manager_combat_ended)

	# Start AI decision loop
	is_active = true
	hero_positioned_this_level = false  # Reset for new level

	print("✅ AI Controller ready - Strategy: %s" % strategy_name)
	print("   Tower spots found: %d" % tower_spots.size())
	print("   Path found: %s" % ("Yes" if enemy_path else "No"))
	print("=== ✅ INITIALIZATION COMPLETE ===\n")

func _find_managers():
	"""Find all necessary game managers"""
	# Get root level node
	var level = get_tree().current_scene

	# Find WaveManager
	wave_manager = level.get_node_or_null("WaveManager")
	if not wave_manager:
		wave_manager = get_tree().get_first_node_in_group("wave_manager")

	# Find PlacementManager
	placement_manager = level.get_node_or_null("PlacementManager")
	if not placement_manager:
		placement_manager = get_tree().get_first_node_in_group("placement_manager")

	# Find camera
	camera = get_viewport().get_camera_2d()

	# Find HeroManager
	hero_manager = level.get_node_or_null("HeroManager")
	if not hero_manager:
		hero_manager = get_tree().get_first_node_in_group("hero_manager")

	print("  Managers found:")
	print("    WaveManager: %s" % ("✓" if wave_manager else "✗"))
	print("    PlacementManager: %s" % ("✓" if placement_manager else "✗"))
	print("    Camera: %s" % ("✓" if camera else "✗"))
	print("    HeroManager: %s" % ("✓" if hero_manager else "✗"))

func _analyze_map():
	"""Analyze map structure for strategic decisions"""
	# Find all tower spots
	tower_spots = get_tree().get_nodes_in_group("tower_spot")

	# Find enemy path
	enemy_path = get_tree().get_first_node_in_group("enemy_path")
	if not enemy_path:
		var level = get_tree().current_scene
		enemy_path = level.get_node_or_null("EnemyPath")

	# Analyze each spot
	map_data.spots = []
	for i in range(tower_spots.size()):
		var spot = tower_spots[i]
		var spot_info = {
			"index": i,
			"node": spot,
			"position": spot.global_position,
			"has_tower": spot.has_tower,
			"strategic_value": _calculate_spot_value(spot)
		}
		map_data.spots.append(spot_info)

	# Sort spots by strategic value
	map_data.spots.sort_custom(func(a, b): return a.strategic_value > b.strategic_value)

	# Find hero spots and heroes
	hero_spots = get_tree().get_nodes_in_group("hero_spot")
	_find_heroes()

	print("  Map analysis:")
	for i in range(min(3, map_data.spots.size())):
		var spot = map_data.spots[i]
		print("    Spot %d: Value %.2f" % [spot.index, spot.strategic_value])
	print("  Heroes found: %d" % heroes.size())

# ============================================
# STRATEGIC ANALYSIS
# ============================================

func _calculate_spot_value(spot: Node2D) -> float:
	"""Calculate strategic value of a tower spot (0.0-1.0)"""
	if not enemy_path:
		return 0.5  # Default value if no path

	var score = 0.0
	var spot_pos = spot.global_position

	# Use tower_focus_strategy to determine spot value
	match tower_focus_strategy:
		"frontload":  # Prefer spots near path start
			if enemy_path and enemy_path.curve:
				var path_start = enemy_path.curve.get_point_position(0)
				var dist = spot_pos.distance_to(path_start + enemy_path.global_position)
				score = 1.0 - clamp(dist / 1000.0, 0.0, 0.9)

		"backload":  # Prefer spots near path end
			if enemy_path and enemy_path.curve:
				var path_end = enemy_path.curve.get_point_position(enemy_path.curve.point_count - 1)
				var dist = spot_pos.distance_to(path_end + enemy_path.global_position)
				score = 1.0 - clamp(dist / 1000.0, 0.0, 0.9)

		"center_focus":  # Prefer spots in middle of path
			if enemy_path and enemy_path.curve:
				var path_length = enemy_path.curve.get_baked_length()
				var mid_point = enemy_path.curve.sample_baked(path_length * 0.5)
				var dist = spot_pos.distance_to(mid_point + enemy_path.global_position)
				score = 1.0 - clamp(dist / 800.0, 0.0, 0.9)

		_:  # "balanced" - Use default coverage calculation
			var path_coverage = _calculate_path_coverage(spot_pos, 300.0)
			score = path_coverage * 0.5

			# Add distance to exit factor
			if enemy_path and enemy_path.curve:
				var path_end = enemy_path.curve.get_point_position(enemy_path.curve.point_count - 1)
				var distance_to_exit = spot_pos.distance_to(path_end + enemy_path.global_position)
				var frontline_score = 1.0 - clamp(distance_to_exit / 2000.0, 0.0, 1.0)
				score += frontline_score * 0.3

			# Add distance to start factor
			if enemy_path and enemy_path.curve:
				var path_start = enemy_path.curve.get_point_position(0)
				var distance_to_start = spot_pos.distance_to(path_start + enemy_path.global_position)
				var early_damage_score = 1.0 - clamp(distance_to_start / 1000.0, 0.0, 1.0)
				score += early_damage_score * 0.2

	return clamp(score, 0.1, 1.0)

func _calculate_path_coverage(spot_pos: Vector2, range: float) -> float:
	"""Calculate what percentage of enemy path is within tower range"""
	if not enemy_path or not enemy_path.curve:
		return 0.5

	var points = enemy_path.curve.get_baked_points()
	var points_in_range = 0

	for point in points:
		var world_point = point + enemy_path.global_position
		if spot_pos.distance_to(world_point) <= range:
			points_in_range += 1

	return float(points_in_range) / float(max(points.size(), 1))

# ============================================
# HERO MANAGEMENT
# ============================================

func _find_heroes():
	"""Find all heroes in the scene"""
	heroes.clear()

	# Find heroes by group
	var hero_nodes = get_tree().get_nodes_in_group("hero")

	# Also check hero spots for spawned heroes
	for hero_spot in hero_spots:
		if is_instance_valid(hero_spot) and hero_spot.has_hero and hero_spot.current_hero:
			if not heroes.has(hero_spot.current_hero):
				heroes.append(hero_spot.current_hero)

	# Add any heroes found by group
	for hero in hero_nodes:
		if is_instance_valid(hero) and not heroes.has(hero):
			heroes.append(hero)

func _get_optimal_hero_position(hero: Node2D) -> Vector2:
	"""Calculate the best position for a hero based on enemy flow"""
	if not enemy_path or not enemy_path.curve:
		# No path - keep hero at home
		return hero.home_position if "home_position" in hero else hero.global_position

	# Use hero_position_multiplier (set by learning system or defaults to 0.6)
	var path_length = enemy_path.curve.get_baked_length()
	var sample_point = enemy_path.curve.sample_baked(path_length * hero_position_multiplier)
	var world_pos = sample_point + enemy_path.global_position

	# Offset slightly to the side so hero doesn't block center
	var offset = Vector2(80, 0)  # 80 pixels to the right

	return world_pos + offset

func _should_reposition_hero(hero: Node2D) -> bool:
	"""Determine if hero should be repositioned"""
	if not is_instance_valid(hero):
		return false

	# Don't move hero if in combat
	if "current_state" in hero:
		var state_enum = hero.get("State")
		if state_enum:
			var melee_combat = state_enum.get("MELEE_COMBAT", -1)
			var ranged_combat = state_enum.get("RANGED_COMBAT", -1)
			if hero.current_state == melee_combat or hero.current_state == ranged_combat:
				return false

	# Check if hero is far from optimal position
	var optimal_pos = _get_optimal_hero_position(hero)
	var current_pos = hero.global_position

	# Only reposition if more than 200 pixels away
	return current_pos.distance_to(optimal_pos) > 200.0

# ============================================
# GAME STATE OBSERVATION
# ============================================

func observe_state() -> Dictionary:
	"""Get current game state for decision making"""
	var state = {
		"gold": GameStateManager.gold if GameStateManager else 0,
		"lives": GameStateManager.lives if GameStateManager else 0,
		"wave": wave_manager.current_wave if wave_manager else 0,
		"is_combat_active": wave_manager.is_combat_active if wave_manager else false,
		"enemies": [],
		"tower_spots": [],
		"heroes": [],
		"time": Time.get_ticks_msec() / 1000.0
	}

	# Get enemy information
	if EnemyManager:
		state.enemies = EnemyManager.get_all_enemies()

	# Get tower spot information
	for spot_data in map_data.spots:
		var spot = spot_data.node
		if is_instance_valid(spot):
			state.tower_spots.append({
				"index": spot_data.index,
				"node": spot,  # Include node reference!
				"position": spot.global_position,
				"has_tower": spot.has_tower,
				"current_tower": spot.current_tower if spot.has_tower else null,
				"strategic_value": spot_data.strategic_value
			})

	# Get hero information
	_find_heroes()  # Refresh hero list
	for hero in heroes:
		if is_instance_valid(hero):
			state.heroes.append({
				"node": hero,
				"position": hero.global_position,
				"home_position": hero.home_position if "home_position" in hero else Vector2.ZERO,
				"current_state": hero.current_state if "current_state" in hero else 0,
				"health": hero.current_health if "current_health" in hero else 0,
				"max_health": hero.max_health if "max_health" in hero else 1
			})

	return state

# ============================================
# DECISION MAKING
# ============================================

func _process(delta):
	if not is_active:
		return

	# Rate limit decisions
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_decision_time < decision_cooldown:
		return

	last_decision_time = current_time

	# Observe current state
	var state = observe_state()

	# Make decision based on strategy
	var decision = make_decision(state)

	# Execute decision
	if decision and decision.action != "wait":
		execute_decision(decision)

func make_decision(state: Dictionary) -> Dictionary:
	"""Main decision-making function"""
	match current_strategy:
		Strategy.ARCHER_RUSH:
			return _decide_archer_rush(state)
		Strategy.SOLDIER_WALL:
			return _decide_soldier_wall(state)
		Strategy.GREEDY_ECONOMY:
			return _decide_greedy_economy(state)

	return {"action": "wait", "reason": "no_strategy"}

# ============================================
# STRATEGY 1: ARCHER RUSH
# ============================================

func _decide_archer_rush(state: Dictionary) -> Dictionary:
	"""Aggressive archer spam - build fast, upgrade damage path"""

	# RULE 0: Position heroes strategically (ALWAYS do this first in a new level!)
	if not hero_positioned_this_level and not state.heroes.is_empty():
		for hero_data in state.heroes:
			var hero = hero_data.node
			var optimal_pos = _get_optimal_hero_position(hero)
			var current_pos = hero.global_position

			# Only reposition if hero is not already at optimal position
			if current_pos.distance_to(optimal_pos) > 200.0:
				hero_positioned_this_level = true  # Mark as positioned
				return {
					"action": "move_hero",
					"hero": hero,
					"position": optimal_pos,
					"reason": "archer_rush_hero_positioning",
					"state": state
				}
		# If hero is already at optimal position, mark as positioned anyway
		hero_positioned_this_level = true

	# RULE 1: Choose damage path at level 3 (HIGHEST PRIORITY!)
	var level3_tower = _find_level3_tower_needing_path(state.tower_spots)
	if level3_tower:
		return {
			"action": "choose_damage_path",
			"tower": level3_tower,
			"reason": "archer_rush_damage_focus",
			"state": state
		}

	# RULE 2: Build towers gradually based on wave (don't build all at once!)
	var tower_count = _count_all_towers(state.tower_spots)
	var desired_towers = min(state.wave, 4)  # Wave 1 = 1 tower, Wave 2 = 2 towers, etc.

	if tower_count < desired_towers and state.gold >= 100:  # Archer cost
		var best_spot = _find_best_empty_spot(state.tower_spots)
		if best_spot:
			return {
				"action": "build_tower",
				"tower_type": "archer",
				"spot": best_spot,
				"reason": "archer_rush_gradual_build",
				"state": state
			}

	# RULE 3: Upgrade frontline towers
	if state.gold >= 80 and state.wave >= 2:
		var tower_to_upgrade = _find_tower_to_upgrade(state.tower_spots)
		if tower_to_upgrade:
			return {
				"action": "upgrade_tower",
				"tower": tower_to_upgrade,
				"reason": "archer_rush_upgrade",
				"state": state
			}

	return {"action": "wait", "reason": "saving_gold"}

# ============================================
# STRATEGY 2: SOLDIER WALL
# ============================================

func _decide_soldier_wall(state: Dictionary) -> Dictionary:
	"""Build soldier towers for blocking, archer support"""

	# RULE 1: Build 3 soldiers first
	var soldier_count = _count_tower_type(state.tower_spots, "soldier")
	if soldier_count < 3 and state.gold >= 120:  # Soldier cost
		var best_spot = _find_best_empty_spot(state.tower_spots)
		if best_spot:
			return {
				"action": "build_tower",
				"tower_type": "soldier",
				"spot": best_spot,
				"reason": "soldier_wall_formation",
				"state": state
			}

	# RULE 2: Fill remaining spots with archers
	if state.gold >= 100:
		var best_spot = _find_best_empty_spot(state.tower_spots)
		if best_spot:
			return {
				"action": "build_tower",
				"tower_type": "archer",
				"spot": best_spot,
				"reason": "soldier_wall_support",
				"state": state
			}

	# RULE 3: Upgrade soldiers first
	if state.gold >= 80:
		var soldier_to_upgrade = _find_soldier_to_upgrade(state.tower_spots)
		if soldier_to_upgrade:
			return {
				"action": "upgrade_tower",
				"tower": soldier_to_upgrade,
				"reason": "soldier_wall_upgrade",
				"state": state
			}

	return {"action": "wait", "reason": "saving_gold"}

# ============================================
# STRATEGY 3: GREEDY ECONOMY
# ============================================

func _decide_greedy_economy(state: Dictionary) -> Dictionary:
	"""Save gold, minimal building, heavy upgrades"""

	# RULE 1: Don't build until wave 3
	if state.wave < 3:
		return {"action": "wait", "reason": "greedy_saving_early"}

	# RULE 2: Emergency defense if enemies close
	if state.enemies.size() > 0:
		var closest_distance = _get_closest_enemy_to_exit(state.enemies)
		if closest_distance < 500 and state.gold >= 100:
			var emergency_spot = _find_best_empty_spot(state.tower_spots)
			if emergency_spot:
				return {
					"action": "build_tower",
					"tower_type": "archer",
					"spot": emergency_spot,
					"reason": "greedy_emergency",
					"state": state
				}

	# RULE 3: Only build if gold > 200 (excess)
	if state.gold >= 200:
		var best_spot = _find_best_empty_spot(state.tower_spots)
		if best_spot:
			return {
				"action": "build_tower",
				"tower_type": "archer",
				"spot": best_spot,
				"reason": "greedy_excess_gold",
				"state": state
			}

	# RULE 4: Invest heavily in upgrades
	if state.gold >= 120:  # Save for level 2→3 upgrade
		var tower_to_max = _find_lowest_level_tower(state.tower_spots)
		if tower_to_max:
			return {
				"action": "upgrade_tower",
				"tower": tower_to_max,
				"reason": "greedy_max_upgrade",
				"state": state
			}

	return {"action": "wait", "reason": "greedy_saving"}

# ============================================
# HELPER FUNCTIONS
# ============================================

func _find_best_empty_spot(spots: Array) -> Dictionary:
	"""Find highest value empty spot"""
	for spot_data in spots:
		if not spot_data.has_tower:
			return spot_data
	return {}

func _find_tower_to_upgrade(spots: Array) -> Node:
	"""Find a tower that can be upgraded"""
	for spot_data in spots:
		if spot_data.has_tower and spot_data.current_tower:
			var tower = spot_data.current_tower
			if is_instance_valid(tower) and tower.has_method("can_upgrade"):
				if tower.can_upgrade():
					return tower
	return null

func _find_level3_tower_needing_path(spots: Array) -> Node:
	"""Find a level 3 tower that needs path choice"""
	for spot_data in spots:
		if spot_data.has_tower and spot_data.current_tower:
			var tower = spot_data.current_tower
			if is_instance_valid(tower) and tower.has_method("needs_path_choice"):
				if tower.needs_path_choice():
					return tower
	return null

func _find_lowest_level_tower(spots: Array) -> Node:
	"""Find tower with lowest level for upgrading"""
	var lowest_tower = null
	var lowest_level = 999

	for spot_data in spots:
		if spot_data.has_tower and spot_data.current_tower:
			var tower = spot_data.current_tower
			if is_instance_valid(tower) and "tower_level" in tower:
				if tower.tower_level < lowest_level:
					lowest_level = tower.tower_level
					lowest_tower = tower

	return lowest_tower

func _find_soldier_to_upgrade(spots: Array) -> Node:
	"""Find a soldier tower to upgrade"""
	for spot_data in spots:
		if spot_data.has_tower and spot_data.current_tower:
			var tower = spot_data.current_tower
			if is_instance_valid(tower):
				var scene_path = tower.scene_file_path if "scene_file_path" in tower else ""
				if "soldier" in scene_path.to_lower():
					if tower.has_method("can_upgrade") and tower.can_upgrade():
						return tower
	return null

func _count_tower_type(spots: Array, tower_type: String) -> int:
	"""Count how many towers of a specific type exist"""
	var count = 0
	for spot_data in spots:
		if spot_data.has_tower and spot_data.current_tower:
			var tower = spot_data.current_tower
			if is_instance_valid(tower):
				var scene_path = tower.scene_file_path if "scene_file_path" in tower else ""
				if tower_type.to_lower() in scene_path.to_lower():
					count += 1
	return count

func _count_all_towers(spots: Array) -> int:
	"""Count total number of towers built"""
	var count = 0
	for spot_data in spots:
		if spot_data.has_tower:
			count += 1
	return count

func _get_closest_enemy_to_exit(enemies: Array) -> float:
	"""Get distance of closest enemy to the exit"""
	if enemies.is_empty() or not enemy_path or not enemy_path.curve:
		return 999999.0

	var exit_pos = enemy_path.curve.get_point_position(enemy_path.curve.point_count - 1)
	exit_pos += enemy_path.global_position

	var closest = 999999.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = enemy.global_position.distance_to(exit_pos)
			if dist < closest:
				closest = dist

	return closest

# ============================================
# ACTION EXECUTION
# ============================================

func execute_decision(decision: Dictionary):
	"""Execute an AI decision"""
	print("🤖 AI Decision: %s (%s)" % [decision.action, decision.reason])

	# Record decision for analytics
	_record_decision(decision)

	match decision.action:
		"build_tower":
			_execute_build_tower(decision)
		"upgrade_tower":
			_execute_upgrade_tower(decision)
		"choose_damage_path":
			_execute_choose_damage_path(decision)
		"choose_range_path":
			_execute_choose_range_path(decision)
		"move_hero":
			_execute_move_hero(decision)

func _execute_build_tower(decision: Dictionary):
	"""Build a tower at specified spot"""
	var spot_data = decision.spot
	var tower_type = decision.tower_type

	# Get the actual spot node
	var spot = spot_data.node if "node" in spot_data else null
	if not spot or not is_instance_valid(spot):
		print("  ❌ Invalid spot!")
		return

	# Load tower scene
	var tower_scene_path = "res://scenes/towers/%s_tower.tscn" % tower_type
	if not ResourceLoader.exists(tower_scene_path):
		print("  ❌ Tower scene not found: %s" % tower_scene_path)
		return

	var tower_scene = load(tower_scene_path)

	# Check gold
	var cost = 100 if tower_type == "archer" else 120
	if GameStateManager.gold < cost:
		print("  ❌ Not enough gold! Need %d, have %d" % [cost, GameStateManager.gold])
		return

	# Place tower
	spot.place_tower(tower_scene)
	print("  ✅ Built %s tower at spot %d" % [tower_type, spot_data.index])

func _execute_upgrade_tower(decision: Dictionary):
	"""Upgrade a tower"""
	var tower = decision.tower
	if not tower or not is_instance_valid(tower):
		print("  ❌ Invalid tower!")
		return

	if tower.has_method("upgrade_tower"):
		var success = tower.upgrade_tower()
		if success:
			print("  ✅ Upgraded tower to level %d" % tower.tower_level)
		else:
			print("  ❌ Upgrade failed!")
	else:
		print("  ❌ Tower has no upgrade_tower method!")

func _execute_choose_damage_path(decision: Dictionary):
	"""Choose damage path for level 3 tower"""
	var tower = decision.tower
	if not tower or not is_instance_valid(tower):
		print("  ❌ Invalid tower!")
		return

	if tower.has_method("choose_damage_path"):
		var success = tower.choose_damage_path()
		if success:
			print("  ✅ Chose damage path")
		else:
			print("  ❌ Path choice failed!")

func _execute_choose_range_path(decision: Dictionary):
	"""Choose range path for level 3 tower"""
	var tower = decision.tower
	if not tower or not is_instance_valid(tower):
		print("  ❌ Invalid tower!")
		return

	if tower.has_method("choose_range_path"):
		var success = tower.choose_range_path()
		if success:
			print("  ✅ Chose range path")
		else:
			print("  ❌ Path choice failed!")

func _execute_move_hero(decision: Dictionary):
	"""Move hero to a new position"""
	var hero = decision.hero
	var position = decision.position

	if not hero or not is_instance_valid(hero):
		print("  ❌ Invalid hero!")
		return

	# Check if hero has move_to_position method
	if hero.has_method("move_to_position"):
		hero.move_to_position(position)
		print("  ✅ Moved hero to position: (%d, %d)" % [position.x, position.y])
	else:
		print("  ❌ Hero has no move_to_position method!")

# ============================================
# DECISION LOGGING
# ============================================

func _record_decision(decision: Dictionary):
	"""Record decision for analytics"""
	var record = {
		"time": Time.get_ticks_msec() / 1000.0,
		"action": decision.action,
		"reason": decision.reason,
		"gold": decision.state.gold if "state" in decision else 0,
		"wave": decision.state.wave if "state" in decision else 0
	}

	decisions_made.append(record)

	# Also record in BalanceTracker if available
	if BalanceTracker and BalanceTracker.has_method("record_ai_decision"):
		BalanceTracker.record_ai_decision(
			decision.action,
			decision.get("spot", {}).get("index", -1),
			decision.reason,
			decision.state.gold if "state" in decision else 0
		)

# ============================================
# CONTROL METHODS
# ============================================

func set_strategy(strategy_name_input: String):
	"""Set AI strategy by name"""
	strategy_name = strategy_name_input

	match strategy_name.to_lower():
		"archer rush", "archer_rush":
			current_strategy = Strategy.ARCHER_RUSH
		"soldier wall", "soldier_wall":
			current_strategy = Strategy.SOLDIER_WALL
		"greedy economy", "greedy_economy", "greedy":
			current_strategy = Strategy.GREEDY_ECONOMY
		_:
			print("⚠️ Unknown strategy: %s, defaulting to Archer Rush" % strategy_name)
			current_strategy = Strategy.ARCHER_RUSH
			strategy_name = "Archer Rush"

	print("🎯 Strategy set to: %s" % strategy_name)

func start():
	"""Start AI"""
	is_active = true
	print("▶️ AI started")

func stop():
	"""Stop AI"""
	is_active = false
	print("⏹ AI stopped")

func pause():
	"""Pause AI"""
	is_active = false
	print("⏸ AI paused")

func resume():
	"""Resume AI"""
	is_active = true
	print("▶️ AI resumed")

func get_decisions() -> Array:
	"""Get all decisions made by AI"""
	return decisions_made.duplicate()

func clear_decisions():
	"""Clear decision history"""
	decisions_made.clear()

# ============================================
# LEVEL PROGRESSION
# ============================================

func _on_wave_manager_combat_ended():
	"""Called when a wave ends - check if level is complete"""
	if not wave_manager:
		return

	# Check if this was the last wave
	if wave_manager.current_wave >= wave_manager.waves.size():
		print("\n🎉 [AI] LEVEL COMPLETE! Checking for next level...")

		# Stop the AI to prevent decisions during scene transition
		is_active = false

		# Check if there's a next level
		var next_level = LevelManager.get_next_level()

		if next_level:
			print("📋 [AI] Next level found: %s" % next_level.level_name)
			print("🔄 [AI] Auto-loading next level...")

			# Wait a brief moment for wave_completed() to finish
			await get_tree().create_timer(0.5).timeout

			# INTERCEPT: Load next level BEFORE victory screen appears
			# This prevents the world map redirect
			LevelManager.load_level_config(next_level, LevelManager.current_campaign)

			# Note: Scene changes immediately, ai_test_simple.gd will reinitialize AI
		else:
			print("🏆 [AI] NO MORE LEVELS - Campaign complete!")
			print("🛑 [AI] Letting normal victory flow continue...")
