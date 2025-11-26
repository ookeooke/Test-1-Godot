extends PanelContainer
class_name EquipmentSlot

## EquipmentSlot - Lightweight drop target for equipment paperdoll slots
##
## This class ONLY handles:
## 1. Drop target logic (equipment validation)
## 2. Drag-drop for equip/unequip operations via ItemTransactionService
##
## Item rendering is handled by ItemSprite overlay (same as inventory grids).
## For inventory grids, use InventoryGridSlot instead.

const DEBUG_DRAG_DROP = false

signal item_clicked(item: ItemInstance, slot: EquipmentSlot)
signal item_right_clicked(item: ItemInstance, slot: EquipmentSlot)

@export var slot_type: String = "equipment"
@export var equipment_filter: ItemData.EquipSlot = ItemData.EquipSlot.NONE
@export var equipment_slot_name: String = ""

var hero_id: String = ""
var item_instance: ItemInstance = null  # Reference only (ItemSprite renders it)
var is_empty: bool = true
var is_hovered: bool = false

# Grid coordinates (for positioning in InventoryGridContainer)
var grid_x: int = 0
var grid_y: int = 0


func _ready():
	custom_minimum_size = Vector2(80, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


## Set item reference (ItemSprite handles actual rendering)
func set_item(new_item: ItemInstance):
	item_instance = new_item
	is_empty = (new_item == null)


## Clear the slot reference
func clear_slot():
	item_instance = null
	is_empty = true


## Godot drag-and-drop: Get drag data
func _get_drag_data(_at_position: Vector2):
	if is_empty or not item_instance:
		return null

	TooltipManager.hide_tooltip()

	return {
		"item_id": item_instance.item_id,
		"uuid": item_instance.uuid,
		"item_instance": item_instance,
		"source_slot": self,
		"source_slot_type": slot_type,
		"source_hero_id": hero_id
	}


## Godot drag-and-drop: Check if can drop here
func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not data is Dictionary or not data.has("item_id"):
		return false

	# Don't drop on self
	if data.get("source_slot") == self:
		return false

	# Equipment slot validation
	var dragged_item = ItemDatabase.get_item(data.item_id)
	if dragged_item == null:
		AudioManager.play("error", 0.0)
		return false

	# Only allow items that match this equipment slot
	if dragged_item.equip_slot != equipment_filter:
		AudioManager.play("error", 0.0)
		return false

	modulate = Color(1.2, 1.2, 1.2)
	return true


## Godot drag-and-drop: Handle drop
func _drop_data(_at_position: Vector2, data):
	modulate = Color.WHITE

	if not _can_drop_data(_at_position, data):
		return

	var source_slot = data.get("source_slot")
	_handle_equipment_drop(data, source_slot)


func _handle_equipment_drop(data: Dictionary, source_slot):
	var source_slot_type = "inventory"
	var source_hero_id = ""

	if source_slot:
		source_slot_type = source_slot.slot_type if "slot_type" in source_slot else "inventory"
		source_hero_id = source_slot.hero_id if "hero_id" in source_slot else ""
	elif data.get("source_sprite"):
		source_slot_type = "inventory"
		source_hero_id = data.get("source_hero_id", "stash")

	var target_hero_id = hero_id if hero_id != "" else source_hero_id
	if target_hero_id == "":
		var parent = _find_parent_view()
		if parent and "hero_id" in parent:
			target_hero_id = parent.hero_id

	if target_hero_id == "":
		return

	# FROM inventory TO equipment (EQUIP)
	if source_slot_type == "inventory" and slot_type == "equipment":
		var slot_name = equipment_slot_name if equipment_slot_name != "" else _get_equipment_slot_name()
		if slot_name != "":
			ItemTransactionService.equip_item(target_hero_id, data.uuid, slot_name)
			AudioManager.play("equip", 0.1)

	# FROM equipment TO equipment (SWAP)
	elif source_slot_type == "equipment" and slot_type == "equipment":
		if source_slot and "equipment_slot_name" in source_slot:
			var source_slot_name = source_slot.equipment_slot_name
			var target_slot_name = equipment_slot_name if equipment_slot_name != "" else _get_equipment_slot_name()
			if source_slot_name != "" and target_slot_name != "":
				ItemTransactionService.unequip_item(target_hero_id, source_slot_name)
				ItemTransactionService.equip_item(target_hero_id, data.uuid, target_slot_name)
				AudioManager.play("equip", 0.1)


func _get_equipment_slot_name() -> String:
	match equipment_filter:
		ItemData.EquipSlot.WEAPON:
			return "hand_left"
		ItemData.EquipSlot.HELMET:
			return "helmet"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY:
			var parent = get_parent()
			if parent and "Accessory1" in parent.name:
				return "accessory_1"
			elif parent and "Accessory2" in parent.name:
				return "accessory_2"
			return "accessory_1"
	return ""


func _on_mouse_entered():
	is_hovered = true
	if not is_empty and item_instance:
		TooltipManager.show_tooltip(item_instance, self, hero_id)


func _on_mouse_exited():
	is_hovered = false
	TooltipManager.hide_tooltip()
	modulate = Color.WHITE


func _on_gui_input(event: InputEvent):
	InputDelegate.handle_gui_input(self, event, item_instance)


func _find_parent_view():
	var node = get_parent()
	while node:
		if node.has_method("_refresh_equipment"):
			return node
		node = node.get_parent()
	return null
