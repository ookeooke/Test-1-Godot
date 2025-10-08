# ============================================
# TOWER_PLACEMENT_SPOT.GD
# ============================================
# Simple spot where player can click to place towers
# Expandable for different tower types or upgrades

extends Node2D

# ============================================
# SIGNALS
# ============================================
signal tower_placed(tower, cost)
signal tower_placement_failed(reason)

# ============================================
# EXPORTS (Configure in Inspector)
# ============================================
@export var tower_scene: PackedScene  # Drag tower scene here
@export var tower_cost: int = 100
@export var can_place: bool = true

# ============================================
# INTERNAL REFERENCES
# ============================================
var click_area: Area2D
var visual_rect: ColorRect
var is_hovered: bool = false
var current_tower: Node2D = null

# ============================================
# BUILT-IN FUNCTIONS
# ============================================

func _ready():
	# Create the click area
	click_area = Area2D.new()
	click_area.name = "ClickArea"
	click_area.collision_layer = 0  # Don't collide with anything
	click_area.collision_mask = 0   # Don't detect anything physically
	add_child(click_area)
	
	# Create collision shape
	var shape = CircleShape2D.new()
	shape.radius = 40
	var collision = CollisionShape2D.new()
	collision.shape = shape
	click_area.add_child(collision)
	
	# Create visual indicator
	visual_rect = ColorRect.new()
	visual_rect.size = Vector2(80, 80)
	visual_rect.position = -Vector2(40, 40)
	visual_rect.color = Color.BLUE if can_place else Color.GRAY
	visual_rect.modulate.a = 0.5  # Semi-transparent
	add_child(visual_rect)
	
	# Add label
	var label = Label.new()
	label.text = "PLACE"
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.offset_left = -20
	label.offset_top = -10
	visual_rect.add_child(label)
	
	# Connect signals
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)

func _process(delta):
	# Update visual based on hover state
	if can_place:
		if is_hovered:
			visual_rect.modulate.a = 0.8
			visual_rect.color = Color.GREEN
		else:
			visual_rect.modulate.a = 0.5
			visual_rect.color = Color.BLUE
	else:
		visual_rect.color = Color.GRAY
		visual_rect.modulate.a = 0.3

# ============================================
# PLACEMENT LOGIC
# ============================================

func try_place_tower():
	# Check if already has tower
	if current_tower != null:
		tower_placement_failed.emit("Spot already occupied")
		return
	
	# Check if can place
	if not can_place:
		tower_placement_failed.emit("Cannot place tower here")
		return
	
	# Check if tower scene is assigned
	if tower_scene == null:
		tower_placement_failed.emit("Tower scene not assigned")
		print("ERROR: Tower scene not assigned to spot!")
		return
	
	# Try to spend gold
	if not GameManager.spend_gold(tower_cost):
		tower_placement_failed.emit("Not enough gold")
		return
	
	# Place the tower
	place_tower()

func place_tower():
	# Create tower
	current_tower = tower_scene.instantiate()
	add_child(current_tower)
	
	# Hide placement indicator
	visual_rect.hide()
	can_place = false
	
	# Emit signal
	tower_placed.emit(current_tower, tower_cost)
	print("Tower placed at: ", global_position)

func remove_tower():
	# For later features like selling towers
	if current_tower != null:
		current_tower.queue_free()
		current_tower = null
	
	# Show placement indicator again
	visual_rect.show()
	can_place = true
	print("Tower removed from: ", global_position)

# ============================================
# INPUT HANDLING
# ============================================

func _on_mouse_entered():
	if can_place:
		is_hovered = true

func _on_mouse_exited():
	is_hovered = false

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if can_place:
				try_place_tower()

# ============================================
# GETTERS
# ============================================

func has_tower() -> bool:
	return current_tower != null

func get_tower() -> Node2D:
	return current_tower
