class_name ItemData
extends Resource

## ItemData defines the blueprint for all items in the game
## This is the definition data (read-only), not the player's owned instances

enum ItemType {
	WEAPON,
	ARMOR,
	ACCESSORY,
	CONSUMABLE,
	MATERIAL,
	CURRENCY
}

enum Rarity {
	NORMAL, # White - Base stats only, no magical properties
	MAGIC, # Blue - 1-2 random affixes (prefix/suffix)
	RARE, # Yellow - 3-6 random affixes
	SET, # Green - Fixed set bonuses (future implementation)
	UNIQUE # Gold/Orange - Fixed unique properties
}

enum EquipSlot {
	NONE,
	WEAPON,
	ARMOR,
	ACCESSORY,
	HELMET
}

# Core Identification
@export var item_id: String = ""
@export var item_name: String = "" ## Display name (for unique items) OR base name (for normal/magic/rare items)
@export var base_item_name: String = "" ## Base item name without affixes (e.g., "Sword", "Ring"). If empty, uses item_name
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.WEAPON
@export var rarity: Rarity = Rarity.NORMAL
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var item_level: int = 0 ## Item level (for display purposes)
@export var required_level: int = 0 ## Minimum character level to equip
@export var can_have_affixes: bool = true ## If false, item uses fixed stats (for unique items)

# Stacking & Economy
@export var max_stack: int = 1 ## 1 for equipment, 99 for consumables/materials
@export var sell_value: int = 10
@export var is_starter_equipment: bool = false ## Cannot be unequipped to empty slot (auto-equipped on hero recruitment)
@export var is_account_bound: bool = false ## Cannot be sold or traded

# Equipment Stats (only used for WEAPON/ARMOR/ACCESSORY types)
@export_group("Equipment Stats")
@export var weapon_type: String = "" ## "bow", "crossbow", "sword", "axe", "mace", "staff", "wand", "shield", etc.
@export var armor_type: String = "" ## "leather", "cloth", "plate", "mail", "helmet", etc.
@export var is_two_handed: bool = false ## True for bows, greatswords, staffs (occupies both hand slots)
@export var hand_slot: String = "either" ## "left", "right", "both" (2H weapons), or "either" (can go in any hand)
@export var damage_bonus: int = 0
@export var attack_speed_multiplier: float = 1.0
@export var health_bonus: int = 0
@export var defense_bonus: int = 0
@export var range_bonus: int = 0
@export var crit_chance_bonus: float = 0.0 ## 0.0 to 1.0 (0% to 100%)

# Random Stat Rolls (Diablo Style)
@export_group("Random Stats")
@export var has_random_stats: bool = false ## Enable random stat ranges for this item
@export var damage_range: Vector2i = Vector2i(0, 0) ## Min/Max damage (e.g., 6-10). Use fixed value if min==max
@export var health_range: Vector2i = Vector2i(0, 0) ## Min/Max health bonus
@export var defense_range: Vector2i = Vector2i(0, 0) ## Min/Max defense bonus
@export var crit_chance_range: Vector2 = Vector2(0.0, 0.0) ## Min/Max crit chance (0.03-0.07 = 3%-7%)
@export var attack_speed_range: Vector2 = Vector2(0.0, 0.0) ## Min/Max attack speed multiplier

# Special Effects (string identifiers for special behaviors)
@export_group("Special Effects")
@export var special_effects: Array[String] = [] ## e.g. ["lifesteal_10", "splash_damage", "fire_dot_5"]

# Inventory Display (Multi-Slot Support - Diablo 2 Style)
@export_group("Inventory Display")
@export_range(1, 3) var inventory_width: int = 1 ## Width in inventory grid slots (1-3)
@export_range(1, 3) var inventory_height: int = 1 ## Height in inventory grid slots (1-3)

# Upgrade System
@export_group("Upgrade System")
@export var can_upgrade: bool = true
@export var max_upgrade_level: int = 10
@export var upgrade_costs: Array[int] = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600]
@export var stat_increase_per_level: float = 0.1 ## 10% increase per level

# Visual & Audio
@export_group("Presentation")
@export var flavor_text: String = "" ## Lore/story text
@export var pickup_sound: AudioStream
@export var use_sound: AudioStream


## Get the color associated with this item's rarity (Diablo 2 style)
func get_rarity_color() -> Color:
	match rarity:
		Rarity.NORMAL:
			return Color.WHITE
		Rarity.MAGIC:
			return Color.DODGER_BLUE # Blue for magic items
		Rarity.RARE:
			return Color.YELLOW # Yellow for rare items
		Rarity.SET:
			return Color.GREEN # Green for set items
		Rarity.UNIQUE:
			return Color.ORANGE # Orange/Gold for uniques
	return Color.WHITE


## Get the rarity name as a string (Diablo 2 style)
func get_rarity_name() -> String:
	match rarity:
		Rarity.NORMAL:
			return "Normal"
		Rarity.MAGIC:
			return "Magic"
		Rarity.RARE:
			return "Rare"
		Rarity.SET:
			return "Set"
		Rarity.UNIQUE:
			return "Unique"
	return "Unknown"


## Get the item type name as a string
func get_item_type_name() -> String:
	match item_type:
		ItemType.WEAPON:
			return "Weapon"
		ItemType.ARMOR:
			return "Armor"
		ItemType.CURRENCY:
			return "Currency"
	return "Unknown"


## Calculate the stat bonus at a given upgrade level
func get_upgraded_stat(base_stat: float, upgrade_level: int) -> float:
	if !can_upgrade or upgrade_level <= 0:
		return base_stat

	var total_multiplier = 1.0 + (stat_increase_per_level * upgrade_level)
	return base_stat * total_multiplier


## Get the cost to upgrade from current level to next level
func get_upgrade_cost(current_level: int) -> int:
	if current_level >= max_upgrade_level or current_level >= upgrade_costs.size():
		return -1 # Cannot upgrade further

	return upgrade_costs[current_level]


## Check if this item can be equipped
func is_equippable() -> bool:
	return equip_slot != EquipSlot.NONE


## Check if this item is stackable
func is_stackable() -> bool:
	return max_stack > 1


## Roll random stats for this item (if has_random_stats is enabled)
## Returns a dictionary with rolled stat values
## Example: {"damage_bonus": 7, "crit_chance_bonus": 0.05}
func roll_stats() -> Dictionary:
	var rolled = {}

	if not has_random_stats:
		# Use fixed stats
		rolled["damage_bonus"] = damage_bonus
		rolled["health_bonus"] = health_bonus
		rolled["defense_bonus"] = defense_bonus
		rolled["crit_chance_bonus"] = crit_chance_bonus
		rolled["attack_speed_multiplier"] = attack_speed_multiplier
		return rolled

	# Roll damage if range is set
	if damage_range.x > 0 or damage_range.y > 0:
		rolled["damage_bonus"] = randi_range(damage_range.x, damage_range.y)
	else:
		rolled["damage_bonus"] = damage_bonus

	# Roll health if range is set
	if health_range.x > 0 or health_range.y > 0:
		rolled["health_bonus"] = randi_range(health_range.x, health_range.y)
	else:
		rolled["health_bonus"] = health_bonus

	# Roll defense if range is set
	if defense_range.x > 0 or defense_range.y > 0:
		rolled["defense_bonus"] = randi_range(defense_range.x, defense_range.y)
	else:
		rolled["defense_bonus"] = defense_bonus

	# Roll crit chance if range is set
	if crit_chance_range.x > 0.0 or crit_chance_range.y > 0.0:
		rolled["crit_chance_bonus"] = randf_range(crit_chance_range.x, crit_chance_range.y)
	else:
		rolled["crit_chance_bonus"] = crit_chance_bonus

	# Roll attack speed if range is set
	if attack_speed_range.x > 0.0 or attack_speed_range.y > 0.0:
		rolled["attack_speed_multiplier"] = randf_range(attack_speed_range.x, attack_speed_range.y)
	else:
		rolled["attack_speed_multiplier"] = attack_speed_multiplier

	return rolled


## ============================================
## AFFIX SYSTEM (Diablo 2 Style)
## ============================================

## Roll affixes based on item rarity (Diablo 2 style)
## Returns a dictionary with rolled affixes and their values
## Structure: {
##   "affixes": [{"affix": AffixData, "rolled_value": float}, ...],
##   "prefix": AffixData or null,
##   "suffix": AffixData or null
## }
func roll_affixes() -> Dictionary:
	var result = {
		"affixes": [],
		"prefix": null,
		"suffix": null
	}

	# NORMAL items have no affixes (base stats only)
	if rarity == Rarity.NORMAL:
		return result

	# UNIQUE and SET items use fixed stats (no random affixes)
	if rarity == Rarity.UNIQUE or rarity == Rarity.SET:
		return result

	# Items that can't have affixes use fixed stats
	if not can_have_affixes:
		return result

	# MAGIC items: 1-2 affixes (Diablo 2 distribution)
	if rarity == Rarity.MAGIC:
		var roll = randf()
		if roll < 0.5:
			# 50% chance: Suffix only
			result.suffix = AffixDatabase.get_random_suffix(item_level)
			if result.suffix:
				var rolled_value = result.suffix.roll_value()
				result.affixes.append({"affix": result.suffix, "rolled_value": rolled_value})
		elif roll < 0.75:
			# 25% chance: Prefix only
			result.prefix = AffixDatabase.get_random_prefix(item_level)
			if result.prefix:
				var rolled_value = result.prefix.roll_value()
				result.affixes.append({"affix": result.prefix, "rolled_value": rolled_value})
		else:
			# 25% chance: Both prefix and suffix
			result.prefix = AffixDatabase.get_random_prefix(item_level)
			result.suffix = AffixDatabase.get_random_suffix(item_level)
			if result.prefix:
				var rolled_value = result.prefix.roll_value()
				result.affixes.append({"affix": result.prefix, "rolled_value": rolled_value})
			if result.suffix:
				var rolled_value = result.suffix.roll_value()
				result.affixes.append({"affix": result.suffix, "rolled_value": rolled_value})

	# RARE items: 3-6 affixes (simplified: 2-3 prefixes + 1-3 suffixes)
	elif rarity == Rarity.RARE:
		var prefix_count = randi_range(2, 3)
		var suffix_count = randi_range(1, 3)

		# Roll prefixes (avoid duplicates from same family)
		var used_families = []
		for i in prefix_count:
			var prefix = AffixDatabase.get_random_prefix(item_level)
			if prefix and prefix.affix_family not in used_families:
				used_families.append(prefix.affix_family)
				var rolled_value = prefix.roll_value()
				result.affixes.append({"affix": prefix, "rolled_value": rolled_value})
				if i == 0:
					result.prefix = prefix # Store first prefix for naming

		# Roll suffixes (avoid duplicates from same family)
		used_families.clear()
		for i in suffix_count:
			var suffix = AffixDatabase.get_random_suffix(item_level)
			if suffix and suffix.affix_family not in used_families:
				used_families.append(suffix.affix_family)
				var rolled_value = suffix.roll_value()
				result.affixes.append({"affix": suffix, "rolled_value": rolled_value})
				if i == 0:
					result.suffix = suffix # Store first suffix for naming

	return result


## ============================================
## DYNAMIC ITEM NAMING (Diablo 2 Style)
## ============================================

## Generate display name based on rarity and affixes
## rolled_affixes: Dictionary from roll_affixes() function
func get_display_name(rolled_affixes: Dictionary = {}) -> String:
	# Use base_item_name if set, otherwise item_name
	var base_name = base_item_name if base_item_name != "" else item_name

	# Normal items: Just the base name (white)
	if rarity == Rarity.NORMAL or rolled_affixes.is_empty():
		return base_name

	# Magic items: Prefix + Base + Suffix (blue)
	if rarity == Rarity.MAGIC:
		var prefix_name = ""
		var suffix_name = ""

		# Extract prefix and suffix from rolled_affixes
		if rolled_affixes.has("prefix"):
			var prefix_info = rolled_affixes.prefix
			if prefix_info.has("affix_data"):
				prefix_name = prefix_info.affix_data.affix_name

		if rolled_affixes.has("suffix"):
			var suffix_info = rolled_affixes.suffix
			if suffix_info.has("affix_data"):
				suffix_name = suffix_info.affix_data.affix_name

		# Construct name: "Prefix Base of Suffix"
		var display = ""
		if prefix_name != "":
			display += prefix_name + " "
		display += base_name
		if suffix_name != "":
			display += " " + suffix_name

		return display

	# Rare items: Use random rare name + base type
	if rarity == Rarity.RARE:
		# For now, just show base name (Phase 6 will add rare name generation)
		return base_name

	# Set/Unique: Use fixed item_name
	return item_name


## ============================================
## STAT MODIFIER GENERATION (New Unified System)
## ============================================

## Generate StatModifier objects from this item's stats + affixes (Diablo 2 style)
## This converts flat bonuses and affixes into the unified modifier system
## upgrade_level: Current upgrade level of the item (0 = base level)
## rolled_affixes: Dictionary of rolled affixes from roll_affixes() function
func get_stat_modifiers(upgrade_level: int = 0, rolled_affixes: Dictionary = {}) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	var source_id = "equipment:" + item_id # Namespaced to prevent collision with skills

	# Only generate modifiers for equippable items
	if not is_equippable():
		return modifiers

	# Start with base item stats (with upgrade scaling)
	var final_damage = damage_bonus
	var final_health = health_bonus
	var final_defense = defense_bonus
	var final_range = range_bonus

	if can_upgrade and upgrade_level > 0:
		final_damage = int(get_upgraded_stat(damage_bonus, upgrade_level))
		final_health = int(get_upgraded_stat(health_bonus, upgrade_level))
		final_defense = int(get_upgraded_stat(defense_bonus, upgrade_level))
		final_range = int(get_upgraded_stat(range_bonus, upgrade_level))

	# Base item stat modifiers
	if final_damage > 0:
		var desc = "+%d Damage" % final_damage
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_damage, source_id, desc))

	if final_health > 0:
		var desc = "+%d Health" % final_health
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_health, source_id, desc))

	if final_defense > 0:
		var desc = "+%d Defense" % final_defense
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_defense, source_id, desc))

	if final_range > 0:
		var desc = "+%d Range" % final_range
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_range, source_id, desc))

	if attack_speed_multiplier != 1.0:
		var desc = "×%.2f Attack Speed" % attack_speed_multiplier
		modifiers.append(StatModifier.create_multiplicative(attack_speed_multiplier, source_id, desc))

	if crit_chance_bonus > 0.0:
		var crit_percent = crit_chance_bonus * 100.0
		var desc = "+%.1f%% Crit Chance" % crit_percent
		modifiers.append(StatModifier.create_additive(crit_percent, source_id, desc))

	# Add affix modifiers (Diablo 2 style - affixes add bonus stats)
	if not rolled_affixes.is_empty():
		for affix_key in rolled_affixes.keys():
			var affix_info = rolled_affixes[affix_key]

			# affix_info structure: {affix_data: AffixData, rolled_value: float}
			if affix_info.has("affix_data") and affix_info.has("rolled_value"):
				var affix_data: AffixData = affix_info.affix_data
				var rolled_value: float = affix_info.rolled_value

				# Convert affix to stat modifier
				var affix_modifier = affix_data.to_stat_modifier(rolled_value, source_id + ":affix")
				if affix_modifier:
					modifiers.append(affix_modifier)

	return modifiers


## ============================================
## STATIC HELPER FUNCTIONS
## ============================================

## Convert EquipSlot enum to equipment slot name string
## This is a shared helper to avoid duplicate logic across UI components
static func equip_slot_to_name(slot: EquipSlot) -> String:
	match slot:
		EquipSlot.WEAPON:
			return "hand_left" # Weapons go to left hand by default
		EquipSlot.HELMET:
			return "helmet"
		EquipSlot.ARMOR:
			return "armor"
		EquipSlot.ACCESSORY:
			return "accessory_1" # Default to first accessory slot
		EquipSlot.NONE:
			return ""
	return ""
