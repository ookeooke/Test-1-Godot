extends PanelContainer
class_name EquipmentPanel

## EquipmentPanel - Shows hero's equipped items and stats
## Allows drag-drop from inventory to equipment slots

signal equipment_slot_clicked(slot_name: String)

@export var item_slot_scene: PackedScene = preload("res://scenes/ui/item_slot.tscn")
@export var hero_id: String = "ranger"

# Equipment slots (ItemSlot instances)
var weapon_slot: ItemSlot
var armor_slot: ItemSlot
var accessory1_slot: ItemSlot
var accessory2_slot: ItemSlot

# UI References
@onready var weapon_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/WeaponContainer if has_node("MarginContainer/VBoxContainer/EquipmentGrid/WeaponContainer") else null
@onready var armor_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/ArmorContainer if has_node("MarginContainer/VBoxContainer/EquipmentGrid/ArmorContainer") else null
@onready var accessory1_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/Accessory1Container if has_node("MarginContainer/VBoxContainer/EquipmentGrid/Accessory1Container") else null
@onready var accessory2_container: Control = $MarginContainer/VBoxContainer/EquipmentGrid/Accessory2Container if has_node("MarginContainer/VBoxContainer/EquipmentGrid/Accessory2Container") else null

@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsContainer/StatsLabel if has_node("MarginContainer/VBoxContainer/StatsContainer/StatsLabel") else null
@onready var hero_name_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/HeroNameLabel if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroNameLabel") else null

# equipment_manager removed - now using HeroEquipmentRegistry


func _ready():
	# Create equipment slots
	_create_equipment_slots()

	# Find hero's equipment manager
	_find_equipment_manager()

	# Initial refresh
	refresh_equipment()


func _create_equipment_slots():
	"""Create ItemSlot instances for each equipment slot"""
	# Weapon slot
	weapon_slot = item_slot_scene.instantiate() as ItemSlot
	weapon_slot.slot_type = "equipment"
	weapon_slot.equipment_filter = ItemData.EquipSlot.WEAPON
	weapon_slot.equipment_slot_name = "weapon"
	weapon_slot.hero_id = hero_id
	weapon_slot.item_right_clicked.connect(_on_equipment_slot_right_clicked.bind("weapon"))
	if weapon_container:
		weapon_container.add_child(weapon_slot)

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


func _find_equipment_manager():
	"""Setup equipment registry integration"""
	# Register hero if not already registered
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)

	# Connect to registry batch update signal
	if not HeroEquipmentRegistry.batch_update_completed.is_connected(_on_batch_update):
		HeroEquipmentRegistry.batch_update_completed.connect(_on_batch_update)



func refresh_equipment():
	"""Refresh all equipment slots from HeroEquipmentRegistry"""
	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)

	# Update weapon slot
	var weapon_id = equipped_items.get("weapon", "")
	if weapon_id != "":
		weapon_slot.set_item(weapon_id, 1, 0)
	else:
		weapon_slot.clear_slot()

	# Update armor slot
	var armor_id = equipped_items.get("armor", "")
	if armor_id != "":
		armor_slot.set_item(armor_id, 1, 0)
	else:
		armor_slot.clear_slot()

	# Update accessory 1 slot
	var acc1_id = equipped_items.get("accessory_1", "")
	if acc1_id != "":
		accessory1_slot.set_item(acc1_id, 1, 0)
	else:
		accessory1_slot.clear_slot()

	# Update accessory 2 slot
	var acc2_id = equipped_items.get("accessory_2", "")
	if acc2_id != "":
		accessory2_slot.set_item(acc2_id, 1, 0)
	else:
		accessory2_slot.clear_slot()

	# Update stats display
	_update_stats_display()


func _update_stats_display():
	"""Update the stats text display"""
	if not stats_label:
		return

	var stats_text = "[b]HERO STATS[/b]\n\n"

	# Get modifiers from equipment via registry
	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
	var modifiers: Array[StatModifier] = []
	for item_id in equipped_items.values():
		if item_id == "":
			continue
		var item_data = ItemDatabase.get_item(item_id)
		if item_data:
			var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)
			modifiers.append_array(item_data.get_stat_modifiers(upgrade_level))

	if modifiers.is_empty():
		stats_text += "\n[color=gray]No equipment equipped[/color]"
	else:
		stats_text += "[b]Active Modifiers:[/b]\n\n"

		# Group modifiers by stat type for cleaner display
		var damage_mods = []
		var health_mods = []
		var defense_mods = []
		var range_mods = []
		var attack_speed_mods = []
		var crit_mods = []

		for mod in modifiers:
			var desc_lower = mod.description.to_lower()
			if "damage" in desc_lower and "melee" not in desc_lower:
				damage_mods.append(mod)
			elif "health" in desc_lower:
				health_mods.append(mod)
			elif "defense" in desc_lower:
				defense_mods.append(mod)
			elif "range" in desc_lower:
				range_mods.append(mod)
			elif "attack speed" in desc_lower:
				attack_speed_mods.append(mod)
			elif "crit" in desc_lower:
				crit_mods.append(mod)

		# Display grouped modifiers
		if not damage_mods.is_empty():
			stats_text += "[color=green]Damage Bonuses:[/color]\n"
			for mod in damage_mods:
				stats_text += "  %s\n" % _format_modifier(mod)
			stats_text += "\n"

		if not health_mods.is_empty():
			stats_text += "[color=green]Health Bonuses:[/color]\n"
			for mod in health_mods:
				stats_text += "  %s\n" % _format_modifier(mod)
			stats_text += "\n"

		if not range_mods.is_empty():
			stats_text += "[color=green]Range Bonuses:[/color]\n"
			for mod in range_mods:
				stats_text += "  %s\n" % _format_modifier(mod)
			stats_text += "\n"

		if not attack_speed_mods.is_empty():
			stats_text += "[color=green]Attack Speed Bonuses:[/color]\n"
			for mod in attack_speed_mods:
				stats_text += "  %s\n" % _format_modifier(mod)
			stats_text += "\n"

		if not defense_mods.is_empty():
			stats_text += "[color=green]Defense Bonuses:[/color]\n"
			for mod in defense_mods:
				stats_text += "  %s\n" % _format_modifier(mod)
			stats_text += "\n"

		if not crit_mods.is_empty():
			stats_text += "[color=green]Critical Bonuses:[/color]\n"
			for mod in crit_mods:
				stats_text += "  %s\n" % _format_modifier(mod)
			stats_text += "\n"

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


func _on_batch_update(dirty_hero_ids: Array[String]) -> void:
	"""Handle batched equipment update from registry"""
	if hero_id not in dirty_hero_ids:
		return
	refresh_equipment()


func _on_equipment_slot_right_clicked(item_id: String, slot: ItemSlot, slot_name: String):
	"""Called when an equipment slot is right-clicked (unequip)"""
	if InventoryManager.unequip_item_atomic(hero_id, slot_name):
		pass  # Success
	else:
		pass  # Failure
