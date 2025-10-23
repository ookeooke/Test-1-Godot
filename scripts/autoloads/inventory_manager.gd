extends Node

## InventoryManager - Autoload Singleton
## Manages player's account-wide inventory (Dungeon Defenders pattern)
## Separate from per-hero equipment slots

signal inventory_changed
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal inventory_full(item_id: String)
signal slot_limit_reached(category: String)

## Storage: {item_id: {quantity: int, upgrade_level: int}}
var global_inventory: Dictionary = {}

## Item upgrade levels: {item_id: upgrade_level}
var item_upgrades: Dictionary = {}

## Maximum slots per category (expandable)
var max_slots: Dictionary = {
	"equipment": 20,
	"consumables": 15,
	"materials": 30
}

## Slot upgrade costs
const SLOT_UPGRADE_COST: int = 500
const SLOTS_PER_UPGRADE: int = 5


func _ready():
	# Wait for ItemDatabase to load
	if not ItemDatabase.items_loaded.is_connected(_on_item_database_loaded):
		ItemDatabase.items_loaded.connect(_on_item_database_loaded)


func _on_item_database_loaded():
	print("[InventoryManager] Ready - ItemDatabase loaded")


## Add an item to the inventory
func add_item(item_id: String, quantity: int = 1) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		print("[InventoryManager] Error: Invalid item_id: ", item_id)
		return false

	# Check if we have space
	if !has_space_for_item(item_data):
		inventory_full.emit(item_id)
		print("[InventoryManager] Inventory full for item: ", item_id)
		return false

	# Add to inventory
	if global_inventory.has(item_id):
		# Stack existing item
		global_inventory[item_id].quantity += quantity
	else:
		# New item entry
		global_inventory[item_id] = {
			"quantity": quantity,
			"upgrade_level": 0
		}

	item_added.emit(item_id, quantity)
	inventory_changed.emit()
	print("[InventoryManager] Added %d x %s" % [quantity, item_data.item_name])
	return true


## Remove an item from the inventory
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if !global_inventory.has(item_id):
		print("[InventoryManager] Error: Item not in inventory: ", item_id)
		return false

	if global_inventory[item_id].quantity < quantity:
		print("[InventoryManager] Error: Not enough of item %s (have %d, need %d)" % [item_id, global_inventory[item_id].quantity, quantity])
		return false

	global_inventory[item_id].quantity -= quantity

	if global_inventory[item_id].quantity <= 0:
		global_inventory.erase(item_id)

	item_removed.emit(item_id, quantity)
	inventory_changed.emit()
	return true


## Get quantity of a specific item
func get_item_quantity(item_id: String) -> int:
	if global_inventory.has(item_id):
		return global_inventory[item_id].quantity
	return 0


## Get upgrade level of a specific item
func get_item_upgrade_level(item_id: String) -> int:
	if global_inventory.has(item_id):
		return global_inventory[item_id].upgrade_level
	return 0


## Upgrade an item (increase its level)
func upgrade_item(item_id: String) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null or !item_data.can_upgrade:
		return false

	if !global_inventory.has(item_id):
		print("[InventoryManager] Error: Item not in inventory: ", item_id)
		return false

	var current_level = global_inventory[item_id].upgrade_level
	if current_level >= item_data.max_upgrade_level:
		print("[InventoryManager] Item already at max level: ", item_id)
		return false

	var upgrade_cost = item_data.get_upgrade_cost(current_level)
	if upgrade_cost < 0:
		return false

	# Check if player has enough gems (persistent currency)
	if SaveManager.get_gems() < upgrade_cost:
		print("[InventoryManager] Not enough gems to upgrade")
		return false

	# Deduct cost and upgrade
	SaveManager.add_gems(-upgrade_cost)
	global_inventory[item_id].upgrade_level += 1

	inventory_changed.emit()
	print("[InventoryManager] Upgraded %s to level %d" % [item_data.item_name, global_inventory[item_id].upgrade_level])
	return true


## Check if we have space for a new item
func has_space_for_item(item_data: ItemData) -> bool:
	# If item is stackable and already exists, we can always add more
	if item_data.is_stackable() and global_inventory.has(item_data.item_id):
		return true

	# Check category slot limits
	var category = _get_category_for_item_type(item_data.item_type)
	var items_in_category = get_items_by_category(category)

	return items_in_category.size() < max_slots[category]


## Get all items in a specific category
func get_items_by_category(category: String) -> Array:
	var result = []

	for item_id in global_inventory.keys():
		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		var item_category = _get_category_for_item_type(item_data.item_type)
		if item_category == category:
			result.append({
				"item_id": item_id,
				"item_data": item_data,
				"quantity": global_inventory[item_id].quantity,
				"upgrade_level": global_inventory[item_id].upgrade_level
			})

	return result


## Get all items by ItemType
func get_items_by_type(item_type: ItemData.ItemType) -> Array:
	var result = []

	for item_id in global_inventory.keys():
		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		if item_data.item_type == item_type:
			result.append({
				"item_id": item_id,
				"item_data": item_data,
				"quantity": global_inventory[item_id].quantity,
				"upgrade_level": global_inventory[item_id].upgrade_level
			})

	return result


## Get ALL items in inventory (all categories combined)
func get_all_items() -> Array:
	var result = []

	for item_id in global_inventory.keys():
		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		result.append({
			"item_id": item_id,
			"item_data": item_data,
			"quantity": global_inventory[item_id].quantity,
			"upgrade_level": global_inventory[item_id].upgrade_level
		})

	return result


## Get category string for an item type
func _get_category_for_item_type(item_type: ItemData.ItemType) -> String:
	match item_type:
		ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR:
			return "equipment"
		ItemData.ItemType.CONSUMABLE:
			return "consumables"
		ItemData.ItemType.MATERIAL:
			return "materials"
		_:
			return "materials"


## Upgrade inventory slots for a category
func upgrade_inventory_slots(category: String) -> bool:
	if !max_slots.has(category):
		return false

	# Check if player has enough gems
	if SaveManager.get_gems() < SLOT_UPGRADE_COST:
		print("[InventoryManager] Not enough gems to upgrade slots")
		return false

	# Deduct cost and increase slots
	SaveManager.add_gems(-SLOT_UPGRADE_COST)
	max_slots[category] += SLOTS_PER_UPGRADE

	inventory_changed.emit()
	print("[InventoryManager] Upgraded %s slots to %d" % [category, max_slots[category]])
	return true


## Sell an item for gold
func sell_item(item_id: String, quantity: int = 1) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	if !remove_item(item_id, quantity):
		return false

	var sell_value = item_data.sell_value * quantity
	SaveManager.add_gems(sell_value)

	print("[InventoryManager] Sold %d x %s for %d gems" % [quantity, item_data.item_name, sell_value])
	return true


## Use a consumable item
func use_consumable(item_id: String) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null or item_data.item_type != ItemData.ItemType.CONSUMABLE:
		return false

	if !remove_item(item_id, 1):
		return false

	# The actual effect would be applied by the hero/game manager
	print("[InventoryManager] Used consumable: ", item_data.item_name)
	return true


## Check if player has a specific item
func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_quantity(item_id) >= quantity


## Get total number of unique items
func get_unique_item_count() -> int:
	return global_inventory.size()


## Clear entire inventory (for testing/reset)
func clear_inventory():
	global_inventory.clear()
	inventory_changed.emit()
	print("[InventoryManager] Inventory cleared")


## Save inventory data to dictionary (for SaveManager)
func save_to_dict() -> Dictionary:
	return {
		"global_inventory": global_inventory.duplicate(true),
		"max_slots": max_slots.duplicate()
	}


## Load inventory data from dictionary (from SaveManager)
func load_from_dict(data: Dictionary):
	global_inventory = data.get("global_inventory", {})
	max_slots = data.get("max_slots", max_slots)
	inventory_changed.emit()
	print("[InventoryManager] Loaded inventory with %d unique items" % global_inventory.size())
