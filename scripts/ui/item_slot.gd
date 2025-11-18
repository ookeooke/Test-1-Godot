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
var rolled_affixes: Dictionary = {}  # Stores rolled affixes for magic/rare items (Diablo 2 style)

# Multi-slot grid support (Diablo 2 style)
var grid_x: int = -1  ## Grid X coordinate (column)
var grid_y: int = -1  ## Grid Y coordinate (row)
var is_root_slot: bool = true  ## True if this is the top-left cell of a multi-slot item
var occupied_by_item_id: String = ""  ## If not root, stores the item_id occupying this cell

# Cached theme style (prevents color trail artifacts)
var _original_panel_style: StyleBox = null

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

	# Cache original theme style to prevent color trail artifacts
	var theme_style = get_theme_stylebox("panel")
	if theme_style:
		_original_panel_style = theme_style.duplicate()

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	# Enable tooltip
	tooltip_text = ""

	# Update visual
	update_display()


func _restore_default_style():
	"""Restore original theme panel style using cached style.
	Fixes bow color trail bug by restoring actual theme instead of hard-coded colors."""
	if _original_panel_style:
		# Use cached original style (prevents color trail artifacts)
		add_theme_stylebox_override("panel", _original_panel_style.duplicate())
	else:
		# Fallback: Remove override to use default theme
		remove_theme_stylebox_override("panel")


## Set item in this slot
func set_item(new_item_id: String, new_quantity: int = 1, new_upgrade_level: int = 0, new_rolled_affixes: Dictionary = {}):
	item_id = new_item_id
	quantity = new_quantity
	upgrade_level = new_upgrade_level
	rolled_affixes = new_rolled_affixes

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
	print("[ItemSlot] 🎯 _get_drag_data called - item_id: %s, is_empty: %s, slot_type: %s, grid_pos: (%d,%d)" % [item_id, is_empty, slot_type, grid_x, grid_y])

	if is_empty:
		print("[ItemSlot] ❌ Slot is empty, canceling drag")
		return null

	# Create drag preview
	var preview = TextureRect.new()
	preview.texture = item_data.icon if item_data.icon else null
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.8)  # Semi-transparent
	set_drag_preview(preview)

	print("[ItemSlot] ✅ Drag data created for item: %s" % item_id)

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
	print("[ItemSlot] 🔍 _can_drop_data - target slot: (%d,%d), slot_type: %s, is_root: %s" % [grid_x, grid_y, slot_type, is_root_slot])

	if not data is Dictionary:
		print("[ItemSlot] ❌ Data is not Dictionary")
		return false

	if not data.has("item_id"):
		print("[ItemSlot] ❌ Data missing item_id")
		return false

	print("[ItemSlot] Checking drop for item: %s" % data.item_id)

	# Don't drop on self
	if data.get("source_slot") == self:
		print("[ItemSlot] ❌ Cannot drop on self")
		return false

	# Can't drop on occupied (non-root) slots
	if not is_root_slot and occupied_by_item_id != "":
		print("[ItemSlot] ❌ Slot occupied by: %s (non-root)" % occupied_by_item_id)
		return false

	# For inventory slots, use spatial grid validation
	if slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		# Determine which inventory manager to use
		var parent_view = _find_parent_inventory_view()
		var using_hero_inventory = false

		# Priority 1: Check if EquipmentView in common chest mode (uses shared stash)
		if parent_view and "common_chest_mode" in parent_view and parent_view.common_chest_mode:
			using_hero_inventory = false
		# Priority 2: Check if InventoryView (has hero_id, uses hero inventory)
		elif parent_view and "hero_id" in parent_view and parent_view.hero_id != "":
			using_hero_inventory = true
		else:
			using_hero_inventory = false  # Fallback to shared stash

		# Check if item can be placed at this grid position
		var can_place = false
		if using_hero_inventory:
			# For hero inventory, we can't validate without modifying HeroInventoryManager
			# Let the drop operation handle validation via set_grid_position()
			can_place = true  # Optimistic validation - actual validation happens in _drop_data
			print("[ItemSlot] Grid validation: hero inventory (optimistic)")
		else:
			# For shared stash, use InventoryManager validation
			can_place = InventoryManager.can_place_item(data.item_id, grid_x, grid_y)
			print("[ItemSlot] Grid validation: shared stash can_place = %s" % can_place)

		if not can_place:
			return false

	# Check equipment slot filter
	if slot_type == "equipment" and equipment_filter != ItemData.EquipSlot.NONE:
		var dragged_item = ItemDatabase.get_item(data.item_id)
		if dragged_item == null:
			print("[ItemSlot] ❌ Invalid item in database")
			return false

		# Only allow items that match this equipment slot
		if dragged_item.equip_slot != equipment_filter:
			print("[ItemSlot] ❌ Item type mismatch for equipment slot")
			return false

	print("[ItemSlot] ✅ Drop validation passed")
	return true


## Godot drag-and-drop: Handle drop
func _drop_data(at_position: Vector2, data):
	print("[ItemSlot] 📥 _drop_data called - item: %s to slot (%d,%d)" % [data.get("item_id"), grid_x, grid_y])

	if not _can_drop_data(at_position, data):
		print("[ItemSlot] ❌ Drop validation failed")
		return

	var source_slot = data.get("source_slot") as ItemSlot
	if source_slot == null:
		print("[ItemSlot] ❌ No source slot in data")
		return

	print("[ItemSlot] Source slot: (%d,%d), type: %s" % [source_slot.grid_x, source_slot.grid_y, source_slot.slot_type])

	# Special handling for equipment slots
	if slot_type == "equipment" or source_slot.slot_type == "equipment":
		print("[ItemSlot] → Routing to equipment drop handler")
		_handle_equipment_drop(data, source_slot)
		return

	# Detect cross-panel transfers by checking if source and target are in different views
	var target_parent_view = _find_parent_inventory_view()
	var source_parent_view = source_slot._find_parent_inventory_view() if source_slot else null

	# Cross-panel transfer detection:
	# - Source and target must be in different views
	# - At least one must be EquipmentView (has _refresh_shared_stash method)
	# - At least one must be InventoryView (has _refresh_inventory method)
	var is_cross_panel_transfer = false

	if target_parent_view and source_parent_view and target_parent_view != source_parent_view:
		var source_is_equipment = source_parent_view.has_method("_refresh_shared_stash")
		var target_is_equipment = target_parent_view.has_method("_refresh_shared_stash")
		var source_is_inventory = source_parent_view.has_method("_refresh_inventory")
		var target_is_inventory = target_parent_view.has_method("_refresh_inventory")

		# Cross-panel if one is EquipmentView and other is InventoryView
		is_cross_panel_transfer = (source_is_equipment and target_is_inventory) or \
		                           (source_is_inventory and target_is_equipment)

	print("[ItemSlot] Cross-panel transfer detected: %s (source: %s, target: %s)" % [is_cross_panel_transfer, source_parent_view != null, target_parent_view != null])

	if is_cross_panel_transfer:
		print("[ItemSlot] → Routing to dual grid drop handler (cross-panel transfer)")
		_handle_dual_grid_drop(data, source_slot, target_parent_view)
		return

	# For inventory slots with grid coordinates, use spatial placement
	if slot_type == "inventory" and grid_x >= 0 and grid_y >= 0:
		print("[ItemSlot] → Spatial grid mode: moving item to (%d,%d)" % [grid_x, grid_y])

		# Reuse target_parent_view from line 370 (already found above)
		# Determine which inventory manager to use
		var using_hero_inventory = false
		var target_hero_id = ""

		# Priority 1: Check if EquipmentView in common chest mode (uses shared stash)
		if target_parent_view and "common_chest_mode" in target_parent_view and target_parent_view.common_chest_mode:
			using_hero_inventory = false
		# Priority 2: Check if InventoryView (has hero_id, uses hero inventory)
		elif target_parent_view and "hero_id" in target_parent_view and target_parent_view.hero_id != "":
			using_hero_inventory = true
			target_hero_id = target_parent_view.hero_id
		else:
			using_hero_inventory = false  # Fallback to shared stash

		var success = false
		if using_hero_inventory:
			# Use HeroInventoryManager for per-hero inventory
			print("[ItemSlot] Using HeroInventoryManager for hero '%s'" % target_hero_id)
			success = HeroInventoryManager.set_grid_position(target_hero_id, data.item_id, grid_x, grid_y)
			print("[ItemSlot] Hero inventory move result: %s" % ("SUCCESS" if success else "FAILED"))
		else:
			# Use InventoryManager for shared stash
			print("[ItemSlot] Using InventoryManager (shared stash)")
			success = InventoryManager.move_item(data.item_id, grid_x, grid_y)
			print("[ItemSlot] Shared stash move result: %s" % ("SUCCESS" if success else "FAILED"))

		return

	# Fallback: Normal inventory swap (for non-spatial inventory modes)
	print("[ItemSlot] → Fallback swap mode")
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
					# Shift+Click for context menu (web compatibility)
					if event.shift_pressed:
						item_right_clicked.emit(item_id, self)
					else:
						item_clicked.emit(item_id, self)
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


## Generate tooltip (Diablo 2 style)
func _generate_tooltip() -> String:
	if not item_data:
		return ""

	var tooltip = ""

	# Item name (first line)
	tooltip += "%s\n" % item_data.item_name

	# Rarity + Type (second line)
	var rarity_name = item_data.get_rarity_name()
	if _is_equipment_type(item_data.item_type):
		var type_name = _get_item_type_name(item_data.item_type)
		tooltip += "%s %s\n" % [rarity_name, type_name]
	else:
		tooltip += "%s\n" % rarity_name

	tooltip += "───────────\n"

	# Stats (for equipment)
	if _is_equipment_type(item_data.item_type):
		# Show base item stats (affixes will be shown separately in Phase 6)
		var display_damage = item_data.damage_bonus
		var display_health = item_data.health_bonus
		var display_defense = item_data.defense_bonus
		var display_range = item_data.range_bonus
		var display_attack_speed = item_data.attack_speed_multiplier
		var display_crit = item_data.crit_chance_bonus

		# Show rolled range if item has random stats (legacy system - will be replaced with affix display in Phase 6)
		if item_data.has_random_stats and false:  # Temporarily disabled - Phase 6 will add proper affix tooltips
			tooltip += _format_stat_with_range("Damage", display_damage, item_data.damage_range)
			tooltip += _format_stat_with_range("Health", display_health, item_data.health_range)
			tooltip += _format_stat_with_range("Defense", display_defense, item_data.defense_range)
			tooltip += _format_stat_line("Range", display_range)  # Range bonus has no random range

			if display_attack_speed != 1.0:
				var bonus_percent = (display_attack_speed - 1.0) * 100
				var range_text = ""
				if item_data.attack_speed_range.x > 0.0 or item_data.attack_speed_range.y > 0.0:
					var min_pct = (item_data.attack_speed_range.x - 1.0) * 100
					var max_pct = (item_data.attack_speed_range.y - 1.0) * 100
					range_text = " (%.0f%%-%.0f%%)" % [min_pct, max_pct]
				tooltip += "%+.0f%% Attack Speed%s\n" % [bonus_percent, range_text]

			if display_crit > 0:
				var crit_pct = display_crit * 100
				var range_text = ""
				if item_data.crit_chance_range.x > 0.0 or item_data.crit_chance_range.y > 0.0:
					var min_pct = item_data.crit_chance_range.x * 100
					var max_pct = item_data.crit_chance_range.y * 100
					range_text = " (%.1f%%-%.1f%%)" % [min_pct, max_pct]
				tooltip += "+%.1f%% Critical Strike%s\n" % [crit_pct, range_text]
		else:
			# Fixed stats (no random rolls)
			tooltip += _format_stat_line("Damage", display_damage)
			tooltip += _format_stat_line("Health", display_health)
			tooltip += _format_stat_line("Defense", display_defense)
			tooltip += _format_stat_line("Range", display_range)

			if display_attack_speed != 1.0:
				var bonus_percent = (display_attack_speed - 1.0) * 100
				tooltip += "%+.0f%% Attack Speed\n" % bonus_percent

			if display_crit > 0:
				tooltip += "+%.1f%% Critical Strike\n" % (display_crit * 100)

	# Item level / Requirements
	var has_level_info = false
	if item_data.item_level > 0 or item_data.required_level > 0:
		tooltip += "───────────\n"
		has_level_info = true
		if item_data.item_level > 0:
			tooltip += "Item Level: %d\n" % item_data.item_level
		if item_data.required_level > 0:
			tooltip += "Requires Level %d\n" % item_data.required_level

	# Sell value
	if has_level_info:
		tooltip += "───────────\n"
	else:
		tooltip += "───────────\n"
	tooltip += "Sell Value: %d Gold\n" % item_data.sell_value

	return tooltip


func _format_stat_line(stat_name: String, value: int) -> String:
	"""Format a stat line (Diablo 2 style - value first), hiding if value is 0"""
	if value == 0:
		return ""
	return "+%d %s\n" % [value, stat_name]


func _format_stat_with_range(stat_name: String, value: int, range: Vector2i) -> String:
	"""Format a stat line showing rolled value with possible range (Diablo 2 style - value first)"""
	if value == 0:
		return ""

	# Show range if available (min-max differs)
	if range.x > 0 and range.y > range.x:
		return "+%d %s (%d-%d)\n" % [value, stat_name, range.x, range.y]
	else:
		return "+%d %s\n" % [value, stat_name]


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


func _find_parent_inventory_view():
	"""Find parent InventoryView or EquipmentView instance

	NOTE: get_class() returns ENGINE class names ("Control"), NOT script class names!
	Instead, we identify views by their unique method signatures:
	- InventoryView has: _refresh_inventory(), set_hero_id(new_hero_id)
	- EquipmentView has: _refresh_equipment(), _refresh_shared_stash()
	"""
	print("[ItemSlot] 🔎 Searching for parent inventory view...")
	var parent = get_parent()
	var depth = 0
	while parent:
		depth += 1
		print("[ItemSlot]   Depth %d: %s (class: %s)" % [depth, parent.name, parent.get_class()])

		# Check for InventoryView by unique methods
		if parent.has_method("_refresh_inventory"):
			print("[ItemSlot] ✅ Found InventoryView by method signature (_refresh_inventory)")
			return parent

		# Check for EquipmentView by unique methods
		if parent.has_method("_refresh_equipment") or parent.has_method("_refresh_shared_stash"):
			print("[ItemSlot] ✅ Found EquipmentView by method signature (_refresh_equipment/_refresh_shared_stash)")
			return parent

		# Fallback: check by node name (less reliable but works for standard scene structure)
		if "InventoryView" in parent.name or "EquipmentView" in parent.name:
			print("[ItemSlot] ✅ Found view by node name: %s" % parent.name)
			return parent

		parent = parent.get_parent()
	print("[ItemSlot] ❌ No parent view found")
	return null


func _find_both_panel_views() -> Dictionary:
	"""Find both EquipmentView and InventoryView from DualPanelScreen for cross-panel transfers

	Uses group lookup (same proven pattern as InventoryView._get_hero_id_from_equipment_view)
	NOTE: get_class() returns ENGINE class names ("Control"), NOT script class names ("DualPanelScreen")!
	"""
	var result = {
		"equipment_view": null,
		"inventory_view": null
	}

	# Check if scene tree is available
	if not get_tree():
		print("[ItemSlot] ❌ No scene tree available")
		return result

	# Use group lookup - DualPanelScreen adds itself to "dual_panel_screen" group (line 35 in dual_panel_screen.gd)
	var dual_panels = get_tree().get_nodes_in_group("dual_panel_screen")
	if dual_panels.size() == 0:
		print("[ItemSlot] ❌ No DualPanelScreen found in 'dual_panel_screen' group")
		return result

	var dual_panel = dual_panels[0]
	print("[ItemSlot] ✅ Found DualPanelScreen via group: %s" % dual_panel.name)

	# Get left panel (EquipmentView)
	if dual_panel.has_method("get_left_panel"):
		var left_panel = dual_panel.get_left_panel()
		print("[ItemSlot]   Left panel found: %s" % (left_panel != null))
		if left_panel and left_panel.has_method("get_current_view"):
			var view = left_panel.get_current_view()
			if view:
				print("[ItemSlot]   Left panel current view: %s" % view.name)
				result["equipment_view"] = view
			else:
				print("[ItemSlot]   ⚠️ Left panel has no current view")
		else:
			print("[ItemSlot]   ⚠️ Left panel has no get_current_view() method")
	else:
		print("[ItemSlot] ❌ DualPanelScreen has no get_left_panel() method")

	# Get right panel (InventoryView)
	if dual_panel.has_method("get_right_panel"):
		var right_panel = dual_panel.get_right_panel()
		print("[ItemSlot]   Right panel found: %s" % (right_panel != null))
		if right_panel and right_panel.has_method("get_current_view"):
			var view = right_panel.get_current_view()
			if view:
				print("[ItemSlot]   Right panel current view: %s" % view.name)
				result["inventory_view"] = view
			else:
				print("[ItemSlot]   ⚠️ Right panel has no current view")
		else:
			print("[ItemSlot]   ⚠️ Right panel has no get_current_view() method")
	else:
		print("[ItemSlot] ❌ DualPanelScreen has no get_right_panel() method")

	print("[ItemSlot] Final result - equipment_view: %s, inventory_view: %s" % [
		result["equipment_view"] != null,
		result["inventory_view"] != null
	])

	return result


func _handle_dual_grid_drop(data: Dictionary, source_slot: ItemSlot, inventory_view):
	"""Handle drag-drop in common chest mode (shared stash or dual grids)"""
	print("[ItemSlot] 🔄 _handle_dual_grid_drop called")
	print("[ItemSlot]   Item: %s, Source: (%d,%d), Target: (%d,%d)" % [data.item_id, source_slot.grid_x, source_slot.grid_y, grid_x, grid_y])

	# FIRST: Check for cross-panel transfers (EquipmentView <-> InventoryView)
	print("[ItemSlot] 🔍 Checking for cross-panel transfer scenario...")
	var both_views = _find_both_panel_views()
	var equipment_view = both_views["equipment_view"]
	var inventory_view_right = both_views["inventory_view"]

	if equipment_view and inventory_view_right:
		print("[ItemSlot]   Found both views - equipment_view: %s, inventory_view: %s" % [equipment_view != null, inventory_view_right != null])

		# Check if source is in EquipmentView's shared stash
		var source_in_equipment_stash = false
		if "stash_item_slots" in equipment_view and equipment_view.stash_item_slots.size() > 0:
			source_in_equipment_stash = source_slot in equipment_view.stash_item_slots

		# Check if target is in InventoryView's hero inventory
		var target_in_inventory = false
		if "item_slots" in inventory_view_right and inventory_view_right.item_slots.size() > 0:
			target_in_inventory = self in inventory_view_right.item_slots

		print("[ItemSlot]   source_in_equipment_stash: %s, target_in_inventory: %s" % [source_in_equipment_stash, target_in_inventory])

		# CROSS-PANEL TRANSFER: Shared Stash (LEFT) → Hero Inventory (RIGHT)
		if source_in_equipment_stash and target_in_inventory:
			print("[ItemSlot] 🔄 CROSS-PANEL TRANSFER DETECTED: Shared Stash → Hero Inventory")
			var target_hero_id = inventory_view_right.hero_id
			print("[ItemSlot]   Target hero_id: %s" % target_hero_id)

			if target_hero_id != "":
				var success = HeroInventoryManager.transfer_from_shared_stash(target_hero_id, data.item_id, data.quantity)
				if success:
					print("[ItemSlot] ✅ Transfer to hero inventory succeeded")
					# Set grid position in hero inventory
					HeroInventoryManager.set_grid_position(target_hero_id, data.item_id, grid_x, grid_y)
					print("[ItemSlot] ✅ Grid position set to (%d,%d)" % [grid_x, grid_y])
				else:
					print("[ItemSlot] ❌ Transfer to hero inventory failed")
			else:
				print("[ItemSlot] ❌ Target hero_id is empty")
			return

		# Check reverse: Hero Inventory (RIGHT) → Shared Stash (LEFT)
		var source_in_inventory = false
		if "item_slots" in inventory_view_right and inventory_view_right.item_slots.size() > 0:
			source_in_inventory = source_slot in inventory_view_right.item_slots

		var target_in_equipment_stash = false
		if "stash_item_slots" in equipment_view and equipment_view.stash_item_slots.size() > 0:
			target_in_equipment_stash = self in equipment_view.stash_item_slots

		if source_in_inventory and target_in_equipment_stash:
			print("[ItemSlot] 🔄 CROSS-PANEL TRANSFER DETECTED: Hero Inventory → Shared Stash")
			var source_hero_id = inventory_view_right.hero_id
			print("[ItemSlot]   Source hero_id: %s" % source_hero_id)

			if source_hero_id != "":
				var success = HeroInventoryManager.transfer_to_shared_stash(source_hero_id, data.item_id, data.quantity)
				if success:
					print("[ItemSlot] ✅ Transfer to shared stash succeeded")
					# Set grid position in shared stash
					InventoryManager.move_item(data.item_id, grid_x, grid_y)
					print("[ItemSlot] ✅ Grid position set to (%d,%d)" % [grid_x, grid_y])
				else:
					print("[ItemSlot] ❌ Transfer to shared stash failed")
			else:
				print("[ItemSlot] ❌ Source hero_id is empty")
			return

	# Check if EquipmentView with shared stash grid (new single-grid mode)
	var has_refresh_method = inventory_view.has_method("_refresh_shared_stash")
	var has_stash_slots = "stash_item_slots" in inventory_view
	print("[ItemSlot]   has_refresh_method: %s, has_stash_slots: %s" % [has_refresh_method, has_stash_slots])

	if has_refresh_method and has_stash_slots:
		print("[ItemSlot] → EquipmentView with shared stash detected")
		var stash_slots_count = inventory_view.stash_item_slots.size()
		print("[ItemSlot]   Stash has %d slots" % stash_slots_count)

		var source_is_stash = source_slot in inventory_view.stash_item_slots
		var target_is_stash = self in inventory_view.stash_item_slots

		print("[ItemSlot]   source_is_stash: %s, target_is_stash: %s" % [source_is_stash, target_is_stash])

		# Both in shared stash - just rearrange
		if source_is_stash and target_is_stash:
			print("[ItemSlot] ✅ Both slots in shared stash - calling InventoryManager.move_item()")
			var success = InventoryManager.move_item(data.item_id, grid_x, grid_y)
			print("[ItemSlot] InventoryManager.move_item() result: %s" % ("SUCCESS" if success else "FAILED"))
		else:
			print("[ItemSlot] ⚠️ Slots not both in stash - skipping move")
		# Otherwise, let it fall through to normal drop logic
		return

	# Legacy: InventoryView with dual grids (left = hero, right = shared stash)
	if "left_item_slots" in inventory_view and "right_item_slots" in inventory_view:
		var source_is_left = source_slot in inventory_view.left_item_slots
		var target_is_left = self in inventory_view.left_item_slots

		# Same grid - just move position
		if source_is_left == target_is_left:
			if target_is_left:
				# Left grid (hero inventory)
				HeroInventoryManager.set_grid_position(inventory_view.hero_id, data.item_id, grid_x, grid_y)
			else:
				# Right grid (shared stash)
				InventoryManager.move_item(data.item_id, grid_x, grid_y)
		else:
			# Cross-grid transfer
			if source_is_left and not target_is_left:
				# Left to right (hero → shared stash)
				if HeroInventoryManager.transfer_to_shared_stash(inventory_view.hero_id, data.item_id, data.quantity):
					# Success - now move to target position in shared stash
					InventoryManager.move_item(data.item_id, grid_x, grid_y)
				else:
					print("[ItemSlot] Transfer to shared stash failed")
			else:
				# Right to left (shared stash → hero)
				if HeroInventoryManager.transfer_from_shared_stash(inventory_view.hero_id, data.item_id, data.quantity):
					# Success - now move to target position in hero inventory
					HeroInventoryManager.set_grid_position(inventory_view.hero_id, data.item_id, grid_x, grid_y)
				else:
					print("[ItemSlot] Transfer from shared stash failed")
