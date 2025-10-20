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

var equipment_manager: EquipmentManager = null


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


func _find_equipment_manager():
	"""Find the hero's equipment manager in the scene"""
	# Try to find hero in scene
	var heroes = get_tree().get_nodes_in_group("hero")
	for hero in heroes:
		if hero.has_method("get_hero_id") and hero.get_hero_id() == hero_id:
			if hero.has_node("EquipmentManager"):
				equipment_manager = hero.get_node("EquipmentManager")
				equipment_manager.equipment_changed.connect(_on_equipment_changed)
				print("[EquipmentPanel] Found equipment manager for hero: ", hero_id)
				return

	print("[EquipmentPanel] Warning: Could not find equipment manager for hero: ", hero_id)


func set_equipment_manager(manager: EquipmentManager):
	"""Manually set the equipment manager"""
	if equipment_manager and equipment_manager.equipment_changed.is_connected(_on_equipment_changed):
		equipment_manager.equipment_changed.disconnect(_on_equipment_changed)

	equipment_manager = manager

	if equipment_manager:
		equipment_manager.equipment_changed.connect(_on_equipment_changed)
		refresh_equipment()


func refresh_equipment():
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

	# Update stats display
	_update_stats_display()


func _update_stats_display():
	"""Update the stats text display"""
	if not stats_label or not equipment_manager:
		return

	var stats_text = "[b]HERO STATS[/b]\n\n"

	# Get bonuses from equipment
	var damage_bonus = equipment_manager.get_damage_bonus()
	var health_bonus = equipment_manager.get_health_bonus()
	var defense_bonus = equipment_manager.get_defense_bonus()
	var attack_speed_mult = equipment_manager.get_attack_speed_multiplier()
	var range_bonus = equipment_manager.get_range_bonus()
	var crit_bonus = equipment_manager.get_crit_chance_bonus()

	# Display stats with bonuses highlighted
	if damage_bonus > 0:
		stats_text += "Damage: [color=green]+%d[/color]\n" % damage_bonus
	else:
		stats_text += "Damage: Base\n"

	if health_bonus > 0:
		stats_text += "Health: [color=green]+%d[/color]\n" % health_bonus
	else:
		stats_text += "Health: Base\n"

	if defense_bonus > 0:
		stats_text += "Defense: [color=green]+%d[/color]\n" % defense_bonus

	if attack_speed_mult > 1.0:
		stats_text += "Attack Speed: [color=green]%.1fx[/color]\n" % attack_speed_mult

	if range_bonus > 0:
		stats_text += "Range: [color=green]+%d[/color]\n" % range_bonus

	if crit_bonus > 0:
		stats_text += "Crit Chance: [color=green]+%.1f%%[/color]\n" % (crit_bonus * 100)

	if not equipment_manager.has_equipment():
		stats_text += "\n[color=gray]No equipment equipped[/color]"

	stats_label.text = stats_text


func _on_equipment_changed():
	"""Called when equipment changes"""
	refresh_equipment()


func _on_equipment_slot_right_clicked(item_id: String, slot: ItemSlot, slot_name: String):
	"""Called when an equipment slot is right-clicked (unequip)"""
	if equipment_manager:
		equipment_manager.unequip_item(slot_name)
		print("[EquipmentPanel] Unequipped item from: ", slot_name)
