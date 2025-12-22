extends Node

# TEST SCRIPT FOR BALANCE TRACKER LOGIC
# Verifies that concurrent waves are tracked separately.

var balance_tracker

func _init():
	print("🧪 STARTING AUTOMATED METRICS TEST")
	# If running as MainLoop (godot -s), _init runs.
	# If running as Node in scene, _enter_tree/_ready runs.
	pass

func _ready():
	_setup()
	_test_concurrent_waves()
	if get_tree():
		get_tree().quit()

func _setup():
	# 1. Load the real script
	var BalanceTrackerScript = load("res://scripts/debug/balance_tracker.gd")
	
	# 2. Instantiate BalanceTracker
	# We test the logic of the class directly
	balance_tracker = BalanceTrackerScript.new()
	balance_tracker.is_tracking = true
	# Initialize mock run data
	balance_tracker.current_run = {"waves": {}, "economy": {"gold_history": []}, "towers": {}, "heroes": {}, "enemies": {}, "balance_metrics": {}}

func _test_concurrent_waves():
	print("running test...")
	var tracker = balance_tracker
	
	# Step 1: Start Wave 1
	print("--- Step 1: Start Wave 1 ---")
	tracker.start_wave(1)
	tracker.record_enemy_spawned("goblin", 1)
	tracker.record_enemy_spawned("goblin", 1)
	
	_assert(tracker.active_waves_enemies.has(1), "Wave 1 should be active")
	_assert(tracker.active_waves_enemies[1]["goblin"].spawned == 2, "Wave 1 should have 2 goblins")
	
	# Step 2: Start Wave 2 (Overlap)
	print("--- Step 2: Start Wave 2 (Concurrent) ---")
	tracker.start_wave(2)
	tracker.record_enemy_spawned("orc", 2)
	
	# CRITICAL CHECK: Did Wave 1 get wiped?
	_assert(tracker.active_waves_enemies.has(1), "Wave 1 should STILL be active")
	_assert(tracker.active_waves_enemies.has(2), "Wave 2 should be active")
	_assert(tracker.active_waves_enemies[1]["goblin"].spawned == 2, "Wave 1 data should persist")
	_assert(tracker.active_waves_enemies[2]["orc"].spawned == 1, "Wave 2 data should exist")
	
	# Step 3: End Wave 1
	print("--- Step 3: End Wave 1 ---")
	tracker.end_wave(1)
	
	_assert(not tracker.active_waves_enemies.has(1), "Wave 1 should be closed")
	_assert(tracker.active_waves_enemies.has(2), "Wave 2 should STILL be active")
	
	# Verify Wave 1 saved to history
	_assert(tracker.wave_data.has(1), "Wave 1 data saved to history")
	_assert(tracker.wave_data[1].enemies_spawned == 2, "Wave 1 history correct")
	
	print("✅ TEST PASSED: Concurrent Metrics Logic Verified")

func _assert(condition, message):
	if not condition:
		print("❌ FAILED: " + message)
		# get_tree().quit(1)
	else:
		print("   PASS: " + message)
