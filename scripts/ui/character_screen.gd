extends Control
class_name CharacterScreen

## CharacterScreen - Combined Equipment + Inventory UI
## Shows hero equipment slots on left, inventory storage on right
## Press C or I to toggle

signal screen_closed

@onready var equipment_panel: EquipmentPanel = $CanvasLayer/CenterContainer/HBoxContainer/EquipmentPanel if has_node("CanvasLayer/CenterContainer/HBoxContainer/EquipmentPanel") else null
@onready var inventory_panel: InventoryPanel = $CanvasLayer/CenterContainer/HBoxContainer/InventoryPanel if has_node("CanvasLayer/CenterContainer/HBoxContainer/InventoryPanel") else null
@onready var close_button: Button = $CanvasLayer/CenterContainer/HBoxContainer/VBoxContainer/CloseButton if has_node("CanvasLayer/CenterContainer/HBoxContainer/VBoxContainer/CloseButton") else null


func _ready():
	# Set up as always-process (for pause compatibility)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Hide by default
	visible = false

	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	# Connect inventory closed signal
	if inventory_panel:
		inventory_panel.inventory_closed.connect(_on_close_button_pressed)


func _input(event: InputEvent):
	if event.is_action_pressed("toggle_inventory"):
		if visible:
			hide_character_screen()
		else:
			show_character_screen()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel") and visible:
		hide_character_screen()
		get_viewport().set_input_as_handled()


func show_character_screen():
	"""Show the character screen (equipment + inventory)"""
	visible = true

	# Refresh both panels
	if equipment_panel:
		equipment_panel.refresh_equipment()

	if inventory_panel:
		inventory_panel.refresh_inventory()

	print("[CharacterScreen] Opened")


func hide_character_screen():
	"""Hide the character screen"""
	visible = false
	screen_closed.emit()
	print("[CharacterScreen] Closed")


func _on_close_button_pressed():
	hide_character_screen()


func set_hero_id(hero_id: String):
	"""Set which hero's equipment to show"""
	if equipment_panel:
		equipment_panel.hero_id = hero_id
