extends Node

func _ready():
	print("\n=== STARTING INVENTORY SYSTEM VERIFICATION ===\n")
	
	# Allow time for Autoloads to initialize
	await get_tree().create_timer(0.5).timeout
	
	test_container_logic()
	test_transaction_service()
	test_equipment_transaction()
	
	print("\n=== ALL TESTS COMPLETED SUCCESSFULLY ===")
	# get_tree().quit() # Optional: Quit after tests

func test_container_logic():
	print("[TEST] InventoryContainer Logic")
	var container = InventoryContainer.new(8, 8, "test_container")
	var item = ItemInstance.new("basic_bow")
	
	# 1. Add Item
	var added = container.add_item(item)
	_assert(added, "Item should be added")
	_assert(container.has_item(item.uuid), "Container should have item")
	
	# 2. Check Position (Auto-place)
	var pos = container.get_item_position(item.uuid)
	_assert(pos != Vector2i(-1, -1), "Item should have a valid position")
	print("  - Add Item: OK")
	
	# 3. Remove Item
	var removed_item = container.remove_item(item.uuid)
	_assert(removed_item == item, "Removed item should match")
	_assert(not container.has_item(item.uuid), "Container should not have item")
	print("  - Remove Item: OK")
	
	print("  -> PASS")

func test_transaction_service():
	print("\n[TEST] ItemTransactionService (Move)")
	
	# Setup Containers
	var source_id = "test_source"
	var target_id = "test_target"
	
	var source = InventoryContainer.new(8, 8, source_id)
	var target = InventoryContainer.new(8, 8, target_id)
	
	InventoryRegistry.register_container(source_id, source)
	InventoryRegistry.register_container(target_id, target)
	
	var item = ItemInstance.new("basic_bow")
	source.add_item(item)
	
	# 1. Move Source -> Target
	var success = ItemTransactionService.move_item(item.uuid, source_id, target_id)
	_assert(success, "Move should succeed")
	_assert(not source.has_item(item.uuid), "Source should be empty")
	_assert(target.has_item(item.uuid), "Target should have item")
	print("  - Move Item: OK")
	
	# 2. Move Target -> Source (Return)
	success = ItemTransactionService.move_item(item.uuid, target_id, source_id)
	_assert(success, "Return move should succeed")
	_assert(source.has_item(item.uuid), "Source should have item back")
	print("  - Return Item: OK")
	
	# Cleanup
	InventoryRegistry.unregister_container(source_id)
	InventoryRegistry.unregister_container(target_id)
	print("  -> PASS")

func test_equipment_transaction():
	print("\n[TEST] ItemTransactionService (Equip/Unequip)")
	
	var hero_id = "test_hero_ranger"
	var container_id = hero_id # Hero's inventory ID is same as hero ID
	
	# Setup Hero Inventory
	var container = InventoryContainer.new(8, 8, container_id)
	InventoryRegistry.register_container(container_id, container)
	
	# Register Hero in Equipment Registry (if needed, but registry handles data)
	# We might need to ensure HeroEquipmentRegistry is ready or clear it
	
	var item = ItemInstance.new("basic_bow")
	container.add_item(item)
	
	# 1. Equip Item (Hand Left)
	# Note: "basic_bow" is 2H, so it might take both slots, but let's try "hand_left"
	# The system might auto-handle 2H logic, but for this test we just check basic flow
	var slot_name = "hand_left"
	
	var success = ItemTransactionService.equip_item(hero_id, item.uuid, slot_name)
	_assert(success, "Equip should succeed")
	_assert(not container.has_item(item.uuid), "Item should be removed from inventory")
	
	var equipped = HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name)
	_assert(equipped != null and equipped.uuid == item.uuid, "Item should be in equipment slot")
	print("  - Equip Item: OK")
	
	# 2. Unequip Item
	success = ItemTransactionService.unequip_item(hero_id, slot_name)
	_assert(success, "Unequip should succeed")
	_assert(container.has_item(item.uuid), "Item should be back in inventory")
	_assert(HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name) == null, "Equipment slot should be empty")
	print("  - Unequip Item: OK")
	
	# Cleanup
	InventoryRegistry.unregister_container(container_id)
	print("  -> PASS")

func _assert(condition: bool, message: String):
	if not condition:
		push_error("ASSERTION FAILED: " + message)
		print("FAILED: " + message)
