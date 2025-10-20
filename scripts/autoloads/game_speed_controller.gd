extends Node

## ============================================
## GAME SPEED CONTROLLER - Control game time scale
## ============================================
##
## Allows speeding up the game for faster testing
## Press keys to change speed:
##   1 - Normal speed (1x)
##   2 - 2x speed
##   3 - 4x speed
##   4 - 8x speed
## ============================================

# Available speed multipliers
const SPEEDS = [1.0, 2.0, 4.0, 8.0]
const SPEED_NAMES = ["1x", "2x", "4x", "8x"]

# Current speed index
var current_speed_index = 0

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("✅ GameSpeedController initialized")
	print("   Press 1/2/3/4 to change game speed (1x/2x/4x/8x)")
	set_speed(0)  # Start at normal speed

# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				set_speed(0)  # 1x
			KEY_2:
				set_speed(1)  # 2x
			KEY_3:
				set_speed(2)  # 4x
			KEY_4:
				set_speed(3)  # 8x

# ============================================
# SPEED CONTROL
# ============================================

func set_speed(speed_index: int):
	"""Set game speed by index (0-3)"""
	if speed_index < 0 or speed_index >= SPEEDS.size():
		return

	current_speed_index = speed_index
	var speed = SPEEDS[speed_index]

	Engine.time_scale = speed

	print("⏩ Game speed: %s (%.1fx)" % [SPEED_NAMES[speed_index], speed])

func get_current_speed() -> float:
	"""Get current speed multiplier"""
	return SPEEDS[current_speed_index]

func get_current_speed_name() -> String:
	"""Get current speed name"""
	return SPEED_NAMES[current_speed_index]

# ============================================
# HELPER FUNCTIONS
# ============================================

func cycle_speed():
	"""Cycle to next speed"""
	set_speed((current_speed_index + 1) % SPEEDS.size())

func reset_speed():
	"""Reset to normal speed"""
	set_speed(0)
