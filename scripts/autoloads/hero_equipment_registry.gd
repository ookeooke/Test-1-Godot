extends Node

## ============================================
## HERO EQUIPMENT REGISTRY - Centralized Equipment State
## ============================================
##
## Single source of truth for ALL hero equipment across all contexts.
## Replaces dual EquipmentManager instances (hero node + UI-created).
##
## Architecture:
## - Singleton autoload (globally accessible)
## - Per-hero equipment storage (supports multiple heroes)
## - Transaction system with rollback
## - Mutex for thread-safety
## - Signal batching with dirty flags
## - Unified save/load integration

# SIGNALS
signal equipment_transaction_completed(hero_id: String, transaction_type: String, details: Dictionary)
signal batch_update_completed(hero_ids: Array[String])

# STORAGE - Per-hero equipment state
var _equipment_registry: Dictionary = {}
# Structure:
# {
#   "ranger_hero_1": {
#     "equipped_items": {"weapon": "bow_01", "armor": "", ...},
#     "dirty": false
#   }
# }

# TRANSACTION CONTROL
var _transaction_mutex: Mutex = Mutex.new()
var _pending_transaction: Dictionary = {}
var _dirty_heroes: Dictionary = {}  # {hero_id: true}

# DEFERRED REFRESH CONTROL
var _refresh_scheduled: bool = false

## ============================================
## INITIALIZATION
## ============================================

func _ready():
	print("[HeroEquipmentRegistry] Initialized")

## ============================================
## HERO REGISTRATION
## ============================================

func register_hero(hero_id: String) -> void:
	"""Register a hero in the equipment registry"""
	if _equipment_registry.has(hero_id):
		print("[HeroEquipmentRegistry] Warning: Hero already registered: ", hero_id)
		return

	_equipment_registry[hero_id] = {
		"equipped_items": {
			"weapon": "",
			"armor": "",
			"helmet": "",
			"accessory_1": "",
			"accessory_2": ""
		},
		"dirty": false
	}

	print("[HeroEquipmentRegistry] Registered hero: ", hero_id)

func unregister_hero(hero_id: String) -> void:
	"""Unregister a hero (cleanup on death/removal)"""
	_equipment_registry.erase(hero_id)
	_dirty_heroes.erase(hero_id)
	print("[HeroEquipmentRegistry] Unregistered hero: ", hero_id)

func is_hero_registered(hero_id: String) -> bool:
	return _equipment_registry.has(hero_id)

## ============================================
## EQUIPMENT QUERIES (Thread-Safe Reads)
## ============================================

func get_equipped_item(hero_id: String, slot: String) -> String:
	"""Get item ID in a specific slot (thread-safe)"""
	if not _equipment_registry.has(hero_id):
		return ""

	return _equipment_registry[hero_id]["equipped_items"].get(slot, "")

func get_all_equipped_items(hero_id: String) -> Dictionary:
	"""Get all equipped items for a hero (thread-safe copy)"""
	if not _equipment_registry.has(hero_id):
		return {}

	# Return copy to prevent external modification
	return _equipment_registry[hero_id]["equipped_items"].duplicate()

func is_slot_empty(hero_id: String, slot: String) -> bool:
	"""Check if equipment slot is empty"""
	return get_equipped_item(hero_id, slot) == ""

## ============================================
## TRANSACTION SYSTEM (Atomic Operations)
## ============================================

func begin_transaction(hero_id: String, transaction_type: String) -> bool:
	"""Start atomic equipment transaction (thread-safe)"""
	_transaction_mutex.lock()

	# Check if transaction already in progress
	if not _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		push_error("[HeroEquipmentRegistry] Transaction already in progress!")
		return false

	# Validate hero
	if not _equipment_registry.has(hero_id):
		_transaction_mutex.unlock()
		push_error("[HeroEquipmentRegistry] Cannot start transaction - hero not registered: ", hero_id)
		return false

	# Create transaction snapshot
	_pending_transaction = {
		"hero_id": hero_id,
		"type": transaction_type,
		"snapshot": _equipment_registry[hero_id]["equipped_items"].duplicate(),
		"changes": []
	}

	_transaction_mutex.unlock()
	return true

func equip_item_in_transaction(slot: String, item_id: String) -> bool:
	"""Equip item within active transaction"""
	_transaction_mutex.lock()

	if _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		push_error("[HeroEquipmentRegistry] No active transaction!")
		return false

	var hero_id = _pending_transaction["hero_id"]
	var old_item = _equipment_registry[hero_id]["equipped_items"][slot]

	# Record change for rollback
	_pending_transaction["changes"].append({
		"slot": slot,
		"old_item": old_item,
		"new_item": item_id
	})

	# Apply change
	_equipment_registry[hero_id]["equipped_items"][slot] = item_id

	_transaction_mutex.unlock()
	return true

func commit_transaction() -> bool:
	"""Commit transaction and emit batched signal"""
	_transaction_mutex.lock()

	if _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		push_error("[HeroEquipmentRegistry] No transaction to commit!")
		return false

	var hero_id = _pending_transaction["hero_id"]
	var transaction_type = _pending_transaction["type"]

	# Mark hero as dirty for deferred refresh
	_dirty_heroes[hero_id] = true
	_equipment_registry[hero_id]["dirty"] = true

	# Clear transaction
	var transaction_details = _pending_transaction.duplicate()
	_pending_transaction.clear()

	_transaction_mutex.unlock()

	# Emit single transaction signal
	equipment_transaction_completed.emit(hero_id, transaction_type, transaction_details)

	# Schedule deferred batch refresh
	_schedule_batch_refresh()

	return true

func rollback_transaction() -> void:
	"""Rollback transaction (restore snapshot)"""
	_transaction_mutex.lock()

	if _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		return

	var hero_id = _pending_transaction["hero_id"]
	var snapshot = _pending_transaction["snapshot"]

	# Restore snapshot
	_equipment_registry[hero_id]["equipped_items"] = snapshot.duplicate()

	# Clear transaction
	_pending_transaction.clear()

	_transaction_mutex.unlock()

	print("[HeroEquipmentRegistry] Transaction rolled back for hero: ", hero_id)

## ============================================
## BATCH REFRESH SYSTEM (Dirty Flags)
## ============================================

func _schedule_batch_refresh() -> void:
	"""Schedule single end-of-frame batch refresh"""
	if _refresh_scheduled:
		return

	_refresh_scheduled = true
	call_deferred("_execute_batch_refresh")

func _execute_batch_refresh() -> void:
	"""Execute batched refresh for all dirty heroes"""
	if _dirty_heroes.is_empty():
		_refresh_scheduled = false
		return

	# Collect dirty hero IDs
	var dirty_hero_ids: Array[String] = []
	for hero_id in _dirty_heroes.keys():
		dirty_hero_ids.append(hero_id)
		_equipment_registry[hero_id]["dirty"] = false

	# Clear dirty flags
	_dirty_heroes.clear()
	_refresh_scheduled = false

	# Emit SINGLE batch signal for ALL dirty heroes
	batch_update_completed.emit(dirty_hero_ids)

	print("[HeroEquipmentRegistry] Batch refresh completed for ", dirty_hero_ids.size(), " heroes")

## ============================================
## SAVE/LOAD INTEGRATION
## ============================================

func save_to_dict() -> Dictionary:
	"""Export all hero equipment to save dictionary"""
	var save_dict = {}

	for hero_id in _equipment_registry.keys():
		save_dict[hero_id] = _equipment_registry[hero_id]["equipped_items"].duplicate()

	return save_dict

func load_from_dict(save_dict: Dictionary) -> void:
	"""Load all hero equipment from save dictionary"""
	for hero_id in save_dict.keys():
		# Register hero if not already registered
		if not _equipment_registry.has(hero_id):
			register_hero(hero_id)

		# Load equipped items
		_equipment_registry[hero_id]["equipped_items"] = save_dict[hero_id].duplicate()
		_equipment_registry[hero_id]["dirty"] = true
		_dirty_heroes[hero_id] = true

	# Schedule refresh for all loaded heroes
	_schedule_batch_refresh()

	print("[HeroEquipmentRegistry] Loaded equipment for ", save_dict.size(), " heroes")
