extends Node

## UI Animator - Centralized "Juice" for UI elements
## Handles standardized animations for buttons, popups, and transitions.

# ============================================
# BUTTON ANIMATIONS
# ============================================

func animate_button_press(button: Control):
	"""Scale down button slightly on press"""
	if not button: return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)

func animate_button_release(button: Control):
	"""Restore button scale on release"""
	if not button: return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.3)

func animate_button_hover(button: Control):
	"""Slight scale up on hover"""
	if not button: return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.2)

func animate_button_reset(button: Control):
	"""Reset to normal"""
	if not button: return
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.2)

# ============================================
# WINDOW / PANEL ANIMATIONS
# ============================================

func animate_window_open(window: Control, background: Control = null):
	"""Standard pop-in animation for windows"""
	if not window: return
	
	# Setup initial state
	window.scale = Vector2(0.9, 0.9)
	window.modulate.a = 0.0
	window.pivot_offset = window.size / 2 # Pivot from center
	
	if background:
		background.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animate window
	tween.tween_property(window, "scale", Vector2.ONE, 0.3)
	tween.tween_property(window, "modulate:a", 1.0, 0.2)
	
	# Animate background
	if background:
		tween.tween_property(background, "modulate:a", 1.0, 0.2)
		
	return tween

func animate_window_close(window: Control, background: Control = null):
	"""Standard fade-out for windows"""
	if not window: return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tween.tween_property(window, "scale", Vector2(0.9, 0.9), 0.2)
	tween.tween_property(window, "modulate:a", 0.0, 0.2)
	
	if background:
		tween.tween_property(background, "modulate:a", 0.0, 0.2)
		
	return tween

# ============================================
# HELPER: AUTO-CONNECT
# ============================================

func apply_button_effects(button: BaseButton):
	"""Automatically connect press/hover signals to animations"""
	if not button: return
	
	# Ensure pivot is center for scaling
	button.pivot_offset = button.size / 2
	button.resized.connect(func(): button.pivot_offset = button.size / 2)
	
	if not button.button_down.is_connected(animate_button_press.bind(button)):
		button.button_down.connect(animate_button_press.bind(button))
		
	if not button.button_up.is_connected(animate_button_release.bind(button)):
		button.button_up.connect(animate_button_release.bind(button))
		
	# Optional: Hover effects (good for PC, subtle for mobile)
	if not button.mouse_entered.is_connected(animate_button_hover.bind(button)):
		button.mouse_entered.connect(animate_button_hover.bind(button))
		
	if not button.mouse_exited.is_connected(animate_button_reset.bind(button)):
		button.mouse_exited.connect(animate_button_reset.bind(button))
