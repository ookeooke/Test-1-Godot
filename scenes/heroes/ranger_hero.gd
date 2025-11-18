extends CharacterBody2D

# ============================================
# RANGER HERO - Now using ClickManager!
# ============================================

signal hero_died(respawn_time)
signal hero_selected(hero)

# STATES
enum State { IDLE, RANGED_COMBAT, MELEE_COMBAT, RETURNING, WALKING }
var current_state = State.IDLE
var hero_id: String

# STATS - NEW UNIFIED SYSTEM
var hero_level = 1

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
var current_health = BASE_MAX_HEALTH  # Will be properly set after stat initialization

# Base stats (for reference and reset)
const BASE_MAX_HEALTH = 300.0  # BALANCE FIX: Was 200 (40 hits), now 300 (60 hits - matches KR1 durability)
const BASE_RANGED_DAMAGE = 0.0  # All damage comes from equipment (requires weapon equipped)
const BASE_MELEE_DAMAGE = 0.0  # All damage comes from equipment
const BASE_RANGED_RANGE = 240.0  # BALANCE FIX: Was 300 (same as tower), now 240 (80% of tower - requires positioning risk)
const BASE_RANGED_ATTACK_SPEED = 0.55  # 25.5 DPS ranged (lower = faster)
const BASE_MOVEMENT_SPEED = 150.0

# Fixed stats (not affected by modifiers)
var melee_range = 100.0
var melee_attack_speed = 0.8  # 7.5 DPS melee
var combat_distance = 50.0  # How close to get before attacking (visual improvement)

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
var max_melee_enemies = 2  # HEROES ARE STRONGER: Block 2 enemies at once (soldiers = 1)
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
var regen_delay: float = 2.0  # 2 seconds delay for heroes (longer than soldiers)
var regen_rate: float = 3.0   # 3 HP per second (slower than soldiers)

# SELECTION
var is_selected = false

# REFERENCES
var click_area: Area2D  # For clicking the hero
@onready var ranged_detection = $RangedDetection
@onready var melee_detection = $MeleeDetection
@onready var range_indicator = $RangeIndicator
@onready var health_bar = $HealthBar
@onready var sprite = $Sprite2D

# TOWER BUFF SYSTEM (Phase 2B)
# Phase 2B: Area2D for detecting nearby towers (add TowerAura node manually to scene)
var tower_aura: Area2D = null
var towers_in_aura = []  # List of towers currently being buffed
const AURA_RADIUS = 200.0  # How close hero must be to buff towers

# PROJECTILE
@export var arrow_scene: PackedScene

# VISUAL
@export var hero_texture: Texture2D  # Inspector-selectable sprite texture

# SKILL SYSTEM
@export var available_skills: Array[HeroSkillData] = []  # All skills this hero can learn
var skill_manager: SkillManager = null

# EQUIPMENT SYSTEM
# Now managed by HeroEquipmentRegistry singleton

# ============================================
# INITIALIZATION
# ============================================

func _ready():
	print("\n🎯 === RANGER HERO INITIALIZATION START ===")

	# Initialize stat system FIRST (before equipment/skills)
	_initialize_stats()

	# Initialize equipment system
	_setup_equipment_system()

	# Initialize skill system
	_setup_skill_system()

	# Apply all modifiers from equipment and skills
	_recalculate_all_stats()

	# Set hero to full health after all stat bonuses are applied
	current_health = max_health

	print("✅ === RANGER HERO INITIALIZATION COMPLETE ===\n")

	# Set collision layers
	collision_layer = 2
	collision_mask = 0

	# Setup detection areas
	ranged_detection.collision_layer = 0
	ranged_detection.collision_mask = 1
	melee_detection.collision_layer = 0
	melee_detection.collision_mask = 1

	# Setup click detection (if ClickArea node exists in scene)
	if has_node("ClickArea"):
		click_area = $ClickArea
		click_area.input_pickable = true
		click_area.input_event.connect(_on_area_input_event)
		click_area.mouse_entered.connect(_on_mouse_entered)
		click_area.mouse_exited.connect(_on_mouse_exited)

	# Connect signals
	ranged_detection.body_entered.connect(_on_ranged_enemy_entered)
	ranged_detection.body_exited.connect(_on_ranged_enemy_exited)
	melee_detection.body_entered.connect(_on_melee_enemy_entered)
	melee_detection.body_exited.connect(_on_melee_enemy_exited)

	# Phase 2B: Setup tower buff aura
	if has_node("TowerAura"):
		tower_aura = $TowerAura
		tower_aura.collision_layer = 0  # Don't create collisions
		tower_aura.collision_mask = 8  # Detect towers on layer 4 (bit 3, value 8)
		tower_aura.body_entered.connect(_on_tower_entered_aura)
		tower_aura.body_exited.connect(_on_tower_exited_aura)

	# Create timers
	ranged_timer = Timer.new()
	ranged_timer.wait_time = ranged_attack_speed
	ranged_timer.timeout.connect(_on_ranged_timer_timeout)
	add_child(ranged_timer)

	melee_timer = Timer.new()
	melee_timer.wait_time = melee_attack_speed
	melee_timer.timeout.connect(_on_melee_timer_timeout)
	add_child(melee_timer)

	# Setup visuals
	draw_range_circle()
	range_indicator.visible = false
	update_health_bar()

	# Apply texture if provided (Kingdom Rush style sprite support)
	if sprite is Sprite2D:
		if hero_texture:
			sprite.texture = hero_texture
			# Hide fallback ColorRect if it exists
			if sprite.has_node("FallbackRect"):
				sprite.get_node("FallbackRect").visible = false
		else:
			# No texture provided - show fallback ColorRect placeholder
			if sprite.has_node("FallbackRect"):
				sprite.get_node("FallbackRect").visible = true
			push_warning("[RangerHero] No hero_texture assigned - using fallback ColorRect")

	# Register with BalanceTracker
	if BalanceTracker:
		BalanceTracker.register_hero(self, get_hero_id())


# ============================================
# STAT SYSTEM - NEW UNIFIED APPROACH
# ============================================

func _initialize_stats():
	"""Initialize all Stat objects with base values"""
	stat_max_health = Stat.new(BASE_MAX_HEALTH)
	stat_ranged_damage = Stat.new(BASE_RANGED_DAMAGE)
	stat_melee_damage = Stat.new(BASE_MELEE_DAMAGE)
	stat_ranged_range = Stat.new(BASE_RANGED_RANGE)
	stat_ranged_attack_speed = Stat.new(BASE_RANGED_ATTACK_SPEED)
	stat_movement_speed = Stat.new(BASE_MOVEMENT_SPEED)

	# Optional stats (start at 0, only increased by equipment/skills)
	stat_crit_chance = Stat.new(0.0)
	stat_defense = Stat.new(0.0)

	# Set initial health to max
	current_health = BASE_MAX_HEALTH



func _recalculate_all_stats():
	"""Recalculate all stats by applying modifiers from equipment and skills"""
	if not stat_max_health:
		push_error("[RangerHero] Stats not initialized!")
		return

	# Clear all existing modifiers
	stat_max_health.clear_modifiers()
	stat_ranged_damage.clear_modifiers()
	stat_melee_damage.clear_modifiers()
	stat_ranged_range.clear_modifiers()
	stat_ranged_attack_speed.clear_modifiers()
	stat_movement_speed.clear_modifiers()
	stat_crit_chance.clear_modifiers()
	stat_defense.clear_modifiers()

	var equipment_mod_count = 0
	var skill_mod_count = 0

	# Gather modifiers from equipment (via HeroEquipmentRegistry)
	var equipped_items = HeroEquipmentRegistry.get_all_equipped_items(hero_id)
	for slot in equipped_items.keys():
		var item_id = equipped_items[slot]
		if item_id == "":
			continue
		var item_data = ItemDatabase.get_item(item_id)
		if not item_data:
			continue

		# Get upgrade level AND rolled affixes from inventory
		var upgrade_level = InventoryManager.get_item_upgrade_level(item_id)
		var rolled_affixes = InventoryManager.get_item_rolled_affixes(item_id)

		# Generate modifiers from base stats + affixes
		var modifiers = item_data.get_stat_modifiers(upgrade_level, rolled_affixes)

		for modifier in modifiers:
			_apply_modifier_to_appropriate_stat(modifier)
			equipment_mod_count += 1

	# Gather modifiers from skills
	if skill_manager:
		var skill_modifiers = skill_manager.get_passive_skill_modifiers()
		skill_mod_count = skill_modifiers.size()
		for modifier in skill_modifiers:
			_apply_modifier_to_appropriate_stat(modifier)


	# Update timer with new attack speed
	if ranged_timer:
		ranged_timer.wait_time = ranged_attack_speed

	# Update visuals
	draw_range_circle()  # Range might have changed
	update_health_bar()

	# Ensure current health doesn't exceed new max
	if current_health > max_health:
		current_health = max_health


	# Track equipment in BalanceTracker
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
	"""Route a modifier to the correct stat based on its description"""
	var desc_lower = modifier.description.to_lower()

	# Match modifier to appropriate stat
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
	elif "movement" in desc_lower or "speed" in desc_lower:
		stat_movement_speed.add_modifier(modifier)
	else:
		push_warning("[RangerHero] Could not match modifier to stat: ", modifier.description)

# ============================================
# EQUIPMENT SYSTEM SETUP
# ============================================

func _setup_equipment_system():
	"""Initialize the equipment registry integration"""
	# Generate unique hero ID
	var unique_hero_id = _generate_unique_hero_id()
	hero_id = unique_hero_id

	# Register hero in equipment registry
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)

	# Connect to registry signals
	HeroEquipmentRegistry.equipment_transaction_completed.connect(_on_equipment_transaction)
	HeroEquipmentRegistry.batch_update_completed.connect(_on_batch_update)

	# Ensure starter equipment is equipped FIRST (before loading save)
	_equip_starter_gear()

	# Load equipment from save (this will override starter gear if player has better equipment)
	_load_equipment_from_save()


func _generate_unique_hero_id() -> String:
	"""Generate static hero class ID for equipment persistence"""
	# Use static ID so equipment persists across game sessions
	return "ranger"

func _load_equipment_from_save() -> void:
	"""Verify equipment is loaded from save manager"""
	# Equipment is automatically loaded by SaveManager.load_profile()
	# which calls HeroEquipmentRegistry.load_from_dict()
	# Just verify hero is registered
	if not HeroEquipmentRegistry.is_hero_registered(hero_id):
		HeroEquipmentRegistry.register_hero(hero_id)

func _equip_starter_gear() -> void:
	"""Ensure ranger has Basic Bow equipped (auto-equipped on first spawn)"""
	var equipped_weapon = HeroEquipmentRegistry.get_equipped_item(hero_id, "weapon")

	if equipped_weapon == "":  # No weapon equipped
		print("[RangerHero] No weapon equipped - equipping starter Basic Bow")

		# Add Basic Bow to inventory if not exists
		if not InventoryManager.has_item("basic_bow"):
			InventoryManager.add_item("basic_bow", 1)
			print("[RangerHero] Added Basic Bow to inventory")

		# Auto-equip it
		if InventoryManager.equip_item_atomic(hero_id, "weapon", "basic_bow"):
			print("[RangerHero] ✅ Starter weapon equipped: Basic Bow")
		else:
			print("[RangerHero] ⚠️ Failed to equip starter weapon")
	else:
		print("[RangerHero] Weapon already equipped: ", equipped_weapon)

func _on_equipment_transaction(transaction_hero_id: String, transaction_type: String, details: Dictionary) -> void:
	"""Handle equipment transaction for this hero"""
	if transaction_hero_id != hero_id:
		return

func _on_batch_update(dirty_hero_ids: Array[String]) -> void:
	"""Handle batched equipment update"""
	if hero_id not in dirty_hero_ids:
		return
	_recalculate_all_stats()




# ============================================
# SKILL SYSTEM SETUP
# ============================================

func _setup_skill_system():
	"""Initialize the skill manager and load saved skills"""
	# Create skill manager
	skill_manager = SkillManager.new()
	skill_manager.name = "SkillManager"
	add_child(skill_manager)

	# Load skill definitions
	skill_manager.load_skill_definitions(available_skills)

	# Load saved skill data from SaveManager
	if SaveManager:
		var hero_id = "ranger"  # TODO: Make this dynamic for multiple heroes
		var saved_skills = SaveManager.get_hero_skills(hero_id)

		if saved_skills:
			skill_manager.load_save_data(saved_skills)
			skill_manager.recalculate_all_passives()

	# Connect to skill activation signal
	skill_manager.skill_activated.connect(_on_skill_activated)

	# FOR TESTING: Auto-unlock multishot skill
	if not skill_manager.is_skill_owned("ranger_multishot"):
		var multishot_data = null
		for skill_data in available_skills:
			if skill_data.skill_id == "ranger_multishot":
				multishot_data = skill_data
				break
		if multishot_data:
			skill_manager.unlock_skill("ranger_multishot", multishot_data)


func _on_skill_activated(skill_id: String):
	"""Handle skill activation"""

	# Execute skill-specific logic
	match skill_id:
		"ranger_multishot":
			_execute_multishot()
		"ranger_smoke_bomb":
			_execute_smoke_bomb()
		"ranger_rally_call":
			_execute_rally_call()
		_:
			push_warning("Unknown skill activated: ", skill_id)

# ============================================
# SKILL IMPLEMENTATIONS
# ============================================

func _execute_multishot():
	"""Multishot ability - Fire multiple arrows in a cone"""
	if arrow_scene == null:
		push_error("Cannot execute multishot: arrow_scene is null")
		return

	# Get current targets
	if enemies_in_ranged_range.is_empty():
		return

	# Determine number of arrows based on skill level
	var skill_level = skill_manager.get_skill_level("ranger_multishot")
	var arrow_count = 5 + (skill_level - 1) * 2  # 5 at level 1, 7 at level 2, etc.

	# Get damage multiplier from skill data
	var skill_data = skill_manager.get_skill_data("ranger_multishot")
	var damage_multiplier = 1.0
	if skill_data:
		damage_multiplier = skill_data.get_current_damage_multiplier(skill_level)

	# Find up to arrow_count targets
	var targets = enemies_in_ranged_range.duplicate()
	targets.shuffle()  # Randomize target selection
	targets = targets.slice(0, min(arrow_count, targets.size()))

	# Fire arrows at each target
	for target in targets:
		if not is_instance_valid(target):
			continue

		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		arrow.global_position = global_position

		# Apply skill damage multiplier
		var damage = ranged_damage * damage_multiplier
		arrow.setup(target, damage, self)  # Pass self as source for balance tracking


	# Visual feedback (could add particle effect here)
	_flash_hero(Color(1.5, 1.3, 1.0))

func _execute_smoke_bomb():
	"""Smoke Bomb ability - Become invisible, enemies lose aggro"""

	# TODO: Implement invisibility mechanic
	# For now, just clear enemy aggro
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and enemy.has_method("unblock"):
			if enemy.is_blocked and enemy.blocking_hero == self:
				enemy.unblock()

	current_melee_targets.clear()

	# Visual feedback
	_flash_hero(Color(0.7, 0.7, 0.7, 0.5))

func _execute_rally_call():
	"""Rally Call ability - Boost nearby towers' attack speed"""

	# TODO: Find nearby towers and boost their attack speed
	# This requires tower manager or getting towers from the scene

	# Visual feedback
	_flash_hero(Color(1.3, 1.5, 1.0))

func _flash_hero(color: Color):
	"""Visual feedback for skill activation"""
	var original_color = sprite.modulate
	sprite.modulate = color

	await get_tree().create_timer(0.2).timeout
	sprite.modulate = original_color

func get_hero_id() -> String:
	"""Get unique ID for this hero (used for save/load)"""
	return "ranger"

# ============================================
# CLICK HANDLING - Using Area2D
# ============================================

func _on_area_input_event(_viewport, event, _shape_idx):
	# Handle mouse input
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_clicked()
			get_viewport().set_input_as_handled()
		# Right-click removed for web compatibility (ESC key for deselect)
	# Handle touch input
	elif event is InputEventScreenTouch and event.pressed:
		_on_clicked()
		get_viewport().set_input_as_handled()

func _on_clicked() -> void:
	"""Called when this hero is clicked"""
	# Single click: Select hero
	hero_selected.emit(self)

func _on_mouse_entered() -> void:
	"""Called when mouse enters hero area"""
	if not is_selected:
		sprite.modulate = Color(1.2, 1.2, 1.5)  # Blue tint
		# Could show tooltip here

func _on_mouse_exited() -> void:
	"""Called when mouse leaves hero area"""
	if not is_selected:
		sprite.modulate = Color(1, 1, 1)

# ============================================
# MAIN LOOP
# ============================================

func _physics_process(delta):
	# Update regeneration FIRST (Kingdom Rush style)
	update_regeneration(delta)

	match current_state:
		State.IDLE:
			handle_idle_state()
		State.RANGED_COMBAT:
			handle_ranged_combat_state()
		State.MELEE_COMBAT:
			handle_melee_combat_state()
		State.RETURNING:
			handle_returning_state(delta)
		State.WALKING:
			handle_walking_state(delta)

	clean_enemy_lists()

# ============================================
# VISUAL - KINGDOM RUSH STYLE SPRITE FLIPPING
# ============================================

func update_sprite_direction(target_position: Vector2):
	"""Kingdom Rush style: Flip sprite left/right only (no 360° rotation)

	This keeps the character always upright and readable, matching the
	isometric 2D tower defense style of Kingdom Rush.
	"""
	if not sprite:
		return

	# Calculate direction to target
	var direction_to_target = target_position - global_position

	# Flip sprite horizontally based on X direction
	# flip_h = true means sprite faces LEFT
	# flip_h = false means sprite faces RIGHT (default)
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
		# Kingdom Rush style: Just flip sprite left/right (no rotation)
		update_sprite_direction(current_ranged_target.global_position)

func handle_melee_combat_state():
	current_melee_targets = get_melee_targets()

	if current_melee_targets.is_empty():
		# Unblock ALL enemies when no targets
		for enemy in enemies_in_melee_range:
			if is_instance_valid(enemy) and enemy.has_method("unblock"):
				if enemy.is_blocked and enemy.blocking_hero == self:
					enemy.unblock()

		if not enemies_in_ranged_range.is_empty():
			enter_ranged_combat()
		else:
			enter_returning_state()
		return

	# Unblock enemies NOT in the target list (when hero switches targets)
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and not current_melee_targets.has(enemy):
			if enemy.has_method("unblock") and enemy.is_blocked and enemy.blocking_hero == self:
				enemy.unblock()

	# Block target enemies (hero can block up to 2)
	var closest = current_melee_targets[0]
	if is_instance_valid(closest):
		# COMBAT POSITIONING: Move to combat distance before attacking
		var distance_to_enemy = global_position.distance_to(closest.global_position)
		if distance_to_enemy > combat_distance:
			# Move closer
			var direction = (closest.global_position - global_position).normalized()
			velocity = direction * movement_speed
			move_and_slide()
		else:
			# In position - stop moving
			velocity = Vector2.ZERO

		# Kingdom Rush style: Flip sprite to face enemies (not 360° rotation)
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
		# Track state change for balance metrics
		if BalanceTracker:
			BalanceTracker.record_hero_state_change(self, "idle")
	
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
		# Track state change for balance metrics
		if BalanceTracker:
			BalanceTracker.record_hero_state_change(self, "idle")

# ============================================
# STATE TRANSITIONS
# ============================================

func enter_ranged_combat():
	current_state = State.RANGED_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.start()

	# Track state change for balance metrics
	if BalanceTracker:
		BalanceTracker.record_hero_state_change(self, "ranged_combat")

func enter_melee_combat():
	current_state = State.MELEE_COMBAT
	velocity = Vector2.ZERO
	ranged_timer.stop()
	melee_timer.start()
	_set_combat_state_visual(true)

	# Track state change for balance metrics
	if BalanceTracker:
		BalanceTracker.record_hero_state_change(self, "melee_combat")

func enter_returning_state():
	current_state = State.RETURNING
	ranged_timer.stop()
	melee_timer.stop()
	_set_combat_state_visual(false)

	# Track state change for balance metrics
	if BalanceTracker:
		BalanceTracker.record_hero_state_change(self, "returning")

func enter_walking_state(destination: Vector2):
	current_state = State.WALKING
	target_position = destination
	ranged_timer.stop()
	melee_timer.stop()

	# Track state change for balance metrics
	if BalanceTracker:
		BalanceTracker.record_hero_state_change(self, "walking")

# ============================================
# ENEMY DETECTION
# ============================================

func _on_ranged_enemy_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_ranged_range.append(body)

func _on_ranged_enemy_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_ranged_range.erase(body)

func _on_melee_enemy_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_melee_range.append(body)

func _on_melee_enemy_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_melee_range.erase(body)

func clean_enemy_lists():
	enemies_in_ranged_range = enemies_in_ranged_range.filter(func(e): return is_instance_valid(e))
	enemies_in_melee_range = enemies_in_melee_range.filter(func(e): return is_instance_valid(e))

func get_closest_ranged_enemy():
	if enemies_in_ranged_range.is_empty():
		return null

	# TARGET PERSISTENCE: If current target still valid and in range, keep it
	if current_ranged_target and is_instance_valid(current_ranged_target):
		if enemies_in_ranged_range.has(current_ranged_target):
			# Don't keep melee-range enemies as ranged targets
			if not enemies_in_melee_range.has(current_ranged_target):
				return current_ranged_target

	# Need new target - find closest
	var closest = enemies_in_ranged_range[0]
	var closest_dist = global_position.distance_to(closest.global_position)

	for enemy in enemies_in_ranged_range:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist

	return closest

func get_melee_targets() -> Array:
	if enemies_in_melee_range.is_empty():
		return []
	
	var sorted_enemies = enemies_in_melee_range.duplicate()
	sorted_enemies.sort_custom(func(a, b): 
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	
	var targets = []
	for i in range(min(max_melee_enemies, sorted_enemies.size())):
		targets.append(sorted_enemies[i])
	
	return targets

# ============================================
# COMBAT - SHOOTING
# ============================================

func _on_ranged_timer_timeout():
	if current_state == State.RANGED_COMBAT:
		shoot_arrow()

func shoot_arrow():
	# Debug: Check if arrow scene is assigned
	if arrow_scene == null:
		print("⚠️ Hero CANNOT SHOOT: arrow_scene is null! Check Inspector settings.")
		return

	current_ranged_target = get_closest_ranged_enemy()
	if current_ranged_target == null or not is_instance_valid(current_ranged_target):
		return

	# Don't shoot melee targets (they should be blocked)
	if enemies_in_melee_range.has(current_ranged_target):
		return

	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	arrow.global_position = global_position
	arrow.setup(current_ranged_target, ranged_damage, self)

# ============================================
# COMBAT - MELEE
# ============================================

func _on_melee_timer_timeout():
	if current_state == State.MELEE_COMBAT:
		melee_attack()

func melee_attack():
	current_melee_targets = get_melee_targets()

	if current_melee_targets.is_empty():
		return

	# ATTACK FLASH: Visual feedback when attacking
	_play_attack_flash()

	for enemy in current_melee_targets:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			# Track melee damage
			if BalanceTracker:
				BalanceTracker.record_damage(self, enemy, melee_damage, "hero_melee")

			# Deal damage (pass source for kill tracking)
			enemy.take_damage(melee_damage, self, "hero_melee")

func _play_attack_flash():
	"""Visual feedback for attack - flash white"""
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 1.5)  # Flash bright white

		# Reset after 0.1 seconds
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite):
			sprite.modulate = original_modulate

# ============================================
# HEALTH & DEATH
# ============================================

func take_damage(amount: float):
	current_health -= amount

	# CRITICAL: Reset regeneration timer! (Kingdom Rush style)
	time_since_last_damage = 0.0

	# Stop regeneration visual
	if is_regenerating:
		is_regenerating = false
		show_regen_visual(false)

	update_health_bar()

	if current_health <= 0:
		die()

func die():
	# Phase 2B: Remove all tower buffs before dying
	_cleanup_all_tower_buffs()

	# Track hero death
	if BalanceTracker:
		BalanceTracker.record_hero_death(self)

	var respawn_time = 10.0 + (hero_level - 1) * 5.0
	hero_died.emit(respawn_time)
	queue_free()

func update_health_bar():
	if health_bar:
		# Use enemy-style health bar's update_health method
		if health_bar.has_method("update_health"):
			health_bar.update_health(current_health, max_health)
		else:
			# Fallback for ProgressBar (old style)
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
	"""Draw a filled circle to show range (Kingdom Rush style)"""
	var points = []
	var num_points = 64  # More points = smoother circle

	for i in range(num_points):
		var angle = (i / float(num_points)) * TAU  # TAU = 2*PI (full circle)
		var x = cos(angle) * ranged_range
		var y = sin(angle) * ranged_range
		points.append(Vector2(x, y))

	# Set polygon points for filled circle
	range_indicator.polygon = PackedVector2Array(points)

	# Set Kingdom Rush blue color with transparency
	range_indicator.color = Color(0.3, 0.5, 1.0, 0.3)  # Blue, 30% opacity

# ============================================
# REGENERATION SYSTEM (Kingdom Rush)
# ============================================

func update_regeneration(delta):
	"""Kingdom Rush style health regeneration - 3 HP/sec after 2s out of combat"""
	# Count time since last hit
	time_since_last_damage += delta

	# Can only regen if not at full health
	if current_health < max_health:
		# Check if enough time passed (2 seconds out of combat for heroes)
		if time_since_last_damage >= regen_delay:
			# Start regenerating
			if not is_regenerating:
				is_regenerating = true
				show_regen_visual(true)

			# Heal over time
			current_health += regen_rate * delta

			# Cap at max health
			if current_health > max_health:
				current_health = max_health
				is_regenerating = false
				show_regen_visual(false)

			update_health_bar()
	else:
		# Already at full health
		if is_regenerating:
			is_regenerating = false
			show_regen_visual(false)

func show_regen_visual(enabled: bool):
	"""Show/hide green pulse on health bar during regeneration"""
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
	"""Visual indicator when hero is in melee combat"""
	if sprite and not is_selected:  # Don't override selection color
		if in_combat:
			# Reddish tint = in combat
			sprite.modulate = Color(1.2, 0.8, 0.8)
		else:
			# Normal color
			sprite.modulate = Color(1, 1, 1)

# ============================================
# TOWER BUFF SYSTEM (Phase 2B)
# ============================================

func _on_tower_entered_aura(body: Node2D):
	"""Called when a tower enters hero's buff aura"""
	if not body.has_method("get"): # Basic validation
		return

	# Check if it's a tower (has tower_id export)
	if not ("tower_id" in body):
		return

	towers_in_aura.append(body)
	_apply_tower_buff(body)

func _on_tower_exited_aura(body: Node2D):
	"""Called when a tower exits hero's buff aura"""
	if body in towers_in_aura:
		towers_in_aura.erase(body)
		_remove_tower_buff(body)

func _apply_tower_buff(tower: Node2D):
	"""Apply hero aura buff to a tower (additive stacking)"""
	# Phase 2B: Hero proximity grants +20% damage (additive)
	# Future: Will read from hero's equipped items
	var damage_bonus = 0.20  # 20% additive bonus

	var mod_source = "hero_aura_%s" % get_instance_id()
	var mod_description = "Hero Aura (+20% DMG)"

	# Apply to appropriate stat based on tower type
	if tower.has("stat_damage"):
		# Archer tower: boost damage
		tower.stat_damage.add_modifier(
			StatModifier.create_additive(damage_bonus, mod_source, mod_description)
		)
	elif tower.has("stat_soldier_damage"):
		# Barracks: boost soldier damage
		tower.stat_soldier_damage.add_modifier(
			StatModifier.create_additive(damage_bonus, mod_source, mod_description)
		)

	# Visual indicator: add a subtle glow/tint to buffed tower
	if tower.has("sprite"):
		tower.sprite.modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint

func _remove_tower_buff(tower: Node2D):
	"""Remove hero aura buff from a tower"""
	if not is_instance_valid(tower):
		return

	var mod_source = "hero_aura_%s" % get_instance_id()

	# Remove modifiers
	if tower.has("stat_damage"):
		tower.stat_damage.remove_modifiers_from_source(mod_source)
	elif tower.has("stat_soldier_damage"):
		tower.stat_soldier_damage.remove_modifiers_from_source(mod_source)

	# Remove visual indicator
	if tower.has("sprite"):
		tower.sprite.modulate = Color(1.0, 1.0, 1.0)  # Reset to normal

func _cleanup_all_tower_buffs():
	"""Remove all tower buffs (called on hero death/removal)"""
	for tower in towers_in_aura.duplicate():
		_remove_tower_buff(tower)
	towers_in_aura.clear()

# ============================================
# CLEANUP
# ============================================

func _exit_tree():
	# Phase 2B: Remove all tower buffs when hero is removed/dies
	_cleanup_all_tower_buffs()
	# Area2D will auto-cleanup its signals

	# Note: We do NOT unregister from HeroEquipmentRegistry here
	# because equipment should persist across hero respawns
	# Registry cleanup happens on profile change/logout only
