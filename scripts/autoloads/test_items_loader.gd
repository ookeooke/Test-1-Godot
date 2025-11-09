extends Node

## TestItemsLoader - Creates test items programmatically
## This avoids .tres UID issues during development

func _ready():
	# Wait for ItemDatabase to be ready
	await get_tree().process_frame
	create_test_items()


func create_test_items():
	print("[TestItemsLoader] Creating test items...")

	# Basic Bow (Common Weapon)
	var basic_bow = ItemData.new()
	basic_bow.item_id = "basic_bow"
	basic_bow.item_name = "Basic Bow"
	basic_bow.description = "A simple wooden bow for beginning rangers."
	basic_bow.item_type = ItemData.ItemType.WEAPON
	basic_bow.rarity = ItemData.Rarity.COMMON
	basic_bow.equip_slot = ItemData.EquipSlot.WEAPON
	basic_bow.max_stack = 1
	basic_bow.sell_value = 50
	basic_bow.damage_bonus = 15
	basic_bow.can_upgrade = true
	_register_item(basic_bow)

	# Legendary Bow
	var legendary_bow = ItemData.new()
	legendary_bow.item_id = "legendary_bow"
	legendary_bow.item_name = "Windseeker Bow"
	legendary_bow.description = "A legendary bow blessed by ancient winds."
	legendary_bow.item_type = ItemData.ItemType.WEAPON
	legendary_bow.rarity = ItemData.Rarity.LEGENDARY
	legendary_bow.equip_slot = ItemData.EquipSlot.WEAPON
	legendary_bow.max_stack = 1
	legendary_bow.sell_value = 500
	legendary_bow.damage_bonus = 75
	legendary_bow.attack_speed_multiplier = 1.3
	legendary_bow.crit_chance_bonus = 0.15
	legendary_bow.can_upgrade = true
	_register_item(legendary_bow)

	print("[TestItemsLoader] Created %d test items" % ItemDatabase.items.size())


func _register_item(item_data: ItemData):
	"""Manually register item in ItemDatabase"""
	if ItemDatabase.items.has(item_data.item_id):
		return

	ItemDatabase.items[item_data.item_id] = item_data
	ItemDatabase.items_by_type[item_data.item_type].append(item_data)
	ItemDatabase.items_by_rarity[item_data.rarity].append(item_data)
