extends Node

## ============================================
## SIMPLE AI TEST - Quick way to test AI
## ============================================
##
## This script makes the AI play the current level automatically.
##
## Usage:
##   1. Attach this script to your level scene (as a child node)
##   2. Run the level
##   3. AI will play automatically!
## ============================================

# AI instance
var ai: AIController = null

# Strategy to use
@export var strategy: String = "Archer Rush"  # Options: "Archer Rush", "Soldier Wall", "Greedy Economy"

# Enable visual debugging
@export var show_debug_info: bool = true

func _ready():
	# Check if learning mode is active
	var learning_node = get_tree().current_scene.get_node_or_null("AILearning")
	if learning_node and learning_node.total_games_to_play > 1:
		print("🧠 Learning mode detected - skipping simple AI test")
		queue_free()
		return

	print("\n==================================================")
	print("🤖 SIMPLE AI TEST STARTING")
	print("==================================================")

	# Wait for level to be fully loaded
	await get_tree().process_frame
	await get_tree().process_frame

	# SETUP: Ensure LevelManager knows about current level and campaign
	# This is needed for auto-progression to work
	_ensure_level_manager_setup()

	# Create AI controller
	ai = AIController.new()
	ai.name = "AIController"
	add_child(ai)

	# Set strategy
	ai.set_strategy(strategy)

	# Initialize AI (this will scan the map and start playing)
	await ai.initialize()

	print("\n✅ AI IS NOW PLAYING!")
	print("   Strategy: %s" % strategy)
	print("   Watch the console to see AI decisions")
	print("==================================================\n")

	# Note: Game end detection will happen through BalanceTracker
	# No need to connect signals here

func _ensure_level_manager_setup():
	"""Ensure LevelManager has current_level and current_campaign set for auto-progression"""
	# If already set up (came from world map), we're good
	if LevelManager.current_level and LevelManager.current_campaign:
		print("📋 [AI] Level already loaded via LevelManager")
		return

	# Otherwise, we're testing from editor - set it up manually
	print("⚠️ [AI] Testing from editor - setting up LevelManager manually")

	# Guess which level we're in based on scene name
	var scene_name = get_tree().current_scene.name
	var level_id = "forest_01"  # Default

	if "level_01" in scene_name.to_lower() or "forest" in scene_name.to_lower():
		level_id = "forest_01"
	elif "level_02" in scene_name.to_lower():
		level_id = "forest_02"

	# Find the campaign
	var campaign = LevelManager.get_campaign("forest")
	if not campaign:
		print("❌ [AI] Could not find forest campaign!")
		return

	# Find the level config
	var level = campaign.get_level_by_id(level_id)
	if not level:
		print("❌ [AI] Could not find level: %s" % level_id)
		return

	# Set them in LevelManager
	LevelManager.current_level = level
	LevelManager.current_campaign = campaign

	print("✅ [AI] Set current level: %s (%s)" % [level.level_name, level_id])
	print("✅ [AI] Set current campaign: %s" % campaign.campaign_name)

func _on_game_over():
	"""Called when game ends (victory or defeat)"""
	print("\n==================================================")
	print("🏁 GAME ENDED")
	print("==================================================")

	# Get AI decision history
	var decisions = ai.get_decisions()
	print("   AI made %d decisions" % decisions.size())

	# Get BalanceTracker data
	if BalanceTracker:
		var run_data = BalanceTracker.get_current_run_data()
		print("   Result: %s" % run_data.result)
		print("   Stars: %d" % run_data.stars)
		print("   Lives remaining: %d" % run_data.lives_remaining)
		print("   Duration: %.1fs" % run_data.duration)

	print("==================================================\n")

func _process(delta):
	"""Show debug info on screen"""
	if not show_debug_info or not ai:
		return

	# This will show AI status in the console
	# We'll add a visual overlay in the next method
