extends PanelContainer
class_name ItemSlot

## ItemSlot - UI element representing a single inventory slot
## Dual input system for PC and mobile:
## - PC: Hover for tooltip, drag-drop to move, right-click for context menu
## - Mobile: Tap to equip/use, long-press (0.5s) for context menu
## Built-in Godot tooltips work automatically on hover

signal item_clicked(item_id: String, slot: ItemSlot)
signal item_right_clicked(item_id: String, slot: ItemSlot)

@export var slot_index: int = 0
@export var slot_type: String = "inventory"  # "inventory", "equipment", "storage"
@export var equipment_filter: ItemData.EquipSlot = ItemData.EquipSlot.NONE  # For equipment slots
@export var equipment_slot_name: String = ""  # For equipment slots: "weapon", "armor", etc.


var hero_id: String = ""  # Set by EquipmentView for equipment slots
var item_id: String = ""
var item_data: ItemData = null
var quantity: int = 0
var upgrade_level: int = 0

# Multi-slot grid support (Diablo 2 style)
var grid_x: int = -1  ## Grid X coordinate (column)
var grid_y: int = -1  ## Grid Y coordinate (row)
var is_root_slot: bool = true  ## True if this is the top-left cell of a multi-slot item
var occupied_by_item_id: String = ""  ## If not root, stores the item_id occupying this cell

# UI References
@onready var icon: TextureRect = $MarginContainer/VBoxContainer/Icon if has_node("MarginContainer/VBoxContainer/Icon") else null
@onready var quantity_label: Label = $MarginContainer/VBoxContainer/QuantityLabel if has_node("MarginContainer/VBoxContainer/QuantityLabel") else null
@onready var upgrade_label: Label = $MarginContainer/VBoxContainer/UpgradeLabel if has_node("MarginContainer/VBoxContainer/UpgradeLabel") else null
@onready var rarity_border: Panel = $RarityBorder if has_node("RarityBorder") else null
@onready var margin_container: MarginContainer = $MarginContainer if has_node("MarginContainer") else null

var is_empty: bool = true
var is_hovered: bool = false

# Long-press detection for mobile
var touch_start_time: float = 0.0
var is_touch_held: bool = false
const LONG_PRESS_DURATION: float = 0.5  # 500ms


func _ready():
	# Set up custom minimum size for mobile-friendly touch targets
	# 80x80px exceeds Android Material Design 48dp minimum
	custom_minimum_size = Vector2(80, 80)

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	# Enable tooltip
	tooltip_text = ""

	# Update visual
	update_display()


func _restore_default_style():
	"""Restore default panel style by ALWAYS creating a fresh StyleBox instance.
	This prevents StyleBox reference sharing bugs across ItemSlot instances.
	Values match item_slot.tscn SubResource StyleBoxFlat_1."""
	var fresh_style = StyleBoxFlat.new()
	fresh_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	fresh_style.border_width_left = 2
	fresh_style.border_width_top = 2
	fresh_style.border_width_right = 2
	fresh_style.border_width_bottom = 2
	fresh_style.border_color = Color(0.5, 0.5, 0.5, 1)
	fresh_style.corner_radius_top_left = 4
	fresh_style.corner_radius_top_right = 4
	fresh_style.corner_radius_bottom_right = 4
	fresh_style.corner_radius_bottom_left = 4
	add_theme_stylebox_override("panel", fresh_style)


## Set item in this slot
func set_item(new_item_id: String, new_quantity: int = 1, new_upgrade_level: int = 0):
	item_id = new_item_id
	quantity = new_quantity
	upgrade_level = new_upgrade_level

	if item_id == "":
		clear_slot()
		return

	# Load item data
	item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		print("[ItemSlot] Error: Invalid item_id: ", item_id)
		clear_slot()
		return

	is_empty = false

	# MULTI-CELL STRETCHING: Resize slot to span multiple grid cells (Diablo 2 style)
	if is_root_slot and item_data.inventory_width > 0 and item_data.inventory_height > 0:
		var slot_width = 80  # Base slot size
		var slot_height = 80
		var grid_gap = 5  # Gap between grid cells (from inventory_view.tscn)

		# Calculate total size: (slots × base_size) + (gaps × (slots - 1))
		var total_width = (item_data.inventory_width * slot_width) + ((item_data.inventory_width - 1) * grid_gap)
		var total_height = (item_data.inventory_height * slot_height) + ((item_data.inventory_height - 1) * grid_gap)

		custom_minimum_size = Vector2(total_width, total_height)
		size = Vector2(total_width, total_height)

		# Set higher z_index so multi-cell items render on top
		z_index = 10

		# DIABLO 2 STYLE: Hide panel styling for multi-cell items
		# Show ONLY the icon (no border, no background)
		var transparent_style = StyleBoxFlat.new()
		transparent_style.bg_color = Color(0, 0, 0, 0)  # Fully transparent
		transparent_style.border_width_left = 0
		transparent_style.border_width_top = 0
		transparent_style.border_width_right = 0
		transparent_style.border_width_bottom = 0
		add_theme_stylebox_override("panel", transparent_style)

		# Remove margins so icon fills entire area
		if margin_container:
			margin_container.add_theme_constant_override("margin_left", 0)
			margin_container.add_theme_constant_override("margin_top", 0)
			margin_container.add_theme_constant_override("margin_right", 0)
			margin_container.add_theme_constant_override("margin_bottom", 0)
	else:
		# Reset to default size for single-cell items
		custom_minimum_size = Vector2(80, 80)
		z_index = 0

		# Restore default panel styling (uses cached style for consistency)
		_restore_default_style()

		# Restore default margins
		if margin_container:
			margin_container.add_theme_constant_override("margin_left", 4)
			margin_container.add_theme_constant_override("margin_top", 4)
			margin_container.add_theme_constant_override("margin_right", 4)
			margin_container.add_theme_constant_override("margin_bottom", 4)

	update_display()


## Clear the slot
func clear_slot():
	item_id = ""
	item_data = null
	quantity = 0
	upgrade_level = 0
	is_empty = true

	# Reset size to default
	custom_minimum_size = Vector2(80, 80)
	z_index = 0

	# Restore default panel styling (uses cached style for consistency)
	_restore_default_style()

	# Restore default margins
	if margin_container:
		margin_container.add_theme_constant_override("margin_left", 4)
		margin_container.add_theme_constant_override("margin_top", 4)
		margin_container.add_theme_constant_override("margin_right", 4)
		margin_container.add_theme_constant_override("margin_bottom", 4)

	update_display()


## Update the visual display
func update_display():
	# ALWAYS clear old emoji labels first to prevent visual bugs
	_clear_emoji_label()

	# Handle occupied (non-root) slots - HIDE THEM COMPLETELY (Diablo 2 style)
	if not is_root_slot and occupied_by_item_id != "":
		# This slot is occupied by a multi-slot item - hide it
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE  # Can't interact with occupied slots
		return
	else:
		# Re-show if this slot is no longer occupied
		visible = true

	# Re-enable mouse input for non-occupied slots
	mouse_filter = Control.MOUSE_FILTER_STOP

	if is_empty or item_data == null:
		# Empty slot
		if icon:
			icon.texture = null
		if quantity_label:
			quantity_label.text = ""
		if upgrade_label:
			upgrade_label.text = ""
		if rarity_border:
			rarity_border.modulate = Color(1, 1, 1, 0)  # Transparent
		modulate = Color(1, 1, 1, 0.5)  # Dim empty slots
		tooltip_text = ""
		return

	# Item is present
	modulate = Color.WHITE

	# Set icon (texture or emoji)
	if icon:
		if item_data.icon:
			# Use texture icon if available
			icon.texture = item_data.icon
		elif item_data.emoji != "":
			# Use emoji as fallback - create a temporary label to show it
			icon.texture = null
			_show_emoji_in_icon(item_data.emoji)
		else:
			# No icon at all
			icon.texture = null

	# Set quantity label (only for stackable items)
	if quantity_label:
		if item_data.is_stackable() and quantity > 1:
			quantity_label.text = str(quantity)
		else:
			quantity_label.text = ""

	# Set upgrade level label (only for upgradeable items)
	if upgrade_label:
		if item_data.can_upgrade and upgrade_level > 0:
			upgrade_label.text = "+%d" % upgrade_level
		else:
			upgrade_label.text = ""

	# Set rarity border color
	if rarity_border:
		rarity_border.modulate = item_data.get_rarity_color()

	# Update tooltip with comparison
	tooltip_text = _generate_tooltip()


## Godot drag-and-drop: Get drag data
func _get_drag_data(at_position: Vector2):
	if is_empty:
		return null

	# Create drag preview
	var preview = TextureRect.new()
	preview.texture = item_data.icon if item_data.icon else null
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.8)  # Semi-transparent
	set_drag_preview(preview)

	# Return drag data
	return {
		"item_id": item_id,
		"quantity": quantity,
		"upgrade_level": upgrade_level,
		"source_slot": self,
		"source_slot_type": slot_type
	}


## Godot drag-and-drop: Check if can drop here
func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false

	if not data.has("item_id"):
		return false

	# Don't drop on self
	if data.get("source_slot") == self:
		return false

	# Can't drop on occupied (non-root) slots
	if not is_root_slot and occupied_by_item_id != "":
		return false

	# For inventory slots, use spatial grid validation
	if slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		# Check if item can be placed at this grid position
		if not InventoryManager.can_place_item(data.item_id, grid_x, grid_y):
			return false

	# Check equipment slot filter
	if slot_type == "equipment" and equipment_filter != ItemData.EquipSlot.NONE:
		var dragged_item = ItemDatabase.get_item(data.item_id)
		if dragged_item == null:
			return false

		# Only allow items that match this equipment slot
		if dragged_item.equip_slot != equipment_filter:
			return false

	return true


## Godot drag-and-drop: Handle drop
func _drop_data(at_position: Vector2, data):
	if not _can_drop_data(at_position, data):
		return

	var source_slot = data.get("source_slot") as ItemSlot
	if source_slot == null:
		return

	# Special handling for equipment slots
	if slot_type == "equipment" or source_slot.slot_type == "equipment":
		_handle_equipment_drop(data, source_slot)
		return

	# For inventory slots with grid coordinates, use spatial placement
	if slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		# Move item in InventoryManager's spatial grid
		if InventoryManager.move_item(data.item_id, grid_x, grid_y):
			# Trigger refresh of inventory view
			InventoryManager.inventory_changed.emit()
		return

	# Fallback: Normal inventory swap (for non-spatial inventory modes)
	var temp_item_id = item_id
	var temp_quantity = quantity
	var temp_upgrade_level = upgrade_level

	# Set this slot to the dragged item
	set_item(data.item_id, data.quantity, data.upgrade_level)

	# Set source slot to this slot's previous item (may be empty)
	if temp_item_id != "":
		source_slot.set_item(temp_item_id, temp_quantity, temp_upgrade_level)
	else:
		source_slot.clear_slot()



func _handle_equipment_drop(data: Dictionary, source_slot: ItemSlot):
	"""Handle dropping to/from equipment slots using atomic transactions"""
	# Get hero_id from equipment slot (set by EquipmentView)
	var target_hero_id = hero_id if slot_type == "equipment" else source_slot.hero_id
	
	if target_hero_id == "":
		return

	# Dragging FROM inventory TO equipment (EQUIP)
	if source_slot.slot_type == "inventory" and slot_type == "equipment":
		var slot_name = equipment_slot_name if equipment_slot_name != "" else _get_equipment_slot_name()
		if slot_name != "":
			if InventoryManager.equip_item_atomic(target_hero_id, slot_name, data.item_id):
				pass  # Success - transaction handles all logic
			else:
				pass  # Failure - transaction rolled back

	# Dragging FROM equipment TO inventory (UNEQUIP)
	elif source_slot.slot_type == "equipment" and slot_type == "inventory":
		var slot_name = source_slot.equipment_slot_name if source_slot.equipment_slot_name != "" else source_slot._get_equipment_slot_name()
		if slot_name != "":
			if InventoryManager.unequip_item_atomic(target_hero_id, slot_name):
				pass  # Success
			else:
				pass  # Failure

	# Dragging between equipment slots (SWAP)
	elif source_slot.slot_type == "equipment" and slot_type == "equipment":
		var source_slot_name = source_slot.equipment_slot_name if source_slot.equipment_slot_name != "" else source_slot._get_equipment_slot_name()
		var target_slot_name = equipment_slot_name if equipment_slot_name != "" else _get_equipment_slot_name()

		if source_slot_name != "" and target_slot_name != "":
			# Atomic swap: unequip from source, equip to target
			if InventoryManager.unequip_item_atomic(target_hero_id, source_slot_name):
				if InventoryManager.equip_item_atomic(target_hero_id, target_slot_name, data.item_id):
					pass  # Success
				else:
					pass  # Equip failed
			else:
				pass  # Unequip failed


func _get_equipment_slot_name() -> String:
	"""Get the equipment slot name based on filter"""
	match equipment_filter:
		ItemData.EquipSlot.WEAPON:
			return "weapon"
		ItemData.EquipSlot.ARMOR:
			return "armor"
		ItemData.EquipSlot.ACCESSORY:
			# Need to determine which accessory slot
			var parent = get_parent()
			if parent and parent.name == "Accessory1Container":
				return "accessory_1"
			elif parent and parent.name == "Accessory2Container":
				return "accessory_2"
			return "accessory_1"
	return ""


## Handle mouse enter
func _on_mouse_entered():
	is_hovered = true

	if not is_empty:
		# Scale up slightly
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)


## Handle mouse exit
func _on_mouse_exited():
	is_hovered = false

	# Scale back to normal
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)


## Handle GUI input (clicks)
func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if not is_empty:
					item_clicked.emit(item_id, self)
					accept_event()  # Prevent click from reaching world
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if not is_empty:
					item_right_clicked.emit(item_id, self)
					accept_event()  # Prevent click from reaching world

	elif event is InputEventScreenTouch:
		if event.pressed:
			# Touch started - begin long-press timer
			if not is_empty:
				touch_start_time = Time.get_ticks_msec() / 1000.0
				is_touch_held = true
		else:
			# Touch released
			if is_touch_held:
				var hold_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time

				if hold_duration >= LONG_PRESS_DURATION:
					# Long press detected - trigger right-click action (context menu)
					if not is_empty:
						item_right_clicked.emit(item_id, self)
				else:
					# Short tap - trigger normal click (auto-equip)
					if not is_empty:
						item_clicked.emit(item_id, self)

				is_touch_held = false
				accept_event()  # Prevent tap from reaching world


## Generate tooltip with item comparison
func _generate_tooltip() -> String:
	if not item_data:
		return ""

	var tooltip = ""

	# Item name with rarity color
	var rarity_name = item_data.get_rarity_name()
	tooltip += "%s (%s)\n" % [item_data.item_name, rarity_name]
	tooltip += "───────────\n"

	# Equip slot (if equipment) - skip item type, it's redundant
	if _is_equipment_type(item_data.item_type):
		var slot_name = _get_equip_slot_name(item_data.equip_slot)
		tooltip += "Slot: %s\n" % slot_name
		tooltip += "───────────\n"
	else:
		# For non-equipment, show type
		var type_name = _get_item_type_name(item_data.item_type)
		tooltip += "%s\n" % type_name
		tooltip += "───────────\n"

	# Stats (for equipment)
	if _is_equipment_type(item_data.item_type):
		tooltip += _format_stat_line("Damage", item_data.damage_bonus)
		tooltip += _format_stat_line("Health", item_data.health_bonus)
		tooltip += _format_stat_line("Defense", item_data.defense_bonus)
		tooltip += _format_stat_line("Range", item_data.range_bonus)

		if item_data.attack_speed_multiplier != 1.0:
			var bonus_percent = (item_data.attack_speed_multiplier - 1.0) * 100
			tooltip += "Attack Speed: %+.0f%%\n" % bonus_percent

		if item_data.crit_chance_bonus > 0:
			tooltip += "Crit Chance: +%.1f%%\n" % (item_data.crit_chance_bonus * 100)

		# Add comparison if not in equipment slot and item can be equipped
		if slot_type == "inventory":
			tooltip += _generate_comparison()

	# Sell value
	tooltip += "───────────\n"
	tooltip += "Sell: %d gold\n" % item_data.sell_value

	return tooltip


func _format_stat_line(stat_name: String, value: int) -> String:
	"""Format a stat line, hiding if value is 0"""
	if value == 0:
		return ""
	return "%s: +%d\n" % [stat_name, value]


func _generate_comparison() -> String:
	"""Generate comparison section with equipped item"""
	if not item_data or not _is_equipment_type(item_data.item_type):
		return ""

	# Get hero_id from parent view (if available)
	if not hero_id or hero_id == "":
		return ""  # Can't compare without knowing which hero

	# Convert equip slot enum to string slot name
	var slot_name = ""
	match item_data.equip_slot:
		ItemData.EquipSlot.WEAPON:
			slot_name = "weapon"
		ItemData.EquipSlot.ARMOR:
			slot_name = "armor"
		ItemData.EquipSlot.ACCESSORY:
			slot_name = "accessory_1"  # Default to first accessory slot for comparison

	# Get equipped item from registry
	var equipped_item_id = HeroEquipmentRegistry.get_equipped_item(hero_id, slot_name)
	if equipped_item_id == "":
		return "\n───────────\nNo item equipped\n"

	var equipped_item = ItemDatabase.get_item(equipped_item_id)
	if not equipped_item:
		return ""

	# Generate comparison
	var comparison = "\n───────────\n"
	comparison += "VS EQUIPPED:\n"

	comparison += _compare_stat("Damage", item_data.damage_bonus, equipped_item.damage_bonus)
	comparison += _compare_stat("Health", item_data.health_bonus, equipped_item.health_bonus)
	comparison += _compare_stat("Defense", item_data.defense_bonus, equipped_item.defense_bonus)
	comparison += _compare_stat("Range", item_data.range_bonus, equipped_item.range_bonus)

	# Attack speed comparison
	if item_data.attack_speed_multiplier != equipped_item.attack_speed_multiplier:
		var diff = (item_data.attack_speed_multiplier - equipped_item.attack_speed_multiplier) * 100
		var color = "green" if diff > 0 else "red" if diff < 0 else "gray"
		comparison += "[color=%s]Attack Speed: %+.0f%%[/color]\n" % [color, diff]

	# Crit chance comparison
	if item_data.crit_chance_bonus != equipped_item.crit_chance_bonus:
		var diff = (item_data.crit_chance_bonus - equipped_item.crit_chance_bonus) * 100
		var color = "green" if diff > 0 else "red" if diff < 0 else "gray"
		comparison += "[color=%s]Crit Chance: %+.1f%%[/color]\n" % [color, diff]

	return comparison


func _compare_stat(stat_name: String, new_value: int, old_value: int) -> String:
	"""Compare stat values and return colored string"""
	if new_value == old_value:
		return ""

	var diff = new_value - old_value
	var color = "green" if diff > 0 else "red"

	return "[color=%s]%s: %+d[/color]\n" % [color, stat_name, diff]


func _is_equipment_type(type: ItemData.ItemType) -> bool:
	"""Check if item type is equipment"""
	return type == ItemData.ItemType.WEAPON or type == ItemData.ItemType.ARMOR


func _get_item_type_name(type: ItemData.ItemType) -> String:
	"""Get human-readable item type name"""
	match type:
		ItemData.ItemType.WEAPON:
			return "Weapon"
		ItemData.ItemType.ARMOR:
			return "Armor"
		ItemData.ItemType.CURRENCY:
			return "Currency"
	return "Unknown"


func _get_equip_slot_name(slot: ItemData.EquipSlot) -> String:
	"""Get human-readable equip slot name"""
	match slot:
		ItemData.EquipSlot.WEAPON:
			return "Weapon"
		ItemData.EquipSlot.ARMOR:
			return "Armor"
		ItemData.EquipSlot.ACCESSORY:
			return "Accessory"
	return "Unknown"


func _clear_emoji_label():
	"""Remove any existing emoji label immediately"""
	if icon and icon.has_node("EmojiLabel"):
		var old_label = icon.get_node("EmojiLabel")
		icon.remove_child(old_label)
		old_label.queue_free()


func _show_emoji_in_icon(emoji_text: String):
	"""Display emoji symbol in the icon slot when no texture is available"""
	# Create label to show emoji
	var emoji_label = Label.new()
	emoji_label.name = "EmojiLabel"
	emoji_label.text = emoji_text
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 48)  # Large emoji
	emoji_label.anchors_preset = Control.PRESET_FULL_RECT
	emoji_label.z_index = 10  # Above icon texture rect

	icon.add_child(emoji_label)
