extends Area2D
class_name ItemPickup

## ItemPickup - Simplified glow-only visual system
## - Shows only a small colored glow on the ground (no sprite, no labels)
## - Common/Materials: Auto-collect after delay
## - Rare+: Manual click required (with timeout fallback)
## - All items go to LootManager.pending_wave_loot

signal item_collected(item_id: String)

@export var item_id: String = ""

# Collection behavior based on rarity
enum CollectionMode {
	AUTO,      # Auto-collect after delay (Common/Uncommon)
	MANUAL,    # Requires click (Rare+)
	INSTANT    # Instant auto-collect (Gold/Currency)
}

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ground_glow: Sprite2D = $GroundGlow

var item_data: ItemData
var is_collected: bool = false
var collection_mode: CollectionMode = CollectionMode.MANUAL
var auto_collect_timer: Timer = null
var fallback_collect_timer: Timer = null

# Configuration
const AUTO_COLLECT_DELAY: float = 2.0  # Seconds before auto-collecting common items
const FALLBACK_TIMEOUT: float = 15.0   # Seconds before rare items auto-collect anyway


func _ready():
	# Set up click detection
	input_pickable = true
	collision_layer = 0
	collision_mask = 0

	# Load item data
	if item_id != "":
		load_item_data()

	# Connect input signals
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	print("[ItemPickup] Ready at ", global_position, " | Item: ", item_id, " | Mode: ", CollectionMode.keys()[collection_mode])


func load_item_data():
	item_data = ItemDatabase.get_item(item_id)

	if item_data == null:
		push_error("[ItemPickup] Invalid item_id: " + item_id)
		queue_free()
		return

	# Set up ground glow with rarity color
	if ground_glow:
		ground_glow.modulate = item_data.get_rarity_color()
		# Small, subtle glow - scale slightly based on rarity
		var glow_scale = 0.6 + (item_data.rarity * 0.1)  # 0.6 to 1.0
		ground_glow.scale = Vector2(glow_scale, glow_scale)

	# Determine collection mode based on rarity
	_setup_collection_mode()

	# Add pulsing glow effect
	_add_glow_effect()


func _setup_collection_mode():
	"""Determine how this item should be collected based on rarity"""
	match item_data.rarity:
		ItemData.Rarity.COMMON:
			collection_mode = CollectionMode.AUTO
			_start_auto_collect_timer(AUTO_COLLECT_DELAY)
			print("[ItemPickup] Common item - auto-collecting in ", AUTO_COLLECT_DELAY, "s")

		ItemData.Rarity.UNCOMMON:
			collection_mode = CollectionMode.AUTO
			_start_auto_collect_timer(AUTO_COLLECT_DELAY)
			print("[ItemPickup] Uncommon item - auto-collecting in ", AUTO_COLLECT_DELAY, "s")

		ItemData.Rarity.RARE, ItemData.Rarity.EPIC, ItemData.Rarity.LEGENDARY:
			collection_mode = CollectionMode.MANUAL
			_start_fallback_timer(FALLBACK_TIMEOUT)
			print("[ItemPickup] ", item_data.get_rarity_name(), " item - manual click required (", FALLBACK_TIMEOUT, "s timeout)")


func _start_auto_collect_timer(delay: float):
	"""Start timer for automatic collection"""
	auto_collect_timer = Timer.new()
	auto_collect_timer.wait_time = delay
	auto_collect_timer.one_shot = true
	auto_collect_timer.timeout.connect(_on_auto_collect_timeout)
	add_child(auto_collect_timer)
	auto_collect_timer.start()


func _start_fallback_timer(timeout: float):
	"""Start fallback timer for rare items (auto-collect if not clicked)"""
	fallback_collect_timer = Timer.new()
	fallback_collect_timer.wait_time = timeout
	fallback_collect_timer.one_shot = true
	fallback_collect_timer.timeout.connect(_on_fallback_timeout)
	add_child(fallback_collect_timer)
	fallback_collect_timer.start()


func _on_auto_collect_timeout():
	"""Auto-collect common/uncommon items after delay"""
	if not is_collected:
		print("[ItemPickup] Auto-collecting: ", item_data.item_name)
		collect_item(true)  # true = auto-collected


func _on_fallback_timeout():
	"""Fallback auto-collect for rare items that weren't clicked"""
	if not is_collected:
		print("[ItemPickup] Fallback timeout - auto-collecting rare item: ", item_data.item_name)
		collect_item(true)  # Auto-collect with timeout


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	"""Handle click/tap events - supports both mouse and touch"""
	# Support both mouse and touch input
	var is_interact = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_interact = true
	elif event is InputEventScreenTouch and event.pressed:
		is_interact = true

	if is_interact:
		if not is_collected:
			print("[ItemPickup] Clicked/Tapped! Collecting: ", item_data.item_name)
			collect_item(false)  # false = manually clicked/tapped
			get_viewport().set_input_as_handled()


func _on_mouse_entered():
	"""Visual feedback on hover - brighten glow"""
	if not is_collected and ground_glow:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(ground_glow, "scale", ground_glow.scale * 1.3, 0.2)
		tween.tween_property(ground_glow, "modulate:a", 0.9, 0.2)


func _on_mouse_exited():
	"""Reset visual feedback"""
	if not is_collected and ground_glow and item_data:
		var original_scale = 0.6 + (item_data.rarity * 0.1)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ground_glow, "scale", Vector2(original_scale, original_scale), 0.2)
		tween.tween_property(ground_glow, "modulate:a", 0.6, 0.2)


func collect_item(was_auto: bool = false):
	"""
	Collect the item - adds to LootManager pending loot (not directly to inventory)
	Items will be distributed at victory screen
	"""
	if is_collected:
		return

	is_collected = true

	# Stop timers
	if auto_collect_timer:
		auto_collect_timer.stop()
	if fallback_collect_timer:
		fallback_collect_timer.stop()

	# Add to pending wave loot (NEW: goes to LootManager instead of direct inventory)
	LootManager.add_to_pending_loot(item_id, 1)

	# Emit signal
	item_collected.emit(item_id)

	# Visual/audio feedback
	var collection_type = "manually" if not was_auto else "automatically"
	print("[ItemPickup] Collected ", collection_type, ": ", item_data.item_name)

	# Show click feedback effect
	if has_node("/root/ClickFeedback"):
		ClickFeedback.play_click_feedback(global_position)

	# Play collection animation
	_play_collect_animation()


func _play_collect_animation():
	"""Animate item collection - fade out glow"""
	var tween = create_tween()
	tween.set_parallel(true)

	if ground_glow:
		tween.tween_property(ground_glow, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(ground_glow, "scale", ground_glow.scale * 1.5, 0.3).set_ease(Tween.EASE_OUT)

	await tween.finished
	queue_free()


func _add_glow_effect():
	"""Add subtle pulsing glow effect"""
	if ground_glow:
		var glow_tween = create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(ground_glow, "modulate:a", 0.7, 1.0).set_ease(Tween.EASE_IN_OUT)
		glow_tween.tween_property(ground_glow, "modulate:a", 0.4, 1.0).set_ease(Tween.EASE_IN_OUT)


## Public API for external control

func force_collect():
	"""Force immediate collection (called by wave end cleanup)"""
	if not is_collected:
		print("[ItemPickup] Force collecting: ", item_data.item_name)
		collect_item(true)


func get_item_data() -> ItemData:
	"""Return the item data for this pickup"""
	return item_data


func is_auto_collect() -> bool:
	"""Check if this item will auto-collect"""
	return collection_mode == CollectionMode.AUTO
