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
	print("[RestartManager] Starting cleanup for restart...")

	# Reset BalanceTracker (gameplay statistics)
	if BalanceTracker:
		BalanceTracker.reset_run()
		print("[RestartManager] ✓ BalanceTracker reset")
	else:
		push_warning("[RestartManager] BalanceTracker not found")

	# Clear pending loot (items waiting to be distributed)
	if LootManager:
		LootManager.clear_pending_loot()
		print("[RestartManager] ✓ LootManager cleared")
	else:
		push_warning("[RestartManager] LootManager not found")

	# Reset GameStateManager (will be re-initialized by LevelManager)
	if GameStateManager:
		GameStateManager.reset_for_new_run()
		print("[RestartManager] ✓ GameStateManager reset")
	else:
		push_warning("[RestartManager] GameStateManager not found")

	# EXPANSION POINT: Add new cleanup here as needed
	# When you add new managers that need cleanup on restart, add them here.
	# Examples:
	#   - QuestManager.reset_level_quests()
	#   - AchievementManager.reset_level_progress()
	#   - PowerUpManager.clear_active_powerups()

	print("[RestartManager] Cleanup complete ✓")

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
