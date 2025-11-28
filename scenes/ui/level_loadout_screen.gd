extends Control

signal back_pressed

@onready var hero_container = $CenterContainer/HBoxContainer
@onready var level_info_label = $VBoxContainer/LevelInfoLabel
@onready var deploy_button = $VBoxContainer/DeployButton

var selected_hero_id: String = ""
var target_level_id: String = ""

func setup(level_id: String):
	target_level_id = level_id
	_update_level_info()
	_populate_heroes()

func _ready():
	deploy_button.disabled = true
	deploy_button.pressed.connect(_on_deploy_pressed)
	
	# Back button (if exists)
	var back_btn = find_child("BackButton")
	if back_btn:
		back_btn.pressed.connect(func():
			back_pressed.emit()
			queue_free()
		)

func _update_level_info():
	if target_level_id == "": return
	
	# Get level data (placeholder for now, or from LevelManager if available)
	level_info_label.text = "[center][b]Level: %s[/b]\nSelect your hero![/center]" % target_level_id.capitalize()

func _populate_heroes():
	# Clear existing
	for child in hero_container.get_children():
		child.queue_free()
		
	# Get unlocked heroes
	var unlocked_heroes = SaveManager.get_unlocked_heroes()
	
	for hero_id in unlocked_heroes:
		var hero_data = HeroDatabase.get_hero(hero_id)
		if not hero_data: continue
		
		var button = Button.new()
		button.text = hero_data.hero_name
		button.custom_minimum_size = Vector2(150, 200)
		button.toggle_mode = true
		button.button_group = load("res://resources/ui/hero_selection_group.tres")
		
		# Add icon if available
		if hero_data.portrait:
			button.icon = hero_data.portrait
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.expand_icon = true
			
		button.pressed.connect(func(): _on_hero_button_pressed(hero_id, hero_data))
		hero_container.add_child(button)
		
	# Auto-select current squad leader if possible
	var current_squad = SaveManager.get_current_squad()
	if not current_squad.is_empty():
		# Find button for this hero and press it
		# (Simplified: just wait for user input)
		pass

func _on_hero_button_pressed(hero_id: String, _data):
	selected_hero_id = hero_id
	deploy_button.disabled = false
	deploy_button.text = "DEPLOY " + _data.hero_name.to_upper()

func _on_deploy_pressed():
	if selected_hero_id == "": return
	
	print("[LevelLoadoutScreen] Deploying to %s with %s" % [target_level_id, selected_hero_id])
	
	# 1. Update Squad
	print("[LevelLoadoutScreen] Updating squad...")
	SaveManager.set_current_squad([selected_hero_id])
	
	# 2. Load Level
	print("[LevelLoadoutScreen] Loading level...")
	LevelManager.quick_load_level(target_level_id)
	
	queue_free()
