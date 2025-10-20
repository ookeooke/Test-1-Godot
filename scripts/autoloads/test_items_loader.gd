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

	# Health Potion (Common Consumable)
	var health_potion = ItemData.new()
	health_potion.item_id = "health_potion"
	health_potion.item_name = "Health Potion"
	health_potion.description = "Restores 100 health when consumed."
	health_potion.item_type = ItemData.ItemType.CONSUMABLE
	health_potion.rarity = ItemData.Rarity.COMMON
	health_potion.equip_slot = ItemData.EquipSlot.NONE
	health_potion.max_stack = 99
	health_potion.sell_value = 10
	health_potion.heal_amount = 100
	_register_item(health_potion)

	# Iron Ore (Common Material)
	var iron_ore = ItemData.new()
	iron_ore.item_id = "iron_ore"
	iron_ore.item_name = "Iron Ore"
	iron_ore.description = "Raw iron ore. Used for crafting."
	iron_ore.item_type = ItemData.ItemType.MATERIAL
	iron_ore.rarity = ItemData.Rarity.COMMON
	iron_ore.equip_slot = ItemData.EquipSlot.NONE
	iron_ore.max_stack = 99
	iron_ore.sell_value = 5
	_register_item(iron_ore)

	# Magic Essence (Rare Material)
	var magic_essence = ItemData.new()
	magic_essence.item_id = "magic_essence"
	magic_essence.item_name = "Magic Essence"
	magic_essence.description = "Crystallized magical energy."
	magic_essence.item_type = ItemData.ItemType.MATERIAL
	magic_essence.rarity = ItemData.Rarity.RARE
	magic_essence.equip_slot = ItemData.EquipSlot.NONE
	magic_essence.max_stack = 99
	magic_essence.sell_value = 20
	_register_item(magic_essence)

	# Dragon Scale (Legendary Material)
	var dragon_scale = ItemData.new()
	dragon_scale.item_id = "dragon_scale"
	dragon_scale.item_name = "Dragon Scale"
	dragon_scale.description = "A scale from an ancient dragon."
	dragon_scale.item_type = ItemData.ItemType.MATERIAL
	dragon_scale.rarity = ItemData.Rarity.LEGENDARY
	dragon_scale.equip_slot = ItemData.EquipSlot.NONE
	dragon_scale.max_stack = 99
	dragon_scale.sell_value = 100
	_register_item(dragon_scale)

	print("[TestItemsLoader] Created %d test items" % ItemDatabase.items.size())


func _register_item(item_data: ItemData):
	"""Manually register item in ItemDatabase"""
	if ItemDatabase.items.has(item_data.item_id):
		return

	ItemDatabase.items[item_data.item_id] = item_data
	ItemDatabase.items_by_type[item_data.item_type].append(item_data)
	ItemDatabase.items_by_rarity[item_data.rarity].append(item_data)
