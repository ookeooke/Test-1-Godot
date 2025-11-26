class_name InputDelegate
extends RefCounted

## InputDelegate - Unified Input Handling for Item Slots and Sprites
##
## Centralizes the logic for:
## 1. PC: Click (Select/Use), Right-Click (Context Menu), Ctrl+Click (Quick Equip)
## 2. Mobile: Tap (Select/Use), Long-Press (Context Menu)
##
## Usage:
## Call handle_gui_input() from _on_gui_input() or signal handlers.

const LONG_PRESS_DURATION: float = 0.5 # 500ms

# State tracking (must be passed in or stored in the node)
# Since this is a static helper, we rely on the caller to track state if needed,
# OR we can use metadata on the node.

static func handle_gui_input(node: Control, event: InputEvent, item: ItemInstance) -> void:
	if not item:
		return

	# 1. MOUSE INPUT (PC)
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Shift+Click / Ctrl+Click logic
				if event.shift_pressed:
					# Shift+Click -> Context Menu (Web/Accessibility)
					_trigger_context_menu(node, item)
				else:
					# Normal Click -> Select/Use/Equip
					_trigger_primary_action(node, item)
				node.accept_event()
				
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Right Click -> Context Menu
				_trigger_context_menu(node, item)
				node.accept_event()

	# 2. TOUCH INPUT (Mobile)
	elif event is InputEventScreenTouch:
		if event.pressed:
			# Touch Start
			node.set_meta("touch_start_time", Time.get_ticks_msec() / 1000.0)
			node.set_meta("is_touch_held", true)
		else:
			# Touch End
			if node.has_meta("is_touch_held") and node.get_meta("is_touch_held"):
				var start_time = node.get_meta("touch_start_time", 0.0)
				var hold_duration = (Time.get_ticks_msec() / 1000.0) - start_time

				if hold_duration >= LONG_PRESS_DURATION:
					# Long Press -> Context Menu
					_trigger_context_menu(node, item)
				else:
					# Short Tap -> Primary Action
					_trigger_primary_action(node, item)

				node.set_meta("is_touch_held", false)
				node.accept_event()

static func _trigger_primary_action(node: Control, item: ItemInstance):
	# Emit signal 'item_clicked' if it exists
	if node.has_signal("item_clicked"):
		node.emit_signal("item_clicked", item, node)
	elif node.has_signal("item_tapped"): # ItemSprite uses 'item_tapped'
		node.emit_signal("item_tapped", node)

static func _trigger_context_menu(node: Control, item: ItemInstance):
	# Emit signal 'item_right_clicked' if it exists
	if node.has_signal("item_right_clicked"):
		node.emit_signal("item_right_clicked", item, node)
	elif node.has_signal("item_long_pressed"): # ItemSprite uses 'item_long_pressed'
		node.emit_signal("item_long_pressed", node)
