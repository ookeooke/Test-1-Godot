extends Node2D

# Level Controller - Handles level-specific input like pause
# Attach this to the root node of each level

@onready var wave_manager = $WaveManager if has_node("WaveManager") else null
@onready var dual_panel_screen = $DualPanelScreen if has_node("DualPanelScreen") else null


func _ready():
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


func _input(event):
	# ESC key to pause
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		GameManager.show_pause_menu()
		get_viewport().set_input_as_handled()
