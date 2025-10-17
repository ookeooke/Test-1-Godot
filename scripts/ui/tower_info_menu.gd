extends Control

# ============================================
# TOWER INFO MENU - Shows tower stats and upgrade options
# ============================================

signal upgrade_selected(tower)
signal sell_selected(tower)
signal menu_closed()

var tower = null
var spot = null

# Upgrade costs
var upgrade_cost = 150

# References
@onready var panel = $PanelContainer
@onready var tower_name_label = $PanelContainer/MarginContainer/VBoxContainer/TowerNameLabel
@onready var stats_label = $PanelContainer/MarginContainer/VBoxContainer/StatsLabel
@onready var first_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/FirstButton
@onready var strong_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/StrongButton
@onready var upgrade_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/UpgradeButton
@onready var sell_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SellButton

func _ready():
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)
	if first_button:
		first_button.pressed.connect(_on_first_button_pressed)
	if strong_button:
		strong_button.pressed.connect(_on_strong_button_pressed)

	update_display()

	# Connect to gold changes
	GameManager.gold_changed.connect(_on_gold_changed)

func setup(tower_ref, spot_ref):
	"""Initialize the menu with tower data"""
	tower = tower_ref
	spot = spot_ref
	
	if is_inside_tree():
		update_display()

func update_display():
	"""Update the displayed information"""
	if not tower:
		return

	# Set tower name
	if tower_name_label:
		tower_name_label.text = "Archer Tower"  # TODO: Get from tower

	# Set stats
	if stats_label and tower:
		var damage = tower.damage if "damage" in tower else 0
		var attack_speed = tower.attack_speed if "attack_speed" in tower else 0
		var range_val = tower.range_radius if "range_radius" in tower else 0

		stats_label.text = "Damage: %d\nAttack Speed: %.1f/s\nRange: %d" % [damage, attack_speed, range_val]

	# Set button text with costs
	if upgrade_button:
		upgrade_button.text = "Upgrade\n" + str(upgrade_cost) + "g"
	if sell_button:
		var sell_value = 70  # 70% of original cost
		sell_button.text = "Sell\n" + str(sell_value) + "g"

	# Update button states
	update_button_states()
	update_targeting_buttons()

func _on_gold_changed(new_amount):
	update_button_states()

func update_button_states():
	if upgrade_button:
		upgrade_button.disabled = GameManager.gold < upgrade_cost

func _on_upgrade_button_pressed():
	if GameManager.spend_gold(upgrade_cost):
		print("Tower upgraded!")
		upgrade_selected.emit(tower)
		queue_free()
	else:
		print("Not enough gold for upgrade!")

func _on_sell_button_pressed():
	# Sell for 70% of original cost
	var sell_value = 70  # 70% of 100
	GameManager.add_gold(sell_value)
	print("Tower sold for ", sell_value, " gold")
	sell_selected.emit(tower)
	queue_free()

func update_targeting_buttons():
	"""Update targeting button states based on tower's current mode"""
	if not tower or not "targeting_mode" in tower:
		return

	var mode = tower.targeting_mode

	# Update button colors to show active mode
	if first_button:
		if mode == 0:  # FIRST mode
			first_button.modulate = Color(0.5, 0.8, 1.0)  # Bright cyan
		else:
			first_button.modulate = Color(0.6, 0.6, 0.6)  # Gray

	if strong_button:
		if mode == 1:  # STRONG mode
			strong_button.modulate = Color(1.0, 0.5, 0.5)  # Bright red
		else:
			strong_button.modulate = Color(0.6, 0.6, 0.6)  # Gray

func _on_first_button_pressed():
	"""Set tower to FIRST targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(0)  # TargetingMode.FIRST
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected FIRST mode")

func _on_strong_button_pressed():
	"""Set tower to STRONG targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(1)  # TargetingMode.STRONG
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected STRONG mode")

func _input(event):
	"""Close menu when clicking outside"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not get_global_rect().has_point(get_global_mouse_position()):
				menu_closed.emit()
				get_viewport().set_input_as_handled()
				queue_free()
