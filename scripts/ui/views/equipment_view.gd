extends BasePanelView
class_name EquipmentView

## EquipmentView - Shows hero's equipped items and stats
## Allows drag-drop from inventory to equipment slots
## Extends BasePanelView for use in FlexiblePanel

const DEBUG_INVENTORY = false  # Set to true to enable verbose inventory logging

signal equipment_slot_clicked(slot_name: String)
signal switch_hero_requested
signal hero_changed(new_hero_id: String)

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")
@export var hero_id: String = "ranger"

# Common chest mode (toggle between equipment and shared stash display)
var common_chest_mode: bool = false

# Static variable to persist toggle state across panel open/close (session-only)
static var _saved_chest_mode_preference: bool = false

# Shared stash grid references (for common chest mode)
var stash_item_slots: Array[ItemSlot] = []

# Tile-based sizing constants (matching inventory grid system)
const TILE_SIZE: int = 80  # Base size of one tile in pixels
const TILE_GAP: int = 5    # Gap between tiles in pixels

# Equipment slot grid dimensions (width × height in tiles)
const HELMET_GRID: Vector2i = Vector2i(2, 2)      # 2×2 tiles for helmets
const HAND_GRID: Vector2i = Vector2i(2, 4)         # 2×4 tiles for weapons (bows, swords, shields)
const ARMOR_GRID: Vector2i = Vector2i(2, 3)        # 2×3 tiles for body armor
const ACCESSORY_GRID: Vector2i = Vector2i(1, 1)    # 1×1 tiles for rings/amulets

# Equipment slots (ItemSlot instances)
var hand_left_slot: ItemSlot
var hand_right_slot: ItemSlot
var helmet_slot: ItemSlot
var armor_slot: ItemSlot
var accessory1_slot: ItemSlot
var accessory2_slot: ItemSlot

# UI References
@onready var hand_left_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/LeftHandSlot/LeftHandContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/LeftHandSlot/LeftHandContainer") else null
@onready var hand_right_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/RightHandSlot/RightHandContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/RightHandSlot/RightHandContainer") else null
@onready var helmet_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/HelmetSlot/HelmetContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/HelmetSlot/HelmetContainer") else null
@onready var armor_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/ArmorSlot/ArmorContainer if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/ArmorSlot/ArmorContainer") else null
@onready var accessory1_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory1Slot/Accessory1Container if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory1Slot/Accessory1Container") else null
@onready var accessory2_container: Control = $MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory2Slot/Accessory2Container if has_node("MarginContainer/VBoxContainer/EquipmentPaperDoll/Accessory2Slot/Accessory2Container") else null

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
	if warrior_button:
		warrior_button.pressed.connect(_on_hero_button_pressed.bind("warrior"))
	if wizard_button:
		wizard_button.pressed.connect(_on_hero_button_pressed.bind("mage"))

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
	_on_viewport_resized()  # Initial sizing

	# Connect to InventoryManager signals for shared stash updates
	if InventoryManager:
		if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
			InventoryManager.inventory_changed.connect(_on_inventory_changed)
		print("[EquipmentView] Connected to InventoryManager.inventory_changed signal")


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
	hand_left_slot = item_slot_scene.instantiate() as ItemSlot
	hand_left_slot.slot_type = "equipment"
	hand_left_slot.equipment_filter = ItemData.EquipSlot.WEAPON
	hand_left_slot.equipment_slot_name = "hand_left"
	hand_left_slot.hero_id = hero_id
	hand_left_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("hand_left"))
	if hand_left_container:
		hand_left_container.add_child(hand_left_slot)

	# Right Hand slot
	hand_right_slot = item_slot_scene.instantiate() as ItemSlot
	hand_right_slot.slot_type = "equipment"
	hand_right_slot.equipment_filter = ItemData.EquipSlot.WEAPON
	hand_right_slot.equipment_slot_name = "hand_right"
	hand_right_slot.hero_id = hero_id
	hand_right_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("hand_right"))
	if hand_right_container:
		hand_right_container.add_child(hand_right_slot)

	# Helmet slot
	helmet_slot = item_slot_scene.instantiate() as ItemSlot
	helmet_slot.slot_type = "equipment"
	helmet_slot.equipment_filter = ItemData.EquipSlot.HELMET
	helmet_slot.equipment_slot_name = "helmet"
	helmet_slot.hero_id = hero_id
	helmet_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("helmet"))
	if helmet_container:
		helmet_container.add_child(helmet_slot)

	# Armor slot
	armor_slot = item_slot_scene.instantiate() as ItemSlot
	armor_slot.slot_type = "equipment"
	armor_slot.equipment_filter = ItemData.EquipSlot.ARMOR
	armor_slot.equipment_slot_name = "armor"
	armor_slot.hero_id = hero_id
	armor_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("armor"))
	if armor_container:
		armor_container.add_child(armor_slot)

	# Accessory 1 slot
	accessory1_slot = item_slot_scene.instantiate() as ItemSlot
	accessory1_slot.slot_type = "equipment"
	accessory1_slot.equipment_filter = ItemData.EquipSlot.ACCESSORY
	accessory1_slot.equipment_slot_name = "accessory_1"
	accessory1_slot.hero_id = hero_id
	accessory1_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("accessory_1"))
	if accessory1_container:
		accessory1_container.add_child(accessory1_slot)

	# Accessory 2 slot
	accessory2_slot = item_slot_scene.instantiate() as ItemSlot
	accessory2_slot.slot_type = "equipment"
	accessory2_slot.equipment_filter = ItemData.EquipSlot.ACCESSORY
	accessory2_slot.equipment_slot_name = "accessory_2"
	accessory2_slot.hero_id = hero_id
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
	"""Refresh all equipment slots from HeroEquipmentRegistry"""
	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)

	# Update left hand slot
	var hand_left_id = equipped_items.get("hand_left", "")
	if hand_left_id != "":
		var rolled_affixes = InventoryManager.get_item_rolled_affixes(hand_left_id)
		hand_left_slot.set_item(hand_left_id, 1, 0, rolled_affixes)
	else:
		hand_left_slot.clear_slot()

	# Update right hand slot (check for 2H weapon occupation marker)
	var hand_right_id = equipped_items.get("hand_right", "")
	if hand_right_id != "":
		# Check if this is a 2H weapon occupation marker
		if hand_right_id.begins_with("__2H_OCCUPIED__"):
			# Extract the actual item_id from the marker
			var actual_item_id = hand_right_id.substr(len("__2H_OCCUPIED__"))

			# VALIDATION: Check if the item still exists in ItemDatabase
			var item_data = ItemDatabase.get_item(actual_item_id)
			if item_data:
				# Show the 2H weapon in right hand slot (with visual indication it's occupied)
				var rolled_affixes = InventoryManager.get_item_rolled_affixes(actual_item_id)
				hand_right_slot.set_item(actual_item_id, 1, 0, rolled_affixes)
				# Set slot to dimmed/disabled state to indicate it's occupied by 2H weapon
				hand_right_slot.modulate = Color(0.6, 0.6, 0.6, 1.0)  # Dimmed appearance
			else:
				# ORPHANED MARKER CLEANUP
				# Item was deleted from database - clean up stale marker
				print("[EquipmentView] ⚠️ Orphaned 2H marker detected for non-existent item: ", actual_item_id)
				hand_right_slot.clear_slot()
				hand_right_slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal appearance

				# Clear the orphaned marker using public API (automatically wraps in transaction)
				if not HeroEquipmentRegistry.equip_item(hero_id, "hand_right", ""):
					push_error("[EquipmentView] Failed to clear orphaned 2H marker for hero: ", hero_id)
				else:
					print("[EquipmentView] ✓ Cleared orphaned 2H marker successfully")
		else:
			# Normal item in right hand
			var rolled_affixes = InventoryManager.get_item_rolled_affixes(hand_right_id)
			hand_right_slot.set_item(hand_right_id, 1, 0, rolled_affixes)
			hand_right_slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal appearance
	else:
		hand_right_slot.clear_slot()
		hand_right_slot.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal appearance

	# Update helmet slot
	var helmet_id = equipped_items.get("helmet", "")
	if helmet_id != "":
		var rolled_affixes = InventoryManager.get_item_rolled_affixes(helmet_id)
		helmet_slot.set_item(helmet_id, 1, 0, rolled_affixes)
	else:
		helmet_slot.clear_slot()

	# Update armor slot
	var armor_id = equipped_items.get("armor", "")
	if armor_id != "":
		var rolled_affixes = InventoryManager.get_item_rolled_affixes(armor_id)
		armor_slot.set_item(armor_id, 1, 0, rolled_affixes)
	else:
		armor_slot.clear_slot()

	# Update accessory 1 slot
	var acc1_id = equipped_items.get("accessory_1", "")
	if acc1_id != "":
		var rolled_affixes = InventoryManager.get_item_rolled_affixes(acc1_id)
		accessory1_slot.set_item(acc1_id, 1, 0, rolled_affixes)
	else:
		accessory1_slot.clear_slot()

	# Update accessory 2 slot
	var acc2_id = equipped_items.get("accessory_2", "")
	if acc2_id != "":
		var rolled_affixes = InventoryManager.get_item_rolled_affixes(acc2_id)
		accessory2_slot.set_item(acc2_id, 1, 0, rolled_affixes)
	else:
		accessory2_slot.clear_slot()

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

	for item_id in equipped_items.values():
		if item_id == "":
			continue

		var item_data = ItemDatabase.get_item(item_id)
		if item_data == null:
			continue

		var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)
		var item_modifiers = item_data.get_stat_modifiers(upgrade_level)
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


func _format_modifier(mod: StatModifier) -> String:
	"""Format a modifier for display"""
	match mod.type:
		StatModifier.ModifierType.FLAT:
			return "+%.0f %s" % [mod.value, mod.description]
		StatModifier.ModifierType.ADDITIVE:
			return "+%.0f%% %s" % [mod.value * 100, mod.description]
		StatModifier.ModifierType.MULTIPLICATIVE:
			return "×%.2f %s" % [mod.value, mod.description]
	return mod.description


func _format_stat_line(stat_name: String, base_value: float, final_value: float, bonus: float) -> String:
	"""Format a stat line: 'Stat: Base → Final (+Bonus)' or just 'Stat: Base' if no bonus"""
	if abs(bonus) < 0.01:
		# No bonus - show only base value
		return "[b]%s:[/b] %.0f\n" % [stat_name, base_value]
	else:
		# Has bonus - show base → final (+bonus) in green
		return "[b]%s:[/b] %.0f → [color=green]%.0f[/color] [color=gray](+%.0f)[/color]\n" % [stat_name, base_value, final_value, bonus]


func _format_stat_line_float(stat_name: String, base_value: float, final_value: float, bonus: float, is_speed: bool = false, suffix: String = "") -> String:
	"""Format a stat line for float values (attack speed, crit chance, etc.)"""
	if abs(bonus) < 0.001:
		# No bonus - show only base value
		if is_speed:
			return "[b]%s:[/b] %.2fs%s\n" % [stat_name, base_value, suffix]
		else:
			return "[b]%s:[/b] %.1f%s\n" % [stat_name, base_value, suffix]
	else:
		# Has bonus - show base → final (+bonus) in green
		if is_speed:
			return "[b]%s:[/b] %.2fs → [color=green]%.2fs[/color] [color=gray](%.0f%%)[/color]\n" % [stat_name, base_value, final_value, bonus * 100]
		else:
			return "[b]%s:[/b] %.1f%s → [color=green]%.1f%s[/color] [color=gray](+%.1f%s)[/color]\n" % [stat_name, base_value, suffix, final_value, suffix, bonus, suffix]


func _on_batch_update(dirty_hero_ids: Array[String]) -> void:
	"""Handle batched refresh (ONLY place where UI refreshes!)"""
	if hero_id not in dirty_hero_ids:
		return
	_refresh_equipment()


func _on_equipment_slot_right_clicked(item_id: String, slot: ItemSlot, slot_name: String):
	"""Called when an equipment slot is right-clicked (unequip)"""
	if InventoryManager.unequip_item_atomic(hero_id, slot_name):
		pass  # Success
	else:
		pass  # Failure (starter equipment or inventory full)


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
	var gap = 20.0  # Space between columns
	var slot_size = (available_width - gap) / 2.0

	# Clamp to reasonable min/max
	slot_size = clampf(slot_size, 120.0, 300.0)

	# Apply tile-based sizing (Diablo 2-style fixed tile grids)
	_resize_slot_container(helmet_container, _calculate_tile_size(HELMET_GRID))      # 2×2 tiles = 165×165px
	_resize_slot_container(hand_left_container, _calculate_tile_size(HAND_GRID))     # 2×4 tiles = 165×330px
	_resize_slot_container(hand_right_container, _calculate_tile_size(HAND_GRID))    # 2×4 tiles = 165×330px
	_resize_slot_container(armor_container, _calculate_tile_size(ARMOR_GRID))        # 2×3 tiles = 165×250px
	_resize_slot_container(accessory1_container, _calculate_tile_size(ACCESSORY_GRID))  # 1×1 tiles = 80×80px
	_resize_slot_container(accessory2_container, _calculate_tile_size(ACCESSORY_GRID))  # 1×1 tiles = 80×80px



func _calculate_tile_size(grid_dimensions: Vector2i) -> Vector2:
	"""Calculate pixel size from tile grid dimensions"""
	var width = (grid_dimensions.x * TILE_SIZE) + ((grid_dimensions.x - 1) * TILE_GAP)
	var height = (grid_dimensions.y * TILE_SIZE) + ((grid_dimensions.y - 1) * TILE_GAP)
	return Vector2(width, height)


func _resize_slot_container(container: Control, size: Vector2):
	"""Resize an equipment slot container to specified dimensions"""
	if container:
		container.custom_minimum_size = size


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
	for y in grid_height:
		for x in grid_width:
			var slot = item_slot_scene.instantiate() as ItemSlot
			var i = y * grid_width + x
			slot.slot_index = i
			slot.slot_type = "inventory"
			slot.grid_x = x
			slot.grid_y = y

			# Connect signals
			slot.item_clicked.connect(_on_item_slot_clicked)
			slot.item_right_clicked.connect(_on_item_slot_right_clicked)

			shared_stash_grid.add_child(slot)
			stash_item_slots.append(slot)

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
	"""Refresh shared stash grid in common chest mode"""
	print("[EquipmentView] 🔄 Refreshing shared stash grid...")

	# Validate managers
	if not InventoryManager:
		print("[EquipmentView] ❌ InventoryManager not found!")
		return

	# Clear shared stash grid
	for slot in stash_item_slots:
		slot.clear_slot()
		slot.is_root_slot = true
		slot.occupied_by_item_id = ""
		slot.visible = true
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

	# Load shared stash items
	var stash_items = InventoryManager.get_all_items()
	_populate_grid(stash_items, stash_item_slots, false)  # false = shared stash


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


func _populate_grid(items: Array, slots: Array[ItemSlot], is_hero_inventory: bool):
	"""Populate a specific grid with items"""
	for item_info in items:
		var item_id = item_info.item_id
		var item_data = item_info.item_data

		# Get item's grid position
		var pos: Dictionary
		if is_hero_inventory:
			pos = HeroInventoryManager.get_grid_position(hero_id, item_id)
		else:
			pos = InventoryManager.get_item_position(item_id)

		if pos.x == -1 or pos.y == -1:
			continue

		# Find root slot
		var root_slot = _get_slot_at_position_in_array(pos.x, pos.y, slots)
		if root_slot == null:
			continue

		# Set item
		root_slot.set_item(item_id, item_info.quantity, item_info.upgrade_level, item_info.get("rolled_affixes", {}))
		root_slot.is_root_slot = true

		# Mark occupied cells
		for dy in range(item_data.inventory_height):
			for dx in range(item_data.inventory_width):
				if dx == 0 and dy == 0:
					continue

				var occupied_slot = _get_slot_at_position_in_array(pos.x + dx, pos.y + dy, slots)
				if occupied_slot:
					occupied_slot.is_root_slot = false
					occupied_slot.occupied_by_item_id = item_id
					occupied_slot.update_display()

	# Update all slot displays
	for slot in slots:
		slot.update_display()


func _get_slot_at_position_in_array(x: int, y: int, slots: Array[ItemSlot]) -> ItemSlot:
	"""Get slot at grid coordinates from specific slot array"""
	var grid_width = InventoryManager.GRID_WIDTH
	var index = y * grid_width + x

	if index >= 0 and index < slots.size():
		return slots[index]

	return null


func _on_item_slot_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is clicked in common chest mode - handle Ctrl+Click transfers"""
	var ctrl_held = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)

	if common_chest_mode and ctrl_held:
		_quick_transfer_item(item_id, slot)


func _on_item_slot_right_clicked(item_id: String, slot: ItemSlot):
	"""Called when an item slot is right-clicked in common chest mode"""
	# TODO: Add context menu if needed
	pass


func _quick_transfer_item(item_id: String, slot: ItemSlot):
	"""Ctrl+Click quick transfer in common chest mode (stash → hero inventory)"""
	if hero_id == "":
		return

	if not HeroInventoryManager or not InventoryManager:
		return

	# Check if slot is in shared stash grid
	if slot not in stash_item_slots:
		return  # Slot not in stash grid

	var item_data = ItemDatabase.get_item(item_id)
	if not item_data:
		return

	# Transfer from shared stash → hero inventory
	var success = HeroInventoryManager.transfer_from_shared_stash(hero_id, item_id, 1)

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
		common_chest_toggle.button_pressed = false  # This triggers _on_common_chest_toggled
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

	if InventoryManager:
		if InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
			InventoryManager.inventory_changed.disconnect(_on_inventory_changed)
