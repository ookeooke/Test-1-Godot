extends Control
class_name HeroPostGameReport

## ============================================
## HERO POST-GAME REPORT
## ============================================
## Displays detailed breakdown of hero performance after a run.
## Metric: Total Damage, DPM, Boss Damage %, Survival Rate.

const HERO_ROW_HEIGHT = 60
const PADDING = 20

# UI Containers
var main_container: VBoxContainer
var title_label: Label
var stats_container: VBoxContainer

func _ready():
	# Self-build UI if not instantiated from scene
	if get_child_count() == 0:
		_build_ui()

func _build_ui():
	# Background Panel
	var bg = Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Make it dark transparent
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	# Main Vertical Layout
	main_container = VBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_CENTER)
	main_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_container.custom_minimum_size = Vector2(800, 500)
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)

	# Title
	title_label = Label.new()
	title_label.text = "Hero Performance Report"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	main_container.add_child(title_label)
	
	# Scroll Container for stats
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(scroll)
	
	# Stats VBox
	stats_container = VBoxContainer.new()
	stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(stats_container)
	
	# Close Button
	var close_btn = Button.new()
	close_btn.text = "Close Report"
	close_btn.custom_minimum_size = Vector2(200, 50)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(queue_free)
	main_container.add_child(close_btn)

func populate_report(run_data: Dictionary):
	# Ensure UI is initialized before trying to add children
	if not stats_container:
		_build_ui()

	if not run_data.has("heroes") or run_data.heroes.is_empty():
		var lbl = Label.new()
		lbl.text = "No heroes participated in this run."
		stats_container.add_child(lbl)
		return

	# Calculate Run Duration in Minutes for DPM
	var duration_min = run_data.get("duration", 60.0) / 60.0
	if duration_min < 0.1: duration_min = 0.1
	
	# Get Boss Data for % calculation
	# Get Boss Data for % calculation
	# Actually, BalanceTracker boss_fights stores 'total_damage_taken'
	# We can use that as a proxy for Boss HP if the boss died
	
	# Calculate MVP Counts
	var mvp_counts = {}
	if run_data.has("waves"):
		for w in run_data.waves.values():
			var mvp_id = w.get("mvp_hero", "")
			if mvp_id != "":
				mvp_counts[mvp_id] = mvp_counts.get(mvp_id, 0) + 1
	
	for hero_id in run_data.heroes:
		var hero = run_data.heroes[hero_id]
		var mvp_count = mvp_counts.get(hero_id, 0)
		_create_hero_row(hero, duration_min, run_data, mvp_count)

func _create_hero_row(hero_data: Dictionary, duration_min: float, run_data: Dictionary, mvp_count: int):
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, HERO_ROW_HEIGHT)
	
	# 1. Hero Name/ID + MVP Badge
	var name_vbox = VBoxContainer.new()
	name_vbox.custom_minimum_size = Vector2(150, 0)
	name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var name_lbl = Label.new()
	name_lbl.text = str(hero_data.get("hero_id", "Unknown")).capitalize()
	name_lbl.add_theme_color_override("font_color", Color.GOLD)
	name_vbox.add_child(name_lbl)
	
	if mvp_count > 0:
		var mvp_lbl = Label.new()
		mvp_lbl.text = "🏆 MVP x%d" % mvp_count
		mvp_lbl.add_theme_font_size_override("font_size", 12)
		mvp_lbl.add_theme_color_override("font_color", Color.YELLOW)
		name_vbox.add_child(mvp_lbl)
		
	row.add_child(name_vbox)
	
	# 2. Total Damage & DPM
	var dmg_lbl = Label.new()
	var dpm = hero_data.get("total_damage", 0) / duration_min
	dmg_lbl.text = "⚔️ %.0f (%.0f DPM)" % [hero_data.get("total_damage", 0), dpm]
	dmg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dmg_lbl)
	
	# 3. Kills
	var kill_lbl = Label.new()
	kill_lbl.text = "💀 %d Kills" % hero_data.get("kills", 0)
	kill_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kill_lbl)
	
	# 4. Boss Damage calculation (if available)
	var boss_dmg = 0.0
	if run_data.has("boss_fights"):
		for boss in run_data.boss_fights.values():
			var dmg_by_hero = boss.get("damage_by_hero", {})
			# Check against string vs int instance id issues by iterating
			# Start simple: use our 'instance_id'
			var my_inst_id = hero_data.get("instance_id", -1)
			if dmg_by_hero.has(my_inst_id):
				boss_dmg += dmg_by_hero[my_inst_id]
			# Also try Str key
			elif dmg_by_hero.has(str(my_inst_id)):
				boss_dmg += dmg_by_hero[str(my_inst_id)]
				
	var boss_lbl = Label.new()
	if boss_dmg > 0:
		boss_lbl.text = "👹 Boss Dmg: %.0f" % boss_dmg
		boss_lbl.add_theme_color_override("font_color", Color.ORANGE_RED)
	else:
		boss_lbl.text = "-"
	boss_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(boss_lbl)
	
	# 5. Deaths / Survival
	var deaths = hero_data.get("deaths", 0)
	var death_lbl = Label.new()
	if deaths == 0:
		death_lbl.text = "🛡️ Flawless"
		death_lbl.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		death_lbl.text = "🪦 Deaths: %d" % deaths
		death_lbl.add_theme_color_override("font_color", Color.INDIAN_RED)
	death_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(death_lbl)

	stats_container.add_child(row)
	# Divider
	var div = HSeparator.new()
	stats_container.add_child(div)
