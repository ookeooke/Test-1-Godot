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
		"build_cost": 70,  # BALANCE FIX: Was 100g (50% of start gold), now 70g (28% - matches KR1's 26%)
		"type": "ranged_single",
		"description": "Fast-attacking ranged tower. Choose Damage path for glass cannon DPS or Range path for extended coverage.",
		"scene_path": "res://scenes/towers/archer_tower.tscn",

		"levels": {
			1: {
				"damage": 8,  # BALANCE: Lowered from 12 to match Kingdom Rush difficulty (KR = 6.5 DPS)
				"attack_speed": 1.2,  # BALANCE: Increased from 1.0 to compensate slightly
				"range": 280,  # BALANCE: Matches Kingdom Rush range exactly
				"dps": 9.6,  # Was 12.0 - Closer to KR's 6.5 DPS
				"cost_to_next": 60
			},
			2: {
				"damage": 12,  # BALANCE: Was 17 - More gradual scaling
				"attack_speed": 1.4,  # BALANCE: Was 1.3 - Moderate increase
				"range": 280,  # No range increase until Range Path
				"dps": 16.8,  # Was 22.1 - Linear scaling ~75% increase from L1
				"cost_to_next": 90
			},
			3: {
				"damage": 18,  # BALANCE: Was 27 - More balanced progression
				"attack_speed": 1.6,  # Same as before
				"range": 280,  # No range increase until Range Path
				"dps": 28.8,  # Was 43.2 - ~3x L1 instead of 3.6x
				"cost_to_next": 150  # Path choice cost
			},
			# Level 4 - Path choice required
			4: {
				"damage_path": {
					"damage": 28,  # BALANCE: Was 36 - Glass cannon but not overpowered
					"attack_speed": 1.8,  # BALANCE: Was 2.0 - Toned down speed
					"range": 280,  # Damage path keeps base range
					"dps": 50.4,  # Was 72.0 - Strong but not melting bosses
					"cost_to_next": 200,
					"path_name": "Sharpshooter"
				},
				"range_path": {
					"damage": 18,  # Same as L3 - trading DPS for coverage
					"attack_speed": 1.6,  # Same as L3
					"range": 400,  # BALANCE: Was 300 - NOW ACTUALLY GIVES RANGE (+43%)
					"dps": 28.8,  # Same as L3 - meaningful tradeoff
					"cost_to_next": 200,
					"path_name": "Ranger Tower"
				}
			},
			# Level 5 - Max level
			5: {
				"damage_path": {
					"damage": 38,  # BALANCE: Was 40 - Peak damage for glass cannon
					"attack_speed": 2.0,  # BALANCE: Was 2.5 - Capped at 2.0 for balance
					"range": 280,  # Damage path keeps base range
					"dps": 76.0,  # Was 100.0 - Strong endgame without melting bosses in 4s
					"cost_to_next": 0,  # Max level
					"path_name": "Elite Sharpshooter"
				},
				"range_path": {
					"damage": 22,  # BALANCE: Was 35 - Moderate damage
					"attack_speed": 1.8,  # Same as before
					"range": 500,  # BALANCE: Was 300 - HUGE range advantage (+78% from base)
					"dps": 39.6,  # Was 63.0 - Lower DPS but covers entire map sections
					"cost_to_next": 0,  # Max level
					"path_name": "Master Ranger"
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
		"build_cost": 70,  # BALANCE FIX: Was 120g, now 70g (matches archer tower cost)
		"type": "garrison",
		"description": "Spawns melee soldiers that block and fight enemies on the path. Soldiers respawn after death.",
		"scene_path": "res://scenes/towers/soldier_tower.tscn",

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
				"cost_to_next": 150  # Path choice upgrade
			},
			4: {
				"defense_path": {
					"soldier_count": 4,
					"soldier_health": 280,  # Very tanky
					"soldier_damage": 28,
					"soldier_attack_speed": 1.6,
					"respawn_time": 3.0,
					"cost_to_next": 200
				},
				"offense_path": {
					"soldier_count": 4,
					"soldier_health": 250,  # Less tanky but...
					"soldier_damage": 35,  # Much higher damage
					"soldier_attack_speed": 1.8,
					"respawn_time": 3.5,
					"cost_to_next": 200
				}
			},
			5: {
				"defense_path": {
					"soldier_count": 4,
					"soldier_health": 320,  # 100 base + 220 delta
					"soldier_damage": 38,   # 10 base + 28 delta
					"soldier_attack_speed": 2.0,
					"respawn_time": 2.5
				},
				"offense_path": {
					"soldier_count": 4,
					"soldier_health": 300,  # 100 base + 200 delta
					"soldier_damage": 50,   # 10 base + 40 delta
					"soldier_attack_speed": 2.2,
					"respawn_time": 3.0
				}
			}
		},

		"total_costs": {
			"to_level_3": 200,  # 80 + 120
			"to_level_5_defense": 550,  # 80 + 120 + 150 + 200
			"to_level_5_offense": 550   # 80 + 120 + 150 + 200
		}
	},

	"mage": {
		"name": "Mage Tower",
		"icon": "⚡",
		"build_cost": 75,
		"type": "ranged_aoe",
		"description": "Magic tower that deals area damage. Choose Inferno path for maximum destruction or Frost path for enemy control.",
		"scene_path": "res://scenes/towers/mage_tower.tscn",

		"levels": {
			1: {
				"damage": 6,  # Lower than archer due to AOE
				"attack_speed": 0.8,  # Slower than archer
				"range": 300,  # Slightly longer range
				"splash_radius": 80,  # AOE damage radius
				"dps": 4.8,  # Lower single-target DPS, but hits multiple
				"cost_to_next": 70
			},
			2: {
				"damage": 10,
				"attack_speed": 0.9,
				"range": 300,
				"splash_radius": 90,
				"dps": 9.0,
				"cost_to_next": 100
			},
			3: {
				"damage": 15,
				"attack_speed": 1.0,
				"range": 320,
				"splash_radius": 100,
				"dps": 15.0,
				"cost_to_next": 150  # Path choice cost
			},
			# Level 4 - Path choice required
			4: {
				"inferno_path": {
					"damage": 24,  # High damage
					"attack_speed": 1.1,
					"range": 320,
					"splash_radius": 120,  # Larger explosion
					"dps": 26.4,
					"cost_to_next": 200,
					"path_name": "Inferno Tower"
				},
				"frost_path": {
					"damage": 12,  # Lower damage
					"attack_speed": 1.2,
					"range": 340,  # Longer range
					"splash_radius": 110,
					"slow_amount": 0.5,  # Slows enemies to 50% speed
					"slow_duration": 2.0,  # Slow lasts 2 seconds
					"dps": 14.4,
					"cost_to_next": 200,
					"path_name": "Frost Tower"
				}
			},
			# Level 5 - Max level
			5: {
				"inferno_path": {
					"damage": 32,
					"attack_speed": 1.3,
					"range": 320,
					"splash_radius": 140,  # Massive AOE
					"dps": 41.6,
					"cost_to_next": 0,
					"path_name": "Archmage Inferno"
				},
				"frost_path": {
					"damage": 18,
					"attack_speed": 1.4,
					"range": 360,
					"splash_radius": 130,
					"slow_amount": 0.3,  # Slows to 30% speed (70% reduction)
					"slow_duration": 3.0,
					"dps": 25.2,
					"cost_to_next": 0,
					"path_name": "Archmage Frost"
				}
			}
		},

		"total_costs": {
			"to_level_3": 170,  # 70 + 100
			"inferno_path_full": 520,  # 70 + 100 + 150 + 200
			"frost_path_full": 520
		}
	},

	"artillery": {
		"name": "Artillery Tower",
		"icon": "💣",
		"build_cost": 100,  # Most expensive starting tower
		"type": "ranged_artillery",
		"description": "Long-range siege tower with devastating power. Choose Cannon for single-target destruction or Mortar for area bombardment.",
		"scene_path": "res://scenes/towers/artillery_tower.tscn",

		"levels": {
			1: {
				"damage": 20,  # Very high damage per shot
				"attack_speed": 0.4,  # Very slow
				"range": 350,  # Longest range
				"splash_radius": 0,  # No splash at L1 (single target)
				"dps": 8.0,  # Lower DPS due to slow speed, but powerful hits
				"cost_to_next": 90
			},
			2: {
				"damage": 30,
				"attack_speed": 0.5,
				"range": 370,
				"splash_radius": 60,  # Gains small splash
				"dps": 15.0,
				"cost_to_next": 130
			},
			3: {
				"damage": 45,
				"attack_speed": 0.6,
				"range": 400,
				"splash_radius": 80,
				"dps": 27.0,
				"cost_to_next": 180  # Path choice cost
			},
			# Level 4 - Path choice required
			4: {
				"cannon_path": {
					"damage": 70,  # Massive single-shot damage
					"attack_speed": 0.6,
					"range": 420,
					"splash_radius": 50,  # Small splash
					"knockback": 150,  # Pushes enemies back
					"dps": 42.0,
					"cost_to_next": 250,
					"path_name": "Heavy Cannon"
				},
				"mortar_path": {
					"damage": 40,  # Lower damage
					"attack_speed": 0.8,  # Faster
					"range": 450,  # Longer range
					"splash_radius": 140,  # Large AOE
					"dps": 32.0,
					"cost_to_next": 250,
					"path_name": "Siege Mortar"
				}
			},
			# Level 5 - Max level
			5: {
				"cannon_path": {
					"damage": 100,  # Highest single-shot damage in game
					"attack_speed": 0.7,
					"range": 450,
					"splash_radius": 60,
					"knockback": 200,
					"dps": 70.0,
					"cost_to_next": 0,
					"path_name": "Mega Cannon"
				},
				"mortar_path": {
					"damage": 55,
					"attack_speed": 1.0,
					"range": 500,  # Extreme range
					"splash_radius": 180,  # Massive AOE
					"dps": 55.0,
					"cost_to_next": 0,
					"path_name": "Grand Bombard"
				}
			}
		},

		"total_costs": {
			"to_level_3": 220,  # 90 + 130
			"cannon_path_full": 650,  # 90 + 130 + 180 + 250
			"mortar_path_full": 650
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
