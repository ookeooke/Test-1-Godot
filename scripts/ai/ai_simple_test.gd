extends Node

## ============================================
## SIMPLE AI POSITION TESTER
## ============================================
## Plays the same level 3 times with hero at different positions:
## 1. Frontline (aggressive - 70% along path)
## 2. Midline (balanced - 40% along path)
## 3. Backline (defensive - 20% along path, near exit)
##
## Compares which position survives with most lives.
## ============================================

# Test configuration
var test_positions = ["frontline", "midline", "backline"]
var current_test_index = 0
var test_results = []

# AI reference
var ai_controller: AIController = null

# Current test position multiplier
var hero_position_multiplier = 0.7  # Frontline by default

func _ready():
	print("\n🔬 === SIMPLE POSITION TESTER ===")
	print("   Will test %d hero positions" % test_positions.size())

	# Wait for scene
	await get_tree().process_frame
	await get_tree().process_frame

	# Create AI
	ai_controller = AIController.new()
	ai_controller.set_strategy("Archer Rush")
	add_child(ai_controller)

	# Start first test
	_start_test(0)

func _start_test(index: int):
	"""Start a test with specific hero position"""
	current_test_index = index

	if index >= test_positions.size():
		_finish_all_tests()
		return

	var position_name = test_positions[index]

	# Set hero position multiplier
	match position_name:
		"frontline":
			hero_position_multiplier = 0.7  # 70% along path
		"midline":
			hero_position_multiplier = 0.4  # 40% along path
		"backline":
			hero_position_multiplier = 0.2  # 20% along path (near exit)

	print("\n🎯 === TEST %d/%d: HERO AT %s ===" % [index + 1, test_positions.size(), position_name.to_upper()])
	print("   Position: %.0f%% along enemy path" % (hero_position_multiplier * 100))

	# Override AI's hero positioning function
	_override_hero_positioning()

	# Initialize AI
	await ai_controller.initialize()

	print("✅ Test started!\n")

func _override_hero_positioning():
	"""Override the AI's hero positioning to use our test position"""
	# We'll modify the _get_optimal_hero_position function dynamically
	var original_func = ai_controller._get_optimal_hero_position

	ai_controller._get_optimal_hero_position = func(hero: Node2D) -> Vector2:
		if not ai_controller.enemy_path or not ai_controller.enemy_path.curve:
			return hero.home_position if "home_position" in hero else hero.global_position

		# Use our test position multiplier
		var path_length = ai_controller.enemy_path.curve.get_baked_length()
		var sample_point = ai_controller.enemy_path.curve.sample_baked(path_length * hero_position_multiplier)
		var world_pos = sample_point + ai_controller.enemy_path.global_position

		# Offset to side
		var offset = Vector2(80, 0)
		return world_pos + offset

func _record_result(outcome: String, lives: int, gold: int):
	"""Record result of current test"""
	var result = {
		"position": test_positions[current_test_index],
		"position_percent": hero_position_multiplier * 100,
		"outcome": outcome,
		"lives_remaining": lives,
		"gold_remaining": gold
	}

	test_results.append(result)

	print("\n📊 TEST %d RESULT:" % (current_test_index + 1))
	print("   Position: %s (%.0f%% along path)" % [result.position.to_upper(), result.position_percent])
	print("   Outcome: %s" % outcome.to_upper())
	print("   Lives: %d | Gold: %d" % [lives, gold])

func _finish_all_tests():
	"""All tests complete - show comparison"""
	print("\n" + "=".repeat(60))
	print("🏆 ALL TESTS COMPLETE - RESULTS COMPARISON")
	print("=".repeat(60))

	# Find best result
	var best_result = test_results[0]
	for result in test_results:
		if result.outcome == "victory":
			if best_result.outcome != "victory" or result.lives_remaining > best_result.lives_remaining:
				best_result = result

	# Print all results
	for i in range(test_results.size()):
		var result = test_results[i]
		var marker = " 🏆" if result == best_result else ""
		print("\n%d. %s (%.0f%% along path)%s" % [i+1, result.position.to_upper(), result.position_percent, marker])
		print("   Outcome: %s" % result.outcome.to_upper())
		print("   Lives: %d | Gold: %d" % [result.lives_remaining, result.gold_remaining])

	print("\n✨ BEST STRATEGY:")
	print("   Hero Position: %s (%.0f%% along path)" % [best_result.position.to_upper(), best_result.position_percent])
	print("   Result: %s with %d lives" % [best_result.outcome.to_upper(), best_result.lives_remaining])

	# Save to file
	_save_results()

	print("\n" + "=".repeat(60))

func _save_results():
	"""Save results to JSON"""
	if not BalanceExporter:
		return

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var level_id = LevelManager.current_level.level_id if LevelManager.current_level else "unknown"
	var filename = "position_test_%s_%s.json" % [level_id, timestamp]
	var filepath = BalanceExporter.export_dir.path_join(filename)

	var data = {
		"level_id": level_id,
		"timestamp": timestamp,
		"test_type": "hero_position_comparison",
		"results": test_results
	}

	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("\n💾 Results saved to: %s" % filepath)
