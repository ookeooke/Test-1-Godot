extends Node

## ============================================
## HERO EQUIPMENT REGISTRY - Centralized Equipment State (Unified System)
## ============================================
##
## Single source of truth for ALL hero equipment.
## NOW STORES FULL ItemInstance OBJECTS (not just UUIDs).
## This ensures item data (affixes, upgrades) is preserved when equipped.
##

# SIGNALS
signal equipment_transaction_completed(hero_id: String, transaction_type: String, details: Dictionary)
signal batch_update_completed(hero_ids: Array[String])

# STORAGE - Per-hero equipment state
# {
#   "ranger": {
#     "equipped_items": {
#       "hand_left": ItemInstance_Object, 
#       "hand_right": "__2H_OCCUPIED__", # String marker
#       "armor": null # Empty
#     },
#     "dirty": false
#   }
# }
var _equipment_registry: Dictionary = {}

# TRANSACTION CONTROL
var _transaction_mutex: Mutex = Mutex.new()
var _pending_transaction: Dictionary = {}
var _dirty_heroes: Dictionary = {}

# DEFERRED REFRESH CONTROL
var _refresh_scheduled: bool = false

## ============================================
## INITIALIZATION
## ============================================

func _ready():
	pass

## ============================================
## HERO REGISTRATION
## ============================================

func register_hero(hero_id: String) -> void:
	if _equipment_registry.has(hero_id):
		return

	_equipment_registry[hero_id] = {
		"equipped_items": {
			"hand_left": null,
			"hand_right": null,
			"armor": null,
			"helmet": null,
			"accessory_1": null,
			"accessory_2": null
		},
		"dirty": false
	}
	print("[HeroEquipmentRegistry] Registered hero: ", hero_id)

func unregister_hero(hero_id: String) -> void:
	_equipment_registry.erase(hero_id)
	_dirty_heroes.erase(hero_id)

func is_hero_registered(hero_id: String) -> bool:
	return _equipment_registry.has(hero_id)

## ============================================
## EQUIPMENT QUERIES (Thread-Safe Reads)
## ============================================

## Get the ItemInstance in a slot (or null)
func get_equipped_item(hero_id: String, slot: String) -> ItemInstance:
	if not _equipment_registry.has(hero_id):
		return null
	
	var item = _equipment_registry[hero_id]["equipped_items"].get(slot)
	if item is ItemInstance:
		return item
	return null # Returns null for empty OR "__2H_OCCUPIED__"

## Get the raw value in a slot (ItemInstance, String, or null)
func get_slot_content(hero_id: String, slot: String):
	if not _equipment_registry.has(hero_id):
		return null
	return _equipment_registry[hero_id]["equipped_items"].get(slot)

## Get all equipped items as a Dictionary {slot: ItemInstance}
func get_all_equipped_items(hero_id: String) -> Dictionary:
	if not _equipment_registry.has(hero_id):
		return {}
		
	var result = {}
	var items = _equipment_registry[hero_id]["equipped_items"]
	for slot in items:
		if items[slot] is ItemInstance:
			result[slot] = items[slot]
	return result

func is_slot_empty(hero_id: String, slot: String) -> bool:
	var content = get_slot_content(hero_id, slot)
	return content == null

## ============================================
## TRANSACTION SYSTEM
## ============================================

func begin_transaction(hero_id: String, transaction_type: String) -> bool:
	_transaction_mutex.lock()
	
	if not _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		push_error("[HeroEquipmentRegistry] Transaction already in progress!")
		return false
		
	if not _equipment_registry.has(hero_id):
		_transaction_mutex.unlock()
		return false
		
	_pending_transaction = {
		"hero_id": hero_id,
		"type": transaction_type,
		"snapshot": _equipment_registry[hero_id]["equipped_items"].duplicate(),
		"changes": []
	}
	
	_transaction_mutex.unlock()
	return true

## Equip an ItemInstance (or set marker/null)
func equip_item_in_transaction(slot: String, item) -> bool:
	_transaction_mutex.lock()
	
	if _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		return false
		
	var hero_id = _pending_transaction["hero_id"]
	var old_content = _equipment_registry[hero_id]["equipped_items"][slot]
	
	# Validate input
	if item != null and not (item is ItemInstance) and not (item is String):
		_transaction_mutex.unlock()
		push_error("Invalid equipment item type")
		return false

	_pending_transaction["changes"].append({
		"slot": slot,
		"old_item": old_content,
		"new_item": item
	})
	
	_equipment_registry[hero_id]["equipped_items"][slot] = item
	
	_transaction_mutex.unlock()
	return true

func commit_transaction() -> bool:
	_transaction_mutex.lock()
	
	if _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		return false
		
	var hero_id = _pending_transaction["hero_id"]
	var transaction_type = _pending_transaction["type"]
	var details = _pending_transaction.duplicate()
	
	_dirty_heroes[hero_id] = true
	_equipment_registry[hero_id]["dirty"] = true
	_pending_transaction.clear()
	
	_transaction_mutex.unlock()
	
	equipment_transaction_completed.emit(hero_id, transaction_type, details)
	_schedule_batch_refresh()
	return true

func rollback_transaction() -> void:
	_transaction_mutex.lock()
	
	if _pending_transaction.is_empty():
		_transaction_mutex.unlock()
		return
		
	var hero_id = _pending_transaction["hero_id"]
	var snapshot = _pending_transaction["snapshot"]
	
	_equipment_registry[hero_id]["equipped_items"] = snapshot.duplicate()
	_pending_transaction.clear()
	
	_transaction_mutex.unlock()
	print("[HeroEquipmentRegistry] Transaction rolled back for hero: ", hero_id)

## ============================================
## PUBLIC API
## ============================================

## Equip an item directly (wraps in transaction)
func equip_item(hero_id: String, slot: String, item: ItemInstance) -> bool:
	if not begin_transaction(hero_id, "simple_equip"): return false
	
	if not equip_item_in_transaction(slot, item):
		rollback_transaction()
		return false
		
	if not commit_transaction():
		rollback_transaction()
		return false
		
	return true

## Clear a slot (unequip)
func clear_slot(hero_id: String, slot: String) -> bool:
	if not begin_transaction(hero_id, "clear_slot"): return false
	
	if not equip_item_in_transaction(slot, null):
		rollback_transaction()
		return false
		
	if not commit_transaction():
		rollback_transaction()
		return false
		
	return true

## ============================================
## BATCH REFRESH SYSTEM
## ============================================

func _schedule_batch_refresh() -> void:
	_transaction_mutex.lock()
	if _refresh_scheduled:
		_transaction_mutex.unlock()
		return
	_refresh_scheduled = true
	_transaction_mutex.unlock()
	call_deferred("_execute_batch_refresh")

func _execute_batch_refresh() -> void:
	_transaction_mutex.lock()
	if _dirty_heroes.is_empty():
		_refresh_scheduled = false
		_transaction_mutex.unlock()
		return
		
	var dirty_ids = _dirty_heroes.keys()
	for id in dirty_ids:
		_equipment_registry[id]["dirty"] = false
	_dirty_heroes.clear()
	_refresh_scheduled = false
	_transaction_mutex.unlock()
	
	batch_update_completed.emit(dirty_ids)

## ============================================
## SAVE/LOAD INTEGRATION
## ============================================

func save_to_dict() -> Dictionary:
	var save_dict = {}
	for hero_id in _equipment_registry:
		var equipped = _equipment_registry[hero_id]["equipped_items"]
		var serialized_equipped = {}
		
		for slot in equipped:
			var content = equipped[slot]
			if content is ItemInstance:
				serialized_equipped[slot] = content.to_dict()
			elif content is String:
				serialized_equipped[slot] = content # "__2H_OCCUPIED__"
			else:
				serialized_equipped[slot] = null
				
		save_dict[hero_id] = serialized_equipped
	return save_dict

func load_from_dict(save_dict: Dictionary) -> void:
	for hero_id in save_dict:
		if not _equipment_registry.has(hero_id):
			register_hero(hero_id)
			
		var saved_equipped = save_dict[hero_id]
		var loaded_equipped = {}
		
		for slot in saved_equipped:
			var data = saved_equipped[slot]
			if data is Dictionary:
				# It's an ItemInstance
				loaded_equipped[slot] = ItemInstance.from_dict(data)
			else:
				# It's a String (marker) or null
				loaded_equipped[slot] = data
				
		_equipment_registry[hero_id]["equipped_items"] = loaded_equipped
		_equipment_registry[hero_id]["dirty"] = true
		_dirty_heroes[hero_id] = true
		
	_schedule_batch_refresh()
