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

# Victory star data (NEW - Phase 5)
var stars_earned: int = 0 # Stars earned this run
var level_id: String = "" # Current level ID
var difficulty: String = "normal" # Current difficulty

# Hero data (passed from WaveManager)
var participating_heroes: Array = [] # [{hero_id, hero_name, hero_class}]
var selected_hero_id: String = "" # Currently selected hero's ID
var selected_hero_info: Dictionary = {} # Full hero data

# Star display nodes (Phase 5)
var star_nodes: Array[Polygon2D] = []

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
## PANEL STYLING (PHASE 6)
## ============================================

func _create_panel_style(border_color: Color, bg_color: Color = Color(0.12, 0.12, 0.18, 0.95)) -> StyleBoxFlat:
	"""Create consistent panel styling with borders"""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style


func _apply_panel_styling():
	"""Apply visual styling to hero and loot panels"""

	# Get panel containers from InventoryViews
	var hero_panel = hero_inventory_view.get_parent()
	var loot_panel = loot_inventory_view.get_parent()

	# Apply bronze borders (Option 1: Subtle Game Frame)
	var bronze_color = Color(0.6, 0.5, 0.3)
	if hero_panel and hero_panel is PanelContainer:
		hero_panel.add_theme_stylebox_override("panel", _create_panel_style(bronze_color))
	if loot_panel and loot_panel is PanelContainer:
		loot_panel.add_theme_stylebox_override("panel", _create_panel_style(bronze_color))

	print("[LootDistScreen] ✅ Panel styling applied")


## ============================================
## VICTORY STAR DISPLAY (PHASE 5)
## ============================================

func _create_victory_star_display() -> Control:
	"""Create the star display panel for top of loot screen"""

	# Main container
	var star_panel = PanelContainer.new()
	star_panel.name = "VictoryStarPanel"
	star_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # Allow input to pass through

	# Gradient background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.8, 0.6, 0.3, 0.5)
	style.set_corner_radius_all(8)
	star_panel.add_theme_stylebox_override("panel", style)

	# Inner margin
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE # Allow input to pass through
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	star_panel.add_child(margin)

	# Horizontal layout
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Allow input to pass through
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	margin.add_child(hbox)

	# === LEFT: "VICTORY!" Label ===
	var victory_label = Label.new()
	victory_label.text = "VICTORY!"
	victory_label.add_theme_font_size_override("font_size", 32)
	victory_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hbox.add_child(victory_label)

	# === CENTER: Star Display ===
	var stars_container = Control.new()
	stars_container.mouse_filter = Control.MOUSE_FILTER_IGNORE # Allow input to pass through
	stars_container.custom_minimum_size = Vector2(350, 50)
	hbox.add_child(stars_container)

	# Get star data for all difficulties
	var normal_stars = SaveManager.get_level_stars(level_id, "normal") if level_id != "" else stars_earned

	var center_x = 175.0 # Center of container
	var y_pos = 25.0

	# Normal stars (3x) - Left group
	for i in range(3):
		var star = Polygon2D.new()
		star.polygon = _get_star_polygon(12.0) # Larger for visibility
		star.name = "NormalStar%d" % i
		star.modulate = Color(1, 1, 1, 0) # Start invisible

		# Position calculation
		var x_offset = (i - 1) * 35.0 # -35, 0, +35
		star.position = Vector2(center_x - 100 + x_offset, y_pos)

		stars_container.add_child(star)
		star_nodes.append(star)

	# Hard star (1x) - Right group
	var hard_star = Polygon2D.new()
	hard_star.polygon = _get_star_polygon(14.0) # Slightly larger
	hard_star.name = "HardStar"
	hard_star.modulate = Color(1, 1, 1, 0)
	hard_star.position = Vector2(center_x + 80, y_pos)
	stars_container.add_child(hard_star)
	star_nodes.append(hard_star)

	# Unlimited star (1x) - Right group
	var unlimited_star = Polygon2D.new()
	unlimited_star.polygon = _get_star_polygon(14.0)
	unlimited_star.name = "UnlimitedStar"
	unlimited_star.modulate = Color(1, 1, 1, 0)
	unlimited_star.position = Vector2(center_x + 120, y_pos)
	stars_container.add_child(unlimited_star)
	star_nodes.append(unlimited_star)

	# === RIGHT: Unlock Message ===
	var unlock_label = Label.new()
	unlock_label.name = "UnlockLabel"
	unlock_label.add_theme_font_size_override("font_size", 14)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Determine unlock message
	if difficulty == "normal" and normal_stars == 3:
		if not SaveManager.is_difficulty_unlocked(level_id, "hard"):
			unlock_label.text = "🎉 Hard & Unlimited\nDifficulties Unlocked!"
			unlock_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			unlock_label.text = ""
	elif normal_stars < 3:
		unlock_label.text = "Get 3⭐ on Normal\nto unlock Hard!"
		unlock_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	hbox.add_child(unlock_label)

	return star_panel


func _get_star_polygon(star_size: float) -> PackedVector2Array:
	"""Create 5-pointed star polygon"""
	var points = PackedVector2Array()
	var outer_radius = star_size
	var inner_radius = star_size * 0.4

	for i in range(10):
		var angle = deg_to_rad(i * 36.0 - 90.0)
		var radius = outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))

	return points


func _animate_star_reveal():
	"""Sequentially reveal stars with pulse effect + confetti"""

	await get_tree().create_timer(0.3).timeout # Brief delay

	# Get star counts
	var normal_stars = SaveManager.get_level_stars(level_id, "normal") if level_id != "" else stars_earned
	var hard_stars = SaveManager.get_level_stars(level_id, "hard") if level_id != "" else 0
	var unlimited_stars = SaveManager.get_level_stars(level_id, "unlimited") if level_id != "" else 0

	# Reveal normal stars (indices 0-2)
	for i in range(3):
		if i < normal_stars:
			await _reveal_star(i, Color("#FFD700"), 0.15) # Gold
		else:
			await _reveal_star(i, Color(0.3, 0.3, 0.3, 0.5), 0.1) # Gray

	await get_tree().create_timer(0.2).timeout

	# Reveal hard star (index 3)
	if hard_stars > 0:
		await _reveal_star(3, Color("#9B30FF"), 0.15) # Purple
	else:
		await _reveal_star(3, Color(0.3, 0.3, 0.3, 0.5), 0.1) # Gray (locked)

	# Reveal unlimited star (index 4)
	if unlimited_stars > 0:
		await _reveal_star(4, Color("#FFA500"), 0.15) # Orange
	else:
		await _reveal_star(4, Color(0.3, 0.3, 0.3, 0.5), 0.1) # Gray (locked)

	# Confetti for 3 stars!
	if normal_stars == 3:
		_spawn_confetti()


func _reveal_star(index: int, color: Color, duration: float):
	"""Reveal a single star with pulse effect"""
	if index >= star_nodes.size():
		return

	var star = star_nodes[index]
	star.color = color

	# Instant appear + pulse
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(star, "modulate:a", 1.0, duration)
	tween.tween_property(star, "scale", Vector2(1.3, 1.3), duration * 0.5)
	tween.chain().tween_property(star, "scale", Vector2(1.0, 1.0), duration * 0.5)

	await tween.finished


func _spawn_confetti():
	"""Spawn confetti particles for 3-star victory"""
	# Simple particle effect using CPUParticles2D
	var confetti = CPUParticles2D.new()
	confetti.position = Vector2(get_viewport_rect().size.x / 2, 100)
	confetti.amount = 50
	confetti.lifetime = 2.0
	confetti.one_shot = true
	confetti.explosiveness = 0.8

	# Visual properties
	confetti.color = Color(1, 0.8, 0.2)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0.2))
	gradient.set_color(1, Color(1, 0.4, 0.1, 0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	confetti.color_ramp = gradient_texture

	# Physics
	confetti.direction = Vector2(0, 1)
	confetti.spread = 45.0
	confetti.gravity = Vector2(0, 200)
	confetti.initial_velocity_min = 150.0
	confetti.initial_velocity_max = 300.0

	add_child(confetti)
	confetti.emitting = true

	# Auto-cleanup
	await get_tree().create_timer(3.0).timeout
	confetti.queue_free()


## ============================================
## INITIALIZATION
## ============================================

func _ready():
	"""Initialize loot distribution screen on load"""
	print("[LootDistScreen] ========== INITIALIZATION START ==========")

	# Load heroes and select first one
	print("[LootDistScreen] Step 1: Loading heroes...")
	_load_heroes()
	print("[LootDistScreen] ✓ Heroes loaded: %d heroes" % participating_heroes.size())

	# PHASE 1: Initialize inventory containers
	print("[LootDistScreen] Step 2: Initializing containers...")
	_initialize_containers()
	print("[LootDistScreen] ✓ Containers initialized")

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
	print("[LootDistScreen] Step 3: Loading and displaying loot...")
	_load_loot_data()
	_display_stash()
	_display_found_loot()
	_update_counters()
	print("[LootDistScreen] ✓ Loot loaded and displayed")

	# NEW (Phase 6): Apply panel styling with borders
	print("[LootDistScreen] Step 4: Applying panel styling...")
	_apply_panel_styling()

	# NEW (Phase 9): Increase separation between inventory panels
	var content_hbox = $MainPanel/MarginContainer/VBoxContainer/ContentHBox
	if content_hbox:
		content_hbox.add_theme_constant_override("separation", 30)
	else:
		push_error("[LootDistScreen] CRITICAL: ContentHBox not found!")

	# NEW (Phase 5): Insert victory star display at top of MainPanel VBoxContainer
	print("[LootDistScreen] Step 5: Creating victory star display...")
	var main_vbox = $MainPanel/MarginContainer/VBoxContainer
	if main_vbox:
		var star_display = _create_victory_star_display()
		main_vbox.add_child(star_display)
		main_vbox.move_child(star_display, 0) # Move to top
		print("[LootDistScreen] ✓ Victory star display created")
	else:
		push_error("[LootDistScreen] CRITICAL: MainPanel VBoxContainer not found!")

	# Animate entrance
	print("[LootDistScreen] Step 6: Animating entrance...")
	await _animate_entrance()
	print("[LootDistScreen] ✓ Entrance animation complete")

	# NEW (Phase 5): Start star reveal animation after entrance completes
	print("[LootDistScreen] Step 7: Animating star reveal...")
	await _animate_star_reveal()
	print("[LootDistScreen] ✓ Star reveal animation complete")

	# Connect signals
	print("[LootDistScreen] Step 8: Connecting signals...")
	hero_dropdown.item_selected.connect(_on_hero_selected)
	take_all_button.pressed.connect(_on_take_all_pressed)
	take_rare_button.pressed.connect(_on_take_rare_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# NEW: Add Hero Report Button dynamically
	_create_hero_report_button()
	
	print("[LootDistScreen] ✓ Signals connected")

	print("[LootDistScreen] ========== INITIALIZATION COMPLETE ==========")

	# AI AUTO-SKIP: If AI is active, automatically take all loot and leave
	_check_ai_auto_skip()


func _create_hero_report_button():
	"""Add Hero Report button to the UI"""
	var btn = Button.new()
	btn.text = "📊 Hero Report"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.pressed.connect(func():
		var report = HeroPostGameReport.new()
		var run_data = BalanceTracker.get_current_run_data()
		report.populate_report(run_data)
		add_child(report)
	)
	
	# Add to MiddleButtons container if it exists
	var mid_btns = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/MiddleButtons
	if mid_btns:
		mid_btns.add_child(btn)
	else:
		# Fallback to main button box
		$MainPanel/MarginContainer/VBoxContainer/ButtonsHBox.add_child(btn)


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

	await tween.finished


func _on_take_all_pressed():
	"""Take all items from loot to currently selected hero's inventory"""
	if _is_processing_buttons:
		return

	if not loot_container or not hero_container:
		push_warning("[LootDistScreen] Cannot take all - containers not initialized")
		_is_processing_buttons = false # Release lock before returning
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

	# Show error message if any items failed to transfer
	if failed_count > 0:
		_show_error_message("%d items couldn't fit in hero inventory!" % failed_count)

	# Refresh displays (show items moved)
	if hero_inventory_view:
		hero_inventory_view.refresh_view()
	if loot_inventory_view:
		loot_inventory_view.refresh_view()

	# Release lock after a short delay to prevent accidental double-clicks
	await get_tree().create_timer(0.2).timeout
	_is_processing_buttons = false


func _on_take_rare_pressed():
	"""Take only Rare/Set/Unique items from loot to hero's inventory"""
	if _is_processing_buttons:
		return

	if not loot_container or not hero_container:
		push_warning("[LootDistScreen] Cannot take rare - containers not initialized")
		_is_processing_buttons = false # Release lock before returning
		return

	if loot_container.get_item_count() == 0:
		print("[LootDistScreen] No items to take")
		return

	_is_processing_buttons = true
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

	# Show error message if any items failed to transfer
	if failed_count > 0:
		_show_error_message("%d rare+ items couldn't fit in hero inventory!" % failed_count)

	# Refresh displays (show items moved)
	if hero_inventory_view:
		hero_inventory_view.refresh_view()
	if loot_inventory_view:
		loot_inventory_view.refresh_view()

	# Release lock after a short delay to prevent accidental double-clicks
	await get_tree().create_timer(0.2).timeout
	_is_processing_buttons = false


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
