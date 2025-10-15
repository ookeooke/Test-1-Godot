# Camera System Upgrade Guide

## Overview

Your current camera is good, but this upgrade makes it **commercial-grade** for mobile + PC release.

## What's New

### ✅ Platform Detection
- Auto-detects mobile vs PC
- Different defaults per platform
- Mobile: No edge scroll, higher touch thresholds
- PC: Full features with keyboard + mouse

### ✅ User Preferences System
- All settings can be customized
- Settings persist between sessions
- Accessible from settings menu

### ✅ Mobile-Specific Features
- **Double-tap zoom** (industry standard)
- Adjusted drag sensitivity
- Better pinch-to-zoom
- Frame-independent inertia

### ✅ Camera Effects
- **Camera shake** system for game feel
- Intensity-based shake (small/medium/large)
- Auto-decay

### ✅ Snap-to Feature
- Smooth camera movement to targets
- Focus on towers/heroes
- Dramatic sequences (boss intro, victory)

### ✅ Accessibility
- Can disable edge scroll
- Can disable inertia
- Can disable shake
- Adjustable speeds (0.5x to 2.0x)

### ✅ Performance Improvements
- Frame-independent inertia (fixed bug in original)
- Separate base_position and shake_offset
- Optimized bounds checking

---

## Installation

### Step 1: Replace Camera Script

**Option A: Replace existing camera**
```
1. Open your main scene
2. Select the Camera2D node
3. In Inspector, change script from camera_controller.gd to camera_controller_improved.gd
4. Test the scene
```

**Option B: Keep both (recommended for testing)**
```
1. Keep your old camera
2. Add new Camera2D node
3. Attach camera_controller_improved.gd
4. Toggle between them
```

### Step 2: Add Camera Effects Helper (Optional)

Add `camera_effects.gd` as an autoload:
```
1. Project > Project Settings > Autoload
2. Add camera_effects.gd
3. Name it "CameraEffects"
```

### Step 3: Test Platform Detection

Run on PC:
```gdscript
print("Platform: ", camera.current_platform)
# Should print: Platform: 1 (PC)
```

Export to mobile and test:
```gdscript
# Should print: Platform: 0 (MOBILE)
# Edge scroll should be disabled
# Double-tap should work
```

---

## Usage Examples

### Basic Setup (in your main scene)

```gdscript
extends Node2D

@onready var camera = $Camera2D

func _ready():
	# Set level bounds (important!)
	camera.set_level_bounds(Rect2(0, 0, 2000, 1200))

	# Optional: Adjust zoom range
	camera.min_zoom = 0.4
	camera.max_zoom = 1.2
```

### Using Camera Shake

**In your enemy script:**
```gdscript
func die():
	# Small shake when enemy dies
	var camera = get_viewport().get_camera_2d()
	if camera.has_method("add_shake"):
		camera.add_shake(5.0)

	# Or use helper:
	CameraEffects.small_shake(camera)

	queue_free()
```

**In tower placement:**
```gdscript
func place_tower(tower_scene):
	var tower = tower_scene.instantiate()
	add_child(tower)

	# Medium shake + focus
	var camera = get_viewport().get_camera_2d()
	CameraEffects.medium_shake(camera)
	CameraEffects.focus_on_tower(camera, tower)
```

**Wave complete:**
```gdscript
func wave_completed():
	var camera = get_viewport().get_camera_2d()
	CameraEffects.large_shake(camera)
	# Show completion UI...
```

### Snap-to Object

**Focus on selected hero:**
```gdscript
func _on_hero_selected(hero):
	var camera = get_viewport().get_camera_2d()
	camera.snap_to_object(hero, 1.2)  # Zoom to 1.2x
```

**Show wave spawn point:**
```gdscript
func start_wave():
	var camera = get_viewport().get_camera_2d()
	camera.snap_to_position(spawn_point.global_position, 0.8, 1.0)
```

**Return to overview:**
```gdscript
func show_overview():
	var camera = get_viewport().get_camera_2d()
	camera.reset_to_center()
```

### Dramatic Sequences

**Boss introduction:**
```gdscript
func spawn_boss():
	var boss = boss_scene.instantiate()
	add_child(boss)

	var camera = get_viewport().get_camera_2d()
	CameraEffects.boss_intro_sequence(camera, boss)
```

**Victory screen:**
```gdscript
func show_victory():
	var camera = get_viewport().get_camera_2d()
	CameraEffects.victory_sequence(camera)
	await get_tree().create_timer(1.0).timeout
	# Show victory UI...
```

**Defeat screen:**
```gdscript
func game_over():
	var camera = get_viewport().get_camera_2d()
	CameraEffects.defeat_sequence(camera, base_position)
	await get_tree().create_timer(1.0).timeout
	# Show game over UI...
```

### Settings UI Integration

**Add to your settings menu:**
```gdscript
# In your main menu or pause menu
func _on_camera_settings_pressed():
	var settings_ui = preload("res://camera_settings_ui.tscn").instantiate()
	add_child(settings_ui)

	settings_ui.settings_changed.connect(_on_camera_settings_changed)
	settings_ui.settings_closed.connect(_on_camera_settings_closed)

func _on_camera_settings_changed():
	print("Camera settings updated!")

func _on_camera_settings_closed():
	print("Settings closed")
```

---

## Configuration Guide

### For Mobile Games (Portrait/Landscape)

```gdscript
# In camera _ready() or level setup
if OS.has_feature("mobile"):
	camera.mobile_min_zoom = 0.5  # Less zoomed out on small screens
	camera.mobile_max_zoom = 1.5
	camera.double_tap_zoom_in = 1.4
	camera.mobile_drag_speed = 1.5  # Faster swipes
```

### For PC Games (Monitor/Ultrawide)

```gdscript
# Support ultrawide monitors
if OS.get_name() == "Windows":
	camera.edge_scroll_margin = 100  # Larger margin for big screens
	camera.keyboard_pan_speed = 600.0  # Faster keyboard pan
```

### Per-Level Zoom Limits

```gdscript
# Small arena level
func setup_arena_level():
	camera.set_level_bounds(Rect2(0, 0, 1000, 800))
	camera.min_zoom = 0.6  # Can't zoom out much
	camera.max_zoom = 1.5

# Large battlefield level
func setup_battlefield_level():
	camera.set_level_bounds(Rect2(0, 0, 4000, 3000))
	camera.min_zoom = 0.2  # Zoom way out
	camera.max_zoom = 1.0
```

---

## Save/Load Integration

### Save camera preferences

```gdscript
func save_game():
	var save_data = {
		"camera_state": camera.get_camera_state(),
		"player_progress": {...},
		# ... other data
	}
	# Save to file...
```

### Restore camera preferences

```gdscript
func load_game(save_data):
	if save_data.has("camera_state"):
		camera.set_camera_state(save_data["camera_state"])
```

---

## Testing Checklist

### PC Testing
- [ ] Mouse wheel zoom works
- [ ] Middle-click drag works
- [ ] Right-click drag works
- [ ] Edge scroll works (if enabled)
- [ ] WASD/Arrow keys work
- [ ] Keyboard pan cancels edge scroll
- [ ] Settings menu works
- [ ] All preferences save/load

### Mobile Testing (use remote debug or export)
- [ ] Single finger drag works
- [ ] Two-finger pinch zoom works
- [ ] Double-tap zoom works
- [ ] Inertia feels good
- [ ] No edge scroll on mobile
- [ ] Touch thresholds prevent accidental drags
- [ ] Settings menu accessible

### Camera Effects Testing
- [ ] Small shake visible but not annoying
- [ ] Large shake feels impactful
- [ ] Shake doesn't move camera bounds
- [ ] Snap-to is smooth
- [ ] Snap can be cancelled by user input
- [ ] Victory/defeat sequences work

---

## Performance Notes

### Optimizations Included
1. **Frame-independent inertia** - Works same on 30fps and 144fps
2. **Separated shake from position** - No bounds issues
3. **Snap animation uses ease-out** - Smooth and efficient
4. **Platform detection cached** - Only runs once

### Mobile Performance Tips
```gdscript
# Reduce shake on low-end devices
if OS.get_processor_count() < 4:  # Low-end device
	camera.shake_enabled = false
	camera.inertia_enabled = false  # Simplify for performance
```

---

## Common Issues & Solutions

### Issue: Camera jitters when dragging
**Solution:** Make sure you're using `camera_controller_improved.gd`, not the old one. The new version fixes frame-dependent inertia.

### Issue: Double-tap doesn't work on mobile
**Solution:** Check that `double_tap_time_threshold` isn't too low (0.3 is good). Test on actual device, not simulator.

### Issue: Edge scroll too sensitive
**Solution:** Increase `edge_scroll_margin` or decrease `edge_scroll_speed_multiplier` in settings.

### Issue: Camera goes out of bounds with shake
**Solution:** New system prevents this by separating `base_position` and `shake_offset`. Make sure you're not manually setting `position`.

### Issue: Snap-to doesn't work
**Solution:** Ensure object is valid with `is_instance_valid()` before snapping.

---

## Roadmap / Future Enhancements

Features you might want to add:

1. **Gamepad support** - Add right-stick camera control
2. **Camera follow mode** - Auto-follow selected hero
3. **Letterbox mode** - Cinematic bars for cutscenes
4. **Screen record mode** - Disable shake for smooth recording
5. **VFX camera** - Chromatic aberration, screen distortion
6. **Multi-camera** - Picture-in-picture for multiple areas

---

## Migration from Old Camera

If upgrading from `camera_controller.gd`:

### Breaking Changes
- `position` is now read-only (use `base_position` internally)
- `velocity` calculation changed (frame-independent)
- New required exports (will use defaults if not set)

### API Compatibility
All old functions still work:
- ✅ `zoom_at_point()`
- ✅ `reset_to_center()`
- ✅ `set_level_bounds()`
- ✅ `apply_bounds()`

### New Functions
- `add_shake(intensity)` - Camera shake
- `snap_to_position(pos, zoom)` - Smooth move
- `snap_to_object(object, zoom)` - Focus on object
- `cancel_snap()` - Stop snap animation
- `set_zoom_instant(zoom)` - No smoothing
- `get_camera_state()` / `set_camera_state()` - Save/load

---

## Credits

Based on your excellent `camera_controller.gd` with commercial enhancements.

**Enhanced Features:**
- Platform detection & adaptation
- Mobile double-tap zoom
- Camera shake system
- Snap-to-target animation
- User preferences
- Frame-independent physics
- Accessibility options

**Perfect for:**
- Tower Defense (PC + Mobile)
- Strategy games
- Any 2D game needing professional camera

---

## Support

For issues or questions:
1. Check console for error messages
2. Test with `camera.debug_mode = true`
3. Verify platform detection: `print(camera.current_platform)`
4. Check that bounds are set correctly

Enjoy your professional camera system! 🎥
