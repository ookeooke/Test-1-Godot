extends BasePanelView
class_name HeroRosterView

## HeroRosterView - Grid of all heroes with filtering
## Similar to InventoryView but for heroes instead of items

signal hero_selected(hero_data: HeroData)

# UI References (will be setup in scene or code)
var hero_grid: GridContainer
var search_box: LineEdit
var filter_all_button: Button
var filter_melee_button: Button
var filter_ranged_button: Button
var filter_magic_button: Button
var filter_support_button: Button
var sort_dropdown: OptionButton
var heroes_count_label: Label

var current_filter: String = "All"
var current_sort: String = "Name"
var hero_cards: Array[HeroCard] = []


func _ready():
	super._ready()
	view_name = "Hero Roster"

	# Create UI elements programmatically (for quick implementation)
	_create_ui_elements()

	# Connect to HeroDatabase
	if HeroDatabase.heroes_loaded_flag:
		_populate_hero_grid()
	else:
		HeroDatabase.heroes_loaded.connect(_populate_hero_grid)


func _create_ui_elements():
	"""Create UI structure programmatically"""
	# Main VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Header with search and sort
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_hbox)

	# Search box
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search heroes..."
	search_box.custom_minimum_size = Vector2(200, 40)
	search_box.text_changed.connect(_on_search_changed)
	header_hbox.add_child(search_box)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	# Sort dropdown
	var sort_label = Label.new()
	sort_label.text = "Sort:"
	header_hbox.add_child(sort_label)

	sort_dropdown = OptionButton.new()
	sort_dropdown.add_item("Name")
	sort_dropdown.add_item("Level")
	sort_dropdown.add_item("Class")
	sort_dropdown.item_selected.connect(_on_sort_changed)
	header_hbox.add_child(sort_dropdown)

	# Filter bar
	var filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 5)
	main_vbox.add_child(filter_bar)

	var filter_label = Label.new()
	filter_label.text = "Filter:"
	filter_bar.add_child(filter_label)

	filter_all_button = Button.new()
	filter_all_button.text = "All"
	filter_all_button.toggle_mode = true
	filter_all_button.button_pressed = true
	filter_all_button.pressed.connect(_on_filter_changed.bind("All"))
	filter_bar.add_child(filter_all_button)

	filter_melee_button = Button.new()
	filter_melee_button.text = "Melee"
	filter_melee_button.toggle_mode = true
	filter_melee_button.pressed.connect(_on_filter_changed.bind("Melee"))
	filter_bar.add_child(filter_melee_button)

	filter_ranged_button = Button.new()
	filter_ranged_button.text = "Ranged"
	filter_ranged_button.toggle_mode = true
	filter_ranged_button.pressed.connect(_on_filter_changed.bind("Ranged"))
	filter_bar.add_child(filter_ranged_button)

	filter_magic_button = Button.new()
	filter_magic_button.text = "Magic"
	filter_magic_button.toggle_mode = true
	filter_magic_button.pressed.connect(_on_filter_changed.bind("Magic"))
	filter_bar.add_child(filter_magic_button)

	filter_support_button = Button.new()
	filter_support_button.text = "Support"
	filter_support_button.toggle_mode = true
	filter_support_button.pressed.connect(_on_filter_changed.bind("Support"))
	filter_bar.add_child(filter_support_button)

	# Heroes count label
	heroes_count_label = Label.new()
	heroes_count_label.text = "Heroes: 0"
	filter_bar.add_child(heroes_count_label)

	# Scroll container with grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	hero_grid = GridContainer.new()
	hero_grid.columns = 4  # 4 heroes per row
	hero_grid.add_theme_constant_override("h_separation", 10)
	hero_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(hero_grid)


func _populate_hero_grid():
	"""Create hero cards for all heroes"""
	# Clear existing cards
	for card in hero_cards:
		card.queue_free()
	hero_cards.clear()

	# Get filtered heroes
	var heroes = _get_filtered_heroes()

	# Create cards
	for hero in heroes:
		var card = _create_hero_card(hero)
		hero_grid.add_child(card)
		hero_cards.append(card)

	# Update count
	if heroes_count_label:
		heroes_count_label.text = "Heroes: %d" % heroes.size()


func _create_hero_card(hero_data: HeroData) -> HeroCard:
	"""Create a hero card instance"""
	# Create programmatically for now
	var card = PanelContainer.new()
	card.set_script(preload("res://scripts/ui/hero_card.gd"))
	card.custom_minimum_size = Vector2(120, 180)

	# Setup structure
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	card.add_child(vbox)

	# Portrait
	var portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(100, 100)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(portrait)

	# Name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Level
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(level_label)

	# Class
	var class_label = Label.new()
	class_label.name = "ClassLabel"
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(class_label)

	# Button
	var button = Button.new()
	button.name = "SelectButton"
	button.text = "Select"
	button.custom_minimum_size = Vector2(100, 30)
	card.add_child(button)

	# Locked overlay
	var locked_overlay = ColorRect.new()
	locked_overlay.name = "LockedOverlay"
	locked_overlay.color = Color(0, 0, 0, 0.7)
	locked_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	locked_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(locked_overlay)

	var locked_label = Label.new()
	locked_label.name = "LockedLabel"
	locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	locked_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	locked_overlay.add_child(locked_label)

	# Set data and connect signal
	card.set_hero_data(hero_data)
	card.hero_selected.connect(_on_hero_card_selected)

	return card


func _get_filtered_heroes() -> Array[HeroData]:
	"""Get heroes matching current filter and search"""
	var all_heroes = HeroDatabase.get_all_heroes()
	var filtered: Array[HeroData] = []

	for hero in all_heroes:
		# Apply class filter
		if current_filter != "All":
			if hero.get_class_name() != current_filter:
				continue

		# Apply search filter
		if search_box and not search_box.text.is_empty():
			if not hero.hero_name.to_lower().contains(search_box.text.to_lower()):
				continue

		filtered.append(hero)

	# Sort
	_sort_heroes(filtered)

	return filtered


func _sort_heroes(heroes: Array[HeroData]):
	"""Sort heroes by current sort criteria"""
	match current_sort:
		"Name":
			heroes.sort_custom(func(a, b): return a.hero_name < b.hero_name)
		"Class":
			heroes.sort_custom(func(a, b): return a.get_class_name() < b.get_class_name())
		"Level":
			heroes.sort_custom(func(a, b): return a.get_current_level() > b.get_current_level())


func _on_filter_changed(filter: String):
	"""Handle filter button press"""
	current_filter = filter

	# Update button states
	filter_all_button.button_pressed = (filter == "All")
	filter_melee_button.button_pressed = (filter == "Melee")
	filter_ranged_button.button_pressed = (filter == "Ranged")
	filter_magic_button.button_pressed = (filter == "Magic")
	filter_support_button.button_pressed = (filter == "Support")

	_populate_hero_grid()


func _on_search_changed(new_text: String):
	"""Handle search text change"""
	_populate_hero_grid()


func _on_sort_changed(index: int):
	"""Handle sort dropdown change"""
	current_sort = sort_dropdown.get_item_text(index)
	_populate_hero_grid()


func _on_hero_card_selected(hero_data: HeroData):
	"""Emit signal when hero card is selected"""
	hero_selected.emit(hero_data)


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	_populate_hero_grid()
