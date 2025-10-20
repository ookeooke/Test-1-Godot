extends Resource
class_name StatModifier

## ============================================
## STAT MODIFIER - Represents a single stat modification
## ============================================
##
## Used to modify base values from equipment, skills, difficulty, etc.
## Supports three types: Flat, Additive, Multiplicative
##
## Example:
##   Base gold: 100
##   Flat modifier: +20 → 120
##   Additive modifier: +15% → 120 + (100 × 0.15) = 135
##   Multiplicative modifier: ×1.1 → 135 × 1.1 = 148.5

# ============================================
# MODIFIER TYPES (with order values for sorting)
# ============================================

enum ModifierType {
	FLAT = 100,          ## Direct addition/subtraction (applied first)
	ADDITIVE = 200,      ## Percentage of base value (applied second)
	MULTIPLICATIVE = 300 ## Final multiplier (applied last)
}

# ============================================
# PROPERTIES
# ============================================

## The numerical value of the modifier
## - FLAT: Direct amount (e.g., +20 gold, -50 tower cost)
## - ADDITIVE: Percentage as decimal (e.g., 0.15 = +15%)
## - MULTIPLICATIVE: Multiplier (e.g., 1.1 = ×1.1, 0.9 = ×0.9)
@export var value: float = 0.0

## Type of modifier (determines calculation order)
@export var type: ModifierType = ModifierType.FLAT

## Source identifier for tracking and removal
## Format: "equipment_sword_001" or "skill_ranger_multishot"
## Used to remove all modifiers when item unequipped or skill removed
@export var source_id: String = ""

## Optional: Human-readable description for debugging
@export var description: String = ""

# ============================================
# HELPER METHODS
# ============================================

## Get the order value for sorting (lower = earlier in calculation)
func get_order() -> int:
	return int(type)

## Create a flat modifier
static func create_flat(amount: float, source: String, desc: String = "") -> StatModifier:
	var mod = StatModifier.new()
	mod.value = amount
	mod.type = ModifierType.FLAT
	mod.source_id = source
	mod.description = desc if desc != "" else "Flat %+.1f" % amount
	return mod

## Create an additive modifier (percentage of base)
static func create_additive(percent: float, source: String, desc: String = "") -> StatModifier:
	var mod = StatModifier.new()
	mod.value = percent / 100.0  # Convert percentage to decimal
	mod.type = ModifierType.ADDITIVE
	mod.source_id = source
	mod.description = desc if desc != "" else "%+.1f%%" % percent
	return mod

## Create a multiplicative modifier
static func create_multiplicative(multiplier: float, source: String, desc: String = "") -> StatModifier:
	var mod = StatModifier.new()
	mod.value = multiplier
	mod.type = ModifierType.MULTIPLICATIVE
	mod.source_id = source
	mod.description = desc if desc != "" else "×%.2f" % multiplier
	return mod

## Get debug string representation
func get_debug_string() -> String:
	var type_str = ""
	match type:
		ModifierType.FLAT:
			type_str = "FLAT"
		ModifierType.ADDITIVE:
			type_str = "ADD"
		ModifierType.MULTIPLICATIVE:
			type_str = "MULT"

	return "[%s] %s (from: %s)" % [type_str, description, source_id]
