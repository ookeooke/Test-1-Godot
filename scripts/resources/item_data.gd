class_name ItemData
extends Resource

## ItemData defines the blueprint for all items in the game
## This is the definition data (read-only), not the player's owned instances

enum ItemType {
	WEAPON,
	ARMOR,
	CURRENCY
}

enum Rarity {
	COMMON,      # White/Grey - 70% drop rate
	UNCOMMON,    # Green - 25% drop rate
	RARE,        # Blue - 10% drop rate
	EPIC,        # Purple - 4% drop rate
	LEGENDARY    # Orange/Gold - 1% drop rate
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
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var emoji: String = ""  ## Unicode emoji symbol (e.g., "🏹", "🛡️", "💍") - shown if no icon texture
@export var item_type: ItemType = ItemType.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var equip_slot: EquipSlot = EquipSlot.NONE

# Stacking & Economy
@export var max_stack: int = 1  ## 1 for equipment, 99 for consumables/materials
@export var sell_value: int = 10
@export var is_starter_equipment: bool = false  ## Cannot be unequipped to empty slot (auto-equipped on hero recruitment)
@export var is_account_bound: bool = false  ## Cannot be sold or traded

# Equipment Stats (only used for WEAPON/ARMOR/ACCESSORY types)
@export_group("Equipment Stats")
@export var weapon_type: String = ""  ## "bow", "crossbow", "sword", "axe", "mace", "staff", "wand", "shield", etc.
@export var armor_type: String = ""  ## "leather", "cloth", "plate", "mail", "helmet", etc.
@export var is_two_handed: bool = false  ## True for bows, greatswords, staffs (occupies both hand slots)
@export var hand_slot: String = "either"  ## "left", "right", "both" (2H weapons), or "either" (can go in any hand)
@export var damage_bonus: int = 0
@export var attack_speed_multiplier: float = 1.0
@export var health_bonus: int = 0
@export var defense_bonus: int = 0
@export var range_bonus: int = 0
@export var crit_chance_bonus: float = 0.0  ## 0.0 to 1.0 (0% to 100%)

# Special Effects (string identifiers for special behaviors)
@export_group("Special Effects")
@export var special_effects: Array[String] = []  ## e.g. ["lifesteal_10", "splash_damage", "fire_dot_5"]

# Inventory Display (Multi-Slot Support - Diablo 2 Style)
@export_group("Inventory Display")
@export_range(1, 3) var inventory_width: int = 1  ## Width in inventory grid slots (1-3)
@export_range(1, 3) var inventory_height: int = 1  ## Height in inventory grid slots (1-3)

# Upgrade System
@export_group("Upgrade System")
@export var can_upgrade: bool = true
@export var max_upgrade_level: int = 10
@export var upgrade_costs: Array[int] = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600]
@export var stat_increase_per_level: float = 0.1  ## 10% increase per level

# Visual & Audio
@export_group("Presentation")
@export var flavor_text: String = ""  ## Lore/story text
@export var pickup_sound: AudioStream
@export var use_sound: AudioStream


## Get the color associated with this item's rarity
func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color.WHITE
		Rarity.UNCOMMON:
			return Color.GREEN
		Rarity.RARE:
			return Color.DODGER_BLUE
		Rarity.EPIC:
			return Color.PURPLE
		Rarity.LEGENDARY:
			return Color.ORANGE
	return Color.WHITE


## Get the rarity name as a string
func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
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
		return -1  # Cannot upgrade further

	return upgrade_costs[current_level]


## Check if this item can be equipped
func is_equippable() -> bool:
	return equip_slot != EquipSlot.NONE


## Check if this item is stackable
func is_stackable() -> bool:
	return max_stack > 1


## ============================================
## STAT MODIFIER GENERATION (New Unified System)
## ============================================

## Generate StatModifier objects from this item's stats
## This converts flat bonuses into the unified modifier system
## upgrade_level: Current upgrade level of the item (0 = base level)
func get_stat_modifiers(upgrade_level: int = 0) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	var source_id = "equipment:" + item_id  # Namespaced to prevent collision with skills

	# Only generate modifiers for equippable items
	if not is_equippable():
		return modifiers

	# Calculate upgraded stats if applicable
	var final_damage = damage_bonus
	var final_health = health_bonus
	var final_defense = defense_bonus
	var final_range = range_bonus

	if can_upgrade and upgrade_level > 0:
		final_damage = int(get_upgraded_stat(damage_bonus, upgrade_level))
		final_health = int(get_upgraded_stat(health_bonus, upgrade_level))
		final_defense = int(get_upgraded_stat(defense_bonus, upgrade_level))
		final_range = int(get_upgraded_stat(range_bonus, upgrade_level))

	# Damage modifier (flat bonus)
	if final_damage > 0:
		var desc = "+%d Damage" % final_damage
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_damage, source_id, desc))

	# Health modifier (flat bonus)
	if final_health > 0:
		var desc = "+%d Health" % final_health
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_health, source_id, desc))

	# Defense modifier (flat bonus)
	if final_defense > 0:
		var desc = "+%d Defense" % final_defense
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_defense, source_id, desc))

	# Range modifier (flat bonus)
	if final_range > 0:
		var desc = "+%d Range" % final_range
		if upgrade_level > 0:
			desc += " (+%d)" % upgrade_level
		modifiers.append(StatModifier.create_flat(final_range, source_id, desc))

	# Attack Speed modifier (multiplicative)
	if attack_speed_multiplier != 1.0:
		var desc = "×%.2f Attack Speed" % attack_speed_multiplier
		modifiers.append(StatModifier.create_multiplicative(attack_speed_multiplier, source_id, desc))

	# Crit Chance modifier (additive percentage)
	if crit_chance_bonus > 0.0:
		var crit_percent = crit_chance_bonus * 100.0
		var desc = "+%.1f%% Crit Chance" % crit_percent
		# Convert decimal to percentage for additive modifier
		modifiers.append(StatModifier.create_additive(crit_percent, source_id, desc))

	return modifiers
