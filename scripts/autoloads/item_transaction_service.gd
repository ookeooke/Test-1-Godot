extends Node

## ItemTransactionService - Autoload Singleton
## Handles complex item movements between containers and equipment slots.
## Acts as the "Controller" in the MVC pattern.

## Move an item from one container to another
## Returns true if successful
func move_item(uuid: String, source_id: String, target_id: String, target_x: int = -1, target_y: int = -1) -> bool:
	var source = InventoryRegistry.get_container(source_id)
	var target = InventoryRegistry.get_container(target_id)
	
	if not source or not target:
		push_error("Invalid container IDs: %s -> %s" % [source_id, target_id])
		return false
		
	# 1. Get the item (Optimistic Transaction: Remove first)
	var item = source.remove_item(uuid)
	if not item:
		push_error("Item not found in source: " + uuid)
		return false
		
	# 2. Try to add to target
	var success = false
	if target_x != -1 and target_y != -1:
		# Specific position
		if target.can_place_item(item, target_x, target_y):
			# Manually place to bypass auto-find
			target._items[item.uuid] = item
			target._place_on_grid(item, target_x, target_y)
			target.item_added.emit(item.uuid, item.item_id)
			target.content_changed.emit()
			success = true
	else:
		# Auto-place
		success = target.add_item(item)
		
	# 3. Rollback if failed
	if not success:
		print("Transaction failed: Target full. Rolling back.")
		source.add_item(item) # Put it back
		return false
		
	return true

## Equip an item from ANY container to a Hero
func equip_item(hero_id: String, uuid: String, slot_name: String) -> bool:
	# Determine source container (could be stash or hero inventory)
	# We search hero inventory first, then stash
	var source_id = hero_id # Default to hero's own inventory
	var source = InventoryRegistry.get_container(source_id)
	
	if not source or not source.has_item(uuid):
		# Try stash
		source_id = "stash"
		source = InventoryRegistry.get_container(source_id)
		
	if not source or not source.has_item(uuid):
		push_error("Cannot equip: Item not found in hero inventory or stash")
		return false
	
	# 1. Remove from source
	var item = source.remove_item(uuid)
	if not item: return false
	
	# 2. Check if slot is occupied (Swap logic)
	var current_equipped = HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name)
	
	# 3. Equip new item
	if HeroEquipmentRegistry.equip_item(hero_id, slot_name, item):
		# 4. If there was an item equipped, move it to source container (Swap)
		if current_equipped:
			if not source.add_item(current_equipped):
				# Source full? Try stash if source was hero
				var fallback_success = false
				if source_id != "stash":
					var stash = InventoryRegistry.get_container("stash")
					if stash and stash.add_item(current_equipped):
						fallback_success = true
				
				if not fallback_success:
					# CRITICAL: Nowhere to put unequipped item!
					# Must rollback entire transaction
					HeroEquipmentRegistry.equip_item(hero_id, slot_name, current_equipped) # Restore old
					source.add_item(item) # Restore new to source
					print("Transaction failed: No space for swapped item")
					return false
		return true
	else:
		# Rollback
		source.add_item(item)
		return false

## Unequip an item from a Hero to a specific container (default: hero inventory)
func unequip_item(hero_id: String, slot_name: String, target_id: String = "") -> bool:
	if target_id == "":
		target_id = hero_id # Default to hero's inventory
		
	var target = InventoryRegistry.get_container(target_id)
	if not target: return false
	
	# 1. Get equipped item
	var item = HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name)
	if not item: return false # Nothing to unequip
	
	# 2. Check if target has space
	if not target.has_space_for(item):
		print("Cannot unequip: Target inventory full")
		return false
		
	# 3. Unequip (Clear slot)
	# We use clear_slot which returns success/fail
	# But we need to be careful not to lose the item if add fails (though we checked space)
	
	# Actually, HeroEquipmentRegistry.clear_slot just sets to null.
	# We already have the 'item' reference.
	
	if HeroEquipmentRegistry.clear_slot(hero_id, slot_name):
		# 4. Add to target
		if target.add_item(item):
			return true
		else:
			# CRITICAL: Add failed despite space check? (Race condition?)
			# Rollback: Re-equip
			HeroEquipmentRegistry.equip_item(hero_id, slot_name, item)
			return false
	
	return false
