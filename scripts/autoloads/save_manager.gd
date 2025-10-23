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
		"currency": 1000,  # Starting gold for skill purchases
		"hero_skills": {},  # hero_id: { skill_id: level }
		"inventory": {  # New: Inventory system data
			"global_inventory": {},
			"max_slots": {
				"equipment": 20,
				"consumables": 15,
				"materials": 30
			}
		},
		"hero_equipment": {},  # New: Per-hero equipment slots
		"user_preferences": {},  # UI preferences (panel tabs, etc.)
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

	# Save inventory data from InventoryManager
	if InventoryManager:
		profile_data["inventory"] = InventoryManager.save_to_dict()

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

			# Load inventory data into InventoryManager
			if InventoryManager and profile_data.has("inventory"):
				InventoryManager.load_from_dict(profile_data["inventory"])

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

# ============================================
# CURRENCY MANAGEMENT
# ============================================

func get_currency() -> int:
	"""Get player's current currency (gold)"""
	if not has_current_profile():
		return 0

	# Ensure currency field exists (for backwards compatibility)
	if not current_profile.has("currency"):
		current_profile["currency"] = 0

	return current_profile["currency"]

func add_currency(amount: int) -> void:
	"""Add or remove currency (use negative for spending)"""
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	if not current_profile.has("currency"):
		current_profile["currency"] = 0

	current_profile["currency"] += amount
	current_profile["currency"] = maxi(current_profile["currency"], 0)  # Don't go negative

	print("💰 Currency: ", current_profile["currency"], " (", "+%d" % amount if amount > 0 else str(amount), ")")

	save_current_profile()

func set_currency(amount: int) -> void:
	"""Set currency to a specific amount"""
	if not has_current_profile():
		return

	current_profile["currency"] = maxi(amount, 0)
	save_current_profile()

# ============================================
# HERO SKILLS MANAGEMENT
# ============================================

func unlock_hero_skill(hero_id: String, skill_id: String) -> void:
	"""Unlock a skill for a hero (set to level 1)"""
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	# Ensure hero_skills exists
	if not current_profile.has("hero_skills"):
		current_profile["hero_skills"] = {}

	# Ensure hero entry exists
	if not current_profile["hero_skills"].has(hero_id):
		current_profile["hero_skills"][hero_id] = {}

	# Set skill to level 1
	current_profile["hero_skills"][hero_id][skill_id] = 1

	print("✅ Unlocked skill: ", skill_id, " for hero: ", hero_id)

	save_current_profile()

func upgrade_hero_skill(hero_id: String, skill_id: String) -> void:
	"""Upgrade a hero's skill to the next level"""
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	if not current_profile.has("hero_skills"):
		current_profile["hero_skills"] = {}

	if not current_profile["hero_skills"].has(hero_id):
		push_error("SaveManager: Hero not found: ", hero_id)
		return

	if not current_profile["hero_skills"][hero_id].has(skill_id):
		push_error("SaveManager: Skill not unlocked: ", skill_id)
		return

	# Increment skill level
	current_profile["hero_skills"][hero_id][skill_id] += 1

	print("⬆️ Upgraded skill: ", skill_id, " to level ", current_profile["hero_skills"][hero_id][skill_id])

	save_current_profile()

func get_hero_skill_level(hero_id: String, skill_id: String) -> int:
	"""Get the current level of a hero's skill (0 = not owned)"""
	if not has_current_profile():
		return 0

	if not current_profile.has("hero_skills"):
		return 0

	if not current_profile["hero_skills"].has(hero_id):
		return 0

	if not current_profile["hero_skills"][hero_id].has(skill_id):
		return 0

	return current_profile["hero_skills"][hero_id][skill_id]

func get_hero_skills(hero_id: String) -> Dictionary:
	"""Get all skills for a hero (returns format for SkillManager.load_save_data)"""
	if not has_current_profile():
		return {"owned_skills": {}}

	if not current_profile.has("hero_skills"):
		return {"owned_skills": {}}

	if not current_profile["hero_skills"].has(hero_id):
		return {"owned_skills": {}}

	# Return in SkillManager format
	return {
		"owned_skills": current_profile["hero_skills"][hero_id].duplicate()
	}

func has_hero_skill(hero_id: String, skill_id: String) -> bool:
	"""Check if a hero has unlocked a specific skill"""
	return get_hero_skill_level(hero_id, skill_id) > 0

# ============================================
# INVENTORY & EQUIPMENT MANAGEMENT
# ============================================

func save_hero_equipment(hero_id: String, equipment_data: Dictionary) -> void:
	"""Save a hero's equipped items"""
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	if not current_profile.has("hero_equipment"):
		current_profile["hero_equipment"] = {}

	current_profile["hero_equipment"][hero_id] = equipment_data.duplicate()
	save_current_profile()
	print("SaveManager: Saved equipment for hero: ", hero_id)


func get_hero_equipment(hero_id: String) -> Dictionary:
	"""Get a hero's equipped items"""
	if not has_current_profile():
		return {}

	if not current_profile.has("hero_equipment"):
		return {}

	if not current_profile["hero_equipment"].has(hero_id):
		return {}

	return current_profile["hero_equipment"][hero_id].duplicate()


# ============================================
# USER PREFERENCES (UI STATE)
# ============================================

func set_user_preference(key: String, value: Variant) -> void:
	"""Save a user preference (UI state, panel selections, etc.)"""
	if not has_current_profile():
		return

	if not current_profile.has("user_preferences"):
		current_profile["user_preferences"] = {}

	current_profile["user_preferences"][key] = value
	# Don't auto-save for preferences (only save when profile saves)


func get_user_preference(key: String, default_value: Variant = null) -> Variant:
	"""Get a user preference with optional default"""
	if not has_current_profile():
		return default_value

	if not current_profile.has("user_preferences"):
		return default_value

	if not current_profile["user_preferences"].has(key):
		return default_value

	return current_profile["user_preferences"][key]


# ============================================
# HERO LOADOUT MANAGEMENT (Diablo 2 style)
# ============================================

const MAX_LOADOUT_SLOTS: int = 3  # Build A, B, C

func save_hero_loadout(hero_id: String, slot: int, loadout_data: Dictionary) -> void:
	"""Save a loadout preset for a hero (equipment + skills)"""
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	if slot < 0 or slot >= MAX_LOADOUT_SLOTS:
		push_error("SaveManager: Invalid loadout slot: ", slot)
		return

	# Ensure hero_loadouts exists
	if not current_profile.has("hero_loadouts"):
		current_profile["hero_loadouts"] = {}

	if not current_profile["hero_loadouts"].has(hero_id):
		current_profile["hero_loadouts"][hero_id] = {}

	# Add timestamp
	loadout_data["timestamp"] = Time.get_unix_time_from_system()

	# Save to slot
	current_profile["hero_loadouts"][hero_id][str(slot)] = loadout_data.duplicate()

	save_current_profile()
	print("💾 Saved loadout '%s' for %s (slot %d)" % [loadout_data.get("loadout_name", "Build"), hero_id, slot])


func load_hero_loadout(hero_id: String, slot: int) -> Dictionary:
	"""Load a loadout preset for a hero"""
	if not has_current_profile():
		return {}

	if not current_profile.has("hero_loadouts"):
		return {}

	if not current_profile["hero_loadouts"].has(hero_id):
		return {}

	var loadout_data = current_profile["hero_loadouts"][hero_id].get(str(slot), {})
	return loadout_data.duplicate()


func get_hero_loadouts(hero_id: String) -> Array[Dictionary]:
	"""Get all loadout presets for a hero (returns 3 slots, some may be empty)"""
	var loadouts: Array[Dictionary] = []

	for i in MAX_LOADOUT_SLOTS:
		var loadout = load_hero_loadout(hero_id, i)
		loadouts.append(loadout)  # Empty dict if no loadout

	return loadouts


func delete_hero_loadout(hero_id: String, slot: int) -> void:
	"""Delete a loadout preset"""
	if not has_current_profile():
		return

	if current_profile.has("hero_loadouts") and \
	   current_profile["hero_loadouts"].has(hero_id):
		current_profile["hero_loadouts"][hero_id].erase(str(slot))
		save_current_profile()
		print("🗑️ Deleted loadout for %s (slot %d)" % [hero_id, slot])


# ============================================
# CURRENT SQUAD MANAGEMENT
# ============================================

func set_current_squad(hero_ids: Array[String]) -> void:
	"""Set the active squad for missions (max 3 heroes)"""
	if not has_current_profile():
		return

	# Ensure max 3 heroes
	var squad = hero_ids.duplicate()
	if squad.size() > 3:
		squad.resize(3)

	current_profile["current_squad"] = squad
	save_current_profile()
	print("👥 Squad updated: ", squad)


func get_current_squad() -> Array[String]:
	"""Get the active squad hero IDs"""
	if not has_current_profile():
		return []

	return current_profile.get("current_squad", [])


func add_hero_to_squad(hero_id: String) -> bool:
	"""Add a hero to the current squad (max 3)"""
	var squad = get_current_squad()

	# Check if already in squad
	if squad.has(hero_id):
		print("⚠️ Hero already in squad: ", hero_id)
		return false

	# Check max size
	if squad.size() >= 3:
		print("⚠️ Squad is full (max 3 heroes)")
		return false

	squad.append(hero_id)
	set_current_squad(squad)
	return true


func remove_hero_from_squad(hero_id: String) -> bool:
	"""Remove a hero from the current squad"""
	var squad = get_current_squad()

	if not squad.has(hero_id):
		return false

	squad.erase(hero_id)
	set_current_squad(squad)
	return true


# ============================================
# HERO UNLOCK MANAGEMENT
# ============================================

func unlock_hero(hero_id: String) -> bool:
	"""Unlock a hero (for heroes that cost gold)"""
	if not has_current_profile():
		return false

	# Ensure unlocked_heroes exists
	if not current_profile.has("unlocked_heroes"):
		current_profile["unlocked_heroes"] = []

	# Check if already unlocked
	if current_profile["unlocked_heroes"].has(hero_id):
		print("⚠️ Hero already unlocked: ", hero_id)
		return false

	# Unlock
	current_profile["unlocked_heroes"].append(hero_id)
	save_current_profile()
	print("✅ Unlocked hero: ", hero_id)
	return true


func is_hero_unlocked(hero_id: String) -> bool:
	"""Check if a hero is unlocked"""
	if not has_current_profile():
		return false

	if not current_profile.has("unlocked_heroes"):
		return false

	return current_profile["unlocked_heroes"].has(hero_id)
