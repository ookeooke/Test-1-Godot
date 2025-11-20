extends Control

## Loot Distribution Screen - Battle Brothers Style
## Two-panel layout: Hero Inventory (left) + Found Loot (right)
## Drag items from Found Loot to Hero Inventory
## NOW SUPPORTS: Per-hero inventories + multi-hero selection!
##
## REFACTORED (Phase 1-5):
## - Backend: Uses InventoryContainer + ItemTransactionService (was manual arrays)
## - Drag-Drop: Uses ItemTransactionService with Smart Nudge + Atomic Swap (was custom)
## - Buttons: Use ItemTransactionService for Take All/Rare (was HeroInventoryManager)
## - Benefits: Auto-rollback, Smart Nudge, Atomic Swap, consistent with main inventory system
## - Code Reduction: ~250 lines of duplicate code eliminated

signal continue_to_victory

# UI References
@onready var stars_label: Label = $MainPanel/MarginContainer/VBoxContainer/StarsLabel
@onready var hero_portrait: ColorRect = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroPortrait
@onready var hero_name_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroInfo/HeroNameLabel
@onready var hero_dropdown: OptionButton = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroInfo/HeroDropdown
@onready var stash_grid: GridContainer = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/ScrollContainer/StashGrid
@onready var loot_grid: GridContainer = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/LootPanel/VBox/ScrollContainer/LootGrid
@onready var capacity_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/Header/CapacityLabel
@onready var loot_count_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/LootPanel/VBox/Header/CountLabel
@onready var take_all_button: Button = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/MiddleButtons/TakeAllButton
@onready var take_rare_button: Button = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/MiddleButtons/TakeRareButton
@onready var leave_button: Button = $MainPanel/MarginContainer/VBoxContainer/ButtonsHBox/LeaveButton

# Data
var loot_items: Array = []  # LEGACY: Items in Found Loot panel (being replaced with loot_container)
var loot_container: InventoryContainer  # NEW: Temporary loot container backend
var hero_container: InventoryContainer  # NEW: Reference to selected hero's inventory container
var stars_earned: int = 3
var gems_earned: int = 0  # Gems earned from star bonus

# Hero data (passed from WaveManager)
var participating_heroes: Array = []  # [{hero_id, hero_name, hero_class}]
var selected_hero_id: String = ""  # Currently selected hero's ID
var selected_hero_info: Dictionary = {}  # Full hero data

# Drag state
var dragged_item: Control = null
var drag_preview: Control = null
var drag_start_parent: Control = null

# 🔧 FIX HIGH #6: Mutex lock for button operations
var _is_processing_buttons: bool = false


func _reset_drag_visuals():
	"""CRITICAL: Reset all drag visual states to normal.

	This function MUST be called BEFORE any code path that might free/recreate
	panels (e.g., _display_stash(), _display_found_loot()).

	WHY: When panels are freed via queue_free() while still having modified
	modulation/scale, the visual state can leak into newly created panels,
	causing inconsistent colors/sizes across the UI.

	Visual states reset:
	- dragged_item.modulation: Reset from dimmed (0.3 alpha) to normal (WHITE)
	- dragged_item.scale: Reset from hover scale (1.05x) to normal (1.0x)
	- drag_preview: Freed to prevent memory leak
	"""
	if dragged_item:
		dragged_item.modulate = Color.WHITE  # Reset from dimmed drag state
		dragged_item.scale = Vector2(1.0, 1.0)  # Reset from potential hover scale

	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null


func _clear_drag_state():
	"""Clear drag state references after visual cleanup.

	IMPORTANT: Always call _reset_drag_visuals() BEFORE this function.
	Visual cleanup must happen before clearing references to ensure
	proper cleanup even if panels are freed during processing.
	"""
	dragged_item = null
	drag_start_parent = null


func _show_error_message(message: String):
	"""🔧 FIX HIGH #1: Show error feedback to user"""
	# Create floating error label
	var error_label = Label.new()
	error_label.text = message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 18)
	error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red
	error_label.position = Vector2(size.x / 2 - 150, size.y / 2 - 50)
	error_label.size = Vector2(300, 50)
	error_label.z_index = 200  # Above everything
	add_child(error_label)

	# Animate fade-out and remove
	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	tween.tween_callback(error_label.queue_free)

	print("[LootDistScreen] ⚠️ Error shown to user: %s" % message)


## ============================================
## GODOT NATIVE DRAG-DROP (Phase 2)
## ============================================

func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Check if we can accept a drop from ItemSprite

	Accepts drops if:
	1. Data is from ItemSprite (has 'uuid' key)
	2. Item is from loot container (not already in hero inventory)
	3. Mouse is over the stash grid (left panel)
	"""
	if not data is Dictionary:
		return false

	if not data.has("uuid") or not data.has("source_hero_id"):
		return false

	# Only accept drops FROM loot TO hero inventory
	var source_container_id = data.get("source_hero_id", "")
	if source_container_id != loot_container.container_id:
		return false  # Not from loot, ignore

	# Check if mouse is over stash panel (hero inventory)
	var stash_panel = stash_grid.get_parent().get_parent()  # ScrollContainer -> VBox
	var is_over_stash = _is_point_over_control(at_position, stash_panel)

	return is_over_stash


func _drop_data(at_position: Vector2, data) -> void:
	"""Handle drop from ItemSprite - move item to hero inventory"""
	if not _can_drop_data(at_position, data):
		return

	var uuid = data.get("uuid", "")
	if uuid == "":
		push_error("[LootDistScreen] Drop failed - no UUID in drag data")
		return

	print("[LootDistScreen] 🎯 Dropped item UUID: %s at position: %v" % [uuid, at_position])

	# Move item to hero using existing logic
	_move_item_to_hero(uuid)


func _ready():
	# Connect buttons
	take_all_button.pressed.connect(_on_take_all_pressed)
	take_rare_button.pressed.connect(_on_take_rare_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	hero_dropdown.item_selected.connect(_on_hero_selected)

	# Load heroes and select first one
	_load_heroes()

	# PHASE 1: Initialize inventory containers
	_initialize_containers()

	# Load and display loot
	_load_loot_data()
	_display_stash()
	_display_found_loot()
	_update_counters()
	_update_stars_display()

	# Animate entrance
	_animate_entrance()

	# AI AUTO-SKIP: If AI is active, automatically take all loot and leave
	_check_ai_auto_skip()


func _load_heroes():
	"""Load available heroes into dropdown from participating_heroes data"""
	hero_dropdown.clear()

	if participating_heroes.is_empty():
		# No heroes provided - error state
		hero_dropdown.add_item("No Hero", 0)
		hero_name_label.text = "No Hero"
		hero_portrait.color = Color(0.3, 0.3, 0.3)
		print("[LootDistScreen] ERROR: No participating heroes provided!")
		return

	# Populate dropdown with participating heroes
	for i in range(participating_heroes.size()):
		var hero_info = participating_heroes[i]
		hero_dropdown.add_item(hero_info.hero_name, i)

	# Select first hero
	selected_hero_info = participating_heroes[0]
	selected_hero_id = selected_hero_info.hero_id
	hero_dropdown.select(0)

	# 🔧 FIX HIGH #4: Validate hero registration
	if not HeroInventoryManager.is_hero_registered(selected_hero_id):
		HeroInventoryManager.register_hero(selected_hero_id)
		print("[LootDistScreen] Registered new hero in inventory system: ", selected_hero_id)

		# Validate registration succeeded
		if not HeroInventoryManager.is_hero_registered(selected_hero_id):
			push_error("[LootDistScreen] CRITICAL: Hero registration failed: " + selected_hero_id)
			_show_error_message("Failed to register hero: " + selected_hero_id)
			return

	_update_hero_display()
	print("[LootDistScreen] Loaded %d heroes, selected: %s" % [participating_heroes.size(), selected_hero_id])


func _on_hero_selected(index: int):
	"""When user selects a different hero from dropdown"""
	# 🔧 FIX HIGH #2: Cancel active drag when hero switches to prevent corruption
	if dragged_item:
		print("[LootDistScreen] ⚠️ Hero switch detected during drag - canceling drag")
		_reset_drag_visuals()
		_clear_drag_state()

	if index < participating_heroes.size():
		selected_hero_info = participating_heroes[index]
		selected_hero_id = selected_hero_info.hero_id

		# 🔧 FIX HIGH #4: Validate hero registration
		if not HeroInventoryManager.is_hero_registered(selected_hero_id):
			HeroInventoryManager.register_hero(selected_hero_id)
			print("[LootDistScreen] Registered new hero in inventory system: ", selected_hero_id)

			# Validate registration succeeded
			if not HeroInventoryManager.is_hero_registered(selected_hero_id):
				push_error("[LootDistScreen] CRITICAL: Hero registration failed: " + selected_hero_id)
				_show_error_message("Failed to register hero: " + selected_hero_id)
				return

		# PHASE 1: Update hero_container reference when hero changes
		hero_container = InventoryRegistry.get_container(selected_hero_id)
		if not hero_container:
			push_error("[LootDistScreen] CRITICAL: Hero container not found after registration: " + selected_hero_id)
			_show_error_message("Hero inventory not available!")
			return

		_update_hero_display()
		_display_stash()  # Refresh inventory display
		_update_counters()
		print("[LootDistScreen] Switched to hero: %s (%s)" % [selected_hero_info.hero_name, selected_hero_id])


func _update_hero_display():
	"""Update hero portrait and name"""
	if selected_hero_info.is_empty():
		return

	hero_name_label.text = selected_hero_info.hero_name

	# Set portrait color based on hero class
	var hero_class = selected_hero_info.get("hero_class", "warrior")
	match hero_class:
		"warrior":
			hero_portrait.color = Color(0.8, 0.2, 0.2)  # Red
		"ranger":
			hero_portrait.color = Color(0.2, 0.8, 0.2)  # Green
		"mage":
			hero_portrait.color = Color(0.2, 0.2, 0.8)  # Blue
		_:
			hero_portrait.color = Color(0.5, 0.5, 0.5)  # Gray


func _initialize_containers():
	"""PHASE 1: Initialize inventory containers for loot and hero"""
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 🔧 PHASE 1: Initializing Containers")

	# Create temporary loot container (10x10 grid for large drops)
	var container_id = "temp_loot_" + str(Time.get_ticks_msec())
	loot_container = InventoryContainer.new(10, 10, container_id)
	InventoryRegistry.register_container(container_id, loot_container)
	print("  ✅ Created loot container: %s (10x10)" % container_id)

	# Get hero container reference (will be updated when hero changes)
	if selected_hero_id != "":
		hero_container = InventoryRegistry.get_container(selected_hero_id)
		if hero_container:
			print("  ✅ Hero container found: %s" % selected_hero_id)
		else:
			push_warning("Hero container not found: " + selected_hero_id)

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


func _load_loot_data():
	"""PHASE 5: Load all pending loot from LootManager directly into loot_container"""
	if not loot_container:
		push_error("[LootDistScreen] Cannot load loot - container not initialized!")
		return

	# Get loot data from LootManager
	var loot_data = LootManager.get_pending_loot_with_data()
	print("[LootDistScreen] Loading %d loot items for distribution..." % loot_data.size())

	# Keep loot_items for backward compatibility (used by legacy code)
	loot_items = loot_data

	# Populate loot_container
	_populate_loot_container(loot_data)

	# 🔧 FIX CRITICAL #2: Clear pending_wave_loot immediately after loading
	# loot_container is now the SINGLE SOURCE OF TRUTH (no dual-state)
	LootManager.pending_wave_loot.clear()
	print("[LootDistScreen] ✅ Cleared pending_wave_loot - loot_container is now single source of truth")


func _populate_loot_container(loot_data: Array):
	"""PHASE 5: Convert loot_data array into ItemInstances in loot_container"""
	print("[LootDistScreen] 📦 Populating loot container...")

	var invalid_count = 0  # 🔧 FIX HIGH #3: Track invalid items

	for loot in loot_data:
		var item_id = loot.item_id
		var item_data = loot.get("item_data", null)
		var quantity = loot.get("quantity", 1)

		# Create ItemInstances (one per quantity)
		for i in range(quantity):
			# Get item data from database if not provided
			if not item_data:
				item_data = ItemDatabase.get_item(item_id)

			if not item_data:
				push_warning("[LootDistScreen] Loot item not found in database: " + item_id)
				invalid_count += 1  # 🔧 FIX HIGH #3: Count invalid items
				continue

			# Create ItemInstance (UUID auto-generated)
			var item_instance = ItemInstance.new(item_id)

			# Add to loot container (auto-placement)
			if not loot_container.add_item(item_instance):
				push_error("[LootDistScreen] Loot container full! Cannot add: " + item_id)
				break  # Stop adding more of this item

	var item_count = loot_container.get_item_count()
	print("[LootDistScreen] ✅ Populated loot container with %d item instances" % item_count)

	# 🔧 FIX HIGH #3: Warn user if invalid items were removed
	if invalid_count > 0:
		var warning = "%d invalid items removed (not in database)" % invalid_count
		_show_error_message(warning)
		push_error("[LootDistScreen] " + warning)


func _display_stash():
	"""Display hero's personal inventory items in left panel"""
	# Clear existing items (reset modulation first for defensive programming)
	for child in stash_grid.get_children():
		if child is PanelContainer:
			child.modulate = Color.WHITE  # Safety reset before freeing
		child.queue_free()

	# Safety check
	if selected_hero_id == "":
		var error_label = Label.new()
		error_label.text = "No Hero Selected"
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.add_theme_font_size_override("font_size", 16)
		error_label.modulate = Color(1.0, 0.3, 0.3)
		stash_grid.add_child(error_label)
		return

	# Get items from hero's personal inventory (HeroInventoryManager)
	# Returns Array of {item_id, item_data, quantity, upgrade_level}
	# Get the container for this hero
	var container = InventoryRegistry.get_container(selected_hero_id)
	if not container:
		print("[LootDistScreen] ❌ No container found for hero: ", selected_hero_id)
		return

	# Get all items (returns Array[ItemInstance])
	var hero_items = container.get_all_items()

	# DEBUG: Log hero inventory details
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 📦 Displaying Hero Inventory")
	print("  Hero ID: '%s' (type: %s)" % [selected_hero_id, typeof(selected_hero_id)])
	print("  Hero Name: '%s'" % selected_hero_info.get("hero_name", "Unknown"))
	print("  Items Found: %d" % hero_items.size())
	if hero_items.size() > 0:
		print("  Item List:")
		for item_instance in hero_items:
			var pos = container.get_item_position(item_instance.uuid)
			print("    - %s (UUID: %s, pos: [%d, %d])" % [item_instance.item_id, item_instance.uuid, pos.x, pos.y])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	if hero_items.is_empty():
		# Show empty message
		var empty_label = Label.new()
		empty_label.text = "Empty"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		stash_grid.add_child(empty_label)
		return

	# Display hero's items
	for item_instance in hero_items:
		var item_data = item_instance.get_data()

		# 🔧 FIX HIGH #5: Defensive null check with error logging
		if item_data:
			# PHASE 1 REFACTOR: Use ItemSprite instead of custom rendering
			var item_sprite = ItemSprite.new()
			item_sprite.set_item(item_instance)
			item_sprite.hero_id = selected_hero_id  # Set context for drag-drop
			stash_grid.add_child(item_sprite)
		else:
			push_warning("[LootDistScreen] Skipping hero item with invalid data: UUID %s" % item_instance.uuid)


func _display_found_loot():
	"""Display loot items in right panel (FOUND LOOT) - PHASE 2: Using loot_container"""
	# Clear existing items (reset modulation first for defensive programming)
	for child in loot_grid.get_children():
		if child is PanelContainer:
			child.modulate = Color.WHITE  # Safety reset before freeing
		child.queue_free()

	# PHASE 2: Get items from loot_container instead of loot_items array
	if not loot_container:
		push_warning("[LootDistScreen] loot_container not initialized")
		return

	var loot_item_instances = loot_container.get_all_items()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 📦 Displaying Found Loot")
	print("  Items in container: %d" % loot_item_instances.size())
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# Create draggable item slots for each loot item instance
	for item_instance in loot_item_instances:
		var item_data = item_instance.get_data()

		# 🔧 FIX HIGH #5: Defensive null check with error logging
		if item_data:
			# PHASE 1 REFACTOR: Use ItemSprite instead of custom rendering
			var item_sprite = ItemSprite.new()
			item_sprite.set_item(item_instance)
			item_sprite.hero_id = loot_container.container_id  # Set context for drag-drop
			loot_grid.add_child(item_sprite)
		else:
			push_warning("[LootDistScreen] Skipping loot item with invalid data: UUID %s" % item_instance.uuid)

	# Show empty message if no loot
	if loot_item_instances.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items found"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.modulate = Color(0.5, 0.5, 0.5)
		loot_grid.add_child(empty_label)


func _create_item_display(item_data: ItemData, quantity: int, item_id: String, draggable: bool) -> PanelContainer:
	"""Create item display panel with pixel art icon"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(80, 100)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if draggable else Control.MOUSE_FILTER_IGNORE

	# Store metadata
	panel.set_meta("item_id", item_id)
	panel.set_meta("item_data", item_data)
	panel.set_meta("quantity", quantity)
	panel.set_meta("draggable", draggable)

	# Visual container
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	# Icon background with rarity color
	var icon_bg = ColorRect.new()
	icon_bg.custom_minimum_size = Vector2(60, 60)
	icon_bg.color = item_data.get_rarity_color().darkened(0.3)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_bg)

	# Draw pixel art icon on top
	var icon_drawing = _create_pixel_art_icon(item_data)
	icon_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.add_child(icon_drawing)

	# Name label
	var name_label = Label.new()
	var display_name = item_data.item_name
	if display_name.length() > 10:
		display_name = display_name.substr(0, 7) + "..."
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.modulate = item_data.get_rarity_color()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Quantity label
	if quantity > 1:
		var qty_label = Label.new()
		qty_label.text = "x%d" % quantity
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty_label.add_theme_font_size_override("font_size", 10)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(qty_label)

	# Add drag handlers if draggable
	if draggable:
		panel.mouse_entered.connect(func(): _on_item_hover_enter(panel))
		panel.mouse_exited.connect(func(): _on_item_hover_exit(panel))
		panel.gui_input.connect(func(event): _on_item_input(event, panel))

	return panel


func _create_pixel_art_icon(item_data: ItemData) -> Control:
	"""Create simple pixel art icon based on item type"""
	var canvas = Control.new()
	canvas.custom_minimum_size = Vector2(60, 60)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Determine item type from metadata or name
	var item_type = _get_item_type(item_data)
	var pixels = _get_pixel_pattern(item_type)

	# Draw pixels
	for pixel_data in pixels:
		var px = pixel_data[0]  # x position
		var py = pixel_data[1]  # y position
		var color = pixel_data[2]  # color

		var pixel_rect = ColorRect.new()
		pixel_rect.custom_minimum_size = Vector2(3, 3)
		pixel_rect.position = Vector2(px * 3 + 10, py * 3 + 5)
		pixel_rect.size = Vector2(3, 3)
		pixel_rect.color = color
		pixel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(pixel_rect)

	return canvas


func _get_item_type(item_data: ItemData) -> String:
	"""Determine item type from name or category"""
	var name_lower = item_data.item_name.to_lower()

	if "sword" in name_lower or "blade" in name_lower:
		return "sword"
	elif "bow" in name_lower or "crossbow" in name_lower:
		return "bow"
	elif "potion" in name_lower or "elixir" in name_lower:
		return "potion"
	elif "armor" in name_lower or "chest" in name_lower:
		return "armor"
	elif "shield" in name_lower:
		return "shield"
	elif "scale" in name_lower or "ore" in name_lower or "wood" in name_lower:
		return "material"
	else:
		return "generic"


func _get_pixel_pattern(item_type: String) -> Array:
	"""Return pixel pattern for item type [x, y, color]"""
	match item_type:
		"sword":
			return [
				# Blade (gray)
				[5, 0, Color(0.8, 0.8, 0.9)], [6, 1, Color(0.8, 0.8, 0.9)],
				[7, 2, Color(0.8, 0.8, 0.9)], [8, 3, Color(0.8, 0.8, 0.9)],
				[9, 4, Color(0.8, 0.8, 0.9)], [10, 5, Color(0.8, 0.8, 0.9)],
				# Guard (gold)
				[7, 6, Color(0.9, 0.7, 0.2)], [8, 6, Color(0.9, 0.7, 0.2)],
				[9, 6, Color(0.9, 0.7, 0.2)], [10, 6, Color(0.9, 0.7, 0.2)],
				# Handle (brown)
				[8, 7, Color(0.6, 0.4, 0.2)], [8, 8, Color(0.6, 0.4, 0.2)],
				[8, 9, Color(0.6, 0.4, 0.2)]
			]
		"bow":
			return [
				# Bow arc (brown)
				[2, 2, Color(0.6, 0.4, 0.2)], [2, 3, Color(0.6, 0.4, 0.2)],
				[2, 4, Color(0.6, 0.4, 0.2)], [2, 5, Color(0.6, 0.4, 0.2)],
				[2, 6, Color(0.6, 0.4, 0.2)], [2, 7, Color(0.6, 0.4, 0.2)],
				[2, 8, Color(0.6, 0.4, 0.2)],
				[10, 3, Color(0.6, 0.4, 0.2)], [10, 4, Color(0.6, 0.4, 0.2)],
				[10, 5, Color(0.6, 0.4, 0.2)], [10, 6, Color(0.6, 0.4, 0.2)],
				[10, 7, Color(0.6, 0.4, 0.2)],
				# String (white)
				[9, 3, Color(0.9, 0.9, 0.9)], [9, 4, Color(0.9, 0.9, 0.9)],
				[9, 5, Color(0.9, 0.9, 0.9)], [9, 6, Color(0.9, 0.9, 0.9)],
				[9, 7, Color(0.9, 0.9, 0.9)]
			]
		"potion":
			return [
				# Cork (brown)
				[7, 1, Color(0.5, 0.3, 0.2)], [8, 1, Color(0.5, 0.3, 0.2)],
				# Bottle outline (gray)
				[6, 2, Color(0.7, 0.7, 0.8)], [7, 2, Color(0.7, 0.7, 0.8)],
				[8, 2, Color(0.7, 0.7, 0.8)], [9, 2, Color(0.7, 0.7, 0.8)],
				[5, 3, Color(0.7, 0.7, 0.8)], [10, 3, Color(0.7, 0.7, 0.8)],
				[5, 4, Color(0.7, 0.7, 0.8)], [10, 4, Color(0.7, 0.7, 0.8)],
				[5, 5, Color(0.7, 0.7, 0.8)], [10, 5, Color(0.7, 0.7, 0.8)],
				[5, 6, Color(0.7, 0.7, 0.8)], [10, 6, Color(0.7, 0.7, 0.8)],
				[5, 7, Color(0.7, 0.7, 0.8)], [10, 7, Color(0.7, 0.7, 0.8)],
				[5, 8, Color(0.7, 0.7, 0.8)], [10, 8, Color(0.7, 0.7, 0.8)],
				[6, 9, Color(0.7, 0.7, 0.8)], [7, 9, Color(0.7, 0.7, 0.8)],
				[8, 9, Color(0.7, 0.7, 0.8)], [9, 9, Color(0.7, 0.7, 0.8)],
				# Liquid (red)
				[6, 5, Color(0.9, 0.2, 0.2)], [7, 5, Color(0.9, 0.2, 0.2)],
				[8, 5, Color(0.9, 0.2, 0.2)], [9, 5, Color(0.9, 0.2, 0.2)],
				[6, 6, Color(0.9, 0.2, 0.2)], [7, 6, Color(0.9, 0.2, 0.2)],
				[8, 6, Color(0.9, 0.2, 0.2)], [9, 6, Color(0.9, 0.2, 0.2)],
				[6, 7, Color(0.9, 0.2, 0.2)], [7, 7, Color(0.9, 0.2, 0.2)],
				[8, 7, Color(0.9, 0.2, 0.2)], [9, 7, Color(0.9, 0.2, 0.2)],
				[6, 8, Color(0.9, 0.2, 0.2)], [7, 8, Color(0.9, 0.2, 0.2)],
				[8, 8, Color(0.9, 0.2, 0.2)], [9, 8, Color(0.9, 0.2, 0.2)]
			]
		"armor":
			return [
				# Chest plate (steel)
				[5, 3, Color(0.6, 0.6, 0.7)], [6, 3, Color(0.6, 0.6, 0.7)],
				[7, 3, Color(0.6, 0.6, 0.7)], [8, 3, Color(0.6, 0.6, 0.7)],
				[9, 3, Color(0.6, 0.6, 0.7)], [10, 3, Color(0.6, 0.6, 0.7)],
				[5, 4, Color(0.6, 0.6, 0.7)], [6, 4, Color(0.8, 0.8, 0.9)],
				[7, 4, Color(0.8, 0.8, 0.9)], [8, 4, Color(0.6, 0.6, 0.7)],
				[9, 4, Color(0.6, 0.6, 0.7)], [10, 4, Color(0.6, 0.6, 0.7)],
				[5, 5, Color(0.6, 0.6, 0.7)], [6, 5, Color(0.6, 0.6, 0.7)],
				[7, 5, Color(0.6, 0.6, 0.7)], [8, 5, Color(0.6, 0.6, 0.7)],
				[9, 5, Color(0.6, 0.6, 0.7)], [10, 5, Color(0.6, 0.6, 0.7)],
				[6, 6, Color(0.6, 0.6, 0.7)], [7, 6, Color(0.6, 0.6, 0.7)],
				[8, 6, Color(0.6, 0.6, 0.7)], [9, 6, Color(0.6, 0.6, 0.7)],
				[6, 7, Color(0.6, 0.6, 0.7)], [7, 7, Color(0.6, 0.6, 0.7)],
				[8, 7, Color(0.6, 0.6, 0.7)], [9, 7, Color(0.6, 0.6, 0.7)]
			]
		"shield":
			return [
				# Shield body (blue)
				[6, 2, Color(0.3, 0.4, 0.7)], [7, 2, Color(0.3, 0.4, 0.7)],
				[8, 2, Color(0.3, 0.4, 0.7)], [9, 2, Color(0.3, 0.4, 0.7)],
				[5, 3, Color(0.3, 0.4, 0.7)], [6, 3, Color(0.3, 0.4, 0.7)],
				[7, 3, Color(0.3, 0.4, 0.7)], [8, 3, Color(0.3, 0.4, 0.7)],
				[9, 3, Color(0.3, 0.4, 0.7)], [10, 3, Color(0.3, 0.4, 0.7)],
				[5, 4, Color(0.3, 0.4, 0.7)], [6, 4, Color(0.3, 0.4, 0.7)],
				[7, 4, Color(0.3, 0.4, 0.7)], [8, 4, Color(0.3, 0.4, 0.7)],
				[9, 4, Color(0.3, 0.4, 0.7)], [10, 4, Color(0.3, 0.4, 0.7)],
				[5, 5, Color(0.3, 0.4, 0.7)], [6, 5, Color(0.3, 0.4, 0.7)],
				[7, 5, Color(0.3, 0.4, 0.7)], [8, 5, Color(0.3, 0.4, 0.7)],
				[9, 5, Color(0.3, 0.4, 0.7)], [10, 5, Color(0.3, 0.4, 0.7)],
				[6, 6, Color(0.3, 0.4, 0.7)], [7, 6, Color(0.3, 0.4, 0.7)],
				[8, 6, Color(0.3, 0.4, 0.7)], [9, 6, Color(0.3, 0.4, 0.7)],
				[6, 7, Color(0.3, 0.4, 0.7)], [7, 7, Color(0.3, 0.4, 0.7)],
				[8, 7, Color(0.3, 0.4, 0.7)], [9, 7, Color(0.3, 0.4, 0.7)],
				[7, 8, Color(0.3, 0.4, 0.7)], [8, 8, Color(0.3, 0.4, 0.7)],
				# Boss (silver center)
				[7, 4, Color(0.8, 0.8, 0.9)], [8, 4, Color(0.8, 0.8, 0.9)],
				[7, 5, Color(0.8, 0.8, 0.9)], [8, 5, Color(0.8, 0.8, 0.9)]
			]
		"material":
			return [
				# Ore/crystal (yellow/orange)
				[7, 2, Color(0.8, 0.6, 0.2)],
				[6, 3, Color(0.8, 0.6, 0.2)], [7, 3, Color(1.0, 0.8, 0.4)],
				[8, 3, Color(0.8, 0.6, 0.2)],
				[5, 4, Color(0.8, 0.6, 0.2)], [6, 4, Color(0.8, 0.6, 0.2)],
				[7, 4, Color(0.8, 0.6, 0.2)], [8, 4, Color(0.8, 0.6, 0.2)],
				[9, 4, Color(0.8, 0.6, 0.2)],
				[5, 5, Color(0.8, 0.6, 0.2)], [6, 5, Color(0.8, 0.6, 0.2)],
				[7, 5, Color(0.8, 0.6, 0.2)], [8, 5, Color(0.8, 0.6, 0.2)],
				[9, 5, Color(0.8, 0.6, 0.2)],
				[6, 6, Color(0.8, 0.6, 0.2)], [7, 6, Color(0.8, 0.6, 0.2)],
				[8, 6, Color(0.8, 0.6, 0.2)],
				[7, 7, Color(0.8, 0.6, 0.2)]
			]
		_:  # generic/default
			return [
				# Simple box
				[6, 4, Color(0.7, 0.7, 0.7)], [7, 4, Color(0.7, 0.7, 0.7)],
				[8, 4, Color(0.7, 0.7, 0.7)], [9, 4, Color(0.7, 0.7, 0.7)],
				[6, 5, Color(0.7, 0.7, 0.7)], [9, 5, Color(0.7, 0.7, 0.7)],
				[6, 6, Color(0.7, 0.7, 0.7)], [9, 6, Color(0.7, 0.7, 0.7)],
				[6, 7, Color(0.7, 0.7, 0.7)], [7, 7, Color(0.7, 0.7, 0.7)],
				[8, 7, Color(0.7, 0.7, 0.7)], [9, 7, Color(0.7, 0.7, 0.7)]
			]


func _on_item_hover_enter(panel: PanelContainer):
	"""Visual feedback on hover"""
	if dragged_item == null:
		panel.modulate = Color(1.2, 1.2, 1.2)


func _on_item_hover_exit(panel: PanelContainer):
	"""Reset hover effect"""
	# CRITICAL FIX: Always reset modulation on hover exit (removed conditional)
	# Prevents brightening state from persisting if drag starts during hover
	# The _start_drag() function will set the correct dimmed state anyway
	panel.modulate = Color.WHITE


func _on_item_input(event: InputEvent, panel: PanelContainer):
	"""Handle drag start"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_start_drag(panel)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_end_drag()


func _unhandled_input(event: InputEvent):
	"""End drag even if mouse button released off the panel"""
	if event is InputEventMouseButton and dragged_item:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_end_drag()


func _start_drag(panel: PanelContainer):
	"""Start dragging an item"""
	dragged_item = panel
	drag_start_parent = panel.get_parent()

	# Create drag preview
	drag_preview = panel.duplicate()
	drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.7)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 100
	add_child(drag_preview)

	# Hide original
	panel.modulate = Color(1.0, 1.0, 1.0, 0.3)

	print("[LootDistScreen] Dragging: ", panel.get_meta("item_data").item_name)


func _end_drag():
	"""End drag and check for valid drop - PHASE 3: Using ItemTransactionService"""
	if dragged_item == null:
		return

	# PHASE 3: Get UUID from metadata (added in Phase 2)
	var uuid = dragged_item.get_meta("uuid", "")
	if uuid == "":
		push_error("[LootDistScreen] Drag failed - no UUID in item metadata!")
		_reset_drag_visuals()
		_clear_drag_state()
		return

	# Check if mouse is over stash panel
	var mouse_pos = get_global_mouse_position()
	var is_over_stash = _is_point_over_control(mouse_pos, stash_grid.get_parent().get_parent())

	# CRITICAL: Reset visuals BEFORE processing drop
	# This prevents visual state leaks when panels are freed/recreated
	_reset_drag_visuals()

	if is_over_stash:
		_move_item_to_hero(uuid)

	# Clear state references
	_clear_drag_state()


func _move_item_to_hero(uuid: String):
	"""PHASE 3: Move item from loot to hero using ItemTransactionService"""
	# Safety check
	if selected_hero_id == "":
		push_error("[LootDistScreen] No hero selected!")
		return

	if not loot_container or not hero_container:
		push_error("[LootDistScreen] Containers not initialized!")
		return

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 🔄 Moving item to hero")
	print("  UUID: %s" % uuid)
	print("  Hero: %s" % selected_hero_id)

	# Use ItemTransactionService to move item (with Smart Nudge, Atomic Swap, etc.)
	var success = ItemTransactionService.move_item(
		uuid,
		loot_container.container_id,  # source: loot
		selected_hero_id,              # target: hero inventory
		-1, -1                         # auto-placement
	)

	if success:
		print("[LootDistScreen] ✅ Item moved successfully!")

		# 🔧 FIX CRITICAL #2: Removed dual-state cleanup loop
		# pending_wave_loot is already cleared at load time (single source of truth)

		# Refresh displays
		_display_stash()
		_display_found_loot()
		_update_counters()
	else:
		print("[LootDistScreen] ❌ Move failed - inventory full or placement blocked")
		# Item automatically rolled back by ItemTransactionService

		# 🔧 FIX HIGH #1: Show error feedback to user
		_show_error_message("Inventory Full!")

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


func _on_take_all_pressed():
	"""PHASE 4: Take all items from loot using ItemTransactionService"""
	# 🔧 FIX HIGH #6: Prevent button spam with mutex lock
	if _is_processing_buttons:
		print("[LootDistScreen] ⚠️ Button spam detected - ignoring click")
		return

	_is_processing_buttons = true
	print("[LootDistScreen] Taking all items...")

	if not loot_container or not hero_container:
		push_error("[LootDistScreen] Containers not initialized!")
		_is_processing_buttons = false
		return

	# Get all items from loot container
	var all_loot = loot_container.get_all_items()
	var success_count = 0
	var failed_count = 0

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 🎁 Taking All Items (%d total)" % all_loot.size())

	for item in all_loot:
		var moved = ItemTransactionService.move_item(
			item.uuid,
			loot_container.container_id,  # source
			selected_hero_id,              # target
			-1, -1                         # auto-placement
		)

		if moved:
			success_count += 1
			# 🔧 FIX CRITICAL #2: Removed dual-state cleanup loop
		else:
			failed_count += 1

	print("[LootDistScreen] ✅ Took %d items, %d failed (inventory full?)" % [success_count, failed_count])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# 🔧 FIX HIGH #1: Show error feedback if some items failed
	if failed_count > 0:
		_show_error_message("%d items failed - Inventory Full!" % failed_count)

	# Refresh displays
	_display_stash()
	_display_found_loot()
	_update_counters()

	# 🔧 FIX HIGH #6: Release mutex lock
	_is_processing_buttons = false

	# Auto-close if all items taken
	if loot_container.get_item_count() == 0:
		print("[LootDistScreen] 🎉 All loot collected!")
		await get_tree().create_timer(0.5).timeout
		_on_leave_pressed()


func _on_take_rare_pressed():
	"""PHASE 4: Take only Rare+ items using ItemTransactionService"""
	# 🔧 FIX HIGH #6: Prevent button spam with mutex lock
	if _is_processing_buttons:
		print("[LootDistScreen] ⚠️ Button spam detected - ignoring click")
		return

	_is_processing_buttons = true
	print("[LootDistScreen] Taking Rare+ items...")

	if not loot_container or not hero_container:
		push_error("[LootDistScreen] Containers not initialized!")
		_is_processing_buttons = false
		return

	# Get all items and filter for Rare+
	var all_loot = loot_container.get_all_items()
	var success_count = 0
	var failed_count = 0
	var rare_threshold = ItemData.Rarity.RARE

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 💎 Taking Rare+ Items")

	for item in all_loot:
		var item_data = item.get_data()

		# 🔧 FIX HIGH #5: Defensive null check
		if not item_data:
			push_warning("[LootDistScreen] Skipping item with invalid data: UUID %s" % item.uuid)
			continue

		# Only take Rare or higher
		if item_data.rarity >= rare_threshold:
			var moved = ItemTransactionService.move_item(
				item.uuid,
				loot_container.container_id,
				selected_hero_id,
				-1, -1  # auto-place
			)

			if moved:
				success_count += 1
				# 🔧 FIX CRITICAL #2: Removed dual-state cleanup loop
			else:
				failed_count += 1

	print("[LootDistScreen] ✅ Took %d Rare+ items, %d failed" % [success_count, failed_count])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# 🔧 FIX HIGH #1: Show error feedback if some items failed
	if failed_count > 0:
		_show_error_message("%d Rare+ items failed - Inventory Full!" % failed_count)

	# Refresh displays
	_display_stash()
	_display_found_loot()
	_update_counters()

	# 🔧 FIX HIGH #6: Release mutex lock
	_is_processing_buttons = false

	# Auto-close if all loot taken
	if loot_container.get_item_count() == 0:
		print("[LootDistScreen] 🎉 All loot collected!")
		await get_tree().create_timer(0.5).timeout
		_on_leave_pressed()


func _process(_delta):
	"""Update drag preview position"""
	if drag_preview and dragged_item:
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2


func _is_point_over_control(point: Vector2, control: Control) -> bool:
	"""Check if point is inside control"""
	var rect = Rect2(control.global_position, control.size)
	return rect.has_point(point)


func _update_counters():
	"""Update capacity and loot count labels - PHASE 2: Using containers"""
	# Get hero's inventory count
	var item_count = 0
	if hero_container:
		item_count = hero_container.get_item_count()
	elif selected_hero_id != "":
		# Fallback to legacy method
		var hero_items = HeroInventoryManager.get_all_items(selected_hero_id)
		item_count = hero_items.size()

	var max_capacity = 64  # 8x8 grid = 64 slots max
	capacity_label.text = "%d/%d" % [item_count, max_capacity]

	# PHASE 2: Get loot count from container
	var loot_count = loot_container.get_item_count() if loot_container else loot_items.size()
	loot_count_label.text = "%d items" % loot_count


func _update_stars_display():
	"""Update star rating and gems earned"""
	if stars_label:
		var star_text = ""
		for i in range(3):
			star_text += "★" if i < stars_earned else "☆"

		# Show stars AND gems earned
		if gems_earned > 0:
			stars_label.text = "%s (%d Stars) | 💎 +%d Gems" % [star_text, stars_earned, gems_earned]
		else:
			stars_label.text = "%s (%d Stars)" % [star_text, stars_earned]

		stars_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))


func _animate_entrance():
	"""Animate screen entrance"""
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_leave_pressed():
	"""Leave loot screen - 🔧 FIX CRITICAL #3: Auto-save remaining loot"""
	var remaining_items = loot_container.get_item_count() if loot_container else loot_items.size()

	# 🔧 FIX CRITICAL #3: Auto-transfer remaining loot to shared stash (prevent loot loss)
	if loot_container and remaining_items > 0:
		print("[LootDistScreen] ⚠️ WARNING: %d items remaining! Auto-transferring to shared stash..." % remaining_items)

		var stash = InventoryRegistry.get_container("stash")
		if stash:
			var saved_count = 0
			var lost_count = 0

			# Get all remaining items and transfer to stash
			var remaining = loot_container.get_all_items()
			for item in remaining:
				var moved = ItemTransactionService.move_item(
					item.uuid,
					loot_container.container_id,
					"stash",
					-1, -1  # auto-placement
				)
				if moved:
					saved_count += 1
				else:
					lost_count += 1
					push_warning("[LootDistScreen] Failed to save item to stash: " + item.item_id)

			print("[LootDistScreen] ✅ Auto-saved %d items to stash, %d lost (stash full?)" % [saved_count, lost_count])

			if lost_count > 0:
				push_error("[LootDistScreen] LOOT LOSS: %d items could not be saved!" % lost_count)
		else:
			push_error("[LootDistScreen] CRITICAL: Stash not found! Cannot save %d remaining items!" % remaining_items)
	else:
		print("[LootDistScreen] Leaving with 0 items remaining - all loot collected!")

	# PHASE 1: Cleanup - unregister temporary loot container
	if loot_container:
		InventoryRegistry.unregister_container(loot_container.container_id)
		print("[LootDistScreen] ✅ Unregistered loot container: %s" % loot_container.container_id)
		loot_container = null

	# No need to clear pending_wave_loot - already cleared at load time (single source of truth)
	continue_to_victory.emit()
	_transition_out()


func _transition_out():
	"""Animate transition out"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func _check_ai_auto_skip():
	"""Check if AI is active and automatically skip loot screen"""
	# Wait for scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame

	# Check if AIController exists in the scene tree
	var ai_controller = get_tree().get_first_node_in_group("ai_controller")

	if ai_controller:
		print("[LootDistScreen] AI detected - auto-skipping loot screen...")

		# Wait a brief moment so the screen is visible (for debugging)
		await get_tree().create_timer(0.5).timeout

		# Take all items automatically
		_on_take_all_pressed()

		# Wait for items to be processed
		await get_tree().process_frame

		# Leave automatically
		_on_leave_pressed()

		print("[LootDistScreen] AI auto-skip complete")
