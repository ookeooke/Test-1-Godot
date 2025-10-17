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
@onready var enemy_list_container = $PanelContainer/MarginContainer/VBoxContainer/EnemyListScroll/EnemyListContainer

# Update timer for enemy list
var update_timer: Timer

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

	# Create update timer for enemy list
	update_timer = Timer.new()
	update_timer.wait_time = 0.1  # Update 10 times per second
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	update_timer.start()

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
	update_enemy_list()

func _on_gold_changed(_new_amount):
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

func _on_update_timer_timeout():
	"""Update enemy list periodically"""
	update_enemy_list()

func update_enemy_list():
	"""Update the list of enemies in range"""
	if not tower or not enemy_list_container:
		return

	# Clear existing labels
	for child in enemy_list_container.get_children():
		child.queue_free()

	# Get enemies in range from tower
	if not "enemies_in_range" in tower:
		return

	var enemies = tower.enemies_in_range.duplicate()

	# Filter out invalid/dead enemies
	enemies = enemies.filter(func(e):
		return (is_instance_valid(e)
			and (not e.has_method("is_dead") or not e.is_dead())
			and ("current_health" not in e or e.current_health > 0.0))
	)

	if enemies.is_empty():
		var no_enemies_label = Label.new()
		no_enemies_label.text = "No enemies in range"
		no_enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_enemies_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		enemy_list_container.add_child(no_enemies_label)
		return

	# Sort enemies based on targeting mode
	var targeting_mode = tower.targeting_mode if "targeting_mode" in tower else 0

	if targeting_mode == 0:  # FIRST mode - sort by progress (descending)
		enemies.sort_custom(func(a, b):
			return _get_enemy_progress(a) > _get_enemy_progress(b)
		)
	else:  # STRONG mode - sort by health (descending)
		enemies.sort_custom(func(a, b):
			return _get_enemy_health(a) > _get_enemy_health(b)
		)

	# Create labels for each enemy
	var position = 1
	for enemy in enemies:
		var enemy_label = Label.new()

		# Get enemy info
		var enemy_name = enemy.get_enemy_name() if enemy.has_method("get_enemy_name") else "Enemy"
		var health = _get_enemy_health(enemy)
		var max_health = enemy.max_health if "max_health" in enemy else health
		var progress = _get_enemy_progress(enemy)
		var progress_percent = int(progress * 100)

		# Format: [1st] Goblin (HP: 45/100, 78%)
		var position_suffix = _get_position_suffix(position)
		enemy_label.text = "[%d%s] %s (HP: %d/%d, %d%%)" % [
			position, position_suffix, enemy_name, health, max_health, progress_percent
		]

		# Set smaller font size
		enemy_label.add_theme_font_size_override("font_size", 12)

		# Color code by priority (1st is red, others fade)
		if position == 1:
			enemy_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red for current target
		elif position == 2:
			enemy_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))  # Orange
		else:
			enemy_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Gray

		enemy_list_container.add_child(enemy_label)
		position += 1

func _get_position_suffix(pos: int) -> String:
	"""Get suffix for position (1st, 2nd, 3rd, etc.)"""
	if pos == 1:
		return "st"
	elif pos == 2:
		return "nd"
	elif pos == 3:
		return "rd"
	else:
		return "th"

func _get_enemy_progress(enemy) -> float:
	"""Get enemy's progress along path"""
	if not enemy or not is_instance_valid(enemy):
		return 0.0

	var path_follower = enemy.get_parent()
	if path_follower and path_follower is PathFollow2D:
		return path_follower.progress_ratio

	return 0.0

func _get_enemy_health(enemy) -> float:
	"""Get enemy's current health"""
	if not enemy or not is_instance_valid(enemy):
		return 0.0

	if "current_health" in enemy:
		return float(enemy.current_health)

	return 0.0
