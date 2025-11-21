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

# Scene Preloads
const ITEM_SLOT_SCENE = preload("res://scenes/ui/item_slot.tscn")

# UI References
@onready var stars_label: Label = $MainPanel/MarginContainer/VBoxContainer/StarsLabel
@onready var hero_portrait: ColorRect = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroPortrait
@onready var hero_name_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroInfo/HeroNameLabel
@onready var hero_dropdown: OptionButton = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroInfo/HeroDropdown
@onready var stash_grid: InventoryGridContainer = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/ScrollContainer/StashGrid
@onready var loot_grid: InventoryGridContainer = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/LootPanel/VBox/ScrollContainer/LootGrid
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
## STATIC GRID CREATION (Diablo 2 / Path of Exile Style)
## ============================================

func _create_static_grid(grid: InventoryGridContainer, container_id: String, width: int = 5, height: int = 8):
	"""Create static ItemSlot grid for spatial positioning

	Creates a grid of empty ItemSlot nodes that serve as:
	1. Visual drop targets for drag-and-drop
	2. Click targets for empty cell interactions
	3. Base layer for grid visualization

	Args:
		grid: The InventoryGridContainer to populate
		container_id: The container ID for this grid (for drag-drop validation)
		width: Number of columns (default 5)
		height: Number of rows (default 8)
	"""
	if not grid:
		push_error("[LootDistScreen] Cannot create grid - grid is null")
		return

	print("[LootDistScreen] Creating %dx%d static grid for container '%s'" % [width, height, container_id])

	# Create all slots with grid coordinates
	for y in height:
		for x in width:
			var slot = ITEM_SLOT_SCENE.instantiate() as ItemSlot
			var i = y * width + x
			slot.slot_index = i
			slot.slot_type = "inventory"
			slot.grid_x = x
			slot.grid_y = y
			# Note: ItemSlot doesn't have container_id property
			# Container is determined dynamically via parent view's hero_id

			# Add to grid (NOT to item_layer - slots are base layer)
			grid.add_child(slot)

	print("[LootDistScreen] ✅ Created %d ItemSlot nodes" % (width * height))


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

	# PHASE 1.5: Create static grid slots (Diablo 2 / Path of Exile style)
	# Must happen AFTER containers are initialized but BEFORE display functions
	if stash_grid and selected_hero_id != "":
		_create_static_grid(stash_grid, selected_hero_id, 5, 8)
		print("[LootDistScreen] Created hero inventory grid for: %s" % selected_hero_id)

	if loot_grid and loot_container:
		_create_static_grid(loot_grid, loot_container.container_id, 5, 8)
		print("[LootDistScreen] Created loot grid for: %s" % loot_container.container_id)

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
	"""Display hero's personal inventory items in left panel

	ARCHITECTURE: Static Grid + Item Overlay (Diablo 2 / Path of Exile style)
	- Static ItemSlot grid remains in place (never cleared)
	- ItemSprites rendered on top as overlay layer (item_layer)
	- Items positioned spatially using grid coordinates, not auto-flow
	"""
	# CRITICAL FIX: Clear item_layer ONLY (synchronous deletion to prevent race conditions)
	# DO NOT clear stash_grid.get_children() - that would delete static ItemSlot grid!
	if stash_grid and stash_grid.item_layer:
		for child in stash_grid.item_layer.get_children():
			child.free()  # Synchronous (Path of Exile / Diablo 2 style)

	# Safety check
	if selected_hero_id == "":
		print("[LootDistScreen] ⚠️ No hero selected - cannot display inventory")
		return

	# Get the container for this hero
	var container = InventoryRegistry.get_container(selected_hero_id)
	if not container:
		print("[LootDistScreen] ❌ No container found for hero: ", selected_hero_id)
		return

	# Get all items (returns Array[ItemInstance])
	var hero_items = container.get_all_items()

	# DEBUG: Log hero inventory details
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 📦 Displaying Hero Inventory (Spatial Grid)")
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
		print("[LootDistScreen] Hero inventory is empty")
		return

	# Display hero's items using spatial positioning
	var displayed_count = 0
	for item_instance in hero_items:
		var uuid = item_instance.uuid
		var item_data = item_instance.get_data()

		# 🔧 FIX HIGH #5: Defensive null check with error logging
		if not item_data:
			push_warning("[LootDistScreen] Skipping hero item with invalid data: UUID %s" % uuid)
			continue

		# Get item's grid position from container
		var pos: Vector2i = container.get_item_position(uuid)
		if pos.x == -1 or pos.y == -1:
			push_warning("[LootDistScreen] Hero item not placed in grid: %s (UUID: %s)" % [item_instance.item_id, uuid])
			continue

		displayed_count += 1

		# Create ItemSprite overlay (renders on top of static grid)
		var item_sprite = ItemSprite.new()
		item_sprite.set_item(item_instance, true)  # skip_animation=true prevents mass bouncing
		item_sprite.hero_id = selected_hero_id  # Set context for drag-drop
		item_sprite.set_grid_position(pos.x, pos.y)  # Spatial positioning

		# Add to item layer (z_index=10, renders on top)
		if stash_grid.item_layer:
			stash_grid.item_layer.add_child(item_sprite)

	print("[LootDistScreen] ✅ Displayed %d/%d hero items" % [displayed_count, hero_items.size()])


func _display_found_loot():
	"""Display loot items in right panel (FOUND LOOT)

	ARCHITECTURE: Static Grid + Item Overlay (Diablo 2 / Path of Exile style)
	- Static ItemSlot grid remains in place (never cleared)
	- ItemSprites rendered on top as overlay layer (item_layer)
	- Items positioned spatially using grid coordinates, not auto-flow
	"""
	# CRITICAL FIX: Clear item_layer ONLY (synchronous deletion to prevent race conditions)
	# DO NOT clear loot_grid.get_children() - that would delete static ItemSlot grid!
	if loot_grid and loot_grid.item_layer:
		for child in loot_grid.item_layer.get_children():
			child.free()  # Synchronous (Path of Exile / Diablo 2 style)

	# PHASE 2: Get items from loot_container instead of loot_items array
	if not loot_container:
		push_warning("[LootDistScreen] loot_container not initialized")
		return

	var loot_item_instances = loot_container.get_all_items()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[LootDistScreen] 📦 Displaying Found Loot (Spatial Grid)")
	print("  Items in container: %d" % loot_item_instances.size())
	if loot_item_instances.size() > 0:
		print("  Item List:")
		for item_instance in loot_item_instances:
			var pos = loot_container.get_item_position(item_instance.uuid)
			print("    - %s (UUID: %s, pos: [%d, %d])" % [item_instance.item_id, item_instance.uuid, pos.x, pos.y])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	if loot_item_instances.is_empty():
		print("[LootDistScreen] No loot items to display")
		return

	# Display loot items using spatial positioning
	var displayed_count = 0
	for item_instance in loot_item_instances:
		var uuid = item_instance.uuid
		var item_data = item_instance.get_data()

		# 🔧 FIX HIGH #5: Defensive null check with error logging
		if not item_data:
			push_warning("[LootDistScreen] Skipping loot item with invalid data: UUID %s" % uuid)
			continue

		# Get item's grid position from container
		var pos: Vector2i = loot_container.get_item_position(uuid)
		if pos.x == -1 or pos.y == -1:
			push_warning("[LootDistScreen] Loot item not placed in grid: %s (UUID: %s)" % [item_instance.item_id, uuid])
			continue

		displayed_count += 1

		# Create ItemSprite overlay (renders on top of static grid)
		var item_sprite = ItemSprite.new()
		item_sprite.set_item(item_instance, true)  # skip_animation=true prevents mass bouncing
		item_sprite.hero_id = loot_container.container_id  # Set context for drag-drop
		item_sprite.set_grid_position(pos.x, pos.y)  # Spatial positioning

		# Add to item layer (z_index=10, renders on top)
		if loot_grid.item_layer:
			loot_grid.item_layer.add_child(item_sprite)

	print("[LootDistScreen] ✅ Displayed %d/%d loot items" % [displayed_count, loot_item_instances.size()])


## ============================================
## LEGACY RENDERING REMOVED (Phase 5 Cleanup)
## ============================================
## Removed 9 functions (~305 lines) that implemented custom pixel art rendering.
## These functions were replaced by ItemSprite system in earlier phases:
## - _create_item_display() - Custom PanelContainer rendering
## - _create_pixel_art_icon() - Procedural pixel art generator
## - _get_item_type() - Item type detection from name
## - _get_pixel_pattern() - 120+ lines of pixel patterns
## - _on_item_hover_enter/_exit/_input() - Legacy drag handlers
## - _start_drag() / _end_drag() - Legacy drag system
##
## The loot screen now uses ItemSprite exclusively (unified with main inventory).
## All item rendering goes through ItemDatabase icons, not procedural pixel art.


func _unhandled_input(event: InputEvent):
	"""End drag even if mouse button released off the panel"""
	if event is InputEventMouseButton and dragged_item:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Legacy drag system - kept for safety but should never trigger
			# (ItemSprite handles all drag-drop now)
			_reset_drag_visuals()
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

	# Save all inventory changes (hero inventories + shared stash)
	if SaveManager:
		SaveManager.mark_dirty()
		print("[LootDistScreen] ✅ Marked save as dirty - changes will persist")

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
