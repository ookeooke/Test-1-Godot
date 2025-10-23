extends Control

# ============================================
# PATH CHOICE MENU - Choose tower specialization at level 3
# ============================================

signal damage_path_selected(tower)
signal range_path_selected(tower)
signal menu_closed()

var tower = null
var path_choice_cost = 150

# Preview state for two-click system
var is_damage_preview = false
var is_range_preview = false

# References
@onready var damage_button = $PanelContainer/MarginContainer/VBoxContainer/DamagePathButton
@onready var range_button = $PanelContainer/MarginContainer/VBoxContainer/RangePathButton
@onready var title_label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var cost_label = $PanelContainer/MarginContainer/VBoxContainer/CostLabel

func _ready():
	# Set smaller font sizes for cleaner look
	if title_label:
		title_label.add_theme_font_size_override("font_size", 12)  # Was 14
	if cost_label:
		cost_label.add_theme_font_size_override("font_size", 11)  # Was 12
	if damage_button:
		damage_button.add_theme_font_size_override("font_size", 9)  # Was 10
		damage_button.pressed.connect(_on_damage_button_pressed)
	if range_button:
		range_button.add_theme_font_size_override("font_size", 9)  # Was 10
		range_button.pressed.connect(_on_range_button_pressed)

	# Connect to gold changes
	GameStateManager.gold_changed.connect(_on_gold_changed)

	# Update button states
	update_button_states()

func setup(tower_ref):
	"""Initialize the menu with tower data"""
	tower = tower_ref

	if is_inside_tree():
		update_button_states()

func _on_gold_changed(_new_amount):
	update_button_states()

func update_button_states():
	"""Enable/disable buttons based on gold"""
	var can_afford = GameStateManager.gold >= path_choice_cost

	if damage_button:
		damage_button.disabled = not can_afford and not is_damage_preview
	if range_button:
		range_button.disabled = not can_afford and not is_range_preview

	# Update cost label color
	if cost_label:
		if can_afford:
			cost_label.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			cost_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

func _on_damage_button_pressed():
	print("\n=== 🔥 DAMAGE PATH BUTTON PRESSED ===")

	# TWO-CLICK SYSTEM
	if not is_damage_preview:
		# FIRST CLICK: Enter preview mode
		print("🔥 [PathChoiceMenu] First click - entering DAMAGE preview mode")
		_enter_damage_preview()
	else:
		# SECOND CLICK: Confirm choice
		print("🔥 [PathChoiceMenu] Second click - confirming DAMAGE path")
		_confirm_damage_path()

func _on_range_button_pressed():
	print("\n=== 🎯 RANGE PATH BUTTON PRESSED ===")

	# TWO-CLICK SYSTEM
	if not is_range_preview:
		# FIRST CLICK: Enter preview mode
		print("🎯 [PathChoiceMenu] First click - entering RANGE preview mode")
		_enter_range_preview()
	else:
		# SECOND CLICK: Confirm choice
		print("🎯 [PathChoiceMenu] Second click - confirming RANGE path")
		_confirm_range_path()

func _enter_damage_preview():
	"""First click on Damage Path: Show preview"""
	is_damage_preview = true
	is_range_preview = false

	# Visual feedback - highlight selected button
	if damage_button:
		damage_button.modulate = Color(1.2, 1.0, 0.8)  # Orange tint
	if range_button:
		range_button.modulate = Color(0.7, 0.7, 0.7)  # Dim the other

	# Update title
	if title_label:
		title_label.text = "Damage Path Selected - Click Again to Confirm"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))

	print("✅ [PathChoiceMenu] Damage preview mode active")

func _enter_range_preview():
	"""First click on Range Path: Show preview"""
	is_range_preview = true
	is_damage_preview = false

	# Visual feedback - highlight selected button
	if range_button:
		range_button.modulate = Color(0.8, 1.0, 1.2)  # Blue tint
	if damage_button:
		damage_button.modulate = Color(0.7, 0.7, 0.7)  # Dim the other

	# Update title
	if title_label:
		title_label.text = "Range Path Selected - Click Again to Confirm"
		title_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))

	print("✅ [PathChoiceMenu] Range preview mode active")

func _confirm_damage_path():
	"""Second click: Actually choose Damage Path"""
	if not tower:
		return

	print("🔥 [PathChoiceMenu] Confirming DAMAGE path")
	print("🔥 [PathChoiceMenu] Cost: %d gold" % path_choice_cost)
	print("🔥 [PathChoiceMenu] Current gold: %d gold" % GameStateManager.gold)

	if GameStateManager.spend_gold(path_choice_cost):
		print("✅ [PathChoiceMenu] Gold spent successfully!")
		print("🔥 [PathChoiceMenu] Emitting damage_path_selected signal...")
		damage_path_selected.emit(tower)
		print("=== ✅ DAMAGE PATH CHOSEN ===\n")
	else:
		print("❌ [PathChoiceMenu] Not enough gold!")
		print("   Need: %d, Have: %d" % [path_choice_cost, GameStateManager.gold])

func _confirm_range_path():
	"""Second click: Actually choose Range Path"""
	if not tower:
		return

	print("🎯 [PathChoiceMenu] Confirming RANGE path")
	print("🎯 [PathChoiceMenu] Cost: %d gold" % path_choice_cost)
	print("🎯 [PathChoiceMenu] Current gold: %d gold" % GameStateManager.gold)

	if GameStateManager.spend_gold(path_choice_cost):
		print("✅ [PathChoiceMenu] Gold spent successfully!")
		print("🎯 [PathChoiceMenu] Emitting range_path_selected signal...")
		range_path_selected.emit(tower)
		print("=== ✅ RANGE PATH CHOSEN ===\n")
	else:
		print("❌ [PathChoiceMenu] Not enough gold!")
		print("   Need: %d, Have: %d" % [path_choice_cost, GameStateManager.gold])

func _gui_input(event):
	"""Handle input on this control - consume events inside menu"""
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var is_press = false
		if event is InputEventMouseButton:
			is_press = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			is_press = event.pressed

		if is_press:
			print("⏸️ [PathChoiceMenu] Click inside menu - consuming event")
			accept_event()

func _unhandled_input(event):
	"""Close menu when clicking outside"""
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var is_click = false
		if event is InputEventMouseButton:
			is_click = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		elif event is InputEventScreenTouch:
			is_click = event.pressed

		if is_click:
			# Cancel any preview
			if is_damage_preview or is_range_preview:
				print("❌ [PathChoiceMenu] Canceling preview - clicked outside")

			print("✅ [PathChoiceMenu] Closing menu - clicked outside")
			menu_closed.emit()
			get_viewport().set_input_as_handled()
			queue_free()
