extends Node

## ============================================
## RESTART MANAGER - Centralized Level Restart Cleanup
## ============================================
##
## Single source of truth for cleanup logic before restarting a level.
## Previously this logic was duplicated in 3 places:
##   - PauseMenu._cleanup_before_restart()
##   - VictoryScreen._cleanup_before_restart()
##   - DefeatScreen._cleanup_before_restart()
##
## Now all screens call RestartManager.cleanup_for_restart()
##
## Benefits:
##   - No code duplication (easier to maintain)
##   - Adding new cleanup is done in ONE place
##   - Consistent cleanup across all restart scenarios

# ============================================
# CLEANUP METHOD
# ============================================

func cleanup_for_restart() -> void:
	"""
	Clean up persistent autoload state before restarting a level.
	Called before any level restart (from pause menu, victory, or defeat).
	"""
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[RestartManager] 🧹 Starting cleanup for restart...")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# Reset BalanceTracker (gameplay statistics)
	if BalanceTracker:
		var was_tracking = BalanceTracker.is_tracking
		BalanceTracker.reset_run()
		print("[RestartManager] ✓ BalanceTracker reset (was tracking: %s)" % was_tracking)
	else:
		push_warning("[RestartManager] ⚠️ BalanceTracker not found")

	# Clear pending loot (items waiting to be distributed)
	if LootManager:
		var loot_count = LootManager.get_pending_loot_count() if LootManager.has_method("get_pending_loot_count") else "unknown"
		LootManager.clear_pending_loot()
		print("[RestartManager] ✓ LootManager cleared (had %s pending items)" % loot_count)
	else:
		push_warning("[RestartManager] ⚠️ LootManager not found")

	# Reset GameStateManager (will be re-initialized by LevelManager)
	if GameStateManager:
		var old_gold = GameStateManager.gold
		var old_lives = GameStateManager.lives
		GameStateManager.reset_for_new_run()
		print("[RestartManager] ✓ GameStateManager reset (was: %dg, %d lives)" % [old_gold, old_lives])
	else:
		push_warning("[RestartManager] ⚠️ GameStateManager not found")

	# Reset game speed to normal (fixes bug: speed persisted across levels)
	if GameSpeedController:
		var old_speed = GameSpeedController.get_current_speed_name()
		GameSpeedController.reset_speed()
		print("[RestartManager] ✓ Game speed reset (%s → 1x)" % old_speed)
	else:
		push_warning("[RestartManager] ⚠️ GameSpeedController not found")

	# Verify pause state
	var pause_state = "paused" if get_tree().paused else "running"
	print("[RestartManager] ℹ️ Game state: %s" % pause_state)

	# EXPANSION POINT: Add new cleanup here as needed
	# When you add new managers that need cleanup on restart, add them here.
	# Examples:
	#   - QuestManager.reset_level_quests()
	#   - AchievementManager.reset_level_progress()
	#   - PowerUpManager.clear_active_powerups()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("[RestartManager] ✅ Cleanup complete!")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func cleanup_for_exit() -> void:
	"""
	Clean up when exiting to menu (more thorough than restart).
	Use this when returning to main menu or world map.
	"""
	print("[RestartManager] Starting cleanup for exit...")

	# Do all the restart cleanup
	cleanup_for_restart()

	# EXPANSION POINT: Additional cleanup for exiting to menu
	# Add cleanup that should only happen when leaving level completely
	# Examples:
	#   - HeroManager.deselect_all_heroes()
	#   - TutorialManager.reset_tutorials()
	#   - ChallengeManager.clear_active_challenges()

	print("[RestartManager] Exit cleanup complete ✓")

# ============================================
# UTILITY METHODS
# ============================================

func is_cleanup_safe() -> bool:
	"""
	Check if all required managers exist for cleanup.
	Returns true if cleanup can proceed safely.
	"""
	var required_managers = [
		"BalanceTracker",
		"LootManager",
		"GameStateManager"
	]

	for manager_name in required_managers:
		if not has_node("/root/" + manager_name):
			push_warning("[RestartManager] Required manager missing: ", manager_name)
			return false

	return true
