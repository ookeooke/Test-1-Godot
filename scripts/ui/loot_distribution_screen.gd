extends Control

## Loot Distribution Screen - Battle Brothers Style
## Two-panel layout: Hero Inventory (left) + Found Loot (right)
## Drag items from Found Loot to Hero Inventory
## NOW SUPPORTS: Per-hero inventories + multi-hero selection!

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
var loot_items: Array = []  # Items in Found Loot panel
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


func _ready():
	# Connect buttons
	take_all_button.pressed.connect(_on_take_all_pressed)
	take_rare_button.pressed.connect(_on_take_rare_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	hero_dropdown.item_selected.connect(_on_hero_selected)

	# Load heroes and select first one
	_load_heroes()

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

	# Register hero in HeroInventoryManager if not already registered
	if not HeroInventoryManager.is_hero_registered(selected_hero_id):
		HeroInventoryManager.register_hero(selected_hero_id)
		print("[LootDistScreen] Registered new hero in inventory system: ", selected_hero_id)

	_update_hero_display()
	print("[LootDistScreen] Loaded %d heroes, selected: %s" % [participating_heroes.size(), selected_hero_id])


func _on_hero_selected(index: int):
	"""When user selects a different hero from dropdown"""
	if index < participating_heroes.size():
		selected_hero_info = participating_heroes[index]
		selected_hero_id = selected_hero_info.hero_id

		# Register hero in HeroInventoryManager if not already registered
		if not HeroInventoryManager.is_hero_registered(selected_hero_id):
			HeroInventoryManager.register_hero(selected_hero_id)
			print("[LootDistScreen] Registered new hero in inventory system: ", selected_hero_id)

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


func _load_loot_data():
	"""Load all pending loot from LootManager"""
	loot_items = LootManager.get_pending_loot_with_data()
	print("[LootDistScreen] Loaded %d items for distribution" % loot_items.size())


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
	var hero_items = HeroInventoryManager.get_all_items(selected_hero_id)

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
	for item_entry in hero_items:
		var item_id = item_entry.item_id
		var item_data = item_entry.item_data
		var quantity = item_entry.quantity

		if item_data:
			var item_panel = _create_item_display(item_data, quantity, item_id, false)
			stash_grid.add_child(item_panel)


func _display_found_loot():
	"""Display loot items in right panel (FOUND LOOT)"""
	# Clear existing items (reset modulation first for defensive programming)
	for child in loot_grid.get_children():
		if child is PanelContainer:
			child.modulate = Color.WHITE  # Safety reset before freeing
		child.queue_free()

	# Create draggable item slots for each loot item
	for loot in loot_items:
		var item_data: ItemData = loot.item_data
		var item_panel = _create_item_display(item_data, loot.quantity, loot.item_id, true)
		loot_grid.add_child(item_panel)

	# Show empty message if no loot
	if loot_items.is_empty():
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
	"""End drag and check for valid drop"""
	if dragged_item == null:
		return

	var item_id = dragged_item.get_meta("item_id")
	var item_data = dragged_item.get_meta("item_data")
	var quantity = dragged_item.get_meta("quantity")

	# Check if mouse is over stash panel
	var mouse_pos = get_global_mouse_position()
	var is_over_stash = _is_point_over_control(mouse_pos, stash_grid.get_parent().get_parent())

	# CRITICAL FIX: Always reset modulation BEFORE processing drop
	# This prevents visual state leaks when panels are freed/recreated
	dragged_item.modulate = Color.WHITE

	if is_over_stash:
		_add_item_to_inventory(item_id, item_data, quantity)

	# Cleanup
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	dragged_item = null
	drag_start_parent = null


func _add_item_to_inventory(item_id: String, item_data: ItemData, quantity: int):
	"""Add item to selected hero's inventory"""
	# Safety check
	if selected_hero_id == "":
		print("[LootDistScreen] ERROR: No hero selected!")
		if dragged_item:
			dragged_item.modulate = Color.WHITE
		return

	# Try to add to hero's inventory
	var success = HeroInventoryManager.add_item_to_hero(selected_hero_id, item_id, quantity)

	if success:
		print("[LootDistScreen] Item added to %s's inventory: %s" % [selected_hero_info.hero_name, item_data.item_name])

		# Remove from pending loot
		for i in range(LootManager.pending_wave_loot.size()):
			if LootManager.pending_wave_loot[i].item_id == item_id:
				LootManager.pending_wave_loot.remove_at(i)
				break

		# Remove from loot_items array
		for i in range(loot_items.size()):
			if loot_items[i].item_id == item_id:
				loot_items.remove_at(i)
				break

		# Refresh displays
		_display_stash()
		_display_found_loot()
		_update_counters()
	else:
		print("[LootDistScreen] Hero inventory full! Cannot add: %s" % item_data.item_name)
		if dragged_item:
			dragged_item.modulate = Color.WHITE


func _on_take_all_pressed():
	"""Take all items from Found Loot"""
	print("[LootDistScreen] Taking all items...")

	var items_to_take = loot_items.duplicate()
	for loot in items_to_take:
		_add_item_to_inventory(loot.item_id, loot.item_data, loot.quantity)


func _on_take_rare_pressed():
	"""Take only Rare+ items"""
	print("[LootDistScreen] Taking Rare+ items...")

	var items_to_take = []
	for loot in loot_items:
		var item_data: ItemData = loot.item_data
		if item_data.rarity >= ItemData.Rarity.RARE:
			items_to_take.append(loot)

	for loot in items_to_take:
		_add_item_to_inventory(loot.item_id, loot.item_data, loot.quantity)


func _process(_delta):
	"""Update drag preview position"""
	if drag_preview and dragged_item:
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2


func _is_point_over_control(point: Vector2, control: Control) -> bool:
	"""Check if point is inside control"""
	var rect = Rect2(control.global_position, control.size)
	return rect.has_point(point)


func _update_counters():
	"""Update capacity and loot count labels"""
	# Get hero's inventory count
	var item_count = 0
	if selected_hero_id != "":
		var hero_items = HeroInventoryManager.get_all_items(selected_hero_id)
		item_count = hero_items.size()

	var max_capacity = 64  # 8x8 grid = 64 slots max
	capacity_label.text = "%d/%d" % [item_count, max_capacity]

	loot_count_label.text = "%d items" % loot_items.size()


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
	"""Leave loot screen"""
	print("[LootDistScreen] Leaving, destroying %d items..." % loot_items.size())

	LootManager.pending_wave_loot.clear()
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
