extends Node2D

# ============================================
# TOWER_PLACEMENT_SPOT.GD
# ============================================

signal tower_placed(tower, cost)
signal tower_placement_failed(reason)

@export var tower_scene: PackedScene
@export var tower_cost: int = 100
@export var can_place: bool = true

var click_area: Area2D
var visual_rect: ColorRect
var is_hovered: bool = false
var current_tower: Node2D = null

func _ready():
	click_area = Area2D.new()
	click_area.name = "ClickArea"
	click_area.collision_layer = 0
	click_area.collision_mask = 0
	add_child(click_area)
	
	var shape = CircleShape2D.new()
	shape.radius = 40
	var collision = CollisionShape2D.new()
	collision.shape = shape
	click_area.add_child(collision)
	
	visual_rect = ColorRect.new()
	visual_rect.size = Vector2(80, 80)
	visual_rect.position = -Vector2(40, 40)
	visual_rect.color = Color.BLUE if can_place else Color.GRAY
	visual_rect.modulate.a = 0.5
	add_child(visual_rect)
	
	var label = Label.new()
	label.text = "PLACE"
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.offset_left = -20
	label.offset_top = -10
	visual_rect.add_child(label)
	
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	click_area.input_event.connect(_on_input_event)

func _process(delta):
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

func try_place_tower():
	if current_tower != null:
		tower_placement_failed.emit("Spot already occupied")
		return
	
	if not can_place:
		tower_placement_failed.emit("Cannot place tower here")
		return
	
	if tower_scene == null:
		tower_placement_failed.emit("Tower scene not assigned")
		print("ERROR: Tower scene not assigned to spot!")
		return
	
	if not GameManager.spend_gold(tower_cost):
		tower_placement_failed.emit("Not enough gold")
		return
	
	place_tower()

func place_tower():
	current_tower = tower_scene.instantiate()
	add_child(current_tower)
	
	visual_rect.hide()
	can_place = false
	
	tower_placed.emit(current_tower, tower_cost)
	print("Tower placed at: ", global_position)

func remove_tower():
	if current_tower != null:
		current_tower.queue_free()
		current_tower = null
	
	visual_rect.show()
	can_place = true
	print("Tower removed from: ", global_position)

func has_tower() -> bool:
	return current_tower != null

func get_tower() -> Node2D:
	return current_tower

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
