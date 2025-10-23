extends Node

## ============================================
## AI LEARNING SYSTEM
## ============================================
## Plays Level 1 hundreds of times with different strategies
## Learns which approaches work best
## Generates a balance analysis report with suggestions
## ============================================

# Learning configuration
@export var total_games_to_play: int = 100
@export var show_progress: bool = true

# Current game state
var games_played: int = 0
var current_strategy: Dictionary = {}

# AI controller
var ai_controller: AIController = null

# All game results
var all_results: Array = []

# Strategy parameters to test
var hero_positions = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]  # % along path
var tower_spot_priorities = []  # Will be filled based on spots available
var upgrade_strategies = ["rush_to_4", "balanced", "save_for_quality"]

# Learning data
var strategy_performance: Dictionary = {}

# Start time
var learning_start_time: float = 0.0

func _ready():
	var separator = "======================================================================"
	print("\n" + separator)
	print("🧠 AI LEARNING SYSTEM - LEVEL 1 MASS TESTING")
	print(separator)
	print("   Total games to play: %d" % total_games_to_play)
	print("   Target level: forest_01 (Level 1)")
	print(separator + "\n")

	learning_start_time = Time.get_ticks_msec() / 1000.0

	# Wait for scene to load
	await get_tree().process_frame
	await get_tree().process_frame

	# CRITICAL: Clear any saved progress to ensure fresh start
	_reset_campaign_progress()

	# Ensure we're on Level 1
	if not _ensure_level_1():
		print("❌ ERROR: Not on Level 1! Please start from Level 1.")
		return

	# Create AI controller
	ai_controller = AIController.new()
	add_child(ai_controller)

	# Start first game
	_start_next_game()

func _reset_campaign_progress():
	"""Reset campaign progress to ensure fresh start for learning"""
	print("🔄 Resetting campaign progress for fresh start...")

	# Reset GameStateManager to default state
	if GameStateManager:
		if GameStateManager.has_method("reset_to_defaults"):
			GameStateManager.reset_to_defaults()
		else:
			# Manual reset
			GameStateManager.gold = 150  # Starting gold for Level 1
			GameStateManager.lives = 20  # Starting lives for Level 1

	# Clear any loot or inventory data
	if InventoryManager and InventoryManager.has_method("clear"):
		InventoryManager.clear()

	print("✅ Campaign progress reset complete")

func _ensure_level_1() -> bool:
	"""Make sure we're on forest_01"""
	if LevelManager.current_level:
		if LevelManager.current_level.level_id == "forest_01":
			return true

	# Try to load Level 1
	var campaign = LevelManager.get_campaign("forest")
	if campaign:
		var level = campaign.get_level_by_id("forest_01")
		if level:
			LevelManager.current_level = level
			LevelManager.current_campaign = campaign
			return true

	return false

## ============================================
## GAME LOOP
## ============================================

func _start_next_game():
	"""Start the next game with a new strategy"""
	games_played += 1

	if games_played > total_games_to_play:
		# Learning complete!
		_finish_learning()
		return

	# Generate random strategy for this game
	current_strategy = _generate_random_strategy()

	if show_progress:
		print("\n🎮 GAME %d/%d" % [games_played, total_games_to_play])
		print("   Hero position: %.0f%% along path" % (current_strategy.hero_pos * 100))
		print("   Tower priority: %s" % current_strategy.tower_focus)
		print("   Upgrade strategy: %s" % current_strategy.upgrade_strat)

	# Apply strategy to AI
	_apply_strategy_to_ai(current_strategy)

	# Initialize AI for this run
	ai_controller.set_strategy("Archer Rush")
	await ai_controller.initialize()

	# Connect to game end
	if ai_controller.wave_manager:
		if not ai_controller.wave_manager.is_connected("combat_ended", _on_game_ended):
			ai_controller.wave_manager.combat_ended.connect(_on_game_ended)

func _generate_random_strategy() -> Dictionary:
	"""Generate a random strategy to test"""
	var strategy = {}

	# Random hero position
	strategy.hero_pos = hero_positions[randi() % hero_positions.size()]

	# Random tower focus (frontload vs backload vs balanced)
	var tower_focuses = ["frontload", "backload", "balanced", "center_focus"]
	strategy.tower_focus = tower_focuses[randi() % tower_focuses.size()]

	# Random upgrade strategy
	strategy.upgrade_strat = upgrade_strategies[randi() % upgrade_strategies.size()]

	# Random path choice (damage vs range)
	strategy.path_choice = "damage" if randf() > 0.5 else "range"

	# Hero behavior (aggressive vs defensive)
	strategy.hero_behavior = "aggressive" if randf() > 0.3 else "defensive"

	return strategy

func _apply_strategy_to_ai(strategy: Dictionary):
	"""Apply the current strategy to the AI controller"""
	# Set AI parameters instead of overriding functions
	ai_controller.hero_position_multiplier = strategy.hero_pos
	ai_controller.tower_focus_strategy = strategy.tower_focus
	ai_controller.upgrade_priority = strategy.upgrade_strat

	if show_progress:
		print("   → Applied: hero_pos=%.1f, towers=%s, upgrades=%s" % [
			strategy.hero_pos,
			strategy.tower_focus,
			strategy.upgrade_strat
		])

func _calculate_path_coverage(spot_pos: Vector2, range: float) -> float:
	"""Calculate what percentage of enemy path is within tower range"""
	if not ai_controller.enemy_path or not ai_controller.enemy_path.curve:
		return 0.5

	var points = ai_controller.enemy_path.curve.get_baked_points()
	var points_in_range = 0

	for point in points:
		var world_point = point + ai_controller.enemy_path.global_position
		if spot_pos.distance_to(world_point) <= range:
			points_in_range += 1

	return float(points_in_range) / float(max(points.size(), 1))

## ============================================
## RESULT TRACKING
## ============================================

func _on_game_ended():
	"""Called when wave ends - check if game is over"""
	# Safety check
	if not is_inside_tree():
		return

	await get_tree().create_timer(0.5).timeout

	# Check if all waves complete
	if ai_controller and ai_controller.wave_manager:
		if ai_controller.wave_manager.current_wave >= ai_controller.wave_manager.waves.size():
			# Game complete - record result
			_record_game_result("victory")

			# Small delay before next game
			if is_inside_tree():
				await get_tree().create_timer(1.0).timeout

			# Reload level for next game
			_reload_level_1()

func _record_game_result(outcome: String):
	"""Record the result of this game"""
	var result = {
		"game_number": games_played,
		"strategy": current_strategy.duplicate(),
		"outcome": outcome,
		"lives": GameStateManager.lives if GameStateManager else 0,
		"gold": GameStateManager.gold if GameStateManager else 0,
		"time": (Time.get_ticks_msec() / 1000.0) - learning_start_time
	}

	all_results.append(result)

	# Update strategy performance tracking
	var strat_key = _get_strategy_key(current_strategy)
	if not strategy_performance.has(strat_key):
		strategy_performance[strat_key] = {
			"wins": 0,
			"total_games": 0,
			"total_lives": 0,
			"strategy": current_strategy.duplicate()
		}

	strategy_performance[strat_key].total_games += 1
	strategy_performance[strat_key].total_lives += result.lives

	if outcome == "victory":
		strategy_performance[strat_key].wins += 1

	if show_progress and games_played % 10 == 0:
		var elapsed = (Time.get_ticks_msec() / 1000.0) - learning_start_time
		var wins = _count_wins()
		var win_rate = (float(wins) / games_played) * 100.0
		print("\n📊 Progress: %d/%d games | Win rate: %.1f%% | Time: %.1fs" % [games_played, total_games_to_play, win_rate, elapsed])

func _get_strategy_key(strategy: Dictionary) -> String:
	"""Create a unique key for this strategy combination"""
	return "%s_%s_%s_%s" % [
		str(strategy.hero_pos),
		strategy.tower_focus,
		strategy.upgrade_strat,
		strategy.path_choice
	]

func _count_wins() -> int:
	"""Count total victories"""
	var wins = 0
	for result in all_results:
		if result.outcome == "victory":
			wins += 1
	return wins

func _reload_level_1():
	"""Reload Level 1 for next game"""
	# Safety check
	if not is_inside_tree():
		return

	# Reset campaign progress before reloading
	_reset_campaign_progress()

	var campaign = LevelManager.get_campaign("forest")
	if campaign:
		var level = campaign.get_level_by_id("forest_01")
		if level:
			LevelManager.load_level_config(level, campaign)
			# Wait for level to load
			if is_inside_tree():
				await get_tree().create_timer(0.5).timeout
			# Start next game
			_start_next_game()

## ============================================
## LEARNING ANALYSIS
## ============================================

func _finish_learning():
	"""All games complete - analyze results and generate report"""
	var elapsed_time = (Time.get_ticks_msec() / 1000.0) - learning_start_time
	var separator = "======================================================================"

	print("\n" + separator)
	print("🎓 LEARNING COMPLETE!")
	print(separator)
	print("   Total games: %d" % games_played)
	print("   Total time: %.1f seconds (%.1f minutes)" % [elapsed_time, elapsed_time / 60.0])
	print("   Wins: %d (%.1f%%)" % [_count_wins(), (float(_count_wins()) / games_played) * 100.0])
	print(separator + "\n")

	# Analyze results
	var analysis = _analyze_learning_data()

	# Generate report
	_generate_report(analysis)

	# Save raw data
	_save_raw_data()

	print("\n✅ Learning complete! Check the generated report for AI insights.")
	print("\n" + separator)

func _analyze_learning_data() -> Dictionary:
	"""Analyze all results to find patterns"""
	var analysis = {}

	# Find best overall strategy
	var best_strat = null
	var best_score = 0.0

	for strat_key in strategy_performance:
		var perf = strategy_performance[strat_key]
		var win_rate = float(perf.wins) / float(perf.total_games)
		var avg_lives = float(perf.total_lives) / float(perf.total_games)

		# Score = win_rate * 100 + avg_lives
		var score = win_rate * 100.0 + avg_lives

		if score > best_score:
			best_score = score
			best_strat = perf

	analysis.best_strategy = best_strat

	# Analyze hero positions
	analysis.hero_analysis = _analyze_hero_positions()

	# Analyze tower strategies
	analysis.tower_analysis = _analyze_tower_strategies()

	# Analyze upgrade strategies
	analysis.upgrade_analysis = _analyze_upgrade_strategies()

	return analysis

func _analyze_hero_positions() -> Dictionary:
	"""Analyze which hero positions work best"""
	var pos_stats = {}

	for result in all_results:
		var pos = result.strategy.hero_pos
		var pos_key = "%.1f" % pos

		if not pos_stats.has(pos_key):
			pos_stats[pos_key] = {"wins": 0, "games": 0, "total_lives": 0}

		pos_stats[pos_key].games += 1
		pos_stats[pos_key].total_lives += result.lives

		if result.outcome == "victory":
			pos_stats[pos_key].wins += 1

	# Find best position
	var best_pos = null
	var best_win_rate = 0.0

	for pos_key in pos_stats:
		var stats = pos_stats[pos_key]
		var win_rate = float(stats.wins) / float(stats.games)

		if win_rate > best_win_rate:
			best_win_rate = win_rate
			best_pos = pos_key

	return {
		"all_positions": pos_stats,
		"best_position": best_pos,
		"best_win_rate": best_win_rate
	}

func _analyze_tower_strategies() -> Dictionary:
	"""Analyze which tower placement strategies work best"""
	var tower_stats = {}

	for result in all_results:
		var focus = result.strategy.tower_focus

		if not tower_stats.has(focus):
			tower_stats[focus] = {"wins": 0, "games": 0, "total_lives": 0}

		tower_stats[focus].games += 1
		tower_stats[focus].total_lives += result.lives

		if result.outcome == "victory":
			tower_stats[focus].wins += 1

	# Find best strategy
	var best_focus = null
	var best_win_rate = 0.0

	for focus in tower_stats:
		var stats = tower_stats[focus]
		var win_rate = float(stats.wins) / float(stats.games)

		if win_rate > best_win_rate:
			best_win_rate = win_rate
			best_focus = focus

	return {
		"all_strategies": tower_stats,
		"best_strategy": best_focus,
		"best_win_rate": best_win_rate
	}

func _analyze_upgrade_strategies() -> Dictionary:
	"""Analyze which upgrade paths work best"""
	var upgrade_stats = {}

	for result in all_results:
		var strat = result.strategy.upgrade_strat

		if not upgrade_stats.has(strat):
			upgrade_stats[strat] = {"wins": 0, "games": 0, "total_lives": 0}

		upgrade_stats[strat].games += 1
		upgrade_stats[strat].total_lives += result.lives

		if result.outcome == "victory":
			upgrade_stats[strat].wins += 1

	return {"all_strategies": upgrade_stats}

## ============================================
## REPORT GENERATION
## ============================================

func _generate_report(analysis: Dictionary):
	"""Generate AI analysis report with balance suggestions"""
	var report = []
	var separator = "======================================================================"

	report.append(separator)
	report.append("🤖 AI LEARNING SYSTEM - BALANCE ANALYSIS REPORT")
	report.append(separator)
	report.append("")
	report.append("LEVEL: Forest Entrance (forest_01)")
	report.append("GAMES PLAYED: %d" % games_played)
	report.append("OVERALL WIN RATE: %.1f%%" % ((float(_count_wins()) / games_played) * 100.0))
	report.append("")

	# Best strategy found
	if analysis.best_strategy:
		var best = analysis.best_strategy
		var win_rate = float(best.wins) / float(best.total_games) * 100.0
		var avg_lives = float(best.total_lives) / float(best.total_games)

		report.append(separator)
		report.append("🏆 BEST STRATEGY DISCOVERED")
		report.append(separator)
		report.append("Hero Position: %.0f%% along path" % (best.strategy.hero_pos * 100))
		report.append("Tower Focus: %s" % best.strategy.tower_focus)
		report.append("Upgrade Strategy: %s" % best.strategy.upgrade_strat)
		report.append("Path Choice: %s" % best.strategy.path_choice)
		report.append("")
		report.append("Performance:")
		report.append("  - Win Rate: %.1f%% (%d/%d games)" % [win_rate, best.wins, best.total_games])
		report.append("  - Average Lives Remaining: %.1f" % avg_lives)
		report.append("")

	# Hero position analysis
	if analysis.hero_analysis:
		var hero = analysis.hero_analysis
		report.append(separator)
		report.append("🦸 HERO POSITION ANALYSIS")
		report.append(separator)
		report.append("Best Position: %s%% along path (%.1f%% win rate)" % [
			float(hero.best_position) * 100,
			hero.best_win_rate * 100
		])
		report.append("")
		report.append("All Positions Tested:")

		for pos_key in hero.all_positions:
			var stats = hero.all_positions[pos_key]
			var wr = float(stats.wins) / float(stats.games) * 100.0
			var al = float(stats.total_lives) / float(stats.games)
			report.append("  %.0f%%: %d wins/%d games (%.1f%% WR, %.1f avg lives)" % [
				float(pos_key) * 100,
				stats.wins,
				stats.games,
				wr,
				al
			])

		report.append("")

	# Tower strategy analysis
	if analysis.tower_analysis:
		var tower = analysis.tower_analysis
		report.append(separator)
		report.append("🏰 TOWER PLACEMENT ANALYSIS")
		report.append(separator)
		report.append("Best Strategy: %s (%.1f%% win rate)" % [
			tower.best_strategy,
			tower.best_win_rate * 100
		])
		report.append("")
		report.append("All Strategies Tested:")

		for focus in tower.all_strategies:
			var stats = tower.all_strategies[focus]
			var wr = float(stats.wins) / float(stats.games) * 100.0
			var al = float(stats.total_lives) / float(stats.games)
			report.append("  %s: %d wins/%d games (%.1f%% WR, %.1f avg lives)" % [
				focus,
				stats.wins,
				stats.games,
				wr,
				al
			])

		report.append("")

	# AI Suggestions
	report.append(separator)
	report.append("💡 AI BALANCE SUGGESTIONS")
	report.append(separator)
	report.append("")

	# Generate suggestions based on data
	report.append(_generate_balance_suggestions(analysis))

	report.append("")
	report.append(separator)
	report.append("END OF REPORT")
	report.append(separator)

	# Print report
	for line in report:
		print(line)

	# Save report to file
	_save_report(report)

func _generate_balance_suggestions(analysis: Dictionary) -> String:
	"""Generate AI balance suggestions based on learning"""
	var suggestions = []

	var win_rate = (float(_count_wins()) / games_played) * 100.0

	if win_rate > 95.0:
		suggestions.append("⚠️  LEVEL TOO EASY - Win rate is %.1f%%" % win_rate)
		suggestions.append("   Recommendation: Increase enemy HP or add more enemies")
		suggestions.append("")

	elif win_rate < 50.0:
		suggestions.append("⚠️  LEVEL TOO HARD - Win rate is only %.1f%%" % win_rate)
		suggestions.append("   Recommendation: Reduce enemy HP or give more starting gold")
		suggestions.append("")

	# Hero position insights
	if analysis.hero_analysis:
		var hero = analysis.hero_analysis
		var best_pos_percent = float(hero.best_position) * 100

		if best_pos_percent < 30:
			suggestions.append("🦸 Hero performs best in DEFENSIVE position (%.0f%% along path)" % best_pos_percent)
			suggestions.append("   This suggests enemies are too strong in early waves")
			suggestions.append("")

		elif best_pos_percent > 70:
			suggestions.append("🦸 Hero performs best in AGGRESSIVE position (%.0f%% along path)" % best_pos_percent)
			suggestions.append("   This suggests hero damage is very effective")
			suggestions.append("   Consider: Reduce hero damage or increase enemy HP")
			suggestions.append("")

	# Tower strategy insights
	if analysis.tower_analysis:
		var tower = analysis.tower_analysis
		if tower.best_strategy == "frontload":
			suggestions.append("🏰 Early tower placement is most effective")
			suggestions.append("   This suggests enemies need more HP in later waves")
			suggestions.append("")

		elif tower.best_strategy == "backload":
			suggestions.append("🏰 Late tower placement (near exit) is most effective")
			suggestions.append("   This suggests early waves are too weak")
			suggestions.append("")

	if suggestions.is_empty():
		suggestions.append("✅ Level balance appears reasonable")
		suggestions.append("   Win rate: %.1f%% (target: 60-80%%)" % win_rate)

	return "\n".join(suggestions)

func _save_report(report: Array):
	"""Save report to text file"""
	if not BalanceExporter:
		return

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "AI_LEARNING_REPORT_%s.txt" % timestamp
	var filepath = BalanceExporter.export_dir.path_join(filename)

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		for line in report:
			file.store_line(line)
		file.close()
		print("\n💾 Report saved to: %s" % filepath)

func _save_raw_data():
	"""Save raw results data to JSON"""
	if not BalanceExporter:
		return

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "AI_LEARNING_DATA_%s.json" % timestamp
	var filepath = BalanceExporter.export_dir.path_join(filename)

	var data = {
		"total_games": games_played,
		"all_results": all_results,
		"strategy_performance": strategy_performance
	}

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("💾 Raw data saved to: %s" % filepath)
