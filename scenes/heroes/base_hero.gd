extends CharacterBody2D
class_name BaseHero

# ============================================
# BASE HERO - Common logic for all heroes
# ============================================

signal hero_died(respawn_time)
signal hero_selected(hero)

# STATES
enum State {IDLE, RANGED_COMBAT, MELEE_COMBAT, RETURNING, WALKING}
var current_state = State.IDLE
var hero_id: String

# COMBAT CONFIGURATION
const USE_COMBAT_ANCHOR = true

# STATS - NEW UNIFIED SYSTEM
var current_level: int = 1

# Core stats using new Stat system 
var stat_max_health: Stat
var stat_ranged_damage: Stat
var stat_melee_damage: Stat
var stat_ranged_range: Stat
var stat_ranged_attack_speed: Stat
var stat_movement_speed: Stat
var stat_crit_chance: Stat
var stat_defense: Stat

# Current health 
var current_health = 0.0

# Base stats (Override in child classes)
var BASE_MAX_HEALTH = 100.0
var BASE_RANGED_DAMAGE = 0.0
var BASE_MELEE_DAMAGE = 0.0
var BASE_RANGED_RANGE = 0.0
var BASE_RANGED_ATTACK_SPEED = 1.0
var BASE_MOVEMENT_SPEED = 150.0

# Fixed stats 
var melee_range = 100.0
var melee_attack_speed = 0.8
var combat_distance = 50.0

# MOVEMENT
var max_distance_from_home = 100.0 # LEASH: Increased to 100px to prevent deadlock with 50px stop distance
var max_chase_distance = 150.0 # LEASH: Max distance to chase enemies
var home_position = Vector2.ZERO
var target_position = Vector2.ZERO

# Convenience properties 
var max_health: float:
	get: return stat_max_health.get_value() if stat_max_health else BASE_MAX_HEALTH
var ranged_damage: float:
	get: return stat_ranged_damage.get_value() if stat_ranged_damage else BASE_RANGED_DAMAGE
var melee_damage: float:
	get: return stat_melee_damage.get_value() if stat_melee_damage else BASE_MELEE_DAMAGE
var ranged_range: float:
	get: return stat_ranged_range.get_value() if stat_ranged_range else BASE_RANGED_RANGE
var ranged_attack_speed: float:
	get: return stat_ranged_attack_speed.get_value() if stat_ranged_attack_speed else BASE_RANGED_ATTACK_SPEED
var movement_speed: float:
	get: return stat_movement_speed.get_value() if stat_movement_speed else BASE_MOVEMENT_SPEED
var crit_chance: float:
	get: return stat_crit_chance.get_value() if stat_crit_chance else 0.0
var defense: float:
	get: return stat_defense.get_value() if stat_defense else 0.0

# ENEMY MANAGEMENT
var block_capacity = 2
var current_load = 0
var enemies_in_melee_range = []
var enemies_in_ranged_range = []
var current_ranged_target = null
var current_melee_targets = []

# KINGDOM RUSH COMBAT MOVEMENT
var combat_target: Node2D = null # Current enemy we're walking toward
var combat_movement_enabled: bool = true # Toggle for testing/debugging
const COMBAT_CLOSE_DISTANCE: float = 40.0 # Stop within 40px (Hero Radius 25 + Enemy Radius ~15)

# TIMERS
var ranged_timer: Timer
var melee_timer: Timer

# REGENERATION SYSTEM 
var time_since_last_damage: float = 0.0
var is_regenerating: bool = false
var regen_delay: float = 2.0
var regen_rate: float = 3.0

# ATTRIBUTE BONUSES
var _attribute_regen_bonus: float = 0.0
var _attribute_cdr_bonus: float = 0.0

# SELECTION
var is_selected = false

# REFERENCES
var click_area: Area2D
var ranged_detection: Area2D
var melee_detection: Area2D
var range_indicator: Node2D
var health_bar: Control
var xp_bar: Control
var sprite: Sprite2D
var visuals_node: Node2D = null
var projectile_spawn_node: Node2D = null

# TOWER BUFF SYSTEM
var tower_aura: Area2D = null
var towers_in_aura = []
const AURA_RADIUS = 200.0

# VISUAL
@export var hero_texture: Texture2D


# SKILL SYSTEM
@export var available_skills: Array[HeroSkillData] = []
var skill_manager: HeroSkillManager = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	_setup_references()
	
	print("\n🎯 === HERO INITIALIZATION START: %s ===" % get_hero_id())
	_initialize_stats()
	_setup_equipment_system()
	_setup_skill_system()
	_setup_progression_system()

	if SaveManager:
		SaveManager.hero_attributes_changed.connect(_on_attributes_changed)

	if xp_bar and xp_bar.has_method("setup"):
		xp_bar.setup(self)

	_recalculate_all_stats()
	current_health = max_health
	
	# Set home position to initial spawn point
	home_position = global_position

	set_meta("hero_id", hero_id)
	
	_setup_collisions()
	_setup_timers()
	
	if range_indicator:
		draw_range_circle()
		range_indicator.visible = false
	
	update_health_bar()
	_setup_visuals()

	if BalanceTracker:
		BalanceTracker.register_hero(self, get_hero_id())

func _setup_references():
	if has_node("Visuals"):
		visuals_node = $Visuals
		if visuals_node.has_node("ProjectileSpawnPoint"):
			projectile_spawn_node = visuals_node.get_node("ProjectileSpawnPoint")
	elif has_node("Sprite2D"):
		sprite = $Sprite2D
		if sprite.has_node("ProjectileSpawnPoint"):
			projectile_spawn_node = sprite.get_node("ProjectileSpawnPoint")
			
	if has_node("RangedDetection"): ranged_detection = $RangedDetection
	if has_node("MeleeDetection"): melee_detection = $MeleeDetection
	if has_node("RangeIndicator"): range_indicator = $RangeIndicator
	if has_node("HealthBar"): health_bar = $HealthBar
	if has_node("XPBar"): xp_bar = $XPBar
	
	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)
		
	if has_node("TowerAura"):
		tower_aura = $TowerAura
		tower_aura.collision_layer = 0
		tower_aura.collision_mask = 8
		tower_aura.body_entered.connect(_on_tower_entered_aura)
		tower_aura.body_exited.connect(_on_tower_exited_aura)

func _setup_collisions():
	collision_layer = 2
	collision_mask = 0

	if ranged_detection:
		ranged_detection.collision_layer = 0
		ranged_detection.collision_mask = 1
		if not ranged_detection.body_entered.is_connected(_on_ranged_enemy_entered):
			ranged_detection.body_entered.connect(_on_ranged_enemy_entered)
		if not ranged_detection.body_exited.is_connected(_on_ranged_enemy_exited):
			ranged_detection.body_exited.connect(_on_ranged_enemy_exited)
			
	if melee_detection:
		melee_detection.collision_layer = 0
		melee_detection.collision_mask = 1
		if not melee_detection.body_entered.is_connected(_on_melee_enemy_entered):
			melee_detection.body_entered.connect(_on_melee_enemy_entered)
		if not melee_detection.body_exited.is_connected(_on_melee_enemy_exited):
			melee_detection.body_exited.connect(_on_melee_enemy_exited)

func _setup_timers():
	ranged_timer = Timer.new()
	ranged_timer.wait_time = ranged_attack_speed
	ranged_timer.timeout.connect(_on_ranged_timer_timeout)
	add_child(ranged_timer)

	melee_timer = Timer.new()
	melee_timer.wait_time = melee_attack_speed
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)

func _setup_visuals():
	if sprite and hero_texture:
		sprite.texture = hero_texture
		if sprite.has_node("FallbackRect"):
			sprite.get_node("FallbackRect").visible = false
	elif sprite and sprite.has_node("FallbackRect"):
		sprite.get_node("FallbackRect").visible = true
	
	_add_dynamic_shadow()

func _add_dynamic_shadow():
	"""Add a blob shadow under the unit"""
	# 1. Check if a Shadow node already exists (added in Editor)
	if has_node("Shadow"):
		var shadow = get_node("Shadow")
		move_child(shadow, 0)
		return

	# 2. Fallback: Create dynamic shadow if none exists
	var shadow_scene = load("res://scenes/effects/shadow.tscn")
	if shadow_scene:
		var shadow = shadow_scene.instantiate()
		shadow.name = "Shadow"
		
		# SMART SCALING: Calculate scale based on CollisionShape
		var target_scale = Vector2(1.0, 1.0)
		if has_node("CollisionShape2D"):
			var shape = get_node("CollisionShape2D").shape
			if shape is CircleShape2D:
				var scale_factor = (shape.radius * 2.0) / 32.0
				target_scale = Vector2(scale_factor, scale_factor)
			elif shape is CapsuleShape2D:
				var scale_factor = (shape.radius * 2.0) / 32.0
				target_scale = Vector2(scale_factor, scale_factor)
				
		shadow.scale = target_scale
		shadow.position = Vector2(0, 5)
		add_child(shadow)
		move_child(shadow, 0)
# STAT SYSTEM
# ============================================

func _initialize_stats():
	stat_max_health = Stat.new(BASE_MAX_HEALTH)
	stat_ranged_damage = Stat.new(BASE_RANGED_DAMAGE)
	stat_melee_damage = Stat.new(BASE_MELEE_DAMAGE)
	stat_ranged_range = Stat.new(BASE_RANGED_RANGE)
	stat_ranged_attack_speed = Stat.new(BASE_RANGED_ATTACK_SPEED)
	stat_movement_speed = Stat.new(BASE_MOVEMENT_SPEED)
	stat_crit_chance = Stat.new(0.0)
	stat_defense = Stat.new(0.0)
	current_health = BASE_MAX_HEALTH

func _recalculate_all_stats():
	print("[BaseHero] Recalculating stats for %s..." % hero_id)
	if not stat_max_health: return

	_attribute_regen_bonus = 0.0
	_attribute_cdr_bonus = 0.0

	stat_max_health.clear_modifiers()
	stat_ranged_damage.clear_modifiers()
	stat_melee_damage.clear_modifiers()
	stat_ranged_range.clear_modifiers()
	stat_ranged_attack_speed.clear_modifiers()
	stat_movement_speed.clear_modifiers()
	stat_crit_chance.clear_modifiers()
	stat_defense.clear_modifiers()

	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
	for slot in equipped_items.keys():
		var item = equipped_items[slot]
		if item == null or not item is ItemInstance: continue
		var item_data = item.get_data()
		if not item_data: continue
		var modifiers = item_data.get_stat_modifiers(item.upgrade_level, item.rolled_affixes)
		for modifier in modifiers:
			_apply_modifier_to_appropriate_stat(modifier)

	if skill_manager:
		var skill_modifiers = skill_manager.get_passive_skill_modifiers()
		for modifier in skill_modifiers:
			_apply_modifier_to_appropriate_stat(modifier)

	var level_modifiers = _get_level_based_modifiers()
	for modifier in level_modifiers:
		_apply_modifier_to_appropriate_stat(modifier)

	var attribute_modifiers = _get_attribute_modifiers()
	for modifier in attribute_modifiers:
		_apply_modifier_to_appropriate_stat(modifier)

	if ranged_timer:
		ranged_timer.wait_time = ranged_attack_speed

	if range_indicator:
		draw_range_circle()
	update_health_bar()

	if current_health > max_health:
		current_health = max_health

	if BalanceTracker:
		var equipped_for_tracking = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
		var bonuses = {
			"damage": ranged_damage - BASE_RANGED_DAMAGE,
			"health": max_health - BASE_MAX_HEALTH,
			"attack_speed_mult": BASE_RANGED_ATTACK_SPEED / ranged_attack_speed,
			"range": ranged_range - BASE_RANGED_RANGE
		}
		BalanceTracker.record_hero_equipment(self, equipped_for_tracking, bonuses)

func _apply_modifier_to_appropriate_stat(modifier: StatModifier):
	var desc_lower = modifier.description.to_lower()
	if "damage" in desc_lower:
		if "melee" in desc_lower:
			stat_melee_damage.add_modifier(modifier)
		elif "ranged" in desc_lower:
			stat_ranged_damage.add_modifier(modifier)
		else:
			# Generic damage - apply based on class type
			if _get_class_type() == 0: # Melee
				stat_melee_damage.add_modifier(modifier)
			else: # Ranged (or others)
				stat_ranged_damage.add_modifier(modifier)
	elif "health" in desc_lower:
		stat_max_health.add_modifier(modifier)
	elif "range" in desc_lower:
		stat_ranged_range.add_modifier(modifier)
	elif "attack speed" in desc_lower:
		stat_ranged_attack_speed.add_modifier(modifier)
	elif "crit" in desc_lower:
		stat_crit_chance.add_modifier(modifier)
	elif "defense" in desc_lower or "armor" in desc_lower:
		stat_defense.add_modifier(modifier)
	elif "movement" in desc_lower or "speed" in desc_lower:
		stat_movement_speed.add_modifier(modifier)

# ============================================
# EQUIPMENT SYSTEM
# ============================================

func _setup_equipment_system():
	var unique_hero_id = _generate_unique_hero_id()
	hero_id = unique_hero_id
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)
	HeroEquipmentRegistry.equipment_transaction_completed.connect(_on_equipment_transaction)
	HeroEquipmentRegistry.batch_update_completed.connect(_on_batch_update)
	_equip_starter_gear()
	_load_equipment_from_save()

func _generate_unique_hero_id() -> String:
	return "base_hero" # Override this

func _load_equipment_from_save() -> void:
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)

func _equip_starter_gear() -> void:
	pass # Override this

func _on_equipment_transaction(transaction_hero_id: String, _transaction_type: String, _details: Dictionary) -> void:
	if transaction_hero_id != hero_id: return

func _on_batch_update(dirty_hero_ids: Array[String]) -> void:
	if hero_id not in dirty_hero_ids: return
	_recalculate_all_stats()

# ============================================
# SKILL SYSTEM
# ============================================

func _setup_skill_system():
	skill_manager = HeroSkillManager.new()
	skill_manager.name = "SkillManager"
	add_child(skill_manager)
	var skills_to_load = available_skills
	
	# Load from class config if empty
	if skills_to_load.is_empty() and HeroClassDatabase:
		var class_type = _get_class_type()
		var class_config = HeroClassDatabase.get_class_config(class_type)
		if class_config and class_config.available_skill_pool.size() > 0:
			skills_to_load = class_config.available_skill_pool
			
	skill_manager.load_skill_definitions(skills_to_load)
	
	if SaveManager:
		var saved_skills = SaveManager.get_hero_skills(hero_id)
		if saved_skills:
			skill_manager.load_save_data(saved_skills)
			skill_manager.recalculate_all_passives()
			
	skill_manager.skill_activated.connect(_on_skill_activated)

func _get_class_type() -> int:
	return 0 # Override (0=Melee, 1=Ranged, etc)

func activate_skill(skill_id: String):
	print("[BaseHero] Attempting to activate skill: ", skill_id)
	
	if not skill_manager:
		print("[BaseHero] Error: SkillManager is null")
		return
		
	if not skill_manager.is_skill_unlocked(skill_id):
		print("[BaseHero] Skill not unlocked: ", skill_id)
		return
		
	if not skill_manager.can_cast(skill_id):
		print("[BaseHero] Skill on cooldown or cannot cast: ", skill_id)
		return
		
	print("[BaseHero] Activating skill: ", skill_id)
	skill_manager.activate_skill(skill_id)

func _on_skill_activated(skill_id: String):
	print("[BaseHero] Skill activated signal received: ", skill_id)
	# Override in child classes to implement specific effects

# ============================================
# SELECTION & MOVEMENT API
# ============================================

func select():
	is_selected = true
	if range_indicator:
		range_indicator.visible = true
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 1.5) # Highlight
	# Show health bar if hidden
	if health_bar:
		health_bar.visible = true

func deselect():
	is_selected = false
	if range_indicator:
		range_indicator.visible = false
	if sprite:
		sprite.modulate = Color(1, 1, 1) # Normal
	# Hide health bar if desired (optional)
	# if health_bar: health_bar.visible = false

func move_to_position(pos: Vector2):
	set_target_position(pos)
	# Play movement sound if available
	# AudioManager.play("hero_move")

# ============================================
# PROGRESSION SYSTEM
# ============================================

func _setup_progression_system():
	if not HeroProgressionManager: return
	HeroProgressionManager.register_hero(self)
	HeroProgressionManager.hero_leveled_up.connect(_on_hero_leveled_up)

func set_current_level(level: int) -> void:
	if level < 1 or level > 20: return
	current_level = level
	_recalculate_all_stats()

func get_current_level() -> int:
	return current_level

func _on_attributes_changed(changed_hero_id: String) -> void:
	if changed_hero_id != hero_id: return
	_recalculate_all_stats()

func _on_hero_leveled_up(hero: Node, new_level: int) -> void:
	if hero != self: return
	_show_level_up_notification(new_level)

func _show_level_up_notification(new_level: int):
	var notification_scene = preload("res://scenes/ui/level_up_notification.tscn")
	var popup = notification_scene.instantiate()
	popup.show_level_up(new_level)
	var screen_pos = global_position
	popup.global_position = screen_pos + Vector2(-60, -80)
	get_tree().root.add_child(popup)

func _get_level_based_modifiers() -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	if current_level <= 1: return modifiers
	var levels_gained = current_level - 1
	var health_bonus = levels_gained * 5.0
	modifiers.append(StatModifier.create_flat(health_bonus, "level", "Level Bonus: +%d Health" % int(health_bonus)))
	var damage_bonus = levels_gained * 2.0
	modifiers.append(StatModifier.create_flat(damage_bonus, "level", "Level Bonus: +%d Damage" % int(damage_bonus)))
	var attack_speed_multiplier = 1.0 + (levels_gained * 0.005)
	modifiers.append(StatModifier.create_multiplicative(attack_speed_multiplier, "level", "Level Bonus: +%.1f%% Attack Speed" % ((attack_speed_multiplier - 1.0) * 100)))
	var crit_bonus = levels_gained * 1.0
	modifiers.append(StatModifier.create_flat(crit_bonus, "level", "Level Bonus: +%d%% Crit Chance" % int(crit_bonus)))
	return modifiers

func _get_attribute_modifiers() -> Array[StatModifier]:
	var modifiers: Array[StatModifier] = []
	if not SaveManager or not SaveManager.has_current_profile(): return modifiers
	var attrs = SaveManager.get_hero_attributes(hero_id)
	if attrs.is_empty(): return modifiers
	var class_config: HeroClassConfig = null
	if HeroClassDatabase:
		class_config = HeroClassDatabase.get_class_config(_get_class_type())
	var might_scale = 1.0
	var agility_scale = 1.0
	var vitality_scale = 1.0
	var wisdom_scale = 1.0
	if class_config:
		might_scale = class_config.might_scaling
		agility_scale = class_config.agility_scaling
		vitality_scale = class_config.vitality_scaling
		wisdom_scale = class_config.wisdom_scaling

	var might_pts = attrs.get("might", 0)
	if might_pts > 0:
		var might_damage = HeroMetaManager.apply_soft_cap(might_pts, 2.0) * might_scale
		var might_health = HeroMetaManager.apply_soft_cap(might_pts, 5.0) * might_scale
		modifiers.append(StatModifier.create_flat(might_damage, "attribute:might", "MIGHT: +%.0f Damage" % might_damage))
		modifiers.append(StatModifier.create_flat(might_health, "attribute:might", "MIGHT: +%.0f Health" % might_health))

	var agility_pts = attrs.get("agility", 0)
	if agility_pts > 0:
		var agility_as_bonus = HeroMetaManager.apply_soft_cap(agility_pts, 0.005) * agility_scale
		var attack_speed_mult = 1.0 / (1.0 + agility_as_bonus)
		modifiers.append(StatModifier.create_multiplicative(attack_speed_mult, "attribute:agility", "AGILITY: +%.1f%% Attack Speed" % (agility_as_bonus * 100)))
		var agility_crit = HeroMetaManager.apply_soft_cap(agility_pts, 0.2) * agility_scale
		modifiers.append(StatModifier.create_flat(agility_crit, "attribute:agility", "AGILITY: +%.1f%% Crit" % agility_crit))

	var vitality_pts = attrs.get("vitality", 0)
	if vitality_pts > 0:
		var vitality_health = HeroMetaManager.apply_soft_cap(vitality_pts, 10.0) * vitality_scale
		modifiers.append(StatModifier.create_flat(vitality_health, "attribute:vitality", "VITALITY: +%.0f Health" % vitality_health))
		var vitality_regen = HeroMetaManager.apply_soft_cap(vitality_pts, 0.1) * vitality_scale
		_attribute_regen_bonus = vitality_regen

	var wisdom_pts = attrs.get("wisdom", 0)
	if wisdom_pts > 0:
		var wisdom_cdr = HeroMetaManager.apply_soft_cap(wisdom_pts, 0.3) * wisdom_scale
		wisdom_cdr = minf(wisdom_cdr, 40.0)
		_attribute_cdr_bonus = wisdom_cdr / 100.0

	return modifiers

# ============================================
# CLICK HANDLING
# ============================================

func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_clicked()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_on_clicked()
		get_viewport().set_input_as_handled()

func _on_clicked() -> void:
	hero_selected.emit(self)

func _on_mouse_entered() -> void:
	if not is_selected and sprite:
		sprite.modulate = Color(1.2, 1.2, 1.5)

func _on_mouse_exited() -> void:
	if not is_selected and sprite:
		sprite.modulate = Color(1, 1, 1)

# ============================================
# MAIN LOOP & STATE MACHINE
# ============================================

func _physics_process(delta):
	update_regeneration(delta)
	match current_state:
		State.IDLE: handle_idle_state()
		State.RANGED_COMBAT: handle_ranged_combat_state()
		State.MELEE_COMBAT: handle_melee_combat_state()
		State.RETURNING: handle_returning_state(delta)
		State.WALKING: handle_walking_state(delta)
	clean_enemy_lists()

func handle_idle_state():
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
	elif not enemies_in_ranged_range.is_empty():
		enter_ranged_combat()
	if global_position.distance_to(home_position) > 5:
		enter_returning_state()

func handle_ranged_combat_state():
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
		return
	if enemies_in_ranged_range.is_empty():
		enter_returning_state()
		return
	current_ranged_target = get_closest_ranged_enemy()
	if current_ranged_target and is_instance_valid(current_ranged_target):
		update_sprite_direction(current_ranged_target.global_position)

# Engagement Slot System
var current_engagement_slot: int = -1

func handle_melee_combat_state():
	current_melee_targets = get_melee_targets()

	# DEBUG: Log combat state entry
	if DebugConfig.visual_debug_enabled and not current_melee_targets.is_empty():
		if is_instance_valid(current_melee_targets[0]):
			var dist = global_position.distance_to(current_melee_targets[0].global_position)
			print("[COMBAT] Hero '%s' | Targets: %d | Distance: %.1fpx | State: MELEE_COMBAT" % [name, current_melee_targets.size(), dist])

	if current_melee_targets.is_empty():
		# No targets? Release slot and return
		combat_target = null
		if current_engagement_slot != -1:
			current_engagement_slot = -1

		for enemy in enemies_in_melee_range:
			if is_instance_valid(enemy) and enemy.has_method("unblock"):
				if enemy.is_blocked and enemy.blocking_hero == self:
					enemy.unblock()
					enemy.release_engagement_slot(self)

		if not enemies_in_ranged_range.is_empty():
			enter_ranged_combat()
		else:
			enter_returning_state()
		return

	# We have targets - fight the closest one
	var closest = current_melee_targets[0]
	if is_instance_valid(closest):
		combat_target = closest

		# KINGDOM RUSH COMBAT: Hero walks TO the enemy
		if combat_movement_enabled:
			var distance_to_enemy = global_position.distance_to(closest.global_position)

			# Leash check - don't chase beyond home range
			if global_position.distance_to(home_position) > max_distance_from_home:
				if closest.has_method("unblock"):
					closest.unblock(self)
				combat_target = null
				enter_returning_state()
				return

			# STOPPING DISTANCE: Increased to 50.0 to prevent jitter
			# (Hero Radius 25 + Enemy Radius 15 = 40 collision)
			if distance_to_enemy > COMBAT_CLOSE_DISTANCE:
				# Too far - walk closer for face-to-face combat
				var direction = (closest.global_position - global_position).normalized()
				velocity = direction * movement_speed * 0.6 # 60% speed in combat
				move_and_slide()
				update_sprite_direction(closest.global_position)
			else:
				# Close enough - stop and fight
				velocity = Vector2.ZERO
				update_sprite_direction(closest.global_position)
		else:
			# Legacy mode: stationary anchor
			velocity = Vector2.ZERO
			update_sprite_direction(closest.global_position)

func handle_returning_state(_delta):
	var distance = global_position.distance_to(home_position)
	if distance < 5:
		global_position = home_position
		enter_idle_state()
	else:
		# YOYO PREVENTION: Ignore enemies until we are closer to home
		# Only switch back to combat if we are nearly back (e.g. < 50px)
		# This stops the hero from turning around immediately after leashing.
		if distance < 50.0 and not enemies_in_melee_range.is_empty():
			enter_melee_combat()
			return
			
		var direction = (home_position - global_position).normalized()
		velocity = direction * movement_speed
		move_and_slide()
		update_sprite_direction(home_position)

func _draw():
	# DEBUG VISUALS
	if not DebugConfig.visual_debug_enabled:
		return

	var font = ThemeDB.fallback_font

	# KINGDOM RUSH COMBAT DEBUG
	if combat_target and is_instance_valid(combat_target):
		# Draw line to combat target (Yellow)
		var to_target = combat_target.global_position - global_position
		draw_line(Vector2.ZERO, to_target, Color.YELLOW, 3.0)

		# Draw combat close distance circle (Green if in range, Red if too far)
		var dist = global_position.distance_to(combat_target.global_position)
		var in_range = dist <= COMBAT_CLOSE_DISTANCE
		var color = Color.GREEN if in_range else Color.RED
		draw_circle(Vector2.ZERO, COMBAT_CLOSE_DISTANCE, Color(color, 0.3))
		draw_arc(Vector2.ZERO, COMBAT_CLOSE_DISTANCE, 0, TAU, 32, color, 2.0)

		# Draw distance text
		draw_string(font, Vector2(0, -50), "Dist: %.1fpx" % dist, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)
		draw_string(font, Vector2(0, -35), "Stop Range: %.1fpx" % COMBAT_CLOSE_DISTANCE, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)
		
		# Draw line between collision shapes (approximate)
		# Hero Radius ~25, Enemy Radius ~15
		var surface_dist = dist - 25.0 - 15.0
		draw_string(font, Vector2(0, -20), "Gap: %.1fpx" % surface_dist, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.YELLOW)

		# DEBUG: Check if we are behind the enemy
		var enemy_forward = Vector2.RIGHT
		if "velocity" in combat_target and combat_target.velocity.length() > 1.0:
			enemy_forward = combat_target.velocity.normalized()
		
		var to_hero = global_position - combat_target.global_position
		if to_hero.dot(enemy_forward) < -0.1:
			draw_string(font, Vector2(0, -80), "⚠️ BEHIND ENEMY", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.RED)

		# DEBUG: Check for Dragging (Enemy moving while we chase)
		if "velocity" in combat_target and combat_target.velocity.length() > 1.0:
			draw_string(font, Vector2(0, -95), "⚠️ DRAGGING", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.ORANGE)

	# Draw Leash Line (Home -> Hero)
	if max_distance_from_home > 0:
		var dist_home = global_position.distance_to(home_position)
		var leash_color = Color.GREEN if dist_home < max_distance_from_home else Color.RED
		draw_line(Vector2.ZERO, home_position - global_position, Color(leash_color, 0.3), 1.0)
		if dist_home > max_distance_from_home * 0.8:
			draw_string(font, Vector2(0, 20), "Leash: %.0f/%.0f" % [dist_home, max_distance_from_home], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, leash_color)

	# Draw state info

	# Draw state info
	var state_text = State.keys()[current_state]
	draw_string(font, Vector2(0, -20), "State: %s" % state_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.CYAN)

	# Draw velocity info
	var is_moving = velocity.length() > 1.0
	draw_string(font, Vector2(0, -5), "Moving: %s" % ("YES" if is_moving else "NO"), HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.YELLOW)

	# Draw Engagement Slots (Simplified - just show blocked count)
	var blocked_count = 0
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and enemy.is_blocked and enemy.blocking_hero == self:
			blocked_count += 1
			# Draw line to blocked enemy
			draw_line(Vector2.ZERO, enemy.global_position - global_position, Color.RED, 2.0)
			
	draw_string(font, Vector2(0, -65), "Blocked: %d/%d" % [blocked_count, block_capacity], HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

	# Draw line to blocked enemies (Melee Range)
	draw_circle(Vector2.ZERO, melee_range, Color(1, 1, 1, 0.1)) # Range ring

func handle_walking_state(_delta):
	var distance = global_position.distance_to(target_position)
	if distance < 5:
		home_position = target_position
		enter_idle_state()
	else:
		var direction = (target_position - global_position).normalized()
		velocity = direction * movement_speed
		move_and_slide()
		update_sprite_direction(target_position)

# ============================================
# COMBAT HELPERS
# ============================================

func enter_idle_state():
	current_state = State.IDLE
	velocity = Vector2.ZERO
	if ranged_timer: ranged_timer.stop()
	if melee_timer: melee_timer.stop()

func enter_ranged_combat():
	current_state = State.RANGED_COMBAT
	if ranged_timer: ranged_timer.start()

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	if melee_timer: melee_timer.start()

func enter_returning_state():
	current_state = State.RETURNING
	if ranged_timer: ranged_timer.stop()
	if melee_timer: melee_timer.stop()

func set_target_position(pos: Vector2):
	target_position = pos
	current_state = State.WALKING

func get_closest_ranged_enemy():
	var closest_enemy = null
	var min_dist = INF
	for enemy in enemies_in_ranged_range:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = enemy
	return closest_enemy

# ============================================
# HERO ENGAGEMENT SLOTS (Enemies surrounding Hero)
# ============================================

# ============================================
# HERO ENGAGEMENT (Simplified for Kingdom Rush Style)
# ============================================

# We no longer use specific slots.
# We just track how many enemies are blocked to enforce capacity.
# The enemies themselves handle positioning (they stop at contact).

func request_hero_engagement_slot(enemy: Node2D) -> int:
	"""Legacy compatibility: Returns 0 if capacity allows, -1 if full"""
	# Check if we are already blocking this enemy (re-request)
	if enemies_in_melee_range.has(enemy) and enemy.is_blocked and enemy.blocking_hero == self:
		return 0
		
	# Check capacity
	var current_blocked_count = 0
	for e in enemies_in_melee_range:
		if is_instance_valid(e) and e.is_blocked and e.blocking_hero == self:
			current_blocked_count += e.weight if "weight" in e else 1
			
	if current_blocked_count < block_capacity:
		return 0 # Granted
	return -1 # Denied

func release_hero_engagement_slot(_enemy: Node2D):
	"""Legacy compatibility: No-op"""
	pass

func get_hero_slot_position(_slot_index: int) -> Vector2:
	"""Legacy compatibility: Returns hero position (center)"""
	return global_position

func get_melee_targets():
	var targets = []
	var current_weight = 0
	
	for enemy in enemies_in_melee_range:
		if not is_instance_valid(enemy): continue
		
		# If already blocking this enemy, keep it
		if enemy.is_blocked and enemy.blocking_hero == self:
			targets.append(enemy)
			current_weight += enemy.weight
			continue
			
		# If we have capacity, block new enemy
		if current_weight + enemy.weight <= block_capacity and not enemy.is_blocked:
			# DISTANCE CHECK: Don't block immediately at detection edge (100px).
			# Let them walk closer so the fight feels "tight".
			# Block only if they are within Combat Distance + small buffer (e.g. 45px).
			var dist_to_enemy = global_position.distance_to(enemy.global_position)
			if dist_to_enemy > COMBAT_CLOSE_DISTANCE + 5.0:
				# Too far to block yet. Let them come closer.
				# We still add them to targets so we can attack them if they are in range,
				# but we don't call enemy.block() yet.
				targets.append(enemy)
				continue

			enemy.block(self)
			targets.append(enemy)
			current_weight += enemy.weight
			
	return targets

func clean_enemy_lists():
	enemies_in_melee_range = enemies_in_melee_range.filter(func(e): return is_instance_valid(e))
	enemies_in_ranged_range = enemies_in_ranged_range.filter(func(e): return is_instance_valid(e))

func _on_ranged_enemy_entered(body):
	if body.is_in_group("enemies") and not enemies_in_ranged_range.has(body):
		enemies_in_ranged_range.append(body)

func _on_ranged_enemy_exited(body):
	if enemies_in_ranged_range.has(body):
		enemies_in_ranged_range.erase(body)

func _on_melee_enemy_entered(body):
	if body.is_in_group("enemies") and not enemies_in_melee_range.has(body):
		enemies_in_melee_range.append(body)

func _on_melee_enemy_exited(body):
	if enemies_in_melee_range.has(body):
		enemies_in_melee_range.erase(body)
		if body.has_method("unblock") and body.is_blocked and body.blocking_hero == self:
			body.unblock(self)

func _on_ranged_timer_timeout():
	if current_state != State.RANGED_COMBAT: return
	var target = get_closest_ranged_enemy()
	if target:
		perform_ranged_attack(target)

func _on_melee_timer_timeout():
	# DEBUG: Log timer trigger
	if DebugConfig.visual_debug_enabled:
		if current_state != State.MELEE_COMBAT:
			print("[ATTACK] Timer fired but NOT in MELEE_COMBAT state (current: %s)" % State.keys()[current_state])
			return
		if current_melee_targets.is_empty():
			print("[ATTACK] Timer fired but NO TARGETS available")
			return
		print("[ATTACK] Timer fired! Attempting attack on %d target(s)" % current_melee_targets.size())
	else:
		if current_state != State.MELEE_COMBAT: return
		if current_melee_targets.is_empty(): return

	# Single Target Attack: Only hit the first valid target
	for target in current_melee_targets:
		if is_instance_valid(target):
			perform_melee_attack(target)
			break # Stop after hitting one enemy

func perform_ranged_attack(_target):
	# Override in child class
	pass

func perform_melee_attack(target) -> bool:
	# Override in child class
	if target.has_method("take_damage"):
		# DEAD CHECK: Don't hit dead enemies (even if instance is valid this frame)
		if "current_health" in target and target.current_health <= 0:
			if DebugConfig.visual_debug_enabled:
				print("[ATTACK] ❌ Skipped - Target '%s' is already dead" % target.name)
			return false

		# RANGE CHECK: Don't hit if they are still walking to the slot
		var distance_to_target = global_position.distance_to(target.global_position)
		# Allow a buffer over the stopping distance (50 + 25 = 75px)
		var max_attack_range = COMBAT_CLOSE_DISTANCE + 25.0
		if distance_to_target > max_attack_range:
			if DebugConfig.visual_debug_enabled:
				print("[ATTACK] ❌ Skipped - Target '%s' too far (%.1fpx > %.1fpx)" % [target.name, distance_to_target, max_attack_range])
			return false

		if DebugConfig.visual_debug_enabled:
			print("[ATTACK] ✅ HITTING '%s' for %.1f damage (distance: %.1fpx)" % [target.name, melee_damage, distance_to_target])
		else:
			print("[BaseHero] Attacking %s for %.1f damage" % [target.name, melee_damage])
		target.take_damage(melee_damage, self, "hero_melee")
		return true
	return false

# ============================================
# VISUAL HELPERS
# ============================================

func update_sprite_direction(look_at_pos: Vector2):
	var direction_to_target = look_at_pos - global_position
	
	if visuals_node:
		if direction_to_target.x < 0:
			visuals_node.scale.x = -1 * abs(visuals_node.scale.x)
		else:
			visuals_node.scale.x = 1 * abs(visuals_node.scale.x)
	elif sprite:
		var should_flip = direction_to_target.x < 0
		sprite.flip_h = should_flip
		if projectile_spawn_node:
			var current_x = abs(projectile_spawn_node.position.x)
			projectile_spawn_node.position.x = current_x * (-1 if should_flip else 1)

func draw_range_circle():
	if range_indicator and range_indicator is Polygon2D:
		var points = PackedVector2Array()
		var radius = ranged_range
		if radius <= 0: radius = melee_range # Fallback for melee heroes
		
		var segments = 32
		for i in range(segments + 1):
			var angle = (i / float(segments)) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		range_indicator.polygon = points

func update_health_bar():
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)

func _flash_hero(color: Color):
	if sprite:
		var original_color = sprite.modulate
		sprite.modulate = color
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = original_color


# ============================================
# REGENERATION
# ============================================

func update_regeneration(delta):
	if current_health < max_health:
		time_since_last_damage += delta
		if time_since_last_damage >= regen_delay:
			is_regenerating = true
			var heal_amount = (regen_rate + _attribute_regen_bonus) * delta
			heal(heal_amount)
		else:
			is_regenerating = false
	else:
		is_regenerating = false

func get_hero_id() -> String:
	return hero_id

func _on_tower_entered_aura(body):
	if body.is_in_group("towers") and not towers_in_aura.has(body):
		towers_in_aura.append(body)
		if body.has_method("apply_hero_buff"):
			body.apply_hero_buff(self)

func _on_tower_exited_aura(body):
	if towers_in_aura.has(body):
		towers_in_aura.erase(body)
		if body.has_method("remove_hero_buff"):
			body.remove_hero_buff(self)

func take_damage(amount):
	var damage_taken = max(0, amount - defense)
	current_health -= damage_taken
	time_since_last_damage = 0.0
	is_regenerating = false
	update_health_bar()
	
	# Visual feedback
	_flash_hero(Color(1.5, 0.5, 0.5)) # Red flash for damage

	
	if current_health <= 0:
		die()

func heal(amount):
	current_health = min(current_health + amount, max_health)
	update_health_bar()

func die():
	hero_died.emit(10.0)
	queue_free()
