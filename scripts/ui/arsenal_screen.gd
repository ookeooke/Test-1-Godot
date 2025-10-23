extends Control
class_name ArsenalScreen

## ArsenalScreen - Central hub for hero management from world map
## Left panel: Hero roster with filter/search
## Right panel: Selected hero's equipment, skills, stats (reusing FlexiblePanel)
## Bottom: Loadout selector for saving/loading builds

signal closed

@export var current_hero_id: String = "ranger"

# UI Structure (created programmatically for quick implementation)
var canvas_layer: CanvasLayer
var background: ColorRect
var main_container: VBoxContainer
var close_button: Button
var title_label: Label
var gold_label: Label
var panels_hbox: HBoxContainer
var left_panel_container: PanelContainer
var right_panel_container: PanelContainer

# Views
var hero_roster_view: HeroRosterView
var equipment_view: EquipmentView
var inventory_view: Control  # InventoryView for drag-drop equipping

# State
var is_transitioning: bool = false


func _ready():
	_create_ui_structure()
	_connect_signals()

	# Hide by default
	visible = false
	if canvas_layer:
		canvas_layer.visible = false

	print("[ArsenalScreen] Ready")


func _create_ui_structure():
	"""Create the full UI structure programmatically"""
	# CanvasLayer (always on top)
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	add_child(canvas_layer)

	# Background overlay
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(background)

	# Center container
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(center_container)

	# Main container - FULL SCREEN for 1920x1080
	main_container = VBoxContainer.new()
	main_container.custom_minimum_size = Vector2(1800, 1000)
	center_container.add_child(main_container)

	# Top bar
	var top_bar = PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 70)
	main_container.add_child(top_bar)

	var top_bar_margin = MarginContainer.new()
	top_bar_margin.add_theme_constant_override("margin_left", 20)
	top_bar_margin.add_theme_constant_override("margin_right", 20)
	top_bar_margin.add_theme_constant_override("margin_top", 10)
	top_bar_margin.add_theme_constant_override("margin_bottom", 10)
	top_bar.add_child(top_bar_margin)

	var top_bar_hbox = HBoxContainer.new()
	top_bar_hbox.add_theme_constant_override("separation", 30)
	top_bar_margin.add_child(top_bar_hbox)

	title_label = Label.new()
	title_label.text = "ARSENAL"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	top_bar_hbox.add_child(title_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_hbox.add_child(spacer)

	gold_label = Label.new()
	gold_label.text = "💎 0"  # Gems (persistent currency)
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))  # Blue for gems
	top_bar_hbox.add_child(gold_label)

	close_button = Button.new()
	close_button.text = "✖"
	close_button.custom_minimum_size = Vector2(60, 60)
	close_button.add_theme_font_size_override("font_size", 32)
	top_bar_hbox.add_child(close_button)

	# Panels HBox (Hero Roster | Equipment + Inventory)
	panels_hbox = HBoxContainer.new()
	panels_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels_hbox.add_theme_constant_override("separation", 15)
	main_container.add_child(panels_hbox)

	# ===== LEFT: HERO ROSTER (30% width) =====
	left_panel_container = PanelContainer.new()
	left_panel_container.custom_minimum_size = Vector2(380, 0)
	left_panel_container.size_flags_horizontal = Control.SIZE_FILL
	panels_hbox.add_child(left_panel_container)

	var left_margin = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 15)
	left_margin.add_theme_constant_override("margin_right", 15)
	left_margin.add_theme_constant_override("margin_top", 15)
	left_margin.add_theme_constant_override("margin_bottom", 15)
	left_panel_container.add_child(left_margin)

	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_margin.add_child(left_vbox)

	var roster_title = Label.new()
	roster_title.text = "HERO ROSTER"
	roster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_title.add_theme_font_size_override("font_size", 24)
	roster_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	left_vbox.add_child(roster_title)

	hero_roster_view = HeroRosterView.new()
	hero_roster_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(hero_roster_view)

	# ===== RIGHT: EQUIPMENT + INVENTORY (70% width) =====
	right_panel_container = PanelContainer.new()
	right_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panels_hbox.add_child(right_panel_container)

	var right_margin = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 15)
	right_margin.add_theme_constant_override("margin_right", 15)
	right_margin.add_theme_constant_override("margin_top", 15)
	right_margin.add_theme_constant_override("margin_bottom", 15)
	right_panel_container.add_child(right_margin)

	# HSplit for Equipment (40%) + Inventory (60%)
	var hsplit = HSplitContainer.new()
	hsplit.split_offset = 350  # Equipment gets 350px, rest for inventory
	right_margin.add_child(hsplit)

	# ===== EQUIPMENT SECTION =====
	var equipment_container = VBoxContainer.new()
	equipment_container.add_theme_constant_override("separation", 10)
	hsplit.add_child(equipment_container)

	var equipment_label = Label.new()
	equipment_label.text = "EQUIPMENT"
	equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_label.add_theme_font_size_override("font_size", 22)
	equipment_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	equipment_label.custom_minimum_size = Vector2(0, 40)
	equipment_container.add_child(equipment_label)

	# Hero name display
	var detail_header = Label.new()
	detail_header.text = "Select a hero from roster"
	detail_header.name = "DetailHeader"
	detail_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_header.add_theme_font_size_override("font_size", 18)
	detail_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	equipment_container.add_child(detail_header)

	equipment_view = preload("res://scenes/ui/views/equipment_view.tscn").instantiate()
	equipment_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_container.add_child(equipment_view)

	# ===== INVENTORY SECTION =====
	var inventory_container = VBoxContainer.new()
	inventory_container.add_theme_constant_override("separation", 10)
	hsplit.add_child(inventory_container)

	var inventory_label = Label.new()
	inventory_label.text = "INVENTORY (drag to equipment slots)"
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label.add_theme_font_size_override("font_size", 22)
	inventory_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.8))
	inventory_label.custom_minimum_size = Vector2(0, 40)
	inventory_container.add_child(inventory_label)

	inventory_view = preload("res://scenes/ui/views/inventory_view.tscn").instantiate()
	inventory_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_container.add_child(inventory_view)

	print("[ArsenalScreen] UI structure created")


func _connect_signals():
	"""Connect UI signals"""
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	if hero_roster_view:
		hero_roster_view.hero_selected.connect(_on_hero_selected)


func show_screen():
	"""Show the arsenal with fade-in animation"""
	if is_transitioning:
		return

	is_transitioning = true
	visible = true

	if canvas_layer:
		canvas_layer.visible = true

	# Update gems display (persistent currency)
	if gold_label:
		gold_label.text = "💎 %d" % SaveManager.get_gems()

	# DEBUG: Add test items to inventory if empty (first time opening Arsenal)
	if InventoryManager.get_unique_item_count() == 0:
		_add_test_items_for_debugging()

	# Fade in animation
	if background:
		background.modulate.a = 0.0
	if main_container:
		main_container.modulate.a = 0.0
		main_container.scale = Vector2(0.95, 0.95)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	if background:
		tween.tween_property(background, "modulate:a", 1.0, 0.2)
	if main_container:
		tween.tween_property(main_container, "modulate:a", 1.0, 0.2)
		tween.tween_property(main_container, "scale", Vector2.ONE, 0.3)

	await tween.finished
	is_transitioning = false

	print("[ArsenalScreen] Opened")


func hide_screen():
	"""Hide the arsenal with fade-out animation"""
	if is_transitioning:
		return

	is_transitioning = true

	# Fade out animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)

	if background:
		tween.tween_property(background, "modulate:a", 0.0, 0.15)
	if main_container:
		tween.tween_property(main_container, "modulate:a", 0.0, 0.15)
		tween.tween_property(main_container, "scale", Vector2(0.95, 0.95), 0.2)

	await tween.finished

	visible = false
	if canvas_layer:
		canvas_layer.visible = false

	closed.emit()
	is_transitioning = false

	print("[ArsenalScreen] Closed")


func _on_close_pressed():
	"""Handle close button"""
	hide_screen()


func _on_hero_selected(hero_data: HeroData):
	"""Handle hero selection from roster"""
	current_hero_id = hero_data.hero_id

	print("[ArsenalScreen] Selected hero: ", hero_data.hero_name)

	# Update right panel header
	var detail_header = right_panel_container.find_child("DetailHeader", true, false)
	if detail_header:
		detail_header.text = "%s - Level %d - %s" % [hero_data.hero_name, hero_data.get_current_level(), hero_data.get_class_name()]
		detail_header.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))  # Highlight selected hero

	# Update equipment view
	if equipment_view:
		equipment_view.set_hero_id(current_hero_id)
		equipment_view.refresh_view()

	print("[ArsenalScreen] Equipment view updated for: ", current_hero_id)


# Loadout functions removed - not needed for tower defense gameplay
# Equipment auto-saves per hero, no manual save/load needed


func _input(event: InputEvent):
	"""Handle ESC key"""
	if event.is_action_pressed("ui_cancel") and visible:
		hide_screen()
		get_viewport().set_input_as_handled()


func _add_test_items_for_debugging():
	"""DEBUG: Add test items to inventory for testing equipment system"""
	print("[ArsenalScreen] DEBUG: Adding test items to inventory...")

	# Add weapons
	InventoryManager.add_item("basic_bow", 1)
	InventoryManager.add_item("legendary_bow", 1)

	# Add armor (if exists in ItemDatabase)
	var all_items = ItemDatabase.items.values()
	for item_data in all_items:
		if item_data.equip_slot == ItemData.EquipSlot.ARMOR:
			InventoryManager.add_item(item_data.item_id, 1)
			break  # Add just one armor piece

	# Add some consumables
	InventoryManager.add_item("health_potion", 5)

	# Add materials
	InventoryManager.add_item("iron_ore", 10)
	InventoryManager.add_item("magic_essence", 3)
	InventoryManager.add_item("dragon_scale", 1)

	print("[ArsenalScreen] DEBUG: Added %d unique items to inventory" % InventoryManager.get_unique_item_count())
