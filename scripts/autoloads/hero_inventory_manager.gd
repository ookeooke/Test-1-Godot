extends Node

## HeroInventoryManager - Autoload Singleton (Unified Architecture)
## Manages per-hero inventories using InventoryContainer instances.
## Acts as a factory and coordinator for hero inventories.

signal hero_inventory_changed(hero_id: String)
signal hero_item_instance_added(hero_id: String, uuid: String, item_id: String)
signal hero_item_instance_removed(hero_id: String, uuid: String, item_id: String)
signal hero_inventory_full(hero_id: String, item_id: String)

# Storage: hero_id -> InventoryContainer
var _hero_containers: Dictionary = {}

func _ready():
	print("[HeroInventoryManager] Initialized (Unified Architecture)")

## ============================================
## HERO REGISTRATION
## ============================================

func register_hero(hero_id: String) -> void:
	if _hero_containers.has(hero_id):
		return

	# Create Container (8x8)
	var container = InventoryContainer.new(8, 8, hero_id)
	_hero_containers[hero_id] = container

	# Register with Registry
	InventoryRegistry.register_container(hero_id, container)

	# Connect Signals
	container.content_changed.connect(func(): hero_inventory_changed.emit(hero_id))
	container.item_added.connect(func(uuid, item_id): hero_item_instance_added.emit(hero_id, uuid, item_id))
	container.item_removed.connect(func(uuid, item_id): hero_item_instance_removed.emit(hero_id, uuid, item_id))

	print("[HeroInventoryManager] Registered hero container: ", hero_id)

func unregister_hero(hero_id: String) -> void:
	if _hero_containers.has(hero_id):
		InventoryRegistry.unregister_container(hero_id)
		_hero_containers.erase(hero_id)
		print("[HeroInventoryManager] Unregistered hero: ", hero_id)

func is_hero_registered(hero_id: String) -> bool:
	return _hero_containers.has(hero_id)

func get_container(hero_id: String) -> InventoryContainer:
	return _hero_containers.get(hero_id)

## ============================================
## PUBLIC API (Delegates to Container)
## ============================================

func add_item_instance_to_hero(hero_id: String, item_id: String, upgrade_level: int = 0, rolled_affixes: Dictionary = {}) -> String:
	if not _hero_containers.has(hero_id):
		push_error("Hero not registered: " + hero_id)
		return ""

	var container = _hero_containers[hero_id]
	var item = ItemInstance.new(item_id)
	item.upgrade_level = upgrade_level
	item.rolled_affixes = rolled_affixes

	if container.add_item(item):
		SaveManager.mark_dirty()
		return item.uuid
	else:
		hero_inventory_full.emit(hero_id, item_id)
		return ""

func remove_item_instance_from_hero(hero_id: String, uuid: String) -> bool:
	if not _hero_containers.has(hero_id): return false
	var container = _hero_containers[hero_id]

	var item = container.remove_item(uuid)
	if item:
		SaveManager.mark_dirty()
		return true
	return false

func get_item_instance(hero_id: String, uuid: String) -> ItemInstance:
	if not _hero_containers.has(hero_id): return null
	return _hero_containers[hero_id]._items.get(uuid)

func get_all_items(hero_id: String) -> Array[ItemInstance]:
	if not _hero_containers.has(hero_id): return []
	return _hero_containers[hero_id].get_all_items()

func has_space_for_item(hero_id: String, item_data: ItemData) -> bool:
	if not _hero_containers.has(hero_id): return false
	var dummy = ItemInstance.new(item_data.item_id)
	return _hero_containers[hero_id].find_free_space(dummy) != Vector2i(-1, -1)

## ============================================
## LEGACY SUPPORT
## ============================================

func add_item_to_hero(hero_id: String, item_id: String, quantity: int = 1, upgrade_level: int = 0) -> bool:
	for i in range(quantity):
		if add_item_instance_to_hero(hero_id, item_id, upgrade_level) == "":
			return false
	return true

func get_item_quantity(hero_id: String, item_id: String) -> int:
	if not _hero_containers.has(hero_id): return 0
	var count = 0
	for item in _hero_containers[hero_id].get_all_items():
		if item.item_id == item_id:
			count += 1
	return count

## ============================================
## TRANSFER LOGIC (Using Transaction Service)
## ============================================

func transfer_instance_to_shared_stash(hero_id: String, uuid: String) -> bool:
	return ItemTransactionService.move_item(uuid, hero_id, "stash")

func transfer_to_shared_stash(hero_id: String, item_id: String, quantity: int = 1) -> bool:
	# Find N items and move them
	if not _hero_containers.has(hero_id): return false
	var container = _hero_containers[hero_id]

	var moved = 0
	var items = container.get_all_items()
	for item in items:
		if item.item_id == item_id:
			if ItemTransactionService.move_item(item.uuid, hero_id, "stash"):
				moved += 1
				if moved >= quantity:
					return true
	return moved >= quantity

func transfer_from_shared_stash(hero_id: String, item_id: String, quantity: int = 1) -> bool:
	# Find N items in stash and move to hero
	var stash = InventoryRegistry.get_container("stash")
	if not stash: return false

	var moved = 0
	var items = stash.get_all_items()
	for item in items:
		if item.item_id == item_id:
			if ItemTransactionService.move_item(item.uuid, "stash", hero_id):
				moved += 1
				if moved >= quantity:
					return true
	return moved >= quantity

## ============================================
## SAVE/LOAD
## ============================================

func save_to_dict() -> Dictionary:
	var data = {}
	for hero_id in _hero_containers:
		data[hero_id] = _hero_containers[hero_id].to_dict()
	return data

func load_from_dict(data: Dictionary):
	# Unregister all existing hero containers from Registry first
	for hero_id in _hero_containers:
		InventoryRegistry.unregister_container(hero_id)
		
	_hero_containers.clear()
	for hero_id in data:
		register_hero(hero_id)
		var container_data = data[hero_id]

		if container_data.has("width"):
			# New format
			_hero_containers[hero_id].load_from_dict(container_data)
		else:
			# Old format migration
			_migrate_legacy_hero(hero_id, container_data)

func _migrate_legacy_hero(hero_id: String, data: Dictionary):
	var container = _hero_containers[hero_id]
	var old_items = data.get("item_instances", {})
	if old_items.is_empty():
		old_items = data.get("items", {}) # Even older format

	# Note: old_positions not used - items are auto-placed during migration

	for key in old_items:
		# Handle both UUID keys and ItemID keys
		var item_data_dict = old_items[key]
		var item_id = item_data_dict.get("item_id", "")
		if item_id == "": continue # Skip invalid

		var item = ItemInstance.new(item_id)
		item.upgrade_level = item_data_dict.get("upgrade_level", 0)
		item.rolled_affixes = item_data_dict.get("rolled_affixes", {})

		container.add_item(item) # Auto-place for migration simplicity
