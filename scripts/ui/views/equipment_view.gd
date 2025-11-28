extends BasePanelView
class_name EquipmentView

## EquipmentView - Shows hero's equipped items and stats
## Allows drag-drop from inventory to equipment slots
## Extends BasePanelView for use in FlexiblePanel

const DEBUG_INVENTORY = false # Set to true to enable verbose inventory logging

# Preload ItemSprite for overlay rendering (static grid + item overlay architecture)
const ItemSpriteScript = preload("res://scripts/ui/item_sprite.gd")

# signal equipment_slot_clicked(slot_name: String) # Unused
# signal switch_hero_requested # Unused
signal hero_changed(new_hero_id: String)

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/equipment_slot.tscn")
@export var hero_id: String = "ranger"

# Common chest mode (toggle between equipment and shared stash display)
var common_chest_mode: bool = false

# Static variable to persist toggle state across panel open/close (session-only)
static var _saved_chest_mode_preference: bool = false

# Shared stash grid references (for common chest mode)
# REFACTORED: Now uses lightweight InventoryGridSlot instead of bloated EquipmentSlot
var stash_item_slots: Array[InventoryGridSlot] = []

# Tile-based sizing constants (matching inventory grid system)
const TILE_SIZE: int = 80 # Base size of one tile in pixels
const TILE_GAP: int = 5 # Gap between tiles in pixels

# Equipment slot grid dimensions (width × height in tiles)
const HELMET_GRID: Vector2i = Vector2i(2, 2) # 2×2 tiles for helmets
const HAND_GRID: Vector2i = Vector2i(2, 4) # 2×4 tiles for weapons (bows, swords, shields)
const ARMOR_GRID: Vector2i = Vector2i(2, 3) # 2×3 tiles for body armor
const ACCESSORY_GRID: Vector2i = Vector2i(1, 1) # 1×1 tiles for rings/amulets

# Equipment slots (EquipmentSlot instances)
var hand_left_slot: EquipmentSlot
var hand_right_slot: EquipmentSlot
var helmet_slot: EquipmentSlot
var armor_slot: EquipmentSlot
var accessory1_slot: EquipmentSlot
var accessory2_slot: EquipmentSlot

# UI References
@onready var hand_left_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/LeftHandSlot/LeftHandContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/LeftHandSlot/LeftHandContainer") else null
@onready var hand_right_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/RightHandSlot/RightHandContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/RightHandSlot/RightHandContainer") else null
@onready var helmet_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/HelmetSlot/HelmetContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/HelmetSlot/HelmetContainer") else null
@onready var armor_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/ArmorSlot/ArmorContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/ArmorSlot/ArmorContainer") else null
@onready var accessory1_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory1Slot/Accessory1Container if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory1Slot/Accessory1Container") else null
@onready var accessory2_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory2Slot/Accessory2Container if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory2Slot/Accessory2Container") else null

# GridBackground references (InventoryGridContainer - for ItemSprite rendering)
@onready var helmet_grid: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/HelmetSlot/HelmetContainer/GridBackground if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/HelmetSlot/HelmetContainer/GridBackground") else null
@onready var hand_left_grid: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/LeftHandSlot/LeftHandContainer/GridBackground if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/LeftHandSlot/LeftHandContainer/GridBackground") else null
@onready var hand_right_grid: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/RightHandSlot/RightHandContainer/GridBackground if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/RightHandSlot/RightHandContainer/GridBackground") else null
@onready var armor_grid: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/ArmorSlot/ArmorContainer/GridBackground if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/ArmorSlot/ArmorContainer/GridBackground") else null
@onready var accessory1_grid: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory1Slot/Accessory1Container/GridBackground if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory1Slot/Accessory1Container/GridBackground") else null
@onready var accessory2_grid: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory2Slot/Accessory2Container/GridBackground if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory2Slot/Accessory2Container/GridBackground") else null

@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsFooter if has_node("MarginContainer/VBoxContainer/StatsFooter") else null

# Hero buttons
@onready var hero_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer") else null
@onready var archer_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer/ArcherButton if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer/ArcherButton") else null
@onready var warrior_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer/WarriorButton if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer/WarriorButton") else null
@onready var wizard_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer/WizardButton if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroButtonsContainer/WizardButton") else null

# Common chest toggle
@onready var common_chest_toggle: CheckButton = $MarginContainer/VBoxContainer/HeaderContainer/CommonChestToggle if has_node("MarginContainer/VBoxContainer/HeaderContainer/CommonChestToggle") else null

# Equipment paperdoll
@onready var equipment_paperdoll: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll") else null

# Shared stash container (for common chest mode)
@onready var shared_stash_container: Control = $MarginContainer/VBoxContainer/SharedStashContainer if has_node("MarginContainer/VBoxContainer/SharedStashContainer") else null
@onready var shared_stash_grid: Control = $MarginContainer/VBoxContainer/SharedStashContainer/SharedStashGrid if has_node("MarginContainer/VBoxContainer/SharedStashContainer/SharedStashGrid") else null


func _ready():
	super._ready()
	view_name = "Equipment"

	# Make stats text 30% smaller
	if stats_label:
		stats_label.add_theme_font_size_override("normal_font_size", 11)
		stats_label.add_theme_font_size_override("bold_font_size", 12)

	# Create equipment slots
	_create_equipment_slots()

	# Create or find equipment manager
	_setup_equipment_manager()

	# Connect hero selection buttons
	if archer_button:
		archer_button.pressed.connect(_on_hero_button_pressed.bind("ranger"))
		var ranger_data = HeroDatabase.get_hero("ranger")
		if ranger_data and ranger_data.portrait:
			archer_button.text = ""
			archer_button.icon = ranger_data.portrait
			archer_button.expand_icon = true
			
	if warrior_button:
		warrior_button.pressed.connect(_on_hero_button_pressed.bind("warrior"))
		var warrior_data = HeroDatabase.get_hero("warrior")
		if warrior_data and warrior_data.portrait:
			warrior_button.text = ""
			warrior_button.icon = warrior_data.portrait
			warrior_button.expand_icon = true
			
	if wizard_button:
		wizard_button.pressed.connect(_on_hero_button_pressed.bind("mage"))
		# Mage might not have a portrait yet, keep text fallback


	# Connect common chest toggle
	if common_chest_toggle:
		common_chest_toggle.toggled.connect(_on_common_chest_toggled)

	# Create shared stash grid slots for common chest mode
	_create_stash_grid_slots()

	# Hide shared stash container initially
	if shared_stash_container:
		shared_stash_container.visible = false

	# Restore saved chest mode preference (if any)
	if common_chest_toggle and _saved_chest_mode_preference:
		common_chest_toggle.button_pressed = true

	# Setup responsive slot sizing
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized() # Initial sizing

	# Connect to InventoryManager signals for shared stash updates
	# Note: InventoryManager is now just a wrapper around InventoryContainer("stash")
	# But we can connect to InventoryRegistry.get_container("stash").content_changed
	var stash = InventoryRegistry.get_container("stash")
	if stash:
		if not stash.content_changed.is_connected(_on_inventory_changed):
			stash.content_changed.connect(_on_inventory_changed)
		print("[EquipmentView] Connected to Stash content_changed signal")


func on_view_shown():
	super.on_view_shown()
	refresh_view()


func refresh_view():
	super.refresh_view()
	_refresh_equipment()


func set_hero_id(p_hero_id: String):
	"""Set which hero's equipment to show"""
	hero_id = p_hero_id
	_setup_equipment_manager()


func _create_equipment_slots():
	"""Create ItemSlot instances for each equipment slot"""
	# Left Hand slot
	hand_left_slot = item_slot_scene.instantiate() as EquipmentSlot
	hand_left_slot.slot_type = "equipment"
	hand_left_slot.equipment_filter = ItemData.EquipSlot.WEAPON
	hand_left_slot.equipment_slot_name = "hand_left"
	hand_left_slot.hero_id = hero_id
	hand_left_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_left_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_left_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("hand_left"))
	if hand_left_container:
		hand_left_container.add_child(hand_left_slot)

	# Right Hand slot
	hand_right_slot = item_slot_scene.instantiate() as EquipmentSlot
	hand_right_slot.slot_type = "equipment"
	hand_right_slot.equipment_filter = ItemData.EquipSlot.WEAPON
	hand_right_slot.equipment_slot_name = "hand_right"
	hand_right_slot.hero_id = hero_id
	hand_right_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_right_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_right_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("hand_right"))
	if hand_right_container:
		hand_right_container.add_child(hand_right_slot)

	# Helmet slot
	helmet_slot = item_slot_scene.instantiate() as EquipmentSlot
	helmet_slot.slot_type = "equipment"
	helmet_slot.equipment_filter = ItemData.EquipSlot.HELMET
	helmet_slot.equipment_slot_name = "helmet"
	helmet_slot.hero_id = hero_id
	helmet_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	helmet_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	helmet_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("helmet"))
	if helmet_container:
		helmet_container.add_child(helmet_slot)

	# Armor slot
	armor_slot = item_slot_scene.instantiate() as EquipmentSlot
	armor_slot.slot_type = "equipment"
	armor_slot.equipment_filter = ItemData.EquipSlot.ARMOR
	armor_slot.equipment_slot_name = "armor"
	armor_slot.hero_id = hero_id
	armor_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armor_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	armor_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("armor"))
	if armor_container:
		armor_container.add_child(armor_slot)

	# Accessory 1 slot
	accessory1_slot = item_slot_scene.instantiate() as EquipmentSlot
	accessory1_slot.slot_type = "equipment"
	accessory1_slot.equipment_filter = ItemData.EquipSlot.ACCESSORY
	accessory1_slot.equipment_slot_name = "accessory_1"
	accessory1_slot.hero_id = hero_id
	accessory1_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessory1_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	accessory1_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("accessory_1"))
	if accessory1_container:
		accessory1_container.add_child(accessory1_slot)

	# Accessory 2 slot
	accessory2_slot = item_slot_scene.instantiate() as EquipmentSlot
	accessory2_slot.slot_type = "equipment"
	accessory2_slot.equipment_filter = ItemData.EquipSlot.ACCESSORY
	accessory2_slot.equipment_slot_name = "accessory_2"
	accessory2_slot.hero_id = hero_id
	accessory2_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accessory2_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	accessory2_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("accessory_2"))
	if accessory2_container:
		accessory2_container.add_child(accessory2_slot)


func _setup_equipment_manager():
	"""Setup equipment registry integration for this hero"""
	# Register hero in equipment registry if not already registered
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)

	# Connect to registry batch update signal (only once)
	if not HeroEquipmentRegistry.batch_update_completed.is_connected(_on_batch_update):
		HeroEquipmentRegistry.batch_update_completed.connect(_on_batch_update)

	# Load and display current equipment
	_refresh_equipment()


func _refresh_equipment():
	"""Refresh all equipment slots from HeroEquipmentRegistry

	Uses Static Grid + ItemSprite Overlay architecture (Diablo 2 style):
	- EquipmentSlot: Drop target only (no rendering)
	- GridBackground: Draws tile texture
	- ItemSprite: Renders item at actual size on grid's item_layer
	"""
	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)

	# Helper to update a slot and render item via ItemSprite
	var update_slot = func(slot: EquipmentSlot, grid: Control, slot_name: String):
		var content = equipped_items.get(slot_name)

		# Clear old ItemSprites from this grid
		if grid and grid.has_node("ItemLayer"):
			var item_layer = grid.get_node("ItemLayer")
			for child in item_layer.get_children():
				child.free() # Synchronous deletion

		if content is ItemInstance:
			# Update slot reference (for drag-drop source tracking)
			slot.set_item(content)
			slot.modulate = Color.WHITE

			# Create ItemSprite overlay on the grid
			if grid and grid.has_node("ItemLayer"):
				var item_sprite = ItemSpriteScript.new()
				item_sprite.hero_id = hero_id
				item_sprite.container_id = hero_id # Equipment uses hero_id as container
				item_sprite.set_item(content, true) # skip_animation=true
				item_sprite.set_grid_position(0, 0) # Equipment items start at (0,0)

				# Connect signals for click interactions
				item_sprite.item_tapped.connect(_on_equipment_sprite_tapped.bind(slot_name))
				item_sprite.item_long_pressed.connect(_on_equipment_sprite_long_pressed.bind(slot_name))

				grid.get_node("ItemLayer").add_child(item_sprite)

		elif content is String and content.begins_with("__2H_OCCUPIED__"):
			# 2H Marker - slot is occupied by 2H weapon in other hand
			slot.clear_slot()
			slot.modulate = Color(0.5, 0.5, 0.5, 0.5) # Dimmed
		else:
			slot.clear_slot()
			slot.modulate = Color.WHITE

	update_slot.call(hand_left_slot, hand_left_grid, "hand_left")
	update_slot.call(hand_right_slot, hand_right_grid, "hand_right")
	update_slot.call(helmet_slot, helmet_grid, "helmet")
	update_slot.call(armor_slot, armor_grid, "armor")
	update_slot.call(accessory1_slot, accessory1_grid, "accessory_1")
	update_slot.call(accessory2_slot, accessory2_grid, "accessory_2")

	# Update stats display
	_update_stats_display()


func _update_stats_display():
	"""Update the stats text display - Compact Diablo 2 style single-line format"""
	if not stats_label:
		return

	# Get hero data
	var hero_data = HeroDatabase.get_hero(hero_id)
	if not hero_data:
		stats_label.text = "Hero data not found"
		return

	# Get equipped items from HeroEquipmentRegistry
	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)

	# Collect all stat modifiers from equipped items
	var modifiers: Array[StatModifier] = []

	for content in equipped_items.values():
		if content is ItemInstance:
			var item_data = content.get_data()
			if item_data:
				var item_modifiers = item_data.get_stat_modifiers(content.upgrade_level)
				modifiers.append_array(item_modifiers)

	# Calculate bonuses by stat type
	var damage_bonus: float = 0.0
	var health_bonus: float = 0.0
	var defense_bonus: float = 0.0
	var range_bonus: float = 0.0
	var attack_speed_bonus: float = 0.0
	var crit_bonus: float = 0.0

	for mod in modifiers:
		var desc_lower = mod.description.to_lower()

		if "damage" in desc_lower:
			if mod.type == StatModifier.ModifierType.FLAT:
				damage_bonus += mod.value
			elif mod.type == StatModifier.ModifierType.ADDITIVE:
				damage_bonus += hero_data.base_damage * mod.value

		elif "health" in desc_lower or "max_health" in desc_lower:
			if mod.type == StatModifier.ModifierType.FLAT:
				health_bonus += mod.value
			elif mod.type == StatModifier.ModifierType.ADDITIVE:
				health_bonus += hero_data.base_health * mod.value

		elif "defense" in desc_lower or "armor" in desc_lower:
			if mod.type == StatModifier.ModifierType.FLAT:
				defense_bonus += mod.value
			elif mod.type == StatModifier.ModifierType.ADDITIVE:
				defense_bonus += hero_data.base_defense * mod.value

		elif "range" in desc_lower:
			if mod.type == StatModifier.ModifierType.FLAT:
				range_bonus += mod.value
			elif mod.type == StatModifier.ModifierType.ADDITIVE:
				range_bonus += hero_data.base_range * mod.value

		elif "attack_speed" in desc_lower or "attack speed" in desc_lower:
			if mod.type == StatModifier.ModifierType.ADDITIVE:
				attack_speed_bonus += mod.value
			elif mod.type == StatModifier.ModifierType.MULTIPLICATIVE:
				attack_speed_bonus += (mod.value - 1.0)

		elif "crit" in desc_lower:
			if mod.type == StatModifier.ModifierType.FLAT:
				crit_bonus += mod.value
			elif mod.type == StatModifier.ModifierType.ADDITIVE:
				crit_bonus += mod.value

	# Calculate final stats
	var final_damage = int(hero_data.base_damage + damage_bonus)
	var final_health = int(hero_data.base_health + health_bonus)
	var final_defense = int(hero_data.base_defense + defense_bonus)
	var final_range = int(hero_data.base_range + range_bonus)
	var final_attack_speed = hero_data.base_attack_speed * (1.0 + attack_speed_bonus)
	var final_crit = (hero_data.base_crit_chance + crit_bonus) * 100

	# Compact single-line format (Diablo 2 style)
	stats_label.text = "Dmg: %d | HP: %d | Def: %d | Rng: %d | AS: %.2fs | Crit: %.1f%%" % [
		final_damage,
		final_health,
		final_defense,
		final_range,
		final_attack_speed,
		final_crit
	]


func _on_batch_update(dirty_hero_ids: Array[String]) -> void:
	"""Handle batched refresh (ONLY place where UI refreshes!)"""
	if hero_id not in dirty_hero_ids:
		return
	_refresh_equipment()


func _on_equipment_slot_right_clicked(_item: ItemInstance, _slot: EquipmentSlot, slot_name: String):
	"""Called when an equipment slot is right-clicked (unequip)"""
	ItemTransactionService.unequip_item(hero_id, slot_name)


func _on_equipment_sprite_tapped(item_sprite: ItemSprite, slot_name: String):
	"""Handle ItemSprite tap on equipment slot (Ctrl+Click = unequip)"""
	if not item_sprite or not item_sprite.item_instance:
		return

	var ctrl_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if ctrl_held:
		ItemTransactionService.unequip_item(hero_id, slot_name)


func _on_equipment_sprite_long_pressed(item_sprite: ItemSprite, slot_name: String):
	"""Handle ItemSprite long-press on equipment slot (unequip on mobile/right-click)"""
	if not item_sprite or not item_sprite.item_instance:
		return

	ItemTransactionService.unequip_item(hero_id, slot_name)


## ============================================
## RESPONSIVE SLOT SIZING (New Smart Layout)
## ============================================

func _on_viewport_resized():
	"""Adjust equipment slot sizes based on panel width"""
	# Calculate available width for equipment grid
	var panel_width = _get_parent_panel().size.x if _get_parent_panel() else 600.0

	# Account for margins (10px each side = 20px total)
	var available_width = panel_width - 20.0

	# Calculate slot size for 2×2 grid
	# Formula: (available_width - gap_between_columns) / 2
	var gap = 20.0 # Space between columns
	var slot_size = (available_width - gap) / 2.0

	# Clamp to reasonable min/max
	slot_size = clampf(slot_size, 120.0, 300.0)

	# Apply tile-based sizing (Diablo 2-style fixed tile grids)
	_resize_slot_container(helmet_container, _calculate_tile_size(HELMET_GRID)) # 2×2 tiles = 165×165px
	_resize_slot_container(hand_left_container, _calculate_tile_size(HAND_GRID)) # 2×4 tiles = 165×330px
	_resize_slot_container(hand_right_container, _calculate_tile_size(HAND_GRID)) # 2×4 tiles = 165×330px
	_resize_slot_container(armor_container, _calculate_tile_size(ARMOR_GRID)) # 2×3 tiles = 165×250px
	_resize_slot_container(accessory1_container, _calculate_tile_size(ACCESSORY_GRID)) # 1×1 tiles = 80×80px
	_resize_slot_container(accessory2_container, _calculate_tile_size(ACCESSORY_GRID)) # 1×1 tiles = 80×80px


func _calculate_tile_size(grid_dimensions: Vector2i) -> Vector2:
	"""Calculate pixel size from tile grid dimensions"""
	var width = (grid_dimensions.x * TILE_SIZE) + ((grid_dimensions.x - 1) * TILE_GAP)
	var height = (grid_dimensions.y * TILE_SIZE) + ((grid_dimensions.y - 1) * TILE_GAP)
	return Vector2(width, height)


func _resize_slot_container(container: Control, target_size: Vector2):
	"""Resize an equipment slot container to specified dimensions"""
	if container:
		container.custom_minimum_size = target_size


func _get_parent_panel() -> Control:
	"""Get the parent FlexiblePanel to determine available width"""
	var node = get_parent()
	while node != null:
		if node is Panel or node is PanelContainer:
			return node
		node = node.get_parent()
	return null


func _input(event: InputEvent):
	"""Handle keyboard shortcuts: C (common chest mode)"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			# Toggle common chest mode (if button exists)
			if common_chest_toggle:
				common_chest_toggle.button_pressed = !common_chest_toggle.button_pressed
				# Signal will fire automatically, calling _on_common_chest_toggled()
				accept_event()


func _create_stash_grid_slots():
	"""Create item slots for shared stash grid in common chest mode"""
	if not shared_stash_grid:
		return

	var grid_width = InventoryManager.GRID_WIDTH
	var grid_height = InventoryManager.GRID_HEIGHT

	# Create shared stash grid slots
	# REFACTORED: Use lightweight InventoryGridSlot instead of bloated EquipmentSlot
	# ItemSprite handles input (item_clicked signals), not the grid slots
	for y in grid_height:
		for x in grid_width:
			var slot = InventoryGridSlot.new()
			var i = y * grid_width + x
			slot.slot_index = i
			slot.slot_type = "inventory"
			slot.grid_x = x
			slot.grid_y = y

			# NOTE: InventoryGridSlot doesn't emit item_clicked/item_right_clicked
			# ItemSprite handles input and signals are connected in _refresh_shared_stash()

			shared_stash_grid.add_child(slot)
			stash_item_slots.append(slot)

	# Wire up stash container for drag highlight collision checking (3-state highlighting)
	if shared_stash_grid.has_method("set_container"):
		var stash = InventoryRegistry.get_container("stash")
		if stash:
			shared_stash_grid.set_container(stash)

	print("[EquipmentView] Created %d shared stash slots" % stash_item_slots.size())


func _on_common_chest_toggled(button_pressed: bool):
	"""Toggle between equipment and shared stash (common chest) mode"""
	common_chest_mode = button_pressed

	# Save preference (persists across panel open/close during session)
	_saved_chest_mode_preference = button_pressed

	if common_chest_mode:
		# Enable common chest mode - hide equipment, show shared stash
		# Hero buttons stay visible (to control which hero is shown in the RIGHT panel)
		if equipment_paperdoll:
			equipment_paperdoll.visible = false
		if shared_stash_container:
			shared_stash_container.visible = true

		# Refresh shared stash grid
		_refresh_shared_stash()
	else:
		# Return to equipment mode - show equipment, hide shared stash
		if equipment_paperdoll:
			equipment_paperdoll.visible = true
		if shared_stash_container:
			shared_stash_container.visible = false

	print("[EquipmentView] Common chest mode: %s" % ("ON" if common_chest_mode else "OFF"))


func _refresh_shared_stash():
	"""Refresh shared stash grid in common chest mode (using ItemSprite overlays)"""
	print("[EquipmentView] 🔄 Refreshing shared stash grid...")

	var container = InventoryRegistry.get_container("stash")
	if not container:
		print("[EquipmentView] ❌ Stash container not found!")
		return

	# REFACTOR: Static Grid + Item Overlay Architecture
	# Grid slots remain STATIC (never modified)
	# Items are rendered as ItemSprite overlays on top of the grid

	# CRITICAL FIX: Clear old item sprites SYNCHRONOUSLY (not queue_free!)
	# queue_free() is async - nodes aren't freed immediately, causing race conditions
	if shared_stash_grid and shared_stash_grid.has_node("ItemLayer"):
		for child in shared_stash_grid.get_node("ItemLayer").get_children():
			child.free() # Synchronous deletion (Path of Exile / Diablo 2 style)

	# Load shared stash items
	var stash_items = container.get_all_items()

	# Create ItemSprite overlays for each item
	for item_instance in stash_items:
		# Get item's grid position from container
		var pos: Vector2i = container.get_item_position(item_instance.uuid)

		if pos.x == -1 or pos.y == -1:
			continue

		# Create ItemSprite overlay
		var item_sprite = ItemSpriteScript.new()
		item_sprite.hero_id = "" # Empty string = shared stash
		item_sprite.container_id = "stash" # 🔧 FIX: Set explicitly for drag-drop source lookup
		item_sprite.set_item(item_instance, true) # skip_animation=true prevents mass bouncing
		item_sprite.set_grid_position(pos.x, pos.y)

		# 🔧 FIX CRITICAL: Connect ItemSprite signals for click interactions
		# ItemSprite blocks input to ItemSlot (mouse_filter = STOP), so we must
		# connect to ItemSprite's signals instead of ItemSlot's
		item_sprite.item_tapped.connect(_on_stash_sprite_tapped)
		item_sprite.item_long_pressed.connect(_on_stash_sprite_long_pressed)

		# Add to item layer (renders on top of grid)
		if shared_stash_grid and shared_stash_grid.has_node("ItemLayer"):
			shared_stash_grid.get_node("ItemLayer").add_child(item_sprite)

	# Refresh debug grid visualization
	if shared_stash_grid:
		shared_stash_grid.refresh_items_display()


func _on_inventory_changed():
	"""Called when shared stash inventory changes"""
	if DEBUG_INVENTORY:
		print("[EquipmentView] 🔔 inventory_changed signal received")

	# Only refresh if in common chest mode
	if common_chest_mode:
		if DEBUG_INVENTORY:
			print("[EquipmentView] Common chest mode ON - refreshing shared stash")
		_refresh_shared_stash()
	elif DEBUG_INVENTORY:
		print("[EquipmentView] Common chest mode OFF - ignoring signal")


# NOTE: _on_item_slot_clicked and _on_item_slot_right_clicked REMOVED
# After migration to InventoryGridSlot, ItemSprite handles input instead.
# See _on_stash_sprite_tapped and _on_stash_sprite_long_pressed below.

func _on_stash_sprite_tapped(item_sprite: ItemSprite):
	"""🔧 FIX CRITICAL: Adapter for ItemSprite tap events in shared stash

	ItemSprite blocks input to ItemSlot (overlay architecture), so we connect
	to ItemSprite signals and forward to quick transfer logic.

	This enables Ctrl+Click quick transfer from stash to hero inventory.
	"""
	if not item_sprite or not item_sprite.item_instance:
		return

	var ctrl_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)

	if common_chest_mode and ctrl_held:
		_quick_transfer_item_from_sprite(item_sprite.item_instance)


func _on_stash_sprite_long_pressed(item_sprite: ItemSprite):
	"""🔧 FIX CRITICAL: Adapter for ItemSprite long-press events in shared stash

	ItemSprite blocks input to ItemSlot (overlay architecture), so we connect
	to ItemSprite signals and forward to quick transfer logic.

	This enables:
	- Right-click quick transfer on PC
	- Long-press quick transfer on mobile
	"""
	if not item_sprite or not item_sprite.item_instance:
		return

	if common_chest_mode:
		_quick_transfer_item_from_sprite(item_sprite.item_instance)


func _quick_transfer_item_from_sprite(item_instance: ItemInstance):
	"""Quick transfer from shared stash to hero inventory (called from ItemSprite adapters)"""
	if hero_id == "":
		return

	var item_data = item_instance.get_data()
	if not item_data:
		return

	# Transfer from shared stash → hero inventory
	var success = ItemTransactionService.move_item(item_instance.uuid, "stash", hero_id)

	if success:
		print("[EquipmentView] ⚡ Quick transferred '%s' to hero inventory" % item_data.item_name)
		# Refresh will happen automatically via signals
		_refresh_shared_stash()


func _quick_transfer_item(item_instance: ItemInstance, slot: EquipmentSlot):
	"""Ctrl+Click quick transfer in common chest mode (stash → hero inventory)"""
	if hero_id == "":
		return

	# Check if slot is in shared stash grid
	if slot not in stash_item_slots:
		return # Slot not in stash grid
		
	var item_data = item_instance.get_data()
	if not item_data: return

	# Transfer from shared stash → hero inventory
	var success = ItemTransactionService.move_item(item_instance.uuid, "stash", hero_id)

	if success:
		print("[EquipmentView] ⚡ Quick transferred '%s' to hero inventory" % item_data.item_name)
		# Refresh will happen automatically via signals
		_refresh_shared_stash()


func _on_hero_button_pressed(new_hero_id: String):
	"""Called when a hero selection button is pressed"""
	# Update hero_id and setup equipment manager if changed
	if new_hero_id != hero_id:
		hero_id = new_hero_id
		_setup_equipment_manager()

	# ALWAYS emit signal for UI consistency (even if hero_id unchanged)
	# This ensures the RIGHT panel and other listeners always update
	hero_changed.emit(new_hero_id)

	# Exit common chest mode when clicking hero button
	# User wants to see THIS HERO'S equipment, not the shared stash
	if common_chest_mode and common_chest_toggle:
		common_chest_toggle.button_pressed = false # This triggers _on_common_chest_toggled
	else:
		# Refresh equipment if not in common chest mode
		_refresh_equipment()


func cleanup():
	"""Clean up when view is closed"""
	super.cleanup()

	# Disconnect signals to prevent memory leaks
	if HeroEquipmentRegistry:
		if HeroEquipmentRegistry.batch_update_completed.is_connected(_on_batch_update):
			HeroEquipmentRegistry.batch_update_completed.disconnect(_on_batch_update)

	var stash = InventoryRegistry.get_container("stash")
	if stash:
		if stash.content_changed.is_connected(_on_inventory_changed):
			stash.content_changed.disconnect(_on_inventory_changed)
