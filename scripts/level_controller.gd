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
@export var level_config: LevelConfig

@onready var wave_manager = $WaveManager if has_node("WaveManager") else null
@onready var dual_panel_screen = $DualPanelScreen if has_node("DualPanelScreen") else null
@onready var camera = $Camera2D if has_node("Camera2D") else null


func _ready():
	# Set camera bounds from level config
	_setup_camera_bounds()
	# Connect WaveManager to DualPanelScreen for combat lockout
	if wave_manager and dual_panel_screen:
		wave_manager.combat_started.connect(_on_combat_started)
		wave_manager.combat_ended.connect(_on_combat_ended)
		print("[LevelController] Connected WaveManager to DualPanelScreen")


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
	if not camera:
		print("[LevelController] No camera found - skipping bounds setup")
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

	# If no content found, return default bounds
	if not found_content:
		print("[LevelController] WARNING: No content found for auto-calculation, using default bounds")
		return Rect2(-500, -500, 2000, 1500)

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
	if event.is_action_pressed("ui_text_completion_replace"):  # F9 key
		debug_print_bounds_info()
		get_viewport().set_input_as_handled()

	# ESC key to pause (highest priority - runs before other UI handlers)
	# Only trigger if game is not already paused to avoid conflicts with pause_menu
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		GameManager.show_pause_menu()
		get_viewport().set_input_as_handled()  # Consume to prevent other handlers
