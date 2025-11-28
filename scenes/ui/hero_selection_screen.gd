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
	
	# 2. Unlock Selected Hero
	print("[HeroSelectionScreen] Unlocking hero: ", selected_hero_id)
	SaveManager.unlock_hero(selected_hero_id)
	
	# 3. Add to Squad
	print("[HeroSelectionScreen] Setting squad: ", [selected_hero_id])
	SaveManager.set_current_squad([selected_hero_id])
	
	# 4. Go to World Map
	print("[HeroSelectionScreen] Loading World Map...")
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")
	
	queue_free()

func _ready():
	_setup_debug_panel()
	_populate_heroes()
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)

func _setup_debug_panel():
	var debug_panel = VBoxContainer.new()
	debug_panel.name = "DebugPanel"
	add_child(debug_panel)
	debug_panel.position = Vector2(10, 10)
	
	var title = Label.new()
	title.text = "DEBUG: Hero Resources"
	title.modulate = Color.YELLOW
	debug_panel.add_child(title)
	
	# 1. Get all .tres files in resources/heroes/
	var dir = DirAccess.open("res://resources/heroes/")
	var found_files = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				found_files.append(file_name)
			file_name = dir.get_next()
	
	# 2. Check status of each file
	var hero_list = HeroDatabase.heroes
	
	for file_name in found_files:
		# Check if this file corresponds to any loaded hero
		for h_id in hero_list:
			if file_name.begins_with(h_id):
				break
				
		# Alternative: Check if ANY hero loaded from this file? 
		# Hard to do reverse lookup. Let's list LOADED heroes and UNLOADED files.
		pass

	# Simpler approach: List LOADED, then list FILES NOT LOADED
	
	# List Loaded
	for h_id in hero_list:
		var h_data = hero_list[h_id]
		var status = "LOADED"
		var color = Color.GREEN
		if not h_data.portrait:
			status = "NO PORTRAIT"
			color = Color.ORANGE
			
		var label = Label.new()
		label.text = "ID: %s [%s]" % [h_id, status]
		label.modulate = color
		debug_panel.add_child(label)
		
	# Check for missing
	for file_name in found_files:
		var is_represented = false
		for h_id in hero_list:
			# loose match
			if file_name.contains(h_id):
				is_represented = true
				break
		
		if not is_represented:
			var label = Label.new()
			label.text = "FILE: %s [NOT LOADED]" % file_name
			label.modulate = Color.RED
			debug_panel.add_child(label)
