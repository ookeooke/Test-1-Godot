extends Control

# Profile Select - 3 save slots like Kingdom Rush
# Shows existing profiles or empty slots

# Slot buttons
@onready var slot1_container = $VBoxContainer/Slot1Container
@onready var slot1_button: Button = $VBoxContainer/Slot1Container/SlotButton
@onready var slot1_label: Label = $VBoxContainer/Slot1Container/SlotButton/Label
@onready var slot1_delete: Button = $VBoxContainer/Slot1Container/DeleteButton

@onready var slot2_container = $VBoxContainer/Slot2Container
@onready var slot2_button: Button = $VBoxContainer/Slot2Container/SlotButton
@onready var slot2_label: Label = $VBoxContainer/Slot2Container/SlotButton/Label
@onready var slot2_delete: Button = $VBoxContainer/Slot2Container/DeleteButton

@onready var slot3_container = $VBoxContainer/Slot3Container
@onready var slot3_button: Button = $VBoxContainer/Slot3Container/SlotButton
@onready var slot3_label: Label = $VBoxContainer/Slot3Container/SlotButton/Label
@onready var slot3_delete: Button = $VBoxContainer/Slot3Container/DeleteButton

@onready var back_button: Button = $VBoxContainer/BackButton

# Store profile names for each slot
var slot_profiles = ["", "", ""]  # Empty = no profile in that slot

func _ready():
	# Connect signals
	slot1_button.pressed.connect(_on_slot_pressed.bind(0))
	slot2_button.pressed.connect(_on_slot_pressed.bind(1))
	slot3_button.pressed.connect(_on_slot_pressed.bind(2))

	slot1_delete.pressed.connect(_on_delete_pressed.bind(0))
	slot2_delete.pressed.connect(_on_delete_pressed.bind(1))
	slot3_delete.pressed.connect(_on_delete_pressed.bind(2))

	back_button.pressed.connect(_on_back_pressed)

	# Load existing profiles
	_load_profiles()

func _load_profiles():
	# Get all saved profiles
	var all_profiles = SaveManager.list_profiles()

	# Fill slots (max 3)
	for i in range(3):
		if i < all_profiles.size():
			slot_profiles[i] = all_profiles[i]
		else:
			slot_profiles[i] = ""

	# Update UI
	_update_slot_ui(0, slot1_label, slot1_delete)
	_update_slot_ui(1, slot2_label, slot2_delete)
	_update_slot_ui(2, slot3_label, slot3_delete)

func _update_slot_ui(slot_index: int, label: Label, delete_btn: Button):
	var profile_name = slot_profiles[slot_index]

	if profile_name.is_empty():
		# Empty slot
		label.text = "Empty Slot - Click to Create"
		delete_btn.visible = false
	else:
		# Existing profile - show name and stats
		var profile_data = _load_profile_data(profile_name)
		if profile_data:
			var completed = profile_data.get("completed_levels", []).size()
			label.text = profile_name + "\n" + str(completed) + " levels completed"
		else:
			label.text = profile_name
		delete_btn.visible = true

func _load_profile_data(profile_name: String) -> Dictionary:
	# Temporarily load profile to get data
	var save_path = SaveManager.SAVE_DIR + profile_name + SaveManager.SAVE_EXTENSION

	if not FileAccess.file_exists(save_path):
		return {}

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			return json.data

	return {}

func _on_slot_pressed(slot_index: int):
	var profile_name = slot_profiles[slot_index]

	if profile_name.is_empty():
		# Empty slot - create new profile
		# Store which slot we're creating for
		get_tree().root.set_meta("creating_slot", slot_index)
		get_tree().change_scene_to_file("res://scenes/ui/profile_creation.tscn")
	else:
		# Existing profile - load and play
		if SaveManager.load_profile(profile_name):
			get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")
		else:
			push_error("Failed to load profile: ", profile_name)

func _on_delete_pressed(slot_index: int):
	var profile_name = slot_profiles[slot_index]

	if profile_name.is_empty():
		return

	# Show confirmation (simple for now - just delete)
	print("Deleting profile: ", profile_name)

	if SaveManager.delete_profile(profile_name):
		# Reload profiles
		_load_profiles()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
