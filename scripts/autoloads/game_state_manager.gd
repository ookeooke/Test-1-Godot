extends Node

## ============================================
## GAME STATE MANAGER - Central stat calculation with modifiers
## ============================================
##
## Single source of truth for all game state values with modifier support.
## Calculates final values from base values + modifiers from equipment, skills, etc.
##
## Architecture:
##   Base Value (from config) + Modifiers (from gear/skills) = Final Value
##
## Calculation Order:
##   1. Flat modifiers (+20 gold)
##   2. Additive modifiers (+15% of base)
##   3. Multiplicative modifiers (×1.1 final)

# ============================================
# SIGNALS
# ============================================

signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal modifiers_changed()

# ============================================
# BASE VALUES (set by LevelManager when level loads)
# ============================================

var _base_starting_gold: int = 0
var _base_starting_lives: int = 0
var _base_tower_costs: Dictionary = {}  # tower_id → base_cost

# ============================================
# CURRENT RUNTIME VALUES
# ============================================

## Current gold amount (starts at calculated starting_gold, changes during gameplay)
var gold: int = 0

## Current lives remaining
var lives: int = 0

## Reference to current level config
var current_level_config: LevelConfig = null

# ============================================
# MODIFIER COLLECTIONS
# ============================================

## Modifiers for starting gold calculation
var _starting_gold_modifiers: Array[StatModifier] = []

## Modifiers for specific tower costs (tower_id → Array[StatModifier])
var _tower_cost_modifiers: Dictionary = {}

## Global modifiers that affect all tower costs
var _global_tower_cost_modifiers: Array[StatModifier] = []

## ============================================
## HERO STAT MODIFIERS REMOVED
## ============================================
## Old hero stat modifier system has been removed.
## Heroes now manage their own stats via Stat objects and EquipmentManager.
## See ranger_hero.gd for the new implementation.

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("[GameStateManager] Initialized")

## Called by LevelManager when a level is loaded
## This is the ONLY place where base values should be set
func initialize_level(level_config: LevelConfig):
	if not level_config:
		push_error("[GameStateManager] Cannot initialize with null level config!")
		return

	current_level_config = level_config
	_base_starting_gold = level_config.starting_gold
	_base_starting_lives = level_config.starting_lives

	# Calculate final starting values with all active modifiers
	gold = get_calculated_starting_gold()
	lives = _base_starting_lives  # Lives typically don't have modifiers

	print("[GameStateManager] Level initialized:")
	print("  Base starting gold: %d" % _base_starting_gold)
	print("  Modifiers applied: %d" % _starting_gold_modifiers.size())
	print("  Final starting gold: %d" % gold)
	print("  Lives: %d" % lives)

	# Emit signals
	gold_changed.emit(gold)
	lives_changed.emit(lives)

## Reset for new run (clears runtime state but keeps modifiers)
func reset_for_new_run():
	_base_starting_gold = 0
	_base_starting_lives = 0
	_base_tower_costs.clear()
	gold = 0
	lives = 0
	current_level_config = null
	print("[GameStateManager] Reset for new run")

# ============================================
# MODIFIER MANAGEMENT - STARTING GOLD
# ============================================

## Add a modifier for starting gold
## Example: equipment that gives +15% starting gold
func add_starting_gold_modifier(modifier: StatModifier):
	_starting_gold_modifiers.append(modifier)
	modifiers_changed.emit()
	print("[GameStateManager] Added starting gold modifier: %s" % modifier.get_debug_string())

	# If level is already loaded, recalculate gold
	if current_level_config != null:
		var new_gold = get_calculated_starting_gold()
		print("  Starting gold recalculated: %d → %d" % [gold, new_gold])

## Remove all modifiers from a specific source
func remove_modifiers_from_source(source_id: String):
	var removed_count = 0

	# Remove from starting gold
	var old_size = _starting_gold_modifiers.size()
	_starting_gold_modifiers = _starting_gold_modifiers.filter(func(m): return m.source_id != source_id)
	removed_count += old_size - _starting_gold_modifiers.size()

	# Remove from global tower costs
	old_size = _global_tower_cost_modifiers.size()
	_global_tower_cost_modifiers = _global_tower_cost_modifiers.filter(func(m): return m.source_id != source_id)
	removed_count += old_size - _global_tower_cost_modifiers.size()

	# Remove from specific tower costs
	for tower_id in _tower_cost_modifiers.keys():
		old_size = _tower_cost_modifiers[tower_id].size()
		_tower_cost_modifiers[tower_id] = _tower_cost_modifiers[tower_id].filter(func(m): return m.source_id != source_id)
		removed_count += old_size - _tower_cost_modifiers[tower_id].size()

		# Clean up empty arrays
		if _tower_cost_modifiers[tower_id].is_empty():
			_tower_cost_modifiers.erase(tower_id)

	# Hero stat modifiers removed - heroes manage their own stats now

	if removed_count > 0:
		modifiers_changed.emit()
		print("[GameStateManager] Removed %d modifiers from source: %s" % [removed_count, source_id])

## Calculate final starting gold with all modifiers
func get_calculated_starting_gold() -> int:
	return int(_calculate_final_value(_base_starting_gold, _starting_gold_modifiers))

# ============================================
# MODIFIER MANAGEMENT - TOWER COSTS
# ============================================

## Add a modifier for a specific tower type
func add_tower_cost_modifier(tower_id: String, modifier: StatModifier):
	if not _tower_cost_modifiers.has(tower_id):
		_tower_cost_modifiers[tower_id] = []

	_tower_cost_modifiers[tower_id].append(modifier)
	modifiers_changed.emit()
	print("[GameStateManager] Added tower cost modifier for %s: %s" % [tower_id, modifier.get_debug_string()])

## Add a global modifier that affects all tower costs
## Example: skill that reduces all tower costs by 15%
func add_global_tower_cost_modifier(modifier: StatModifier):
	_global_tower_cost_modifiers.append(modifier)
	modifiers_changed.emit()
	print("[GameStateManager] Added global tower cost modifier: %s" % modifier.get_debug_string())

## Calculate final tower cost with all modifiers
## Call this when displaying costs or checking if player can afford
func get_tower_cost(tower_id: String, base_cost: int) -> int:
	# Store base cost for future reference
	if not _base_tower_costs.has(tower_id):
		_base_tower_costs[tower_id] = base_cost

	# Get tower-specific modifiers
	var tower_modifiers = _tower_cost_modifiers.get(tower_id, [])

	# Combine with global modifiers
	var all_modifiers = tower_modifiers + _global_tower_cost_modifiers

	var final_cost = int(_calculate_final_value(base_cost, all_modifiers))

	# Debug log if cost is modified
	if final_cost != base_cost:
		print("[GameStateManager] Tower %s cost: %d → %d (saved %d)" % [tower_id, base_cost, final_cost, base_cost - final_cost])

	return final_cost

# ============================================
# HERO STAT MODIFIERS - REMOVED
# ============================================
# The hero stat modifier system has been removed from GameStateManager.
# Heroes now manage their own stats via:
#   - Stat objects (stat_ranged_damage, stat_max_health, etc.)
#   - EquipmentManager.get_all_stat_modifiers()
#   - SkillManager.get_passive_skill_modifiers()
# See ranger_hero.gd:_recalculate_all_stats() for the new implementation.

# ============================================
# CORE CALCULATION ENGINE
# ============================================

## Calculate final value from base value and modifiers
## Order: Flat → Additive → Multiplicative
func _calculate_final_value(base_value: float, modifiers: Array[StatModifier]) -> float:
	if modifiers.is_empty():
		return base_value

	# Sort modifiers by type (flat → additive → multiplicative)
	var sorted_mods = modifiers.duplicate()
	sorted_mods.sort_custom(func(a, b): return a.get_order() < b.get_order())

	var final_value = float(base_value)
	var additive_sum = 0.0

	for mod in sorted_mods:
		match mod.type:
			StatModifier.ModifierType.FLAT:
				# Direct addition/subtraction
				final_value += mod.value

			StatModifier.ModifierType.ADDITIVE:
				# Accumulate percentage bonuses (applied to base value)
				additive_sum += mod.value

			StatModifier.ModifierType.MULTIPLICATIVE:
				# Multiply current value
				final_value *= mod.value

	# Apply accumulated additive modifiers as percentage of original base
	if additive_sum != 0.0:
		final_value += base_value * additive_sum

	# Never return negative values (important for costs)
	return max(0.0, final_value)

# ============================================
# RESOURCE MANAGEMENT (Gold & Lives)
# ============================================

## Add gold (from killing enemies, selling towers, etc.)
func add_gold(amount: int):
	gold += amount
	gold_changed.emit(gold)
	print("[GameStateManager] Gold: %d (+%d)" % [gold, amount])

## Spend gold (returns true if successful)
func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		print("[GameStateManager] Gold: %d (-%d)" % [gold, amount])
		return true
	else:
		print("[GameStateManager] Not enough gold! Have: %d, Need: %d" % [gold, amount])
		return false

## Lose life/lives
func lose_life(amount: int = 1):
	lives -= amount
	lives_changed.emit(lives)
	print("[GameStateManager] Lives: %d (-%d)" % [lives, amount])

	if lives <= 0:
		game_over()

## Trigger game over
func game_over():
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[GameStateManager] 💀 GAME OVER!")
	print("[GameStateManager] Final state: %dg, %d lives" % [gold, lives])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# Pause the game (stops enemies, towers, timers)
	get_tree().paused = true

	# End balance tracking with defeat
	if BalanceTracker:
		BalanceTracker.end_run("defeat", 0)
		# Auto-save data on defeat
		if BalanceExporter:
			BalanceExporter.export_current_run()

	# Show defeat screen
	_show_defeat_screen()

func _show_defeat_screen():
	"""Show the defeat screen"""
	var defeat_screen_scene = preload("res://scenes/ui/defeat_screen.tscn")

	# Create canvas layer for defeat screen
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Modal game over screen
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused

	# Instantiate defeat screen
	var defeat_screen = defeat_screen_scene.instantiate()

	# Add to scene tree (canvas layer to root, screen to canvas layer)
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(defeat_screen)

	print("[GameStateManager] Defeat screen shown (on CanvasLayer)")

# ============================================
# DEBUG & INSPECTION
# ============================================

## Get debug info about all active modifiers
func get_debug_info() -> String:
	var info = "=== GAME STATE MANAGER DEBUG ===\n"
	info += "Current Level: %s\n" % (current_level_config.level_name if current_level_config else "NONE")
	info += "\n"

	info += "GOLD:\n"
	info += "  Base starting: %d\n" % _base_starting_gold
	info += "  Current: %d\n" % gold
	info += "  Starting gold modifiers: %d\n" % _starting_gold_modifiers.size()
	for mod in _starting_gold_modifiers:
		info += "    - %s\n" % mod.get_debug_string()
	info += "\n"

	info += "LIVES:\n"
	info += "  Base starting: %d\n" % _base_starting_lives
	info += "  Current: %d\n" % lives
	info += "\n"

	info += "TOWER COST MODIFIERS:\n"
	info += "  Global modifiers: %d\n" % _global_tower_cost_modifiers.size()
	for mod in _global_tower_cost_modifiers:
		info += "    - %s\n" % mod.get_debug_string()

	if not _tower_cost_modifiers.is_empty():
		info += "  Tower-specific modifiers:\n"
		for tower_id in _tower_cost_modifiers.keys():
			info += "    %s (%d modifiers)\n" % [tower_id, _tower_cost_modifiers[tower_id].size()]
	info += "\n"

	return info

## Print debug info to console
func print_debug_info():
	print(get_debug_info())

# ============================================
# STAR CALCULATION (centralized logic)
# ============================================

## Calculate star rating based on lives remaining
## Returns 1-3 stars based on percentage of lives left
func calculate_stars(lives_remaining: int, max_lives: int) -> int:
	"""
	Calculate star rating based on lives remaining.

	Star thresholds:
	  3 stars: 80%+ lives remaining (16/20 = 80%)
	  2 stars: 50-79% lives remaining (10-15/20)
	  1 star: Completed but less than 50% lives

	Args:
	  lives_remaining: Current lives count
	  max_lives: Maximum lives for the level

	Returns:
	  Star rating (1-3)
	"""
	if max_lives <= 0:
		push_warning("[GameStateManager] Cannot calculate stars: max_lives is 0")
		return 1

	var lives_percent = (float(lives_remaining) / float(max_lives)) * 100.0

	if lives_percent >= 80.0:  # 80%+ health = 3 stars
		return 3
	elif lives_percent >= 50.0:  # 50-79% health = 2 stars
		return 2
	else:  # Survived but barely = 1 star
		return 1

## Get current star rating during gameplay
## Uses current lives and base starting lives
func get_current_star_rating() -> int:
	"""
	Calculate star rating for current game state.
	Useful for showing "current stars" in UI during gameplay.

	Returns:
	  Star rating (1-3) based on current lives
	"""
	if _base_starting_lives <= 0:
		push_warning("[GameStateManager] Cannot calculate current stars: no level loaded")
		return 1

	return calculate_stars(lives, _base_starting_lives)

## Get maximum possible lives for current level
func get_max_lives() -> int:
	"""Get the starting lives count (max lives for star calculation)"""
	return _base_starting_lives
