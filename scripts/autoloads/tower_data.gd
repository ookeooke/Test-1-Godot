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
		"build_cost": 70, # KR1: 70g
		"type": "ranged_single",
		"description": "Rapid-fire physical damage. The staple of defense.",
		"scene_path": "res://scenes/towers/archer_tower.tscn",

		"levels": {
			1: {
				"damage": 6, # KR1: 5-7
				"attack_speed": 0.8,
				"range": 280,
				"cost_to_next": 110
			},
			2: {
				"damage": 10, # KR1: 8-12
				"attack_speed": 0.7,
				"range": 300,
				"cost_to_next": 160
			},
			3: {
				"damage": 15, # KR1: 12-18
				"attack_speed": 0.6,
				"range": 320,
				"cost_to_next": 230
			},
			# Level 4 - Path choice required
			4: {
				"damage_path": { # Mapped to: Ranger's Hideout (Machine Gun)
					"damage": 18, # Low damage per shot, high fire rate
					"attack_speed": 0.4, # Machine Gun!
					"range": 350,
					"dps": 45.0,
					"cost_to_next": 350,
					"path_name": "Rangers Hideout"
				},
				"range_path": { # Mapped to: Musketeer Garrison (Sniper)
					"damage": 50, # Massive single shot
					"attack_speed": 1.5, # Slow reload
					"range": 450, # Sniper range
					"dps": 33.3,
					"cost_to_next": 350,
					"path_name": "Musketeer Garrison"
				}
			},
			# Level 5 - Legendary Tier (Custom Extrapolation)
			5: {
				"damage_path": { # Elite Ranger
					"damage": 24,
					"attack_speed": 0.3, # 3.3 shots/sec
					"range": 380,
					"dps": 80.0,
					"cost_to_next": 0,
					"path_name": "Elite Ranger"
				},
				"range_path": { # Royal Musketeer
					"damage": 80,
					"attack_speed": 1.4,
					"range": 500, # Map presence
					"dps": 57.0,
					"cost_to_next": 0,
					"path_name": "Royal Musketeer"
				}
			}
		},

		"total_costs": {
			"to_level_3": 340, # 70 + 110 + 160
			"damage_path_full": 920, # 340 + 230 + 350
			"range_path_full": 920
		}
	},

	"barracks": {
		"name": "Barracks",
		"icon": "🛡️",
		"build_cost": 70, # KR1: 70g
		"type": "garrison",
		"description": "Spawns melee soldiers that block and fight enemies on the path. Soldiers respawn after death.",
		"scene_path": "res://scenes/towers/soldier_tower.tscn",

		"levels": {
			1: {
				"soldier_count": 3,
				"soldier_health": 60, # KR1: 60
				"soldier_damage": 2, # KR1: 1-3
				"soldier_attack_speed": 1.0,
				"respawn_time": 10.0,
				"range": 250,
				"cost_to_next": 110
			},
			2: {
				"soldier_count": 3,
				"soldier_health": 100, # KR1: 100
				"soldier_damage": 4, # KR1: 3-5
				"soldier_attack_speed": 1.0,
				"respawn_time": 10.0,
				"range": 270,
				"cost_to_next": 160
			},
			3: {
				"soldier_count": 3,
				"soldier_health": 150, # KR1: 150
				"soldier_damage": 8, # KR1: 6-10
				"soldier_attack_speed": 1.0,
				"respawn_time": 10.0,
				"range": 300,
				"cost_to_next": 230
			},
			4: {
				"defense_path": { # Mapped to: Holy Order (Paladins)
					"soldier_count": 3,
					"soldier_health": 250, # High HP
					"soldier_damage": 12,
					"soldier_attack_speed": 1.0,
					"respawn_time": 8.0, # Faster respawn upgrade
					"range": 320,
					"cost_to_next": 350,
					"path_name": "Holy Order"
				},
				"offense_path": { # Mapped to: Barbarian Mead Hall
					"soldier_count": 3,
					"soldier_health": 180, # Lower HP
					"soldier_damage": 20, # High Damage
					"soldier_attack_speed": 0.8, # Faster attacks
					"respawn_time": 10.0,
					"range": 320,
					"cost_to_next": 350,
					"path_name": "Barbarian Hall"
				}
			},
			5: { # Legendary Tier
				"defense_path": { # Holy Champion
					"soldier_count": 3,
					"soldier_health": 350, # Immortals
					"soldier_damage": 18,
					"soldier_attack_speed": 1.0,
					"respawn_time": 5.0,
					"range": 350,
					"path_name": "Holy Champion"

				},
				"offense_path": { # Warlord
					"soldier_count": 3,
					"soldier_health": 250,
					"soldier_damage": 35,
					"soldier_attack_speed": 0.6,
					"respawn_time": 8.0,
					"path_name": "Warlord"
				}
			}
		},

		"total_costs": {
			"to_level_3": 340,
			"defense_path_full": 920,
			"offense_path_full": 920
		}
	},

	"mage": {
		"name": "Mage Tower",
		"icon": "⚡",
		"build_cost": 100, # KR1: 100g
		"type": "ranged_aoe",
		"description": "Armor piercing magic damage. High burst, slow speed.",
		"scene_path": "res://scenes/towers/mage_tower.tscn",

		"levels": {
			1: {
				"damage": 15, # KR1: 9-17
				"attack_speed": 1.5,
				"range": 280,
				"splash_radius": 0, # Single target (mostly)
				"dps": 10.0,
				"cost_to_next": 160
			},
			2: {
				"damage": 35, # KR1: 23-43
				"attack_speed": 1.5,
				"range": 300,
				"splash_radius": 0,
				"dps": 23.3,
				"cost_to_next": 240
			},
			3: {
				"damage": 60, # KR1: 40-74
				"attack_speed": 1.5,
				"range": 320,
				"splash_radius": 0,
				"dps": 40.0,
				"cost_to_next": 300
			},
			# Level 4 - Path choice required
			4: {
				"inferno_path": { # Mapped to: Arcane Wizard (Burst)
					"damage": 100, # KR1: 70-130
					"attack_speed": 1.7, # Slower
					"range": 350,
					"splash_radius": 0,
					"dps": 58.8,
					"cost_to_next": 400,
					"path_name": "Arcane Wizard"
				},
				"frost_path": { # Mapped to: Sorcerer Mage (Debuff)
					"damage": 40, # KR1: 30-50
					"attack_speed": 1.2, # Faster
					"range": 320,
					"splash_radius": 0,
					"slow_amount": 0.5, # Curse
					"slow_duration": 3.0,
					"dps": 33.3,
					"cost_to_next": 400,
					"path_name": "Sorcerer Mage"
				}
			},
			# Level 5 - Legendary Tier
			5: {
				"inferno_path": { # Arch-Wizard
					"damage": 140,
					"attack_speed": 1.5,
					"range": 380,
					"splash_radius": 0,
					"dps": 93.3,
					"cost_to_next": 0,
					"path_name": "Arch-Wizard"
				},
				"frost_path": { # High Sorcerer
					"damage": 60,
					"attack_speed": 1.0,
					"range": 350,
					"splash_radius": 0,
					"slow_amount": 0.7,
					"slow_duration": 4.0,
					"dps": 60.0,
					"cost_to_next": 0,
					"path_name": "High Sorcerer"
				}
			}
		},

		"total_costs": {
			"to_level_3": 500, # 100 + 160 + 240
			"inferno_path_full": 1200, # 500 + 300 + 400
			"frost_path_full": 1200
		}
	},

	"artillery": {
		"name": "Artillery Tower",
		"icon": "💣",
		"build_cost": 125, # KR1: 125g
		"type": "ranged_artillery",
		"description": "Area damage bombardment. Very slow but essential for crowds.",
		"scene_path": "res://scenes/towers/artillery_tower.tscn",

		"levels": {
			1: {
				"damage": 8, # KR1: 5-9
				"attack_speed": 3.0,
				"range": 320,
				"splash_radius": 80,
				"cost_to_next": 220
			},
			2: {
				"damage": 15, # KR1: 10-18
				"attack_speed": 3.0,
				"range": 340,
				"splash_radius": 90,
				"dps": 5.0,
				"cost_to_next": 320
			},
			3: {
				"damage": 30, # KR1: 20-35
				"attack_speed": 3.0,
				"range": 360,
				"splash_radius": 100,
				"dps": 10.0,
				"cost_to_next": 500
			},
			# Level 4 - Path choice required
			4: {
				"cannon_path": { # Mapped to: Big Bertha (Splash)
					"damage": 70, # KR1: 50-90
					"attack_speed": 3.0,
					"range": 400,
					"splash_radius": 140, # Huge AOE
					"knockback": 150,
					"dps": 23.3,
					"cost_to_next": 600,
					"path_name": "Big Bertha"
				},
				"mortar_path": { # Mapped to: Tesla x104 (Chain)
					"damage": 45, # KR1: 30-60
					"attack_speed": 2.5,
					"range": 380,
					"splash_radius": 120, # Static Field
					"dps": 18.0,
					"cost_to_next": 600,
					"path_name": "Tesla x104"
				}
			},
			# Level 5 - Legendary Tier
			5: {
				"cannon_path": { # Doomsday Bertha
					"damage": 110,
					"attack_speed": 2.8,
					"range": 420,
					"splash_radius": 160,
					"knockback": 200,
					"dps": 39.2,
					"cost_to_next": 0,
					"path_name": "Doomsday Bertha"
				},
				"mortar_path": { # Zeus Coil
					"damage": 70,
					"attack_speed": 2.2,
					"range": 400,
					"splash_radius": 140,
					"dps": 31.8,
					"cost_to_next": 0,
					"path_name": "Zeus Coil"
				}
			}
		},

		"total_costs": {
			"to_level_3": 665,
			"cannon_path_full": 1765,
			"mortar_path_full": 1765
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

func get_tower_scene_path(tower_id: String) -> String:
	"""Get scene path for a tower (Phase 3A: Dynamic loading)"""
	var tower = get_tower_data(tower_id)
	return tower.get("scene_path", "")

func get_tower_scene(tower_id: String) -> PackedScene:
	"""Load and return tower scene (Phase 3A: Dynamic loading)

	Returns:
		PackedScene if successful, null if tower not found or scene fails to load
	"""
	var scene_path = get_tower_scene_path(tower_id)

	if scene_path.is_empty():
		push_error("[TowerData] No scene_path found for tower: %s" % tower_id)
		return null

	var scene = load(scene_path)

	if scene == null:
		push_error("[TowerData] Failed to load scene for tower %s at path: %s" % [tower_id, scene_path])
		return null

	return scene

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
