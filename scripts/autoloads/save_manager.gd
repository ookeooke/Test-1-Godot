extends Node

# SaveManager - Handles all save/load operations for player profiles
# Singleton autoload for global save access

signal profile_loaded(profile_data: Dictionary)
signal profile_saved(profile_name: String)
signal profile_created(profile_name: String)

const SAVE_DIR = "user://saves/"
const SAVE_EXTENSION = ".save"

var current_profile: Dictionary = {}
var current_profile_name: String = ""

func _ready():
	# Ensure save directory exists
	_ensure_save_directory()

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("saves"):
			dir.make_dir("saves")
			print("SaveManager: Created saves directory")

func create_new_profile(profile_name: String) -> bool:
	if profile_name.is_empty():
		push_error("SaveManager: Profile name cannot be empty")
		return false

	# Check if profile already exists
	if profile_exists(profile_name):
		push_error("SaveManager: Profile already exists: ", profile_name)
		return false

	# Create new profile data
	var new_profile = {
		"profile_name": profile_name,
		"created_at": Time.get_datetime_string_from_system(),
		"last_played": Time.get_datetime_string_from_system(),
		"completed_levels": [],
		"level_stars": {}, # level_id: stars_earned (1-3)
		"settings": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"camera_shake": true
		},
		"stats": {
			"total_playtime": 0.0,
			"enemies_killed": 0,
			"towers_built": 0,
			"waves_completed": 0
		}
	}

	# Save the profile
	if save_profile(new_profile):
		current_profile = new_profile
		current_profile_name = profile_name
		profile_created.emit(profile_name)
		return true

	return false

func save_profile(profile_data: Dictionary) -> bool:
	if not profile_data.has("profile_name"):
		push_error("SaveManager: Profile data missing profile_name")
		return false

	var profile_name = profile_data["profile_name"]
	var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION

	# Update last played time
	profile_data["last_played"] = Time.get_datetime_string_from_system()

	# Convert to JSON
	var json_string = JSON.stringify(profile_data, "\t")

	# Write to file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("SaveManager: Profile saved: ", profile_name)
		profile_saved.emit(profile_name)
		return true
	else:
		push_error("SaveManager: Failed to save profile: ", profile_name)
		return false

func load_profile(profile_name: String) -> bool:
	var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION

	if not FileAccess.file_exists(save_path):
		push_error("SaveManager: Profile not found: ", profile_name)
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		# Parse JSON
		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var profile_data = json.data
			current_profile = profile_data
			current_profile_name = profile_name
			print("SaveManager: Profile loaded: ", profile_name)
			profile_loaded.emit(profile_data)
			return true
		else:
			push_error("SaveManager: Failed to parse profile JSON: ", profile_name)
			return false
	else:
		push_error("SaveManager: Failed to open profile file: ", profile_name)
		return false

func get_current_profile() -> Dictionary:
	return current_profile

func get_current_profile_name() -> String:
	return current_profile_name

func has_current_profile() -> bool:
	return not current_profile.is_empty()

func profile_exists(profile_name: String) -> bool:
	var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION
	return FileAccess.file_exists(save_path)

func list_profiles() -> Array[String]:
	var profiles: Array[String] = []
	var dir = DirAccess.open(SAVE_DIR)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
				# Remove extension to get profile name
				var profile_name = file_name.trim_suffix(SAVE_EXTENSION)
				profiles.append(profile_name)
			file_name = dir.get_next()

		dir.list_dir_end()

	return profiles

func get_last_played_profile() -> String:
	var profiles = list_profiles()
	if profiles.is_empty():
		return ""

	var last_profile = ""
	var last_time = 0

	for profile_name in profiles:
		var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION
		var modified_time = FileAccess.get_modified_time(save_path)

		if modified_time > last_time:
			last_time = modified_time
			last_profile = profile_name

	return last_profile

func mark_level_complete(level_id: String, stars: int = 1) -> void:
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	# Add to completed levels if not already there
	if not current_profile["completed_levels"].has(level_id):
		current_profile["completed_levels"].append(level_id)

	# Update stars (keep highest)
	if not current_profile["level_stars"].has(level_id):
		current_profile["level_stars"][level_id] = stars
	else:
		current_profile["level_stars"][level_id] = max(current_profile["level_stars"][level_id], stars)

	# Save profile
	save_profile(current_profile)
	print("SaveManager: Level completed: ", level_id, " with ", stars, " stars")

func is_level_completed(level_id: String) -> bool:
	if not has_current_profile():
		return false
	return current_profile["completed_levels"].has(level_id)

func get_level_stars(level_id: String) -> int:
	if not has_current_profile():
		return 0
	if current_profile["level_stars"].has(level_id):
		return current_profile["level_stars"][level_id]
	return 0

func update_stat(stat_name: String, value: float) -> void:
	if not has_current_profile():
		return

	if current_profile["stats"].has(stat_name):
		current_profile["stats"][stat_name] += value
	else:
		current_profile["stats"][stat_name] = value

func get_stat(stat_name: String) -> float:
	if not has_current_profile():
		return 0.0
	if current_profile["stats"].has(stat_name):
		return current_profile["stats"][stat_name]
	return 0.0

func delete_profile(profile_name: String) -> bool:
	var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION

	if not FileAccess.file_exists(save_path):
		push_error("SaveManager: Profile not found: ", profile_name)
		return false

	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		var error = dir.remove(save_path)
		if error == OK:
			print("SaveManager: Profile deleted: ", profile_name)

			# Clear current profile if it was deleted
			if current_profile_name == profile_name:
				current_profile = {}
				current_profile_name = ""

			return true
		else:
			push_error("SaveManager: Failed to delete profile: ", profile_name)
			return false

	return false

func save_current_profile() -> bool:
	if not has_current_profile():
		push_error("SaveManager: No profile loaded to save")
		return false
	return save_profile(current_profile)
