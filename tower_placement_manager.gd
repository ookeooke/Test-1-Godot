extends Node2D

@export var placement_spots_parent: Node
@export var archer_tower_scene: PackedScene
@export var archer_tower_cost: int = 100

func _ready():
	if placement_spots_parent == null:
		print("ERROR: Placement spots parent not assigned!")
		return
	
	setup_all_spots()

func setup_all_spots():
	for spot in placement_spots_parent.get_children():
		if spot is Node2D and spot.has_method("try_place_tower"):
			spot.tower_scene = archer_tower_scene
			spot.tower_cost = archer_tower_cost
			
			spot.tower_placed.connect(_on_tower_placed.bindv([spot]))
			spot.tower_placement_failed.connect(_on_tower_placement_failed.bindv([spot]))
			
			print("Configured placement spot: ", spot.name)

func _on_tower_placed(tower: Node2D, cost: int, spot: Node2D):
	print("Tower placed at spot: ", spot.name, " | Cost: ", cost)

func _on_tower_placement_failed(reason: String, spot: Node2D):
	print("Placement failed at ", spot.name, ": ", reason)
