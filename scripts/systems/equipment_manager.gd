class_name EquipmentManager
extends Node

## EquipmentManager - Manages equipped items for a hero
## Handles equip/unequip logic and calculates stat bonuses

signal equipment_changed
signal item_equipped(slot: String, item_id: String)
signal item_unequipped(slot: String, item_id: String)

@export var hero_id: String = "ranger"  ## ID for save/load

# Equipment slots
var equipped_items: Dictionary = {
	"weapon": "",       # item_id or empty string
	"armor": "",
	"accessory_1": "",
	"accessory_2": ""
}

# Internal flag to prevent duplicate loading
var _has_loaded_from_save: bool = false


func _ready():
	# Load equipped items from SaveManager (if not already loaded by parent)
	if not _has_loaded_from_save:
		load_from_save()


## Equip an item in a specific slot
func equip_item(slot: String, item_id: String) -> bool:
	if not equipped_items.has(slot):
		print("[EquipmentManager] Error: Invalid slot: ", slot)
		return false

	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		print("[EquipmentManager] Error: Item not found: ", item_id)
		return false

	# Verify item can be equipped in this slot
	if not _can_equip_in_slot(item_data, slot):
		print("[EquipmentManager] Error: Item cannot be equipped in slot: ", slot)
		return false

	# Unequip current item if present
	if equipped_items[slot] != "":
		unequip_item(slot)

	# Remove item from inventory
	if not InventoryManager.remove_item(item_id, 1):
		print("[EquipmentManager] Error: Could not remove item from inventory")
		return false

	# Equip the item
	equipped_items[slot] = item_id

	item_equipped.emit(slot, item_id)
	equipment_changed.emit()

	# Save to SaveManager
	save_to_save()

	print("[EquipmentManager] Equipped %s in %s" % [item_data.item_name, slot])
	return true


## Unequip an item from a slot
func unequip_item(slot: String) -> bool:
	if not equipped_items.has(slot):
		return false

	var item_id = equipped_items[slot]
	if item_id == "":
		return false

	# Add item back to inventory
	if not InventoryManager.add_item(item_id, 1):
		print("[EquipmentManager] Error: Inventory full, cannot unequip")
		return false

	# Unequip
	equipped_items[slot] = ""

	item_unequipped.emit(slot, item_id)
	equipment_changed.emit()

	# Save to SaveManager
	save_to_save()

	print("[EquipmentManager] Unequipped item from %s" % slot)
	return true


## Check if an item can be equipped in a specific slot
func _can_equip_in_slot(item_data: ItemData, slot: String) -> bool:
	# Weapon slot
	if slot == "weapon":
		return item_data.equip_slot == ItemData.EquipSlot.WEAPON

	# Armor slot
	elif slot == "armor":
		return item_data.equip_slot == ItemData.EquipSlot.ARMOR

	# Accessory slots
	elif slot == "accessory_1" or slot == "accessory_2":
		return item_data.equip_slot == ItemData.EquipSlot.ACCESSORY

	return false


## ============================================
## NEW UNIFIED STAT SYSTEM
## ============================================

## Get all stat modifiers from equipped items (NEW unified system)
## This is the primary method for the new stat system
func get_all_stat_modifiers() -> Array[StatModifier]:
	var all_modifiers: Array[StatModifier] = []

	for item_id in equipped_items.values():
		if item_id == "":
			continue

		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		# Get upgrade level if item is upgraded
		var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)

		# Get modifiers from this item (includes upgrade bonuses)
		var item_modifiers = item_data.get_stat_modifiers(upgrade_level)
		all_modifiers.append_array(item_modifiers)

	if all_modifiers.size() > 0:
		print("[EquipmentManager] Generated %d stat modifiers from equipment" % all_modifiers.size())

	return all_modifiers

## ============================================
## DEPRECATED METHODS REMOVED
## ============================================
## Old cached stat system has been removed.
## Use get_all_stat_modifiers() for the unified stat system.
## Heroes recalculate stats automatically via equipment_changed signal.


## Get item ID equipped in a slot
func get_equipped_item(slot: String) -> String:
	return equipped_items.get(slot, "")


## Get equipped item in a slot by equip slot type (for comparisons)
func get_equipped_item_by_type(equip_slot: ItemData.EquipSlot) -> String:
	"""Returns the item_id of the equipped item matching the given equip slot type"""
	match equip_slot:
		ItemData.EquipSlot.WEAPON:
			return equipped_items.get("weapon", "")
		ItemData.EquipSlot.ARMOR:
			return equipped_items.get("armor", "")
		ItemData.EquipSlot.ACCESSORY:
			# Return first non-empty accessory slot
			var acc1 = equipped_items.get("accessory_1", "")
			if acc1 != "":
				return acc1
			return equipped_items.get("accessory_2", "")
	return ""


## Check if a slot is empty
func is_slot_empty(slot: String) -> bool:
	return equipped_items.get(slot, "") == ""


## Get all equipped items as dictionary
func get_all_equipped() -> Dictionary:
	return equipped_items.duplicate()


## Check if hero has any equipment equipped
func has_equipment() -> bool:
	for item_id in equipped_items.values():
		if item_id != "":
			return true
	return false


## Save equipped items to SaveManager
func save_to_save():
	if SaveManager:
		SaveManager.save_hero_equipment(hero_id, equipped_items)


## Load equipped items from SaveManager
func load_from_save():
	if SaveManager:
		var saved_equipment = SaveManager.get_hero_equipment(hero_id)
		if not saved_equipment.is_empty():
			equipped_items = saved_equipment.duplicate()
			equipment_changed.emit()
			print("[EquipmentManager] Loaded equipment for hero: ", hero_id)

	# Mark as loaded to prevent duplicate loads
	_has_loaded_from_save = true


## Clear all equipment (unequip everything)
func clear_all_equipment():
	for slot in equipped_items.keys():
		if equipped_items[slot] != "":
			unequip_item(slot)


## Get equipment summary for display
func get_equipment_summary() -> String:
	var summary = ""
	for slot in equipped_items.keys():
		var item_id = equipped_items[slot]
		if item_id != "":
			var item_data = ItemDatabase.get_item(item_id)
			if item_data:
				summary += "%s: %s\n" % [slot.capitalize(), item_data.item_name]
		else:
			summary += "%s: Empty\n" % slot.capitalize()
	return summary
