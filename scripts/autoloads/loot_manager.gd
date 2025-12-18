extends Node

## LootManager - Autoload Singleton
## Handles loot generation, drop rates, and spawning loot pickups
## Implements hybrid system: random drops + guaranteed boss loot

signal loot_spawned(item_id: String, position: Vector2)
signal gold_spawned(amount: int, position: Vector2)

const ITEM_PICKUP_SCENE = preload("res://scenes/items/item_pickup.tscn")

# Loot tables per enemy tier (Diablo 2 style)
# Normal (white) = Base items, Magic (blue) = 1-2 affixes, Rare (yellow) = 3-6 affixes
# Steep rarity curve - bosses drop best loot
var loot_tables: Dictionary = {
	"tier1": {
		"drop_chance": 0.015, # 1.5% - Very rare drops
		"gold_range": [5, 15],
		"rarity_weights": {
			ItemData.Rarity.NORMAL: 0.85, # 85% normal (white) items
			ItemData.Rarity.MAGIC: 0.14, # 14% magic (blue) items
			ItemData.Rarity.RARE: 0.01, # 1% rare (yellow) items
			ItemData.Rarity.SET: 0.0, # No set items from trash mobs
			ItemData.Rarity.UNIQUE: 0.0 # No unique items from trash mobs
		}
	},
	"tier2": {
		"drop_chance": 0.04, # 4% - Rare drops
		"gold_range": [15, 40],
		"rarity_weights": {
			ItemData.Rarity.NORMAL: 0.70, # 70% normal items
			ItemData.Rarity.MAGIC: 0.25, # 25% magic items
			ItemData.Rarity.RARE: 0.05, # 5% rare items
			ItemData.Rarity.SET: 0.0, # No set items
			ItemData.Rarity.UNIQUE: 0.0 # No unique items
		}
	},
	"tier3": {
		"drop_chance": 0.10, # 10% - Uncommon drops
		"gold_range": [40, 80],
		"rarity_weights": {
			ItemData.Rarity.NORMAL: 0.50, # 50% normal items
			ItemData.Rarity.MAGIC: 0.35, # 35% magic items
			ItemData.Rarity.RARE: 0.14, # 14% rare items
			ItemData.Rarity.SET: 0.0, # No set items
			ItemData.Rarity.UNIQUE: 0.01 # 1% unique items (very rare!)
		}
	},
	"boss": {
		"drop_chance": 1.0, # 100% guaranteed drop
		"gold_range": [100, 200],
		"item_count": 1, # 1 item per boss
		"rarity_weights": {
			ItemData.Rarity.NORMAL: 0.0, # Bosses never drop normal items
			ItemData.Rarity.MAGIC: 0.20, # 20% magic items
			ItemData.Rarity.RARE: 0.50, # 50% rare items (HIGH CHANCE!)
			ItemData.Rarity.SET: 0.05, # 5% set items
			ItemData.Rarity.UNIQUE: 0.25 # 25% unique items (HIGH CHANCE!)
		}
	}
}

# Temporary storage for loot to collect at wave end (Dungeon Defenders pattern)
var pending_wave_loot: Array = []
var pending_wave_gold: int = 0


func _ready():
	print("[LootManager] Ready")


## Roll loot for an enemy death
func roll_loot_for_enemy(enemy_tier: String, position: Vector2, guaranteed_item: String = "") -> void:
	var table = loot_tables.get(enemy_tier, loot_tables["tier1"])

	# Always drop gold
	var gold_amount = randi_range(table.gold_range[0], table.gold_range[1])
	_spawn_gold_pickup(gold_amount, position)

	# Guaranteed item (for bosses or special enemies)
	if guaranteed_item != "":
		_spawn_item_pickup(guaranteed_item, position)
		return

	# Boss special handling
	if enemy_tier == "boss":
		var item_count = table.get("item_count", 1)
		for i in item_count:
			var rarity = _roll_rarity(table.rarity_weights)
			var item_data = _get_random_item_of_rarity(rarity)
			if item_data:
				_spawn_item_pickup(item_data.item_id, position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
		return

	# Normal enemy: roll for drop
	if randf() < table.drop_chance:
		var rarity = _roll_rarity(table.rarity_weights)
		var item_data = _get_random_item_of_rarity(rarity)
		if item_data:
			_spawn_item_pickup(item_data.item_id, position)


## Roll for a rarity tier based on weighted chances
func _roll_rarity(weights: Dictionary) -> ItemData.Rarity:
	var roll = randf()
	var cumulative = 0.0

	# Sort rarities by value for consistent rolling
	var sorted_rarities = weights.keys()
	sorted_rarities.sort()

	for rarity in sorted_rarities:
		cumulative += weights[rarity]
		if roll <= cumulative:
			return rarity

	# Fallback to normal
	return ItemData.Rarity.NORMAL


## Get a random item of a specific rarity
func _get_random_item_of_rarity(rarity: ItemData.Rarity) -> ItemData:
	var items_of_rarity = ItemDatabase.get_items_by_rarity(rarity)

	# Filter out only currency items (we spawn gold separately)
	# Allow consumables and equipment to drop
	var valid_items: Array[ItemData] = []
	for item in items_of_rarity:
		if item.item_type != ItemData.ItemType.CURRENCY:
			valid_items.append(item)

	if valid_items.is_empty():
		print("[LootManager] Warning: No items found for rarity ", rarity)
		return null

	return valid_items[randi() % valid_items.size()]


## Spawn an item pickup in the world
func _spawn_item_pickup(item_id: String, position: Vector2):
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		print("[LootManager] Error: Invalid item_id: ", item_id)
		return

	# Roll affixes based on rarity (Diablo 2 system)
	var rolled_affixes = item_data.roll_affixes()

	# Check if ITEM_PICKUP_SCENE exists
	if ITEM_PICKUP_SCENE == null:
		print("[LootManager] Warning: ItemPickup scene not found, adding to pending loot")
		pending_wave_loot.append({"item_id": item_id, "quantity": 1, "rolled_affixes": rolled_affixes})
		return

	var pickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = item_id
	pickup.rolled_affixes = rolled_affixes
	pickup.global_position = position

	# Add to current scene (deferred to avoid "flushing queries" error)
	var current_scene = get_tree().current_scene
	if current_scene:
		# Use call_deferred to avoid physics/tree state issues
		current_scene.call_deferred("add_child", pickup)
		loot_spawned.emit(item_id, position)
		# print("[LootManager] Spawned item: ", item_data.item_name, " (", item_data.get_rarity_name(), ")")
	else:
		print("[LootManager] Error: No current scene to spawn loot")


## Spawn gold pickup in the world
func _spawn_gold_pickup(amount: int, position: Vector2):
	# Add gold directly to mission gold (temporary, lost after mission ends)
	# This is DIFFERENT from gems (permanent currency)
	if GameStateManager:
		GameStateManager.add_gold(amount)

	# Track for stats/logging
	pending_wave_gold += amount

	gold_spawned.emit(amount, position)
	# print("[LootManager] Enemy dropped %d mission gold (temporary)" % amount)


## REMOVED - Enemy gold now goes directly to mission_gold (not persistent gems)
## Items stay in pending_wave_loot until victory screen
func collect_wave_loot() -> void:
	var items_pending: int = pending_wave_loot.size()
	var gold_collected: int = pending_wave_gold

	# NOTE: Gold is NO LONGER added to persistent gems here!
	# Enemy gold drops are now added to GameStateManager.mission_gold immediately in _spawn_gold_pickup()
	# This function just clears the pending_wave_gold counter
	pending_wave_gold = 0

	# Items remain in pending_wave_loot for victory screen distribution
	if items_pending > 0 or gold_collected > 0:
		pass # print("[LootManager] Wave complete: %d items pending, %d mission gold earned this wave" % [items_pending, gold_collected])


## Add item to pending wave loot (for auto-collect at wave end)
func add_to_pending_loot(item_id: String, quantity: int = 1, rolled_affixes: Dictionary = {}):
	pending_wave_loot.append({"item_id": item_id, "quantity": quantity, "rolled_affixes": rolled_affixes})


## Add gold to pending wave gold
func add_to_pending_gold(amount: int):
	pending_wave_gold += amount


## Get the total pending loot count
func get_pending_loot_count() -> int:
	return pending_wave_loot.size()


## Get the total pending gold
func get_pending_gold() -> int:
	return pending_wave_gold


## Clear all pending loot (for testing or level restart)
func clear_pending_loot():
	pending_wave_loot.clear()
	pending_wave_gold = 0
	print("[LootManager] Cleared all pending loot")


## Roll loot from a chest or container
func roll_chest_loot(chest_tier: String = "tier2") -> Array:
	var loot: Array = []
	var table = loot_tables.get(chest_tier, loot_tables["tier2"])

	# Chests always give gold
	var gold_amount = randi_range(table.gold_range[0], table.gold_range[1])
	loot.append({"type": "gold", "amount": gold_amount})

	# Chests give 2-4 items
	var item_count = randi_range(2, 4)
	for i in item_count:
		var rarity = _roll_rarity(table.rarity_weights)
		var item_data = _get_random_item_of_rarity(rarity)
		if item_data:
			loot.append({"type": "item", "item_id": item_data.item_id, "quantity": 1})

	return loot


## Spawn loot from a chest
func spawn_chest_loot(position: Vector2, chest_tier: String = "tier2"):
	var loot = roll_chest_loot(chest_tier)

	for loot_item in loot:
		if loot_item.type == "gold":
			_spawn_gold_pickup(loot_item.amount, position)
		elif loot_item.type == "item":
			_spawn_item_pickup(loot_item.item_id, position + Vector2(randf_range(-50, 50), randf_range(-50, 50)))


## Get loot table for debugging/inspection
func get_loot_table(tier: String) -> Dictionary:
	return loot_tables.get(tier, {})


## Get all pending loot with full item data (for victory screen)
func get_pending_loot_with_data() -> Array:
	"""Returns array of {item_id, quantity, item_data} for victory screen"""
	var loot_with_data: Array = []

	for loot in pending_wave_loot:
		var item_data = ItemDatabase.get_item(loot.item_id)
		if item_data:
			loot_with_data.append({
				"item_id": loot.item_id,
				"quantity": loot.get("quantity", 1),
				"item_data": item_data
			})

	return loot_with_data


## Distribute pending loot to inventory (called from victory screen)
func distribute_pending_loot_to_inventory(hero_id: String = "") -> Dictionary:
	"""
	Moves all pending loot to hero inventory (if hero_id provided) or shared stash

	🆕 UUID SYSTEM: Now generates unique UUIDs for each item instance

	Args:
		hero_id: If provided, items go to hero's inventory first. If empty, items go to shared stash

	Returns: {items_added: int, items_failed: int}
	"""
	var items_added: int = 0
	var items_failed: int = 0
	var target_inventory: String = "hero inventory" if hero_id != "" else "shared stash"

	for loot_data in pending_wave_loot:
		var uuid: String = ""
		var rolled_affixes: Dictionary = loot_data.get("rolled_affixes", {})

		# Try to add to hero inventory first if hero_id is provided
		if hero_id != "" and HeroInventoryManager:
			# Register hero if not already registered
			HeroInventoryManager.register_hero(hero_id)

			# 🆕 UUID SYSTEM: Generate UUID for item instance
			uuid = HeroInventoryManager.add_item_instance_to_hero(
				hero_id,
				loot_data.item_id,
				0, # upgrade_level (default 0 for new loot)
				rolled_affixes
			)

			if uuid != "":
				print("[LootManager] Added '%s' (UUID: %s) to hero '%s' inventory" % [loot_data.item_id, uuid, hero_id])

		# Fallback to shared stash if no hero_id or hero inventory is full
		if uuid == "" and InventoryManager:
			# 🆕 UUID SYSTEM: Generate UUID for item instance
			uuid = InventoryManager.add_item_instance(
				loot_data.item_id,
				0, # upgrade_level (default 0 for new loot)
				rolled_affixes
			)

			if uuid != "":
				if hero_id != "":
					print("[LootManager] Hero inventory full, added '%s' (UUID: %s) to shared stash" % [loot_data.item_id, uuid])
				else:
					print("[LootManager] Added '%s' (UUID: %s) to shared stash" % [loot_data.item_id, uuid])

		# Track results
		if uuid != "":
			items_added += 1
		else:
			items_failed += 1
			print("[LootManager] Warning: Could not add item to any inventory: ", loot_data.item_id)

	# Clear pending loot after distribution
	pending_wave_loot.clear()

	print("[LootManager] Distributed loot to %s: %d added, %d failed" % [target_inventory, items_added, items_failed])

	return {
		"items_added": items_added,
		"items_failed": items_failed
	}
