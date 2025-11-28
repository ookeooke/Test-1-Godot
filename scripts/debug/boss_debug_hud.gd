extends CanvasLayer

## Boss Debug HUD - Real-time boss fight monitoring
##
## Displays:
## - Boss health and position
## - Towers detecting/targeting the boss
## - Boss damage sources
## - Detection issues
##
## Toggle with F6 key

# ============================================
# UI ELEMENTS
# ============================================

var hud_container: VBoxContainer
var boss_info_label: Label
var health_bar: ProgressBar
var tower_detection_label: Label
var damage_sources_label: Label
var debug_status_label: Label

# ============================================
# STATE
# ============================================

var is_hud_visible: bool = false
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1 # Update every 0.1 seconds

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Set layer to render on top
	layer = 100

	_create_ui()
	_hide_hud()

	print("[BossDebugHUD] Initialized - Press F6 to toggle")

func _create_ui():
	"""Create the HUD UI elements"""
	# Main container
	hud_container = VBoxContainer.new()
	hud_container.position = Vector2(10, 10)
	add_child(hud_container)

	# Background panel
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	hud_container.add_child(panel)

	# Content container (on top of panel)
	var content = VBoxContainer.new()
	content.position = Vector2(10, 10)
	content.custom_minimum_size = Vector2(380, 280)
	panel.add_child(content)

	# Title
	var title = Label.new()
	title.text = "🔴 BOSS DEBUG MONITOR"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.RED)
	content.add_child(title)

	# Separator
	var separator1 = HSeparator.new()
	content.add_child(separator1)

	# Boss info
	boss_info_label = Label.new()
	boss_info_label.text = "No boss active"
	boss_info_label.add_theme_font_size_override("font_size", 14)
	content.add_child(boss_info_label)

	# Health bar
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(360, 30)
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = true
	content.add_child(health_bar)

	# Separator
	var separator2 = HSeparator.new()
	content.add_child(separator2)

	# Tower detection info
	tower_detection_label = Label.new()
	tower_detection_label.text = "Tower Detection: N/A"
	tower_detection_label.add_theme_font_size_override("font_size", 12)
	tower_detection_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tower_detection_label.custom_minimum_size = Vector2(360, 60)
	content.add_child(tower_detection_label)

	# Damage sources
	damage_sources_label = Label.new()
	damage_sources_label.text = "Damage Sources: N/A"
	damage_sources_label.add_theme_font_size_override("font_size", 12)
	damage_sources_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	damage_sources_label.custom_minimum_size = Vector2(360, 60)
	content.add_child(damage_sources_label)

	# Debug status
	debug_status_label = Label.new()
	debug_status_label.text = "Debug Status: All systems operational"
	debug_status_label.add_theme_font_size_override("font_size", 11)
	debug_status_label.add_theme_color_override("font_color", Color.GREEN)
	debug_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	debug_status_label.custom_minimum_size = Vector2(360, 40)
	content.add_child(debug_status_label)

# ============================================
# UPDATE LOOP
# ============================================

func _process(delta):
	# Update HUD if visible
	if is_hud_visible:
		update_timer += delta
		if update_timer >= UPDATE_INTERVAL:
			update_timer = 0.0
			_update_hud()

func _update_hud():
	"""Update all HUD elements with current boss data"""
	if not EnemyManager:
		return

	var boss = EnemyManager.get_current_boss()

	if not boss or not is_instance_valid(boss):
		_show_no_boss()
		return

	# Update boss info
	_update_boss_info(boss)

	# Update tower detection
	_update_tower_detection(boss)

	# Update damage sources
	_update_damage_sources(boss)

	# Update debug status
	_update_debug_status(boss)

func _show_no_boss():
	"""Display 'no boss' state"""
	boss_info_label.text = "No boss currently active"
	health_bar.value = 0
	tower_detection_label.text = "Tower Detection: N/A"
	damage_sources_label.text = "Damage Sources: N/A"
	debug_status_label.text = "Waiting for boss to appear..."
	debug_status_label.add_theme_color_override("font_color", Color.GRAY)

func _update_boss_info(boss):
	"""Update boss information display"""
	var boss_name = boss.get_enemy_name() if boss.has_method("get_enemy_name") else "Unknown Boss"
	var health = boss.current_health if "current_health" in boss else 0
	var max_health = boss.max_health if "max_health" in boss else 1
	var health_percent = (health / max_health) * 100.0
	var pos = boss.global_position

	boss_info_label.text = "%s\nHealth: %.0f / %.0f (%.1f%%)\nPosition: (%.0f, %.0f)" % [
		boss_name, health, max_health, health_percent, pos.x, pos.y
	]

	# Update health bar
	health_bar.value = health_percent

	# Color code health bar
	if health_percent > 75:
		health_bar.modulate = Color.GREEN
	elif health_percent > 50:
		health_bar.modulate = Color.YELLOW
	elif health_percent > 25:
		health_bar.modulate = Color.ORANGE
	else:
		health_bar.modulate = Color.RED

func _update_tower_detection(boss):
	"""Update tower detection status"""
	var towers_detecting = []
	var towers_targeting = []

	# Find all towers in the scene
	var towers = get_tree().get_nodes_in_group("tower")

	for tower in towers:
		if not is_instance_valid(tower):
			continue

		# Check if tower has boss in detection range
		if "enemies_in_range" in tower:
			if tower.enemies_in_range.has(boss):
				var tower_type = tower.get("type") if "type" in tower else "Tower"
				towers_detecting.append(tower_type)

				# Check if tower is actively targeting the boss
				if "current_target" in tower and tower.current_target == boss:
					towers_targeting.append(tower_type)

	var detection_text = "Towers Detecting (%d): %s\nTowers Targeting (%d): %s" % [
		towers_detecting.size(),
		", ".join(towers_detecting) if towers_detecting.size() > 0 else "None",
		towers_targeting.size(),
		", ".join(towers_targeting) if towers_targeting.size() > 0 else "None"
	]

	tower_detection_label.text = detection_text

	# Color code based on detection
	if towers_targeting.size() > 0:
		tower_detection_label.add_theme_color_override("font_color", Color.GREEN)
	elif towers_detecting.size() > 0:
		tower_detection_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		tower_detection_label.add_theme_color_override("font_color", Color.RED)

func _update_damage_sources(_boss):
	"""Update damage sources from BalanceTracker"""
	if not BalanceTracker:
		damage_sources_label.text = "Damage Sources: N/A"
		return

	var boss_type = "troll_boss" # Could make this dynamic
	if not BalanceTracker.boss_fights.has(boss_type):
		damage_sources_label.text = "Damage Sources: No tracking data"
		return

	var boss_data = BalanceTracker.boss_fights[boss_type]
	var total_damage = boss_data.total_damage_taken
	var hits = boss_data.hits_taken
	var tower_count = boss_data.damage_by_tower.size()
	var hero_count = boss_data.damage_by_hero.size()

	# Calculate fight duration
	var current_time = Time.get_ticks_msec() / 1000.0
	var fight_time = current_time - (BalanceTracker.run_start_time + boss_data.appear_time)
	var dps = total_damage / fight_time if fight_time > 0 else 0

	damage_sources_label.text = "Total Damage: %.0f (%.1f DPS)\nHits: %d | Towers: %d | Heroes: %d\nFight Duration: %.1fs" % [
		total_damage, dps, hits, tower_count, hero_count, fight_time
	]

func _update_debug_status(boss):
	"""Update debug status warnings"""
	var warnings = []

	# Check if boss has current_health property
	if not "current_health" in boss:
		warnings.append("⚠ Boss missing 'current_health' property!")

	# Check if boss is in enemy group
	if not boss.is_in_group("enemy"):
		warnings.append("⚠ Boss not in 'enemy' group!")

	# Check boss parent type
	var parent = boss.get_parent()
	if parent:
		var parent_type = parent.get_class()
		if parent_type != "PathFollow2D" and not "waypoint" in boss:
			warnings.append("⚠ Boss parent is %s (not PathFollow2D, may affect targeting)" % parent_type)

	# Check if any towers exist
	var tower_count = get_tree().get_nodes_in_group("tower").size()
	if tower_count == 0:
		warnings.append("⚠ No towers placed!")

	# Display warnings or all clear
	if warnings.size() > 0:
		debug_status_label.text = "\n".join(warnings)
		debug_status_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		debug_status_label.text = "✅ All systems operational\n✅ Boss properly configured\n✅ Detection systems active"
		debug_status_label.add_theme_color_override("font_color", Color.GREEN)

# ============================================
# VISIBILITY CONTROL
# ============================================

func _toggle_hud():
	"""Toggle HUD visibility"""
	if is_hud_visible:
		_hide_hud()
	else:
		_show_hud()

func _show_hud():
	"""Show the HUD"""
	is_hud_visible = true
	hud_container.visible = true
	print("[BossDebugHUD] Shown - Press F6 to hide")

func _hide_hud():
	"""Hide the HUD"""
	is_hud_visible = false
	hud_container.visible = false

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	"""Handle F6 key press"""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			_toggle_hud()
			get_viewport().set_input_as_handled()
