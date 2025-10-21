extends Node
class_name GestureDetector

## GestureDetector - Utility for detecting tap, drag, and long-press gestures
## Handles both mouse and touch input uniformly
## Usage: Create as child node or singleton, connect to signals

signal tap(position: Vector2)
signal long_press(position: Vector2)
signal drag_started(position: Vector2)
signal drag_updated(position: Vector2, delta: Vector2)
signal drag_ended(position: Vector2)

## Configuration
@export var long_press_duration: float = 0.5  ## Seconds to trigger long-press
@export var drag_threshold: float = 10.0  ## Pixels moved before it's a drag
@export var enabled: bool = true

## Internal state
var _is_pressing: bool = false
var _press_start_position: Vector2 = Vector2.ZERO
var _press_start_time: float = 0.0
var _current_position: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _has_moved_beyond_threshold: bool = false
var _long_press_triggered: bool = false
var _long_press_timer: Timer

func _ready():
	# Create long-press timer
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.timeout.connect(_on_long_press_timer_timeout)
	add_child(_long_press_timer)

func process_event(event: InputEvent) -> bool:
	"""
	Process an input event for gestures.
	Returns true if the event was consumed by a gesture.
	"""
	if not enabled:
		return false

	# Handle press start (mouse down or touch down)
	if _is_press_start(event):
		_on_press_start(_get_event_position(event))
		return true

	# Handle press end (mouse up or touch up)
	if _is_press_end(event):
		_on_press_end(_get_event_position(event))
		return true

	# Handle motion (mouse motion or touch drag)
	if _is_motion(event) and _is_pressing:
		_on_motion(_get_event_position(event))
		return true

	return false

## ============================================
## EVENT DETECTION
## ============================================

func _is_press_start(event: InputEvent) -> bool:
	"""Check if event is a press start"""
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false

func _is_press_end(event: InputEvent) -> bool:
	"""Check if event is a press end"""
	if event is InputEventMouseButton:
		return not event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not event.pressed
	return false

func _is_motion(event: InputEvent) -> bool:
	"""Check if event is motion"""
	return event is InputEventMouseMotion or event is InputEventScreenDrag

func _get_event_position(event: InputEvent) -> Vector2:
	"""Get position from any input event"""
	if event is InputEventMouse:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	if event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO

## ============================================
## GESTURE HANDLERS
## ============================================

func _on_press_start(position: Vector2):
	"""Handle press start"""
	_is_pressing = true
	_press_start_position = position
	_current_position = position
	_press_start_time = Time.get_ticks_msec() / 1000.0
	_is_dragging = false
	_has_moved_beyond_threshold = false
	_long_press_triggered = false

	# Start long-press timer
	_long_press_timer.start(long_press_duration)

func _on_motion(position: Vector2):
	"""Handle motion during press"""
	var delta = position - _current_position
	_current_position = position

	# Check if moved beyond threshold
	var distance_from_start = _press_start_position.distance_to(position)

	if distance_from_start > drag_threshold and not _has_moved_beyond_threshold:
		_has_moved_beyond_threshold = true
		# Cancel long-press if we start dragging
		_long_press_timer.stop()

	# Start drag if threshold exceeded
	if _has_moved_beyond_threshold and not _is_dragging:
		_is_dragging = true
		drag_started.emit(_press_start_position)

	# Emit drag updates
	if _is_dragging:
		drag_updated.emit(position, delta)

func _on_press_end(position: Vector2):
	"""Handle press end"""
	_is_pressing = false
	_long_press_timer.stop()

	# Determine what type of gesture it was
	var distance_moved = _press_start_position.distance_to(position)
	var press_duration = (Time.get_ticks_msec() / 1000.0) - _press_start_time

	if _is_dragging:
		# It was a drag
		drag_ended.emit(position)
	elif _long_press_triggered:
		# Already handled by long-press
		pass
	elif distance_moved < drag_threshold:
		# It was a tap
		tap.emit(position)

	# Reset state
	_is_dragging = false
	_has_moved_beyond_threshold = false
	_long_press_triggered = false

func _on_long_press_timer_timeout():
	"""Called when long-press duration is reached"""
	if _is_pressing and not _has_moved_beyond_threshold:
		_long_press_triggered = true
		long_press.emit(_current_position)

## ============================================
## PUBLIC API
## ============================================

func is_dragging() -> bool:
	"""Check if currently dragging"""
	return _is_dragging

func is_pressing() -> bool:
	"""Check if currently pressing"""
	return _is_pressing

func get_current_position() -> Vector2:
	"""Get current pointer position"""
	return _current_position

func get_press_start_position() -> Vector2:
	"""Get position where press started"""
	return _press_start_position

func reset():
	"""Reset detector state"""
	_is_pressing = false
	_is_dragging = false
	_has_moved_beyond_threshold = false
	_long_press_triggered = false
	_long_press_timer.stop()
