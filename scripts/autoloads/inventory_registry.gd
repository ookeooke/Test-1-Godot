extends Node

## InventoryRegistry - Autoload Singleton
## Central directory for all active InventoryContainers.
## Allows looking up any inventory by a unique ID (e.g., "stash", "hero_ranger").

var _containers: Dictionary = {} # ID (String) -> InventoryContainer

## Register a container
func register_container(id: String, container: InventoryContainer):
	if _containers.has(id):
		push_warning("Overwriting existing inventory container: " + id)
	_containers[id] = container
	container.container_id = id
	print("[InventoryRegistry] Registered: " + id)

## Unregister a container
func unregister_container(id: String):
	if _containers.has(id):
		_containers.erase(id)
		print("[InventoryRegistry] Unregistered: " + id)

## Get a container by ID
func get_container(id: String) -> InventoryContainer:
	return _containers.get(id)

## Check if container exists
func has_container(id: String) -> bool:
	return _containers.has(id)

## Get all registered IDs
func get_all_ids() -> Array:
	return _containers.keys()

## Get all registered container IDs (typed version for scalability)
func get_all_container_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _containers.keys():
		ids.append(id)
	return ids
