extends Control

## Loot Distribution Screen - Option D Hybrid System
## Shows all loot collected during mission
## Allows player to distribute items to heroes or store in inventory

signal loot_distributed
signal continue_to_victory

@onready var loot_grid: GridContainer = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/LootPanel/VBox/ScrollContainer/LootGrid
@onready var item_count_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/StatsContainer/ItemCountLabel
@onready var gold_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/StatsContainer/GoldLabel
@onready var common_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/RarityBreakdown/CommonLabel
@onready var uncommon_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/RarityBreakdown/UncommonLabel
@onready var rare_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/RarityBreakdown/RareLabel
@onready var epic_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/RarityBreakdown/EpicLabel
@onready var legendary_label: Label = $MainPanel/MarginContainer/VBoxContainer/ContentHBox/SummaryPanel/VBox/RarityBreakdown/LegendaryLabel
@onready var take_all_button: Button = $MainPanel/MarginContainer/VBoxContainer/ButtonsHBox/TakeAllButton
@onready var continue_button: Button = $MainPanel/MarginContainer/VBoxContainer/ButtonsHBox/ContinueButton

# Loot data
var loot_items: Array = []
var total_gold_earned: int = 0

# Item slot scene for displaying items
const ITEM_SLOT_SCENE = preload("res://scenes/ui/item_slot.tscn")


func _ready():
	# Connect buttons
	take_all_button.pressed.connect(_on_take_all_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	# Load and display loot
	_load_loot_data()
	_display_loot()
	_update_summary()

	# Animate entrance
	_animate_entrance()


func _load_loot_data():
	"""Load all pending loot from LootManager"""
	loot_items = LootManager.get_pending_loot_with_data()
	total_gold_earned = SaveManager.get_currency() - SaveManager.get_currency()  # Will track delta later

	print("[LootDistScreen] Loaded %d items for distribution" % loot_items.size())


func _display_loot():
	"""Display all loot items in the grid"""
	# Clear existing items
	for child in loot_grid.get_children():
		child.queue_free()

	# Create item slots for each loot item
	for loot in loot_items:
		var item_slot = _create_loot_item_slot(loot)
		if item_slot:
			loot_grid.add_child(item_slot)

	# If no items, show message
	if loot_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No items found this mission"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		loot_grid.add_child(empty_label)


func _create_loot_item_slot(loot: Dictionary) -> Control:
	"""Create a visual slot for a loot item"""
	var item_data: ItemData = loot.item_data
	var quantity: int = loot.quantity

	# Try to use existing ItemSlot scene
	if ITEM_SLOT_SCENE:
		var item_slot = ITEM_SLOT_SCENE.instantiate()
		# Set the item data
		if item_slot.has_method("set_item"):
			item_slot.set_item(loot.item_id, quantity)
		elif item_slot.has_method("setup"):
			item_slot.setup(loot.item_id, quantity)
		return item_slot
	else:
		# Fallback: create simple panel
		return _create_simple_item_display(item_data, quantity)


func _create_simple_item_display(item_data: ItemData, quantity: int) -> PanelContainer:
	"""Fallback: create simple item display"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 100)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Icon (colored square)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = item_data.get_rarity_color()
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	# Name label
	var name_label = Label.new()
	name_label.text = item_data.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.modulate = item_data.get_rarity_color()
	vbox.add_child(name_label)

	# Quantity label
	if quantity > 1:
		var qty_label = Label.new()
		qty_label.text = "x%d" % quantity
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(qty_label)

	return panel


func _update_summary():
	"""Update the summary panel with loot statistics"""
	# Count items by rarity
	var rarity_counts = {
		ItemData.Rarity.COMMON: 0,
		ItemData.Rarity.UNCOMMON: 0,
		ItemData.Rarity.RARE: 0,
		ItemData.Rarity.EPIC: 0,
		ItemData.Rarity.LEGENDARY: 0
	}

	for loot in loot_items:
		var item_data: ItemData = loot.item_data
		if rarity_counts.has(item_data.rarity):
			rarity_counts[item_data.rarity] += loot.quantity

	# Update labels
	item_count_label.text = "Items: %d" % loot_items.size()
	gold_label.text = "Gold Earned: %d" % total_gold_earned

	# Update rarity breakdown
	common_label.text = "Common: %d" % rarity_counts[ItemData.Rarity.COMMON]
	common_label.modulate = _get_rarity_color(ItemData.Rarity.COMMON)

	uncommon_label.text = "Uncommon: %d" % rarity_counts[ItemData.Rarity.UNCOMMON]
	uncommon_label.modulate = _get_rarity_color(ItemData.Rarity.UNCOMMON)

	rare_label.text = "Rare: %d" % rarity_counts[ItemData.Rarity.RARE]
	rare_label.modulate = _get_rarity_color(ItemData.Rarity.RARE)

	epic_label.text = "Epic: %d" % rarity_counts[ItemData.Rarity.EPIC]
	epic_label.modulate = _get_rarity_color(ItemData.Rarity.EPIC)

	legendary_label.text = "Legendary: %d" % rarity_counts[ItemData.Rarity.LEGENDARY]
	legendary_label.modulate = _get_rarity_color(ItemData.Rarity.LEGENDARY)


func _get_rarity_color(rarity: ItemData.Rarity) -> Color:
	"""Get color for a rarity tier"""
	match rarity:
		ItemData.Rarity.COMMON:
			return Color(0.8, 0.8, 0.8)  # Gray
		ItemData.Rarity.UNCOMMON:
			return Color(0.3, 1.0, 0.3)  # Green
		ItemData.Rarity.RARE:
			return Color(0.3, 0.5, 1.0)  # Blue
		ItemData.Rarity.EPIC:
			return Color(0.8, 0.3, 1.0)  # Purple
		ItemData.Rarity.LEGENDARY:
			return Color(1.0, 0.6, 0.1)  # Orange
	return Color.WHITE


func _animate_entrance():
	"""Animate screen entrance"""
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_take_all_pressed():
	"""Take all items to inventory and continue"""
	print("[LootDistScreen] Taking all items to inventory...")

	# Distribute all pending loot to inventory
	var result = LootManager.distribute_pending_loot_to_inventory()

	# Show feedback
	if result.items_added > 0:
		print("[LootDistScreen] Added %d items to inventory" % result.items_added)

	if result.items_failed > 0:
		push_warning("[LootDistScreen] Failed to add %d items (inventory full?)" % result.items_failed)

	# Emit signal and close
	loot_distributed.emit()
	_transition_to_victory()


func _on_continue_pressed():
	"""Continue to victory screen (items already distributed or skipped)"""
	print("[LootDistScreen] Continuing to victory screen...")

	# For now, also distribute items to inventory (could be changed to "forfeit" logic)
	if loot_items.size() > 0:
		LootManager.distribute_pending_loot_to_inventory()

	continue_to_victory.emit()
	_transition_to_victory()


func _transition_to_victory():
	"""Animate transition to victory screen"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	await tween.finished

	queue_free()


## Public API for external control

func set_gold_earned(amount: int):
	"""Set the gold earned this mission (called before showing screen)"""
	total_gold_earned = amount
	if is_node_ready():
		_update_summary()


func refresh_display():
	"""Refresh the loot display (if items changed)"""
	_load_loot_data()
	_display_loot()
	_update_summary()
