extends "res://scripts/enemies/base_enemy.gd"

## Troll Boss Enemy
## Boss enemy with very high HP, slow speed, high damage.

## Boss flag for identification
var is_boss: bool = true

## Health milestones to track (75%, 50%, 25%)
var health_milestones: Array = [75.0, 50.0, 25.0]
var reached_milestones: Array = []

## Boss tracking flag
var boss_tracking_started: bool = false

func _init():
	# Set troll boss-specific stats
	speed = 18.0  # PACING FIX: Reduced from 30 (-40% total: -25% KR pacing, -20% strategic slowdown)
	max_health = 1200.0  # BALANCE FIX: Was 2000 (165s fight), now 1200 (56s fight - matches KR1's 46s)
	melee_damage = 20.0
	attack_cooldown = 1.5
	gold_reward = 50  # Increased from 40 (+25% gold rewards)
	life_damage = 3
	can_be_blocked = true
	melee_detection_range = 100.0
	death_shake = "Large"  # Epic boss shake!
	armor = 0.20  # BALANCE FIX: Was 0.30 (too tanky), now 0.20 - boss still tough but not marathon

	# Hit point for arrows (upper chest of large troll)
	hit_point_offset = Vector2(0, -15)

func _ready():
	super._ready()

	# Register boss appearance with BalanceTracker
	if BalanceTracker:
		BalanceTracker.record_boss_appeared("troll_boss", self)
		boss_tracking_started = true

	print("🔴 TROLL BOSS SPAWNED - Health: %.0f, Speed: %.1f" % [max_health, speed])

func _process(delta):
	# Check health milestones
	if boss_tracking_started and current_health > 0:
		_check_health_milestones()

func _check_health_milestones():
	"""Check if boss reached any health milestones"""
	var health_percent = (current_health / max_health) * 100.0

	for milestone in health_milestones:
		# Check if we crossed this milestone and haven't recorded it yet
		if health_percent <= milestone and not reached_milestones.has(milestone):
			reached_milestones.append(milestone)

			if BalanceTracker:
				BalanceTracker.record_boss_health_milestone("troll_boss", milestone)

			print("🔴 BOSS HEALTH MILESTONE: %.0f%% (%.0f / %.0f HP)" % [milestone, current_health, max_health])

func take_damage(amount: float, damage_source = null, damage_source_type = "unknown"):
	"""Override to track boss-specific damage"""
	super.take_damage(amount, damage_source, damage_source_type)

	# Record boss damage in BalanceTracker
	if boss_tracking_started and BalanceTracker and damage_source:
		BalanceTracker.record_boss_damage("troll_boss", damage_source, amount, damage_source_type)

func die():
	"""Override to record boss defeat"""
	if boss_tracking_started and BalanceTracker:
		BalanceTracker.record_boss_defeated("troll_boss")

	super.die()

func reached_end():
	"""Override to record boss leak (when boss reaches end of path)"""
	if boss_tracking_started and BalanceTracker:
		BalanceTracker.record_boss_leaked("troll_boss")

	super.reached_end()

func get_enemy_name() -> String:
	return "Troll Boss"
