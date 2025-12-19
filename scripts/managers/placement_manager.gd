extends Node2D

# ============================================
# PLACEMENT MANAGER - Handles tower spots and menus
# ============================================

var tower_info_menu_scene = preload("res://scenes/ui/tower_info_menu.tscn") # LEGACY - kept for reference
var ring_menu_script = preload("res://scripts/ui/ring_menu.gd")
var ring_upgrade_menu_script = preload("res://scripts/ui/ring_upgrade_menu.gd") # NEW
var current_menu = null
var current_spot = null
var current_selected_tower = null # Track selected tower for deselection

# MENU LAYER - CanvasLayer for zoom-independent UI
var menu_layer: Control # Reference to MenuContainer in CanvasLayer

# CAMERA - for input locking (Kingdom Rush style)
var camera: Camera2D

# ROAD RENDERER - for soldier placement validation
var road_renderer: RoadRenderer = null

func _ready():
	await get_tree().process_frame

	# Get reference to MenuContainer in CanvasLayer
	# MenuLayer is a sibling node in the level scene
	# The scene structure is: MenuLayer (CanvasLayer) -> MenuContainer (Control)
	var parent_node = get_parent()
	if parent_node.has_node("MenuLayer/MenuContainer"):
		menu_layer = parent_node.get_node("MenuLayer/MenuContainer")
		print("✓ MenuLayer found successfully!")
	else:
		push_error("MenuLayer/MenuContainer not found! Menus will not work correctly.")
		print("Looking for: MenuLayer/MenuContainer")
		print("Parent node: ", parent_node.name)
		print("Available children: ", parent_node.get_children())

	# Get reference to camera for input locking
	camera = get_viewport().get_camera_2d()
	if camera:
		print("✓ Camera found successfully!")
	else:
		push_error("Camera2D not found! Camera locking will not work.")

	# Get reference to road renderer for soldier placement validation
	road_renderer = get_tree().get_first_node_in_group("road_renderer")
	if road_renderer:
		print("✓ RoadRenderer found - soldier placement validation enabled!")
	else:
		print("⚠ RoadRenderer not found - soldier placement validation disabled")

	connect_tower_spots()

func connect_tower_spots():
	var spots = get_tree().get_nodes_in_group("tower_spot")

	for spot in spots:
		if spot.has_signal("spot_clicked"):
			spot.spot_clicked.connect(_on_tower_spot_clicked)
		if spot.has_signal("tower_clicked"):
			spot.tower_clicked.connect(_on_tower_clicked)

func _on_tower_spot_clicked(spot):
	"""Handle clicks on empty tower spots"""
	close_current_menu()
	current_spot = spot
	show_ring_menu(spot)

func _on_tower_clicked(spot, tower):
	"""Handle clicks on existing towers"""
	# Deselect previously selected tower
	_deselect_current_tower()

	close_current_menu()
	current_spot = spot
	current_selected_tower = tower

	# Show tower range indicator
	if tower and tower.has_method("select_tower"):
		tower.select_tower()

	show_tower_info_menu(spot, tower)

func close_current_menu():
	"""Close any open menu"""
	# Deselect tower before closing menu
	_deselect_current_tower()

	if current_menu:
		current_menu.queue_free()
		current_menu = null

	# Unlock camera input
	_unlock_camera()

	current_selected_tower = null

func show_ring_menu(spot):
	"""Show the ring menu for tower selection (Phase 3B)"""
	# Create ring menu programmatically
	current_menu = Control.new()
	current_menu.set_script(ring_menu_script)

	# ADD TO CANVAS LAYER (screen space), not root (world space)
	menu_layer.add_child(current_menu)

	# Open ring menu at tower spot position
	var screen_pos = spot.get_global_transform_with_canvas().origin
	var loadout = TowerData.get_all_tower_ids()
	current_menu.open_at_position(screen_pos, loadout)

	# Lock camera input (Kingdom Rush style)
	_lock_camera()

	# Connect signals
	current_menu.tower_selected.connect(_on_tower_selected)
	current_menu.menu_closed.connect(_on_menu_closed)

func show_tower_info_menu(spot, tower):
	"""Show the ring-based tower upgrade menu"""
	# Create ring upgrade menu programmatically
	current_menu = Control.new()
	current_menu.set_script(ring_upgrade_menu_script)

	# ADD TO CANVAS LAYER (screen space), not root (world space)
	menu_layer.add_child(current_menu)

	# Wait for menu to initialize
	await get_tree().process_frame

	# Get screen position of tower spot
	var world_pos = spot.global_position
	var screen_pos = get_viewport().get_canvas_transform() * world_pos

	# Open ring upgrade menu at tower position
	current_menu.open_for_tower(screen_pos, tower, spot)

	# Lock camera input (Kingdom Rush style)
	_lock_camera()

	# Connect signals (same as before)
	current_menu.upgrade_selected.connect(_on_tower_upgraded)
	current_menu.sell_selected.connect(_on_tower_sold)
	current_menu.menu_closed.connect(_on_menu_closed)
	current_menu.damage_path_chosen.connect(_on_damage_path_chosen)
	current_menu.range_path_chosen.connect(_on_range_path_chosen)
	current_menu.targeting_mode_changed.connect(_on_targeting_mode_changed)
	current_menu.rally_mode_entered.connect(_on_rally_mode_entered)

func position_menu_in_screen_space(spot):
	"""Position menu in screen space, following tower spot but zoom-independent (Kingdom Rush style)"""

	# STEP 1: Get tower spot world position
	var world_pos = spot.global_position
	print("🎯 Menu Positioning:")
	print("  Tower spot world position: ", world_pos)

	# STEP 2: Convert world position to screen position using Godot's canvas transform
	# BEST PRACTICE: Use get_canvas_transform() which handles all transformations automatically
	var screen_pos: Vector2

	if get_viewport().get_camera_2d():
		# Use Godot's built-in transform (handles camera position, zoom, rotation)
		screen_pos = get_viewport().get_canvas_transform() * world_pos
		print("  Using get_canvas_transform()")
		print("  Camera position: ", get_viewport().get_camera_2d().global_position)
		print("  Camera zoom: ", get_viewport().get_camera_2d().zoom)
		print("  Tower screen position: ", screen_pos)
	else:
		# Fallback if no camera (center of screen)
		screen_pos = get_viewport().get_visible_rect().size / 2
		print("  No camera - using screen center")

	# STEP 3: Smart offset based on tower position (Option 3)
	# Detect if tower is near screen edges and adjust menu placement accordingly
	var viewport_size = get_viewport().get_visible_rect().size
	var menu_size = current_menu.size
	print("  Menu size at positioning: ", menu_size)

	# Define "danger zones" - areas near screen edges (200px threshold)
	var edge_threshold = 200.0
	var near_top = screen_pos.y < edge_threshold
	var _near_bottom = screen_pos.y > viewport_size.y - edge_threshold
	var near_left = screen_pos.x < edge_threshold
	var near_right = screen_pos.x > viewport_size.x - edge_threshold

	# Apply smart offset (Kingdom Rush style: above by default, below if near top)
	if near_top:
		screen_pos.y += 100 # Place BELOW tower (near top edge)
		print("  Tower near top edge - placing menu BELOW")
	else:
		screen_pos.y -= 100 # Place ABOVE tower (default)
		print("  Placing menu ABOVE tower")

	# Adjust horizontal offset if near left/right edges
	if near_left:
		screen_pos.x += 50 # Push menu right
		print("  Tower near left edge - pushing menu RIGHT")
	elif near_right:
		screen_pos.x -= 50 # Push menu left
		print("  Tower near right edge - pushing menu LEFT")

	print("  After smart offset: ", screen_pos)

	# STEP 4: Clamp to screen edges (Option 1 - FIXED LOGIC)
	# Calculate actual menu bounds (top-left and bottom-right corners)
	var margin = 20.0
	var menu_top_left = screen_pos - menu_size / 2
	var menu_bottom_right = screen_pos + menu_size / 2

	# Clamp horizontally (check actual menu bounds)
	if menu_top_left.x < margin:
		screen_pos.x = menu_size.x / 2 + margin
		print("  Clamped: Menu too far LEFT")
	elif menu_bottom_right.x > viewport_size.x - margin:
		screen_pos.x = viewport_size.x - menu_size.x / 2 - margin
		print("  Clamped: Menu too far RIGHT")

	# Clamp vertically (check actual menu bounds)
	if menu_top_left.y < margin:
		screen_pos.y = menu_size.y / 2 + margin
		print("  Clamped: Menu too far UP (off top edge)")
	elif menu_bottom_right.y > viewport_size.y - margin:
		screen_pos.y = viewport_size.y - menu_size.y / 2 - margin
		print("  Clamped: Menu too far DOWN (off bottom edge)")

	# STEP 5: Center the menu at calculated position
	current_menu.position = screen_pos - menu_size / 2
	print("  Final menu position (top-left): ", current_menu.position)
	print("  Final menu bounds: ", Rect2(current_menu.position, menu_size))
	print("  ✅ Menu positioned and guaranteed visible!")

func _on_tower_selected(tower_id: String):
	"""Handle tower build selection from ring menu

	Args:
		tower_id: Tower ID string (e.g., "archer", "barracks")
	"""
	if current_spot:
	# Load tower scene from TowerData database
		var tower_scene = TowerData.get_tower_scene(tower_id)

		if tower_scene == null:
			push_error("[PlacementManager] Failed to load tower scene for: %s" % tower_id)
			close_current_menu()
			current_spot = null
			return

		# VALIDATE COST
		var build_cost = TowerData.get_build_cost(tower_id)
		if not GameStateManager.spend_gold(build_cost):
			print("❌ [PlacementManager] Cannot afford tower! Cost: %d" % build_cost)
			# TODO: Add UI feedback (flash red, sound)
			close_current_menu()
			current_spot = null
			return
		
		print("💰 [PlacementManager] Spent %d gold for tower %s" % [build_cost, tower_id])

		# Check if this is a soldier tower and validate placement

		if _is_soldier_tower(tower_scene):
			if not _can_place_soldier_tower_here(current_spot.global_position):
				print("❌ Cannot place soldier tower here - not on road!")
				# Show error message to player (you can add UI feedback here)
				close_current_menu()
				current_spot = null
				return

		current_spot.place_tower(tower_scene)

		# CHANGED: Close menu AFTER placing tower (fixes race condition)
		close_current_menu()
		current_spot = null
	else:
		print("ERROR: No current spot!")

func _is_soldier_tower(tower_scene: PackedScene) -> bool:
	"""Check if a tower scene is a soldier/garrison tower"""
	var scene_path = tower_scene.resource_path
	return "soldier" in scene_path.to_lower() or "garrison" in scene_path.to_lower()

func _can_place_soldier_tower_here(check_pos: Vector2) -> bool:
	"""Check if a position is valid for soldier tower placement (on road)"""
	if not road_renderer:
		# No road renderer = allow placement anywhere (backward compatibility)
		print("⚠ No road renderer - allowing soldier placement")
		return true

	# Check if position is on road (with 30px tolerance)
	var on_road = road_renderer.is_point_on_road(check_pos, 30.0)

	if on_road:
		print("✅ Position is on road - soldier placement allowed")
	else:
		print("❌ Position is NOT on road - soldier placement blocked")

	return on_road

func _on_tower_upgraded(tower):
	"""Handle tower upgrade"""
	print("\n=== 🔧 PLACEMENT MANAGER UPGRADE HANDLER ===")
	print("🔧 [PlacementManager] _on_tower_upgraded() called")
	print("🔧 [PlacementManager] Tower valid: %s" % str(is_instance_valid(tower)))

	if not tower or not is_instance_valid(tower):
		print("❌ [PlacementManager] ERROR: Tower is null or invalid!")
		print("=== ❌ UPGRADE ABORTED ===\n")
		return

	print("🔧 [PlacementManager] Tower is valid - proceeding")

	# NOTE: Path choice (Level 3) is handled directly by tower_info_menu.gd
	# The menu shows path buttons when tower.needs_path_choice() is true
	# No special handling needed here - upgrade system works for all levels

	# Standard upgrade (level 1→2→3)
	if tower.has_method("upgrade_tower"):
		# CRITICAL: CHECK AFFORDABILITY AND SPEND GOLD BEFORE UPGRADING
		# Tower.upgrade_tower() calculates cost but doesn't deduct it from GameStateManager
		# 1. Get upgrade cost
		var upgrade_cost = 0
		if tower.has_method("get_upgrade_cost"):
			upgrade_cost = tower.get_upgrade_cost()
		else:
			push_warning("[PlacementManager] Tower missing get_upgrade_cost() - assuming free upgrade")
			
		# 2. Check affordability
		if not GameStateManager.can_afford(upgrade_cost):
			print("❌ [PlacementManager] Cannot afford upgrade! Cost: %d" % upgrade_cost)
			# Only show UI feedback if not afford
			# TODO: Flash red or screen shake
			return

		# 3. Spend Gold
		if GameStateManager.spend_gold(upgrade_cost):
			print("💰 [PlacementManager] Spent %d gold for upgrade" % upgrade_cost)
			
			# 4. Perform Upgrade
			print("🔧 [PlacementManager] Calling tower.upgrade_tower()...")
			var upgrade_result = tower.upgrade_tower()
			print("🔧 [PlacementManager] upgrade_tower() returned: %s" % str(upgrade_result))

			if upgrade_result:
				print("✅ [PlacementManager] Tower upgraded successfully to level %d" % tower.tower_level)
				print("🔧 [PlacementManager] Closing menu after upgrade (Kingdom Rush style)...")
				close_current_menu()
				print("=== ✅ UPGRADE SUCCESS ===\n")
			else:
				# Refund if upgrade failed for game logic reasons (e.g. max level)
				GameStateManager.add_gold(upgrade_cost)
				push_error("[PlacementManager] Tower upgrade failed after payment! Refunded %d gold." % upgrade_cost)
				print("=== ❌ UPGRADE FAILED (REFUNDED) ===\n")
		else:
			print("❌ [PlacementManager] Failed to spend gold (race condition?)")
			
	else:
		print("⚠️ [PlacementManager] Tower does NOT have upgrade_tower() method!")
		# Fallback for towers without upgrade system
		if "damage" in tower:
			tower.damage += 5
			print("[PlacementManager] Legacy tower upgraded (damage +5)")
			print("=== ✅ LEGACY UPGRADE COMPLETE ===\n")
		else:
			print("❌ [PlacementManager] Cannot upgrade - no upgrade_tower() method and no damage property!")
			print("=== ❌ UPGRADE IMPOSSIBLE ===\n")

func _on_rally_mode_entered(tower):
	"""Handle entering rally point placement mode"""
	print("🚩 [PlacementManager] Rally mode entered for tower: %s" % tower.name)
	
	if tower.has_method("enter_rally_placement_mode"):
		tower.enter_rally_placement_mode()
		# Menu is already closed by the signal emission in ring_upgrade_menu
	else:
		print("❌ [PlacementManager] Tower does not support rally placement!")

func _on_tower_sold(tower_to_sell):
	"""Handle tower sell"""
	print("\n=== 💰 TOWER SELL HANDLER ===")
	print("💰 [PlacementManager] _on_tower_sold() called")

	# Calculate sell value (70% of build cost)
	var sell_value = 0
	if tower_to_sell and is_instance_valid(tower_to_sell):
		if tower_to_sell.has_method("get_sell_value"):
			sell_value = tower_to_sell.get_sell_value()
		else:
			# Fallback: 70% of build_cost
			var build_cost = tower_to_sell.build_cost if "build_cost" in tower_to_sell else 100
			sell_value = int(build_cost * 0.7)
	
	print("💰 [PlacementManager] Sell value: %d" % sell_value)

	# Refund gold
	if GameStateManager:
		GameStateManager.add_gold(sell_value)
		print("✅ [PlacementManager] Gold refunded: +%d" % sell_value)
	else:
		push_error("❌ [PlacementManager] GameStateManager not found! Gold not refunded.")

	# Deselect tower before selling
	_deselect_current_tower()

	if current_spot:
		# Use the tower spot's built-in cleanup method
		# This properly resets has_tower, current_tower, sprite visibility,
		# AND re-enables click_area.input_pickable (critical for re-building)
		current_spot.remove_tower()

		# CRITICAL FIX: Close the menu immediately after selling
		# This prevents the "stuck menu" bug where user has to click elsewhere
		close_current_menu()
		
		current_spot = null
		current_selected_tower = null
		
	print("=== ✅ TOWER SOLD ===\n")

func _on_menu_closed():
	"""Handle menu close (when clicking outside or pressing ESC)"""
	# print("🔧 [PlacementManager] _on_menu_closed() called")

	# Deselect tower when menu closes
	_deselect_current_tower()

	# Unlock camera input
	_unlock_camera()

	current_spot = null
	current_selected_tower = null
	# print("🔧 [PlacementManager] Menu closed and cleanup complete")

func _on_damage_path_chosen(tower):
	"""Handle damage path choice - LEFT BUTTON for all towers"""
	print("\n=== 🔥 PATH CHOICE HANDLER (LEFT BUTTON) ===")
	print("🔥 [PlacementManager] _on_damage_path_chosen() called")
	print("🔥 [PlacementManager] Tower valid: %s" % str(is_instance_valid(tower)))

	if not tower or not is_instance_valid(tower):
		print("❌ [PlacementManager] ERROR: Tower is null or invalid!")
		print("=== ❌ PATH CHOICE ABORTED ===\n")
		return

	# Determine tower type and call appropriate path method
	var tower_id = tower.tower_id if "tower_id" in tower else ""
	var result = false

	match tower_id:
		"archer":
			if tower.has_method("choose_damage_path"):
				print("🔥 [PlacementManager] Archer: Calling choose_damage_path()...")
				result = tower.choose_damage_path()
		"barracks":
			if tower.has_method("choose_defense_path"):
				print("🛡️ [PlacementManager] Barracks: Calling choose_defense_path()...")
				result = tower.choose_defense_path()
		"mage":
			if tower.has_method("choose_inferno_path"):
				print("🔥 [PlacementManager] Mage: Calling choose_inferno_path()...")
				result = tower.choose_inferno_path()
		"artillery":
			if tower.has_method("choose_cannon_path"):
				print("💥 [PlacementManager] Artillery: Calling choose_cannon_path()...")
				result = tower.choose_cannon_path()
		_:
			print("❌ [PlacementManager] Unknown tower type: %s" % tower_id)

	if result:
		print("✅ [PlacementManager] Path chosen successfully!")
		print("✅ [PlacementManager] Tower is now Level %d with path: %s" % [tower.tower_level, tower.upgrade_path])
		print("🔧 [PlacementManager] Closing menu after path choice (Kingdom Rush style)...")
		close_current_menu()
		print("=== ✅ PATH CHOICE SUCCESS ===\n")
	else:
		print("❌ [PlacementManager] Path choice failed!")
		print("=== ❌ PATH CHOICE FAILED ===\n")

func _on_range_path_chosen(tower):
	"""Handle range path choice - RIGHT BUTTON for all towers"""
	print("\n=== 🎯 PATH CHOICE HANDLER (RIGHT BUTTON) ===")
	print("🎯 [PlacementManager] _on_range_path_chosen() called")
	print("🎯 [PlacementManager] Tower valid: %s" % str(is_instance_valid(tower)))

	if not tower or not is_instance_valid(tower):
		print("❌ [PlacementManager] ERROR: Tower is null or invalid!")
		print("=== ❌ PATH CHOICE ABORTED ===\n")
		return

	# Determine tower type and call appropriate path method
	var tower_id = tower.tower_id if "tower_id" in tower else ""
	var result = false

	match tower_id:
		"archer":
			if tower.has_method("choose_range_path"):
				print("🎯 [PlacementManager] Archer: Calling choose_range_path()...")
				result = tower.choose_range_path()
		"barracks":
			if tower.has_method("choose_offense_path"):
				print("⚔️ [PlacementManager] Barracks: Calling choose_offense_path()...")
				result = tower.choose_offense_path()
		"mage":
			if tower.has_method("choose_frost_path"):
				print("❄️ [PlacementManager] Mage: Calling choose_frost_path()...")
				result = tower.choose_frost_path()
		"artillery":
			if tower.has_method("choose_mortar_path"):
				print("💣 [PlacementManager] Artillery: Calling choose_mortar_path()...")
				result = tower.choose_mortar_path()
		_:
			print("❌ [PlacementManager] Unknown tower type: %s" % tower_id)

	if result:
		print("✅ [PlacementManager] Path chosen successfully!")
		print("✅ [PlacementManager] Tower is now Level %d with path: %s" % [tower.tower_level, tower.upgrade_path])
		print("🔧 [PlacementManager] Closing menu after path choice (Kingdom Rush style)...")
		close_current_menu()
		print("=== ✅ PATH CHOICE SUCCESS ===\n")
	else:
		print("❌ [PlacementManager] Path choice failed!")
		print("=== ❌ PATH CHOICE FAILED ===\n")

func _on_targeting_mode_changed(tower, mode: int):
	"""Handle targeting mode change from ring menu"""
	print("\n=== 🎯 TARGETING MODE CHANGE ===")
	print("🎯 [PlacementManager] _on_targeting_mode_changed() called")
	print("🎯 [PlacementManager] Tower: %s, Mode: %d" % [tower.name if tower else "null", mode])

	if not tower or not is_instance_valid(tower):
		print("❌ [PlacementManager] ERROR: Tower is null or invalid!")
		return

	if tower.has_method("set_targeting_mode"):
		tower.set_targeting_mode(mode)
		print("✅ [PlacementManager] Targeting mode changed to: %d" % mode)
	else:
		print("❌ [PlacementManager] Tower doesn't have set_targeting_mode() method!")


	# 4. Set rally point on tower
	print("⚠️ [PlacementManager] Rally point placement not yet implemented")

func _lock_camera():
	if camera and is_instance_valid(camera):
		camera.lock_input()
		# print("🔒 [PlacementManager] Camera locked")
	else:
		push_warning("[PlacementManager] Cannot lock camera - reference invalid")

func _unlock_camera():
	if camera and is_instance_valid(camera):
		camera.unlock_input()
		# print("🔓 [PlacementManager] Camera unlocked")
	else:
		push_warning("[PlacementManager] Cannot unlock camera - reference invalid")

func _deselect_current_tower():
	"""Deselect and hide range indicator for current tower"""
	if current_selected_tower and is_instance_valid(current_selected_tower):
		if current_selected_tower.has_method("deselect_tower"):
			current_selected_tower.deselect_tower()
			# print("🔧 [PlacementManager] Tower deselected: %s" % current_selected_tower.name)
		else:
			push_warning("[PlacementManager] Tower missing deselect_tower() method")
	current_selected_tower = null
