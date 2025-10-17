extends Node

## Level Manager - Autoload Singleton
## Manages level loading, progression, and campaign data

# ============================================
# SIGNALS
# ============================================

signal level_loaded(level_config: LevelConfig)
signal level_completed(level_id: String, stars: int)
signal campaign_completed(campaign_id: String)

# ============================================
# CAMPAIGN DATA
# ============================================

## All available campaigns (assign in project settings or load from file)
@export var campaigns: Array[CampaignData] = []

## Preload all campaigns automatically
const FOREST_CAMPAIGN = preload("res://data/campaigns/forest_campaign.tres")
const DESERT_CAMPAIGN = preload("res://data/campaigns/desert_campaign.tres")
const MOUNTAINS_CAMPAIGN = preload("res://data/campaigns/mountains_campaign.tres")

# ============================================
# CURRENT STATE
# ============================================

## Currently loaded level config
var current_level: LevelConfig = null

## Currently active campaign
var current_campaign: CampaignData = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("LevelManager initialized")

	# Auto-load all campaigns if campaigns array is empty
	if campaigns.is_empty():
		print("LevelManager: Auto-loading campaigns")
		campaigns.append(FOREST_CAMPAIGN)
		campaigns.append(DESERT_CAMPAIGN)
		campaigns.append(MOUNTAINS_CAMPAIGN)

	print("LevelManager: ", campaigns.size(), " campaign(s) loaded")
	for campaign in campaigns:
		print("  - ", campaign.campaign_name, " (", campaign.levels.size(), " levels)")

# ============================================
# CAMPAIGN MANAGEMENT
# ============================================

## Get campaign by ID
func get_campaign(campaign_id: String) -> CampaignData:
	for campaign in campaigns:
		if campaign.campaign_id == campaign_id:
			return campaign
	push_error("LevelManager: Campaign '", campaign_id, "' not found!")
	return null

## Get all unlocked campaigns based on player's star count
func get_unlocked_campaigns(player_stars: int) -> Array[CampaignData]:
	var unlocked: Array[CampaignData] = []
	for campaign in campaigns:
		if campaign.is_unlocked(player_stars):
			unlocked.append(campaign)
	return unlocked

# ============================================
# LEVEL MANAGEMENT
# ============================================

## Load a level by campaign and level ID
func load_level(campaign_id: String, level_id: String) -> void:
	var campaign = get_campaign(campaign_id)
	if not campaign:
		return

	var level = campaign.get_level_by_id(level_id)
	if not level:
		push_error("LevelManager: Level '", level_id, "' not found in campaign '", campaign_id, "'!")
		return

	load_level_config(level, campaign)

## Load a level from a LevelConfig resource directly
func load_level_config(level_config: LevelConfig, campaign: CampaignData = null) -> void:
	if not level_config:
		push_error("LevelManager: Invalid level config!")
		return

	# Safety check: make sure level has a scene
	if not level_config.level_scene:
		push_error("LevelManager: Level '", level_config.level_id, "' has no scene assigned!")
		return

	current_level = level_config
	current_campaign = campaign

	print("LevelManager: Loading level '", level_config.level_id, "' (", level_config.level_name, ")")

	# Set initial game state
	GameManager.gold = level_config.starting_gold
	GameManager.lives = level_config.starting_lives

	# Emit signal before loading
	level_loaded.emit(level_config)

	# Load the level scene
	get_tree().change_scene_to_packed(level_config.level_scene)

## Get level by ID from any campaign
func get_level_by_id(level_id: String) -> LevelConfig:
	for campaign in campaigns:
		var level = campaign.get_level_by_id(level_id)
		if level:
			return level
	return null

## Get next level in the current campaign
func get_next_level() -> LevelConfig:
	if not current_level or not current_campaign:
		return null

	return current_campaign.get_next_level(current_level.level_id)

## Load the next level in the current campaign
func load_next_level() -> void:
	var next_level = get_next_level()
	if next_level:
		load_level_config(next_level, current_campaign)
	else:
		print("LevelManager: No next level - campaign complete!")
		if current_campaign:
			campaign_completed.emit(current_campaign.campaign_id)

# ============================================
# LEVEL COMPLETION
# ============================================

## Call this when a level is completed
func complete_level(stars: int) -> void:
	if not current_level:
		push_error("LevelManager: No current level to complete!")
		return

	print("LevelManager: Level '", current_level.level_id, "' completed with ", stars, " stars")

	# Award bonus gold based on stars
	var bonus_gold = 0
	match stars:
		3: bonus_gold = current_level.three_star_gold_bonus
		2: bonus_gold = current_level.two_star_gold_bonus
		1: bonus_gold = current_level.one_star_gold_bonus

	if bonus_gold > 0:
		GameManager.add_gold(bonus_gold)
		print("LevelManager: Bonus gold awarded: ", bonus_gold)

	# Emit completion signal
	level_completed.emit(current_level.level_id, stars)

	# Save progress (handled by SaveManager)
	SaveManager.save_level_completion(current_level.level_id, stars)

# ============================================
# HELPER METHODS
# ============================================

## Get all levels from all campaigns (for debug/testing)
func get_all_levels() -> Array[LevelConfig]:
	var all_levels: Array[LevelConfig] = []
	for campaign in campaigns:
		all_levels.append_array(campaign.levels)
	return all_levels

## Quick load level by ID (searches all campaigns)
func quick_load_level(level_id: String) -> void:
	var level = get_level_by_id(level_id)
	if level:
		# Find which campaign this level belongs to
		for campaign in campaigns:
			if campaign.get_level_by_id(level_id):
				load_level_config(level, campaign)
				return
	else:
		push_error("LevelManager: Level '", level_id, "' not found in any campaign!")
