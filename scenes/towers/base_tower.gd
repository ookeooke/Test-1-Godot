class_name BaseTower
extends StaticBody2D

# ============================================
# BASE TOWER - Common logic for all towers
# ============================================

# EDITOR PREVIEW
@export_range(1, 5) var preview_level: int = 1:
	set(value):
		preview_level = value
		tower_level = value
		_update_tower_visual()

# TOWER IDENTITY
@export var tower_id: String = "base"

# TARGETING MODES
enum TargetingMode {
	FIRST,
	LAST,
	CLOSE,
	STRONG,
	WEAK
}

# TOWER STATS
var stat_damage: Stat
var stat_attack_speed: Stat
var stat_range: Stat

# Computed properties
var damage: float:
	get: return stat_damage.get_value() if stat_damage else 0.0

var attack_speed: float:
	get: return stat_attack_speed.get_value() if stat_attack_speed else 0.0

var range_radius: float:
	get: return stat_range.get_value() if stat_range else 0.0

@export var targeting_mode: TargetingMode = TargetingMode.FIRST
var build_cost = 0

# UPGRADE SYSTEM
var tower_level = 1
var upgrade_path = ""
const MAX_LEVEL_BEFORE_CHOICE = 3
const MAX_LEVEL = 5

# TARGET SELECTION TUNING
const PROGRESS_EPSILON := 0.01
const PROGRESS_SWITCH_THRESHOLD := 0.05
const HEALTH_EPSILON := 1.0
const HEALTH_SWITCH_THRESHOLD := 25.0
const MIN_TARGET_LOCK_TIME := 0.25

var last_target_change_time_msec := 0

# REFERENCES
var detection_range: Area2D
var click_area: Area2D
var range_indicator: Polygon2D
var shoot_timer: Timer
var mode_label: Label
var debug_line: Line2D

# SELECTION STATE
var is_selected = false

# TARGETING
var enemies_in_range = []
var current_target = null

# VISUAL SCENES
@export_group("Visual Scenes")
@export var visual_scene_l1: PackedScene
@export var visual_scene_l2: PackedScene
@export var visual_scene_l3: PackedScene
@export var visual_scene_l4_damage: PackedScene
@export var visual_scene_l4_range: PackedScene
@export var visual_scene_l5_damage: PackedScene
@export var visual_scene_l5_range: PackedScene
@export var construction_scene: PackedScene = preload("res://scenes/towers/construction_site.tscn")

# TOWER SPOT
var parent_spot = null

# CONSTRUCTION STATE
var is_under_construction: bool = false
var construction_instance: Node2D = null
var current_build_time: float = 2.0

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Force level 1 for new towers
	if not Engine.is_editor_hint():
		tower_level = 1

	_initialize_stats()

	# Get references
	detection_range = $DetectionRange
	range_indicator = $RangeIndicator

	# Setup click detection
	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	# Initialize visuals
	if tower_level == 1:
		is_under_construction = true
		
	_update_tower_visual()

	# Setup detection
	detection_range.collision_layer = 8
	detection_range.collision_mask = 1
	detection_range.monitoring = true
	detection_range.body_entered.connect(_on_enemy_entered_range)
	detection_range.body_exited.connect(_on_enemy_exited_range)

	_defer_enemy_registration()

	# Create shoot timer
	shoot_timer = Timer.new()
	if attack_speed > 0:
		shoot_timer.wait_time = 1.0 / attack_speed
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	add_child(shoot_timer)
	if attack_speed > 0:
		shoot_timer.start()

	# Draw range indicator
	draw_range_circle()
	range_indicator.visible = false

	# Create mode label
	mode_label = Label.new()
	add_child(mode_label)
	mode_label.position = Vector2(-30, -80)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 10)
	update_mode_label()

	# Create debug line
	debug_line = Line2D.new()
	add_child(debug_line)
	debug_line.width = 3.0
	debug_line.default_color = Color.RED
	debug_line.z_index = 100
	debug_line.visible = false

	last_target_change_time_msec = Time.get_ticks_msec()

	if BalanceTracker:
		BalanceTracker.register_tower(self, tower_id, build_cost)

func _process(_delta):
	# Don't do anything if under construction
	if is_under_construction:
		return

	# Child classes should handle rotation/attack logic here
	# or override _process completely
	pass

func _physics_process(_delta):
	if detection_range and not detection_range.monitoring:
		detection_range.monitoring = true

func _draw():
	if not DebugConfig.visual_debug_enabled:
		return

	draw_arc(Vector2.ZERO, range_radius, 0, TAU, 64, Color(0, 1, 0, 0.5), 2.0)
	
	var range_text = "R: %d" % range_radius
	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(-20, -range_radius - 10), range_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.GREEN)

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue

		var enemy_pos = to_local(enemy.global_position)
		var is_boss = _is_enemy_boss(enemy)
		var line_color = Color.RED if is_boss else Color(0.5, 0.5, 0.5, 0.3)
		var line_width = 3.0 if is_boss else 1.0
		draw_line(Vector2.ZERO, enemy_pos, line_color, line_width)

		if is_boss:
			draw_circle(enemy_pos, 40.0, Color(1, 0, 0, 0.3))
			draw_arc(enemy_pos, 40.0, 0, TAU, 32, Color.RED, 3.0)

		var info_text = ""
		match targeting_mode:
			TargetingMode.FIRST, TargetingMode.LAST:
				info_text = "P:%.2f" % _get_enemy_progress(enemy)
			TargetingMode.CLOSE:
				info_text = "D:%d" % int(global_position.distance_to(enemy.global_position))
			TargetingMode.STRONG, TargetingMode.WEAK:
				info_text = "H:%d" % int(_get_enemy_health(enemy))

		if is_boss:
			info_text = "🔴BOSS🔴\n" + info_text

		var label_pos = enemy_pos + Vector2(0, -50 if is_boss else -30)
		var text_color = Color.RED if is_boss else (Color.YELLOW if enemy == current_target else Color.WHITE)
		draw_string(font, label_pos, info_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16 if is_boss else 14, text_color)

	var count_text = "Enemies: %d" % enemies_in_range.size()
	draw_string(font, Vector2(-40, range_radius + 20), count_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.CYAN)

# ============================================
# VIRTUAL FUNCTIONS (Override in Child)
# ============================================

func _on_shoot_timer_timeout():
	pass

func _update_weapon_reference(_visual_instance):
	pass

# ============================================
# STAT INITIALIZATION
# ============================================

func _initialize_stats():
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)

	if level_1_stats.is_empty():
		push_error("[BaseTower] CRITICAL: Failed to load stats for %s" % tower_id)
		stat_damage = Stat.new(0.0)
		stat_attack_speed = Stat.new(0.0)
		stat_range = Stat.new(0.0)
	else:
		stat_damage = Stat.new(level_1_stats.get("damage", 0.0))
		stat_attack_speed = Stat.new(level_1_stats.get("attack_speed", 0.0))
		stat_range = Stat.new(level_1_stats.get("range", 0.0))

	# print("[%s] Stats initialized - DMG: %.1f, AS: %.1f, Range: %.1f" % [name, stat_damage.get_value(), stat_attack_speed.get_value(), stat_range.get_value()])

# ============================================
# UPGRADE SYSTEM
# ============================================

func needs_path_choice() -> bool:
	return tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == ""

func upgrade_tower():
	if tower_level == MAX_LEVEL_BEFORE_CHOICE and upgrade_path == "":
		push_warning("[%s] Cannot upgrade past level 3 - must choose path!" % name)
		return false

	if tower_level >= MAX_LEVEL:
		push_warning("[%s] Tower already at MAX LEVEL!" % name)
		return false

	var old_level = tower_level
	var upgrade_cost = get_upgrade_cost()
	tower_level += 1
	build_cost += upgrade_cost

	var old_source = "upgrade_level_%d" % old_level
	stat_damage.remove_modifiers_from_source(old_source)
	stat_attack_speed.remove_modifiers_from_source(old_source)
	stat_range.remove_modifiers_from_source(old_source)

	var mod_source = "upgrade_level_%d" % tower_level
	var target_stats: Dictionary
	var level_1_stats = TowerData.get_tower_stats(tower_id, 1)

	if tower_level <= MAX_LEVEL_BEFORE_CHOICE:
		target_stats = TowerData.get_tower_stats(tower_id, tower_level)
	else:
		var path_key = upgrade_path + "_path"
		target_stats = TowerData.get_tower_stats(tower_id, tower_level, path_key)

	if target_stats.is_empty():
		push_error("[%s] Failed to load upgrade stats for level %d" % [name, tower_level])
		return false

	var damage_delta = target_stats.get("damage", 0.0) - level_1_stats.get("damage", 0.0)
	var attack_speed_delta = target_stats.get("attack_speed", 0.0) - level_1_stats.get("attack_speed", 0.0)
	var range_delta = target_stats.get("range", 0.0) - level_1_stats.get("range", 0.0)

	if damage_delta != 0:
		stat_damage.add_modifier(StatModifier.create_flat(damage_delta, mod_source, "Level %d" % tower_level))
	if attack_speed_delta != 0:
		stat_attack_speed.add_modifier(StatModifier.create_flat(attack_speed_delta, mod_source, "Level %d" % tower_level))
	if range_delta != 0:
		stat_range.add_modifier(StatModifier.create_flat(range_delta, mod_source, "Level %d" % tower_level))

	# print("✅ [%s] Upgraded to Level %d" % [name, tower_level])

	_update_detection_range()
	draw_range_circle()

	is_under_construction = true
	current_build_time = 1.5
	
	# SHOW SPOT SPRITE DURING UPGRADE
	# Acts as foundation while construction animation plays
	if parent_spot:
		if "sprite" in parent_spot:
			parent_spot.sprite.visible = true
		if parent_spot.has_method("play_construction_intro"):
			print("[BaseTower] Triggering Intro Animation on Spot")
			parent_spot.play_construction_intro(self)
		
	_update_tower_visual()

	if shoot_timer and attack_speed > 0:
		shoot_timer.wait_time = 1.0 / attack_speed

	if BalanceTracker:
		BalanceTracker.record_tower_upgrade(self, tower_level, upgrade_cost)
	return true

func get_upgrade_cost() -> int:
	if tower_level >= 5:
		return 0
	var path_param = ""
	if upgrade_path != "":
		path_param = upgrade_path + "_path"
	var current_stats = TowerData.get_tower_stats(tower_id, tower_level, path_param)
	if current_stats and "cost_to_next" in current_stats:
		return current_stats["cost_to_next"]
	return 0

func get_upgrade_stats(preview_path: String = "") -> Dictionary:
	var current_damage = damage
	var current_attack_speed = attack_speed
	var current_range = range_radius
	
	var next_level = tower_level + 1
	var preview_path_key = ""
	if next_level == 4 and preview_path != "":
		preview_path_key = preview_path + "_path"
	elif next_level == 5 and upgrade_path != "":
		preview_path_key = upgrade_path + "_path"

	var next_level_stats: Dictionary
	if next_level <= MAX_LEVEL_BEFORE_CHOICE:
		next_level_stats = TowerData.get_tower_stats(tower_id, next_level)
	else:
		next_level_stats = TowerData.get_tower_stats(tower_id, next_level, preview_path_key)

	if next_level_stats.is_empty():
		return {}

	return {
		"damage": next_level_stats.get("damage", 0.0),
		"attack_speed": next_level_stats.get("attack_speed", 0.0),
		"range": next_level_stats.get("range", 0.0),
		"damage_delta": next_level_stats.get("damage", 0.0) - current_damage,
		"attack_speed_delta": next_level_stats.get("attack_speed", 0.0) - current_attack_speed,
		"range_delta": next_level_stats.get("range", 0.0) - current_range
	}

func choose_damage_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "damage"
	var success = upgrade_tower()
	if success:
		current_build_time = 2.0
		_update_tower_visual()
	return success

func choose_range_path() -> bool:
	if tower_level != MAX_LEVEL_BEFORE_CHOICE: return false
	upgrade_path = "range"
	var success = upgrade_tower()
	if success:
		current_build_time = 2.0
		_update_tower_visual()
	return success

func _update_detection_range():
	if not detection_range: return
	for child in detection_range.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			if shape and shape is CircleShape2D:
				shape.radius = range_radius
			break
	call_deferred("_revalidate_enemies_in_range")

func _revalidate_enemies_in_range():
	var enemies_to_remove = []
	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			enemies_to_remove.append(enemy)
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance > range_radius:
			enemies_to_remove.append(enemy)
	
	for enemy in enemies_to_remove:
		enemies_in_range.erase(enemy)
		if current_target == enemy:
			if enemy.has_method("set_debug_targeted"):
				enemy.set_debug_targeted(false)
			current_target = null
			_record_target_change_time()

# ============================================
# VISUALS & CONSTRUCTION
# ============================================

func _update_tower_visual():
	if is_under_construction:
		_show_construction_site()
		return

	if has_node("VisualContainer"):
		$VisualContainer.queue_free()
		$VisualContainer.name = "VisualContainer_Deleting"
		
	var container = Node2D.new()
	container.name = "VisualContainer"
	add_child(container)
	
	var scene_to_spawn = visual_scene_l1
	
	if tower_level == 5:
		if upgrade_path == "damage" and visual_scene_l5_damage:
			scene_to_spawn = visual_scene_l5_damage
		elif upgrade_path == "range" and visual_scene_l5_range:
			scene_to_spawn = visual_scene_l5_range
	elif tower_level == 4:
		if upgrade_path == "damage" and visual_scene_l4_damage:
			scene_to_spawn = visual_scene_l4_damage
		elif upgrade_path == "range" and visual_scene_l4_range:
			scene_to_spawn = visual_scene_l4_range
	elif tower_level >= 3 and visual_scene_l3:
		scene_to_spawn = visual_scene_l3
	elif tower_level >= 2 and visual_scene_l2:
		scene_to_spawn = visual_scene_l2
		
	if scene_to_spawn:
		var visual_instance = scene_to_spawn.instantiate()
		container.add_child(visual_instance)
		_update_weapon_reference(visual_instance)
		# print("[Tower] %s updated visual. Level: %d | Scene: %s" % [name, tower_level, scene_to_spawn.resource_path])
	else:
		print("[Tower] %s MISSING VISUAL SCENE for Level %d" % [name, tower_level])
		
	if construction_instance:
		construction_instance.queue_free()
		construction_instance = null

func _show_construction_site():
	if has_node("VisualContainer"):
		$VisualContainer.queue_free()
		
	if construction_scene:
		if construction_instance and is_instance_valid(construction_instance):
			return
		construction_instance = construction_scene.instantiate()
		add_child(construction_instance)
		construction_instance.start_construction(current_build_time)
		construction_instance.construction_finished.connect(_on_construction_finished)

func _on_construction_finished():
	is_under_construction = false
	if construction_instance:
		construction_instance.queue_free()
		construction_instance = null
	
	# HIDE SPOT SPRITE NOW
	# Upgrade complete, new tower covers the spot
	if parent_spot:
		if "sprite" in parent_spot:
			parent_spot.sprite.visible = false
		if parent_spot.has_method("play_construction_complete"):
			print("[BaseTower] Triggering Complete Animation on Spot")
			parent_spot.play_construction_complete(self)
		
	_update_tower_visual()

func _get_tower_sprite() -> Sprite2D:
	if has_node("VisualContainer"):
		var container = $VisualContainer
		if container.get_child_count() > 0:
			var visual_scene = container.get_child(0)
			if visual_scene.has_node("TowerSprite"):
				return visual_scene.get_node("TowerSprite")
			if visual_scene.has_node("TowerVisual"):
				return visual_scene.get_node("TowerVisual")
	return null

func draw_range_circle():
	if range_indicator:
		var points = []
		var steps = 64
		for i in range(steps + 1):
			var angle = i * TAU / steps
			points.append(Vector2(cos(angle), sin(angle)) * range_radius)
		range_indicator.polygon = points
		range_indicator.color = Color(0.3, 0.5, 1.0, 0.3)

# ============================================
# RANGE PREVIEW SYSTEM
# ============================================

var range_preview_indicator: Polygon2D = null

func show_range_preview(preview_radius: float):
	"""Show a secondary ghost range circle to preview upgrade range"""
	
	if not range_preview_indicator:
		# Create indicator if it doesn't exist
		range_preview_indicator = Polygon2D.new()
		range_preview_indicator.name = "RangePreviewIndicator"
		add_child(range_preview_indicator)
		# Use a distinct color (e.g., Green tint for upgrade)
		range_preview_indicator.color = Color(0.2, 1.0, 0.2, 0.3)
		range_preview_indicator.z_index = 100 # FORCE ON TOP for debugging
	
	# Draw the circle for the new radius
	var points = []
	var steps = 64
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * preview_radius)
	
	range_preview_indicator.polygon = points
	range_preview_indicator.visible = true

func hide_range_preview():
	"""Hide the ghost range preview"""
	if range_preview_indicator:
		range_preview_indicator.visible = false


# ============================================
# INTERACTION
# ============================================

func select_tower():
	is_selected = true
	range_indicator.visible = true

func deselect_tower():
	is_selected = false
	range_indicator.visible = false

func _on_area_input_event(_viewport, event, _shape_idx):
	var is_interact = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_interact = true
	elif event is InputEventScreenTouch and event.pressed:
		is_interact = true

	if is_interact:
		_on_clicked()
		get_viewport().set_input_as_handled()

func _on_clicked():
	if parent_spot:
		parent_spot.tower_clicked.emit(parent_spot, self)
	else:
		var spot = get_parent()
		if spot and spot.has_signal("tower_clicked"):
			spot.tower_clicked.emit(spot, self)

func _on_mouse_entered():
	var sprite = _get_tower_sprite()
	if sprite:
		sprite.modulate = Color(1.3, 1.3, 1.3)

func _on_mouse_exited():
	var sprite = _get_tower_sprite()
	if sprite:
		sprite.modulate = Color(1, 1, 1)

# ============================================
# TARGETING HELPERS
# ============================================

func _on_enemy_entered_range(body):
	if body.is_in_group("enemy"):
		if body.has_signal("enemy_died") and not body.enemy_died.is_connected(_on_enemy_died):
			body.enemy_died.connect(_on_enemy_died.bind(body))
		if enemies_in_range.has(body):
			return
		enemies_in_range.append(body)

func _on_enemy_exited_range(body):
	if body.is_in_group("enemy"):
		enemies_in_range.erase(body)
		if current_target == body:
			if body.has_method("set_debug_targeted"):
				body.set_debug_targeted(false)
			current_target = null
			_record_target_change_time()

func _defer_enemy_registration():
	await get_tree().physics_frame
	_register_existing_enemies()

func _register_existing_enemies():
	if not detection_range: return
	var found_enemies = detection_range.get_overlapping_bodies()
	for body in found_enemies:
		_on_enemy_entered_range(body)

func _on_enemy_died(enemy):
	enemies_in_range.erase(enemy)
	if current_target == enemy:
		if enemy.has_method("set_debug_targeted"):
			enemy.set_debug_targeted(false)
		current_target = get_target_by_mode()
		_record_target_change_time()
		if current_target != null and shoot_timer.time_left < 0.1:
			_on_shoot_timer_timeout()

func get_target_by_mode():
	var filtered_enemies = []
	for e in enemies_in_range:
		if is_instance_valid(e) and (not e.has_method("is_dead") or not e.is_dead()) and ("current_health" not in e or e.current_health > 0.0):
			filtered_enemies.append(e)
	enemies_in_range = filtered_enemies

	if enemies_in_range.is_empty():
		return null

	# Find the "best" candidate based on current mode
	var candidate = null
	match targeting_mode:
		TargetingMode.FIRST: candidate = get_first_enemy()
		TargetingMode.LAST: candidate = get_last_enemy()
		TargetingMode.CLOSE: candidate = get_closest_enemy()
		TargetingMode.STRONG: candidate = get_strongest_enemy()
		TargetingMode.WEAK: candidate = get_weakest_enemy()
		
	# Apply hysteresis (stickiness)
	return _pick_target_with_stickiness(current_target, candidate)

func _pick_target_with_stickiness(old_target, candidate_target):
	# If we have no candidate, we must lose target
	if candidate_target == null:
		if old_target != null:
			_record_target_change_time()
		return null

	# If same target, keep it
	if old_target == candidate_target:
		return candidate_target

	# Check if old target is still valid
	var old_valid = old_target != null and is_instance_valid(old_target) and enemies_in_range.has(old_target)
	
	if old_valid:
		# Time-based lock: Don't switch too fast (e.g. 0.25s)
		var now_msec = Time.get_ticks_msec()
		var elapsed = (now_msec - last_target_change_time_msec) / 1000.0
		if elapsed < MIN_TARGET_LOCK_TIME:
			return old_target

		# Score-based hysteresis: Only switch if new target is SIGNIFICANTLY better
		match targeting_mode:
			TargetingMode.FIRST:
				var old_p = _get_enemy_progress(old_target)
				var new_p = _get_enemy_progress(candidate_target)
				# Only switch if new is > 5% ahead
				if new_p < old_p + PROGRESS_SWITCH_THRESHOLD:
					return old_target
			TargetingMode.LAST:
				var old_p = _get_enemy_progress(old_target)
				var new_p = _get_enemy_progress(candidate_target)
				if new_p > old_p - PROGRESS_SWITCH_THRESHOLD:
					return old_target
			TargetingMode.CLOSE:
				var old_d = global_position.distance_to(old_target.global_position)
				var new_d = global_position.distance_to(candidate_target.global_position)
				# Only switch if new is > 50px closer
				if new_d > old_d - 50.0:
					return old_target
			TargetingMode.STRONG:
				var old_h = _get_enemy_health(old_target)
				var new_h = _get_enemy_health(candidate_target)
				# Only switch if new has > 25 more health
				if new_h <= old_h + HEALTH_SWITCH_THRESHOLD:
					return old_target
			TargetingMode.WEAK:
				var old_h = _get_enemy_health(old_target)
				var new_h = _get_enemy_health(candidate_target)
				if new_h >= old_h - HEALTH_SWITCH_THRESHOLD:
					return old_target

	# If we decided to switch, record the time
	if old_target != candidate_target:
		_record_target_change_time()

	return candidate_target

func get_first_enemy():
	var furthest = enemies_in_range[0]
	var furthest_progress = _get_enemy_progress(furthest)
	for enemy in enemies_in_range:
		var progress = _get_enemy_progress(enemy)
		if progress > furthest_progress + PROGRESS_EPSILON:
			furthest = enemy
			furthest_progress = progress
	return furthest

func get_last_enemy():
	var last = enemies_in_range[0]
	var last_progress = _get_enemy_progress(last)
	for enemy in enemies_in_range:
		var progress = _get_enemy_progress(enemy)
		if progress < last_progress - PROGRESS_EPSILON:
			last = enemy
			last_progress = progress
	return last

func get_closest_enemy():
	var closest = enemies_in_range[0]
	var min_distance = global_position.distance_to(closest.global_position)
	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			closest = enemy
			min_distance = distance
	return closest

func get_strongest_enemy():
	var strongest = enemies_in_range[0]
	var highest_health = _get_enemy_health(strongest)
	for enemy in enemies_in_range:
		var health = _get_enemy_health(enemy)
		if health > highest_health:
			strongest = enemy
			highest_health = health
	return strongest

func get_weakest_enemy():
	var weakest = enemies_in_range[0]
	var lowest_health = _get_enemy_health(weakest)
	for enemy in enemies_in_range:
		var health = _get_enemy_health(enemy)
		if health < lowest_health:
			weakest = enemy
			lowest_health = health
	return weakest

func _get_enemy_progress(enemy) -> float:
	if not enemy or not is_instance_valid(enemy): return 0.0
	var path_follower = enemy.get_parent()
	if path_follower and path_follower is PathFollow2D:
		return path_follower.progress_ratio
	if "waypoint_progress" in enemy:
		return enemy.waypoint_progress
	if enemy.has_method("get_progress"):
		return enemy.get_progress()
	var normalized_position = enemy.global_position / 1000.0
	return clamp(normalized_position.x + normalized_position.y, 0.0, 1.0)

func _get_enemy_health(enemy) -> float:
	if not enemy or not is_instance_valid(enemy): return 0.0
	if "current_health" in enemy:
		return float(enemy.current_health)
	return 0.0

func _is_enemy_boss(enemy) -> bool:
	if not enemy or not is_instance_valid(enemy): return false
	if "is_boss" in enemy: return enemy.is_boss
	var enemy_name = enemy.get_enemy_name() if enemy.has_method("get_enemy_name") else ""
	return "troll" in enemy_name.to_lower() or "boss" in enemy_name.to_lower()

func _record_target_change_time(now_msec := -1):
	last_target_change_time_msec = now_msec if now_msec >= 0 else Time.get_ticks_msec()

func set_targeting_mode(mode: TargetingMode):
	targeting_mode = mode
	update_mode_label()

func update_mode_label():
	if not mode_label: return
	match targeting_mode:
		TargetingMode.FIRST:
			mode_label.text = "[FIRST]"
			mode_label.modulate = Color.CYAN
		TargetingMode.LAST:
			mode_label.text = "[LAST]"
			mode_label.modulate = Color.LIGHT_BLUE
		TargetingMode.CLOSE:
			mode_label.text = "[CLOSE]"
			mode_label.modulate = Color.YELLOW
		TargetingMode.STRONG:
			mode_label.text = "[STRONG]"
			mode_label.modulate = Color.RED
		TargetingMode.WEAK:
			mode_label.text = "[WEAK]"
			mode_label.modulate = Color.GREEN
