extends Node2D

# ============================================
# TOWER PLACEMENT
# ============================================

var tower_to_place = preload("res://scenes/towers/archer_tower.tscn")
var tower_cost = 100

func _ready():
	# Wait one frame for nodes to be ready
	await get_tree().process_frame
	setup_placement_zones()

func setup_placement_zones():
	# Get all placement zones (they're children of this node)
	for zone in get_children():
		var click_area = zone.get_node_or_null("ClickArea")
		if click_area:
			click_area.input_event.connect(_on_placement_zone_clicked.bind(zone))
			print("Connected placement zone: ", zone.name)

func _on_placement_zone_clicked(viewport, event, shape_idx, zone):
	# Called when player clicks a placement zone
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_tower_at(zone)

func place_tower_at(zone):
	# Try to place a tower
	print("Trying to place tower at: ", zone.global_position)
	
	# Check if player has enough gold
	if not GameManager.spend_gold(tower_cost):
		print("Not enough gold! Need ", tower_cost)
		return
	
	# Create tower
	var tower = tower_to_place.instantiate()
	get_parent().add_child(tower)  # Add to parent (TestLevel) not this node
	tower.global_position = zone.global_position
	
	# Disable this placement zone
	zone.queue_free()
	
	print("Tower placed!")
