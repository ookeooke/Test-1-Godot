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
@onready var hero_portrait: ColorRect = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroPortrait
@onready var hero_name_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroInfo/HeroNameLabel
@onready var hero_dropdown: OptionButton = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroSelector/HeroInfo/HeroDropdown
@onready var hero_inventory_view: InventoryView = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/StashPanel/VBox/HeroInventoryView
@onready var loot_inventory_view: InventoryView = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/LootPanel/VBox/LootInventoryView
@onready var take_all_button: Button = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/MiddleButtons/TakeAllButton
@onready var take_rare_button: Button = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/MiddleButtons/TakeRareButton
@onready var leave_button: Button = $MainPanel/MarginContainer/VBoxContainer/ButtonsHBox/LeaveButton

# Data
var loot_container: InventoryContainer # Temporary loot container backend
var hero_container: InventoryContainer # NEW: Reference to selected hero's inventory container
var gems_earned: int = 0 # Gems earned from star bonus (awarded but not displayed here)

# Hero data (passed from WaveManager)
var participating_heroes: Array = [] # [{hero_id, hero_name, hero_class}]
var selected_hero_id: String = "" # Currently selected hero's ID
var selected_hero_info: Dictionary = {} # Full hero data

# Drag state
var dragged_item: Control = null
var drag_preview: Control = null
var drag_start_parent: Control = null

# 🔧 FIX HIGH #6: Mutex lock for button operations
var _is_processing_buttons: bool = false

# 🔧 FIX: Expose hero_id for ItemSlot compatibility
var hero_id: String:
	get: return selected_hero_id

# 🔧 FIX: Expose _refresh_inventory for ItemSlot compatibility
func _refresh_inventory():
	_display_stash()


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
		dragged_item.modulate = Color.WHITE # Reset from dimmed drag state
		dragged_item.scale = Vector2(1.0, 1.0) # Reset from potential hover scale

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
	error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Red
	error_label.position = Vector2(size.x / 2 - 150, size.y / 2 - 50)
	error_label.size = Vector2(300, 50)
	error_label.z_index = 200 # Above everything
	add_child(error_label)

	# Animate fade-out and remove
	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	tween.tween_callback(error_label.queue_free)

	print("[LootDistScreen] ⚠️ Error shown to user: %s" % message)


## ============================================
## INITIALIZATION
## ============================================

func _ready():
	"""Initialize loot distribution screen on load"""
	# Load heroes and select first one
	_load_heroes()

	# PHASE 1: Initialize inventory containers
	_initialize_containers()

	# PHASE 1.5: Create static grid slots (Diablo 2 / Path of Exile style)
	# Must happen AFTER containers are initialized but BEFORE display functions
	# PHASE 1.5: Create static grid slots (Diablo 2 / Path of Exile style)
	# Must happen AFTER containers are initialized but BEFORE display functions
	if hero_inventory_view and selected_hero_id != "":
		hero_inventory_view.set_hero_id(selected_hero_id)
		print("[LootDistScreen] Initialized HeroInventoryView for: %s" % selected_hero_id)

	if loot_inventory_view and loot_container:
		loot_inventory_view.set_loot_container(loot_container.container_id)
		print("[LootDistScreen] Initialized LootInventoryView for: %s" % loot_container.container_id)

	# Load and display loot
	_load_loot_data()
	_display_stash()
	_display_found_loot()
	_update_counters()

	# Animate entrance
	_animate_entrance()

	# Connect signals
	hero_dropdown.item_selected.connect(_on_hero_selected)
	take_all_button.pressed.connect(_on_take_all_pressed)
	take_rare_button.pressed.connect(_on_take_rare_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

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
		_update_hero_display()
		
		# Update InventoryView
		if hero_inventory_view:
			hero_inventory_view.set_hero_id(selected_hero_id)
			
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
			hero_portrait.color = Color(0.8, 0.2, 0.2) # Red
		"ranger":
			hero_portrait.color = Color(0.2, 0.8, 0.2) # Green
		"mage":
			hero_portrait.color = Color(0.2, 0.2, 0.8) # Blue
		_:
			hero_portrait.color = Color(0.5, 0.5, 0.5) # Gray


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

	# Populate loot_container
	_populate_loot_container(loot_data)

	# 🔧 FIX CRITICAL #2: Clear pending_wave_loot immediately after loading
	# loot_container is now the SINGLE SOURCE OF TRUTH (no dual-state)
	LootManager.pending_wave_loot.clear()
	print("[LootDistScreen] ✅ Cleared pending_wave_loot - loot_container is now single source of truth")


func _populate_loot_container(loot_data: Array):
	"""PHASE 5: Convert loot_data array into ItemInstances in loot_container"""
	print("[LootDistScreen] 📦 Populating loot container...")

	var invalid_count = 0 # 🔧 FIX HIGH #3: Track invalid items

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
				invalid_count += 1 # 🔧 FIX HIGH #3: Count invalid items
				continue

			# Create ItemInstance (UUID auto-generated)
			var item_instance = ItemInstance.new(item_id)

			# Add to loot container (auto-placement)
			if not loot_container.add_item(item_instance):
				push_error("[LootDistScreen] Loot container full! Cannot add: " + item_id)
				break # Stop adding more of this item

	var item_count = loot_container.get_item_count()
	print("[LootDistScreen] ✅ Populated loot container with %d item instances" % item_count)

	# 🔧 FIX HIGH #3: Warn user if invalid items were removed
	if invalid_count > 0:
		var warning = "%d invalid items removed (not in database)" % invalid_count
		_show_error_message(warning)
		push_error("[LootDistScreen] " + warning)


func _display_stash():
	"""DEPRECATED: Handled by HeroInventoryView"""
	if hero_inventory_view:
		hero_inventory_view.refresh_view()


func _display_found_loot():
	"""DEPRECATED: Handled by LootInventoryView"""
	if loot_inventory_view:
		loot_inventory_view.refresh_view()


func _process(_delta):
	"""Update drag preview position"""
	if drag_preview and dragged_item:
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2


func _is_point_over_control(point: Vector2, control: Control) -> bool:
	"""Check if point is inside control"""
	var rect = Rect2(control.global_position, control.size)
	return rect.has_point(point)


func _update_counters():
	"""Update capacity and loot count labels - Handled by views"""
	pass


func _animate_entrance():
	"""Animate screen entrance"""
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_take_all_pressed():
	"""Take all items from loot to currently selected hero's inventory"""
	if _is_processing_buttons:
		return

	if not loot_container or not hero_container:
		push_warning("[LootDistScreen] Cannot take all - containers not initialized")
		return

	if loot_container.get_item_count() == 0:
		print("[LootDistScreen] No items to take")
		return

	_is_processing_buttons = true
	print("[LootDistScreen] Taking all %d items to hero: %s" % [loot_container.get_item_count(), selected_hero_id])

	var items_to_take = loot_container.get_all_items()
	var taken_count = 0
	var failed_count = 0

	for item in items_to_take:
		# Try to move to hero inventory using ItemTransactionService
		var moved = ItemTransactionService.move_item(
			item.uuid,
			loot_container.container_id,
			hero_container.container_id,
			-1, -1 # auto-placement
		)
		if moved:
			taken_count += 1
		else:
			failed_count += 1

	print("[LootDistScreen] ✅ Took %d items, %d failed (hero inventory full?)" % [taken_count, failed_count])

	# Refresh displays
	_update_counters()
	
	# Release lock after a short delay to prevent accidental double-clicks
	await get_tree().create_timer(0.2).timeout
	_is_processing_buttons = false


func _on_take_rare_pressed():
	"""Take only Rare/Set/Unique items from loot to hero's inventory"""
	if not loot_container or not hero_container:
		push_warning("[LootDistScreen] Cannot take rare - containers not initialized")
		return

	if loot_container.get_item_count() == 0:
		print("[LootDistScreen] No items to take")
		return

	print("[LootDistScreen] Taking rare+ items to hero: %s" % selected_hero_id)

	var items_to_check = loot_container.get_all_items()
	var taken_count = 0
	var failed_count = 0
	var filtered_count = 0

	for item in items_to_check:
		var item_data = item.get_data()

		# Filter: Only take Rare, Set, or Unique items
		if item_data.rarity >= ItemData.Rarity.RARE:
			# Try to move to hero inventory using ItemTransactionService
			var moved = ItemTransactionService.move_item(
				item.uuid,
				loot_container.container_id,
				hero_container.container_id,
				-1, -1 # auto-placement
			)
			if moved:
				taken_count += 1
			else:
				failed_count += 1
		else:
			filtered_count += 1

	print("[LootDistScreen] ✅ Took %d rare+ items, %d failed, %d filtered (common/magic)" % [taken_count, failed_count, filtered_count])

	# Refresh displays
	_update_counters()


func _on_leave_pressed():
	"""Leave loot screen - Auto-save remaining loot"""
	print("[LootDistScreen] Leaving loot screen...")

	# PHASE 1: Auto-save remaining loot to stash (if any)
	if loot_container and loot_container.get_item_count() > 0:
		var remaining_items = loot_container.get_item_count()
		print("[LootDistScreen] Auto-saving %d remaining items to shared stash..." % remaining_items)

		var stash_container = InventoryRegistry.get_container("stash")
		if stash_container:
			# WARNING: Check if stash has enough space before attempting save
			var free_cells = stash_container.get_free_space_count()
			var items_to_save = loot_container.get_all_items()

			# Rough estimate: assume average item is 1 cell (actual may vary for multi-cell items)
			if free_cells < items_to_save.size():
				push_warning("⚠️ [LootDistScreen] WARNING: Stash may be too full! Free cells: %d, Items to save: %d" % [free_cells, items_to_save.size()])
				push_warning("⚠️ [LootDistScreen] Some items may be LOST! Clear stash space or take items manually.")

			var saved_count = 0
			var lost_count = 0

			for item in items_to_save:
				# Try to move to stash
				var moved = ItemTransactionService.move_item(
					item.uuid,
					loot_container.container_id,
					"stash",
					-1, -1 # auto-placement
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

	# Save all inventory changes (hero inventories + shared stash)
	if SaveManager:
		SaveManager.save_current_profile()
		print("[LootDistScreen] ✅ Forced save - all changes persisted to disk")

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
