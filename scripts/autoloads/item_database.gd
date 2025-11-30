extends Node

## ItemDatabase - Autoload Singleton
## Loads and manages all ItemData resources from the game
## Provides fast lookup by item_id

signal items_loaded

var items: Dictionary = {} ## {item_id: ItemData}
var items_by_type: Dictionary = {} ## {ItemType: Array[ItemData]}
var items_by_rarity: Dictionary = {} ## {Rarity: Array[ItemData]}

const ITEMS_PATH = "res://resources/items/"


func _ready():
	load_all_items()


## Load all ItemData resources from the items directory
func load_all_items():
	items.clear()
	items_by_type.clear()
	items_by_rarity.clear()

	# Initialize type and rarity dictionaries
	for item_type in ItemData.ItemType.values():
		var type_array: Array[ItemData] = []
		items_by_type[item_type] = type_array

	for rarity in ItemData.Rarity.values():
		var rarity_array: Array[ItemData] = []
		items_by_rarity[rarity] = rarity_array

	# Load all items from subdirectories
	_load_items_from_directory(ITEMS_PATH)

	print("[ItemDatabase] Loaded %d items" % items.size())
	items_loaded.emit()


## Recursively load items from a directory
func _load_items_from_directory(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		print("[ItemDatabase] Warning: Could not open directory: ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + file_name

		if dir.current_is_dir():
			# Recursively load from subdirectories
			if file_name != "." and file_name != "..":
				_load_items_from_directory(full_path + "/")
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			# Load the resource
			var item_data = load(full_path) as ItemData
			if item_data != null:
				_register_item(item_data)
			else:
				print("[ItemDatabase] Warning: Failed to load item from: ", full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

	# FALLBACK: If directory scan found nothing (common in Export), try hardcoded load
	if items.is_empty():
		print("[ItemDatabase] Warning: Directory scan failed. Attempting hardcoded fallback...")
		var known_items = [
			# Weapons
			"weapons/basic_sword", "weapons/basic_bow", "weapons/basic_staff",
			"weapons/fire_bow", "weapons/elven_longbow",
			# Armor
			"armor/leather_vest", "helmets/leather_cap",
			# Accessories
			"accessories/power_ring",
			# Consumables
			"potions/health_potion", "potions/damage_buff_potion",
			# Materials
			"materials/dragon_scale", "materials/iron_ore", "materials/magic_essence"
		]
		
		for path_suffix in known_items:
			var fallback_path = ITEMS_PATH + path_suffix + ".tres"
			var item_data = load(fallback_path) as ItemData
			if item_data:
				print("[ItemDatabase] Fallback loaded: ", item_data.item_id)
				_register_item(item_data)
			else:
				print("[ItemDatabase] Fallback failed for: ", fallback_path)


## Register an item in the database
func _register_item(item_data: ItemData):
	if item_data.item_id == "":
		print("[ItemDatabase] Error: Item has empty item_id: ", item_data.item_name)
		return

	if items.has(item_data.item_id):
		print("[ItemDatabase] Warning: Duplicate item_id: ", item_data.item_id)
		return

	items[item_data.item_id] = item_data
	items_by_type[item_data.item_type].append(item_data)
	items_by_rarity[item_data.rarity].append(item_data)


## Get an item by its ID
func get_item(item_id: String) -> ItemData:
	if items.has(item_id):
		return items[item_id]

	# Don't warn about placeholder items (e.g., __2H_OCCUPIED__basic_bow)
	if item_id.begins_with("__") and item_id.contains("OCCUPIED"):
		return null

	print("[ItemDatabase] Warning: Item not found: ", item_id)
	return null


## Get all items of a specific type
func get_items_by_type(item_type: ItemData.ItemType) -> Array[ItemData]:
	if items_by_type.has(item_type):
		return items_by_type[item_type]
	var empty: Array[ItemData] = []
	return empty


## Get all items of a specific rarity
func get_items_by_rarity(rarity: ItemData.Rarity) -> Array[ItemData]:
	if items_by_rarity.has(rarity):
		return items_by_rarity[rarity]
	var empty: Array[ItemData] = []
	return empty


## Get all items that can be equipped in a specific slot
func get_items_by_equip_slot(slot: ItemData.EquipSlot) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item_data in items.values():
		if item_data.equip_slot == slot:
			result.append(item_data)
	return result


## Check if an item exists
func has_item(item_id: String) -> bool:
	return items.has(item_id)


## Get all item IDs
func get_all_item_ids() -> Array:
	return items.keys()


## Get random item by rarity (for loot generation)
func get_random_item_by_rarity(rarity: ItemData.Rarity) -> ItemData:
	var items_of_rarity = get_items_by_rarity(rarity)
	if items_of_rarity.is_empty():
		print("[ItemDatabase] Warning: No items found for rarity: ", rarity)
		return null

	return items_of_rarity[randi() % items_of_rarity.size()]


## Get random item by type
func get_random_item_by_type(item_type: ItemData.ItemType) -> ItemData:
	var items_of_type = get_items_by_type(item_type)
	if items_of_type.is_empty():
		print("[ItemDatabase] Warning: No items found for type: ", item_type)
		return null

	return items_of_type[randi() % items_of_type.size()]


## Get random item by type AND rarity
func get_random_item_by_type_and_rarity(item_type: ItemData.ItemType, rarity: ItemData.Rarity) -> ItemData:
	var filtered_items: Array[ItemData] = []

	for item_data in items.values():
		if item_data.item_type == item_type and item_data.rarity == rarity:
			filtered_items.append(item_data)

	if filtered_items.is_empty():
		print("[ItemDatabase] Warning: No items found for type %s and rarity %s" % [item_type, rarity])
		return null

	return filtered_items[randi() % filtered_items.size()]


## Reload all items (useful for development/hot-reload)
func reload_items():
	load_all_items()
