extends CanvasLayer

# Pause Menu - In-game pause overlay
# Triggered by ESC key during gameplay
#
# ESC KEY PRIORITY:
# This menu runs in _input() stage when pause tree is active (paused=true).
# The pause tree process_mode allows this to run while other nodes are paused.
# When this menu closes, other ESC handlers (dual_panel, inventory) can run again.

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton

func _ready():
	# Connect signals
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	# Pause the game when this menu appears
	get_tree().paused = true

	# HIGH-PRIORITY FIX: Lock camera input during pause
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("lock_input"):
		camera.lock_input()

func _input(event):
	# Allow ESC to close pause menu
	# Consume event to prevent other handlers from also processing it
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func _on_resume_pressed():
	print("PauseMenu: Resume game")

	# HIGH-PRIORITY FIX: Unlock camera before resuming
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("unlock_input"):
		camera.unlock_input()

	get_tree().paused = false
	queue_free()

func _on_restart_pressed():
	print("PauseMenu: Restart level")

	# Save immediately before restarting
	SaveManager.save_current_profile()

	get_tree().paused = false
	queue_free()  # Remove pause menu before restarting

	# Use centralized restart logic
	NavigationManager.restart_current_level()

func _on_main_menu_pressed():
	print("PauseMenu: Return to world map")

	# Save immediately before exiting level
	SaveManager.save_current_profile()

	get_tree().paused = false
	queue_free()  # Remove pause menu before navigating away

	# Clean up level state before exiting (fixes bug: autoloads kept dirty state)
	if RestartManager:
		RestartManager.cleanup_for_exit()

	# Use centralized navigation
	NavigationManager.go_to_world_map()

func _exit_tree():
	# Ensure game is unpaused when menu is removed
	get_tree().paused = false

	# HIGH-PRIORITY FIX: Ensure camera is unlocked when menu is removed
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("unlock_input"):
		camera.unlock_input()
