extends Node2D

# ============================================
# DPS BENCHMARK SCRIPT
# ============================================
# Recreated to validate balance changes and tracking fixes.
# ============================================

@export var duration: float = 10.0

var towers = []
var enemies = []
var time_elapsed = 0.0
var tracking_started = false

# SCENE REFERENCES
var archer_scene = preload("res://scenes/towers/archer_tower.tscn")
var mage_scene = preload("res://scenes/towers/mage_tower.tscn")
var artillery_scene = preload("res://scenes/towers/artillery_tower.tscn")
var barracks_scene = preload("res://scenes/towers/soldier_tower.tscn") # SoldierTower

var enemy_goblin_scene = preload("res://scenes/enemies/goblin.tscn")
var enemy_wolf_scene = preload("res://scenes/enemies/wolf.tscn")

func _ready():
	print("🚀 Starting DPS Benchmark...")
	
	# SETUP ENVIRONMENT
	if BalanceTracker:
		BalanceTracker.start_run("benchmark_v2")
		BalanceTracker.is_tracking = true
	
	setup_test_scenario()
	
func setup_test_scenario():
	# 1. Spawn Towers (Spread out)
	spawn_tower("archer", archer_scene, Vector2(300, 300))
	spawn_tower("mage", mage_scene, Vector2(500, 300))
	spawn_tower("artillery", artillery_scene, Vector2(700, 300))
	spawn_tower("barracks", barracks_scene, Vector2(900, 300))
	
	# 2. Spawn Wave of Enemies (Continuous stream)
	# Archers/Mages need targets. Barracks need soldiers to fight.
	start_enemy_spawner()

func spawn_tower(type: String, scene: PackedScene, pos: Vector2):
	if not scene:
		push_error("Scene missing for " + type)
		return
		
	var tower = scene.instantiate()
	tower.position = pos
	add_child(tower)
	
	# Force finish construction
	if "is_under_construction" in tower:
		tower.is_under_construction = false
		if tower.has_method("_update_tower_visual"):
			tower._update_tower_visual()
			
	towers.append(tower)
	print("Combined: Spawned " + type)
	
	if BalanceTracker:
		BalanceTracker.register_tower(tower, type, 100)

var spawn_timer = 0.0
func _process(delta):
	time_elapsed += delta
	spawn_timer += delta
	
	# Spawn enemies every 0.5s to ensure constant targets
	if spawn_timer > 0.5:
		spawn_timer = 0.0
		spawn_enemies()
		
	if time_elapsed >= duration:
		finish_benchmark()
		set_process(false)

func spawn_enemies():
	# Spawn closer to towers so they engage immediately
	spawn_enemy(enemy_goblin_scene, Vector2(300, 400)) # Under Archer
	spawn_enemy(enemy_goblin_scene, Vector2(500, 400)) # Under Mage
	spawn_enemy(enemy_wolf_scene, Vector2(700, 400)) # Under Artillery (Swarm)
	spawn_enemy(enemy_wolf_scene, Vector2(900, 400)) # Under Barracks
	
func spawn_enemy(scene: PackedScene, pos: Vector2):
	if notscene: return
	var enemy = scene.instantiate()
	enemy.position = pos
	# Dummy path follower needed? No, just place them.
	# But BaseEnemy expects a parent path follower usually?
	# Let's add them directly to root or self for test.
	add_child(enemy)
	# Force collision update
	enemy.global_position = pos

func finish_benchmark():
	print("\n📊 BENCHMARK COMPLETE (%.1fs)" % time_elapsed)
	
	if BalanceTracker:
		print("--- Live Tracking Data ---")
		var run_data = BalanceTracker.current_run
		var towers_data = BalanceTracker.tracked_towers
		
		for id in towers_data:
			var t = towers_data[id]
			print("Stats for [%s]:" % t.type)
			print("  - Total Damage: %.1f" % t.total_damage)
			print("  - Kills: %d" % t.kills)
			print("  - DPS: %.1f" % (t.total_damage / duration))
			
			if t.type == "barracks":
				if t.total_damage > 0:
					print("  ✅ BARRACKS TRACKING WORKING!")
				else:
					print("  ❌ BARRACKS HAS 0 DAMAGE (Fix Attempt Failed?)")
	
	print("--------------------------")
