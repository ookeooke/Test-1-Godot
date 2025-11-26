extends Node

## ItemTransactionService - Autoload Singleton
## Handles complex item movements between containers and equipment slots.
## Acts as the "Controller" in the MVC pattern.

# Debug mode
const DEBUG_TRANSACTIONS = false # Enable verbose transaction logging

## Move an item from one container to another
## Returns true if successful
func move_item(uuid: String, source_id: String, target_id: String, target_x: int = -1, target_y: int = -1) -> bool:
	if DEBUG_TRANSACTIONS:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("[ItemTransactionService] 🔄 Starting Transaction")
		print("  UUID: %s" % uuid)
		print("  Route: '%s' → '%s'" % [source_id, target_id])
		print("  Target Position: %s" % ("(%d, %d)" % [target_x, target_y] if target_x != -1 else "AUTO"))

	var source = InventoryRegistry.get_container(source_id)
	var target = InventoryRegistry.get_container(target_id)

	if not source:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Source container not found: '%s'" % source_id)
			print("  Available containers: %s" % InventoryRegistry._containers.keys())
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Invalid source container ID: %s" % source_id)
		return false

	if not target:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Target container not found: '%s'" % target_id)
			print("  Available containers: %s" % InventoryRegistry._containers.keys())
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Invalid target container ID: %s" % target_id)
		return false

	# 1. Get the item (Optimistic Transaction: Remove first)
	# 🔧 FIX: Capture original position BEFORE removing (for rollback)
	var original_pos = source.get_item_position(uuid)

	var item = source.remove_item(uuid)
	if not item:
		if DEBUG_TRANSACTIONS:
			print("  ❌ FAILED: Item not found in source container")
			print("  Searched UUID: %s" % uuid)
			print("  Items in source: %d" % source._items.size())
			var item_uuids = source._items.keys()
			if item_uuids.size() > 0:
				print("  Sample UUIDs in source: %s" % str(item_uuids.slice(0, 3)))
			else:
				print("  Source container is EMPTY")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		push_error("Item not found in source: " + uuid)
		return false

	if DEBUG_TRANSACTIONS:
		print("  ✅ Item removed from source: %s" % item.item_id)
		var item_data = item.get_data()
		print("  Item Size: %dx%d" % [item_data.inventory_width, item_data.inventory_height])

	# 2. Try to add to target
	var success = false
	if target_x != -1 and target_y != -1:
		# Specific position
		if DEBUG_TRANSACTIONS:
			print("  🎯 Attempting placement at specific position (%d, %d)" % [target_x, target_y])

		if target.can_place_item(item, target_x, target_y):
			# Manually place to bypass auto-find
			target._items[item.uuid] = item
			target._place_on_grid(item, target_x, target_y)
			target.item_added.emit(item.uuid, item.item_id)
			target.content_changed.emit()
			success = true
			if DEBUG_TRANSACTIONS:
				print("  ✅ Placement successful at (%d, %d)" % [target_x, target_y])
		else:
			if DEBUG_TRANSACTIONS:
				print("  ❌ Placement BLOCKED at (%d, %d)" % [target_x, target_y])
				# Check WHY placement failed
				var item_data = item.get_data()
				var bounds_ok = target_x >= 0 and target_y >= 0 and target_x + item_data.inventory_width <= target.width and target_y + item_data.inventory_height <= target.height
				print("  Bounds Check: %s" % ("✅ PASS" if bounds_ok else "❌ FAIL"))
				if not bounds_ok:
					print("    Item: %dx%d at (%d,%d)" % [item_data.inventory_width, item_data.inventory_height, target_x, target_y])
					print("    Grid: %dx%d" % [target.width, target.height])
					print("    Would extend to: (%d, %d)" % [target_x + item_data.inventory_width, target_y + item_data.inventory_height])

				# Check collision
				if bounds_ok:
					print("  Collision Check: CHECKING...")
					for dy in range(item_data.inventory_height):
						for dx in range(item_data.inventory_width):
							var cell_x = target_x + dx
							var cell_y = target_y + dy
							if cell_y < target._grid.size() and cell_x < target._grid[cell_y].size():
								var cell_content = target._grid[cell_y][cell_x]
								if cell_content != "":
									print("    ❌ Cell (%d, %d) occupied by: %s" % [cell_x, cell_y, cell_content])

			# 🧲 SMART NUDGE: Try to find a nearby valid position
			var nudged_pos = target.find_nearest_valid_position(item, target_x, target_y)
			if nudged_pos != Vector2i(-1, -1):
				if DEBUG_TRANSACTIONS:
					print("  🧲 SMART NUDGE: Found valid position at (%d, %d)" % [nudged_pos.x, nudged_pos.y])
				# Place at nudged position
				target._items[item.uuid] = item
				target._place_on_grid(item, nudged_pos.x, nudged_pos.y)
				target.item_added.emit(item.uuid, item.item_id)
				target.content_changed.emit()
				success = true  # ✅ Nudge succeeded
			else:
				# 🔄 ATOMIC SWAP: Try to swap with blocking item (if exactly 1 blocking)
				# Item was removed from source at line 40, so we can't get its old position
				# But try_atomic_swap doesn't need it (parameter kept for future use)
				if try_atomic_swap(item, source, target, target_x, target_y, Vector2i(-1, -1)):
					success = true  # ✅ Swap succeeded
				# If swap also failed, fall through to rollback
	else:
		# Auto-place
		if DEBUG_TRANSACTIONS:
			print("  🎯 Attempting AUTO-PLACEMENT")
		success = target.add_item(item)
		if DEBUG_TRANSACTIONS:
			if success:
				var pos = target.get_item_position(item.uuid)
				print("  ✅ Auto-placed at (%d, %d)" % [pos.x, pos.y])
			else:
				print("  ❌ Auto-placement FAILED (no free space)")

	# 3. Rollback if failed
	if not success:
		if DEBUG_TRANSACTIONS:
			print("  🔄 ROLLBACK: Returning item to source")
		print("Transaction failed: Target full or placement blocked. Rolling back.")

		# 🔧 FIX: Restore to ORIGINAL position (not auto-place)
		if original_pos != Vector2i(-1, -1):
			if source.add_item_at(item, original_pos.x, original_pos.y):
				if DEBUG_TRANSACTIONS:
					print("  ✅ Restored to original position (%d, %d)" % [original_pos.x, original_pos.y])
			else:
				# Fallback: Original position blocked (shouldn't happen, but defensive)
				source.add_item(item)
				if DEBUG_TRANSACTIONS:
					print("  ⚠️ Original position blocked, used auto-place")
		else:
			# Fallback: No original position available
			source.add_item(item)
			if DEBUG_TRANSACTIONS:
				print("  ⚠️ No original position, used auto-place")

		if DEBUG_TRANSACTIONS:
			print("  ❌ TRANSACTION FAILED")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return false

	if DEBUG_TRANSACTIONS:
		print("  ✅ TRANSACTION SUCCESSFUL")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# 🔧 FIX CRITICAL: Mark save data as dirty so auto-save persists item movements
	SaveManager.mark_dirty()

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

	# Get item data for 2H check
	var item_data = item.get_data()

	# 🏹 2H WEAPON LOGIC: Handle two-handed weapons
	if item_data and item_data.is_two_handed and slot_name == "hand_left":
		# 2H weapon going to left hand - must clear right hand first
		var right_item = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_right")
		if right_item:
			# Unequip right hand item to inventory first
			if not unequip_item(hero_id, "hand_right", source_id):
				# Can't unequip right hand - rollback
				source.add_item(item)
				return false

	# 🏹 2H WEAPON LOGIC: If equipping to right hand, check if left has 2H
	if slot_name == "hand_right":
		var left_item = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_left")
		if left_item:
			var left_data = left_item.get_data()
			if left_data and left_data.is_two_handed:
				# Left hand has 2H weapon - must unequip it first
				if not unequip_item(hero_id, "hand_left", source_id):
					# Can't unequip 2H - rollback
					source.add_item(item)
					return false

	# 2. Check if slot is occupied (Swap logic)
	var current_equipped = HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name)

	# 3. Equip new item
	if HeroEquipmentRegistry.equip_item(hero_id, slot_name, item):
		# 🏹 2H WEAPON: Set marker on right hand if equipping 2H to left
		if item_data and item_data.is_two_handed and slot_name == "hand_left":
			# Use transaction API to set string marker (equip_item only accepts ItemInstance)
			HeroEquipmentRegistry.begin_transaction(hero_id, "2h_marker")
			HeroEquipmentRegistry.equip_item_in_transaction("hand_right", "__2H_OCCUPIED__")
			HeroEquipmentRegistry.commit_transaction()
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

		# 🔧 FIX CRITICAL: Mark save data as dirty so auto-save persists equipment changes
		SaveManager.mark_dirty()
		return true
	else:
		# Rollback
		source.add_item(item)
		return false

## ATOMIC SWAP: Try to swap two items if exactly ONE item is blocking
## Returns true if swap succeeded, false otherwise
## This is called AFTER Smart Nudge fails
func try_atomic_swap(item_a: ItemInstance, source: InventoryContainer, target: InventoryContainer, target_x: int, target_y: int, _source_pos: Vector2i) -> bool:
	if DEBUG_TRANSACTIONS:
		print("  🔄 ATOMIC SWAP: Analyzing collision...")

	# 1. Identify blocking items in target area
	var blocking_uuids = target.get_items_in_area(item_a, target_x, target_y)

	if DEBUG_TRANSACTIONS:
		print("  Blocking items: %d" % blocking_uuids.size())

	# 2. CONSTRAINT: Must be EXACTLY 1 blocking item for clean swap
	if blocking_uuids.size() == 0:
		if DEBUG_TRANSACTIONS:
			print("  ❌ No blocking items (placement failed for other reasons)")
		return false  # Failed for other reasons (bounds, etc.)

	if blocking_uuids.size() > 1:
		if DEBUG_TRANSACTIONS:
			print("  ❌ Too complex: %d items blocking (swap requires exactly 1)" % blocking_uuids.size())
		return false  # Too complex (e.g., 2x2 armor on 4 rings)

	# 3. Get the single blocking item (Item B)
	var item_b_uuid = blocking_uuids[0]

	# 🔧 FIX: Use direct O(1) dictionary lookup instead of O(n) filter
	var item_b = target._items.get(item_b_uuid)

	if not item_b:
		push_error("Blocking item not found: " + item_b_uuid)
		return false

	if DEBUG_TRANSACTIONS:
		print("  🔍 Blocking item: %s" % item_b.item_id)

	# 4. LOOSE CHECK: Can Item B fit ANYWHERE in source container?
	# (We don't require it to fit at exact source_pos, just any valid space)
	if not source.has_space_for(item_b):
		if DEBUG_TRANSACTIONS:
			print("  ❌ Item B cannot fit in source container (no space)")
		return false

	if DEBUG_TRANSACTIONS:
		print("  ✅ Item B can fit in source - proceeding with swap...")

	# 5. ATOMIC TRANSACTION (4 steps with rollback)
	# Remember: Item A is ALREADY removed from source (optimistic transaction)
	# We need to restore it if swap fails

	# Backup Item B's position for rollback
	var item_b_pos = target.get_item_position(item_b_uuid)

	# Step 1: Remove Item B from target
	var removed_b = target.remove_item(item_b_uuid)
	if not removed_b:
		push_error("Failed to remove Item B during swap")
		return false

	if DEBUG_TRANSACTIONS:
		print("  Step 1/4: Removed Item B from target")

	# Step 2: Try to place Item A at target position
	if not target.add_item_at(item_a, target_x, target_y):
		# ROLLBACK: Restore Item B to target
		if DEBUG_TRANSACTIONS:
			print("  ❌ ROLLBACK: Failed to place Item A at target")
		target.add_item_at(item_b, item_b_pos.x, item_b_pos.y)
		return false

	if DEBUG_TRANSACTIONS:
		print("  Step 2/4: Placed Item A at target (%d, %d)" % [target_x, target_y])

	# Step 3: Try to place Item B in source (any position - AUTO-PLACE)
	if not source.add_item(item_b):
		# CRITICAL ROLLBACK: Undo both operations
		if DEBUG_TRANSACTIONS:
			print("  ❌ ROLLBACK: Failed to place Item B in source")

		# Remove Item A from target
		target.remove_item(item_a.uuid)

		# Restore Item B to target
		target.add_item_at(item_b, item_b_pos.x, item_b_pos.y)

		# Restore Item A to source (will be done by caller's rollback)
		return false

	if DEBUG_TRANSACTIONS:
		var item_b_new_pos = source.get_item_position(item_b_uuid)
		print("  Step 3/4: Placed Item B in source at (%d, %d)" % [item_b_new_pos.x, item_b_new_pos.y])

	# 4. SUCCESS!
	if DEBUG_TRANSACTIONS:
		print("  ✅ ATOMIC SWAP SUCCESSFUL!")
		print("    '%s' → target (%d, %d)" % [item_a.item_id, target_x, target_y])
		var item_b_final_pos = source.get_item_position(item_b_uuid)
		print("    '%s' → source (%d, %d)" % [item_b.item_id, item_b_final_pos.x, item_b_final_pos.y])

	return true

## Unequip an item from a Hero to a specific container (default: hero inventory)
func unequip_item(hero_id: String, slot_name: String, target_id: String = "", target_x: int = -1, target_y: int = -1) -> bool:
	if target_id == "":
		target_id = hero_id # Default to hero's inventory

	var target = InventoryRegistry.get_container(target_id)
	if not target: return false

	# 1. Get equipped item
	var item = HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name)
	if not item: return false # Nothing to unequip

	# 2. Check if target has space (at specific position if provided, otherwise anywhere)
	var has_space = false
	if target_x >= 0 and target_y >= 0:
		has_space = target.can_place_item(item, target_x, target_y)
	else:
		has_space = target.has_space_for(item)

	if not has_space:
		print("Cannot unequip: Target inventory full or position blocked")
		return false

	# 🏹 2H WEAPON LOGIC: Check if unequipping a 2H weapon from hand_left
	var item_data = item.get_data()
	var is_2h_weapon = item_data and item_data.is_two_handed and slot_name == "hand_left"

	# 3. Unequip (Clear slot)
	# We use clear_slot which returns success/fail
	# But we need to be careful not to lose the item if add fails (though we checked space)

	# Actually, HeroEquipmentRegistry.clear_slot just sets to null.
	# We already have the 'item' reference.

	if HeroEquipmentRegistry.clear_slot(hero_id, slot_name):
		# 4. Add to target (at specific position if provided)
		var add_success = false
		if target_x >= 0 and target_y >= 0:
			add_success = target.add_item_at(item, target_x, target_y)
		else:
			add_success = target.add_item(item)

		if add_success:
			# 🏹 2H WEAPON: Clear the __2H_OCCUPIED__ marker from hand_right
			if is_2h_weapon:
				HeroEquipmentRegistry.clear_slot(hero_id, "hand_right")
			# 🔧 FIX CRITICAL: Mark save data as dirty so auto-save persists unequip operations
			SaveManager.mark_dirty()
			return true
		else:
			# CRITICAL: Add failed despite space check? (Race condition?)
			# Rollback: Re-equip
			HeroEquipmentRegistry.equip_item(hero_id, slot_name, item)
			return false

	return false
