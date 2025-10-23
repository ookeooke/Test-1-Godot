extends Resource
class_name Stat

## ============================================
## STAT - Unified stat with modifier management
## ============================================
##
## Represents a single stat (damage, health, range, etc.) with support for:
## - Base value (from hero/item definition)
## - Multiple modifiers (equipment, skills, buffs, debuffs)
## - Lazy evaluation with dirty flag pattern
## - Automatic caching for performance
##
## Example:
##   var damage_stat = Stat.new(10.0)  # Base damage: 10
##   damage_stat.add_modifier(StatModifier.create_flat(15, "fire_bow"))  # +15
##   damage_stat.add_modifier(StatModifier.create_multiplicative(1.5, "power_shot"))  # ×1.5
##   print(damage_stat.get_value())  # Returns: 37.5

# ============================================
# PROPERTIES
# ============================================

## Base value before any modifiers
@export var base_value: float = 0.0

## All active modifiers affecting this stat
var _modifiers: Array[StatModifier] = []

## Cached final value (only recalculated when dirty)
var _cached_value: float = 0.0

## Whether the cached value needs recalculation
var _is_dirty: bool = true

# ============================================
# SIGNALS
# ============================================

## Emitted when the stat value changes (after recalculation)
signal value_changed(new_value: float)

# ============================================
# INITIALIZATION
# ============================================

func _init(initial_value: float = 0.0):
	base_value = initial_value
	_cached_value = initial_value
	_is_dirty = false

# ============================================
# PUBLIC API
# ============================================

## Get the final calculated value (with lazy evaluation)
func get_value() -> float:
	if _is_dirty:
		_recalculate()
	return _cached_value

## Add a modifier to this stat
func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		push_error("[Stat] Cannot add null modifier")
		return

	_modifiers.append(modifier)
	_mark_dirty()

	print("[Stat] Added modifier: %s (total modifiers: %d)" % [modifier.get_debug_string(), _modifiers.size()])

## Remove a specific modifier
func remove_modifier(modifier: StatModifier) -> bool:
	var index = _modifiers.find(modifier)
	if index >= 0:
		_modifiers.remove_at(index)
		_mark_dirty()
		print("[Stat] Removed modifier: %s" % modifier.get_debug_string())
		return true
	return false

## Remove all modifiers from a specific source
## Example: remove_modifiers_from_source("fire_bow") when unequipping item
func remove_modifiers_from_source(source_id: String) -> int:
	var old_size = _modifiers.size()
	_modifiers = _modifiers.filter(func(m): return m.source_id != source_id)
	var removed_count = old_size - _modifiers.size()

	if removed_count > 0:
		_mark_dirty()
		print("[Stat] Removed %d modifiers from source: %s" % [removed_count, source_id])

	return removed_count

## Get all active modifiers
func get_modifiers() -> Array[StatModifier]:
	return _modifiers.duplicate()

## Get count of active modifiers
func get_modifier_count() -> int:
	return _modifiers.size()

## Check if this stat has any modifiers
func has_modifiers() -> bool:
	return not _modifiers.is_empty()

## Clear all modifiers (reset to base value)
func clear_modifiers() -> void:
	if not _modifiers.is_empty():
		_modifiers.clear()
		_mark_dirty()
		print("[Stat] Cleared all modifiers")

## Force recalculation (normally not needed, automatic via dirty flag)
func force_recalculate() -> void:
	_recalculate()

# ============================================
# INTERNAL METHODS
# ============================================

## Mark the cached value as dirty (needs recalculation)
func _mark_dirty() -> void:
	_is_dirty = true

## Recalculate the final value from base + modifiers
func _recalculate() -> void:
	# Use GameStateManager's calculation engine
	if _modifiers.is_empty():
		_cached_value = base_value
	else:
		_cached_value = GameStateManager._calculate_final_value(base_value, _modifiers)

	_is_dirty = false
	value_changed.emit(_cached_value)

	# Debug logging (can be disabled in production)
	if DebugConfig and DebugConfig.log_stat_calculations:
		print("[Stat] Recalculated: base %.1f → final %.1f (%d modifiers)" % [base_value, _cached_value, _modifiers.size()])

# ============================================
# DEBUG & INSPECTION
# ============================================

## Get debug string showing all modifiers
func get_debug_string() -> String:
	var result = "Base: %.1f" % base_value

	if _modifiers.is_empty():
		result += " (no modifiers)"
	else:
		result += "\nModifiers:"
		for mod in _modifiers:
			result += "\n  - " + mod.get_debug_string()

	result += "\nFinal: %.1f" % get_value()
	return result

## Print debug info to console
func print_debug() -> void:
	print("[Stat Debug]\n" + get_debug_string())
