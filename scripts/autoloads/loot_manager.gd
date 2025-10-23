extends Node

## LootManager - Autoload Singleton
## Handles loot generation, drop rates, and spawning loot pickups
## Implements hybrid system: random drops + guaranteed boss loot

signal loot_spawned(item_id: String, position: Vector2)
signal gold_spawned(amount: int, position: Vector2)

const ITEM_PICKUP_SCENE = preload("res://scenes/items/item_pickup.tscn")

# Loot tables per enemy tier
# Based on research: Common 70%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 1%
var loot_tables: Dictionary = {
	"tier1": {
		"drop_chance": 0.15,  # 15% chance to drop item
		"gold_range": [5, 15],
		"rarity_weights": {
			ItemData.Rarity.COMMON: 0.70,
			ItemData.Rarity.UNCOMMON: 0.25,
			ItemData.Rarity.RARE: 0.05,
			ItemData.Rarity.EPIC: 0.0,
			ItemData.Rarity.LEGENDARY: 0.0
		}
	},
	"tier2": {
		"drop_chance": 0.30,  # 30% chance to drop item
		"gold_range": [15, 40],
		"rarity_weights": {
			ItemData.Rarity.COMMON: 0.50,
			ItemData.Rarity.UNCOMMON: 0.30,
			ItemData.Rarity.RARE: 0.15,
			ItemData.Rarity.EPIC: 0.05,
			ItemData.Rarity.LEGENDARY: 0.0
		}
	},
	"tier3": {
		"drop_chance": 0.50,  # 50% chance to drop item
		"gold_range": [40, 80],
		"rarity_weights": {
			ItemData.Rarity.COMMON: 0.40,
			ItemData.Rarity.UNCOMMON: 0.30,
			ItemData.Rarity.RARE: 0.20,
			ItemData.Rarity.EPIC: 0.09,
			ItemData.Rarity.LEGENDARY: 0.01
		}
	},
	"boss": {
		"drop_chance": 1.0,  # 100% guaranteed drop
		"gold_range": [100, 200],
		"item_count": 3,  # Drop 3 items
		"rarity_weights": {
			ItemData.Rarity.COMMON: 0.20,
			ItemData.Rarity.UNCOMMON: 0.30,
			ItemData.Rarity.RARE: 0.30,
			ItemData.Rarity.EPIC: 0.15,
			ItemData.Rarity.LEGENDARY: 0.05
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

	# Fallback to common
	return ItemData.Rarity.COMMON


## Get a random item of a specific rarity
func _get_random_item_of_rarity(rarity: ItemData.Rarity) -> ItemData:
	var items_of_rarity = ItemDatabase.get_items_by_rarity(rarity)

	# Filter out currency items (we spawn gold separately)
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

	# Check if ITEM_PICKUP_SCENE exists
	if ITEM_PICKUP_SCENE == null:
		print("[LootManager] Warning: ItemPickup scene not found, adding to pending loot")
		pending_wave_loot.append({"item_id": item_id, "quantity": 1})
		return

	var pickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = item_id
	pickup.global_position = position

	# Add to current scene (deferred to avoid "flushing queries" error)
	var current_scene = get_tree().current_scene
	if current_scene:
		# Use call_deferred to avoid physics/tree state issues
		current_scene.call_deferred("add_child", pickup)
		loot_spawned.emit(item_id, position)
		print("[LootManager] Spawned item: ", item_data.item_name, " (", item_data.get_rarity_name(), ")")
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
	print("[LootManager] Enemy dropped %d mission gold (temporary)" % amount)


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
		print("[LootManager] Wave complete: %d items pending, %d mission gold earned this wave" % [items_pending, gold_collected])


## Add item to pending wave loot (for auto-collect at wave end)
func add_to_pending_loot(item_id: String, quantity: int = 1):
	pending_wave_loot.append({"item_id": item_id, "quantity": quantity})


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
func distribute_pending_loot_to_inventory() -> Dictionary:
	"""
	Moves all pending loot to InventoryManager
	Returns: {items_added: int, items_failed: int}
	"""
	var items_added: int = 0
	var items_failed: int = 0

	for loot_data in pending_wave_loot:
		if InventoryManager.add_item(loot_data.item_id, loot_data.get("quantity", 1)):
			items_added += 1
		else:
			items_failed += 1
			print("[LootManager] Warning: Could not add item to inventory: ", loot_data.item_id)

	# Clear pending loot after distribution
	pending_wave_loot.clear()

	print("[LootManager] Distributed loot: %d added, %d failed" % [items_added, items_failed])

	return {
		"items_added": items_added,
		"items_failed": items_failed
	}
