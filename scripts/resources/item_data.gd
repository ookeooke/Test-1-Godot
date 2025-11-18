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
@export var item_level: int = 0  ## Item level (for display purposes)
@export var required_level: int = 0  ## Minimum character level to equip

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

# Random Stat Rolls (Diablo Style)
@export_group("Random Stats")
@export var has_random_stats: bool = false  ## Enable random stat ranges for this item
@export var damage_range: Vector2i = Vector2i(0, 0)  ## Min/Max damage (e.g., 6-10). Use fixed value if min==max
@export var health_range: Vector2i = Vector2i(0, 0)  ## Min/Max health bonus
@export var defense_range: Vector2i = Vector2i(0, 0)  ## Min/Max defense bonus
@export var crit_chance_range: Vector2 = Vector2(0.0, 0.0)  ## Min/Max crit chance (0.03-0.07 = 3%-7%)
@export var attack_speed_range: Vector2 = Vector2(0.0, 0.0)  ## Min/Max attack speed multiplier

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
## STAT MODIFIER GENERATION (New Unified System)
## ============================================

## Generate StatModifier objects from this item's stats
## This converts flat bonuses into the unified modifier system
## upgrade_level: Current upgrade level of the item (0 = base level)
## rolled_stats: Optional dictionary of rolled stat values (overrides base stats)
func get_stat_modifiers(upgrade_level: int = 0, rolled_stats: Dictionary = {}) -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	var source_id = "equipment:" + item_id  # Namespaced to prevent collision with skills

	# Only generate modifiers for equippable items
	if not is_equippable():
		return modifiers

	# Use rolled stats if available, otherwise use fixed stats
	var base_damage = rolled_stats.get("damage_bonus", damage_bonus)
	var base_health = rolled_stats.get("health_bonus", health_bonus)
	var base_defense = rolled_stats.get("defense_bonus", defense_bonus)
	var base_range = rolled_stats.get("range_bonus", range_bonus)
	var base_attack_speed = rolled_stats.get("attack_speed_multiplier", attack_speed_multiplier)
	var base_crit = rolled_stats.get("crit_chance_bonus", crit_chance_bonus)

	# Calculate upgraded stats if applicable
	var final_damage = base_damage
	var final_health = base_health
	var final_defense = base_defense
	var final_range = base_range

	if can_upgrade and upgrade_level > 0:
		final_damage = int(get_upgraded_stat(base_damage, upgrade_level))
		final_health = int(get_upgraded_stat(base_health, upgrade_level))
		final_defense = int(get_upgraded_stat(base_defense, upgrade_level))
		final_range = int(get_upgraded_stat(base_range, upgrade_level))

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

	# Attack Speed modifier (multiplicative) - use rolled or base
	if base_attack_speed != 1.0:
		var desc = "×%.2f Attack Speed" % base_attack_speed
		modifiers.append(StatModifier.create_multiplicative(base_attack_speed, source_id, desc))

	# Crit Chance modifier (additive percentage) - use rolled or base
	if base_crit > 0.0:
		var crit_percent = base_crit * 100.0
		var desc = "+%.1f%% Crit Chance" % crit_percent
		# Convert decimal to percentage for additive modifier
		modifiers.append(StatModifier.create_additive(crit_percent, source_id, desc))

	return modifiers


## ============================================
## STATIC HELPER FUNCTIONS
## ============================================

## Convert EquipSlot enum to equipment slot name string
## This is a shared helper to avoid duplicate logic across UI components
static func equip_slot_to_name(slot: EquipSlot) -> String:
	match slot:
		EquipSlot.WEAPON:
			return "hand_left"  # Weapons go to left hand by default
		EquipSlot.HELMET:
			return "helmet"
		EquipSlot.ARMOR:
			return "armor"
		EquipSlot.ACCESSORY:
			return "accessory_1"  # Default to first accessory slot
		EquipSlot.NONE:
			return ""
	return ""
