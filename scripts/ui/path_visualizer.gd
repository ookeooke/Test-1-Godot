extends Line2D
## Visualizes a Path2D curve as a Line2D for in-game display
## Auto-syncs with the parent Path2D when the curve changes

func _ready() -> void:
	var path = get_parent() as Path2D
	if path and path.curve:
		update_line(path.curve)
		# Connect to curve changes so editor updates are reflected in real-time
		path.curve.changed.connect(func(): update_line(path.curve))

func update_line(curve: Curve2D) -> void:
	# Get baked points from the curve (smooth approximation)
	points = curve.get_baked_points()
