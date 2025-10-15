extends Node2D

# Level Controller - Handles level-specific input like pause
# Attach this to the root node of each level

func _input(event):
	# ESC key to pause
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		GameManager.show_pause_menu()
		get_viewport().set_input_as_handled()
