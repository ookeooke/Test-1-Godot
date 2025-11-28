extends BaseHero

# ============================================
# WARRIOR HERO
# ============================================

# CLASS TYPE
const CLASS_TYPE_MELEE: int = 0 # Matches HeroClassConfig.class_type

# ============================================
# INITIALIZATION OVERRIDES
# ============================================

func _ready():
	# Warrior Stats: High Health, High Melee Damage, Low Range
	BASE_MAX_HEALTH = 500.0
	BASE_RANGED_DAMAGE = 0.0
	BASE_MELEE_DAMAGE = 25.0
	BASE_RANGED_RANGE = 0.0 # Pure melee
	BASE_RANGED_ATTACK_SPEED = 1.0
	BASE_MOVEMENT_SPEED = 140.0 # Slightly slower
	
	super._ready()
	
	set_meta("hero_name", "Warrior")
	set_meta("hero_class", "warrior")
	
	# Warrior can block more enemies
	block_capacity = 3

func _generate_unique_hero_id() -> String:
	return "warrior"

func _get_class_type() -> int:
	return CLASS_TYPE_MELEE

func _equip_starter_gear() -> void:
	var equipped_weapon = HeroEquipmentRegistry.get_equipped_item(hero_id, "hand_left")
	if equipped_weapon == null:
		var hero_container = InventoryRegistry.get_container(hero_id)
		if hero_container:
			var all_items = hero_container.get_all_items()
			var found_weapon: ItemInstance = null
			for item in all_items:
				if item.item_id == "basic_sword":
					found_weapon = item
					break
			if found_weapon == null:
				var uuid = HeroInventoryManager.add_item_instance_to_hero(hero_id, "basic_sword", 0)
				if uuid != "":
					found_weapon = hero_container._items.get(uuid)
			if found_weapon:
				ItemTransactionService.equip_item(hero_id, found_weapon.uuid, "hand_left")

# ============================================
# SKILL SYSTEM
# ============================================

func _on_skill_activated(skill_id: String):
	print("⚔️ WarriorHero: Skill activated: ", skill_id)
	match skill_id:
		"warrior_cleave": _execute_cleave()
		"warrior_shield_bash": _execute_shield_bash()
		"warrior_taunt": _execute_taunt()
		_: push_warning("Unknown skill activated: ", skill_id)

func _execute_cleave():
	# Damage all enemies in melee range
	if enemies_in_melee_range.is_empty():
		_show_floating_text("No Targets!", Color.RED)
		return
		
	var damage = melee_damage * 1.5
	for enemy in enemies_in_melee_range:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage, self, "skill_cleave")
			
	_flash_hero(Color(1.5, 0.5, 0.5))
	_show_floating_text("CLEAVE!", Color.ORANGE)

func _execute_shield_bash():
	# Stun current target
	if current_melee_targets.is_empty():
		return
		
	var target = current_melee_targets[0]
	if is_instance_valid(target):
		var damage = melee_damage * 2.0
		if target.has_method("take_damage"):
			target.take_damage(damage, self, "skill_bash")
		if target.has_method("stun"):
			target.stun(2.0)
			
	_flash_hero(Color(0.5, 0.5, 1.5))
	_show_floating_text("BASH!", Color.CYAN)

func _execute_taunt():
	# Force enemies to target hero
	var taunt_radius = 200.0
	var taunted_count = 0
	
	# Check all enemies in ranged range (which is usually larger than melee)
	# Or better, use the detection area if available
	for enemy in enemies_in_ranged_range:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= taunt_radius:
			if enemy.has_method("set_target"):
				enemy.set_target(self)
				taunted_count += 1
				
	_flash_hero(Color(1.5, 1.5, 0.5))
	if taunted_count > 0:
		_show_floating_text("TAUNT! (%d)" % taunted_count, Color.YELLOW)
	else:
		_show_floating_text("TAUNT!", Color.YELLOW)

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
