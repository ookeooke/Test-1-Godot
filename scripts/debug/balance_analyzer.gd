extends Node

## ============================================
## BALANCE ANALYZER - Generate balance recommendations
## ============================================
##
## Analyzes balance data and generates recommendations for game balancing
## Detects difficulty spikes, undervalued enemies, poor tower placements, etc.
##
## Usage:
##   var recommendations = BalanceAnalyzer.analyze_current_run()
##   var session_analysis = BalanceAnalyzer.analyze_session()
## ============================================

# ============================================
# ============================================
# BALANCE THRESHOLDS (UPDATED: ARCADE MODE)
# ============================================

## Economy
const TARGET_GOLD_PER_HP_MIN = 0.02 # 2% (200 HP = 5g)
const TARGET_GOLD_PER_HP_MAX = 0.05 # 5%
const TARGET_GOLD_EFFICIENCY = 0.90 # 90% of gold should be spent (Aggressive play)
const GOLD_STARVATION_THRESHOLD = 25 # Consider player starved below this

## Towers
const MIN_TOWER_UPTIME = 0.50 # 50% minimum uptime (Towers should be busy in Arcade)
const MIN_TOWER_ACCURACY = 0.60 # 60% minimum accuracy
const TOWER_EFFICIENCY_THRESHOLD = 30.0 # High DPS = High Efficiency target

## Waves
const DIFFICULTY_SPIKE_MULTIPLIER = 3.0 # Spikes are larger in Arcade (Wave 1->8 is 15x)
const MAX_LEAK_RATE = 0.15 # 15% leak rate is acceptable in chaos
const TARGET_WAVE_DURATION_MIN = 20.0 # Seconds
const TARGET_WAVE_DURATION_MAX = 90.0 # Seconds (Wave 8 is long)

## Balance Ratings
const DIFFICULTY_BALANCED_MIN = 0.8
const DIFFICULTY_BALANCED_MAX = 1.2

# ============================================
# ANALYSIS FUNCTIONS
# ============================================

func analyze_current_run() -> Dictionary:
	"""
	Analyze current run data and generate recommendations
	Returns: Dictionary with analysis results and recommendations array
	"""
	var run_data = BalanceTracker.get_current_run_data()

	if run_data.is_empty():
		return {"recommendations": [], "warnings": ["No run data available"]}

	var recommendations = []
	var warnings = []
	var metrics = {}

	# Analyze economy
	var economy_analysis = _analyze_economy(run_data)
	recommendations.append_array(economy_analysis.recommendations)
	warnings.append_array(economy_analysis.warnings)
	metrics["economy"] = economy_analysis.metrics

	# Analyze towers
	var tower_analysis = _analyze_towers(run_data)
	recommendations.append_array(tower_analysis.recommendations)
	warnings.append_array(tower_analysis.warnings)
	metrics["towers"] = tower_analysis.metrics

	# Analyze enemies
	var enemy_analysis = _analyze_enemies(run_data)
	recommendations.append_array(enemy_analysis.recommendations)
	warnings.append_array(enemy_analysis.warnings)
	metrics["enemies"] = enemy_analysis.metrics

	# Analyze waves
	var wave_analysis = _analyze_waves(run_data)
	recommendations.append_array(wave_analysis.recommendations)
	warnings.append_array(wave_analysis.warnings)
	metrics["waves"] = wave_analysis.metrics

	return {
		"recommendations": recommendations,
		"warnings": warnings,
		"metrics": metrics,
		"run_id": run_data.run_id if run_data.has("run_id") else 0
	}

func analyze_session() -> Dictionary:
	"""
	Analyze entire session (all runs) and generate aggregate recommendations
	"""
	var session_data = BalanceTracker.get_session_data()

	if session_data.runs.is_empty():
		return {"recommendations": [], "warnings": ["No session data available"]}

	var recommendations = []
	var warnings = []

	# Aggregate metrics across all runs
	var aggregate_metrics = _aggregate_session_metrics(session_data)

	# Session-level recommendations
	if session_data.runs.size() > 1:
		var win_rate = _calculate_win_rate(session_data)

		if win_rate < 0.3:
			recommendations.append("Session win rate is low (%.0f%%) - game may be too difficult" % (win_rate * 100))
		elif win_rate > 0.9:
			recommendations.append("Session win rate is very high (%.0f%%) - game may be too easy" % (win_rate * 100))

		# Identify problematic waves across runs
		var problematic_waves = _identify_problematic_waves(session_data)
		for wave in problematic_waves:
			recommendations.append("Wave %d has %.0f%% failure rate across %d attempts" % [wave.number, wave.failure_rate * 100, wave.attempts])

	return {
		"recommendations": recommendations,
		"warnings": warnings,
		"aggregate_metrics": aggregate_metrics,
		"run_count": session_data.runs.size()
	}

# ============================================
# ECONOMY ANALYSIS
# ============================================

func _analyze_economy(run_data: Dictionary) -> Dictionary:
	"""Analyze gold economy and spending patterns"""
	var recommendations = []
	var warnings = []
	var metrics = {}

	if not run_data.has("economy"):
		return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

	var economy = run_data.economy

	# Calculate gold metrics
	var total_available = economy.starting_gold + economy.total_earned
	var efficiency = float(economy.total_spent) / float(total_available) if total_available > 0 else 0.0
	var ending_surplus = economy.ending_gold

	metrics["total_available"] = total_available
	metrics["efficiency"] = efficiency
	metrics["ending_surplus"] = ending_surplus

	# Check gold efficiency
	if efficiency < TARGET_GOLD_EFFICIENCY - 0.15:
		recommendations.append("Gold efficiency is low (%.0f%%) - player has too much leftover gold. Consider reducing starting gold or enemy rewards." % (efficiency * 100))
	elif efficiency > TARGET_GOLD_EFFICIENCY + 0.15:
		recommendations.append("Gold efficiency is very high (%.0f%%) - player is resource-starved. Consider increasing starting gold or enemy rewards." % (efficiency * 100))

	# Check starting gold
	if economy.starting_gold < 100:
		warnings.append("Starting gold is low (%d) - may not be enough for initial tower placement" % economy.starting_gold)

	# Detect gold starvation periods (if gold history available)
	if economy.has("gold_history") and economy.gold_history.size() > 0:
		var starvation_periods = _detect_gold_starvation(economy.gold_history, economy.starting_gold)

		for period in starvation_periods:
			warnings.append("Gold starvation detected from %.1fs to %.1fs (player had <%d gold)" % [period.start, period.end, GOLD_STARVATION_THRESHOLD])

	return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

func _detect_gold_starvation(gold_history: Array, starting_gold: int) -> Array:
	"""Detect periods where player had very low gold"""
	var starvation_periods = []
	var current_gold = starting_gold
	var starvation_start = -1.0

	for event in gold_history:
		var time = event.time
		var amount = event.amount

		# Update current gold
		current_gold += amount

		# Check if entering/exiting starvation
		if current_gold < GOLD_STARVATION_THRESHOLD:
			if starvation_start < 0:
				starvation_start = time
		else:
			if starvation_start >= 0:
				starvation_periods.append({
					"start": starvation_start,
					"end": time,
					"duration": time - starvation_start
				})
				starvation_start = -1.0

	# Close any open starvation period
	if starvation_start >= 0 and gold_history.size() > 0:
		var last_time = gold_history[-1].time
		starvation_periods.append({
			"start": starvation_start,
			"end": last_time,
			"duration": last_time - starvation_start
		})

	return starvation_periods

# ============================================
# TOWER ANALYSIS
# ============================================

func _analyze_towers(run_data: Dictionary) -> Dictionary:
	"""Analyze tower performance"""
	var recommendations = []
	var warnings = []
	var metrics = {}

	if not run_data.has("towers") or run_data.towers.is_empty():
		return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

	var underperforming_towers = []
	var total_towers = 0
	var avg_uptime = 0.0
	var avg_dps = 0.0

	# Analyze each tower
	for tower_id in run_data.towers:
		var tower = run_data.towers[tower_id]
		total_towers += 1

		avg_uptime += tower.uptime_percent
		avg_dps += tower.actual_dps

		# Check uptime
		if tower.uptime_percent < MIN_TOWER_UPTIME:
			underperforming_towers.append({
				"type": tower.type,
				"id": tower_id,
				"issue": "low_uptime",
				"value": tower.uptime_percent
			})
			warnings.append("%s (ID:%s) has %.0f%% uptime - poor placement or insufficient enemy density" % [tower.type, tower_id, tower.uptime_percent * 100])

		# Check accuracy
		if tower.accuracy < MIN_TOWER_ACCURACY and tower.shots_fired > 5:
			warnings.append("%s (ID:%s) has %.0f%% accuracy - enemies may be moving too fast or out of range" % [tower.type, tower_id, tower.accuracy * 100])

		# Check damage efficiency
		if tower.damage_per_gold < TOWER_EFFICIENCY_THRESHOLD:
			underperforming_towers.append({
				"type": tower.type,
				"id": tower_id,
				"issue": "low_efficiency",
				"value": tower.damage_per_gold
			})

	# Calculate averages
	if total_towers > 0:
		avg_uptime /= total_towers
		avg_dps /= total_towers

	metrics["avg_uptime"] = avg_uptime
	metrics["avg_dps"] = avg_dps
	metrics["underperforming_count"] = underperforming_towers.size()

	# Overall recommendations
	if avg_uptime < 0.5:
		recommendations.append("Average tower uptime is low (%.0f%%) - consider increasing enemy spawn rate or adjusting tower range/costs" % (avg_uptime * 100))

	return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

# ============================================
# ENEMY ANALYSIS
# ============================================

func _analyze_enemies(run_data: Dictionary) -> Dictionary:
	"""Analyze enemy balance and value"""
	var recommendations = []
	var warnings = []
	var metrics = {}

	if not run_data.has("enemies") or run_data.enemies.is_empty():
		return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

	var undervalued_enemies = []
	var overvalued_enemies = []
	var leaky_enemies = []

	# Analyze each enemy type
	for enemy_type in run_data.enemies:
		var enemy = run_data.enemies[enemy_type]

		# Skip enemies that weren't spawned
		if enemy.spawned == 0:
			continue

		# Calculate gold per HP (assuming we can get enemy HP from enemy type)
		# For now, we'll note enemies outside the target range
		# TODO: Need enemy max_health to calculate gold/HP ratio properly

		# Check leak rate
		if enemy.leak_rate > MAX_LEAK_RATE:
			leaky_enemies.append({
				"type": enemy_type,
				"leak_rate": enemy.leak_rate,
				"leaked": enemy.leaked,
				"spawned": enemy.spawned
			})
			warnings.append("%s leaked %.0f%% of the time (%d/%d) - may be too fast or not enough blocking" % [enemy_type, enemy.leak_rate * 100, enemy.leaked, enemy.spawned])

		# Check average TTK
		if enemy.killed > 0:
			if enemy.avg_ttk < 1.0:
				warnings.append("%s dies very quickly (%.1fs TTK) - may be too weak" % [enemy_type, enemy.avg_ttk])
			elif enemy.avg_ttk > 30.0:
				warnings.append("%s takes very long to kill (%.1fs TTK) - may be damage sponge" % [enemy_type, enemy.avg_ttk])

	metrics["leaky_enemies"] = leaky_enemies.size()
	metrics["undervalued_count"] = undervalued_enemies.size()
	metrics["overvalued_count"] = overvalued_enemies.size()

	return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

# ============================================
# WAVE ANALYSIS
# ============================================

func _analyze_waves(run_data: Dictionary) -> Dictionary:
	"""Analyze wave difficulty progression"""
	var recommendations = []
	var warnings = []
	var metrics = {}

	if not run_data.has("waves") or run_data.waves.is_empty():
		return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

	# Sort waves by number
	var wave_numbers = run_data.waves.keys()
	wave_numbers.sort()

	var previous_wave_hp = 0
	var difficulty_spikes = []

	# Analyze each wave
	for i in range(wave_numbers.size()):
		var wave_num = wave_numbers[i]
		var wave = run_data.waves[wave_num]

		# Calculate wave HP (enemies_spawned is a rough proxy for difficulty)
		var wave_hp_proxy = wave.enemies_spawned * 100 # Rough estimate

		# Check for difficulty spikes
		if i > 0 and previous_wave_hp > 0:
			var difficulty_ratio = float(wave_hp_proxy) / float(previous_wave_hp)

			if difficulty_ratio >= DIFFICULTY_SPIKE_MULTIPLIER:
				difficulty_spikes.append({
					"wave": wave_num,
					"ratio": difficulty_ratio
				})
				warnings.append("Wave %d is %.1fx harder than Wave %d - difficulty spike detected" % [wave_num, difficulty_ratio, wave_numbers[i - 1]])

		# Check wave duration
		if wave.duration < TARGET_WAVE_DURATION_MIN:
			warnings.append("Wave %d completed very quickly (%.1fs) - may be too easy" % [wave_num, wave.duration])
		elif wave.duration > TARGET_WAVE_DURATION_MAX:
			warnings.append("Wave %d took very long (%.1fs) - may be tedious" % [wave_num, wave.duration])

		# Check if lives were lost
		if wave.lives_lost > 0:
			metrics["wave_%d_lives_lost" % wave_num] = wave.lives_lost

		previous_wave_hp = wave_hp_proxy

	metrics["difficulty_spikes"] = difficulty_spikes.size()

	# Overall wave progression recommendation
	if difficulty_spikes.size() >= 2:
		recommendations.append("Multiple difficulty spikes detected - consider smoothing wave progression curve")

	return {"recommendations": recommendations, "warnings": warnings, "metrics": metrics}

# ============================================
# SESSION ANALYSIS
# ============================================

func _aggregate_session_metrics(session_data: Dictionary) -> Dictionary:
	"""Calculate aggregate metrics across all runs in session"""
	var metrics = {
		"total_runs": session_data.runs.size(),
		"victories": 0,
		"defeats": 0,
		"avg_duration": 0.0,
		"avg_stars": 0.0,
		"total_duration": 0.0
	}

	for run in session_data.runs:
		if run.result == "victory":
			metrics.victories += 1
		elif run.result == "defeat":
			metrics.defeats += 1

		metrics.total_duration += run.duration
		metrics.avg_stars += run.stars

	if metrics.total_runs > 0:
		metrics.avg_duration = metrics.total_duration / metrics.total_runs
		metrics.avg_stars = metrics.avg_stars / metrics.total_runs

	return metrics

func _calculate_win_rate(session_data: Dictionary) -> float:
	"""Calculate win rate across all runs"""
	var victories = 0
	var total = session_data.runs.size()

	for run in session_data.runs:
		if run.result == "victory":
			victories += 1

	return float(victories) / float(total) if total > 0 else 0.0

func _identify_problematic_waves(session_data: Dictionary) -> Array:
	"""Find waves that cause failures across multiple runs"""
	var wave_stats = {} # {wave_number: {attempts: int, failures: int}}

	# Aggregate wave data
	for run in session_data.runs:
		if not run.has("waves"):
			continue

		for wave_num in run.waves:
			if not wave_stats.has(wave_num):
				wave_stats[wave_num] = {"attempts": 0, "failures": 0}

			wave_stats[wave_num].attempts += 1

			# Consider it a failure if lives were lost
			var wave = run.waves[wave_num]
			if wave.lives_lost > 2: # More than 2 lives lost = problematic
				wave_stats[wave_num].failures += 1

	# Find waves with high failure rates
	var problematic = []
	for wave_num in wave_stats:
		var stats = wave_stats[wave_num]
		var failure_rate = float(stats.failures) / float(stats.attempts)

		if failure_rate > 0.5 and stats.attempts >= 2: # 50%+ failure rate
			problematic.append({
				"number": wave_num,
				"attempts": stats.attempts,
				"failures": stats.failures,
				"failure_rate": failure_rate
			})

	return problematic
