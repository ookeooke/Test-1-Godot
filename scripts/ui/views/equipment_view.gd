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
@onready var hero_name_label: Label = $MarginContainer/VBoxContainer/HeaderContainer/HeroInfoVBox/HeroNameLabel if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroInfoVBox/HeroNameLabel") else null
@onready var hero_portrait: ColorRect = $MarginContainer/VBoxContainer/HeaderContainer/HeroPortrait if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroPortrait") else null
@onready var switch_hero_button: Button = $MarginContainer/VBoxContainer/HeaderContainer/HeroInfoVBox/SwitchHeroButton if has_node("MarginContainer/VBoxContainer/HeaderContainer/HeroInfoVBox/SwitchHeroButton") else null

var equipment_manager: EquipmentManager = null


func _ready():
	super._ready()
	view_name = "Equipment"

	# Create equipment slots
	_create_equipment_slots()

	# Create or find equipment manager
	_setup_equipment_manager()

	# Connect switch hero button
	if switch_hero_button:
		switch_hero_button.pressed.connect(_on_switch_hero_button_pressed)


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
	"""Update the stats text display"""
	if not stats_label or not equipment_manager:
		return

	var stats_text = "[center][b]EQUIPMENT STATS[/b][/center]\n\n"

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
