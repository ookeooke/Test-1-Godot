extends Node

## UUIDGenerator - Autoload Singleton
## Generates unique item instance IDs for professional item tracking
## Each item drop gets a UUID to prevent duplication bugs

## Generate a unique UUID for item instances
## Format: "uuid_{timestamp}_{random_hex}"
## Example: "uuid_1732128934567_a3f2b8c1"
func generate() -> String:
	var timestamp = Time.get_ticks_msec()
	var random_value = randi()
	return "uuid_%d_%08x" % [timestamp, random_value]


## Generate multiple UUIDs at once (for batch loot generation)
func generate_batch(count: int) -> Array[String]:
	var uuids: Array[String] = []
	for i in range(count):
		uuids.append(generate())
		# Small delay to ensure unique timestamps
		await get_tree().process_frame
	return uuids


## Validate UUID format
func is_valid_uuid(uuid: String) -> bool:
	return uuid.begins_with("uuid_") and uuid.length() > 10
