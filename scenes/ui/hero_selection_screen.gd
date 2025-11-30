extends Control

@onready var hero_container = $CenterContainer/HBoxContainer
@onready var description_label = $VBoxContainer/DescriptionLabel
@onready var start_button = $VBoxContainer/StartButton

var selected_hero_id: String = ""


func _populate_heroes():
	# Clear existing
	for child in hero_container.get_children():
		child.queue_free()
		
	# Get available starter heroes (Ranger, Warrior, Mage)
	var starter_heroes = ["ranger", "warrior", "mage"]
	
	for hero_id in starter_heroes:
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
			button.custom_minimum_size = Vector2(150, 200)
		else:
			print("[HeroSelectionScreen] No portrait for hero: ", hero_id)
			
		button.pressed.connect(func(): _on_hero_button_pressed(hero_id, hero_data))
		hero_container.add_child(button)

func _on_hero_button_pressed(hero_id: String, data):
	selected_hero_id = hero_id
	description_label.text = "[b]%s[/b]\n\n%s\n\nClass: %s" % [
		data.hero_name,
		data.description,
		HeroClassDatabase.get_class_name(data.hero_class)
	]
	start_button.disabled = false

func _on_start_pressed():
	if selected_hero_id == "": return
	
	print("[HeroSelectionScreen] Selected Hero: ", selected_hero_id)
	
	# 1. Profile already created in ProfileCreation screen
	print("[HeroSelectionScreen] Using current profile: ", SaveManager.get_current_profile_name())
	
	# 2. Unlock All Starter Heroes (for testing)
	var starter_heroes: Array[String] = ["ranger", "warrior", "mage"]
	for hero in starter_heroes:
		print("[HeroSelectionScreen] Unlocking hero: ", hero)
		SaveManager.unlock_hero(hero)
	
	# 3. Add All to Squad (for testing)
	print("[HeroSelectionScreen] Setting squad to all starters: ", starter_heroes)
	SaveManager.set_current_squad(starter_heroes)
	
	# 4. Go to World Map
	print("[HeroSelectionScreen] Loading World Map...")
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")
	
	queue_free()

func _ready():
	# _setup_debug_panel() # Removed debug panel
	_populate_heroes()
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
