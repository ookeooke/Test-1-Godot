extends Control

# ============================================
# TOWER INFO MENU - Shows tower stats and upgrade options
# ============================================

signal upgrade_selected(tower)
signal sell_selected(tower)
signal menu_closed()

var tower = null
var spot = null

# Upgrade costs (dynamic based on tower level)
var upgrade_cost = 60  # Default, will be updated from tower

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

# Rally button for garrison towers (created dynamically)
var rally_button: Button = null

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
		# Show/hide targeting buttons based on tower type
		_update_tower_type_ui()

func update_display():
	"""Update the displayed information"""
	print("\n📋 [TowerInfoMenu] update_display() called")

	if not tower:
		print("⚠️ [TowerInfoMenu] WARNING: No tower reference!")
		return

	print("🔧 [TowerInfoMenu] Tower is valid - updating display")

	# Detect tower type and show appropriate info
	var is_garrison = _is_garrison_tower()
	print("🔧 [TowerInfoMenu] Is garrison tower: %s" % str(is_garrison))

	# Set tower name with level
	if tower_name_label:
		if is_garrison:
			tower_name_label.text = "Soldier Tower"
		else:
			var level = tower.tower_level if "tower_level" in tower else 1
			var path_text = ""
			if "upgrade_path" in tower and tower.upgrade_path != "":
				path_text = " [%s]" % tower.upgrade_path.to_upper()
			tower_name_label.text = "Archer Tower Lv%d%s" % [level, path_text]
		print("✅ [TowerInfoMenu] Tower name set: '%s'" % tower_name_label.text)
	else:
		print("❌ [TowerInfoMenu] ERROR: tower_name_label is NULL!")

	# Set stats
	if stats_label and tower:
		if is_garrison:
			_update_garrison_stats()
		else:
			var damage = tower.damage if "damage" in tower else 0
			var attack_speed = tower.attack_speed if "attack_speed" in tower else 0
			var range_val = tower.range_radius if "range_radius" in tower else 0

			stats_label.text = "Damage: %d\nAttack Speed: %.1f/s\nRange: %d" % [damage, attack_speed, range_val]
		print("✅ [TowerInfoMenu] Stats set: '%s'" % stats_label.text.replace("\n", " | "))
	else:
		if not stats_label:
			print("❌ [TowerInfoMenu] ERROR: stats_label is NULL!")
		else:
			print("⚠️ [TowerInfoMenu] Tower is invalid for stats display")

	# Set button text with costs (get from tower if available)
	if upgrade_button:
		print("🔧 [TowerInfoMenu] Upgrade button exists - configuring...")
		# Get upgrade cost from tower
		if tower and tower.has_method("get_upgrade_cost"):
			upgrade_cost = tower.get_upgrade_cost()
			print("🔧 [TowerInfoMenu] Upgrade cost from tower: %d gold" % upgrade_cost)

			# Check if this is a path choice upgrade
			if tower.has_method("needs_path_choice") and tower.needs_path_choice():
				upgrade_button.text = "Choose Path\n" + str(upgrade_cost) + "g"
				print("✅ [TowerInfoMenu] Button text: 'Choose Path %dg'" % upgrade_cost)
			elif upgrade_cost > 0:
				var level = tower.tower_level if "tower_level" in tower else 1
				upgrade_button.text = "Upgrade (Lv%d)\n%dg" % [level + 1, upgrade_cost]
				print("✅ [TowerInfoMenu] Button text: 'Upgrade (Lv%d) %dg'" % [level + 1, upgrade_cost])
			else:
				upgrade_button.text = "MAX LEVEL"
				upgrade_button.disabled = true
				print("✅ [TowerInfoMenu] Button text: 'MAX LEVEL' (disabled)")
		else:
			upgrade_button.text = "Upgrade\n" + str(upgrade_cost) + "g"
			print("⚠️ [TowerInfoMenu] Using fallback upgrade cost: %d" % upgrade_cost)
	else:
		print("❌ [TowerInfoMenu] ERROR: upgrade_button is NULL!")

	if sell_button:
		# Calculate 70% of build cost dynamically
		var sell_value = _calculate_sell_value()
		sell_button.text = "Sell\n" + str(sell_value) + "g"
		print("✅ [TowerInfoMenu] Sell button text: 'Sell %dg'" % sell_value)
	else:
		print("❌ [TowerInfoMenu] ERROR: sell_button is NULL!")

	# Update button states
	print("🔧 [TowerInfoMenu] Updating button states...")
	update_button_states()
	update_targeting_buttons()
	update_enemy_list()

	print("📋 [TowerInfoMenu] update_display() complete\n")

func _on_gold_changed(_new_amount):
	update_button_states()

func update_button_states():
	if upgrade_button:
		var can_afford = GameManager.gold >= upgrade_cost
		upgrade_button.disabled = not can_afford
		print("💰 [TowerInfoMenu] Button state - Gold: %d, Cost: %d, Enabled: %s" % [GameManager.gold, upgrade_cost, str(can_afford)])
	else:
		print("❌ [TowerInfoMenu] Cannot update button state - upgrade_button is NULL!")

func _on_upgrade_button_pressed():
	print("\n=== 🔧 UPGRADE BUTTON PRESSED ===")
	print("🔧 [TowerInfoMenu] Tower reference valid: %s" % str(is_instance_valid(tower)))
	print("🔧 [TowerInfoMenu] Upgrade cost: %d gold" % upgrade_cost)
	print("🔧 [TowerInfoMenu] Current gold: %d gold" % GameManager.gold)

	if tower:
		print("🔧 [TowerInfoMenu] Tower type: %s" % tower.get_class())
		if "tower_level" in tower:
			print("🔧 [TowerInfoMenu] Tower level BEFORE upgrade: %d" % tower.tower_level)
			print("🔧 [TowerInfoMenu] Tower damage BEFORE upgrade: %d" % tower.damage)
			print("🔧 [TowerInfoMenu] Tower attack_speed BEFORE upgrade: %.1f" % tower.attack_speed)
			print("🔧 [TowerInfoMenu] Tower range BEFORE upgrade: %d" % tower.range_radius)
		else:
			print("⚠️ [TowerInfoMenu] WARNING: Tower has no tower_level property!")

	if GameManager.spend_gold(upgrade_cost):
		print("✅ [TowerInfoMenu] Gold spent successfully!")
		print("🔧 [TowerInfoMenu] Emitting upgrade_selected signal...")
		upgrade_selected.emit(tower)

		# Wait for upgrade to process
		print("🔧 [TowerInfoMenu] Waiting for upgrade to process...")
		await get_tree().process_frame

		if tower and "tower_level" in tower:
			print("🔧 [TowerInfoMenu] Tower level AFTER upgrade: %d" % tower.tower_level)
			print("🔧 [TowerInfoMenu] Tower damage AFTER upgrade: %d" % tower.damage)
			print("🔧 [TowerInfoMenu] Tower attack_speed AFTER upgrade: %.1f" % tower.attack_speed)
			print("🔧 [TowerInfoMenu] Tower range AFTER upgrade: %d" % tower.range_radius)

		# Refresh menu to show new stats immediately
		print("🔧 [TowerInfoMenu] Refreshing menu display...")
		update_display()

		# Show brief visual confirmation
		if tower_name_label:
			var original_text = tower_name_label.text
			var original_color = tower_name_label.modulate
			print("🔧 [TowerInfoMenu] Showing '✓ UPGRADED!' confirmation")
			tower_name_label.text = "✓ UPGRADED!"
			tower_name_label.modulate = Color(0, 1, 0)  # Green
			await get_tree().create_timer(0.4).timeout
			tower_name_label.modulate = original_color  # Reset color
			print("🔧 [TowerInfoMenu] Restoring original menu text")
			update_display()  # Restore original text with new stats
		print("=== ✅ UPGRADE COMPLETE ===\n")
	else:
		print("❌ [TowerInfoMenu] Not enough gold for upgrade!")
		print("   Need: %d, Have: %d" % [upgrade_cost, GameManager.gold])
		print("=== ❌ UPGRADE FAILED ===\n")

func _on_sell_button_pressed():
	# Calculate 70% of build cost dynamically
	var sell_value = _calculate_sell_value()
	GameManager.add_gold(sell_value)
	print("Tower sold for ", sell_value, " gold")
	sell_selected.emit(tower)
	queue_free()

func _calculate_sell_value() -> int:
	"""Calculate sell value as 70% of tower's build cost"""
	if tower and "build_cost" in tower:
		return int(tower.build_cost * 0.7)
	else:
		# Fallback for towers without build_cost property
		return 70

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

# ============================================
# GARRISON TOWER SUPPORT
# ============================================

func _is_garrison_tower() -> bool:
	"""Check if this is a garrison/soldier tower"""
	if not tower:
		return false
	# Garrison towers have soldier_scene property
	return "soldier_scene" in tower or tower.is_in_group("garrison")

func _update_garrison_stats():
	"""Update stats display for garrison towers"""
	if not tower or not tower.has_method("get_garrison_info"):
		stats_label.text = "Garrison Tower"
		return

	var info = tower.get_garrison_info()
	var next_respawn_text = ""
	if info["respawning"] > 0:
		next_respawn_text = "\nNext respawn: %.1fs" % info["next_respawn"]

	stats_label.text = "Squad: %d/%d alive%s\nDamage: %.0f\nAttack Speed: %.1f/s" % [
		info["alive"],
		info["squad_size"],
		next_respawn_text,
		tower.soldier_damage if "soldier_damage" in tower else 0,
		tower.soldier_attack_speed if "soldier_attack_speed" in tower else 0
	]

func _update_tower_type_ui():
	"""Show/hide UI elements based on tower type"""
	var is_garrison = _is_garrison_tower()

	# Hide targeting buttons for garrison towers
	if first_button:
		first_button.visible = not is_garrison
	if strong_button:
		strong_button.visible = not is_garrison

	# Show rally button for garrison towers
	if is_garrison:
		_create_rally_button()
	elif rally_button:
		rally_button.queue_free()
		rally_button = null

func _create_rally_button():
	"""Create the rally point button for garrison towers (Kingdom Rush style)"""
	if rally_button:
		return  # Already created

	# Find the targeting buttons container
	var targeting_container = first_button.get_parent() if first_button else null
	if not targeting_container:
		print("ERROR: Could not find targeting buttons container!")
		return

	# Create rally button
	rally_button = Button.new()
	rally_button.text = "🚩 Rally Point"
	rally_button.custom_minimum_size = Vector2(120, 40)
	targeting_container.add_child(rally_button)

	# Connect signal
	rally_button.pressed.connect(_on_rally_button_pressed)

	# Visual styling
	rally_button.modulate = Color(1.0, 0.9, 0.3)  # Gold tint

func _on_rally_button_pressed():
	"""Called when player clicks Rally Point button - enters placement mode"""
	print("🚩 Rally Point button pressed!")

	if tower and tower.has_method("enter_rally_placement_mode"):
		tower.enter_rally_placement_mode()

		# Close the menu so player can click the map
		menu_closed.emit()
		queue_free()
