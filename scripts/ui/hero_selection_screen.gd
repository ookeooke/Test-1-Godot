extends Control
class_name HeroSelectionScreen

# HeroSelectionScreen - Choose heroes before starting a level
# Kingdom Rush style hero selection with stats and abilities display

signal heroes_confirmed(selected_heroes: Array)
signal selection_cancelled

@export var max_heroes: int = 3  # Maximum number of heroes to select
@export var hero_data_list: Array[Resource] = []  # List of available hero data resources

# UI References
@onready var hero_grid: GridContainer = $Panel/VBoxContainer/HeroGrid
@onready var selected_heroes_container: HBoxContainer = $Panel/VBoxContainer/SelectedHeroesContainer
@onready var confirm_button: Button = $Panel/VBoxContainer/ButtonsContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonsContainer/CancelButton
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel

var selected_heroes: Array = []
var hero_buttons: Array[Button] = []

# Level info (passed when showing screen)
var target_level_data: LevelNodeData = null
var selected_difficulty: String = "Normal"

func _ready():
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	_update_confirm_button()

func show_for_level(level_data: LevelNodeData, difficulty: String):
	target_level_data = level_data
	selected_difficulty = difficulty

	if title_label:
		title_label.text = "Select Heroes for " + level_data.level_name + " (" + difficulty + ")"

	show()

func _create_hero_buttons():
	# Clear existing buttons
	for button in hero_buttons:
		button.queue_free()
	hero_buttons.clear()

	# Create buttons for each available hero
	# For now, we'll create placeholder buttons since we don't have hero data resources yet
	var placeholder_heroes = [
		{"name": "Ranger", "icon": null, "description": "Ranged attacker"},
		{"name": "Warrior", "icon": null, "description": "Melee tank"},
		{"name": "Mage", "icon": null, "description": "Magic damage dealer"}
	]

	for i in range(placeholder_heroes.size()):
		var hero_info = placeholder_heroes[i]
		var button = Button.new()
		button.text = hero_info["name"]
		button.custom_minimum_size = Vector2(150, 100)
		button.pressed.connect(_on_hero_button_pressed.bind(i))

		if hero_grid:
			hero_grid.add_child(button)
		hero_buttons.append(button)

func _on_hero_button_pressed(hero_index: int):
	# Toggle hero selection
	if selected_heroes.has(hero_index):
		selected_heroes.erase(hero_index)
	else:
		if selected_heroes.size() < max_heroes:
			selected_heroes.append(hero_index)

	_update_selection_display()
	_update_confirm_button()

func _update_selection_display():
	# Update visual feedback for selected heroes
	for i in range(hero_buttons.size()):
		var button = hero_buttons[i]
		if selected_heroes.has(i):
			button.modulate = Color(0.5, 1.0, 0.5, 1.0)  # Green tint
		else:
			button.modulate = Color.WHITE

func _update_confirm_button():
	if confirm_button:
		# Require at least one hero
		confirm_button.disabled = selected_heroes.is_empty()

func _on_confirm_pressed():
	print("HeroSelectionScreen: Confirmed heroes: ", selected_heroes)
	heroes_confirmed.emit(selected_heroes)

	# Start the level
	if target_level_data:
		get_tree().change_scene_to_file(target_level_data.level_scene_path)

func _on_cancel_pressed():
	print("HeroSelectionScreen: Cancelled hero selection")
	selection_cancelled.emit()
	hide()
