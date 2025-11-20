class_name ItemInstance
extends RefCounted

## ItemInstance
## Represents a specific existence of an item in the game world.
## Replaces the old Dictionary-based system for better type safety and logic encapsulation.

# Core Identity
var uuid: String = ""
var item_id: String = ""

# Mutable State
var upgrade_level: int = 0
var quantity: int = 1 # For stackable items (potions, materials)
var rolled_affixes: Dictionary = {} # { "prefix": {...}, "suffix": {...} }
var dynamic_properties: Dictionary = {} # Custom data (durability, enchantment, etc.)

# Cache
var _cached_item_data: ItemData = null

## Initialize a new instance
func _init(p_item_id: String, p_uuid: String = ""):
	item_id = p_item_id
	if p_uuid == "":
		uuid = UUIDGenerator.generate()
	else:
		uuid = p_uuid

## Get the static ItemData resource
func get_data() -> ItemData:
	if _cached_item_data == null:
		_cached_item_data = ItemDatabase.get_item(item_id)
	return _cached_item_data

## Serialize to Dictionary (for saving)
func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"uuid": uuid,
		"upgrade_level": upgrade_level,
		"quantity": quantity,
		"rolled_affixes": rolled_affixes,
		"dynamic_properties": dynamic_properties
	}

## Deserialize from Dictionary (for loading)
static func from_dict(data: Dictionary) -> ItemInstance:
	var instance = ItemInstance.new(data.get("item_id", ""), data.get("uuid", ""))
	instance.upgrade_level = data.get("upgrade_level", 0)
	instance.quantity = data.get("quantity", 1)
	instance.rolled_affixes = data.get("rolled_affixes", {})
	instance.dynamic_properties = data.get("dynamic_properties", {})
	return instance
