extends Node

## ============================================
## NAVIGATION MANAGER - Centralized Scene Navigation
## ============================================
##
## Single source of truth for all scene transitions in the game.
## Handles navigation between menus, world map, and levels.
##
## Benefits:
##   - One place to update scene paths
##   - Easy to add loading screens, transitions, analytics
##   - Validates scene paths before loading
##   - Tracks navigation history
##
## Usage:
##   NavigationManager.go_to_world_map()
##   NavigationManager.restart_current_level()
##   NavigationManager.load_level(level_config)

# ============================================
# SCENE PATH CONSTANTS
# ============================================

const SCENE_MAIN_MENU = "res://scenes/ui/main_menu.tscn"
const SCENE_WORLD_MAP = "res://scenes/ui/world_map_select_node2d.tscn"
const SCENE_PROFILE_SELECT = "res://scenes/ui/profile_select.tscn"
const SCENE_PROFILE_CREATION = "res://scenes/ui/profile_creation.tscn"

# ============================================
# STATE TRACKING
# ============================================

## Current scene path (updated after each navigation)
var current_scene_path: String = ""

## Previous scene path (for analytics/debugging)
var previous_scene_path: String = ""

## Navigation history (for future "back" button functionality)
var navigation_history: Array[String] = []
const MAX_HISTORY_SIZE = 10

# ============================================
# SIGNALS
# ============================================

## Emitted when scene changes (useful for analytics)
signal scene_changed(from_scene: String, to_scene: String)

# ============================================
# PUBLIC NAVIGATION METHODS
# ============================================

func go_to_main_menu() -> void:
	"""Navigate to main menu"""
	print("[NavigationManager] Going to main menu")
	_navigate_to(SCENE_MAIN_MENU)

func go_to_world_map() -> void:
	"""Navigate to world map (Kingdom Rush style level select)"""
	print("[NavigationManager] Going to world map")
	_navigate_to(SCENE_WORLD_MAP)

func go_to_profile_select() -> void:
	"""Navigate to profile selection screen"""
	print("[NavigationManager] Going to profile select")
	_navigate_to(SCENE_PROFILE_SELECT)

func go_to_profile_creation() -> void:
	"""Navigate to profile creation screen"""
	print("[NavigationManager] Going to profile creation")
	_navigate_to(SCENE_PROFILE_CREATION)

func restart_current_level() -> void:
	"""Restart the current level (calls RestartManager for cleanup)"""
	print("[NavigationManager] Restarting current level")

	# Clean up autoloads before restart
	if RestartManager:
		RestartManager.cleanup_for_restart()

	# Unpause if paused
	get_tree().paused = false

	# Reload current scene
	get_tree().reload_current_scene()

func load_level(level_config: LevelConfig) -> void:
	"""Load a level from LevelConfig resource"""
	if not level_config:
		push_error("[NavigationManager] Cannot load level: level_config is null")
		return

	if not level_config.level_scene:
		# Note: This is expected if level_scene is not set in .tres file
		# WorldMapSelect will use fallback loading with direct scene path
		print("[NavigationManager] Note: Level %s has no scene assigned in config (using fallback)" % level_config.level_id)
		return

	print("[NavigationManager] Loading level: ", level_config.level_id)

	# Initialize level in LevelManager
	LevelManager.load_level_config(level_config)

	# Navigate to level scene
	var scene_path = level_config.level_scene.resource_path
	_navigate_to(scene_path)

func can_go_back() -> bool:
	"""Check if there's navigation history to go back to"""
	return navigation_history.size() > 0

func go_back() -> void:
	"""Go back to previous scene (if history exists)"""
	if not can_go_back():
		push_warning("[NavigationManager] No history to go back to")
		return

	var previous = navigation_history.pop_back()
	print("[NavigationManager] Going back to: ", previous)

	# Navigate without adding to history (we're going back)
	current_scene_path = previous
	get_tree().change_scene_to_file(previous)

# ============================================
# INTERNAL NAVIGATION LOGIC
# ============================================

func _navigate_to(scene_path: String) -> void:
	"""
	Internal navigation handler with expansion hooks.
	All scene changes go through this method.
	"""

	# Validate scene path
	if not _validate_scene_path(scene_path):
		push_error("[NavigationManager] Invalid scene path: ", scene_path)
		# Fallback to main menu on error
		if scene_path != SCENE_MAIN_MENU:
			_navigate_to(SCENE_MAIN_MENU)
		return

	# EXPANSION POINT 1: Loading Screen
	# Uncomment when ready to add loading screens:
	# await _show_loading_screen()
	# var loader = ResourceLoader.load_threaded_request(scene_path)
	# await _wait_for_load_complete(loader, scene_path)
	# await _hide_loading_screen()

	# EXPANSION POINT 2: Fade Transition
	# Uncomment when ready to add transitions:
	# await _fade_out()

	# EXPANSION POINT 3: Scene Caching
	# Uncomment when ready to implement scene caching:
	# if scene_path in _scene_cache:
	#     get_tree().change_scene_to_packed(_scene_cache[scene_path])
	#     await _fade_in()
	#     return

	# Update navigation state
	_update_navigation_state(scene_path)

	# Perform the actual scene change
	get_tree().change_scene_to_file(scene_path)

	# EXPANSION POINT 4: Fade In
	# Uncomment when ready to add transitions:
	# await get_tree().process_frame  # Wait for scene to load
	# await _fade_in()

	# EXPANSION POINT 5: Analytics
	# Uncomment when ready to add analytics:
	# _log_navigation_analytics(previous_scene_path, scene_path)

func _update_navigation_state(scene_path: String) -> void:
	"""Update internal navigation state"""
	# Add current scene to history (if not empty)
	if current_scene_path != "" and current_scene_path != scene_path:
		navigation_history.push_back(current_scene_path)

		# Limit history size
		if navigation_history.size() > MAX_HISTORY_SIZE:
			navigation_history.pop_front()

	# Update current/previous
	previous_scene_path = current_scene_path
	current_scene_path = scene_path

	# Emit signal
	scene_changed.emit(previous_scene_path, scene_path)

	print("[NavigationManager] %s -> %s" % [
		previous_scene_path.get_file() if previous_scene_path else "START",
		scene_path.get_file()
	])

func _validate_scene_path(scene_path: String) -> bool:
	"""Validate that scene path exists and is valid"""
	if scene_path.is_empty():
		push_error("[NavigationManager] Scene path is empty")
		return false

	if not scene_path.ends_with(".tscn"):
		push_error("[NavigationManager] Scene path must end with .tscn: ", scene_path)
		return false

	if not ResourceLoader.exists(scene_path):
		push_error("[NavigationManager] Scene file doesn't exist: ", scene_path)
		return false

	return true

# ============================================
# EXPANSION METHODS (for Phase 3+)
# ============================================
# These methods are placeholders for future features.
# Uncomment and implement when needed.

# var loading_screen_scene = preload("res://scenes/ui/loading_screen.tscn")
# var loading_screen_instance = null

# func _show_loading_screen() -> void:
# 	"""Show loading screen during scene transition"""
# 	loading_screen_instance = loading_screen_scene.instantiate()
# 	get_tree().root.add_child(loading_screen_instance)
# 	await get_tree().process_frame

# func _hide_loading_screen() -> void:
# 	"""Hide and remove loading screen"""
# 	if loading_screen_instance:
# 		loading_screen_instance.queue_free()
# 		loading_screen_instance = null
# 	await get_tree().process_frame

# func _wait_for_load_complete(loader: ResourceLoader, scene_path: String) -> void:
# 	"""Wait for threaded scene loading to complete"""
# 	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
# 		var progress = []
# 		ResourceLoader.load_threaded_get_status(scene_path, progress)
# 		if loading_screen_instance and loading_screen_instance.has_method("update_progress"):
# 			loading_screen_instance.update_progress(progress[0])
# 		await get_tree().process_frame

# var fade_scene = preload("res://scenes/ui/screen_fade.tscn")
# var fade_instance = null

# func _fade_out() -> void:
# 	"""Fade out current scene"""
# 	fade_instance = fade_scene.instantiate()
# 	get_tree().root.add_child(fade_instance)
# 	fade_instance.fade_out()
# 	await fade_instance.fade_complete

# func _fade_in() -> void:
# 	"""Fade in new scene"""
# 	if fade_instance:
# 		fade_instance.fade_in()
# 		await fade_instance.fade_complete
# 		fade_instance.queue_free()
# 		fade_instance = null

# func _log_navigation_analytics(from: String, to: String) -> void:
# 	"""Log navigation for analytics/telemetry"""
# 	# Example: Send to analytics service
# 	# AnalyticsService.log_event("scene_navigation", {
# 	#     "from": from.get_file(),
# 	#     "to": to.get_file(),
# 	#     "timestamp": Time.get_unix_time_from_system()
# 	# })
# 	pass
