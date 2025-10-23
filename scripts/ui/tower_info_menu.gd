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
@onready var first_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/FirstButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/FirstButton") else null
@onready var last_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/LastButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/LastButton") else null
@onready var close_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/CloseButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/CloseButton") else null
@onready var strong_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/StrongButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/StrongButton") else null
@onready var weak_button = $PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/WeakButton if has_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons/WeakButton") else null
@onready var upgrade_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/UpgradeButton
@onready var sell_button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SellButton
@onready var enemy_list_toggle = $PanelContainer/MarginContainer/VBoxContainer/EnemyListToggle
@onready var enemies_label = $PanelContainer/MarginContainer/VBoxContainer/EnemiesLabel
@onready var enemy_list_scroll = $PanelContainer/MarginContainer/VBoxContainer/EnemyListScroll
@onready var enemy_list_container = $PanelContainer/MarginContainer/VBoxContainer/EnemyListScroll/EnemyListContainer

# Update timer for enemy list
var update_timer: Timer

# Enemy list visibility (hidden by default)
var enemy_list_visible = false

# Upgrade preview state (two-click upgrade system)
var is_preview_mode = false
var preview_stats = {}  # Stores what stats will be after upgrade

# Rally button for garrison towers (created dynamically)
var rally_button: Button = null

func _ready():
	# Connect existing buttons first
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)
	if enemy_list_toggle:
		enemy_list_toggle.pressed.connect(_on_enemy_list_toggle_pressed)

	# Create missing targeting buttons dynamically (this modifies the button variables)
	_ensure_all_targeting_buttons_exist()

	# Now connect all targeting buttons (including dynamically created ones)
	if first_button:
		first_button.pressed.connect(_on_first_button_pressed)
	if last_button:
		last_button.pressed.connect(_on_last_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if strong_button:
		strong_button.pressed.connect(_on_strong_button_pressed)
	if weak_button:
		weak_button.pressed.connect(_on_weak_button_pressed)

	# Set smaller font sizes for better UI (reduced for cleaner look)
	if tower_name_label:
		tower_name_label.add_theme_font_size_override("font_size", 12)  # Was 14
	if stats_label:
		stats_label.add_theme_font_size_override("font_size", 10)  # Was 11
	if enemies_label:
		enemies_label.add_theme_font_size_override("font_size", 9)  # Was 10
	if enemy_list_toggle:
		enemy_list_toggle.add_theme_font_size_override("font_size", 9)  # Was 10
	if upgrade_button:
		upgrade_button.add_theme_font_size_override("font_size", 9)  # Was 11
	if sell_button:
		sell_button.add_theme_font_size_override("font_size", 9)  # Was 11
	if first_button:
		first_button.add_theme_font_size_override("font_size", 8)
	if last_button:
		last_button.add_theme_font_size_override("font_size", 8)
	if close_button:
		close_button.add_theme_font_size_override("font_size", 8)
	if strong_button:
		strong_button.add_theme_font_size_override("font_size", 8)
	if weak_button:
		weak_button.add_theme_font_size_override("font_size", 8)

	# Load enemy list visibility preference (removed - was GameManager feature)
	enemy_list_visible = false  # Default to hidden

	# Apply initial visibility state
	_update_enemy_list_visibility()

	update_display()

	# Connect to gold changes
	GameStateManager.gold_changed.connect(_on_gold_changed)

	# Create update timer for enemy list
	update_timer = Timer.new()
	update_timer.wait_time = 0.1  # Update 10 times per second
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	update_timer.start()

func _ensure_all_targeting_buttons_exist():
	"""Dynamically create missing targeting buttons if they don't exist in scene"""
	var targeting_container = null

	# Find the targeting buttons container
	if has_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons"):
		targeting_container = get_node("PanelContainer/MarginContainer/VBoxContainer/TargetingButtons")
	else:
		print("[TowerInfoMenu] WARNING: TargetingButtons container not found!")
		return

	# Helper function to create a button
	var create_button = func(button_name: String, label: String, existing_button):
		if existing_button == null:
			print("[TowerInfoMenu] Creating missing button: %s" % button_name)
			var new_button = Button.new()
			new_button.name = button_name
			new_button.text = label
			new_button.custom_minimum_size = Vector2(60, 30)
			targeting_container.add_child(new_button)
			return new_button
		return existing_button

	# Create missing buttons
	if not last_button:
		last_button = create_button.call("LastButton", "LAST", last_button)
	if not close_button:
		close_button = create_button.call("CloseButton", "CLOSE", close_button)
	if not weak_button:
		weak_button = create_button.call("WeakButton", "WEAK", weak_button)

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
			# Disable BBCode for normal stats display
			stats_label.bbcode_enabled = false

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
		var can_afford = GameStateManager.gold >= upgrade_cost
		upgrade_button.disabled = not can_afford
		print("💰 [TowerInfoMenu] Button state - Gold: %d, Cost: %d, Enabled: %s" % [GameStateManager.gold, upgrade_cost, str(can_afford)])
	else:
		print("❌ [TowerInfoMenu] Cannot update button state - upgrade_button is NULL!")

func _on_upgrade_button_pressed():
	print("\n=== 🔧 UPGRADE BUTTON PRESSED ===")
	print("🔧 [TowerInfoMenu] Preview mode: %s" % str(is_preview_mode))

	# TWO-CLICK SYSTEM
	if not is_preview_mode:
		# FIRST CLICK: Enter preview mode
		print("🔧 [TowerInfoMenu] First click - entering preview mode")
		_enter_preview_mode()
	else:
		# SECOND CLICK: Actually perform upgrade
		print("🔧 [TowerInfoMenu] Second click - confirming upgrade")
		_confirm_upgrade()

func _enter_preview_mode():
	"""First click: Calculate and show upgrade preview with bonuses in green"""
	if not tower:
		return

	print("🔧 [TowerInfoMenu] Entering preview mode")
	is_preview_mode = true

	# Calculate what stats will be after upgrade
	if tower.has_method("get_upgrade_stats"):
		# If tower has a method to preview stats, use it
		preview_stats = tower.get_upgrade_stats()
	else:
		# Calculate preview based on tower level and type
		_calculate_preview_stats()

	# Update stats display to show bonuses
	_update_stats_with_preview()
	print("✅ [TowerInfoMenu] Preview mode active - showing upgrade bonuses")

func _calculate_preview_stats():
	"""Calculate what stats will be after upgrade (fallback method)"""
	if not tower:
		return

	# Get current stats
	var current_damage = tower.damage if "damage" in tower else 0
	var current_attack_speed = tower.attack_speed if "attack_speed" in tower else 0
	var current_range = tower.range_radius if "range_radius" in tower else 0
	var current_level = tower.tower_level if "tower_level" in tower else 1

	# Simple upgrade formula (50% damage, 25% attack speed per level)
	# This is a fallback - towers should implement get_upgrade_stats()
	var damage_bonus = int(current_damage * 0.5)
	var attack_speed_bonus = current_attack_speed * 0.25
	var range_bonus = 0  # Usually range doesn't change

	preview_stats = {
		"damage": current_damage,
		"damage_bonus": damage_bonus,
		"attack_speed": current_attack_speed,
		"attack_speed_bonus": attack_speed_bonus,
		"range": current_range,
		"range_bonus": range_bonus
	}

func _update_stats_with_preview():
	"""Update stats label to show current + bonus (bonus in green)"""
	if not stats_label or not tower:
		return

	var is_garrison = _is_garrison_tower()
	if is_garrison:
		# Garrison towers don't show preview yet (could add later)
		return

	# Use BBCode for colored text
	stats_label.bbcode_enabled = true

	var damage = preview_stats.get("damage", tower.damage)
	var damage_bonus = preview_stats.get("damage_bonus", 0)
	var attack_speed = preview_stats.get("attack_speed", tower.attack_speed)
	var attack_speed_bonus = preview_stats.get("attack_speed_bonus", 0.0)
	var range_val = preview_stats.get("range", tower.range_radius)
	var range_bonus = preview_stats.get("range_bonus", 0)

	# Build stats text with green bonuses
	var stats_text = ""

	# Damage line
	if damage_bonus > 0:
		stats_text += "Damage: %d [color=green]+%d[/color]\n" % [damage, damage_bonus]
	else:
		stats_text += "Damage: %d\n" % damage

	# Attack Speed line
	if attack_speed_bonus > 0:
		stats_text += "Attack Speed: %.1f/s [color=green]+%.1f/s[/color]\n" % [attack_speed, attack_speed_bonus]
	else:
		stats_text += "Attack Speed: %.1f/s\n" % attack_speed

	# Range line
	if range_bonus > 0:
		stats_text += "Range: %d [color=green]+%d[/color]" % [range_val, range_bonus]
	else:
		stats_text += "Range: %d" % range_val

	stats_label.text = stats_text
	print("✅ [TowerInfoMenu] Stats updated with preview bonuses")

func _confirm_upgrade():
	"""Second click: Actually perform the upgrade"""
	if not tower:
		return

	print("🔧 [TowerInfoMenu] Confirming upgrade")
	print("🔧 [TowerInfoMenu] Upgrade cost: %d gold" % upgrade_cost)
	print("🔧 [TowerInfoMenu] Current gold: %d gold" % GameStateManager.gold)

	if GameStateManager.spend_gold(upgrade_cost):
		print("✅ [TowerInfoMenu] Gold spent successfully!")
		print("🔧 [TowerInfoMenu] Emitting upgrade_selected signal...")

		# Exit preview mode
		is_preview_mode = false
		preview_stats = {}

		# Emit upgrade signal
		upgrade_selected.emit(tower)

		# Wait for upgrade to process
		await get_tree().process_frame

		# Refresh menu to show new stats
		print("🔧 [TowerInfoMenu] Refreshing menu display...")
		update_display()

		# Show brief visual confirmation
		if tower_name_label:
			var original_color = tower_name_label.modulate
			print("🔧 [TowerInfoMenu] Showing '✓ UPGRADED!' confirmation")
			tower_name_label.text = "✓ UPGRADED!"
			tower_name_label.modulate = Color(0, 1, 0)  # Green
			await get_tree().create_timer(0.4).timeout
			tower_name_label.modulate = original_color
			print("🔧 [TowerInfoMenu] Restoring original menu text")
			update_display()
		print("=== ✅ UPGRADE COMPLETE ===\n")
	else:
		print("❌ [TowerInfoMenu] Not enough gold for upgrade!")
		print("   Need: %d, Have: %d" % [upgrade_cost, GameStateManager.gold])
		print("=== ❌ UPGRADE FAILED ===\n")

func _cancel_preview():
	"""Cancel preview mode and return to normal stats display"""
	print("🔧 [TowerInfoMenu] Canceling preview mode")
	is_preview_mode = false
	preview_stats = {}

	# Reset stats label to normal (no BBCode)
	if stats_label:
		stats_label.bbcode_enabled = false

	print("✅ [TowerInfoMenu] Preview canceled")

func _on_sell_button_pressed():
	# Calculate 70% of build cost dynamically
	var sell_value = _calculate_sell_value()
	GameStateManager.add_gold(sell_value)
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
	var inactive_color = Color(0.6, 0.6, 0.6)  # Gray

	# Update button colors to show active mode
	if first_button:
		first_button.modulate = Color(0.5, 0.8, 1.0) if mode == 0 else inactive_color
	if last_button:
		last_button.modulate = Color(0.7, 0.9, 1.0) if mode == 1 else inactive_color
	if close_button:
		close_button.modulate = Color(1.0, 1.0, 0.5) if mode == 2 else inactive_color
	if strong_button:
		strong_button.modulate = Color(1.0, 0.5, 0.5) if mode == 3 else inactive_color
	if weak_button:
		weak_button.modulate = Color(1.0, 0.7, 0.3) if mode == 4 else inactive_color

func _on_first_button_pressed():
	"""Set tower to FIRST targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(0)  # TargetingMode.FIRST
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected FIRST mode")

func _on_last_button_pressed():
	"""Set tower to LAST targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(1)  # TargetingMode.LAST
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected LAST mode")

func _on_close_button_pressed():
	"""Set tower to CLOSE targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(2)  # TargetingMode.CLOSE
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected CLOSE mode")

func _on_strong_button_pressed():
	"""Set tower to STRONG targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(3)  # TargetingMode.STRONG
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected STRONG mode")

func _on_weak_button_pressed():
	"""Set tower to WEAK targeting mode"""
	if tower and tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(4)  # TargetingMode.WEAK
		update_targeting_buttons()
		DebugConfig.log_targeting("Player selected WEAK mode")

func _gui_input(event):
	"""Handle input on this control - consume events inside menu"""
	# This function runs during the UI/Control stage
	# Any event handled here should call accept_event() to prevent propagation

	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var is_press = false
		if event is InputEventMouseButton:
			is_press = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			is_press = event.pressed

		if is_press:
			# Click is inside the panel (this _gui_input only fires for events on this Control)
			# Consume the event so it doesn't reach the world
			print("⏸️ [TowerInfoMenu] Click inside menu - consuming event")
			accept_event()

func _unhandled_input(event):
	"""Close menu when clicking outside (during unhandled input stage)"""
	# This runs AFTER UI controls, so if we get here, the click was outside the menu
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var is_click = false
		if event is InputEventMouseButton:
			is_click = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			is_click = event.pressed

		if is_click:
			# If in preview mode, cancel preview and close menu
			if is_preview_mode:
				print("❌ [TowerInfoMenu] Canceling preview - clicked outside")
				_cancel_preview()

			print("✅ [TowerInfoMenu] Closing menu - clicked outside")
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

	match targeting_mode:
		0:  # FIRST - sort by progress (descending)
			enemies.sort_custom(func(a, b):
				return _get_enemy_progress(a) > _get_enemy_progress(b)
			)
		1:  # LAST - sort by progress (ascending)
			enemies.sort_custom(func(a, b):
				return _get_enemy_progress(a) < _get_enemy_progress(b)
			)
		2:  # CLOSE - sort by distance to tower (ascending)
			enemies.sort_custom(func(a, b):
				var dist_a = tower.global_position.distance_to(a.global_position)
				var dist_b = tower.global_position.distance_to(b.global_position)
				return dist_a < dist_b
			)
		3:  # STRONG - sort by health (descending)
			enemies.sort_custom(func(a, b):
				return _get_enemy_health(a) > _get_enemy_health(b)
			)
		4:  # WEAK - sort by health (ascending)
			enemies.sort_custom(func(a, b):
				return _get_enemy_health(a) < _get_enemy_health(b)
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
		enemy_label.add_theme_font_size_override("font_size", 8)  # Was 9

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
# ENEMY LIST TOGGLE
# ============================================

func _on_enemy_list_toggle_pressed():
	"""Toggle enemy list visibility"""
	enemy_list_visible = not enemy_list_visible
	_update_enemy_list_visibility()

	# Note: Enemy list preference removed (was GameManager feature)
	print("[TowerInfoMenu] Enemy list toggled: %s" % ("visible" if enemy_list_visible else "hidden"))

func _update_enemy_list_visibility():
	"""Update visibility of enemy list elements"""
	if enemies_label:
		enemies_label.visible = enemy_list_visible
	if enemy_list_scroll:
		enemy_list_scroll.visible = enemy_list_visible

	# Update toggle button text
	if enemy_list_toggle:
		if enemy_list_visible:
			enemy_list_toggle.text = "Hide Enemy List"
		else:
			enemy_list_toggle.text = "Show Enemy List"

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

	# Hide targeting buttons for garrison towers (they don't target)
	if first_button:
		first_button.visible = not is_garrison
	if last_button:
		last_button.visible = not is_garrison
	if close_button:
		close_button.visible = not is_garrison
	if strong_button:
		strong_button.visible = not is_garrison
	if weak_button:
		weak_button.visible = not is_garrison

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
