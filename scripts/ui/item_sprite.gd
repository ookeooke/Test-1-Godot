extends Control
class_name ItemSprite

## ItemSprite - Renders a single item as an overlay on top of the static grid
## Part of the Static Grid + Item Overlay architecture (Diablo 2 / Path of Exile style)
##
## ⚠️ ARCHITECTURE NOTE:
## This class is used ONLY in Inventory Grids (InventoryView, EquipmentView common chest).
## Equipment slots use ItemSlot rendering directly (see item_slot.gd MODE 1).
##
## How it works:
## 1. ItemSlots form a STATIC grid (never modified, no item data)
## 2. ItemSprites render as overlays on top (z_index=10)
## 3. ItemSprites handle drag initiation (_get_drag_data)
## 4. ItemSprites validate drops (_can_drop_data)
## 5. ItemSprites forward drop logic to ItemSlot._handle_sprite_drop()
##
## This class handles:
## - Rendering item icon, quantity, upgrade level
## - Positioning based on grid coordinates
## - Sizing based on item dimensions (multi-cell items)
## - Visual hover feedback
## - Tooltip generation
## - Mobile touch input (tap/long-press)
##
## The grid slots beneath remain STATIC (never modified)
## Drag/drop business logic delegated to ItemSlot system

# Debug mode
const DEBUG_DRAG_DROP = true # Enable verbose drag-drop logging

# Item data
var item_instance: ItemInstance = null

# Inventory context (which inventory this item belongs to)
var hero_id: String = "" # Empty string = shared stash, otherwise hero's ID

# Grid positioning
var grid_x: int = 0
var grid_y: int = 0

# UI references (created programmatically)
var icon: TextureRect
var quantity_label: Label
var upgrade_label: Label
var rarity_border: Panel

# ⚠️ DEPRECATED: Hardcoded constants replaced by dynamic _get_grid_params()
# These are kept as fallback defaults only. ItemSprite now reads cell_size from parent grid.
const CELL_SIZE: int = 80 # Fallback default (now read dynamically from InventoryGridContainer)
const CELL_GAP: int = 5 # Fallback default (now read dynamically from InventoryGridContainer)

# Mobile touch support (long-press detection)
var touch_start_time: float = 0.0
var is_touch_held: bool = false
const LONG_PRESS_DURATION: float = 0.5 # 500ms

# Signals for mobile interaction
signal item_tapped(item_sprite: ItemSprite) # Short tap - show tooltip
signal item_long_pressed(item_sprite: ItemSprite) # Long press - context menu


func _get_grid_params() -> Dictionary:
	"""Get cell size and gap from parent grid container dynamically

	This replaces hardcoded CELL_SIZE/CELL_GAP constants to support flexible grid sizing.
	ItemSprite now adapts to whatever grid it's placed in automatically.

	Returns: {cell_size: Vector2, cell_gap: Vector2}
	Fallback: {cell_size: Vector2(80, 80), cell_gap: Vector2(5, 5)} if parent not found
	"""
	# Navigate to parent grid: ItemSprite → item_layer → InventoryGridContainer
	var item_layer_node = get_parent()
	if item_layer_node:
		var grid_container = item_layer_node.get_parent() as InventoryGridContainer
		if grid_container:
			return {
				"cell_size": grid_container.cell_size,
				"cell_gap": grid_container.cell_gap
			}

	# Fallback to default values (matches old hardcoded constants)
	push_warning("[ItemSprite] Could not find parent InventoryGridContainer - using default cell size")
	return {
		"cell_size": Vector2(80, 80),
		"cell_gap": Vector2(5, 5)
	}


func _on_mouse_entered():
	"""Visual feedback when mouse enters item"""
	if item_instance:
		print("[ItemSprite] Mouse ENTERED - item: %s" % item_instance.item_id)
		# Show tooltip via TooltipManager (desktop hover)
		TooltipManager.show_tooltip(item_instance, self, "")

	# Use self_modulate to only brighten background, not icon
	self_modulate = Color(1.2, 1.2, 1.2)


func _on_mouse_exited():
	"""Reset visual when mouse leaves item"""
	if item_instance:
		print("[ItemSprite] Mouse EXITED - item: %s" % item_instance.item_id)

	# Hide tooltip
	TooltipManager.hide_tooltip()

	# Reset brightness
	self_modulate = Color.WHITE


func _on_gui_input(event: InputEvent):
	"""Handle touch input for mobile support

	Mobile interaction patterns:
	- Short tap (< 0.5s): Show tooltip/item details
	- Long press (≥ 0.5s): Show context menu
	- Drag: Handled by _get_drag_data() (Godot's built-in system)
	"""
	if not item_instance:
		return

	# Handle touch events (mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			# Touch started - begin long-press timer
			touch_start_time = Time.get_ticks_msec() / 1000.0
			is_touch_held = true
			print("[ItemSprite] Touch started on: %s" % item_instance.item_id)
		else:
			# Touch ended - check if it was short tap or long press
			if is_touch_held:
				var hold_duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time

				if hold_duration >= LONG_PRESS_DURATION:
					# Long press - show context menu
					print("[ItemSprite] 📱 Long press detected: %s (%.2fs)" % [item_instance.item_id, hold_duration])
					item_long_pressed.emit(self)
				else:
					# Short tap - show tooltip via TooltipManager
					print("[ItemSprite] 📱 Short tap detected: %s (%.2fs)" % [item_instance.item_id, hold_duration])
					item_tapped.emit(self)
					# Show tooltip for mobile
					if item_instance:
						TooltipManager.show_tooltip(item_instance, self, "")

				is_touch_held = false

	# Handle mouse events (PC) - right-click for context menu
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			print("[ItemSprite] 🖱️ Right-click detected: %s" % item_instance.item_id)
			item_long_pressed.emit(self)
			accept_event() # Prevent click from reaching world


func _ready():
	# Create UI elements programmatically (only if not already created)
	if icon == null:
		_setup_ui()

	# CRITICAL: ItemSprite MUST receive input to initiate drags
	# STOP = This node handles input and drag/drop events
	# ItemSlots are empty in overlay architecture - only ItemSprites have item data!
	mouse_filter = Control.MOUSE_FILTER_STOP

	# CRITICAL: Ensure size is applied (must happen after node is in tree)
	# Force the Control to use the size we calculated in set_item()
	if custom_minimum_size != Vector2.ZERO:
		size = custom_minimum_size # Force size to match minimum
		if item_instance:
			print("[ItemSprite] _ready() forcing size to %s for item '%s'" % [size, item_instance.item_id])

	# CRITICAL: Set pivot offset to center for natural scaling/rotation
	pivot_offset = size / 2

	# Visual Polish: Settle animation
	animate_settle()

	# Connect hover signals for visual feedback
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# Connect touch input for mobile support
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

	# Debug: Verify mouse input is configured
	print("[ItemSprite] _ready() complete - mouse_filter=%s, size=%s" % [mouse_filter, size])


func _setup_ui():
	"""Create child nodes for rendering"""

	# Main icon (TextureRect)
	icon = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through to parent
	add_child(icon)

	# Quantity label (bottom-right corner)
	quantity_label = Label.new()
	quantity_label.name = "QuantityLabel"
	quantity_label.add_theme_font_size_override("font_size", 14)
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quantity_label.add_theme_constant_override("outline_size", 2)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	quantity_label.anchor_left = 0.5
	quantity_label.anchor_top = 0.5
	quantity_label.anchor_right = 1.0
	quantity_label.anchor_bottom = 1.0
	quantity_label.offset_left = 0
	quantity_label.offset_top = 0
	quantity_label.offset_right = -4
	quantity_label.offset_bottom = -4
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through to parent
	add_child(quantity_label)

	# Upgrade label (top-left corner)
	upgrade_label = Label.new()
	upgrade_label.name = "UpgradeLabel"
	upgrade_label.add_theme_font_size_override("font_size", 14)
	upgrade_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5)) # Light green
	upgrade_label.add_theme_color_override("font_outline_color", Color.BLACK)
	upgrade_label.add_theme_constant_override("outline_size", 2)
	upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	upgrade_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	upgrade_label.anchor_right = 0.5
	upgrade_label.anchor_bottom = 0.5
	upgrade_label.offset_left = 4
	upgrade_label.offset_top = 4
	upgrade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through to parent
	add_child(upgrade_label)

	# Rarity border (upper-left corner indicator)
	rarity_border = Panel.new()
	rarity_border.name = "RarityBorder"
	rarity_border.custom_minimum_size = Vector2(16, 16)
	rarity_border.position = Vector2(0, 0)
	rarity_border.visible = false # Hidden by default
	rarity_border.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through to parent
	add_child(rarity_border)


func set_item(new_item: ItemInstance):
	"""Set the item to display using ItemInstance"""
	# Ensure UI is set up before we try to use it (handles case where set_item() is called before _ready())
	if icon == null:
		_setup_ui()

	item_instance = new_item
	
	if not item_instance:
		return

	var item_data = item_instance.get_data()
	if not item_data:
		print("[ItemSprite] Warning: Item data not found for: ", item_instance.item_id)
		return

	# Update size based on item dimensions (read cell_size dynamically from parent grid)
	var grid_params = _get_grid_params()
	var cell_w = grid_params.cell_size.x
	var cell_h = grid_params.cell_size.y
	var gap_w = grid_params.cell_gap.x
	var gap_h = grid_params.cell_gap.y

	var total_width = item_data.inventory_width * cell_w + (item_data.inventory_width - 1) * gap_w
	var total_height = item_data.inventory_height * cell_h + (item_data.inventory_height - 1) * gap_h
	custom_minimum_size = Vector2(total_width, total_height)
	size = Vector2(total_width, total_height)
	
	# CRITICAL: Update pivot offset when size changes
	pivot_offset = size / 2

	# Update visual display
	update_display()


func update_display():
	"""Update the visual display of the item"""
	if not item_instance:
		return
		
	var item_data = item_instance.get_data()
	if not item_data:
		return

	# Set icon texture or emoji
	if item_data.icon:
		icon.texture = item_data.icon
		icon.modulate = Color.WHITE
	elif item_data.emoji != "":
		# Create emoji label (similar to ItemSlot approach)
		icon.texture = null
		# TODO: Add emoji label support if needed
	else:
		icon.texture = null

	# Set quantity label
	if quantity_label:
		if item_data.item_type != ItemData.ItemType.CURRENCY and item_instance.quantity > 1:
			quantity_label.text = "×%d" % item_instance.quantity
		else:
			quantity_label.text = ""

	# Set upgrade label
	if upgrade_label:
		if item_data.can_upgrade and item_instance.upgrade_level > 0:
			upgrade_label.text = "+%d" % item_instance.upgrade_level
		else:
			upgrade_label.text = ""

	# Set rarity border (upper-left corner indicator)
	if rarity_border and item_data.rarity != ItemData.Rarity.NORMAL:
		rarity_border.visible = true
		rarity_border.modulate = item_data.get_rarity_color()
	else:
		if rarity_border:
			rarity_border.visible = false

	# Tooltip handled via TooltipManager on tap (mobile) or hover (desktop)


func _generate_tooltip() -> String:
	"""Generate tooltip text for this item"""
	if not item_instance:
		return ""
		
	var item_data = item_instance.get_data()
	if not item_data:
		return ""

	var tooltip = "[b]%s[/b]\n" % item_data.item_name
	tooltip += "[color=gray]%s[/color]\n\n" % item_data.get_rarity_name()

	# Add description
	if item_data.description != "":
		tooltip += "%s\n\n" % item_data.description

	# Add stat bonuses
	var stats_lines: Array = []
	if item_data.damage_bonus > 0:
		stats_lines.append("+%d Damage" % item_data.damage_bonus)
	if item_data.range_bonus > 0:
		stats_lines.append("+%d Range" % item_data.range_bonus)
	if item_data.attack_speed_multiplier > 1.0:
		var speed_percent = (item_data.attack_speed_multiplier - 1.0) * 100
		stats_lines.append("+%d%% Attack Speed" % speed_percent)
	if item_data.health_bonus > 0:
		stats_lines.append("+%d Health" % item_data.health_bonus)
	if item_data.defense_bonus > 0:
		stats_lines.append("+%d Defense" % item_data.defense_bonus)

	if not stats_lines.is_empty():
		tooltip += "\n".join(stats_lines) + "\n"

	# Add upgrade level
	if item_instance.upgrade_level > 0:
		tooltip += "\n[color=green]+%d Upgrade Level[/color]" % item_instance.upgrade_level

	return tooltip


func animate_settle():
	"""Visual Polish: Play a tiny 'settle' animation when item appears"""
	# Start slightly larger
	scale = Vector2(1.1, 1.1)
	modulate.a = 0.5 # Fade in slightly
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK) # Bouncy effect
	
	# Scale back to 1.0
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Fade to full opacity
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func set_grid_position(x: int, y: int):
	"""Set the grid position and update absolute position

	CRITICAL FIX: Use local position (relative to parent), NOT global_position
	Since item_layer is sized to match the grid container (no anchors), local position is correct
	"""
	grid_x = x
	grid_y = y

	# Calculate local position from grid coordinates (read cell_size dynamically from parent grid)
	# This works because item_layer has no anchors and is positioned at parent's origin
	var grid_params = _get_grid_params()
	var cell_w = grid_params.cell_size.x
	var cell_h = grid_params.cell_size.y
	var gap_w = grid_params.cell_gap.x
	var gap_h = grid_params.cell_gap.y

	position = Vector2(grid_x * (cell_w + gap_w), grid_y * (cell_h + gap_h))

	# Debug: Verify positioning
	if item_instance:
		print("[ItemSprite] Positioned '%s' at grid(%d,%d) → pos(%d,%d)" % [
			item_instance.item_id, grid_x, grid_y,
			int(position.x), int(position.y)
		])


## Drag/Drop Implementation (ItemSprite Handles Input)
## ItemSprites MUST handle drag/drop because ItemSlots are empty in overlay architecture
## Only ItemSprites have item data - ItemSlots are just static grid placeholders

func _get_drag_data(at_position: Vector2):
	"""Godot drag-and-drop: Get drag data when user starts dragging"""
	if not item_instance:
		return null

	var item_data = item_instance.get_data()
	if not item_data:
		return null

	# Calculate drag offset (where user clicked within the item)
	# This creates a "natural grab" feel - item follows cursor from where you clicked
	var drag_offset = at_position

	# Create drag preview with correct sizing
	# CRITICAL: Root preview Control must be 0x0 so Godot anchors it exactly at mouse cursor
	var preview = Control.new()
	preview.custom_minimum_size = Vector2.ZERO
	preview.size = Vector2.ZERO

	var preview_icon = TextureRect.new()
	preview_icon.texture = icon.texture
	preview_icon.size = size
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.modulate = Color(1, 1, 1, 0.7)
	# Offset icon so click position stays under cursor (natural grab feel)
	preview_icon.position = Vector2.ZERO - drag_offset

	preview.add_child(preview_icon)
	set_drag_preview(preview)

	print("[ItemSprite] 🎯 Drag started: %s (UUID: %s) from (%d,%d)" % [item_instance.item_id, item_instance.uuid, grid_x, grid_y])

	# Calculate grab offset (which grid cell within the item was clicked?)
	# This allows for "Anchor Point Correction" on drop
	# Read cell_size dynamically to support flexible grid sizing
	var grid_params = _get_grid_params()
	var local_click_pos = get_local_mouse_position()
	var grab_offset_x = int(local_click_pos.x / grid_params.cell_size.x)
	var grab_offset_y = int(local_click_pos.y / grid_params.cell_size.y)
	
	# Clamp offsets to be safe (shouldn't be needed if click is valid, but good practice)
	grab_offset_x = clampi(grab_offset_x, 0, item_data.inventory_width - 1)
	grab_offset_y = clampi(grab_offset_y, 0, item_data.inventory_height - 1)

	if DEBUG_DRAG_DROP:
		print("[ItemSprite] 🖱️ Drag started at local pos (%d, %d) -> Offset (%d, %d)" % [local_click_pos.x, local_click_pos.y, grab_offset_x, grab_offset_y])

	# Return drag data (compatible with ItemSlot's expectations)
	return {
		"uuid": item_instance.uuid, # 🆕 UUID SYSTEM: Primary identifier for item instance
		"item_id": item_instance.item_id, # Legacy/display
		"quantity": item_instance.quantity,
		"upgrade_level": item_instance.upgrade_level,
		"rolled_affixes": item_instance.rolled_affixes,
		"item_instance": item_instance, # Pass the full object for convenience
		"source_sprite": self,
		"source_hero_id": hero_id, # Which inventory (empty = shared stash)
		"source_grid_x": grid_x, # Source grid position
		"source_grid_y": grid_y,
		"drag_offset": drag_offset # Where user clicked within item (for natural feel)
	}


func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Godot drag-and-drop: Check if drop is valid

	FIX: This now properly validates drops to EMPTY slots using grid coordinates!
	The original bug was here - it returned false for all drops, blocking empty slot placement.
	"""
	if not data.has("item_id"):
		return false

	# Get parent grid container for coordinate conversion
	var grid_container = get_parent().get_parent() as InventoryGridContainer
	if not grid_container:
		print("[ItemSprite] ❌ No grid container found")
		return false

	# Convert mouse position to grid coordinates
	var grid_pos = grid_container.screen_to_grid(get_global_mouse_position())

	# Get item data to check dimensions
	var dragged_item = ItemDatabase.get_item(data.item_id)
	if not dragged_item:
		return false

	# Validate using grid bounds
	if not grid_container.is_valid_grid_position(grid_pos, dragged_item.inventory_width, dragged_item.inventory_height):
		print("[ItemSprite] ❌ Invalid grid position: (%d,%d)" % [grid_pos.x, grid_pos.y])
		return false

	# Check inventory-specific validation
	var source_hero_id = data.get("source_hero_id", "")

	# Determine target inventory from parent view
	var target_hero_id = hero_id

	# Same inventory check
	var is_same_inventory = (source_hero_id == target_hero_id)

	if is_same_inventory:
		# Within same inventory - validate via manager
		if target_hero_id != "":
			# Hero inventory - use HeroInventoryManager
			# Note: We can't validate collision without modifying manager, so optimistically allow
			# print("[ItemSprite] ✅ Drop validation passed (hero inventory, optimistic)") # Commented to reduce spam
			return true
		else:
			# Shared stash - get actual container from registry
			var stash = InventoryRegistry.get_container("stash")
			if not stash:
				print("[ItemSprite] ❌ Stash container not found")
				return false

			# Get ItemInstance from drag data
			if data.has("item_instance"):
				var item_inst = data.item_instance

				# Temporarily remove from grid to check if it can fit at new position
				var old_pos = stash.get_item_position(item_inst.uuid)
				stash._clear_from_grid(item_inst.uuid)

				# Check if can place at new position
				var can_place = stash.can_place_item(item_inst, grid_pos.x, grid_pos.y)

				# Restore to original grid position
				stash._place_on_grid(item_inst, old_pos.x, old_pos.y)

				if DEBUG_DRAG_DROP:
					print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
					print("[ItemSprite] 🎯 Drop Validation (Shared Stash)")
					print("  Item: %s (UUID: %s)" % [item_inst.item_id, item_inst.uuid])
					var item_data = item_inst.get_data()
					print("  Item Size: %dx%d" % [item_data.inventory_width, item_data.inventory_height])
					print("  Old Position: (%d, %d)" % [old_pos.x, old_pos.y])
					print("  New Position: (%d, %d)" % [grid_pos.x, grid_pos.y])
					print("  Can Place: %s" % ("✅ YES" if can_place else "❌ NO"))

					# If validation fails, show WHY
					if not can_place:
						print("  ⚠️  Validation FAILED - showing debug info:")
						stash.debug_check_position(item_inst, grid_pos.x, grid_pos.y)

					print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				return can_place
			else:
				print("[ItemSprite] ❌ No item_instance in drag data")
				return false
	else:
		# Cross-inventory transfer - always allow (managers handle validation)
		# print("[ItemSprite] ✅ Drop validation passed (cross-inventory transfer)") # Commented to reduce spam
		return true


func _drop_data(at_position: Vector2, data):
	"""Godot drag-and-drop: Handle drop

	Forwards drop to ItemSlot system which already has comprehensive drop logic.
	ItemSlot._handle_sprite_drop() handles all the business logic
	"""
	if DEBUG_DRAG_DROP:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("[ItemSprite] 📥 Drop Execution Started")
		print("  Item: %s" % data.get("item_id"))
		print("  Source: %s" % data.get("source_hero_id", "stash"))
		print("  Target Grid: (%d, %d)" % [grid_x, grid_y])
		print("  Forwarding to ItemSlot for execution...")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# Get parent grid container
	var grid_container = get_parent().get_parent() as InventoryGridContainer
	if not grid_container:
		print("[ItemSprite] ❌ No grid container found for drop")
		return

	# Convert mouse position to grid coordinates
	var grid_pos = grid_container.screen_to_grid(get_global_mouse_position())

	# Find ItemSlot at target grid position
	var target_slot = _find_slot_at_grid_position(grid_pos.x, grid_pos.y)
	if not target_slot:
		print("[ItemSprite] ❌ No ItemSlot found at grid position (%d,%d)" % [grid_pos.x, grid_pos.y])
		return

	# Forward drop to ItemSlot system (uses existing _handle_sprite_drop logic)
	print("[ItemSprite] → Forwarding drop to ItemSlot at (%d,%d)" % [grid_pos.x, grid_pos.y])
	target_slot._handle_sprite_drop(data)


func _find_slot_at_grid_position(target_x: int, target_y: int) -> ItemSlot:
	"""Find ItemSlot at the specified grid coordinates

	Searches through InventoryGridContainer children to find ItemSlot with matching grid_x/grid_y
	"""
	var grid_container = get_parent().get_parent() as InventoryGridContainer
	if not grid_container:
		return null

	# Search through grid container's children (not item_layer children!)
	for child in grid_container.get_children():
		if child is ItemSlot:
			var slot = child as ItemSlot
			if slot.grid_x == target_x and slot.grid_y == target_y:
				return slot

	print("[ItemSprite] ⚠️  No ItemSlot found at grid position (%d,%d)" % [target_x, target_y])
	return null
