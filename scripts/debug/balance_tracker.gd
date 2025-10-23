extends Node

## ============================================
## BALANCE TRACKER - Singleton for tracking game balance metrics
## ============================================
##
## Tracks all combat, economy, and performance metrics for balance analysis.
## Use this data to measure tower DPS, enemy difficulty, gold economy, etc.
##
## Usage:
##   BalanceTracker.record_damage(source_id, target, damage, source_type)
##   BalanceTracker.record_kill(source_id, enemy_type, gold_reward)
##   BalanceTracker.start_wave(wave_number)
##   var data = BalanceTracker.get_current_run_data()
## ============================================

# ============================================
# SESSION DATA
# ============================================

## All runs in this session (persists across level replays)
var session_data: Dictionary = {
	"session_id": "",
	"session_start_time": "",
	"runs": []
}

## Current run data (resets each level attempt)
var current_run: Dictionary = {}

## Is tracking currently active?
var is_tracking: bool = false

## Session ID counter
var session_id_counter: int = 0

# ============================================
# CURRENT RUN TRACKING
# ============================================

## Tower instances being tracked {instance_id: tower_data}
var tracked_towers: Dictionary = {}

## Hero instances being tracked {hero_id: hero_data}
var tracked_heroes: Dictionary = {}

## Enemy type statistics {enemy_type: stats}
var enemy_stats: Dictionary = {}

## Wave data {wave_number: wave_data}
var wave_data: Dictionary = {}

## Economy tracking
var economy_data: Dictionary = {}

## Current wave number
var current_wave_number: int = 0

## Run start time
var run_start_time: float = 0.0

## Run result
var run_result: String = "in_progress"  # "victory", "defeat", "in_progress"

## AI decision log (for AI playtesting)
var ai_decision_log: Array = []

## Tower placement positions (for heatmaps)
var tower_placement_positions: Array = []

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("✅ BalanceTracker initialized")
	_init_session()

func _init_session():
	"""Initialize a new session"""
	session_id_counter += 1
	var timestamp = Time.get_datetime_string_from_system()
	session_data = {
		"session_id": "%s_%d" % [timestamp.replace(":", "-"), session_id_counter],
		"session_start_time": timestamp,
		"runs": []
	}
	print("[BalanceTracker] Session started: ", session_data.session_id)

# ============================================
# RUN CONTROL
# ============================================

func start_run(level_id: String = "unknown"):
	"""Start tracking a new level run"""
	if is_tracking:
		push_warning("[BalanceTracker] Already tracking - stopping previous run")
		end_run("aborted")

	is_tracking = true
	run_start_time = Time.get_ticks_msec() / 1000.0
	current_wave_number = 0

	# Initialize run data structure
	current_run = {
		"run_id": session_data.runs.size() + 1,
		"level_id": level_id,
		"start_time": Time.get_datetime_string_from_system(),
		"duration": 0.0,
		"result": "in_progress",
		"stars": 0,
		"lives_remaining": 0,
		"towers": {},
		"heroes": {},
		"enemies": {},
		"waves": {},
		"economy": {
			"starting_gold": GameStateManager.gold if GameStateManager else 0,
			"total_earned": 0,
			"total_spent": 0,
			"ending_gold": 0,
			"completion_bonus": 0,
			"gold_history": []  # [{time: float, amount: int, reason: String}]
		},
		"balance_metrics": {}
	}

	# Clear tracking dictionaries
	tracked_towers.clear()
	tracked_heroes.clear()
	enemy_stats.clear()
	wave_data.clear()
	boss_fights.clear()
	current_boss_type = ""

	# Record starting gold
	if GameStateManager:
		current_run.economy.starting_gold = GameStateManager.gold

	print("[BalanceTracker] Run started: ", level_id)

func end_run(result: String, stars: int = 0):
	"""End the current run and calculate final metrics"""
	if not is_tracking:
		push_warning("[BalanceTracker] Not tracking - cannot end run")
		return

	is_tracking = false
	run_result = result

	# Calculate duration
	var run_end_time = Time.get_ticks_msec() / 1000.0
	current_run.duration = run_end_time - run_start_time
	current_run.result = result
	current_run.stars = stars

	# Record ending gold and lives
	if GameStateManager:
		current_run.economy.ending_gold = GameStateManager.gold
		current_run.lives_remaining = GameStateManager.lives

	# Copy tracked data into run
	current_run.towers = _serialize_tower_data()
	current_run.heroes = _serialize_hero_data()
	current_run.enemies = _serialize_enemy_data()
	current_run.waves = wave_data.duplicate(true)
	current_run["boss_fights"] = boss_fights.duplicate(true)

	# Calculate balance metrics
	current_run.balance_metrics = _calculate_balance_metrics()

	# Add run to session
	session_data.runs.append(current_run.duplicate(true))

	print("[BalanceTracker] Run ended: %s (%.1fs, %d stars)" % [result, current_run.duration, stars])

func reset_run():
	"""Reset current run data (soft reset)"""
	if is_tracking:
		end_run("reset")

	tracked_towers.clear()
	tracked_heroes.clear()
	enemy_stats.clear()
	wave_data.clear()
	boss_fights.clear()
	current_boss_type = ""
	current_run.clear()

	print("[BalanceTracker] Run data reset")

func reset_session():
	"""Reset entire session (session reset)"""
	reset_run()
	session_data.runs.clear()
	print("[BalanceTracker] Session data reset")

func reset_all():
	"""Reset everything including session (full reset)"""
	reset_session()
	_init_session()
	print("[BalanceTracker] Full reset complete")

# ============================================
# TOWER TRACKING
# ============================================

func register_tower(tower_instance: Node, tower_type: String, cost: int):
	"""Register a tower for tracking"""
	if not is_tracking:
		return

	var instance_id = tower_instance.get_instance_id()
	tracked_towers[instance_id] = {
		"instance_id": instance_id,
		"type": tower_type,
		"placement_time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"total_damage": 0.0,
		"kills": 0,
		"assists": 0,
		"shots_fired": 0,
		"shots_hit": 0,
		"active_time": 0.0,
		"idle_time": 0.0,
		"last_shot_time": 0.0,
		"gold_spent": cost,
		"position": tower_instance.global_position if tower_instance else Vector2.ZERO,
		"tower_level": 1,
		"upgrade_path": "",
		"upgrade_history": []  # [{level: int, cost: int, time: float, path: String}]
	}

	# Record tower purchase
	_record_gold_spent(cost, "tower_%s" % tower_type)

	print("[BalanceTracker] Tower registered: %s (ID:%d)" % [tower_type, instance_id])

func record_tower_upgrade(tower_instance: Node, new_level: int, upgrade_cost: int, upgrade_path: String = ""):
	"""Record that a tower was upgraded"""
	if not is_tracking:
		return

	var instance_id = tower_instance.get_instance_id()
	if not tracked_towers.has(instance_id):
		push_warning("[BalanceTracker] Tower not registered: ", instance_id)
		return

	var tower_data = tracked_towers[instance_id]
	tower_data.tower_level = new_level
	tower_data.gold_spent += upgrade_cost
	if upgrade_path != "":
		tower_data.upgrade_path = upgrade_path

	# Record upgrade event
	tower_data.upgrade_history.append({
		"level": new_level,
		"cost": upgrade_cost,
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"path": upgrade_path
	})

	# Record gold spent
	_record_gold_spent(upgrade_cost, "tower_upgrade_L%d" % new_level)

	print("[BalanceTracker] Tower upgraded: ID:%d → Level %d (Path: %s, Cost: %dg)" % [instance_id, new_level, upgrade_path if upgrade_path != "" else "none", upgrade_cost])

func record_tower_shot(tower_instance: Node):
	"""Record that a tower fired a shot"""
	if not is_tracking:
		return

	var instance_id = tower_instance.get_instance_id()
	if not tracked_towers.has(instance_id):
		push_warning("[BalanceTracker] Tower not registered: ", instance_id)
		return

	tracked_towers[instance_id].shots_fired += 1
	tracked_towers[instance_id].last_shot_time = Time.get_ticks_msec() / 1000.0 - run_start_time

func record_damage(source_instance: Node, target: Node, damage: float, source_type: String):
	"""Record damage dealt by a tower or hero"""
	if not is_tracking:
		return

	var instance_id = source_instance.get_instance_id()
	var current_time = Time.get_ticks_msec() / 1000.0 - run_start_time

	# Track tower damage
	if source_type == "tower" and tracked_towers.has(instance_id):
		tracked_towers[instance_id].total_damage += damage
		tracked_towers[instance_id].shots_hit += 1

	# Track hero damage
	elif source_type.begins_with("hero_") and tracked_heroes.has(instance_id):
		var attack_type = source_type.replace("hero_", "")  # "ranged" or "melee"
		tracked_heroes[instance_id].total_damage += damage

		if attack_type == "ranged":
			tracked_heroes[instance_id].ranged_damage += damage
		elif attack_type == "melee":
			tracked_heroes[instance_id].melee_damage += damage

func record_kill(source_instance: Node, enemy_type: String, gold_reward: int, source_type: String):
	"""Record that a tower/hero killed an enemy"""
	if not is_tracking:
		return

	var instance_id = source_instance.get_instance_id()

	# Track tower kill
	if source_type == "tower" and tracked_towers.has(instance_id):
		tracked_towers[instance_id].kills += 1

	# Track hero kill
	elif source_type.begins_with("hero_") and tracked_heroes.has(instance_id):
		tracked_heroes[instance_id].kills += 1

# ============================================
# HERO TRACKING
# ============================================

func register_hero(hero_instance: Node, hero_id: String):
	"""Register a hero for tracking"""
	if not is_tracking:
		return

	var instance_id = hero_instance.get_instance_id()
	tracked_heroes[instance_id] = {
		"instance_id": instance_id,
		"hero_id": hero_id,
		"placement_time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"total_damage": 0.0,
		"ranged_damage": 0.0,
		"melee_damage": 0.0,
		"skill_damage": 0.0,
		"kills": 0,
		"enemies_blocked": 0,
		"deaths": 0,
		"skill_uses": {},
		"time_in_states": {
			"idle": 0.0,
			"ranged_combat": 0.0,
			"melee_combat": 0.0,
			"walking": 0.0,
			"returning": 0.0
		},
		"last_state": "idle",
		"last_state_change_time": 0.0
	}

	print("[BalanceTracker] Hero registered: %s (ID:%d)" % [hero_id, instance_id])

func record_hero_state_change(hero_instance: Node, new_state: String):
	"""Record hero state change for time tracking"""
	if not is_tracking:
		return

	var instance_id = hero_instance.get_instance_id()
	if not tracked_heroes.has(instance_id):
		return

	var hero_data = tracked_heroes[instance_id]
	var current_time = Time.get_ticks_msec() / 1000.0 - run_start_time

	# Calculate time spent in previous state
	if hero_data.last_state_change_time > 0:
		var time_in_state = current_time - hero_data.last_state_change_time
		hero_data.time_in_states[hero_data.last_state] += time_in_state

	# Update to new state
	hero_data.last_state = new_state.to_lower()
	hero_data.last_state_change_time = current_time

func record_hero_block(hero_instance: Node):
	"""Record that hero blocked an enemy"""
	if not is_tracking:
		return

	var instance_id = hero_instance.get_instance_id()
	if tracked_heroes.has(instance_id):
		tracked_heroes[instance_id].enemies_blocked += 1

func record_hero_skill_use(hero_instance: Node, skill_id: String, damage: float = 0.0):
	"""Record hero skill usage"""
	if not is_tracking:
		return

	var instance_id = hero_instance.get_instance_id()
	if not tracked_heroes.has(instance_id):
		return

	var hero_data = tracked_heroes[instance_id]

	# Track skill usage count
	if not hero_data.skill_uses.has(skill_id):
		hero_data.skill_uses[skill_id] = 0
	hero_data.skill_uses[skill_id] += 1

	# Track skill damage
	hero_data.skill_damage += damage

func record_hero_death(hero_instance: Node):
	"""Record hero death"""
	if not is_tracking:
		return

	var instance_id = hero_instance.get_instance_id()
	if tracked_heroes.has(instance_id):
		tracked_heroes[instance_id].deaths += 1

# ============================================
# ENEMY TRACKING
# ============================================

func record_enemy_spawned(enemy_type: String):
	"""Record that an enemy was spawned"""
	if not is_tracking:
		return

	_ensure_enemy_stats(enemy_type)
	enemy_stats[enemy_type].spawned += 1
	enemy_stats[enemy_type].spawn_times.append(Time.get_ticks_msec() / 1000.0 - run_start_time)

func record_enemy_killed(enemy_type: String, time_alive: float, gold_reward: int):
	"""Record that an enemy was killed"""
	if not is_tracking:
		return

	_ensure_enemy_stats(enemy_type)
	enemy_stats[enemy_type].killed += 1
	enemy_stats[enemy_type].total_time_alive += time_alive
	enemy_stats[enemy_type].gold_rewarded += gold_reward

	# Record gold earned
	_record_gold_earned(gold_reward, "enemy_kill_%s" % enemy_type)

func record_enemy_leaked(enemy_type: String, lives_lost: int):
	"""Record that an enemy reached the end"""
	if not is_tracking:
		return

	_ensure_enemy_stats(enemy_type)
	enemy_stats[enemy_type].leaked += 1
	enemy_stats[enemy_type].lives_lost += lives_lost

func _ensure_enemy_stats(enemy_type: String):
	"""Ensure enemy stats dictionary exists"""
	if not enemy_stats.has(enemy_type):
		enemy_stats[enemy_type] = {
			"type": enemy_type,
			"spawned": 0,
			"killed": 0,
			"leaked": 0,
			"total_time_alive": 0.0,
			"gold_rewarded": 0,
			"lives_lost": 0,
			"spawn_times": []
		}

# ============================================
# BOSS TRACKING (Extended for Boss Fights)
# ============================================

## Boss fight data {boss_type: boss_data}
var boss_fights: Dictionary = {}

## Current active boss
var current_boss_type: String = ""

func record_boss_appeared(boss_type: String, boss_instance: Node):
	"""Record when a boss enemy appears"""
	if not is_tracking:
		return

	current_boss_type = boss_type

	boss_fights[boss_type] = {
		"boss_type": boss_type,
		"appear_time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"defeat_time": 0.0,
		"fight_duration": 0.0,
		"total_damage_taken": 0.0,
		"hits_taken": 0,
		"health_milestones": [],  # [{health_percent: float, time: float}]
		"damage_by_tower": {},  # {instance_id: damage}
		"damage_by_hero": {},  # {instance_id: damage}
		"defeated": false,
		"leaked": false,
		"wave_number": current_wave_number
	}

	print("🔴 [BalanceTracker] BOSS APPEARED: %s at wave %d" % [boss_type, current_wave_number])

func record_boss_health_milestone(boss_type: String, health_percent: float):
	"""Record when boss reaches a health milestone (75%, 50%, 25%)"""
	if not is_tracking or not boss_fights.has(boss_type):
		return

	var boss_data = boss_fights[boss_type]
	var current_time = Time.get_ticks_msec() / 1000.0 - run_start_time

	# Check if we already recorded this milestone
	for milestone in boss_data.health_milestones:
		if abs(milestone.health_percent - health_percent) < 1.0:
			return  # Already recorded

	boss_data.health_milestones.append({
		"health_percent": health_percent,
		"time": current_time,
		"time_since_appear": current_time - boss_data.appear_time
	})

	print("🔴 [BalanceTracker] Boss %s at %.0f%% health" % [boss_type, health_percent])

func record_boss_damage(boss_type: String, source_instance: Node, damage: float, source_type: String):
	"""Record damage dealt to a boss"""
	if not is_tracking or not boss_fights.has(boss_type):
		return

	var boss_data = boss_fights[boss_type]
	var instance_id = source_instance.get_instance_id()

	boss_data.total_damage_taken += damage
	boss_data.hits_taken += 1

	# Track by source
	if source_type == "tower":
		if not boss_data.damage_by_tower.has(instance_id):
			boss_data.damage_by_tower[instance_id] = 0.0
		boss_data.damage_by_tower[instance_id] += damage
	elif source_type.begins_with("hero_"):
		if not boss_data.damage_by_hero.has(instance_id):
			boss_data.damage_by_hero[instance_id] = 0.0
		boss_data.damage_by_hero[instance_id] += damage

func record_boss_defeated(boss_type: String):
	"""Record when a boss is defeated"""
	if not is_tracking or not boss_fights.has(boss_type):
		return

	var boss_data = boss_fights[boss_type]
	var current_time = Time.get_ticks_msec() / 1000.0 - run_start_time

	boss_data.defeated = true
	boss_data.defeat_time = current_time
	boss_data.fight_duration = current_time - boss_data.appear_time

	current_boss_type = ""

	print("🔴 [BalanceTracker] BOSS DEFEATED: %s (%.1fs fight)" % [boss_type, boss_data.fight_duration])

	# Calculate boss fight stats
	var avg_dps = boss_data.total_damage_taken / boss_data.fight_duration if boss_data.fight_duration > 0 else 0.0
	print("   - Total damage taken: %.0f" % boss_data.total_damage_taken)
	print("   - Average DPS: %.1f" % avg_dps)
	print("   - Hits taken: %d" % boss_data.hits_taken)
	print("   - Health milestones: %d" % boss_data.health_milestones.size())

func record_boss_leaked(boss_type: String):
	"""Record when a boss leaks through"""
	if not is_tracking or not boss_fights.has(boss_type):
		return

	var boss_data = boss_fights[boss_type]
	var current_time = Time.get_ticks_msec() / 1000.0 - run_start_time

	boss_data.leaked = true
	boss_data.defeat_time = current_time
	boss_data.fight_duration = current_time - boss_data.appear_time

	current_boss_type = ""

	print("🔴 [BalanceTracker] BOSS LEAKED: %s (%.1fs)" % [boss_type, boss_data.fight_duration])

# ============================================
# WAVE TRACKING
# ============================================

func start_wave(wave_number: int, enemy_composition: Dictionary = {}):
	"""Record wave start"""
	if not is_tracking:
		return

	current_wave_number = wave_number

	wave_data[wave_number] = {
		"wave_number": wave_number,
		"start_time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"end_time": 0.0,
		"duration": 0.0,
		"enemies_spawned": 0,
		"enemies_killed": 0,
		"enemies_leaked": 0,
		"lives_lost": 0,
		"gold_earned": 0,
		"gold_spent": 0,
		"gold_at_start": GameStateManager.gold if GameStateManager else 0,
		"gold_at_end": 0,
		"lives_at_start": GameStateManager.lives if GameStateManager else 0,
		"lives_at_end": 0,
		"composition": enemy_composition
	}

	print("[BalanceTracker] Wave %d started" % wave_number)

func end_wave(wave_number: int):
	"""Record wave end"""
	if not is_tracking:
		return

	if not wave_data.has(wave_number):
		push_warning("[BalanceTracker] Wave %d not started" % wave_number)
		return

	var wave = wave_data[wave_number]
	wave.end_time = Time.get_ticks_msec() / 1000.0 - run_start_time
	wave.duration = wave.end_time - wave.start_time
	wave.gold_at_end = GameStateManager.gold if GameStateManager else 0
	wave.lives_at_end = GameStateManager.lives if GameStateManager else 0

	# Calculate wave totals from enemy stats
	for enemy_type in enemy_stats:
		var stats = enemy_stats[enemy_type]
		wave.enemies_spawned += stats.spawned
		wave.enemies_killed += stats.killed
		wave.enemies_leaked += stats.leaked
		wave.lives_lost += stats.lives_lost

	print("[BalanceTracker] Wave %d ended (%.1fs)" % [wave_number, wave.duration])

# ============================================
# ECONOMY TRACKING
# ============================================

func _record_gold_earned(amount: int, reason: String):
	"""Record gold earned"""
	if not is_tracking:
		return

	current_run.economy.total_earned += amount
	current_run.economy.gold_history.append({
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"amount": amount,
		"reason": reason,
		"type": "earned"
	})

func _record_gold_spent(amount: int, reason: String):
	"""Record gold spent"""
	if not is_tracking:
		return

	current_run.economy.total_spent += amount
	current_run.economy.gold_history.append({
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"amount": -amount,
		"reason": reason,
		"type": "spent"
	})

# ============================================
# DATA SERIALIZATION
# ============================================

func _serialize_tower_data() -> Dictionary:
	"""Convert tower tracking data to serializable format"""
	var result = {}

	for instance_id in tracked_towers:
		var tower = tracked_towers[instance_id]
		var tower_data = tower.duplicate()

		# Calculate derived metrics
		var total_time = tower.active_time + tower.idle_time
		tower_data["uptime_percent"] = tower.active_time / total_time if total_time > 0 else 0.0
		tower_data["accuracy"] = float(tower.shots_hit) / float(tower.shots_fired) if tower.shots_fired > 0 else 0.0
		tower_data["actual_dps"] = tower.total_damage / total_time if total_time > 0 else 0.0
		tower_data["damage_per_gold"] = tower.total_damage / tower.gold_spent if tower.gold_spent > 0 else 0.0

		result[str(instance_id)] = tower_data

	return result

func _serialize_hero_data() -> Dictionary:
	"""Convert hero tracking data to serializable format"""
	var result = {}

	for instance_id in tracked_heroes:
		var hero = tracked_heroes[instance_id]
		var hero_data = hero.duplicate()

		# Calculate derived metrics
		var total_combat_time = hero.time_in_states.ranged_combat + hero.time_in_states.melee_combat
		hero_data["ranged_dps"] = hero.ranged_damage / total_combat_time if total_combat_time > 0 else 0.0
		hero_data["melee_dps"] = hero.melee_damage / total_combat_time if total_combat_time > 0 else 0.0
		hero_data["skill_dps"] = hero.skill_damage / total_combat_time if total_combat_time > 0 else 0.0

		result[hero.hero_id] = hero_data

	return result

func _serialize_enemy_data() -> Dictionary:
	"""Convert enemy tracking data to serializable format"""
	var result = {}

	for enemy_type in enemy_stats:
		var stats = enemy_stats[enemy_type]
		var enemy_data = stats.duplicate()

		# Calculate derived metrics
		enemy_data["avg_ttk"] = stats.total_time_alive / stats.killed if stats.killed > 0 else 0.0
		enemy_data["leak_rate"] = float(stats.leaked) / float(stats.spawned) if stats.spawned > 0 else 0.0

		result[enemy_type] = enemy_data

	return result

# ============================================
# BALANCE METRICS CALCULATION
# ============================================

func _calculate_balance_metrics() -> Dictionary:
	"""Calculate overall balance metrics for the run"""
	var metrics = {}

	# Tower metrics
	var total_tower_damage = 0.0
	var total_tower_dps = 0.0
	var tower_count = 0

	for tower_id in current_run.towers:
		var tower = current_run.towers[tower_id]
		total_tower_damage += tower.total_damage
		total_tower_dps += tower.actual_dps
		tower_count += 1

	metrics["avg_tower_dps"] = total_tower_dps / tower_count if tower_count > 0 else 0.0
	metrics["total_tower_damage"] = total_tower_damage

	# Hero metrics
	var total_hero_damage = 0.0
	for hero_id in current_run.heroes:
		total_hero_damage += current_run.heroes[hero_id].total_damage

	metrics["total_hero_damage"] = total_hero_damage

	# Enemy metrics
	var total_enemy_hp = 0.0
	var total_enemies = 0
	var total_ttk = 0.0

	for enemy_type in current_run.enemies:
		var enemy = current_run.enemies[enemy_type]
		total_enemies += enemy.spawned
		total_ttk += enemy.avg_ttk * enemy.killed

	metrics["avg_enemy_ttk"] = total_ttk / total_enemies if total_enemies > 0 else 0.0

	# Combined DPS
	metrics["total_dps"] = total_tower_dps + (total_hero_damage / current_run.duration if current_run.duration > 0 else 0.0)

	# Economy metrics
	metrics["gold_efficiency"] = float(current_run.economy.total_spent) / float(current_run.economy.starting_gold + current_run.economy.total_earned) if (current_run.economy.starting_gold + current_run.economy.total_earned) > 0 else 0.0

	return metrics

# ============================================
# DATA ACCESS
# ============================================

func get_current_run_data() -> Dictionary:
	"""Get current run data (even if run is in progress)"""
	if is_tracking:
		# Create a snapshot of current state
		var snapshot = current_run.duplicate(true)
		snapshot.towers = _serialize_tower_data()
		snapshot.heroes = _serialize_hero_data()
		snapshot.enemies = _serialize_enemy_data()
		snapshot.balance_metrics = _calculate_balance_metrics()
		return snapshot
	else:
		return current_run.duplicate(true)

func get_session_data() -> Dictionary:
	"""Get full session data including all runs"""
	return session_data.duplicate(true)

func get_tower_stats(instance_id: int) -> Dictionary:
	"""Get stats for a specific tower"""
	if tracked_towers.has(instance_id):
		return tracked_towers[instance_id].duplicate()
	return {}

func get_hero_stats(instance_id: int) -> Dictionary:
	"""Get stats for a specific hero"""
	if tracked_heroes.has(instance_id):
		return tracked_heroes[instance_id].duplicate()
	return {}


# ============================================
# AI PLAYTEST TRACKING (Extension for AI)
# ============================================

func record_ai_decision(action: String, target: int, reason: String, gold_before: int):
	"""Record an AI decision for analysis"""
	if not is_tracking:
		return

	var decision = {
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time,
		"wave": current_wave_number,
		"action": action,
		"target": target,
		"reason": reason,
		"gold_before": gold_before,
		"gold_after": GameStateManager.gold if GameStateManager else 0
	}

	ai_decision_log.append(decision)

func record_tower_placement_position(position: Vector2, tower_type: String):
	"""Record tower placement position for heatmaps"""
	if not is_tracking:
		return

	tower_placement_positions.append({
		"position": position,
		"type": tower_type,
		"wave": current_wave_number,
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time
	})

