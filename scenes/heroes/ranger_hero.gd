extends "res://scenes/heroes/base_hero.gd"

# ============================================
# RANGER HERO - Inherits from BaseHero
# ============================================

# CLASS TYPE (for attribute scaling)
const CLASS_TYPE_RANGED: int = 1 # Matches HeroClassConfig.class_type

# PROJECTILE
@export var arrow_scene: PackedScene

# ============================================
# INITIALIZATION OVERRIDES
# ============================================

func _ready():
	# Set base stats before calling super._ready()
	BASE_MAX_HEALTH = 300.0
	BASE_RANGED_DAMAGE = 0.0
	BASE_MELEE_DAMAGE = 0.0
	BASE_RANGED_RANGE = 240.0
	BASE_RANGED_ATTACK_SPEED = 0.55
	BASE_MOVEMENT_SPEED = 150.0
	
	super._ready()
	
	set_meta("hero_name", "Ranger")
	set_meta("hero_class", "ranger")

func _generate_unique_hero_id() -> String:
	return "ranger"

func _get_class_type() -> int:
	return CLASS_TYPE_RANGED

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

# ============================================
# COMBAT OVERRIDES
# ============================================

func perform_ranged_attack(target):
	if arrow_scene == null:
		push_error("Cannot execute ranged attack: arrow_scene is null")
		return
		
	var arrow = arrow_scene.instantiate()
	get_tree().root.add_child(arrow)
	
	if projectile_spawn_node:
		arrow.global_position = projectile_spawn_node.global_position
	else:
		arrow.global_position = global_position
		
	arrow.setup(target, ranged_damage, self)

# ============================================
# SKILL SYSTEM
# ============================================

func _on_skill_activated(skill_id: String):
	# print("🏹 RangerHero: Skill activated: ", skill_id)
	match skill_id:
		"ranger_multishot": _execute_multishot()
		"ranger_rapid_fire": _execute_rapid_fire()
		"ranger_poison_arrow": _execute_poison_arrow()
		"ranger_sniper_shot": _execute_sniper_shot()
		"ranger_smoke_bomb": _execute_smoke_bomb()
		"ranger_rally_call": _execute_rally_call()
		"ranger_eagle_eye": pass # Passive
		_: push_warning("Unknown skill activated: ", skill_id)

func _get_skill_attribute_scaling() -> Dictionary:
	if not SaveManager or not SaveManager.has_current_profile():
		return {"might": 0, "agility": 0, "vitality": 0, "wisdom": 0}
	return SaveManager.get_hero_attributes(hero_id)

func _execute_multishot():
	print("🏹 RangerHero: Executing Multishot...")
	if arrow_scene == null:
		push_error("Cannot execute multishot: arrow_scene is null")
		return

	if enemies_in_ranged_range.is_empty():
		print("⚠️ RangerHero: Multishot failed - No enemies in range!")
		_show_floating_text("No Target!", Color.RED)
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
	
	print("🏹 RangerHero: Multishot firing ", targets.size(), " arrows (requested ", arrow_count, ")")

	for target in targets:
		if not is_instance_valid(target): continue
		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		if projectile_spawn_node:
			arrow.global_position = projectile_spawn_node.global_position
		else:
			arrow.global_position = global_position
		var damage = ranged_damage * damage_multiplier
		arrow.setup(target, damage, self)
	_flash_hero(Color(1.5, 1.3, 1.0))
	_show_floating_text("Multishot!", Color.YELLOW)

func _show_floating_text(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	get_tree().root.add_child(label)
	label.global_position = global_position + Vector2(0, -60)
	
	var tween = create_tween()
	tween.parallel().tween_property(label, "global_position", label.global_position + Vector2(0, -50), 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

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
		if projectile_spawn_node:
			arrow.global_position = projectile_spawn_node.global_position
		else:
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
	if projectile_spawn_node:
		arrow.global_position = projectile_spawn_node.global_position
	else:
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
	if projectile_spawn_node:
		arrow.global_position = projectile_spawn_node.global_position
	else:
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
