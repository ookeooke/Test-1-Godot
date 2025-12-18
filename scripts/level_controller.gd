@tool
extends Node2D

# Level Controller - Handles level-specific input like pause
# Attach this to the root node of each level
#
# ESC KEY PRIORITY (Stage 1 - _input()):
# 1. level_controller (this) - Opens pause menu (only if not already paused)
# 2. pause_menu - Closes pause menu (runs in pause tree)
# 3. dual_panel_screen - Closes panel (only if visible and not paused)
# 4. inventory_panel - Closes inventory (only if visible and not paused)

## Optional: LevelConfig resource for this level (defines camera bounds, waves, etc.)
## Cyclic dependency is resolved by using string paths in LevelConfig
@export var level_config: LevelConfig

@onready var wave_manager = $WaveManager if has_node("WaveManager") else null
@onready var dual_panel_screen = $DualPanelScreen if has_node("DualPanelScreen") else null
@onready var camera = $Camera2D if has_node("Camera2D") else null


func _ready():
	# Editor visual debugging
	if Engine.is_editor_hint():
		queue_redraw()
		return

	# Load config dynamically if not set by LevelManager (e.g. F6 testing)
	if LevelManager and LevelManager.current_level:
		level_config = LevelManager.current_level
	else:
		# Auto-detect config based on scene filename (e.g. "level_02.tscn" -> "level_02_config.tres")
		var scene_filename = scene_file_path.get_file().get_basename()
		var auto_config_path = "res://data/level_configs/%s_config.tres" % scene_filename
		
		if ResourceLoader.exists(auto_config_path):
			level_config = load(auto_config_path)
			print("[LevelController] 🔌 Auto-loaded matching config: %s" % auto_config_path)
		else:
			# Fallback: Load default config if specific one doesn't exist
			level_config = load("res://data/level_configs/level_01_config.tres")
			print("[LevelController] ⚠️ No specific config found for '%s', using default level_01_config" % scene_filename)
	
	# Ensure GameState is initialized (fixes 0 gold on restart)
	if not Engine.is_editor_hint() and GameStateManager and GameStateManager.current_level_config != level_config:
		print("[LevelController] Initializing GameState (Restart or Direct Load detected)")
		GameStateManager.initialize_level(level_config)
		
	# Set camera bounds from level config
	_setup_camera_bounds()
	
	# Connect WaveManager to DualPanelScreen for combat lockout
	if not Engine.is_editor_hint() and wave_manager and dual_panel_screen:
		wave_manager.combat_started.connect(_on_combat_started)
		wave_manager.combat_ended.connect(_on_combat_ended)
		print("[LevelController] Connected WaveManager to DualPanelScreen")

	# DEBUG: Print visual hierarchy
	# _print_visual_debug()

func _process(_delta):
	# Redraw in editor to reflect config changes immediately
	if Engine.is_editor_hint():
		if level_config:
			queue_redraw()

func _draw():
	if Engine.is_editor_hint():
		if level_config:
			# Draw camera bounds
			var rect = level_config.camera_bounds
			if rect.size != Vector2.ZERO:
				# Draw yellow border
				draw_rect(rect, Color.YELLOW, false, 4.0)
				# Draw transparent fill
				draw_rect(rect, Color(1, 1, 0, 0.1), true)
				
				# Draw "Camera Bounds" label if simple font available (optional, skipping for simplicity)
			else:
				# Warn about empty bounds
				draw_rect(Rect2(-100, -100, 200, 200), Color.RED, false, 2.0)
		else:
			# Warn about missing config
			draw_rect(Rect2(-100, -100, 200, 200), Color.RED, false, 2.0)
			
func _print_visual_debug():
	print("\n=== VISUAL DEBUG: SCENE HIERARCHY & DRAW ORDER ===")
	print("Level: ", name)
	var children = get_children()
	for child in children:
		if child is Node2D or child is Control:
			var z = child.z_index if "z_index" in child else 0
			print("  - Node: %-20s | Type: %-15s | Z-Index: %d | Visible: %s" % [child.name, child.get_class(), z, child.visible])
			
			# Check for background specifically
			if child.name == "LevelBackground":
				var sprite = child.get_node("Sprite2D")
				var tex = sprite.texture if sprite else null
				print("    -> BACKGROUND FOUND! Texture Resource: ", tex.resource_path if tex else "NULL")
					
	print("==================================================\n")


func _on_combat_started():
	"""Called when a wave starts"""
	if dual_panel_screen:
		dual_panel_screen.set_wave_active(true)


func _on_combat_ended():
	"""Called when a wave ends"""
	if dual_panel_screen:
		dual_panel_screen.set_wave_active(false)


func _setup_camera_bounds():
	"""Setup camera bounds from level config or auto-calculate"""
	# Reduced verbosity - only print essential info to avoid output overflow
	if level_config:
		print("[LevelController] Camera bounds:", level_config.camera_bounds)

	if not camera:
		push_error("[LevelController] ❌ No camera found - skipping bounds setup")
		push_error("[LevelController] → Camera should be a child node named 'Camera2D'")
		return

	# VALIDATION: Check for conflicting configurations
	_validate_bounds_configuration()

	# If no level_config, use camera's default bounds
	if not level_config:
		print("[LevelController] ⚠️ WARNING: No level_config assigned!")
		print("[LevelController] → Using camera's default fallback bounds (NOT recommended for multi-level games)")
		print("[LevelController] → Solution: Create a LevelConfig resource and assign it to this level_controller")
		return

	# Check if we should auto-calculate bounds
	if level_config.auto_calculate_bounds or level_config.camera_bounds.size == Vector2.ZERO:
		var bounds = _calculate_bounds_from_content()
		camera.set_level_bounds(bounds)
		print("[LevelController] ✅ Auto-calculated camera bounds:", bounds, " (padding:", level_config.bounds_padding, ")")
	else:
		# Use manually defined bounds from level_config
		camera.set_level_bounds(level_config.camera_bounds)
		print("[LevelController] ✅ Using manual camera bounds from level_config:", level_config.camera_bounds)


func _validate_bounds_configuration():
	"""Check for conflicting or overlapping border configuration methods"""
	var issues = []
	var warnings = []

	# Check 1: LevelConfig exists but both auto AND manual are set
	if level_config:
		if level_config.auto_calculate_bounds and level_config.camera_bounds.size != Vector2.ZERO:
			warnings.append("Both auto_calculate_bounds=true AND manual camera_bounds are set")
			warnings.append("→ Auto-calculate will be used (manual bounds will be ignored)")

	# Check 2: Camera has non-default bounds AND LevelConfig exists
	var camera_default = Rect2(-200, 200, 2000, 800)
	if level_config and camera.level_rect != camera_default:
		warnings.append("Camera has custom level_rect AND LevelConfig is assigned")
		warnings.append("→ LevelConfig will override camera's level_rect (camera bounds will be ignored)")

	# Check 3: No LevelConfig but camera has default bounds
	if not level_config and camera.level_rect == camera_default:
		warnings.append("Using camera's default fallback bounds (no LevelConfig assigned)")
		warnings.append("→ This works but is NOT recommended for multi-level games")

	# Check 4: Manual bounds mode with zero-sized rect (INVALID STATE)
	if level_config and not level_config.auto_calculate_bounds:
		if level_config.camera_bounds.size == Vector2.ZERO:
			issues.append("❌ Manual bounds mode enabled but camera_bounds is empty (0,0,0,0)")
			issues.append("→ Either enable auto_calculate_bounds OR set valid camera_bounds")
			issues.append("→ Current state will result in broken camera limits!")

	# Print validation results
	if issues.size() > 0:
		print("[LevelController] ❌ CONFIGURATION ERRORS:")
		for issue in issues:
			print("[LevelController]    " + issue)

	if warnings.size() > 0:
		print("[LevelController] ⚠️  CONFIGURATION WARNINGS:")
		for warning in warnings:
			print("[LevelController]    " + warning)

	if issues.size() == 0 and warnings.size() == 0:
		print("[LevelController] ✅ Bounds configuration validated - no conflicts detected")


func _calculate_bounds_from_content() -> Rect2:
	"""Auto-calculate camera bounds from tower spots, paths, and spawners"""
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var found_content = false

	# Find all relevant game objects
	var search_groups = ["TowerSpots", "Path", "Spawners", "Goals"]

	for group_name in search_groups:
		if has_node(group_name):
			var group = get_node(group_name)
			for child in group.get_children():
				if child is Node2D:
					var pos = child.global_position
					min_pos.x = min(min_pos.x, pos.x)
					min_pos.y = min(min_pos.y, pos.y)
					max_pos.x = max(max_pos.x, pos.x)
					max_pos.y = max(max_pos.y, pos.y)
					found_content = true

	# If no content found, use safe fallback bounds
	if not found_content:
		var fallback = Rect2(-500, -500, 2000, 1500) # Safe default fallback
		push_warning("[LevelController] ⚠️ WARNING: No content found for auto-calculation")
		push_warning("[LevelController] → Using fallback bounds: " + str(fallback))
		push_warning("[LevelController] → Tip: Check that TowerSpots, Path, Spawners, or Goals nodes exist")
		push_warning("[LevelController] → Consider setting manual camera_bounds in LevelConfig instead")
		return fallback

	# Add padding
	var padding = level_config.bounds_padding if level_config else 200.0
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)

	# Create rect from min/max
	return Rect2(min_pos, max_pos - min_pos)


func debug_print_bounds_info():
	"""Debug method: Print detailed information about current bounds configuration
	Call this from console: get_tree().current_scene.debug_print_bounds_info()
	"""
	print("\n========================================")
	print("CAMERA BOUNDS DEBUG INFO")
	print("========================================")

	# Configuration status
	print("\n[1] CONFIGURATION:")
	if level_config:
		print("  ✅ LevelConfig assigned:", level_config.resource_path if level_config.resource_path else "unsaved resource")
		print("     - auto_calculate_bounds:", level_config.auto_calculate_bounds)
		print("     - camera_bounds:", level_config.camera_bounds)
		print("     - bounds_padding:", level_config.bounds_padding)
	else:
		print("  ❌ No LevelConfig assigned (using camera fallback)")

	# Camera status
	print("\n[2] CAMERA STATE:")
	if camera:
		print("  ✅ Camera found")
		print("     - level_rect:", camera.level_rect)
		print("     - limit_left:", camera.limit_left)
		print("     - limit_right:", camera.limit_right)
		print("     - limit_top:", camera.limit_top)
		print("     - limit_bottom:", camera.limit_bottom)
		print("     - current position:", camera.position)
	else:
		print("  ❌ No camera found")

	# Active method
	print("\n[3] ACTIVE METHOD:")
	if not level_config:
		print("  📌 Method 3 (Old Way) - Camera fallback bounds")
	elif level_config.auto_calculate_bounds or level_config.camera_bounds.size == Vector2.ZERO:
		print("  📌 Method 1 (Auto-Calculate) - Bounds from content + padding")
	else:
		print("  📌 Method 2 (Manual) - Bounds from level_config.camera_bounds")

	# Validation
	print("\n[4] VALIDATION:")
	_validate_bounds_configuration()

	print("\n========================================\n")


func _input(event):
	# DEBUG: Press F9 to print bounds info
	if event.is_action_pressed("ui_text_completion_replace"): # F9 key
		debug_print_bounds_info()
		get_viewport().set_input_as_handled()

	# DEBUG: Press F7 to spawn test items
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7:
		_spawn_debug_items()
		get_viewport().set_input_as_handled()

	# Toggle Inventory / Hero Management
	if event.is_action_pressed("toggle_inventory"):
		# Don't toggle if pause menu is open
		if get_tree().root.has_node("PauseMenu"):
			return

		if dual_panel_screen:
			if dual_panel_screen.visible:
				dual_panel_screen.hide_screen()
			else:
				dual_panel_screen.show_screen()
			get_viewport().set_input_as_handled()

	# ESC key to pause (highest priority - runs before other UI handlers)
	# Check if pause menu already exists to avoid conflicts
	if event.is_action_pressed("ui_cancel"):
		var root = get_tree().root
		if not root.has_node("PauseMenu"):
			_show_pause_menu()
			get_viewport().set_input_as_handled() # Consume to prevent other handlers

func _spawn_debug_items():
	"""DEBUG: Spawn test items into inventory (F7 key)"""
	print("\n[DEBUG] F7 pressed - Spawning test items...")

	var items_to_spawn = [
		"basic_bow",
		"leather_vest",
		"leather_cap",
		"power_ring",
	]

	var spawned = 0
	for item_id in items_to_spawn:
		if InventoryManager.add_item(item_id, 1):
			spawned += 1
		else:
			print("[DEBUG] Failed to add: ", item_id)

	print("[DEBUG] ✅ Spawned %d/%d items. Press I to open inventory." % [spawned, items_to_spawn.size()])


func _show_pause_menu():
	"""Show the pause menu"""
	var pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
	var root = get_tree().root

	# Check if pause menu already exists
	if root.has_node("PauseMenu"):
		print("[LevelController] Pause menu already open")
		return

	# Instantiate pause menu
	var pause_menu = pause_menu_scene.instantiate()
	root.add_child(pause_menu)

	print("[LevelController] Pause menu shown")
