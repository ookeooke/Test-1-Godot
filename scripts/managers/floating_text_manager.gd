extends Node
class_name FloatingTextManager

## FloatingTextManager
## Static manager for handling floating text (damage numbers, etc.)
## Centralizes creation and cleanup to prevent memory leaks and visual clutter.

# Static list to track all active labels
static var active_labels: Array[Label] = []

## Spawn a floating damage number
static func spawn_damage_number(value: float, position: Vector2, parent: Node) -> void:
	if not is_instance_valid(parent):
		return

	# Create label
	var label = Label.new()
	label.global_position = position + Vector2(randf_range(-10, 10), -30)
	
	# Format text
	var damage_int = int(round(value))
	label.text = str(damage_int)
	
	# Styling
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 100 # Above most things
	
	# Color based on damage
	if value >= 20:
		label.modulate = Color(1.0, 0.3, 0.3) # Red
	elif value >= 10:
		label.modulate = Color(1.0, 0.7, 0.2) # Orange
	else:
		label.modulate = Color(1.0, 1.0, 0.5) # Yellow
		
	# Add to scene and tracking
	parent.add_child(label)
	active_labels.append(label)
	
	# Animate
	# IMPORTANT: Create tween on the LABEL, not the parent.
	# This ensures the tween is killed if the label is freed (preventing "Lambda capture freed" errors)
	var tween = label.create_tween()
	tween.set_parallel(true)
	
	# Float up
	tween.tween_property(label, "global_position:y", label.global_position.y - 50, 0.8).set_ease(Tween.EASE_OUT)
	
	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	
	# Scale pop
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(0.8, 0.8), 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
	
	# Cleanup
	tween.finished.connect(func():
		if is_instance_valid(label):
			active_labels.erase(label)
			label.queue_free()
	)

## Clear all active floating text
## Call this on level restart/exit
static func clear_all_text() -> void:
	var count = 0
	for label in active_labels:
		if is_instance_valid(label):
			label.queue_free()
			count += 1
	active_labels.clear()
	print("[FloatingTextManager] Cleared %d active text labels" % count)
