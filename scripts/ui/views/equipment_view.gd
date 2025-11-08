extends BasePanelView
class_name EquipmentView

## EquipmentView - Shows hero's equipped items and stats
## Allows drag-drop from inventory to equipment slots
## Extends BasePanelView for use in FlexiblePanel

signal equipment_slot_clicked(slot_name: String)
signal switch_hero_requested

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")
@export var hero_id: String = "ranger"

# Equipment slots (ItemSlot instances)
var weapon_slot: ItemSlot
var armor_slot: ItemSlot
var accessory1_slot: ItemSlot
var accessory2_slot: ItemSlot

# UI References
@onready var weapon_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/WeaponSlot/WeaponContainer if has_node("MarginContainer/VBoxContainer/EquipmentGrid/WeaponSlot/WeaponContainer") else null
@onready var armor_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/ArmorSlot/ArmorContainer if has_node("MarginContainer/VBoxContainer/EquipmentGrid/ArmorSlot/ArmorContainer") else null
@onready var accessory1_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/Accessory1Slot/Accessory1Container if has_node("MarginContainer/VBoxContainer/EquipmentGrid/Accessory1Slot/Accessory1Container") else null
@onready var accessory2_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/Accessory2Slot/Accessory2Container if has_node("MarginContainer/VBoxContainer/EquipmentGrid/Accessory2Slot/Accessory2Container") else null

@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsContainer/StatsLabel if has_node("MarginContainer/VBoxContainer/StatsContainer/StatsLabel") else null
@onready var hero_name_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/HeroNameLabel if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroNameLabel") else null
@onready var hero_portrait: ColorRect = $MarginContainer/VBoxContainer/HeaderContainer/HeroPortrait if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroPortrait") else null
@onready var switch_hero_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/SwitchHeroButton if has_node("MarginContainer/VBoxContainer/HeaderContainer/SwitchHeroButton") else null

var equipment_manager: EquipmentManager = null


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

	# Connect switch hero button
	if switch_hero_button:
		switch_hero_button.pressed.connect(_on_switch_hero_button_pressed)

	# Setup responsive slot sizing
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()  # Initial sizing


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
	# Weapon slot
	weapon_slot = item_slot_scene.instantiate() as ItemSlot
	weapon_slot.slot_type = "equipment"
	weapon_slot.equipment_filter = ItemData.EquipSlot.WEAPON
	weapon_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("weapon"))
	if weapon_container:
		weapon_container.add_child(weapon_slot)

	# Armor slot
	armor_slot = item_slot_scene.instantiate() as ItemSlot
	armor_slot.slot_type = "equipment"
	armor_slot.equipment_filter = ItemData.EquipSlot.ARMOR
	armor_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("armor"))
	if armor_container:
		armor_container.add_child(armor_slot)

	# Accessory 1 slot
	accessory1_slot = item_slot_scene.instantiate() as ItemSlot
	accessory1_slot.slot_type = "equipment"
	accessory1_slot.equipment_filter = ItemData.EquipSlot.ACCESSORY
	accessory1_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("accessory_1"))
	if accessory1_container:
		accessory1_container.add_child(accessory1_slot)

	# Accessory 2 slot
	accessory2_slot = item_slot_scene.instantiate() as ItemSlot
	accessory2_slot.slot_type = "equipment"
	accessory2_slot.equipment_filter = ItemData.EquipSlot.ACCESSORY
	accessory2_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("accessory_2"))
	if accessory2_container:
		accessory2_container.add_child(accessory2_slot)


func _setup_equipment_manager():
	"""Find or create the equipment manager for this hero"""
	# First, try to find hero in scene (if in battle)
	var heroes = get_tree().get_nodes_in_group("hero")
	for hero in heroes:
		if hero.has_method("get_hero_id") and hero.get_hero_id() == hero_id:
			if hero.has_node("EquipmentManager"):
				equipment_manager = hero.get_node("EquipmentManager")
				if not equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
					equipment_manager.equipment_changed.connect(_on_equipment_changed)
				print("[EquipmentView] Found equipment manager on hero: ", hero_id)
				_refresh_equipment()
				return

	# Hero not in scene (e.g., on world map) - create standalone EquipmentManager
	if not equipment_manager:
		equipment_manager = EquipmentManager.new()
		equipment_manager.hero_id = hero_id
		add_child(equipment_manager)

		# Connect signals
		if not equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
			equipment_manager.equipment_changed.connect(_on_equipment_changed)

		print("[EquipmentView] Created standalone equipment manager for hero: ", hero_id)
		_refresh_equipment()


func set_equipment_manager(manager: EquipmentManager):
	"""Manually set the equipment manager"""
	if equipment_manager and equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
		equipment_manager.equipment_changed.disconnect(_on_equipment_changed)

	equipment_manager = manager

	if equipment_manager:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)
		_refresh_equipment()


func _refresh_equipment():
	"""Refresh all equipment slots from equipment manager"""
	if not equipment_manager:
		return

	# Update weapon slot
	var weapon_id = equipment_manager.get_equipped_item("weapon")
	if weapon_id != "":
		weapon_slot.set_item(weapon_id, 1, 0)
	else:
		weapon_slot.clear_slot()

	# Update armor slot
	var armor_id = equipment_manager.get_equipped_item("armor")
	if armor_id != "":
		armor_slot.set_item(armor_id, 1, 0)
	else:
		armor_slot.clear_slot()

	# Update accessory 1 slot
	var acc1_id = equipment_manager.get_equipped_item("accessory_1")
	if acc1_id != "":
		accessory1_slot.set_item(acc1_id, 1, 0)
	else:
		accessory1_slot.clear_slot()

	# Update accessory 2 slot
	var acc2_id = equipment_manager.get_equipped_item("accessory_2")
	if acc2_id != "":
		accessory2_slot.set_item(acc2_id, 1, 0)
	else:
		accessory2_slot.clear_slot()

	# Update hero info
	_update_hero_info()

	# Update stats display
	_update_stats_display()


func _update_hero_info():
	"""Update hero name and portrait"""
	if hero_name_label:
		hero_name_label.text = hero_id.capitalize()

	if hero_portrait:
		# Set color based on hero type
		match hero_id:
			"ranger":
				hero_portrait.color = Color(0.4, 0.6, 0.8)
			"warrior":
				hero_portrait.color = Color(0.8, 0.4, 0.4)
			"mage":
				hero_portrait.color = Color(0.6, 0.4, 0.8)
			_:
				hero_portrait.color = Color(0.5, 0.5, 0.5)


func _update_stats_display():
	"""Update the stats text display - Professional stats comparison (Base vs Equipped)"""
	if not stats_label or not equipment_manager:
		return

	# Get hero data
	var hero_data = HeroDatabase.get_hero(hero_id)
	if not hero_data:
		stats_label.text = "[center][color=red]Hero data not found[/color][/center]"
		return

	var stats_text = "[center][b]HERO STATS[/b][/center]\n\n"

	# Calculate total stats with equipment bonuses
	var modifiers = equipment_manager.get_all_stat_modifiers()

	# Calculate bonuses by stat type
	var damage_bonus: float = 0.0
	var health_bonus: float = 0.0
	var defense_bonus: float = 0.0
	var range_bonus: float = 0.0
	var attack_speed_bonus: float = 0.0
	var crit_bonus: float = 0.0

	for mod in modifiers:
		var desc_lower = mod.description.to_lower()

		# Parse stat modifiers (simplified - you may need to adjust based on your modifier system)
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
	var final_damage = hero_data.base_damage + damage_bonus
	var final_health = hero_data.base_health + health_bonus
	var final_defense = hero_data.base_defense + defense_bonus
	var final_range = hero_data.base_range + range_bonus
	var final_attack_speed = hero_data.base_attack_speed * (1.0 + attack_speed_bonus)
	var final_crit = hero_data.base_crit_chance + crit_bonus

	# Display stats in professional format: "Stat Name: Base → Final (+Bonus)"
	stats_text += _format_stat_line("Damage", hero_data.base_damage, final_damage, damage_bonus)
	stats_text += _format_stat_line("Health", hero_data.base_health, final_health, health_bonus)
	stats_text += _format_stat_line("Defense", hero_data.base_defense, final_defense, defense_bonus)
	stats_text += _format_stat_line("Range", hero_data.base_range, final_range, range_bonus)
	stats_text += _format_stat_line_float("Attack Speed", hero_data.base_attack_speed, final_attack_speed, attack_speed_bonus, true)
	stats_text += _format_stat_line_float("Crit Chance", hero_data.base_crit_chance * 100, final_crit * 100, crit_bonus * 100, false, "%")

	stats_label.text = stats_text


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


func _on_equipment_changed():
	"""Called when equipment changes"""
	_refresh_equipment()


func _on_equipment_slot_right_clicked(item_id: String, slot: ItemSlot, slot_name: String):
	"""Called when an equipment slot is right-clicked (unequip)"""
	if equipment_manager:
		equipment_manager.unequip_item(slot_name)
		print("[EquipmentView] Unequipped item from: ", slot_name)


func _on_switch_hero_button_pressed():
	"""Called when Switch Hero button is pressed"""
	switch_hero_requested.emit()
	print("[EquipmentView] Switch hero requested")


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

	# Apply size to all equipment slot containers
	_resize_slot_container(weapon_container, slot_size)
	_resize_slot_container(armor_container, slot_size)
	_resize_slot_container(accessory1_container, slot_size)
	_resize_slot_container(accessory2_container, slot_size)

	print("[EquipmentView] Resized equipment slots to %.0fpx (panel: %.0fpx)" % [slot_size, panel_width])


func _resize_slot_container(container: Control, size: float):
	"""Resize an equipment slot container"""
	if container:
		container.custom_minimum_size = Vector2(size, size)


func _get_parent_panel() -> Control:
	"""Get the parent FlexiblePanel to determine available width"""
	var node = get_parent()
	while node != null:
		if node is Panel or node is PanelContainer:
			return node
		node = node.get_parent()
	return null
