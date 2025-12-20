extends Node

## InputActionsSetup - Configures InputMap actions for unified mouse/touch handling
## This autoload script sets up all game input actions at runtime
## Following Godot 4.x best practices for cross-platform input

func _ready():
	setup_input_actions()
	print("[InputActionsSetup] ✅ Input actions configured for cross-platform support")

func setup_input_actions():
	"""Configure all InputMap actions for the game"""

	# ============================================
	# PRIMARY INTERACTION ACTIONS
	# ============================================

	# Primary click/tap - Used for selecting, clicking UI, interacting
	# FORCE INTERACT ACTION: Ensure it exists and has Left Click
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	
	# Verify Left Mouse Button presence
	var has_left_click = false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_left_click = true
			break
	
	if not has_left_click:
		var mouse_left = InputEventMouseButton.new()
		mouse_left.button_index = MOUSE_BUTTON_LEFT
		mouse_left.pressed = true # Important for action matching
		InputMap.action_add_event("interact", mouse_left)
		print("✅ [InputSetup] Added missing MOUSE_BUTTON_LEFT to 'interact'")

	# Verify Touch presence
	var has_touch = false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventScreenTouch:
			has_touch = true
			break
	
	if not has_touch:
		var touch = InputEventScreenTouch.new()
		InputMap.action_add_event("interact", touch)


	# Secondary click - Used for deselecting, canceling, context menu
	if not InputMap.has_action("deselect"):
		InputMap.add_action("deselect")
		# Mouse right-click
		var mouse_right = InputEventMouseButton.new()
		mouse_right.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("deselect", mouse_right)
		# ESC key
		var esc = InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		InputMap.action_add_event("deselect", esc)

	# Camera drag action REMOVED for web compatibility
	# Right/middle mouse conflicts with browser context menu
	# Desktop users can use WASD/arrow keys for camera pan
	# Mobile users use single-finger drag (handled in camera controller)
	# if not InputMap.has_action("camera_drag_start"):
	# 	InputMap.add_action("camera_drag_start")
	# 	var mouse_middle = InputEventMouseButton.new()
	# 	mouse_middle.button_index = MOUSE_BUTTON_MIDDLE
	# 	InputMap.action_add_event("camera_drag_start", mouse_middle)
	# 	var mouse_right = InputEventMouseButton.new()
	# 	mouse_right.button_index = MOUSE_BUTTON_RIGHT
	# 	InputMap.action_add_event("camera_drag_start", mouse_right)

	# ============================================
	# KEYBOARD CAMERA CONTROLS
	# ============================================

	if not InputMap.has_action("camera_up"):
		InputMap.add_action("camera_up")
		_add_key_events("camera_up", [KEY_W, KEY_UP])

	if not InputMap.has_action("camera_down"):
		InputMap.add_action("camera_down")
		_add_key_events("camera_down", [KEY_S, KEY_DOWN])

	if not InputMap.has_action("camera_left"):
		InputMap.add_action("camera_left")
		_add_key_events("camera_left", [KEY_A, KEY_LEFT])

	if not InputMap.has_action("camera_right"):
		InputMap.add_action("camera_right")
		_add_key_events("camera_right", [KEY_D, KEY_RIGHT])

	if not InputMap.has_action("camera_zoom_in"):
		InputMap.add_action("camera_zoom_in")
		var zoom_in = InputEventMouseButton.new()
		zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
		InputMap.action_add_event("camera_zoom_in", zoom_in)

	if not InputMap.has_action("camera_zoom_out"):
		InputMap.add_action("camera_zoom_out")
		var zoom_out = InputEventMouseButton.new()
		zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
		InputMap.action_add_event("camera_zoom_out", zoom_out)

	# ============================================
	# GAME SPEED CONTROLS
	# ============================================

	if not InputMap.has_action("speed_pause"):
		InputMap.add_action("speed_pause")
		_add_key_events("speed_pause", [KEY_1])

	if not InputMap.has_action("speed_normal"):
		InputMap.add_action("speed_normal")
		_add_key_events("speed_normal", [KEY_2])

	if not InputMap.has_action("speed_fast"):
		InputMap.add_action("speed_fast")
		_add_key_events("speed_fast", [KEY_3])

	if not InputMap.has_action("speed_ultra"):
		InputMap.add_action("speed_ultra")
		_add_key_events("speed_ultra", [KEY_4])

	# ============================================
	# ABILITY HOTKEYS (1-9)
	# ============================================

	for i in range(1, 10):
		var action_name = "ability_" + str(i)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key = InputEventKey.new()
			key.keycode = KEY_0 + i # KEY_1 through KEY_9
			InputMap.action_add_event(action_name, key)

	# ============================================
	# DEBUG HOTKEYS
	# ============================================

	if not InputMap.has_action("debug_balance_hud"):
		InputMap.add_action("debug_balance_hud")
		_add_key_events("debug_balance_hud", [KEY_F3])

	if not InputMap.has_action("debug_export_balance"):
		InputMap.add_action("debug_export_balance")
		_add_key_events("debug_export_balance", [KEY_F4])

	if not InputMap.has_action("debug_reset_balance"):
		InputMap.add_action("debug_reset_balance")
		_add_key_events("debug_reset_balance", [KEY_F5])

	# ============================================
	# UI ACTIONS (already exist in Godot)
	# ============================================
	# ui_cancel - ESC key (already configured by Godot)
	# ui_accept - Enter/Space (already configured by Godot)

func _add_key_events(action_name: String, keycodes: Array):
	"""Helper to add multiple key events to an action"""
	for keycode in keycodes:
		var event = InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)
