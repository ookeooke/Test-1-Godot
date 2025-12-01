@tool
extends EditorScript

func _run():
	# 1. Get the level root
	var level = get_scene()
	if not level:
		print("Error: Open level_01.tscn in the editor first!")
		return

	# 2. Find the existing Path2D to use as reference
	var path_2d = level.get_node("EnemyPath")
	if not path_2d:
		print("Error: Could not find EnemyPath node!")
		return

	# 3. Create a container for Waypoints
	var waypoints_container = level.get_node_or_null("Waypoints")
	if not waypoints_container:
		waypoints_container = Node2D.new()
		waypoints_container.name = "Waypoints"
		level.add_child(waypoints_container)
		waypoints_container.owner = level
		print("Created Waypoints container")

	# 4. Generate Waypoints from Curve Points
	var curve = path_2d.curve
	var point_count = curve.get_point_count()
	var created_waypoints = []

	for i in range(point_count):
		var pos = path_2d.to_global(curve.get_point_position(i))
		
		var waypoint = PathWaypoint.new()
		waypoint.name = "Waypoint_%d" % i
		waypoint.position = pos
		waypoint.road_width = 80.0 # Default road width
		
		waypoints_container.add_child(waypoint)
		waypoint.owner = level
		created_waypoints.append(waypoint)
		print("Created Waypoint_%d at %s" % [i, pos])

	# 5. Link Waypoints
	for i in range(created_waypoints.size() - 1):
		var current = created_waypoints[i]
		var next = created_waypoints[i + 1]
		current.next_waypoints = [next]
		print("Linked %s -> %s" % [current.name, next.name])

	# 6. Assign Start Waypoint to WaveManager
	var wave_manager = level.get_node("WaveManager")
	if wave_manager:
		wave_manager.start_waypoint = created_waypoints[0]
		wave_manager.use_waypoint_system = true # Enable the system!
		print("Assigned Start Waypoint to WaveManager and ENABLED system")

	print("✅ Waypoint generation complete!")
