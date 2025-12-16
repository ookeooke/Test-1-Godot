extends Control
class_name HeroCommandWidget

## ============================================
## UNIFIED HERO WIDGET (Formally HeroCommandWidget)
## ============================================
## Handles both Combat HUD and Menu Loadout display.
## Features:
## - Radial/Circular layout for skills
## - Mode switching (Combat vs Loadout)
## - Dynamic slot count based on heap progression
## - Drag-and-drop support in Loadout mode

enum Mode {
	COMBAT, # HUD: Only equipped skills, clickable
	LOADOUT # MENU: All slots (including empty), drag targets
}

signal skill_changed()

@export var current_mode: Mode = Mode.COMBAT
@export var hero_id: String = ""

# CONFIGURATION
const RAIDAL_RADIUS = 115.0
const ACTIVE_ARC_Start = -135.0 # Degrees (Top Left)
const ACTIVE_ARC_END = -45.0 # Degrees (Top Right)
const PASSIVE_ARC_START = 135.0 # Degrees (Bottom Left)
const PASSIVE_ARC_END = 45.0 # Degrees (Bottom Right)

# REFERENCES
@onready var portrait_button: TextureButton = $PortraitButton
@onready var health_bar: ProgressBar = $PortraitButton/HealthBar
@onready var xp_bar: ProgressBar = $PortraitButton/XPBar

@onready var slots_container: Control = $SlotsContainer
@onready var active_slots_node: Control = $SlotsContainer/ActiveSlots
@onready var passive_slots_node: Control = $SlotsContainer/PassiveSlots

# PRELOADS
const SKILL_SLOT_SCENE = preload("res://scenes/ui/skill_slot.tscn")
const ABILITY_BUTTON_SCENE = preload("res://scenes/ui/ability_button.tscn")

# STATE
var _hero_reference: Node = null

func _ready():
	# Add to group for HeroSpot finding
	add_to_group("hero_command_widget")

	# If hero_id is set in editor, initialize
	if hero_id != "":
		setup(hero_id, current_mode)

	# Connect portrait click
	if portrait_button:
		if not portrait_button.pressed.is_connected(_on_portrait_pressed):
			portrait_button.pressed.connect(_on_portrait_pressed)

func _process(_delta):
	if current_mode == Mode.COMBAT and is_instance_valid(_hero_reference):
		_update_hud_bars()

## ============================================
## INTERACTION
## ============================================

func _on_portrait_pressed():
	print("🔘 [UnifiedHeroWidget] Portrait clicked for: ", hero_id)
	if _hero_reference and is_instance_valid(_hero_reference):
		# Create a visual bounce effect
		var tween = create_tween()
		tween.tween_property(portrait_button, "scale", Vector2(0.9, 0.9), 0.05)
		tween.tween_property(portrait_button, "scale", Vector2(1.0, 1.0), 0.05)
		
		# Select the hero
		if _hero_reference.has_method("select"):
			print("  -> Calling hero.select()")
			_hero_reference.select()
		
		# Emit signal for managers
		if _hero_reference.has_signal("hero_selected"):
			_hero_reference.hero_selected.emit(_hero_reference)

func set_selected(is_selected: bool):
	"""Called by HeroManager to update visual selection state"""
	if not portrait_button: return
	
	if is_selected:
		portrait_button.modulate = Color(1.3, 1.3, 1.3) # Highlight
	else:
		portrait_button.modulate = Color.WHITE

## COMPATIBILITY METHOD for HeroSpot
func setup_hero(hero_node: Node):
	"""Adapter for legacy calls from HeroSpot"""
	var h_id = ""
	if "hero_id" in hero_node:
		h_id = hero_node.hero_id
	elif hero_node.has_meta("hero_id"):
		h_id = hero_node.get_meta("hero_id")
	else:
		h_id = hero_node.name.to_lower().replace("hero", "")
		
	setup(h_id, Mode.COMBAT, hero_node)

func setup(p_hero_id: String, p_mode: Mode = Mode.COMBAT, p_hero_node: Node = null):
	print("\n🎯 [UnifiedHeroWidget] setup() called:")
	print("  hero_id: '%s'" % p_hero_id)
	print("  mode: %s" % Mode.keys()[p_mode])
	print("  hero_node: %s" % p_hero_node)

	hero_id = p_hero_id
	current_mode = p_mode
	_hero_reference = p_hero_node

	_update_portrait()
	_rebuild_slots()

	print("[UnifiedHeroWidget] ✅ Setup complete for %s in %s mode\n" % [hero_id, Mode.keys()[current_mode]])

func _update_hud_bars():
	if not _hero_reference: return
	
	# Relaxed check: "max_health" property with getter sometimes fails 'in' check
	if health_bar and "current_health" in _hero_reference:
		var cur = _hero_reference.current_health
		var max_h = _hero_reference.get("max_health") # Use get() for computed properties safety
		
		# Fallback if get() returns null (shouldn't happen for BaseHero)
		if max_h == null and "max_health" in _hero_reference:
			max_h = _hero_reference.max_health
			
		if max_h != null:
			health_bar.max_value = max_h
			health_bar.value = cur
		
	# XP Logic if needed
	# if xp_bar ...

func _update_portrait():
	if not HeroDatabase: return
	var data = HeroDatabase.get_hero(hero_id)
	if data and data.portrait:
		portrait_button.texture_normal = data.portrait
		
func _rebuild_slots():
	print("\n🔨 [UnifiedHeroWidget] _rebuild_slots() called for hero_id='%s'" % hero_id)

	# Clear existing
	for child in active_slots_node.get_children(): child.queue_free()
	for child in passive_slots_node.get_children(): child.queue_free()

	# Get Slot Counts
	var counts = SaveManager.get_unlocked_slot_count(hero_id)
	var active_count = counts.active
	var passive_count = counts.passive

	print("  Slot counts: active=%d, passive=%d" % [active_count, passive_count])

	# Create Slots
	_create_radial_slots(active_slots_node, active_count, "active", ACTIVE_ARC_Start, ACTIVE_ARC_END)
	_create_radial_slots(passive_slots_node, passive_count, "passive", PASSIVE_ARC_START, PASSIVE_ARC_END)

func _create_radial_slots(parent: Node, count: int, type: String, start_deg: float, end_deg: float):
	if count <= 0:
		print("  [Widget] ⚠️ Skipping %s slots (count=0)" % type)
		return

	print("\n  📊 [Widget] Creating %d %s slot(s)" % [count, type])

	var equipped_skills = SaveManager.get_equipped_skills(hero_id)
	var skill_list = equipped_skills.get(type, [])

	print("  [Widget] Equipped %s skills: %s" % [type, skill_list])
	
	# Pad lists if needed
	while skill_list.size() < count:
		skill_list.append("")
		
	# Calculate Angle Step
	# If 1 slot, put it in middle. If multiple, spread them.
	var angle_step = 0.0
	if count > 1:
		angle_step = (end_deg - start_deg) / (count - 1)
	else:
		start_deg = (start_deg + end_deg) / 2 # Center it
		
	for i in range(count):
		var skill_id = ""
		if i < skill_list.size():
			skill_id = skill_list[i]
			
		# Instantiate Component based on Mode
		var slot_instance = null
		
		# Skip empty slots in COMBAT mode mostly, BUT we need positioning.
		# Wait, previously I skipped visual.
		
		if current_mode == Mode.LOADOUT:
			# SkillSlot (Drop Target)
			slot_instance = SKILL_SLOT_SCENE.instantiate()
			slot_instance.setup(i, type, hero_id)
			if not slot_instance.skill_equipped.is_connected(_on_slot_skill_changed):
				slot_instance.skill_equipped.connect(_on_slot_skill_changed)
			
		elif current_mode == Mode.COMBAT:
			if skill_id == "": continue # SKIP visual for empty slots in combat
			
			# AbilityButton (Clickable)
			slot_instance = ABILITY_BUTTON_SCENE.instantiate()
			
			# Get dependencies for combat button
			print("  [Widget] 🔍 Processing slot %d: skill_id='%s'" % [i, skill_id])

			var skill_mgr = null
			if _hero_reference and _hero_reference.has_method("get_skill_manager"):
				skill_mgr = _hero_reference.get_skill_manager()
			elif _hero_reference and "skill_manager" in _hero_reference:
				skill_mgr = _hero_reference.skill_manager

			print("  [Widget] skill_mgr: %s" % skill_mgr)

			var skill_data = null
			if HeroDatabase and HeroClassDatabase:
				var h_data = HeroDatabase.get_hero(hero_id)
				if h_data:
					var c_config = HeroClassDatabase.get_class_config(h_data.hero_class)
					if c_config:
						# Find skill data from pool
						for s in c_config.available_skill_pool:
							if s.skill_id == skill_id:
								skill_data = s
								break

			print("  [Widget] skill_data: %s" % skill_data)

			if type == "active":
				# Pass all required args: id, manager, data, hotkey
				var hotkey = str(i + 1)
				slot_instance.setup(skill_id, skill_mgr, skill_data, hotkey)
				print("  [Widget] ✅ Created AbilityButton for '%s' with manager=%s" % [skill_id, skill_mgr])
			else:
				# Passive icon for combat
				var passive_icon = preload("res://scenes/ui/skill_icon.tscn").instantiate()
				passive_icon.setup(skill_id, skill_data, hero_id)
				slot_instance = Control.new()
				slot_instance.add_child(passive_icon)
				
				# Center passive icon
				passive_icon.position = - passive_icon.custom_minimum_size / 2
				
		if slot_instance:
			parent.add_child(slot_instance)
			
			# Position Radially
			var angle_rad = deg_to_rad(start_deg + (angle_step * i))
			var pos = Vector2(cos(angle_rad), sin(angle_rad)) * RAIDAL_RADIUS
			
			# Center the slot on the point
			if slot_instance is Control: # Ensure we can access properties
				# For AbilityButton (Button) or SkillSlot (PanelContainer)
				var size_offset = slot_instance.custom_minimum_size / 2
				
				# If it's our wrapper Control (for passives), it might not have size set
				if slot_instance.get_class() == "Control" and slot_instance.get_child_count() > 0:
					# It's the passive wrapper
					slot_instance.position = pos # Icon is already centered in wrapper
				else:
					slot_instance.position = pos - size_offset

func _on_slot_skill_changed(_slot_index, _skill_id):
	skill_changed.emit()
