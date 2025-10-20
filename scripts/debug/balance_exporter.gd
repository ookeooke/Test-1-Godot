extends Node

## ============================================
## BALANCE EXPORTER - Export balance data to JSON/CSV
## ============================================
##
## Exports balance tracking data to user://balance_debug/ folder
## Supports JSON and CSV formats for analysis
##
## Usage:
##   BalanceExporter.export_current_run()
##   BalanceExporter.export_session()
##   BalanceExporter.export_to_csv()
## ============================================

# ============================================
# CONSTANTS
# ============================================

const EXPORT_DIR = "user://balance_debug/exports/"
const BACKUP_DIR = "user://balance_debug/backups/"

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	_ensure_directories()
	print("✅ BalanceExporter initialized")
	print("📁 Export directory: %s" % get_export_directory_path())

func _ensure_directories():
	"""Create export directories if they don't exist"""
	var dir = DirAccess.open("user://")

	if not dir.dir_exists("balance_debug"):
		dir.make_dir("balance_debug")

	if not dir.dir_exists("balance_debug/exports"):
		dir.make_dir("balance_debug/exports")

	if not dir.dir_exists("balance_debug/backups"):
		dir.make_dir("balance_debug/backups")

	print("[BalanceExporter] Directories ensured")

# ============================================
# JSON EXPORT
# ============================================

func export_current_run(auto_backup: bool = false) -> String:
	"""
	Export current run data to JSON file
	Returns: File path of exported file, or empty string on failure
	"""
	var run_data = BalanceTracker.get_current_run_data()

	if run_data.is_empty():
		push_warning("[BalanceExporter] No run data to export")
		return ""

	# Generate filename
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "run_%s.json" % timestamp
	var filepath = EXPORT_DIR + filename

	# Optionally create backup
	if auto_backup:
		_backup_current_data()

	# Write JSON file
	return _write_json_file(filepath, run_data)

func export_session() -> String:
	"""
	Export entire session data (all runs) to JSON file
	Returns: File path of exported file, or empty string on failure
	"""
	var session_data = BalanceTracker.get_session_data()

	if session_data.is_empty() or session_data.runs.is_empty():
		push_warning("[BalanceExporter] No session data to export")
		return ""

	# Generate filename
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "session_%s.json" % timestamp
	var filepath = EXPORT_DIR + filename

	# Write JSON file
	return _write_json_file(filepath, session_data)

func _write_json_file(filepath: String, data: Dictionary) -> String:
	"""Write dictionary to JSON file"""
	var file = FileAccess.open(filepath, FileAccess.WRITE)

	if file == null:
		push_error("[BalanceExporter] Failed to open file for writing: %s (Error: %d)" % [filepath, FileAccess.get_open_error()])
		return ""

	# Convert to JSON string with indentation for readability
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	var absolute_path = ProjectSettings.globalize_path(filepath)
	print("[BalanceExporter] ✅ Exported to: %s" % absolute_path)
	print("[BalanceExporter]    (Open this file to view balance data)")
	return filepath

# ============================================
# CSV EXPORT
# ============================================

func export_to_csv() -> Dictionary:
	"""
	Export session data to multiple CSV files
	Returns: Dictionary of {csv_type: filepath}
	"""
	var session_data = BalanceTracker.get_session_data()

	if session_data.is_empty() or session_data.runs.is_empty():
		push_warning("[BalanceExporter] No session data to export")
		return {}

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var exported_files = {}

	# Export towers CSV
	var towers_path = _export_towers_csv(session_data, timestamp)
	if towers_path != "":
		exported_files["towers"] = towers_path

	# Export heroes CSV
	var heroes_path = _export_heroes_csv(session_data, timestamp)
	if heroes_path != "":
		exported_files["heroes"] = heroes_path

	# Export enemies CSV
	var enemies_path = _export_enemies_csv(session_data, timestamp)
	if enemies_path != "":
		exported_files["enemies"] = enemies_path

	# Export waves CSV
	var waves_path = _export_waves_csv(session_data, timestamp)
	if waves_path != "":
		exported_files["waves"] = waves_path

	print("[BalanceExporter] Exported %d CSV files" % exported_files.size())
	return exported_files

func _export_towers_csv(session_data: Dictionary, timestamp: String) -> String:
	"""Export tower data to CSV"""
	var filepath = EXPORT_DIR + "towers_%s.csv" % timestamp
	var file = FileAccess.open(filepath, FileAccess.WRITE)

	if file == null:
		return ""

	# CSV Header
	file.store_csv_line(PackedStringArray([
		"Run", "Tower_Type", "Instance_ID", "Placement_Time", "Total_Damage",
		"Kills", "Assists", "Shots_Fired", "Shots_Hit", "Accuracy",
		"Active_Time", "Idle_Time", "Uptime_Percent", "Actual_DPS",
		"Gold_Spent", "Damage_Per_Gold"
	]))

	# Data rows
	for run in session_data.runs:
		var run_id = run.run_id
		for tower_id in run.towers:
			var tower = run.towers[tower_id]
			file.store_csv_line(PackedStringArray([
				str(run_id),
				tower.type,
				str(tower.instance_id),
				"%.2f" % tower.placement_time,
				"%.1f" % tower.total_damage,
				str(tower.kills),
				str(tower.assists),
				str(tower.shots_fired),
				str(tower.shots_hit),
				"%.2f" % tower.accuracy,
				"%.1f" % tower.active_time,
				"%.1f" % tower.idle_time,
				"%.2f" % tower.uptime_percent,
				"%.2f" % tower.actual_dps,
				str(tower.gold_spent),
				"%.2f" % tower.damage_per_gold
			]))

	file.close()
	return filepath

func _export_heroes_csv(session_data: Dictionary, timestamp: String) -> String:
	"""Export hero data to CSV"""
	var filepath = EXPORT_DIR + "heroes_%s.csv" % timestamp
	var file = FileAccess.open(filepath, FileAccess.WRITE)

	if file == null:
		return ""

	# CSV Header
	file.store_csv_line(PackedStringArray([
		"Run", "Hero_ID", "Total_Damage", "Ranged_Damage", "Melee_Damage",
		"Skill_Damage", "Kills", "Enemies_Blocked", "Deaths",
		"Ranged_DPS", "Melee_DPS", "Skill_DPS"
	]))

	# Data rows
	for run in session_data.runs:
		var run_id = run.run_id
		for hero_id in run.heroes:
			var hero = run.heroes[hero_id]
			file.store_csv_line(PackedStringArray([
				str(run_id),
				hero.hero_id,
				"%.1f" % hero.total_damage,
				"%.1f" % hero.ranged_damage,
				"%.1f" % hero.melee_damage,
				"%.1f" % hero.skill_damage,
				str(hero.kills),
				str(hero.enemies_blocked),
				str(hero.deaths),
				"%.2f" % hero.ranged_dps,
				"%.2f" % hero.melee_dps,
				"%.2f" % hero.skill_dps
			]))

	file.close()
	return filepath

func _export_enemies_csv(session_data: Dictionary, timestamp: String) -> String:
	"""Export enemy data to CSV"""
	var filepath = EXPORT_DIR + "enemies_%s.csv" % timestamp
	var file = FileAccess.open(filepath, FileAccess.WRITE)

	if file == null:
		return ""

	# CSV Header
	file.store_csv_line(PackedStringArray([
		"Run", "Enemy_Type", "Spawned", "Killed", "Leaked",
		"Avg_TTK", "Leak_Rate", "Gold_Rewarded", "Lives_Lost"
	]))

	# Data rows
	for run in session_data.runs:
		var run_id = run.run_id
		for enemy_type in run.enemies:
			var enemy = run.enemies[enemy_type]
			file.store_csv_line(PackedStringArray([
				str(run_id),
				enemy.type,
				str(enemy.spawned),
				str(enemy.killed),
				str(enemy.leaked),
				"%.2f" % enemy.avg_ttk,
				"%.2f" % enemy.leak_rate,
				str(enemy.gold_rewarded),
				str(enemy.lives_lost)
			]))

	file.close()
	return filepath

func _export_waves_csv(session_data: Dictionary, timestamp: String) -> String:
	"""Export wave data to CSV"""
	var filepath = EXPORT_DIR + "waves_%s.csv" % timestamp
	var file = FileAccess.open(filepath, FileAccess.WRITE)

	if file == null:
		return ""

	# CSV Header
	file.store_csv_line(PackedStringArray([
		"Run", "Wave", "Duration", "Enemies_Spawned", "Enemies_Killed",
		"Enemies_Leaked", "Lives_Lost", "Gold_Earned", "Gold_Spent",
		"Gold_Start", "Gold_End"
	]))

	# Data rows
	for run in session_data.runs:
		var run_id = run.run_id
		for wave_num in run.waves:
			var wave = run.waves[wave_num]
			file.store_csv_line(PackedStringArray([
				str(run_id),
				str(wave.wave_number),
				"%.1f" % wave.duration,
				str(wave.enemies_spawned),
				str(wave.enemies_killed),
				str(wave.enemies_leaked),
				str(wave.lives_lost),
				str(wave.gold_earned),
				str(wave.gold_spent),
				str(wave.gold_at_start),
				str(wave.gold_at_end)
			]))

	file.close()
	return filepath

# ============================================
# BACKUP SYSTEM
# ============================================

func _backup_current_data():
	"""Create backup of current data before reset"""
	var run_data = BalanceTracker.get_current_run_data()

	if run_data.is_empty():
		return

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "backup_%s.json" % timestamp
	var filepath = BACKUP_DIR + filename

	_write_json_file(filepath, run_data)
	print("[BalanceExporter] Backup created: %s" % filename)

func backup_before_reset():
	"""Public method to create backup (called before reset)"""
	_backup_current_data()

# ============================================
# FILE MANAGEMENT
# ============================================

func get_export_files() -> Array:
	"""Get list of all exported files"""
	var files = []
	var dir = DirAccess.open(EXPORT_DIR)

	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()

		while filename != "":
			if not dir.current_is_dir():
				files.append(EXPORT_DIR + filename)
			filename = dir.get_next()

		dir.list_dir_end()

	return files

func get_backup_files() -> Array:
	"""Get list of all backup files"""
	var files = []
	var dir = DirAccess.open(BACKUP_DIR)

	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()

		while filename != "":
			if not dir.current_is_dir():
				files.append(BACKUP_DIR + filename)
			filename = dir.get_next()

		dir.list_dir_end()

	return files

func delete_all_exports() -> int:
	"""Delete all export files. Returns number of files deleted."""
	var files = get_export_files()
	var deleted_count = 0

	for filepath in files:
		var dir = DirAccess.open("user://")
		if dir.remove(filepath) == OK:
			deleted_count += 1

	print("[BalanceExporter] Deleted %d export files" % deleted_count)
	return deleted_count

func delete_all_backups() -> int:
	"""Delete all backup files. Returns number of files deleted."""
	var files = get_backup_files()
	var deleted_count = 0

	for filepath in files:
		var dir = DirAccess.open("user://")
		if dir.remove(filepath) == OK:
			deleted_count += 1

	print("[BalanceExporter] Deleted %d backup files" % deleted_count)
	return deleted_count

func get_export_directory_path() -> String:
	"""Get the absolute path to export directory for user reference"""
	return ProjectSettings.globalize_path(EXPORT_DIR)
