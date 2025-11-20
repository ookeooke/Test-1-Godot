extends Node

## InventoryManager - Autoload Singleton (Unified Architecture)
## Manages the player's Shared Stash using an InventoryContainer.
## Acts as a high-level coordinator for the Stash.

signal inventory_changed
signal item_instance_added(uuid: String, item_id: String)
signal item_instance_removed(uuid: String, item_id: String)
signal inventory_full(item_id: String)

# Constants (for UI grid creation)
const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 8

# The Stash Container
var _stash: InventoryContainer

func _ready():
	# Create the Stash (10x10 for now, or 8x8 as before)
	_stash = InventoryContainer.new(8, 8, "stash")

	# Connect signals
	_stash.content_changed.connect(_on_stash_changed)
	_stash.item_added.connect(_on_item_added)
	_stash.item_removed.connect(_on_item_removed)

	# Register with Registry
	InventoryRegistry.register_container("stash", _stash)

	print("[InventoryManager] Stash initialized (8x8)")

# Signal Forwarding
func _on_stash_changed():
	inventory_changed.emit()

func _on_item_added(uuid: String, item_id: String):
	item_instance_added.emit(uuid, item_id)

func _on_item_removed(uuid: String, item_id: String):
	item_instance_removed.emit(uuid, item_id)

## ============================================
## PUBLIC API (Delegates to Container)
## ============================================

func add_item_instance(item_id: String, upgrade_level: int = 0, rolled_affixes: Dictionary = {}) -> String:
	var item = ItemInstance.new(item_id)
	item.upgrade_level = upgrade_level
	item.rolled_affixes = rolled_affixes

	if _stash.add_item(item):
		SaveManager.mark_dirty()
		return item.uuid
	else:
		inventory_full.emit(item_id)
		return ""

func remove_item_instance(uuid: String) -> bool:
	var item = _stash.remove_item(uuid)
	if item:
		SaveManager.mark_dirty()
		return true
	return false

func get_item_instance(uuid: String) -> ItemInstance:
	# We need to access the container's items directly or add a getter
	# InventoryContainer stores items in _items
	# Let's add a helper to InventoryContainer or just access it if we can
	# Since _items is technically private but GDScript is permissive...
	# Better: Use the registry or container API.
	# For now, let's assume we can get it from the stash.
	return _stash._items.get(uuid)

func get_all_items() -> Array[ItemInstance]:
	return _stash.get_all_items()

func has_space_for_item(item_data: ItemData) -> bool:
	# Create a dummy instance to check space
	var dummy = ItemInstance.new(item_data.item_id)
	return _stash.find_free_space(dummy) != Vector2i(-1, -1)

## ============================================
## LEGACY SUPPORT (For existing calls)
## ============================================

func add_item(item_id: String, quantity: int = 1, rolled_affixes: Dictionary = {}) -> bool:
	for i in range(quantity):
		if add_item_instance(item_id, 0, rolled_affixes) == "":
			return false
	return true

func get_item_quantity(item_id: String) -> int:
	var count = 0
	for item in _stash.get_all_items():
		if item.item_id == item_id:
			count += 1
	return count

## ============================================
## SAVE/LOAD
## ============================================

func save_to_dict() -> Dictionary:
	return _stash.to_dict()

func load_from_dict(data: Dictionary):
	# Check for migration (old format vs new format)
	if data.has("items") and data.has("width"):
		# New format
		_stash.load_from_dict(data)
	else:
		# Migration from old format
		print("[InventoryManager] Migrating legacy stash data...")
		_migrate_legacy_data(data)

func _migrate_legacy_data(data: Dictionary):
	# Old format: { "item_instances": {...}, "item_positions": {...} } OR { "global_inventory": ... }
	var old_instances = {}
	var old_positions = {}

	if data.has("item_instances"):
		old_instances = data["item_instances"]
		old_positions = data.get("item_positions", {})
	elif data.has("global_inventory"):
		# Very old format
		# ... (Skip complex migration for now, assume intermediate format)
		pass

	_stash._items.clear()
	_stash._init_grid()

	for uuid in old_instances:
		var d = old_instances[uuid]
		var item = ItemInstance.new(d.item_id, uuid)
		item.upgrade_level = d.get("upgrade_level", 0)
		item.rolled_affixes = d.get("rolled_affixes", {})

		_stash._items[uuid] = item

		if old_positions.has(uuid):
			var pos = old_positions[uuid]
			_stash._place_on_grid(item, int(pos.x), int(pos.y))
		else:
			# Auto place
			var new_pos = _stash.find_free_space(item)
			if new_pos != Vector2i(-1, -1):
				_stash._place_on_grid(item, new_pos.x, new_pos.y)

	_stash.content_changed.emit()
