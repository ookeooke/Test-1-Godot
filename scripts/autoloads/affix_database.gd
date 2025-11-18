extends Node

## AffixDatabase - Autoload Singleton
## Manages all available affixes for magic/rare item generation
## Based on Diablo 2's prefix/suffix system

signal affixes_loaded

# Storage
var all_affixes: Array[AffixData] = []
var prefixes: Array[AffixData] = []
var suffixes: Array[AffixData] = []

# Organized by stat type for easier filtering
var prefixes_by_stat: Dictionary = {}  # {StatType: [AffixData]}
var suffixes_by_stat: Dictionary = {}  # {StatType: [AffixData]}

var is_loaded: bool = false


func _ready():
	print("[AffixDatabase] Loading affixes...")
	_load_affixes()


## Load all affix resources
func _load_affixes():
	# Preload affix resources
	var prefix_paths = [
		"res://resources/affixes/prefixes/bronze_prefix.tres",
		"res://resources/affixes/prefixes/iron_prefix.tres",
		"res://resources/affixes/prefixes/tough_prefix.tres"
	]

	var suffix_paths = [
		"res://resources/affixes/suffixes/of_strength_suffix.tres",
		"res://resources/affixes/suffixes/of_vitality_suffix.tres",
		"res://resources/affixes/suffixes/of_precision_suffix.tres"
	]

	# Load prefixes
	for path in prefix_paths:
		var affix = load(path) as AffixData
		if affix:
			all_affixes.append(affix)
			prefixes.append(affix)
			_add_to_stat_dict(affix, prefixes_by_stat)

	# Load suffixes
	for path in suffix_paths:
		var affix = load(path) as AffixData
		if affix:
			all_affixes.append(affix)
			suffixes.append(affix)
			_add_to_stat_dict(affix, suffixes_by_stat)

	is_loaded = true
	affixes_loaded.emit()

	print("[AffixDatabase] Loaded %d prefixes, %d suffixes" % [prefixes.size(), suffixes.size()])


## Add affix to stat-organized dictionary
func _add_to_stat_dict(affix: AffixData, dict: Dictionary):
	if not dict.has(affix.stat_type):
		dict[affix.stat_type] = []
	dict[affix.stat_type].append(affix)


## Get a random prefix (any stat type)
func get_random_prefix(item_level: int = 1) -> AffixData:
	var valid_affixes = prefixes.filter(func(a): return a.required_item_level <= item_level)

	if valid_affixes.is_empty():
		return null

	return valid_affixes[randi() % valid_affixes.size()]


## Get a random suffix (any stat type)
func get_random_suffix(item_level: int = 1) -> AffixData:
	var valid_affixes = suffixes.filter(func(a): return a.required_item_level <= item_level)

	if valid_affixes.is_empty():
		return null

	return valid_affixes[randi() % valid_affixes.size()]


## Get a random prefix for a specific stat type
func get_random_prefix_for_stat(stat_type: AffixData.StatType, item_level: int = 1) -> AffixData:
	if not prefixes_by_stat.has(stat_type):
		return null

	var valid_affixes = prefixes_by_stat[stat_type].filter(func(a): return a.required_item_level <= item_level)

	if valid_affixes.is_empty():
		return null

	return valid_affixes[randi() % valid_affixes.size()]


## Get a random suffix for a specific stat type
func get_random_suffix_for_stat(stat_type: AffixData.StatType, item_level: int = 1) -> AffixData:
	if not suffixes_by_stat.has(stat_type):
		return null

	var valid_affixes = suffixes_by_stat[stat_type].filter(func(a): return a.required_item_level <= item_level)

	if valid_affixes.is_empty():
		return null

	return valid_affixes[randi() % valid_affixes.size()]


## Get all affixes (for debugging/inspection)
func get_all_affixes() -> Array[AffixData]:
	return all_affixes.duplicate()


## Check if an affix exists
func has_affix(affix_id: String) -> bool:
	return all_affixes.any(func(a): return a.affix_id == affix_id)


## Get affix by ID
func get_affix(affix_id: String) -> AffixData:
	for affix in all_affixes:
		if affix.affix_id == affix_id:
			return affix
	return null
