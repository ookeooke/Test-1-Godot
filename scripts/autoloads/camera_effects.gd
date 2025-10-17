extends Node

# ============================================
# CAMERA EFFECTS HELPER
# ============================================
# Convenient functions for common camera effects in tower defense games
# Add as autoload or use as reference in your game manager

# ============================================
# CAMERA SHAKE PRESETS
# ============================================

static func small_shake(camera: Camera2D) -> void:
	"""Small shake (enemy death, arrow hit)"""
	if camera.has_method("add_shake"):
		camera.add_shake(5.0)

static func medium_shake(camera: Camera2D) -> void:
	"""Medium shake (tower placed, explosion)"""
	if camera.has_method("add_shake"):
		camera.add_shake(15.0)

static func large_shake(camera: Camera2D) -> void:
	"""Large shake (boss death, wave complete)"""
	if camera.has_method("add_shake"):
		camera.add_shake(30.0)

static func massive_shake(camera: Camera2D) -> void:
	"""Massive shake (game over, victory)"""
	if camera.has_method("add_shake"):
		camera.add_shake(50.0)

# ============================================
# COMMON TD CAMERA ACTIONS
# ============================================

static func focus_on_tower(camera: Camera2D, tower: Node2D, zoom: float = 1.2) -> void:
	"""Snap camera to newly placed tower"""
	if camera.has_method("snap_to_object"):
		camera.snap_to_object(tower, zoom)

static func focus_on_hero(camera: Camera2D, hero: Node2D, zoom: float = 1.0) -> void:
	"""Snap camera to selected hero"""
	if camera.has_method("snap_to_object"):
		camera.snap_to_object(hero, zoom)

static func focus_on_wave_start(camera: Camera2D, spawn_point: Vector2, zoom: float = 0.8) -> void:
	"""Show where enemies spawn at wave start"""
	if camera.has_method("snap_to_position"):
		camera.snap_to_position(spawn_point, zoom, 0.8)
		# Then zoom back out after delay
		await camera.get_tree().create_timer(1.5).timeout
		if camera.has_method("set_zoom_instant"):
			camera.target_zoom = Vector2(0.6, 0.6)

static func overview_zoom(camera: Camera2D) -> void:
	"""Zoom out to show entire battlefield"""
	if camera.has_method("reset_to_center"):
		camera.reset_to_center()

static func focus_on_base(camera: Camera2D, base_position: Vector2) -> void:
	"""Show base when enemy is about to reach it"""
	if camera.has_method("snap_to_position"):
		camera.snap_to_position(base_position, 1.0, 0.5)

# ============================================
# DRAMATIC EFFECTS
# ============================================

static func victory_sequence(camera: Camera2D) -> void:
	"""Camera sequence for victory screen"""
	# Zoom out
	if camera.has_method("reset_to_center"):
		camera.reset_to_center()

	# Add shake for celebration (disabled - adjust in inspector if needed)
	# large_shake(camera)

	# Smooth zoom to show entire level
	await camera.get_tree().create_timer(0.5).timeout
	camera.target_zoom = Vector2(0.4, 0.4)

static func defeat_sequence(camera: Camera2D, base_position: Vector2) -> void:
	"""Camera sequence for defeat"""
	# Focus on destroyed base
	if camera.has_method("snap_to_position"):
		camera.snap_to_position(base_position, 1.5, 0.3)

	# Massive shake (disabled - adjust in inspector if needed)
	await camera.get_tree().create_timer(0.3).timeout
	# massive_shake(camera)

static func boss_intro_sequence(camera: Camera2D, boss: Node2D) -> void:
	"""Dramatic boss introduction"""
	# Snap to boss
	if camera.has_method("snap_to_object"):
		camera.snap_to_object(boss, 1.5)

	# Shake (disabled - adjust in inspector if needed)
	await camera.get_tree().create_timer(0.5).timeout
	# large_shake(camera)

	# Zoom back out
	await camera.get_tree().create_timer(1.5).timeout
	camera.target_zoom = Vector2(0.7, 0.7)

# ============================================
# MOBILE-SPECIFIC HELPERS
# ============================================

static func is_mobile_platform() -> bool:
	"""Check if running on mobile"""
	return OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]

static func show_zoom_controls_hint(camera: Camera2D) -> bool:
	"""Should we show on-screen zoom buttons?"""
	# Show on mobile if pinch-to-zoom might be difficult
	return is_mobile_platform()

static func suggest_tutorial_for_camera(camera: Camera2D) -> String:
	"""Get platform-appropriate tutorial text"""
	if is_mobile_platform():
		return "Swipe to pan • Pinch to zoom • Double-tap to quick-zoom"
	else:
		return "Middle-click drag to pan • Mouse wheel to zoom • Arrow keys to move"

# ============================================
# UTILITY FUNCTIONS
# ============================================

static func get_camera() -> Camera2D:
	"""Get the main camera from the scene"""
	var vp = Engine.get_main_loop() as SceneTree
	if vp:
		var root = vp.current_scene
		if root:
			return root.get_viewport().get_camera_2d()
	return null

static func shake_on_damage(camera: Camera2D, damage_amount: float) -> void:
	"""Scale shake intensity based on damage"""
	var intensity = clamp(damage_amount * 0.5, 2.0, 40.0)
	if camera.has_method("add_shake"):
		camera.add_shake(intensity)

static func pulse_zoom(camera: Camera2D, amount: float = 0.05, duration: float = 0.2) -> void:
	"""Quick zoom pulse (for feedback)"""
	var original_zoom = camera.target_zoom.x
	camera.target_zoom = Vector2(original_zoom + amount, original_zoom + amount)

	await camera.get_tree().create_timer(duration).timeout
	camera.target_zoom = Vector2(original_zoom, original_zoom)
