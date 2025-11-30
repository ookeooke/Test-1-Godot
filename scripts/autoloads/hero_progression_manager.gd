##
## HeroProgressionManager
##
## Manages in-mission hero leveling and experience progression.
## Heroes level from 1-20 during each mission, gaining stat bonuses and unlocking abilities.
## Progress resets between missions (temporary, not saved).
##
## Architecture:
## - Tracks XP per hero instance (not hero_id)
## - Exponential XP curve: base_xp * (level^1.5)
## - Auto-levels heroes when XP threshold reached
## - Integrates with existing Stat modifier system
##
## Signals:
## - hero_gained_xp(hero, xp_amount) - For UI updates
## - hero_leveled_up(hero, new_level) - For stat recalc and skill unlocks
##

extends Node

## Emitted when a hero gains experience (even if not enough to level)
signal hero_gained_xp(hero: Node, xp_amount: int)

## Emitted when a hero levels up (may emit multiple times if big XP gain)
signal hero_leveled_up(hero: Node, new_level: int)

## Emitted when a hero's abilities are auto-unlocked
signal abilities_unlocked(hero: Node, skill_ids: Array)

## Base XP required for level 2 (scales exponentially)
const BASE_XP_REQUIREMENT: int = 100

## Maximum hero level in mission (Bloons TD 6 uses 20)
const MAX_LEVEL: int = 20

## Minimum hero level
const MIN_LEVEL: int = 1

## XP tracking per hero instance
## Structure: {hero_instance: {xp: int, level: int}}
var _hero_progress: Dictionary = {}

const DEBUG_HERO_PROGRESSION = true # Toggle detailed logging for hero progression


## Initialize tracking for a hero when they spawn
func register_hero(hero: Node) -> void:
	if hero in _hero_progress:
		push_warning("HeroProgressionManager: Hero already registered: %s" % hero)
		return

	_hero_progress[hero] = {
		"xp": 0,
		"level": MIN_LEVEL,
		"total_xp_earned": 0 # For statistics
	}

	# Set initial level on hero if it has the property
	if hero.has_method("set_current_level"):
		hero.set_current_level(MIN_LEVEL)


## Remove tracking when hero is removed/dies
func unregister_hero(hero: Node) -> void:
	if hero not in _hero_progress:
		push_warning("HeroProgressionManager: Cannot unregister unknown hero: %s" % hero)
		return

	_hero_progress.erase(hero)


## Award XP to a hero (handles level-ups automatically)
func award_xp(hero: Node, amount: int) -> void:
	if amount <= 0:
		return

	if hero not in _hero_progress:
		push_warning("HeroProgressionManager: Cannot award XP to unregistered hero: %s" % hero)
		return

	var progress = _hero_progress[hero]

	# Add XP
	progress.xp += amount
	progress.total_xp_earned += amount
	hero_gained_xp.emit(hero, amount)

	# Check for level-ups (may level multiple times from one XP gain)
	while progress.level < MAX_LEVEL and progress.xp >= get_xp_required(progress.level + 1):
		_level_up_hero(hero)


## Award XP to multiple heroes (e.g., all heroes in radius)
func award_xp_to_multiple(heroes: Array, amount: int) -> void:
	for hero in heroes:
		award_xp(hero, amount)


## Internal: Handle level-up logic
func _level_up_hero(hero: Node) -> void:
	var progress = _hero_progress[hero]

	# Deduct XP for this level
	progress.xp -= get_xp_required(progress.level + 1)
	progress.level += 1

	var new_level = progress.level

	# Update hero's level property
	if hero.has_method("set_current_level"):
		hero.set_current_level(new_level)

	# Emit signal (hero will recalculate stats)
	hero_leveled_up.emit(hero, new_level)

	# Check for ability unlocks
	_check_ability_unlocks(hero, new_level)

	# Debug output
	if DEBUG_HERO_PROGRESSION:
		print("🆙 [HeroProgression] %s leveled up to %d!" % [hero.name, new_level])


## Check if hero should unlock abilities at this level
func _check_ability_unlocks(hero: Node, level: int) -> void:
	# Get hero's available skills
	var available_skills = []
	if hero.has_method("get_available_skills"):
		available_skills = hero.get_available_skills()
	elif "hero_data" in hero and hero.hero_data != null:
		available_skills = hero.hero_data.available_skills
	else:
		return # No skills to unlock

	# Find skills that unlock at this level
	var unlocked_skill_ids = []
	for skill_data in available_skills:
		if skill_data.required_hero_level == level:
			unlocked_skill_ids.append(skill_data.skill_id)
			if DEBUG_HERO_PROGRESSION:
				print("✨ [HeroProgression] Unlocked skill: %s for %s at level %d" % [skill_data.skill_name, hero.name, level])

	if unlocked_skill_ids.size() > 0:
		abilities_unlocked.emit(hero, unlocked_skill_ids)


## Get current level of hero (1-20)
func get_hero_level(hero: Node) -> int:
	if hero not in _hero_progress:
		return MIN_LEVEL
	return _hero_progress[hero].level


## Get current XP of hero (towards next level)
func get_hero_xp(hero: Node) -> int:
	if hero not in _hero_progress:
		return 0
	return _hero_progress[hero].xp


## Get total XP earned this mission (for statistics)
func get_hero_total_xp(hero: Node) -> int:
	if hero not in _hero_progress:
		return 0
	return _hero_progress[hero].total_xp_earned


## Get XP required to reach a specific level
## Formula: BASE_XP * (level^1.5)
## Level 2: 100, Level 5: 559, Level 10: 3162, Level 20: 17889
func get_xp_required(level: int) -> int:
	if level <= MIN_LEVEL:
		return 0
	return int(BASE_XP_REQUIREMENT * pow(level, 1.5))


## Get XP required for hero's next level
func get_xp_to_next_level(hero: Node) -> int:
	if hero not in _hero_progress:
		return get_xp_required(MIN_LEVEL + 1)

	var current_level = _hero_progress[hero].level
	if current_level >= MAX_LEVEL:
		return 0 # Already max level

	return get_xp_required(current_level + 1)


## Get percentage progress to next level (0.0 to 1.0)
func get_level_progress(hero: Node) -> float:
	if hero not in _hero_progress:
		return 0.0

	var progress = _hero_progress[hero]
	if progress.level >= MAX_LEVEL:
		return 1.0

	var xp_required = get_xp_to_next_level(hero)
	if xp_required == 0:
		return 1.0

	return float(progress.xp) / float(xp_required)


## Reset all hero progress (called at mission start/end)
func reset_all_progress() -> void:
	_hero_progress.clear()
	print("[HeroProgressionManager] All hero progress reset")


## Reset specific hero progress
func reset_hero_progress(hero: Node) -> void:
	if hero in _hero_progress:
		_hero_progress[hero] = {
			"xp": 0,
			"level": MIN_LEVEL,
			"total_xp_earned": 0
		}

		if hero.has_method("set_current_level"):
			hero.set_current_level(MIN_LEVEL)


## Debug: Print XP curve for all levels
func print_xp_curve() -> void:
	print("[HeroProgressionManager] XP Curve (1-20):")
	var total_xp = 0
	for level in range(2, MAX_LEVEL + 1):
		var xp = get_xp_required(level)
		total_xp += xp
		print("  Level %2d: %5d XP (total: %6d)" % [level, xp, total_xp])


## Get recommended XP rewards for different enemy tiers
func get_recommended_xp_for_tier(tier: String) -> int:
	match tier.to_lower():
		"tier1", "goblin", "scout":
			return 25
		"tier2", "orc", "wolf", "soldier":
			return 50
		"tier3", "troll", "elite":
			return 100
		"boss", "champion":
			return 500
		_:
			return 10 # Default for unknown


## Calculate XP for wave completion bonus
func get_wave_completion_xp(wave_number: int) -> int:
	# Scale with wave number (later waves = more XP)
	return 50 + (wave_number * 10)


## Get hero statistics for end-of-mission screen
func get_hero_stats(hero: Node) -> Dictionary:
	if hero not in _hero_progress:
		return {
			"final_level": MIN_LEVEL,
			"total_xp_earned": 0,
			"levels_gained": 0
		}

	var progress = _hero_progress[hero]
	return {
		"final_level": progress.level,
		"total_xp_earned": progress.total_xp_earned,
		"levels_gained": progress.level - MIN_LEVEL
	}
