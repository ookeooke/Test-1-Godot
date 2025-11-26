extends CharacterBody2D

# ============================================
# RANGER HERO - Now using ClickManager!
# ============================================

signal hero_died(respawn_time)
signal hero_selected(hero)

# STATES
enum State {IDLE, RANGED_COMBAT, MELEE_COMBAT, RETURNING, WALKING}
var current_state = State.IDLE
var hero_id: String

# COMBAT CONFIGURATION
const USE_COMBAT_ANCHOR = true # Set to false to revert to old movement behavior

# CLASS TYPE (for attribute scaling)
const CLASS_TYPE_RANGED: int = 1 # Matches HeroClassConfig.class_type

# STATS - NEW UNIFIED SYSTEM
var hero_level = 1 # Legacy - use current_level instead
var current_level: int = 1 # In-mission level (1-20, managed by HeroProgressionManager)

# Core stats using new Stat system (with modifiers from equipment/skills)
var stat_max_health: Stat
var stat_ranged_damage: Stat
var stat_melee_damage: Stat
var stat_ranged_range: Stat
var stat_ranged_attack_speed: Stat
var stat_movement_speed: Stat
var stat_crit_chance: Stat
var stat_defense: Stat

# Current health (not a Stat, just a runtime value)
var current_health = BASE_MAX_HEALTH # Will be properly set after stat initialization

# Base stats (for reference and reset)
const BASE_MAX_HEALTH = 300.0
const BASE_RANGED_DAMAGE = 0.0
const BASE_MELEE_DAMAGE = 0.0
const BASE_RANGED_RANGE = 240.0
const BASE_RANGED_ATTACK_SPEED = 0.55
const BASE_MOVEMENT_SPEED = 150.0

# Fixed stats (not affected by modifiers)
var melee_range = 100.0
var melee_attack_speed = 0.8
var combat_distance = 50.0

# MOVEMENT
var max_distance_from_home = 50.0
var home_position = Vector2.ZERO
var target_position = Vector2.ZERO

# Convenience properties for backward compatibility
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
var block_capacity = 2 # CAPACITY SYSTEM: Can hold 2 "weight" of enemies
var current_load = 0 # Current weight being held
var enemies_in_melee_range = []
var enemies_in_ranged_range = []
var current_ranged_target = null
var current_melee_targets = []

# TIMERS
var ranged_timer: Timer
var melee_timer: Timer

# REGENERATION SYSTEM (Kingdom Rush style - heroes)
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
@onready var ranged_detection = $RangedDetection
@onready var melee_detection = $MeleeDetection
@onready var range_indicator = $RangeIndicator
@onready var health_bar = $HealthBar
@onready var xp_bar = $XPBar
@onready var sprite = $Sprite2D

# TOWER BUFF SYSTEM
var tower_aura: Area2D = null
var towers_in_aura = []
const AURA_RADIUS = 200.0

# PROJECTILE
@export var arrow_scene: PackedScene

# VISUAL
@export var hero_texture: Texture2D

# SKILL SYSTEM
@export var available_skills: Array[HeroSkillData] = []
var skill_manager: SkillManager = null

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("\n🎯 === RANGER HERO INITIALIZATION START ===")
	_initialize_stats()
	_setup_equipment_system()
	_setup_skill_system()
	_setup_progression_system()

	if SaveManager:
		SaveManager.hero_attributes_changed.connect(_on_attributes_changed)

	if xp_bar:
		xp_bar.setup(self)

	_recalculate_all_stats()
	current_health = max_health

	set_meta("hero_id", hero_id)
	set_meta("hero_name", "Ranger")
	set_meta("hero_class", "ranger")

	collision_layer = 2
	collision_mask = 0

	ranged_detection.collision_layer = 0
	ranged_detection.collision_mask = 1
	melee_detection.collision_layer = 0
	melee_detection.collision_mask = 1

	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	ranged_detection.body_entered.connect(_on_ranged_enemy_entered)
	ranged_detection.body_exited.connect(_on_ranged_enemy_exited)
	melee_detection.body_entered.connect(_on_melee_enemy_entered)
	melee_detection.body_exited.connect(_on_melee_enemy_exited)

	if has_node("TowerAura"):
		tower_aura = $TowerAura
		tower_aura.collision_layer = 0
		tower_aura.collision_mask = 8
		tower_aura.body_entered.connect(_on_tower_entered_aura)
		tower_aura.body_exited.connect(_on_tower_exited_aura)

	ranged_timer = Timer.new()
	ranged_timer.wait_time = ranged_attack_speed
	ranged_timer.timeout.connect(_on_ranged_timer_timeout)
	add_child(ranged_timer)

	melee_timer = Timer.new()
	melee_timer.wait_time = melee_attack_speed
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)

	draw_range_circle()
	range_indicator.visible = false
	update_health_bar()

	if sprite is Sprite2D:
		if hero_texture:
			sprite.texture = hero_texture
			if sprite.has_node("FallbackRect"):
				sprite.get_node("FallbackRect").visible = false
		else:
			if sprite.has_node("FallbackRect"):
				sprite.get_node("FallbackRect").visible = true

	if BalanceTracker:
		BalanceTracker.register_hero(self, get_hero_id())

# ============================================
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
	if "damage" in desc_lower and "melee" not in desc_lower:
		stat_ranged_damage.add_modifier(modifier)
	elif "melee" in desc_lower and "damage" in desc_lower:
		stat_melee_damage.add_modifier(modifier)
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
# EQUIPMENT SYSTEM SETUP
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
	return "ranger"

func _load_equipment_from_save() -> void:
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)

func _equip_starter_gear() -> void:
	var equipped_weapon = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_left")
	if equipped_weapon == null:
		var hero_container = InventoryRegistry.get_container(hero_id)
		if hero_container:
			var all_items = hero_container.get_all_items()
			var found_weapon: ItemInstance = null
			for item in all_items:
				if item.item_id == "basic_bow":
					found_weapon = item
					break
			if found_weapon == null:
				var uuid = HeroInventoryManager.add_item_instance_to_hero(hero_id, "basic_bow", 0)
				if uuid != "":
					found_weapon = hero_container._items.get(uuid)
			if found_weapon:
				ItemTransactionService.equip_item(hero_id, found_weapon.uuid, "hand_left")

func _on_equipment_transaction(transaction_hero_id: String, transaction_type: String, details: Dictionary) -> void:
	if transaction_hero_id != hero_id: return

func _on_batch_update(dirty_hero_ids: Array[String]) -> void:
	if hero_id not in dirty_hero_ids: return
	_recalculate_all_stats()

# ============================================
# SKILL SYSTEM SETUP
# ============================================

func _setup_skill_system():
	skill_manager = SkillManager.new()
	skill_manager.name = "SkillManager"
	add_child(skill_manager)
	var skills_to_load = available_skills
	if skills_to_load.is_empty() and HeroClassDatabase:
		var class_config = HeroClassDatabase.get_class_config(CLASS_TYPE_RANGED)
		if class_config and class_config.available_skill_pool.size() > 0:
			skills_to_load = class_config.available_skill_pool
	skill_manager.load_skill_definitions(skills_to_load)
	if SaveManager:
		var saved_skills = SaveManager.get_hero_skills(hero_id)
		if saved_skills:
			skill_manager.load_save_data(saved_skills)
			skill_manager.recalculate_all_passives()
	skill_manager.skill_activated.connect(_on_skill_activated)
	if not skill_manager.is_skill_owned("ranger_eagle_eye"):
		var eagle_eye_data = skill_manager.get_skill_data("ranger_eagle_eye")
		if eagle_eye_data:
			skill_manager.unlock_skill("ranger_eagle_eye", eagle_eye_data)

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
	hero_level = level
	_recalculate_all_stats()

func get_current_level() -> int:
	return current_level

func get_available_skills() -> Array:
	return available_skills

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
		class_config = HeroClassDatabase.get_class_config(CLASS_TYPE_RANGED)
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
		var might_damage = SaveManager.apply_soft_cap(might_pts, 2.0) * might_scale
		var might_health = SaveManager.apply_soft_cap(might_pts, 5.0) * might_scale
		modifiers.append(StatModifier.create_flat(might_damage, "attribute:might", "MIGHT: +%.0f Damage" % might_damage))
		modifiers.append(StatModifier.create_flat(might_health, "attribute:might", "MIGHT: +%.0f Health" % might_health))

	var agility_pts = attrs.get("agility", 0)
	if agility_pts > 0:
		var agility_as_bonus = SaveManager.apply_soft_cap(agility_pts, 0.005) * agility_scale
		var attack_speed_mult = 1.0 / (1.0 + agility_as_bonus)
		modifiers.append(StatModifier.create_multiplicative(attack_speed_mult, "attribute:agility", "AGILITY: +%.1f%% Attack Speed" % (agility_as_bonus * 100)))
		var agility_crit = SaveManager.apply_soft_cap(agility_pts, 0.2) * agility_scale
		modifiers.append(StatModifier.create_flat(agility_crit, "attribute:agility", "AGILITY: +%.1f%% Crit" % agility_crit))

	var vitality_pts = attrs.get("vitality", 0)
	if vitality_pts > 0:
		var vitality_health = SaveManager.apply_soft_cap(vitality_pts, 10.0) * vitality_scale
		modifiers.append(StatModifier.create_flat(vitality_health, "attribute:vitality", "VITALITY: +%.0f Health" % vitality_health))
		var vitality_regen = SaveManager.apply_soft_cap(vitality_pts, 0.1) * vitality_scale
		_attribute_regen_bonus = vitality_regen

	var wisdom_pts = attrs.get("wisdom", 0)
	if wisdom_pts > 0:
		var wisdom_cdr = SaveManager.apply_soft_cap(wisdom_pts, 0.3) * wisdom_scale
		wisdom_cdr = minf(wisdom_cdr, 40.0)
		_attribute_cdr_bonus = wisdom_cdr / 100.0

	return modifiers

func _on_skill_activated(skill_id: String):
	match skill_id:
		"ranger_multishot": _execute_multishot()
		"ranger_rapid_fire": _execute_rapid_fire()
		"ranger_poison_arrow": _execute_poison_arrow()
		"ranger_sniper_shot": _execute_sniper_shot()
		"ranger_smoke_bomb": _execute_smoke_bomb()
		"ranger_rally_call": _execute_rally_call()
		_: push_warning("Unknown skill activated: ", skill_id)

func _get_skill_attribute_scaling() -> Dictionary:
	if not SaveManager or not SaveManager.has_current_profile():
		return {"might": 0, "agility": 0, "vitality": 0, "wisdom": 0}
	return SaveManager.get_hero_attributes(hero_id)

func _execute_multishot():
	if arrow_scene == null:
		push_error("Cannot execute multishot: arrow_scene is null")
		return

	if enemies_in_ranged_range.is_empty():
		return

	var skill_level = skill_manager.get_skill_level("ranger_multishot")
	var skill_data = skill_manager.get_skill_data("ranger_multishot")
	var base_arrows = [5, 6, 7, 8, 10]
	var arrow_count = base_arrows[clampi(skill_level - 1, 0, base_arrows.size() - 1)]
	var attrs = _get_skill_attribute_scaling()
	var might_bonus_arrows = floori(attrs.get("might", 0) / 25.0)
	arrow_count += might_bonus_arrows
	var damage_multiplier = 0.6
	if skill_data:
		damage_multiplier = skill_data.get_current_damage_multiplier(skill_level)
	var agility_bonus = (attrs.get("agility", 0) / 15.0) * 0.10
	damage_multiplier *= (1.0 + agility_bonus)
	var wisdom_bonus = attrs.get("wisdom", 0) * 0.01
	damage_multiplier *= (1.0 + wisdom_bonus)

	var targets = enemies_in_ranged_range.duplicate()
	targets.shuffle()
	targets = targets.slice(0, min(arrow_count, targets.size()))

	for target in targets:
		if not is_instance_valid(target): continue
		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		arrow.global_position = global_position
		var damage = ranged_damage * damage_multiplier
		arrow.setup(target, damage, self)
	_flash_hero(Color(1.5, 1.3, 1.0))

func _execute_rapid_fire():
	if arrow_scene == null:
		push_error("Cannot execute rapid_fire: arrow_scene is null")
		return
	var target = get_closest_ranged_enemy()
	if target == null or not is_instance_valid(target): return
	var skill_level = skill_manager.get_skill_level("ranger_rapid_fire")
	var skill_data = skill_manager.get_skill_data("ranger_rapid_fire")
	var base_arrows = [5, 6, 7, 8, 10]
	var arrow_count = base_arrows[clampi(skill_level - 1, 0, base_arrows.size() - 1)]
	var attrs = _get_skill_attribute_scaling()
	var agility_bonus_arrows = floori(attrs.get("agility", 0) / 20.0)
	arrow_count += agility_bonus_arrows
	var damage_multiplier = 0.8
	if skill_data:
		damage_multiplier = skill_data.get_current_damage_multiplier(skill_level)
	var might_bonus = (attrs.get("might", 0) / 10.0) * 0.05
	damage_multiplier *= (1.0 + might_bonus)
	var wisdom_bonus = attrs.get("wisdom", 0) * 0.01
	damage_multiplier *= (1.0 + wisdom_bonus)
	var stack_bonus = [0.05, 0.07, 0.10, 0.12, 0.15]
	var stack_mult = stack_bonus[clampi(skill_level - 1, 0, stack_bonus.size() - 1)]

	for i in arrow_count:
		if not is_instance_valid(target): break
		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		arrow.global_position = global_position
		var current_stack = 1.0 + (stack_mult * i)
		var damage = ranged_damage * damage_multiplier * current_stack
		arrow.setup(target, damage, self)
		await get_tree().create_timer(0.08).timeout
	_flash_hero(Color(1.0, 1.5, 1.0))

func _execute_poison_arrow():
	if arrow_scene == null:
		push_error("Cannot execute poison_arrow: arrow_scene is null")
		return
	var target = get_closest_ranged_enemy()
	if target == null or not is_instance_valid(target): return
	var skill_level = skill_manager.get_skill_level("ranger_poison_arrow")
	var skill_data = skill_manager.get_skill_data("ranger_poison_arrow")
	var damage_multiplier = 1.5
	var base_duration = 4.0
	if skill_data:
		damage_multiplier = skill_data.get_current_damage_multiplier(skill_level)
		base_duration = skill_data.get_current_duration(skill_level)
	var attrs = _get_skill_attribute_scaling()
	var might_bonus = (attrs.get("might", 0) / 10.0) * 0.10
	damage_multiplier *= (1.0 + might_bonus)
	var wisdom_duration_bonus = floorf(attrs.get("wisdom", 0) / 15.0)
	var total_duration = base_duration + wisdom_duration_bonus
	var wisdom_bonus = attrs.get("wisdom", 0) * 0.01
	damage_multiplier *= (1.0 + wisdom_bonus)

	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	arrow.global_position = global_position
	var damage = ranged_damage * damage_multiplier
	arrow.setup(target, damage, self)

	if target.has_method("apply_poison"):
		var dot_damage = [20, 30, 40, 50, 60][clampi(skill_level - 1, 0, 4)]
		var slow_percent = [0.20, 0.25, 0.30, 0.35, 0.40][clampi(skill_level - 1, 0, 4)]
		var vitality_slow_bonus = (attrs.get("vitality", 0) / 20.0) * 0.05
		slow_percent += vitality_slow_bonus
		slow_percent = minf(slow_percent, 0.60)
		target.apply_poison(dot_damage, total_duration, slow_percent)
	elif target.has_method("apply_slow"):
		var slow_percent = [0.20, 0.25, 0.30, 0.35, 0.40][clampi(skill_level - 1, 0, 4)]
		target.apply_slow(slow_percent, total_duration)
	_flash_hero(Color(0.5, 1.5, 0.5))

func _execute_sniper_shot():
	if arrow_scene == null:
		push_error("Cannot execute sniper_shot: arrow_scene is null")
		return
	var target = get_closest_ranged_enemy()
	if target == null or not is_instance_valid(target): return
	var skill_level = skill_manager.get_skill_level("ranger_sniper_shot")
	var attrs = _get_skill_attribute_scaling()
	var max_damage_mult = [5.0, 6.0, 7.5, 9.0, 12.0][clampi(skill_level - 1, 0, 4)]
	var might_bonus = (attrs.get("might", 0) / 15.0) * 0.50
	max_damage_mult *= (1.0 + might_bonus)
	var wisdom_bonus = attrs.get("wisdom", 0) * 0.01
	max_damage_mult *= (1.0 + wisdom_bonus)
	var execute_threshold = [0.10, 0.12, 0.15, 0.18, 0.20][clampi(skill_level - 1, 0, 4)]
	var wisdom_execute_bonus = (attrs.get("wisdom", 0) / 20.0) * 0.02
	execute_threshold += wisdom_execute_bonus
	execute_threshold = minf(execute_threshold, 0.30)

	var is_execute = false
	if target.has("current_health") and target.has("max_health"):
		var health_percent = target.current_health / target.max_health
		if health_percent <= execute_threshold:
			is_execute = true

	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	arrow.global_position = global_position
	var damage = ranged_damage * max_damage_mult
	if is_execute and not target.is_in_group("boss"):
		damage = 99999
	elif is_execute and target.is_in_group("boss"):
		damage *= 3.0
	arrow.setup(target, damage, self)
	_flash_hero(Color(1.5, 1.0, 1.5))

func _execute_smoke_bomb():
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and enemy.has_method("unblock"):
			if enemy.is_blocked and enemy.blocking_hero == self:
				enemy.unblock()
	current_melee_targets.clear()
	_flash_hero(Color(0.7, 0.7, 0.7, 0.5))

func _execute_rally_call():
	_flash_hero(Color(1.3, 1.5, 1.0))

func _flash_hero(color: Color):
	var original_color = sprite.modulate
	sprite.modulate = color
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = original_color

func get_hero_id() -> String:
	return hero_id

func get_hero_class() -> String:
	return "ranger"

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
	if not is_selected:
		sprite.modulate = Color(1.2, 1.2, 1.5)

func _on_mouse_exited() -> void:
	if not is_selected:
		sprite.modulate = Color(1, 1, 1)

# ============================================
# MAIN LOOP
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

# ============================================
# VISUAL
# ============================================

func update_sprite_direction(target_position: Vector2):
	if not sprite: return
	var direction_to_target = target_position - global_position
	sprite.flip_h = direction_to_target.x < 0

# ============================================
# STATE HANDLERS
# ============================================

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

func handle_melee_combat_state():
	current_melee_targets = get_melee_targets()

	if current_melee_targets.is_empty():
		for enemy in enemies_in_melee_range:
			if is_instance_valid(enemy) and enemy.has_method("unblock"):
				if enemy.is_blocked and enemy.blocking_hero == self:
					enemy.unblock()
		if not enemies_in_ranged_range.is_empty():
			enter_ranged_combat()
		else:
			enter_returning_state()
		return

	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and not current_melee_targets.has(enemy):
			if enemy.has_method("unblock") and enemy.is_blocked and enemy.blocking_hero == self:
				enemy.unblock()

	var closest = current_melee_targets[0]
	if is_instance_valid(closest):
		if USE_COMBAT_ANCHOR:
			var anchor_pos = closest.get_combat_anchor_position(20.0)
			var distance_to_anchor = global_position.distance_to(anchor_pos)
			if distance_to_anchor > 5.0:
				var direction = (anchor_pos - global_position).normalized()
				velocity = direction * movement_speed * 1.2
				move_and_slide()
			else:
				velocity = Vector2.ZERO
				var target_y = closest.global_position.y
				var y_diff = target_y - global_position.y
				if abs(y_diff) > 1.0:
					global_position.y = lerp(global_position.y, target_y, 0.2)
		else:
			var distance_to_enemy = global_position.distance_to(closest.global_position)
			if distance_to_enemy > combat_distance:
				var direction = (closest.global_position - global_position).normalized()
				velocity = direction * movement_speed
				move_and_slide()
			else:
				velocity = Vector2.ZERO

		if current_melee_targets.size() > 1:
			var center = (current_melee_targets[0].global_position + current_melee_targets[1].global_position) / 2
			update_sprite_direction(center)
		else:
			update_sprite_direction(closest.global_position)

		for enemy in current_melee_targets:
			if enemy.has_method("set_blocked_by_hero"):
				if not enemy.is_blocked or enemy.blocking_hero != self:
					enemy.set_blocked_by_hero(self)

func handle_returning_state(delta):
	var direction = (home_position - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()
	if global_position.distance_to(home_position) < 5:
		velocity = Vector2.ZERO
		current_state = State.IDLE
		if BalanceTracker: BalanceTracker.record_hero_state_change(self, "idle")
	if not enemies_in_melee_range.is_empty():
		enter_melee_combat()
	elif not enemies_in_ranged_range.is_empty():
		enter_ranged_combat()

func handle_walking_state(delta):
	var direction = (target_position - global_position).normalized()
	velocity = direction * movement_speed
	move_and_slide()
	if global_position.distance_to(target_position) < 5:
		velocity = Vector2.ZERO
		home_position = global_position
		current_state = State.IDLE
		if BalanceTracker: BalanceTracker.record_hero_state_change(self, "idle")

# ============================================
# STATE TRANSITIONS
# ============================================

func enter_ranged_combat():
	current_state = State.RANGED_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.start()
	if BalanceTracker: BalanceTracker.record_hero_state_change(self, "ranged_combat")

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.stop()
	melee_timer.start()
	_set_combat_state_visual(true)
	if BalanceTracker: BalanceTracker.record_hero_state_change(self, "melee_combat")

func enter_returning_state():
	current_state = State.RETURNING
	ranged_timer.stop()
	melee_timer.stop()
	_set_combat_state_visual(false)
	if BalanceTracker: BalanceTracker.record_hero_state_change(self, "returning")

func enter_walking_state(destination: Vector2):
	current_state = State.WALKING
	target_position = destination
	ranged_timer.stop()
	melee_timer.stop()
	if BalanceTracker: BalanceTracker.record_hero_state_change(self, "walking")

# ============================================
# ENEMY DETECTION
# ============================================

func _on_ranged_enemy_entered(body):
	if body.is_in_group("enemy"): enemies_in_ranged_range.append(body)

func _on_ranged_enemy_exited(body):
	if body.is_in_group("enemy"): enemies_in_ranged_range.erase(body)

func _on_melee_enemy_entered(body):
	if body.is_in_group("enemy"): enemies_in_melee_range.append(body)

func _on_melee_enemy_exited(body):
	if body.is_in_group("enemy"): enemies_in_melee_range.erase(body)

func clean_enemy_lists():
	enemies_in_ranged_range = enemies_in_ranged_range.filter(func(e): return is_instance_valid(e))
	enemies_in_melee_range = enemies_in_melee_range.filter(func(e): return is_instance_valid(e))

func get_closest_ranged_enemy():
	if enemies_in_ranged_range.is_empty(): return null
	if current_ranged_target and is_instance_valid(current_ranged_target):
		if enemies_in_ranged_range.has(current_ranged_target):
			if not enemies_in_melee_range.has(current_ranged_target):
				return current_ranged_target
	var closest = enemies_in_ranged_range[0]
	var closest_dist = global_position.distance_to(closest.global_position)
	for enemy in enemies_in_ranged_range:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	return closest

func get_melee_targets() -> Array:
	var final_targets = []
	var load = 0

	# STEP 1: Keep existing targets (Sticky)
	# Iterate through what we were already fighting
	for enemy in current_melee_targets:
		# Check if they are still valid and in range
		if is_instance_valid(enemy) and enemies_in_melee_range.has(enemy):
			var enemy_weight = 1
			if "weight" in enemy: enemy_weight = enemy.weight
			
			# If they still fit (should always be true unless weight changed), keep them
			if load + enemy_weight <= block_capacity:
				final_targets.append(enemy)
				load += enemy_weight

	# STEP 2: Fill remaining capacity (Greedy)
	if load < block_capacity:
		# Find potential new targets (enemies in range but NOT in final_targets)
		var candidates = []
		var engagement_distance = 50.0 # Enemies must be this close to be engaged
		
		for enemy in enemies_in_melee_range:
			if not final_targets.has(enemy):
				# Only engage if they are close enough (allows stacking)
				if global_position.distance_to(enemy.global_position) <= engagement_distance:
					candidates.append(enemy)

		# Sort candidates by distance (closest first)
		candidates.sort_custom(func(a, b):
			return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
		)

		# Fill the gaps
		for enemy in candidates:
			if not is_instance_valid(enemy): continue
			var enemy_weight = 1
			if "weight" in enemy: enemy_weight = enemy.weight
			
			if load + enemy_weight <= block_capacity:
				final_targets.append(enemy)
				load += enemy_weight
	
	current_load = load
	return final_targets

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	_cleanup_all_tower_buffs()

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	current_health -= amount
	time_since_last_damage = 0.0
	if is_regenerating:
		is_regenerating = false
		show_regen_visual(false)
	update_health_bar()
	if current_health <= 0:
		die()

func die():
	_cleanup_all_tower_buffs()
	if BalanceTracker: BalanceTracker.record_hero_death(self)
	var respawn_time = 10.0 + (hero_level - 1) * 5.0
	hero_died.emit(respawn_time)
	queue_free()

func update_health_bar():
	if health_bar:
		if health_bar.has_method("update_health"):
			health_bar.update_health(current_health, max_health)
		else:
			health_bar.value = (current_health / max_health) * 100

# ============================================
# SELECTION & VISUALS
# ============================================

func select():
	is_selected = true
	range_indicator.visible = true
	sprite.modulate = Color(1.3, 1.3, 1.5)

func deselect():
	is_selected = false
	range_indicator.visible = false
	sprite.modulate = Color(1, 1, 1)

func draw_range_circle():
	var points = []
	var num_points = 64
	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU
		var x = cos(angle) * ranged_range
		var y = sin(angle) * ranged_range
		points.append(Vector2(x, y))
	range_indicator.polygon = PackedVector2Array(points)
	range_indicator.color = Color(0.3, 0.5, 1.0, 0.3)

# ============================================
# REGENERATION SYSTEM
# ============================================

func update_regeneration(delta):
	time_since_last_damage += delta
	if current_health < max_health:
		if time_since_last_damage >= regen_delay:
			if not is_regenerating:
				is_regenerating = true
				show_regen_visual(true)
			var total_regen = regen_rate + _attribute_regen_bonus
			current_health += total_regen * delta
			if current_health > max_health:
				current_health = max_health
				is_regenerating = false
				show_regen_visual(false)
			update_health_bar()
	else:
		if is_regenerating:
			is_regenerating = false
			show_regen_visual(false)

func show_regen_visual(enabled: bool):
	if health_bar and health_bar.has_method("show_regeneration"):
		health_bar.show_regeneration(enabled)

# ============================================
# HELPER FUNCTIONS
# ============================================

func set_home_position(pos: Vector2):
	home_position = pos
	global_position = pos

func move_to_position(pos: Vector2):
	enter_walking_state(pos)

func _set_combat_state_visual(in_combat: bool):
	if sprite and not is_selected:
		if in_combat:
			sprite.modulate = Color(1.2, 0.8, 0.8)
		else:
			sprite.modulate = Color(1, 1, 1)

# ============================================
# TOWER BUFF SYSTEM
# ============================================

func _on_tower_entered_aura(body: Node2D):
	if not body.has_method("get"): return
	if not ("tower_id" in body): return
	towers_in_aura.append(body)
	_apply_tower_buff(body)

func _on_tower_exited_aura(body: Node2D):
	if body in towers_in_aura:
		towers_in_aura.erase(body)
		_remove_tower_buff(body)

func _apply_tower_buff(tower: Node2D):
	var damage_bonus = 0.20
	var mod_source = "hero_aura_%s" % get_instance_id()
	var mod_description = "Hero Aura (+20% DMG)"
	if tower.has("stat_damage"):
		tower.stat_damage.add_modifier(StatModifier.create_additive(damage_bonus, mod_source, mod_description))
	elif tower.has("stat_soldier_damage"):
		tower.stat_soldier_damage.add_modifier(StatModifier.create_additive(damage_bonus, mod_source, mod_description))
	if tower.has("sprite"):
		tower.sprite.modulate = Color(1.2, 1.2, 1.0)

func _remove_tower_buff(tower: Node2D):
	if not is_instance_valid(tower): return
	var mod_source = "hero_aura_%s" % get_instance_id()
	if tower.has("stat_damage"):
		tower.stat_damage.remove_modifiers_from_source(mod_source)
	elif tower.has("stat_soldier_damage"):
		tower.stat_soldier_damage.remove_modifiers_from_source(mod_source)
	if tower.has("sprite"):
		tower.sprite.modulate = Color(1.0, 1.0, 1.0)

func _cleanup_all_tower_buffs():
	for tower in towers_in_aura.duplicate():
		_remove_tower_buff(tower)
	towers_in_aura.clear()

# ============================================
# COMBAT - SHOOTING & MELEE
# ============================================

func _on_ranged_timer_timeout():
	if current_state == State.RANGED_COMBAT:
		shoot_arrow()

func shoot_arrow():
	if arrow_scene == null:
		print("⚠️ Hero CANNOT SHOOT: arrow_scene is null! Check Inspector settings.")
		return
	current_ranged_target = get_closest_ranged_enemy()
	if current_ranged_target == null or not is_instance_valid(current_ranged_target): return
	if enemies_in_melee_range.has(current_ranged_target): return
	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	arrow.global_position = global_position
	arrow.setup(current_ranged_target, ranged_damage, self)

func _on_melee_timer_timeout():
	if current_state == State.MELEE_COMBAT:
		melee_attack()

func melee_attack():
	current_melee_targets = get_melee_targets()
	if current_melee_targets.is_empty(): return
	_play_attack_flash()
	for enemy in current_melee_targets:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			if BalanceTracker: BalanceTracker.record_damage(self, enemy, melee_damage, "hero_melee")
			enemy.take_damage(melee_damage, self, "hero_melee")

func _play_attack_flash():
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate
