extends Node
class_name AIExperimentManager

## ============================================
## AI EXPERIMENT MANAGER
## ============================================
## Runs multiple playthroughs of the same level with different strategies
## to discover optimal tactics and hero usage patterns.
##
## Results are saved for balance analysis.
## ============================================

# Experiment configuration
var experiments_per_level: int = 5  # How many times to replay each level
var current_experiment: int = 0
var experiment_strategies: Array = []

# Results tracking
var experiment_results: Array = []
var current_level_id: String = ""

# Strategy variations
enum HeroPosition {
	FRONTLINE,   # Aggressive - hero fights at 60% path
	MIDLINE,     # Balanced - hero at 40% path
	BACKLINE,    # Defensive - hero at 20% path (near exit)
	FLANKING,    # Side positioning - offset from path
	MOBILE       # Hero repositions based on enemy density
}

enum TowerStrategy {
	RUSH,        # Many cheap towers, minimal upgrades
	QUALITY,     # Few towers, max upgrades
	BALANCED,    # Mix of quantity and quality
	FRONTLOAD,   # All towers at path start
	REARGUARD    # All towers at path end
}

# Current strategy
var hero_strategy: HeroPosition = HeroPosition.FRONTLINE
var tower_strategy: TowerStrategy = TowerStrategy.BALANCED

signal experiment_complete(results: Dictionary)
signal all_experiments_complete(all_results: Array)

func _ready():
	print("🔬 AI Experiment Manager initialized")

## ============================================
## EXPERIMENT CONTROL
## ============================================

func start_experiments_for_level(level_id: String):
	"""Start running experiments on a specific level"""
	current_level_id = level_id
	current_experiment = 0
	experiment_results.clear()

	# Generate strategy combinations to test
	_generate_experiment_strategies()

	print("\n🔬 === STARTING EXPERIMENTS FOR LEVEL: %s ===" % level_id)
	print("   Total experiments: %d" % experiment_strategies.size())
	print("   Strategy combinations:")
	for i in range(experiment_strategies.size()):
		var strat = experiment_strategies[i]
		print("     %d. Hero: %s | Towers: %s" % [i+1, _hero_pos_name(strat.hero), _tower_strat_name(strat.tower)])

	# Start first experiment
	_start_next_experiment()

func _generate_experiment_strategies():
	"""Create all strategy combinations to test"""
	experiment_strategies.clear()

	# Test all hero position variations with different tower strategies
	var hero_positions = [
		HeroPosition.FRONTLINE,
		HeroPosition.MIDLINE,
		HeroPosition.BACKLINE,
		HeroPosition.FLANKING,
		HeroPosition.MOBILE
	]

	var tower_strategies = [
		TowerStrategy.RUSH,
		TowerStrategy.QUALITY,
		TowerStrategy.BALANCED
	]

	# If user wants fewer experiments, use subset
	if experiments_per_level <= 5:
		# Just test different hero positions with balanced tower strategy
		for hero_pos in hero_positions:
			experiment_strategies.append({
				"hero": hero_pos,
				"tower": TowerStrategy.BALANCED
			})
	else:
		# Full matrix of combinations
		for hero_pos in hero_positions:
			for tower_strat in tower_strategies:
				experiment_strategies.append({
					"hero": hero_pos,
					"tower": tower_strat
				})

	# Limit to requested number
	if experiment_strategies.size() > experiments_per_level:
		experiment_strategies.resize(experiments_per_level)

func _start_next_experiment():
	"""Start the next experiment in the queue"""
	if current_experiment >= experiment_strategies.size():
		# All experiments complete
		_finish_all_experiments()
		return

	var strategy = experiment_strategies[current_experiment]
	hero_strategy = strategy.hero
	tower_strategy = strategy.tower

	print("\n🔬 === EXPERIMENT %d/%d ===" % [current_experiment + 1, experiment_strategies.size()])
	print("   Hero Position: %s" % _hero_pos_name(hero_strategy))
	print("   Tower Strategy: %s" % _tower_strat_name(tower_strategy))
	print("   Starting level...")

	# Reload the level to start fresh
	_reload_level()

func _reload_level():
	"""Reload the current level to reset for next experiment"""
	# Get the current level config
	var level_config = LevelManager.current_level
	var campaign = LevelManager.current_campaign

	if not level_config or not campaign:
		print("❌ Cannot reload level - no level config found!")
		return

	# Small delay to let previous run clean up
	await get_tree().create_timer(0.5).timeout

	# Reload the level
	LevelManager.load_level_config(level_config, campaign)

## ============================================
## EXPERIMENT RESULTS
## ============================================

func record_experiment_result(outcome: String, stats: Dictionary):
	"""Record the result of the current experiment"""
	var result = {
		"experiment_number": current_experiment + 1,
		"hero_strategy": _hero_pos_name(hero_strategy),
		"tower_strategy": _tower_strat_name(tower_strategy),
		"outcome": outcome,  # "victory" or "defeat"
		"lives_remaining": stats.get("lives", 0),
		"gold_remaining": stats.get("gold", 0),
		"time_seconds": stats.get("time", 0),
		"hero_deaths": stats.get("hero_deaths", 0),
		"towers_built": stats.get("towers_built", 0),
		"total_damage": stats.get("total_damage", 0),
		"hero_damage": stats.get("hero_damage", 0),
		"tower_damage": stats.get("tower_damage", 0)
	}

	experiment_results.append(result)

	print("\n📊 EXPERIMENT %d COMPLETE:" % result.experiment_number)
	print("   Outcome: %s" % outcome.to_upper())
	print("   Lives: %d | Gold: %d | Time: %.1fs" % [result.lives_remaining, result.gold_remaining, result.time_seconds])
	print("   Hero Deaths: %d | Towers Built: %d" % [result.hero_deaths, result.towers_built])

	emit_signal("experiment_complete", result)

	# Move to next experiment
	current_experiment += 1
	await get_tree().create_timer(2.0).timeout  # Brief pause between experiments
	_start_next_experiment()

func _finish_all_experiments():
	"""All experiments complete - analyze results"""
	print("\n🎉 === ALL EXPERIMENTS COMPLETE ===")
	print("   Level: %s" % current_level_id)
	print("   Total runs: %d" % experiment_results.size())

	_analyze_results()

	emit_signal("all_experiments_complete", experiment_results)

	# Save results to file
	_save_results()

func _analyze_results():
	"""Analyze which strategies performed best"""
	if experiment_results.is_empty():
		return

	print("\n📈 === EXPERIMENT ANALYSIS ===")

	# Find best performer
	var best_result = experiment_results[0]
	for result in experiment_results:
		if result.outcome == "victory":
			# Compare victories by lives remaining
			if result.lives_remaining > best_result.lives_remaining:
				best_result = result
		elif best_result.outcome == "defeat":
			# If both defeats, compare by how long they survived
			if result.lives_remaining > best_result.lives_remaining:
				best_result = result

	print("\n🏆 BEST STRATEGY:")
	print("   Hero: %s" % best_result.hero_strategy)
	print("   Towers: %s" % best_result.tower_strategy)
	print("   Result: %s with %d lives remaining" % [best_result.outcome.to_upper(), best_result.lives_remaining])

	# Hero position analysis
	print("\n🦸 HERO POSITION ANALYSIS:")
	var hero_stats = {}
	for result in experiment_results:
		var hero_pos = result.hero_strategy
		if not hero_stats.has(hero_pos):
			hero_stats[hero_pos] = {"wins": 0, "total_lives": 0, "count": 0}

		hero_stats[hero_pos].count += 1
		hero_stats[hero_pos].total_lives += result.lives_remaining
		if result.outcome == "victory":
			hero_stats[hero_pos].wins += 1

	for hero_pos in hero_stats:
		var stats = hero_stats[hero_pos]
		var avg_lives = stats.total_lives / float(stats.count)
		print("   %s: %d wins, avg %.1f lives" % [hero_pos, stats.wins, avg_lives])

	# Tower strategy analysis
	print("\n🏰 TOWER STRATEGY ANALYSIS:")
	var tower_stats = {}
	for result in experiment_results:
		var tower_strat = result.tower_strategy
		if not tower_stats.has(tower_strat):
			tower_stats[tower_strat] = {"wins": 0, "total_lives": 0, "count": 0}

		tower_stats[tower_strat].count += 1
		tower_stats[tower_strat].total_lives += result.lives_remaining
		if result.outcome == "victory":
			tower_stats[tower_strat].wins += 1

	for tower_strat in tower_stats:
		var stats = tower_stats[tower_strat]
		var avg_lives = stats.total_lives / float(stats.count)
		print("   %s: %d wins, avg %.1f lives" % [tower_strat, stats.wins, avg_lives])

func _save_results():
	"""Save experiment results to JSON file"""
	if not BalanceExporter:
		return

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "experiment_%s_%s.json" % [current_level_id, timestamp]
	var filepath = BalanceExporter.export_dir.path_join(filename)

	var data = {
		"level_id": current_level_id,
		"timestamp": timestamp,
		"total_experiments": experiment_results.size(),
		"results": experiment_results
	}

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("\n💾 Results saved to: %s" % filepath)
	else:
		print("❌ Failed to save results!")

## ============================================
## STRATEGY GETTERS
## ============================================

func get_hero_position_multiplier() -> float:
	"""Get path position multiplier based on current hero strategy"""
	match hero_strategy:
		HeroPosition.FRONTLINE:
			return 0.6  # 60% along path
		HeroPosition.MIDLINE:
			return 0.4  # 40% along path
		HeroPosition.BACKLINE:
			return 0.2  # 20% along path (near exit)
		HeroPosition.FLANKING:
			return 0.5  # Middle but offset to side
		HeroPosition.MOBILE:
			return 0.4  # Start at midline, will move dynamically

	return 0.5  # Default

func get_hero_position_offset() -> Vector2:
	"""Get position offset for flanking strategy"""
	if hero_strategy == HeroPosition.FLANKING:
		return Vector2(150, 0)  # Offset to the right side
	return Vector2.ZERO

func should_hero_be_mobile() -> bool:
	"""Check if hero should reposition during combat"""
	return hero_strategy == HeroPosition.MOBILE

func get_tower_build_limit_for_wave(wave: int) -> int:
	"""Get how many towers to build by this wave"""
	match tower_strategy:
		TowerStrategy.RUSH:
			# Build towers quickly
			return wave  # Wave 1 = 1 tower, Wave 2 = 2 towers, etc.
		TowerStrategy.QUALITY:
			# Build fewer towers
			return max(1, wave / 3)  # Wave 1-3 = 1 tower, Wave 4-6 = 2 towers, etc.
		TowerStrategy.BALANCED:
			# Moderate building
			return max(1, wave / 2)  # Wave 1-2 = 1 tower, Wave 3-4 = 2 towers, etc.
		TowerStrategy.FRONTLOAD:
			return wave
		TowerStrategy.REARGUARD:
			return wave

	return wave  # Default

func should_prioritize_upgrades() -> bool:
	"""Should we upgrade existing towers before building new ones?"""
	return tower_strategy == TowerStrategy.QUALITY

func get_tower_spot_priority_multiplier(spot_index: int, total_spots: int) -> float:
	"""Modify spot priority based on tower strategy"""
	match tower_strategy:
		TowerStrategy.FRONTLOAD:
			# Prefer early spots (closer to path start)
			return 1.0 - (float(spot_index) / total_spots) * 0.5
		TowerStrategy.REARGUARD:
			# Prefer late spots (closer to path end)
			return 0.5 + (float(spot_index) / total_spots) * 0.5

	return 1.0  # No modification for other strategies

## ============================================
## HELPER FUNCTIONS
## ============================================

func _hero_pos_name(pos: HeroPosition) -> String:
	match pos:
		HeroPosition.FRONTLINE: return "Frontline"
		HeroPosition.MIDLINE: return "Midline"
		HeroPosition.BACKLINE: return "Backline"
		HeroPosition.FLANKING: return "Flanking"
		HeroPosition.MOBILE: return "Mobile"
	return "Unknown"

func _tower_strat_name(strat: TowerStrategy) -> String:
	match strat:
		TowerStrategy.RUSH: return "Rush"
		TowerStrategy.QUALITY: return "Quality"
		TowerStrategy.BALANCED: return "Balanced"
		TowerStrategy.FRONTLOAD: return "Frontload"
		TowerStrategy.REARGUARD: return "Rearguard"
	return "Unknown"
