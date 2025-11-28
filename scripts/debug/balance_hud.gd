extends CanvasLayer

## ============================================
## BALANCE HUD - Real-time balance metrics display
## ============================================
##
## Shows live DPS, economy, and performance metrics during gameplay
## Toggle with F3, Export with F4, Reset with F5
##
## Keybindings:
##   F3 - Toggle HUD visibility
##   F4 - Export current run data
##   F5 - Reset current run (soft reset)
##   Ctrl+F5 - Reset session
##   Shift+Ctrl+F5 - Full reset (with confirmation)
## ============================================

# ============================================
# NODES
# ============================================

@onready var panel: Panel = $Panel
@onready var content_container: VBoxContainer = $Panel/MarginContainer/ContentContainer

# Section labels
@onready var header_label: Label = $Panel/MarginContainer/ContentContainer/HeaderLabel
@onready var towers_label: RichTextLabel = $Panel/MarginContainer/ContentContainer/TowersLabel
@onready var heroes_label: RichTextLabel = $Panel/MarginContainer/ContentContainer/HeroesLabel
@onready var wave_label: RichTextLabel = $Panel/MarginContainer/ContentContainer/WaveLabel
@onready var economy_label: RichTextLabel = $Panel/MarginContainer/ContentContainer/EconomyLabel
@onready var performance_label: RichTextLabel = $Panel/MarginContainer/ContentContainer/PerformanceLabel
@onready var controls_label: Label = $Panel/MarginContainer/ContentContainer/ControlsLabel

# ============================================
# SETTINGS
# ============================================

## Update frequency (seconds)
const UPDATE_INTERVAL = 0.5

## HUD visibility (start hidden by default, toggle with button)
var is_hud_visible = false

## Update timer
var update_timer = 0.0

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	# Only enable in debug builds
	if not OS.is_debug_build():
		queue_free()
		return

	# Start hidden by default
	visible = false
	is_hud_visible = false

	# Set process mode to always (works during pause)
	process_mode = Node.PROCESS_MODE_ALWAYS

	print("✅ BalanceHUD initialized (Hidden by default - toggle with button or F3)")
	print("📊 Auto-export enabled - data will save automatically on level complete/defeat")
	print("⏩ Speed controls: Press 1/2/3/4 for 1x/2x/4x/8x speed")

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	# F3 - Toggle HUD
	if event.is_action_pressed("ui_text_completion_query"): # F3 in Godot
		toggle_visibility()
		get_viewport().set_input_as_handled()

	# F4 - Export data
	elif event is InputEventKey and event.keycode == KEY_F4 and event.pressed and not event.echo:
		export_data()
		get_viewport().set_input_as_handled()

	# F5 - Soft reset
	elif event is InputEventKey and event.keycode == KEY_F5 and event.pressed and not event.echo:
		if event.shift_pressed and event.ctrl_pressed:
			# Shift+Ctrl+F5 - Full reset (with confirmation)
			confirm_full_reset()
		elif event.ctrl_pressed:
			# Ctrl+F5 - Session reset
			reset_session()
		else:
			# F5 - Soft reset
			reset_run()
		get_viewport().set_input_as_handled()

# ============================================
# VISIBILITY CONTROL
# ============================================

func toggle_visibility():
	"""Toggle HUD visibility"""
	is_hud_visible = not is_hud_visible
	visible = is_hud_visible

	if is_hud_visible:
		print("[BalanceHUD] Shown")
		_update_display() # Immediate update
	else:
		print("[BalanceHUD] Hidden")

func show_hud():
	"""Show the HUD"""
	is_hud_visible = true
	visible = true
	_update_display()

func hide_hud():
	"""Hide the HUD"""
	is_hud_visible = false
	visible = false

# ============================================
# UPDATE LOOP
# ============================================

func _process(delta):
	if not is_hud_visible:
		return

	update_timer += delta

	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_display()

func _update_display():
	"""Update all HUD sections with current data"""
	if not BalanceTracker or not BalanceTracker.is_tracking:
		header_label.text = "BALANCE DEBUG - Not Tracking"
		towers_label.text = "[color=gray]Start a level to begin tracking[/color]"
		heroes_label.text = ""
		wave_label.text = ""
		economy_label.text = ""
		performance_label.text = ""
		return

	var run_data = BalanceTracker.get_current_run_data()

	# Update header with speed indicator
	var speed_text = ""
	if has_node("/root/GameSpeedController"):
		var speed_controller = get_node("/root/GameSpeedController")
		if speed_controller:
			speed_text = " [%s]" % speed_controller.get_current_speed_name()
	header_label.text = "BALANCE DEBUG - Wave %d%s" % [BalanceTracker.current_wave_number, speed_text]

	# Update each section
	_update_towers_section(run_data)
	_update_heroes_section(run_data)
	_update_wave_section(run_data)
	_update_economy_section(run_data)
	_update_performance_section(run_data)

# ============================================
# SECTION UPDATES
# ============================================

func _update_towers_section(run_data: Dictionary):
	"""Update tower performance display"""
	if not run_data.has("towers") or run_data.towers.is_empty():
		towers_label.text = "[color=gray]No towers placed[/color]"
		return

	var text = "[b]TOWERS (Live DPS)[/b]\n"

	for tower_id in run_data.towers:
		var tower = run_data.towers[tower_id]

		# Calculate rating (stars based on uptime)
		var stars = _get_performance_stars(tower.uptime_percent)

		# Color code based on performance
		var color = _get_performance_color(tower.uptime_percent)

		# Format: Type #ID: DPS (uptime%) ⭐⭐⭐
		text += "[color=%s]├─ %s: %.1f DPS (%.0f%% uptime) %s[/color]\n" % [
			color,
			tower.type,
			tower.actual_dps,
			tower.uptime_percent * 100,
			stars
		]

	towers_label.text = text

func _update_heroes_section(run_data: Dictionary):
	"""Update hero performance display"""
	if not run_data.has("heroes") or run_data.heroes.is_empty():
		heroes_label.text = ""
		return

	var text = "[b]HEROES[/b]\n"

	for hero_id in run_data.heroes:
		var hero = run_data.heroes[hero_id]

		var total_dps = hero.ranged_dps + hero.melee_dps

		text += "└─ %s: %.1f DPS | Blocks: %d | Kills: %d\n" % [
			hero.hero_id.capitalize(),
			total_dps,
			hero.enemies_blocked,
			hero.kills
		]

	heroes_label.text = text

func _update_wave_section(run_data: Dictionary):
	"""Update current wave stats"""
	var text = "[b]CURRENT WAVE[/b]\n"

	# Get enemy count from BalanceTracker
	var enemies_alive = 0
	var _total_spawned = 0

	if run_data.has("enemies"):
		for enemy_type in run_data.enemies:
			var enemy = run_data.enemies[enemy_type]
			_total_spawned += enemy.spawned
			enemies_alive += enemy.spawned - enemy.killed - enemy.leaked

	text += "├─ Enemies: %d remaining\n" % enemies_alive

	# Show current wave time if available
	if run_data.has("waves") and run_data.waves.has(BalanceTracker.current_wave_number):
		var wave = run_data.waves[BalanceTracker.current_wave_number]
		var current_time = Time.get_ticks_msec() / 1000.0
		var wave_duration = current_time - (BalanceTracker.run_start_time + wave.start_time)

		text += "└─ Time: %.1fs\n" % wave_duration

	wave_label.text = text

func _update_economy_section(run_data: Dictionary):
	"""Update economy stats"""
	if not run_data.has("economy"):
		economy_label.text = ""
		return

	var economy = run_data.economy
	var current_gold = GameStateManager.gold if GameStateManager else 0
	var total_available = economy.starting_gold + economy.total_earned

	var efficiency = float(economy.total_spent) / float(total_available) if total_available > 0 else 0.0

	# Color code efficiency
	var eff_color = "white"
	if efficiency > 0.95:
		eff_color = "red" # Overspent
	elif efficiency < 0.5:
		eff_color = "yellow" # Underspent

	var text = "[b]ECONOMY[/b]\n"
	text += "├─ Gold: %d | Spent: %d | Earned: %d\n" % [current_gold, economy.total_spent, economy.total_earned]
	text += "└─ Efficiency: [color=%s]%.0f%%[/color]\n" % [eff_color, efficiency * 100]

	economy_label.text = text

func _update_performance_section(run_data: Dictionary):
	"""Update overall performance metrics"""
	if not run_data.has("balance_metrics"):
		performance_label.text = ""
		return

	var metrics = run_data.balance_metrics
	var lives = GameStateManager.lives if GameStateManager else 0

	var text = "[b]PERFORMANCE[/b]\n"

	if metrics.has("total_dps"):
		text += "├─ Total DPS: %.1f\n" % metrics.total_dps

	text += "├─ Lives: %d\n" % lives

	if metrics.has("gold_efficiency"):
		text += "└─ Gold Efficiency: %.0f%%\n" % (metrics.gold_efficiency * 100)

	performance_label.text = text

# ============================================
# HELPER FUNCTIONS
# ============================================

func _get_performance_stars(uptime: float) -> String:
	"""Get star rating based on uptime percentage"""
	if uptime >= 0.7:
		return "⭐⭐⭐"
	elif uptime >= 0.5:
		return "⭐⭐"
	elif uptime >= 0.3:
		return "⭐"
	else:
		return "☆"

func _get_performance_color(uptime: float) -> String:
	"""Get color based on performance"""
	if uptime >= 0.7:
		return "green"
	elif uptime >= 0.4:
		return "yellow"
	else:
		return "red"

# ============================================
# DATA EXPORT & RESET
# ============================================

func export_data():
	"""Export current run data to JSON"""
	print("[BalanceHUD] Exporting data...")

	var filepath = BalanceExporter.export_current_run()

	if filepath != "":
		print("[BalanceHUD] ✅ Data exported to: %s" % filepath)
		_show_notification("Data exported successfully!")
	else:
		print("[BalanceHUD] ❌ Export failed")
		_show_notification("Export failed - no data to export")

func reset_run():
	"""Reset current run data (soft reset)"""
	print("[BalanceHUD] Soft reset - clearing current run")

	# Backup before reset
	BalanceExporter.backup_before_reset()

	# Reset tracker
	BalanceTracker.reset_run()

	_show_notification("Run data reset (backup created)")
	_update_display()

func reset_session():
	"""Reset session data"""
	print("[BalanceHUD] Session reset - clearing all runs")

	# Backup before reset
	BalanceExporter.backup_before_reset()

	# Reset tracker
	BalanceTracker.reset_session()

	_show_notification("Session data reset (backup created)")
	_update_display()

func confirm_full_reset():
	"""Show confirmation dialog for full reset"""
	print("[BalanceHUD] Full reset requested - showing confirmation")

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Full Reset will:\n• Clear all session data\n• Delete all exported files\n• This cannot be undone!\n\nContinue?"
	dialog.title = "Confirm Full Reset"

	# Connect signals
	dialog.confirmed.connect(_perform_full_reset)
	dialog.canceled.connect(func(): dialog.queue_free())

	# Add to scene and show
	add_child(dialog)
	dialog.popup_centered()

func _perform_full_reset():
	"""Perform full reset after confirmation"""
	print("[BalanceHUD] Performing full reset...")

	# Backup before reset
	BalanceExporter.backup_before_reset()

	# Reset everything
	BalanceTracker.reset_all()
	BalanceExporter.delete_all_exports()

	_show_notification("Full reset complete!")
	_update_display()

func _show_notification(message: String):
	"""Show temporary notification"""
	# Simple print for now - could add visual notification later
	print("[BalanceHUD] %s" % message)

# ============================================
# SCENE TREE
# ============================================

# Note: This script expects the following scene structure:
# CanvasLayer (this script)
#   └─ Panel
#       └─ MarginContainer
#           └─ ContentContainer (VBoxContainer)
#               ├─ HeaderLabel
#               ├─ TowersLabel (RichTextLabel)
#               ├─ HeroesLabel (RichTextLabel)
#               ├─ WaveLabel (RichTextLabel)
#               ├─ EconomyLabel (RichTextLabel)
#               ├─ PerformanceLabel (RichTextLabel)
#               └─ ControlsLabel
