extends Node

# SaveManager - Handles all save/load operations for player profiles
# Singleton autoload for global save access

# Preload DifficultyConstants for 5-star rating system
# const DifficultyConstants = preload("res://scripts/constants/difficulty_constants.gd")

signal profile_loaded(profile_data: Dictionary)
signal profile_saved(profile_name: String)
signal profile_created(profile_name: String)
signal hero_attributes_changed(hero_id: String) # Emitted when attribute points change

const SAVE_DIR = "user://saves/"
const SAVE_EXTENSION = ".save"
const AUTO_SAVE_INTERVAL = 5.0 # Auto-save every 5 seconds if dirty

# Starter heroes configuration (data-driven, scalable to 100+ heroes)
const STARTER_HEROES = [
	{"id": "ranger", "starter_items": ["basic_bow", "leather_vest", "leather_cap", "power_ring"]},
	{"id": "warrior", "starter_items": ["basic_sword"]},
	{"id": "mage", "starter_items": ["basic_staff"]},
]

var current_profile: Dictionary = {}
var current_profile_name: String = ""

# Auto-save system
var _is_dirty: bool = false # Track if data needs saving
var _is_saving: bool = false # Prevent concurrent saves
var _auto_save_timer: Timer = null

func _ready():
	# Ensure save directory exists
	_ensure_save_directory()
	# Clean up orphaned backups on startup (silent, low-priority)
	_cleanup_orphaned_backups_async()
	# Initialize auto-save timer
	_setup_auto_save_timer()

func _notification(what):
	# Mobile: Save immediately when app is paused/backgrounded
	if what == NOTIFICATION_APPLICATION_PAUSED:
		print("[SaveManager] App paused - saving immediately")
		save_current_profile()

func _setup_auto_save_timer() -> void:
	"""Initialize the auto-save timer that periodically saves dirty data"""
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.timeout.connect(_on_auto_save_tick)
	add_child(_auto_save_timer)
	_auto_save_timer.start()
	print("[SaveManager] Auto-save timer started (%.1fs interval)" % AUTO_SAVE_INTERVAL)

func _on_auto_save_tick() -> void:
	"""Timer callback - saves if data is dirty"""
	if _is_dirty and has_current_profile():
		# print("[SaveManager] Auto-save triggered (dirty flag set)")
		save_current_profile()

func mark_dirty() -> void:
	"""Mark profile data as needing save. Called by game systems when data changes."""
	_is_dirty = true

func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("saves"):
			dir.make_dir("saves")
			print("SaveManager: Created saves directory")

func _cleanup_orphaned_backups_async() -> void:
	"""Run cleanup asynchronously to not block startup"""
	# Run on next frame to avoid blocking _ready()
	await get_tree().process_frame

	var result = cleanup_orphaned_backups()

	# Only log if there were orphaned files
	if result.deleted_count > 0:
		print("[SaveManager] Startup cleanup: Removed %d orphaned backup file(s)" % result.deleted_count)

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
		"gems": 1000, # Starting gems for skill purchases / hero unlocks
		"hero_skills": {}, # hero_id: { skill_id: level }
		"hero_meta_progression": {}, # hero_id: {meta_level, meta_xp, attributes, branch_choice}
		"inventory": { # Shared stash inventory (account-wide, spatial grid)
			"global_inventory": {},
			"item_positions": {}
		},
		"hero_inventories": {}, # Per-hero inventories (hero_id: {items, positions})
		"equipment_registry": { # Hero equipment slots (per-hero persistence)
			"heroes": {}
		},
		"unlocked_heroes": ["ranger", "warrior", "mage"], # Default starter heroes
		"equipped_skills": {}, # hero_id -> {active: [skill_id1, skill_id2, ...], passive: [skill_id1, ...]}
		"tower_loadout": ["archer", "barracks", "mage", "artillery"], # Phase 1: Global tower loadout (3-4 tower IDs)
		"unlocked_towers": ["archer", "barracks", "mage", "artillery"], # Phase 1: All unlocked towers
		"user_preferences": {}, # UI preferences (panel tabs, etc.)
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

		# FIX: Load empty inventory into InventoryManager (same as load_profile does)
		# This ensures autoload managers are initialized with new profile state
		if InventoryManager:
			InventoryManager.load_from_dict(new_profile["inventory"])
			print("[SaveManager] Initialized InventoryManager for new profile")

			# Add 4 starter items to shared stash for new players
			InventoryManager.add_item_instance("basic_bow", 0, {})
			InventoryManager.add_item_instance("leather_vest", 0, {})
			InventoryManager.add_item_instance("leather_cap", 0, {})
			InventoryManager.add_item_instance("power_ring", 0, {})
			InventoryManager.add_item_instance("basic_sword", 0, {})
			InventoryManager.add_item_instance("basic_staff", 0, {})
			print("[SaveManager] ✅ Added 6 starter items to shared stash: bow, vest, cap, ring, sword, staff")

		# Initialize empty hero inventories
		if HeroInventoryManager:
			HeroInventoryManager.load_from_dict({}) # Empty dict = no heroes registered yet
			print("[SaveManager] Initialized HeroInventoryManager for new profile")

			# Register all starter heroes with their items (data-driven config)
			for hero_config in STARTER_HEROES:
				var hero_id = hero_config.id
				HeroInventoryManager.register_hero(hero_id)

				var item_names = []
				for item_id in hero_config.starter_items:
					HeroInventoryManager.add_item_instance_to_hero(hero_id, item_id, 0)
					item_names.append(item_id)

				print("[SaveManager] ✅ %s: Registered with %d starter items (%s)" % [
					hero_id.capitalize(),
					hero_config.starter_items.size(),
					", ".join(item_names)
				])

			print("[SaveManager] ✅ All %d heroes registered and ready for item transfers" % STARTER_HEROES.size())

		# Load empty equipment registry
		if HeroEquipmentRegistry and new_profile.has("equipment_registry"):
			HeroEquipmentRegistry.load_from_dict(new_profile["equipment_registry"])
			print("[SaveManager] Initialized HeroEquipmentRegistry for new profile")

		profile_created.emit(profile_name)
		return true

	return false

func save_profile(profile_data: Dictionary) -> bool:
	if not profile_data.has("profile_name"):
		push_error("SaveManager: Profile data missing profile_name")
		return false

	# Prevent concurrent saves
	if _is_saving:
		print("[SaveManager] Save already in progress, skipping")
		return false

	_is_saving = true

	var profile_name = profile_data["profile_name"]
	var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION
	var temp_path = save_path + ".tmp"
	var backup_path = save_path + ".bak"

	# Update last played time
	profile_data["last_played"] = Time.get_datetime_string_from_system()

	# Save inventory data from InventoryManager (shared stash)
	if InventoryManager:
		profile_data["inventory"] = InventoryManager.save_to_dict()

	# Save hero inventories from HeroInventoryManager
	if HeroInventoryManager:
		profile_data["hero_inventories"] = HeroInventoryManager.save_to_dict()

	# Save equipment data from HeroEquipmentRegistry
	if HeroEquipmentRegistry:
		profile_data["equipment_registry"] = HeroEquipmentRegistry.save_to_dict()

	# Convert to JSON
	var json_string = JSON.stringify(profile_data, "\t")

	# ATOMIC WRITE: Write to temp file first
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to open temp file: ", temp_path)
		_is_saving = false
		return false

	file.store_string(json_string)
	file.flush() # Force OS to write to disk
	file.close()

	# Create backup of existing save (if it exists)
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			# Remove old backup if exists
			if FileAccess.file_exists(backup_path):
				dir.remove(backup_path)
			# Copy current save to backup
			dir.copy(save_path, backup_path)

	# ATOMIC RENAME: Replace save file with temp file
	var directory = DirAccess.open(SAVE_DIR)
	if directory:
		var error = directory.rename(temp_path, save_path)
		if error == OK:
			print("[SaveManager] Profile saved: ", profile_name)
			_is_dirty = false # Clear dirty flag after successful save
			_is_saving = false
			profile_saved.emit(profile_name)
			return true
		else:
			push_error("[SaveManager] Failed to rename temp file (error %d)" % error)
			_is_saving = false
			return false
	else:
		push_error("[SaveManager] Failed to access save directory")
		_is_saving = false
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

			# MIGRATION: Remove old consumables/materials from save data
			if profile_data.has("inventory"):
				var inv_data = profile_data["inventory"]

				# Remove legacy max_slots system (migration to spatial grid only)
				if inv_data.has("max_slots"):
					inv_data.erase("max_slots")

				# Filter out consumable/material items from global_inventory
				if inv_data.has("global_inventory"):
					var cleaned_inv = {}
					for item_id in inv_data["global_inventory"].keys():
						var item_data = ItemDatabase.get_item(item_id)
						# Only keep items if they exist and are equipment types
						if item_data and (item_data.item_type == ItemData.ItemType.WEAPON or
										  item_data.item_type == ItemData.ItemType.ARMOR):
							cleaned_inv[item_id] = inv_data["global_inventory"][item_id]
					inv_data["global_inventory"] = cleaned_inv
					print("[SaveManager] Migration: Removed consumables/materials from inventory")

			current_profile = profile_data
			current_profile_name = profile_name

			# MIGRATION: Auto-equip first 2 skills for old saves
			if not profile_data.has("equipped_skills"):
				profile_data["equipped_skills"] = {}
				print("[SaveManager] Migration: Initializing equipped_skills for old save")

				# For each unlocked hero, auto-equip their first 2 active skills
				for hero_id in profile_data.get("unlocked_heroes", []):
					var hero_skills_dict = profile_data.get("hero_skills", {}).get(hero_id, {})
					var active_skills = []

					# Find active skills (need to check HeroClassDatabase)
					if HeroClassDatabase:
						var hero_data = HeroDatabase.get_hero(hero_id)
						if hero_data:
							var class_config = HeroClassDatabase.get_class_config(hero_data.hero_class)
							if class_config:
								# Filter owned active skills
								for skill_data in class_config.available_skill_pool:
									if skill_data and skill_data.skill_type == HeroSkillData.SkillType.ACTIVE:
										if hero_skills_dict.has(skill_data.skill_id):
											active_skills.append(skill_data.skill_id)
											if active_skills.size() >= 2:
												break

					# Create loadout with first 2 skills
					var max_slots = get_max_skill_slots(hero_id)
					var active_loadout = []
					var passive_loadout = []

					for i in max_slots.active:
						if i < active_skills.size():
							active_loadout.append(active_skills[i])
						else:
							active_loadout.append("") # Empty slot

					for i in max_slots.passive:
						passive_loadout.append("") # Empty passive slots for now

					profile_data["equipped_skills"][hero_id] = {
						"active": active_loadout,
						"passive": passive_loadout
					}

					if active_skills.size() > 0:
						print("[SaveManager] Migration: Auto-equipped %d skills for %s: %s" % [
							active_skills.size(),
							hero_id,
							", ".join(active_skills)
						])

				mark_dirty()

			# MIGRATION: Migrate star system from 3-star (int/float) to 5-star (nested dict) format
			if profile_data.has("level_stars"):
				var needs_migration = false
				for level_id in profile_data["level_stars"].keys():
					var star_type = typeof(profile_data["level_stars"][level_id])
					if star_type == TYPE_INT or star_type == TYPE_FLOAT:
						needs_migration = true
						break

				if needs_migration:
					print("[SaveManager] Migration: Converting 3-star system to 5-star system...")
					for level_id in profile_data["level_stars"].keys():
						var stars = profile_data["level_stars"][level_id]
						var star_type = typeof(stars)
						if star_type == TYPE_INT or star_type == TYPE_FLOAT:
							var stars_int = int(stars)
							profile_data["level_stars"][level_id] = {
								"normal": stars_int,
								"hard": 0,
								"unlimited": 0
							}
							print("  └─ Migrated %s: %s stars → {normal: %d, hard: 0, unlimited: 0}" % [level_id, str(stars), stars_int])

					mark_dirty()
					print("[SaveManager] Migration: 5-star system migration complete!")

			# Load inventory data into InventoryManager (shared stash)
			if InventoryManager and profile_data.has("inventory"):
				InventoryManager.load_from_dict(profile_data["inventory"])

			# Load hero inventories into HeroInventoryManager
			if HeroInventoryManager:
				if profile_data.has("hero_inventories"):
					HeroInventoryManager.load_from_dict(profile_data["hero_inventories"])
				else:
					# Migration: Initialize empty hero inventories for old saves
					print("[SaveManager] Migration: Initializing empty hero inventories")

			# Load equipment data into HeroEquipmentRegistry
			if HeroEquipmentRegistry and profile_data.has("equipment_registry"):
				HeroEquipmentRegistry.load_from_dict(profile_data["equipment_registry"])

			# MIGRATION: Add starter items to old profiles that don't have them
			if InventoryManager:
				var all_items = InventoryManager.get_all_items()
				# Check if profile has empty inventory or is missing basic_bow
				var has_basic_bow = false
				for item in all_items:
					if item.item_id == "basic_bow":
						has_basic_bow = true
						break

				if all_items.is_empty() or not has_basic_bow:
					InventoryManager.add_item("basic_bow", 1)
					print("[SaveManager] Migration: Added missing starter item (basic_bow)")
					# Save the profile to persist the migration
					save_current_profile()

			# MIGRATION: Add new weapons (sword/staff) if missing
			if InventoryManager:
				var all_items = InventoryManager.get_all_items()
				var has_sword = false
				var has_staff = false
				for item in all_items:
					if item.item_id == "basic_sword": has_sword = true
					if item.item_id == "basic_staff": has_staff = true
				
				if not has_sword:
					InventoryManager.add_item("basic_sword", 1)
					print("[SaveManager] Migration: Added missing item (basic_sword)")
				if not has_staff:
					InventoryManager.add_item("basic_staff", 1)
					print("[SaveManager] Migration: Added missing item (basic_staff)")
				
				if not has_sword or not has_staff:
					save_current_profile()

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

func mark_level_complete(level_id: String, stars: int = 1, difficulty: String = "normal") -> void:
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	# Validate difficulty
	if not DifficultyConstants.is_valid_difficulty(difficulty):
		push_error("SaveManager: Invalid difficulty: ", difficulty)
		return

	# Add to completed levels if not already there
	if not current_profile["completed_levels"].has(level_id):
		current_profile["completed_levels"].append(level_id)

	# Initialize level_stars entry if needed (support for nested difficulty structure)
	if not current_profile["level_stars"].has(level_id):
		current_profile["level_stars"][level_id] = {}

	# Migrate old format (int/float) to new format (Dictionary) if needed
	var level_data_type = typeof(current_profile["level_stars"][level_id])
	if level_data_type == TYPE_INT or level_data_type == TYPE_FLOAT:
		var old_stars = int(current_profile["level_stars"][level_id])
		current_profile["level_stars"][level_id] = {
			"normal": old_stars,
			"hard": 0,
			"unlimited": 0
		}
		print("[SaveManager] Migrated star data for ", level_id, " from number to Dictionary")

	# Update stars for this difficulty (keep highest)
	var level_data = current_profile["level_stars"][level_id]
	if not level_data.has(difficulty):
		level_data[difficulty] = stars
	else:
		level_data[difficulty] = max(level_data[difficulty], stars)

	# Save profile
	save_profile(current_profile)
	print("SaveManager: Level completed: ", level_id, " with ", stars, " stars on ", difficulty, " difficulty")

func is_level_completed(level_id: String) -> bool:
	if not has_current_profile():
		return false
	return current_profile["completed_levels"].has(level_id)

func get_level_stars(level_id: String, difficulty: String = "normal") -> int:
	"""Get star count for a specific level and difficulty (0-3)"""
	if not has_current_profile():
		return 0

	if not current_profile["level_stars"].has(level_id):
		return 0

	var level_data = current_profile["level_stars"][level_id]
	var level_data_type = typeof(level_data)

	# Handle old format (int/float from JSON) - treat as normal difficulty stars
	if level_data_type == TYPE_INT or level_data_type == TYPE_FLOAT:
		return int(level_data) if difficulty == "normal" else 0

	# New format (Dictionary)
	if level_data_type == TYPE_DICTIONARY:
		return level_data.get(difficulty, 0)

	return 0

func get_level_5star_count(level_id: String) -> int:
	"""Get total star count across all difficulties (0-5 total)
	- 0-3 stars from normal difficulty
	- +1 if hard completed (any stars)
	- +1 if unlimited completed (any stars)
	"""
	if not has_current_profile():
		return 0

	var normal_stars = get_level_stars(level_id, "normal")
	var hard_stars = get_level_stars(level_id, "hard")
	var unlimited_stars = get_level_stars(level_id, "unlimited")

	# Normal contributes 0-3 stars
	# Hard and Unlimited each contribute 0 or 1 star (binary achievement)
	var total = normal_stars
	if hard_stars > 0:
		total += 1
	if unlimited_stars > 0:
		total += 1

	return total

func is_difficulty_unlocked(level_id: String, difficulty: String) -> bool:
	"""Check if a difficulty is unlocked for a level
	- Normal: Always unlocked (for unlocked levels)
	- Hard/Unlimited: Requires 3 stars on Normal
	"""
	if not has_current_profile():
		return false

	# Normal is always available for unlocked levels
	if difficulty == "normal":
		return true

	# Hard and Unlimited require 3 stars on normal
	if difficulty == "hard" or difficulty == "unlimited":
		return get_level_stars(level_id, "normal") >= 3

	return false

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
	var backup_path = save_path + ".bak"

	if not FileAccess.file_exists(save_path):
		push_error("SaveManager: Profile not found: ", profile_name)
		return false

	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		var error = dir.remove(save_path)
		if error == OK:
			# Also delete backup file if it exists
			if FileAccess.file_exists(backup_path):
				var backup_error = dir.remove(backup_path)
				if backup_error == OK:
					print("SaveManager: Deleted backup file: ", profile_name + ".bak")
				else:
					push_warning("SaveManager: Failed to delete backup file (error %d)" % backup_error)

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

func cleanup_orphaned_backups() -> Dictionary:
	"""Clean up orphaned .save.bak files that have no matching .save file

	Returns:
		Dictionary with {deleted_count: int, deleted_files: Array[String], errors: Array[String]}
	"""
	var result = {
		"deleted_count": 0,
		"deleted_files": [],
		"errors": []
	}

	var dir = DirAccess.open(SAVE_DIR)
	if not dir:
		result.errors.append("Failed to open save directory")
		push_error("[SaveManager] Failed to open save directory for cleanup")
		return result

	# Scan for all .bak files
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		# Check if this is a .save.bak file
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION + ".bak"):
			# Extract the profile name (remove .save.bak)
			var profile_name = file_name.trim_suffix(SAVE_EXTENSION + ".bak")
			var save_path = SAVE_DIR + profile_name + SAVE_EXTENSION

			# Check if corresponding .save file exists
			if not FileAccess.file_exists(save_path):
				# This is an orphaned backup - delete it
				var error = dir.remove(file_name)
				if error == OK:
					result.deleted_count += 1
					result.deleted_files.append(file_name)
					print("[SaveManager] Cleaned up orphaned backup: ", file_name)
				else:
					var error_msg = "Failed to delete %s (error %d)" % [file_name, error]
					result.errors.append(error_msg)
					push_warning("[SaveManager] " + error_msg)

		file_name = dir.get_next()

	dir.list_dir_end()

	if result.deleted_count > 0:
		print("[SaveManager] Cleanup complete: Deleted %d orphaned backup(s)" % result.deleted_count)
	else:
		print("[SaveManager] Cleanup complete: No orphaned backups found")

	return result

func save_current_profile() -> bool:
	if not has_current_profile():
		push_error("SaveManager: No profile loaded to save")
		return false
	return save_profile(current_profile)

# ============================================
# GEMS MANAGEMENT (Persistent Meta-Currency)
# ============================================
# Gems are the PERMANENT currency earned from completing levels (star bonuses)
# Used for: hero unlocks, skill upgrades, item upgrades, inventory slots
# NOT used for: in-mission tower building (that uses temporary mission_gold)

func get_gems() -> int:
	"""Get player's current gems (persistent currency)"""
	if not has_current_profile():
		return 0

	# Ensure gems field exists (auto-migrate from old 'currency' field)
	if not current_profile.has("gems"):
		# Migrate old 'currency' field if it exists
		if current_profile.has("currency"):
			current_profile["gems"] = current_profile["currency"]
			current_profile.erase("currency") # Remove old field
			print("💎 SaveManager: Migrated 'currency' → 'gems' (%d)" % current_profile["gems"])
		else:
			current_profile["gems"] = 0

	return current_profile["gems"]

func add_gems(amount: int) -> void:
	"""Add or remove gems (use negative for spending)"""
	if not has_current_profile():
		push_error("SaveManager: No profile loaded")
		return

	if not current_profile.has("gems"):
		current_profile["gems"] = 0

	current_profile["gems"] += amount
	current_profile["gems"] = maxi(current_profile["gems"], 0) # Don't go negative

	print("💎 Gems: ", current_profile["gems"], " (", "+%d" % amount if amount > 0 else str(amount), ")")

	save_current_profile()

func set_gems(amount: int) -> void:
	"""Set gems to a specific amount"""
	if not has_current_profile():
		return

	current_profile["gems"] = maxi(amount, 0)
	save_current_profile()

# ============================================
# DEPRECATED - Backward Compatibility Wrappers
# ============================================

func get_currency() -> int:
	"""DEPRECATED: Use get_gems() instead. Kept for backward compatibility."""
	return get_gems()

func add_currency(amount: int) -> void:
	"""DEPRECATED: Use add_gems() instead. Kept for backward compatibility."""
	add_gems(amount)

func set_currency(amount: int) -> void:
	"""DEPRECATED: Use set_gems() instead. Kept for backward compatibility."""
	set_gems(amount)

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

# NOTE: Equipment save/load now handled by HeroEquipmentRegistry
# Old save_hero_equipment() and get_hero_equipment() functions removed
# to prevent dual save path conflicts. See save_profile() lines 95-96.

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

const MAX_LOADOUT_SLOTS: int = 3 # Build A, B, C

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
		loadouts.append(loadout) # Empty dict if no loadout

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

	var raw_squad = current_profile.get("current_squad", [])
	var typed_squad: Array[String] = []
	typed_squad.assign(raw_squad)
	return typed_squad


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

func get_unlocked_heroes() -> Array:
	"""Get list of all unlocked hero IDs"""
	if not has_current_profile():
		return []
		
	if not current_profile.has("unlocked_heroes"):
		return []
		
	return current_profile["unlocked_heroes"]

# ============================================
# TOWER LOADOUT SYSTEM (Phase 3A)
# ============================================

func get_tower_loadout() -> Array:
	"""Get the current tower loadout (3-4 tower IDs)

	Returns:
		Array of tower_id strings, or default all 4 towers if none set
	"""
	if not has_current_profile():
		return ["archer", "barracks", "mage", "artillery"]

	if not current_profile.has("tower_loadout"):
		return ["archer", "barracks", "mage", "artillery"]

	return current_profile["tower_loadout"]

func set_tower_loadout(loadout: Array) -> bool:
	"""Set the tower loadout (3-4 tower IDs)

	Args:
		loadout: Array of 3-4 tower_id strings

	Returns:
		true if successful, false otherwise
	"""
	if not has_current_profile():
		push_error("SaveManager: Cannot set tower loadout - no profile loaded")
		return false

	if loadout.size() < 3 or loadout.size() > 4:
		push_error("SaveManager: Tower loadout must have 3-4 towers, got %d" % loadout.size())
		return false

	# Validate all tower IDs exist in TowerData
	for tower_id in loadout:
		if not TowerData.get_tower_data(tower_id).has("name"):
			push_error("SaveManager: Invalid tower_id in loadout: %s" % tower_id)
			return false

	current_profile["tower_loadout"] = loadout
	save_current_profile()
	print("✅ Tower loadout updated: %s" % str(loadout))
	return true

func get_unlocked_towers() -> Array:
	"""Get list of all unlocked towers

	Returns:
		Array of tower_id strings
	"""
	if not has_current_profile():
		return ["archer", "barracks", "mage", "artillery"]

	if not current_profile.has("unlocked_towers"):
		current_profile["unlocked_towers"] = ["archer", "barracks", "mage", "artillery"]
		save_current_profile()
		return current_profile["unlocked_towers"]

	# Auto-migrate old profiles: add new towers if missing
	var unlocked = current_profile["unlocked_towers"]
	var all_towers = ["archer", "barracks", "mage", "artillery"]
	var needs_save = false

	for tower_id in all_towers:
		if not tower_id in unlocked:
			unlocked.append(tower_id)
			needs_save = true
			print("[SaveManager] Auto-unlocked new tower: %s" % tower_id)

			# SYNC FIX: Also add to loadout if there's room (max 4 towers)
			if current_profile.has("tower_loadout"):
				if not tower_id in current_profile["tower_loadout"]:
					if current_profile["tower_loadout"].size() < 4:
						current_profile["tower_loadout"].append(tower_id)
						print("[SaveManager] Auto-added %s to loadout" % tower_id)

	if needs_save:
		current_profile["unlocked_towers"] = unlocked
		save_current_profile()

	return current_profile["unlocked_towers"]

func unlock_tower(tower_id: String) -> bool:
	"""Unlock a tower for use

	Args:
		tower_id: Tower to unlock

	Returns:
		true if newly unlocked, false if already unlocked or error
	"""
	if not has_current_profile():
		push_error("SaveManager: Cannot unlock tower - no profile loaded")
		return false

	# Validate tower exists
	if not TowerData.get_tower_data(tower_id).has("name"):
		push_error("SaveManager: Invalid tower_id: %s" % tower_id)
		return false

	# Ensure unlocked_towers array exists
	if not current_profile.has("unlocked_towers"):
		current_profile["unlocked_towers"] = ["archer", "barracks", "mage", "artillery"]

	# Check if already unlocked
	if current_profile["unlocked_towers"].has(tower_id):
		print("⚠️ Tower already unlocked: %s" % tower_id)
		return false

	# Unlock
	current_profile["unlocked_towers"].append(tower_id)
	save_current_profile()
	print("✅ Unlocked tower: %s" % tower_id)
	return true

func is_tower_unlocked(tower_id: String) -> bool:
	"""Check if a tower is unlocked

	Args:
		tower_id: Tower to check

	Returns:
		true if unlocked, false otherwise
	"""
	if not has_current_profile():
		return false

	if not current_profile.has("unlocked_towers"):
		return false

	return current_profile["unlocked_towers"].has(tower_id)

# ============================================
# GAME SETTINGS (UI Scale, Graphics, etc.)
# ============================================

func get_setting(key: String, default_value = null):
	"""Get a game setting value

	Args:
		key: Setting name (e.g., "ui_scale_multiplier")
		default_value: Value to return if setting doesn't exist

	Returns:
		Setting value or default_value
	"""
	if not has_current_profile():
		return default_value

	if not current_profile.has("settings"):
		return default_value

	if current_profile["settings"].has(key):
		return current_profile["settings"][key]

	return default_value

func save_setting(key: String, value) -> void:
	"""Save a game setting value

	Args:
		key: Setting name (e.g., "ui_scale_multiplier")
		value: Setting value
	"""
	if not has_current_profile():
		push_error("SaveManager: Cannot save setting - no profile loaded")
		return

	if not current_profile.has("settings"):
		current_profile["settings"] = {}

	current_profile["settings"][key] = value
	mark_dirty() # Queue auto-save

# ============================================
# HERO META PROGRESSION (Permanent Attributes)
# ============================================
# Meta progression is PERMANENT and carries between missions
# Includes: meta_level, meta_xp, attributes (MIGHT/AGILITY/VITALITY/WISDOM), branch_choice

const META_MAX_LEVEL: int = 50
const META_FREE_STARTING_POINTS: int = 10
const META_SOFT_CAP: int = 30

func get_hero_meta_data(hero_id: String) -> Dictionary:
	"""Get meta progression data for a hero (creates default if not exists)"""
	if not has_current_profile():
		return _get_default_meta_data()

	if not current_profile.has("hero_meta_progression"):
		current_profile["hero_meta_progression"] = {}

	if not current_profile["hero_meta_progression"].has(hero_id):
		current_profile["hero_meta_progression"][hero_id] = _get_default_meta_data()
		mark_dirty()

	return current_profile["hero_meta_progression"][hero_id]

func _get_default_meta_data() -> Dictionary:
	"""Default meta data for a new hero"""
	return {
		"meta_level": 1,
		"meta_xp": 0,
		"attributes": {
			"might": 0,
			"agility": 0,
			"vitality": 0,
			"wisdom": 0
		},
		"branch_choice": "" # "multishot" or "sniper" or "" (not chosen)
	}

func get_meta_level(hero_id: String) -> int:
	"""Get hero's current meta level (1-50)"""
	return get_hero_meta_data(hero_id)["meta_level"]

func get_meta_xp(hero_id: String) -> int:
	"""Get hero's current meta XP"""
	return get_hero_meta_data(hero_id)["meta_xp"]

func get_meta_xp_required(level: int) -> int:
	"""XP needed to level up from 'level' to 'level+1'
	Formula: 200 * level^1.3
	Level 1→2: 200, Level 10→11: ~3,981, Level 50: ~55,107
	"""
	return int(200 * pow(level, 1.3))

func get_meta_xp_progress(hero_id: String) -> Dictionary:
	"""Get XP progress info for UI display"""
	var meta = get_hero_meta_data(hero_id)
	return {
		"current_xp": meta["meta_xp"],
		"required_xp": get_meta_xp_required(meta["meta_level"]),
		"level": meta["meta_level"],
		"is_max_level": meta["meta_level"] >= META_MAX_LEVEL
	}


func get_hero_attributes(hero_id: String) -> Dictionary:
	"""Get all attribute values for a hero"""
	return get_hero_meta_data(hero_id)["attributes"].duplicate()

func get_attribute_value(hero_id: String, attribute: String) -> int:
	"""Get a specific attribute value"""
	var attrs = get_hero_attributes(hero_id)
	return attrs.get(attribute, 0)

func get_total_attribute_points(hero_id: String) -> int:
	"""Get total attribute points available at current meta level"""
	var meta_level = get_meta_level(hero_id)
	return META_FREE_STARTING_POINTS + (meta_level - 1) # 10 free + 1 per level after 1

func get_spent_attribute_points(hero_id: String) -> int:
	"""Get total attribute points spent"""
	var attrs = get_hero_attributes(hero_id)
	var total = 0
	for value in attrs.values():
		total += value
	return total

func get_unspent_attribute_points(hero_id: String) -> int:
	"""Get number of unspent attribute points"""
	return get_total_attribute_points(hero_id) - get_spent_attribute_points(hero_id)

func set_attribute_points(hero_id: String, might: int, agility: int, vitality: int, wisdom: int) -> bool:
	"""Set all attribute points at once (for UI bulk allocation). Validates total doesn't exceed available."""
	var total_requested = might + agility + vitality + wisdom
	var total_available = get_total_attribute_points(hero_id)

	if total_requested > total_available:
		push_error("SaveManager: Requested %d points but only %d available" % [total_requested, total_available])
		return false

	if might < 0 or agility < 0 or vitality < 0 or wisdom < 0:
		push_error("SaveManager: Attribute values cannot be negative")
		return false

	var meta = get_hero_meta_data(hero_id)
	meta["attributes"] = {
		"might": might,
		"agility": agility,
		"vitality": vitality,
		"wisdom": wisdom
	}
	current_profile["hero_meta_progression"][hero_id] = meta
	save_current_profile()

	print("✅ %s attributes set: M%d A%d V%d W%d" % [hero_id, might, agility, vitality, wisdom])
	hero_attributes_changed.emit(hero_id)
	return true

func get_branch_choice(hero_id: String) -> String:
	"""Get the skill branch choice ('multishot', 'sniper', or '' if not chosen)"""
	return get_hero_meta_data(hero_id)["branch_choice"]

func set_branch_choice(hero_id: String, branch: String) -> bool:
	"""Set the skill branch choice. Can only be changed if not already set (or via respec)."""
	var meta = get_hero_meta_data(hero_id)

	# Validate branch name
	var valid_branches = ["multishot", "sniper", ""]
	if not branch in valid_branches:
		push_error("SaveManager: Invalid branch '%s'" % branch)
		return false

	# Check if already chosen (can unlock second at meta level 35)
	if meta["branch_choice"] != "" and branch != "" and meta["meta_level"] < 35:
		push_warning("SaveManager: Branch already chosen. Reach meta level 35 to unlock both.")
		return false

	meta["branch_choice"] = branch
	current_profile["hero_meta_progression"][hero_id] = meta
	save_current_profile()

	print("🌿 %s branch choice: %s" % [hero_id, branch if branch != "" else "(none)"])
	return true

func can_unlock_second_branch(hero_id: String) -> bool:
	"""Check if hero can unlock the second skill branch (meta level 35+)"""
	return get_meta_level(hero_id) >= 35

# ============================================
# SKILL LOADOUT SYSTEM (Per-Hero)
# ============================================

func get_equipped_skills(hero_id: String) -> Dictionary:
	"""Get equipped skills for a hero (active + passive arrays)

	Returns: {active: Array[String], passive: Array[String]}
	Empty slots are represented as "" (empty string)
	"""
	if not has_current_profile():
		return {"active": [], "passive": []}

	if not current_profile.has("equipped_skills"):
		current_profile["equipped_skills"] = {}

	if not current_profile["equipped_skills"].has(hero_id):
		# Initialize with empty slots based on hero's class config
		var max_slots = get_max_skill_slots(hero_id)
		var active_slots = []
		var passive_slots = []

		for i in max_slots.active:
			active_slots.append("")
		for i in max_slots.passive:
			passive_slots.append("")

		current_profile["equipped_skills"][hero_id] = {
			"active": active_slots,
			"passive": passive_slots
		}
		mark_dirty()

	return current_profile["equipped_skills"][hero_id].duplicate()

func update_equipped_skills(hero_id: String, equipped: Dictionary) -> void:
	"""Update equipped skills for a hero (used by SkillTransactionService)

	Args:
		hero_id: Hero ID
		equipped: Dictionary with {active: Array[String], passive: Array[String]}

	Note: This is called by SkillTransactionService after validation.
	SaveManager is the data layer - validation happens in the service layer.
	"""
	if not has_current_profile():
		push_error("[SaveManager] Cannot update equipped skills - no profile loaded")
		return

	if not current_profile.has("equipped_skills"):
		current_profile["equipped_skills"] = {}

	current_profile["equipped_skills"][hero_id] = equipped
	# Note: mark_dirty() is called by SkillTransactionService after transaction completes

func equip_skill(hero_id: String, skill_type: String, slot_index: int, skill_id: String) -> bool:
	"""Equip a skill to a specific slot

	Args:
		hero_id: Hero to equip skill for
		skill_type: "active" or "passive"
		slot_index: Which slot (0-based index)
		skill_id: Skill ID to equip

	Returns: true if successful

	Note: This method delegates to SkillTransactionService for validation and business logic.
	      SaveManager is the data layer - validation happens in the service layer.
	      Consider using SkillTransactionService.equip_skill() directly for new code.
	"""
	return SkillTransactionService.equip_skill(hero_id, skill_id, skill_type, slot_index)

func unequip_skill(hero_id: String, skill_type: String, slot_index: int) -> bool:
	"""Unequip a skill from a slot (set to "")

	Returns: true if successful

	Note: This method delegates to SkillTransactionService for validation and business logic.
	      SaveManager is the data layer - validation happens in the service layer.
	      Consider using SkillTransactionService.unequip_skill() directly for new code.
	"""
	return SkillTransactionService.unequip_skill(hero_id, skill_type, slot_index)

func get_max_skill_slots(hero_id: String) -> Dictionary:
	"""Get max skill slots for a hero based on their class config

	Returns: {active: int, passive: int}
	"""
	# Default fallback
	var default_slots = {"active": 2, "passive": 4}

	# Get hero data
	if not HeroDatabase:
		return default_slots

	var hero_data = HeroDatabase.get_hero(hero_id)
	if not hero_data:
		return default_slots

	# Get class config
	if not HeroClassDatabase:
		return default_slots

	var class_config = HeroClassDatabase.get_class_config(hero_data.hero_class)
	if not class_config:
		return default_slots

	# Return configured slots (access properties directly from Resource)
	var active_slots = 2
	var passive_slots = 4

	if "max_active_ability_slots" in class_config:
		active_slots = class_config.max_active_ability_slots
	if "max_passive_ability_slots" in class_config:
		passive_slots = class_config.max_passive_ability_slots

	return {
		"active": active_slots,
		"passive": passive_slots
	}

func get_unlocked_slot_count(hero_id: String) -> Dictionary:
	"""Get number of UNLOCKED skill slots based on hero level
	
	Progression Curve:
	- Phase 1 (Lv 1-4): 2 Active, 2 Passive (for testing)
	- Phase 2 (Lv 5-9): 3 Active, 3 Passive
	- Phase 3 (Lv 10+): 4 Active, 4 Passive
	"""
	var max_slots = get_max_skill_slots(hero_id)
	
	# Get Hero Level
	var level = 1
	if has_current_profile():
		level = get_meta_level(hero_id)
		
	# Define Unlock Curve
	var active_unlocked = 2 # Start with 2 for testing
	var passive_unlocked = 2
	
	if level >= 5:
		active_unlocked = 3
		passive_unlocked = 3
	if level >= 10:
		active_unlocked = 4
		passive_unlocked = 4
		
	# Clamp to class maximums
	return {
		"active": min(active_unlocked, max_slots.active),
		"passive": min(passive_unlocked, max_slots.passive)
	}
