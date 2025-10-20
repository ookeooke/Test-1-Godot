class_name ItemData
extends Resource

## ItemData defines the blueprint for all items in the game
## This is the definition data (read-only), not the player's owned instances

enum ItemType {
	WEAPON,
	ARMOR,
	CONSUMABLE,
	MATERIAL,
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
	ACCESSORY
}

# Core Identification
@export var item_id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.MATERIAL
@export var rarity: Rarity = Rarity.COMMON
@export var equip_slot: EquipSlot = EquipSlot.NONE

# Stacking & Economy
@export var max_stack: int = 1  ## 1 for equipment, 99 for consumables/materials
@export var sell_value: int = 10

# Equipment Stats (only used for WEAPON/ARMOR/ACCESSORY types)
@export_group("Equipment Stats")
@export var damage_bonus: int = 0
@export var attack_speed_multiplier: float = 1.0
@export var health_bonus: int = 0
@export var defense_bonus: int = 0
@export var range_bonus: int = 0
@export var crit_chance_bonus: float = 0.0  ## 0.0 to 1.0 (0% to 100%)

# Special Effects (string identifiers for special behaviors)
@export_group("Special Effects")
@export var special_effects: Array[String] = []  ## e.g. ["lifesteal_10", "splash_damage", "fire_dot_5"]

# Consumable Properties (only used for CONSUMABLE type)
@export_group("Consumable Properties")
@export var heal_amount: int = 0
@export var buff_duration: float = 0.0
@export var buff_type: String = ""  ## e.g. "damage_boost", "speed_boost"

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
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.MATERIAL:
			return "Material"
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
