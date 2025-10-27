extends Node

# ============================================
# TOWER DATA - Single Source of Truth
# ============================================
# Centralized tower stat definitions for all systems:
# - Tower Codex (encyclopedia)
# - Build Menu (costs)
# - Future: Tower gameplay (Phase 2 refactor)
#
# NOTE: Phase 1 - archer_tower.gd still has hardcoded stats for gameplay
#       This is intentional to avoid breaking existing systems.
#       Stats must be kept in sync manually until Phase 2 refactor.

const TOWERS = {
	"archer": {
		"name": "Archer Tower",
		"icon": "🏹",
		"build_cost": 100,
		"type": "ranged_single",
		"description": "Fast-attacking ranged tower. Choose Damage path for glass cannon DPS or Range path for extended coverage.",

		"levels": {
			1: {
				"damage": 12,
				"attack_speed": 1.0,
				"range": 300,
				"dps": 12.0,
				"cost_to_next": 60
			},
			2: {
				"damage": 17,
				"attack_speed": 1.3,
				"range": 350,
				"dps": 22.1,
				"cost_to_next": 90
			},
			3: {
				"damage": 27,
				"attack_speed": 1.6,
				"range": 400,
				"dps": 43.2,
				"cost_to_next": 150  # Path choice cost
			},
			# Level 4 - Path choice required
			4: {
				"damage_path": {
					"damage": 36,
					"attack_speed": 2.0,
					"range": 500,
					"dps": 72.0,
					"cost_to_next": 200,
					"path_name": "Glass Cannon"
				},
				"range_path": {
					"damage": 27,
					"attack_speed": 1.6,
					"range": 500,
					"dps": 43.2,
					"cost_to_next": 200,
					"path_name": "Long-range Sniper"
				}
			},
			# Level 5 - Max level
			5: {
				"damage_path": {
					"damage": 45,
					"attack_speed": 2.5,
					"range": 500,
					"dps": 112.5,
					"cost_to_next": 0,  # Max level
					"path_name": "Ultimate Glass Cannon"
				},
				"range_path": {
					"damage": 35,
					"attack_speed": 1.8,
					"range": 450,
					"dps": 63.0,
					"cost_to_next": 0,  # Max level
					"path_name": "Balanced Sniper"
				}
			}
		},

		"total_costs": {
			"to_level_3": 150,  # 60 + 90
			"damage_path_full": 500,  # 60 + 90 + 150 + 200
			"range_path_full": 500
		}
	},

	"barracks": {
		"name": "Barracks",
		"icon": "🛡️",
		"build_cost": 120,
		"type": "garrison",
		"description": "Spawns melee soldiers that block and fight enemies on the path. Soldiers respawn after death.",

		"levels": {
			1: {
				"soldier_count": 4,
				"soldier_health": 100,
				"soldier_damage": 10,
				"soldier_attack_speed": 1.0,
				"respawn_time": 5.0,
				"cost_to_next": 80
			},
			2: {
				"soldier_count": 4,
				"soldier_health": 150,
				"soldier_damage": 15,
				"soldier_attack_speed": 1.2,
				"respawn_time": 4.5,
				"cost_to_next": 120
			},
			3: {
				"soldier_count": 4,
				"soldier_health": 200,
				"soldier_damage": 20,
				"soldier_attack_speed": 1.4,
				"respawn_time": 4.0,
				"cost_to_next": 160
			}
			# Add more levels as needed
		},

		"total_costs": {
			"to_level_3": 200  # 80 + 120
		}
	}
}

# ============================================
# HELPER FUNCTIONS
# ============================================

func get_tower_data(tower_id: String) -> Dictionary:
	"""Get complete data for a tower by ID"""
	return TOWERS.get(tower_id, {})

func get_tower_stats(tower_id: String, level: int, path: String = "") -> Dictionary:
	"""Get stats for a specific tower at a specific level

	Args:
		tower_id: Tower identifier (e.g. "archer", "barracks")
		level: Tower level (1-5)
		path: Path choice for levels 4+ ("damage_path" or "range_path")

	Returns:
		Dictionary with tower stats, or empty dict if not found
	"""
	var tower = get_tower_data(tower_id)
	if tower.is_empty():
		push_warning("[TowerData] Tower not found: %s" % tower_id)
		return {}

	if not tower.levels.has(level):
		push_warning("[TowerData] Level %d not found for tower: %s" % [level, tower_id])
		return {}

	var level_data = tower.levels[level]

	# Handle path choice at level 4+
	if path != "" and level_data.has(path):
		return level_data[path]

	# If no path specified but level has paths, return empty (ambiguous)
	if level_data.has("damage_path") and path == "":
		push_warning("[TowerData] Level %d has path choices but no path specified" % level)
		return {}

	return level_data

func get_build_cost(tower_id: String) -> int:
	"""Get the initial build cost for a tower"""
	var tower = get_tower_data(tower_id)
	return tower.get("build_cost", 0)

func get_all_tower_ids() -> Array[String]:
	"""Get list of all available tower IDs"""
	var ids: Array[String] = []
	for key in TOWERS.keys():
		ids.append(key)
	return ids

func get_tower_name(tower_id: String) -> String:
	"""Get display name for a tower"""
	var tower = get_tower_data(tower_id)
	return tower.get("name", "Unknown Tower")

func get_tower_icon(tower_id: String) -> String:
	"""Get icon emoji for a tower"""
	var tower = get_tower_data(tower_id)
	return tower.get("icon", "❓")

func get_tower_description(tower_id: String) -> String:
	"""Get description text for a tower"""
	var tower = get_tower_data(tower_id)
	return tower.get("description", "")

func get_tower_type(tower_id: String) -> String:
	"""Get tower type classification"""
	var tower = get_tower_data(tower_id)
	return tower.get("type", "unknown")

# ============================================
# FUTURE: Phase 2 - Addon/Modifier Support
# ============================================
# When implementing addon system, add these functions:
#
# func get_tower_stats_with_modifiers(tower_id: String, level: int, path: String, modifiers: Dictionary) -> Dictionary:
#     """Apply global modifiers (from equipped items) to base stats"""
#     var base_stats = get_tower_stats(tower_id, level, path)
#     # Apply damage_multiplier, attack_speed_multiplier, range_bonus, etc.
#     return modified_stats
