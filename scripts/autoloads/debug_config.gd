extends Node

# ============================================
# DEBUG CONFIG - Toggle debug features
# ============================================
# F3: Toggle console targeting debug
# F4: Toggle visual debug lines/highlights
# ============================================

# Debug flags
var targeting_debug_enabled = false # Console output for targeting
var visual_debug_enabled = false # Visual lines and highlights
var explosion_debug_enabled = false # Debug explosion triggering
var show_waypoints = false # Show waypoint paths in game
var log_stat_calculations = false # Log stat recalculation details

func _ready():
	print("Debug Config loaded - F3: Targeting Debug | F4: Visual Debug")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F3:
			targeting_debug_enabled = !targeting_debug_enabled
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("🎯 TARGETING DEBUG: ", "ENABLED" if targeting_debug_enabled else "DISABLED")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			get_viewport().set_input_as_handled()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F4:
			visual_debug_enabled = !visual_debug_enabled
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("👁 VISUAL DEBUG: ", "ENABLED" if visual_debug_enabled else "DISABLED")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5:
			explosion_debug_enabled = !explosion_debug_enabled
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("💥 EXPLOSION DEBUG: ", "ENABLED" if explosion_debug_enabled else "DISABLED")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			get_viewport().set_input_as_handled()

func log_targeting(message: String):
	"""Log targeting-related debug messages"""
	if targeting_debug_enabled:
		print("🎯 ", message)
