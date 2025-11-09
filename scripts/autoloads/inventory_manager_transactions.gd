# TEMPORARY FILE - Transaction wrapper functions to be added to inventory_manager.gd

## ============================================
## EQUIPMENT TRANSACTION WRAPPERS (NEW - Option A Refactor)
## ============================================

func equip_item_atomic(hero_id: String, slot: String, item_id: String) -> bool:
	"""Atomically equip item with inventory/equipment coordination"""

	# Validate item exists in inventory
	if not global_inventory.has(item_id):
		print("[InventoryManager] Cannot equip - item not in inventory: ", item_id)
		return false

	# Start transaction
	if not HeroEquipmentRegistry.begin_transaction(hero_id, "equip"):
		return false

	# Get old item if any
	var old_item = HeroEquipmentRegistry.get_equipped_item(hero_id, slot)

	# Step 1: Remove new item from inventory grid
	if not remove_from_grid(item_id):
		HeroEquipmentRegistry.rollback_transaction()
		print("[InventoryManager] Failed to remove item from grid")
		return false

	# Step 2: Unequip old item (if any)
	if old_item != "":
		# Add old item back to inventory
		if not auto_place_item(old_item):
			# Rollback: restore new item to grid
			auto_place_item(item_id)
			HeroEquipmentRegistry.rollback_transaction()
			print("[InventoryManager] Failed to place old item in inventory")
			return false

	# Step 3: Equip new item in registry
	if not HeroEquipmentRegistry.equip_item_in_transaction(slot, item_id):
		# Rollback: restore items to original positions
		if old_item != "":
			remove_from_grid(old_item)
		auto_place_item(item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false

	# Step 4: Commit transaction
	if not HeroEquipmentRegistry.commit_transaction():
		# Rollback all changes
		if old_item != "":
			remove_from_grid(old_item)
		auto_place_item(item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false

	# Success - emit local inventory signal (equipment signal already emitted by registry)
	inventory_changed.emit()

	print("[InventoryManager] Successfully equipped ", item_id, " to ", hero_id, ":", slot)
	return true

func unequip_item_atomic(hero_id: String, slot: String) -> bool:
	"""Atomically unequip item with inventory coordination"""

	var item_id = HeroEquipmentRegistry.get_equipped_item(hero_id, slot)
	if item_id == "":
		print("[InventoryManager] Slot already empty: ", slot)
		return true

	# Start transaction
	if not HeroEquipmentRegistry.begin_transaction(hero_id, "unequip"):
		return false

	# Step 1: Unequip in registry
	if not HeroEquipmentRegistry.equip_item_in_transaction(slot, ""):
		HeroEquipmentRegistry.rollback_transaction()
		return false

	# Step 2: Add to inventory grid
	if not auto_place_item(item_id):
		HeroEquipmentRegistry.rollback_transaction()
		inventory_full.emit(item_id)
		print("[InventoryManager] Inventory full - cannot unequip")
		return false

	# Step 3: Commit transaction
	if not HeroEquipmentRegistry.commit_transaction():
		remove_from_grid(item_id)
		HeroEquipmentRegistry.rollback_transaction()
		return false

	inventory_changed.emit()

	print("[InventoryManager] Successfully unequipped ", item_id, " from ", hero_id, ":", slot)
	return true

func remove_from_grid(item_id: String) -> bool:
	"""Remove item from grid (for equipping)"""
	if not item_positions.has(item_id):
		return false

	var pos = item_positions[item_id]
	var item_data = ItemDatabase.get_item(item_id)

	if not item_data:
		return false

	# Clear grid cells
	for x in range(item_data.inventory_width):
		for y in range(item_data.inventory_height):
			var grid_x = pos.x + x
			var grid_y = pos.y + y
			if is_valid_position(grid_x, grid_y):
				grid[grid_y][grid_x] = ""

	item_positions.erase(item_id)
	return true
