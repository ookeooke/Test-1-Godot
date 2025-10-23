extends Node

## ============================================
## AI EXPERIMENT TEST - Runs multiple experiments
## ============================================
## This script runs the AI multiple times on the same level
## with different strategies to find the best tactics.
## ============================================

# Settings
@export var experiments_to_run: int = 5
@export var show_debug_info: bool = true

# References
var ai_controller: AIController = null
var experiment_manager: AIExperimentManager = null

func _ready():
	print("\n" + "=".repeat(50))
	print("🔬 AI EXPERIMENT MODE STARTING")
	print("=".repeat(50))

	# Wait for level to be fully loaded
	await get_tree().process_frame
	await get_tree().process_frame

	# Create experiment manager
	experiment_manager = AIExperimentManager.new()
	experiment_manager.experiments_per_level = experiments_to_run
	add_child(experiment_manager)

	# Connect signals
	experiment_manager.experiment_complete.connect(_on_experiment_complete)
	experiment_manager.all_experiments_complete.connect(_on_all_experiments_complete)

	# Create AI controller
	ai_controller = AIController.new()
	ai_controller.set_strategy("Archer Rush")
	add_child(ai_controller)

	# Start first experiment
	var level_id = _get_current_level_id()
	experiment_manager.start_experiments_for_level(level_id)

	# Initialize AI for first run
	await ai_controller.initialize()

	print("\n✅ EXPERIMENT MODE IS NOW RUNNING!")
	print("   Total experiments: %d" % experiments_to_run)
	print("=".repeat(50) + "\n")

func _get_current_level_id() -> String:
	"""Get current level ID"""
	if LevelManager.current_level:
		return LevelManager.current_level.level_id
	return "unknown"

func _on_experiment_complete(result: Dictionary):
	"""Called when one experiment finishes"""
	if show_debug_info:
		print("\n📊 Experiment %d complete!" % result.experiment_number)

func _on_all_experiments_complete(all_results: Array):
	"""Called when all experiments finish"""
	print("\n" + "=".repeat(50))
	print("🎉 ALL EXPERIMENTS COMPLETE!")
	print("=".repeat(50))
	print("\nReturning to world map...")

	# Wait a moment
	await get_tree().create_timer(3.0).timeout

	# Return to world map
	get_tree().change_scene_to_file("res://scenes/ui/world_map_select_node2d.tscn")
