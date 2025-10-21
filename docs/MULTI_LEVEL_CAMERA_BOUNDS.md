# Multi-Level Camera Bounds System

## The Problem

The old system had camera bounds hardcoded in `camera_controller_improved.gd`:
```gdscript
@export var level_rect = Rect2(-200, 200, 2000, 800)
```

This meant:
- ❌ Every level uses the same bounds (not flexible)
- ❌ Must manually adjust camera in each level scene (tedious)
- ❌ No way to save bounds per level (not scalable)

## The Solution

**Level-Driven Bounds**: Each level defines its own playable area via `LevelConfig` resource.

```
LevelConfig (resource)
    ↓
level_controller (script)
    ↓
camera_controller (script)
```

---

## How It Works

### 1. Define Bounds in LevelConfig (Per-Level)

Create/edit your level's config resource:

**res://resources/levels/level_01_config.tres**
```gdscript
[resource]
script = ExtResource("level_config.gd")
level_id = "level_01"
level_name = "Level 1"

# Option 1: Auto-calculate from content (RECOMMENDED)
auto_calculate_bounds = true
bounds_padding = 200.0  # Extra space around towers/paths

# Option 2: Manual bounds
auto_calculate_bounds = false
camera_bounds = Rect2(-500, 0, 3000, 1500)  # Custom area
```

### 2. Assign LevelConfig to level_controller

In your level scene (`level_01.tscn`):

1. Select the root node (should have `level_controller.gd` attached)
2. In Inspector, find **"Level Config"** property
3. Drag your `level_01_config.tres` resource into this slot
4. Done! Bounds are now automatic

---

## The Two Methods

### Method A: Auto-Calculate (Recommended)

**Best for**: Most levels

```gdscript
# In LevelConfig resource
auto_calculate_bounds = true
bounds_padding = 200.0
```

The system automatically:
1. Finds all `TowerSpots`, `Path`, `Spawners`, `Goals` nodes
2. Calculates bounding box around all content
3. Adds padding (extra scrollable space)
4. Sets camera bounds on level start

**Pros:**
- ✅ No manual work
- ✅ Adapts to level layout changes
- ✅ Perfect fit every time

**Cons:**
- ❌ Can't have "dead zones" (areas with no content but still scrollable)

---

### Method B: Manual Bounds

**Best for**: Special levels with specific camera areas

```gdscript
# In LevelConfig resource
auto_calculate_bounds = false
camera_bounds = Rect2(x, y, width, height)
```

**Example**: Level has towers from 0-2000, but you want camera to scroll further right:
```gdscript
camera_bounds = Rect2(-200, 0, 3000, 1500)  # Extends beyond towers
```

**Pros:**
- ✅ Full control
- ✅ Can create "empty space" for dramatic effect

**Cons:**
- ❌ Must manually adjust if level layout changes
- ❌ Easy to get wrong (too small = can't see all towers)

---

## Quick Setup Guide

### For a New Level

1. **Create level scene** (`level_02.tscn`)
2. **Attach level_controller.gd** to root node
3. **Create LevelConfig resource**:
   - Right-click in FileSystem → New Resource → LevelConfig
   - Save as `level_02_config.tres`
   - Set `auto_calculate_bounds = true`
4. **Assign config** to level_controller's "Level Config" property
5. **Run the level** - bounds are automatic!

### For Existing Levels

1. **Open level scene** (e.g., `level_01.tscn`)
2. **Find root node** (has level_controller.gd)
3. **Create LevelConfig** resource (see step 3 above)
4. **Assign to level_controller**
5. **Test in-game** - check console for bounds log:
   ```
   [LevelController] Auto-calculated camera bounds: (-400, 0, 2400, 1200)
   ```

---

## Understanding Rect2 Format

```gdscript
Rect2(x, y, width, height)
      ↓  ↓    ↓       ↓
     Position    Size
```

**Example**: `Rect2(-200, 100, 2000, 800)`
- **Position**: Top-left corner at world position (-200, 100)
- **Size**: 2000 pixels wide, 800 pixels tall
- **Coverage**: From (-200, 100) to (1800, 900)

---

## Adjusting Bounds in Inspector

### Quick Adjust (Auto-Calculate)

1. Open level scene
2. Select root node (level_controller)
3. In Inspector → Level Config → expand resource
4. Adjust `bounds_padding` slider (50-500)
   - **Small padding (50-100)**: Tight camera, can barely see beyond playable area
   - **Medium padding (200)**: Comfortable (default)
   - **Large padding (400-500)**: Extra scrollable space for exploration

### Manual Adjust

1. Same as above, but set `auto_calculate_bounds = false`
2. Adjust `camera_bounds` → Position X/Y and Size X/Y
3. Changes are instant in editor (see pink rectangle)

---

## Advanced: Per-Level Padding

Different levels can have different padding:

**level_01_config.tres** (small level):
```gdscript
auto_calculate_bounds = true
bounds_padding = 150.0  # Tight
```

**level_05_config.tres** (huge level):
```gdscript
auto_calculate_bounds = true
bounds_padding = 400.0  # Lots of scrollable space
```

---

## Validation System (Automatic Conflict Detection)

The system **automatically checks** for overlapping methods when the level starts!

### Automatic Checks on Level Start

Every level start shows console output:

**✅ Perfect setup:**
```
[LevelController] ✅ Bounds configuration validated - no conflicts detected
[LevelController] ✅ Auto-calculated camera bounds: (-400, 0, 2400, 1200)
```

**⚠️ Multiple methods active:**
```
[LevelController] ⚠️ CONFIGURATION WARNINGS:
[LevelController]    Both auto_calculate_bounds=true AND manual camera_bounds are set
[LevelController]    → Auto-calculate will be used (manual bounds will be ignored)
```

**⚠️ Conflicting sources:**
```
[LevelController] ⚠️ CONFIGURATION WARNINGS:
[LevelController]    Camera has custom level_rect AND LevelConfig is assigned
[LevelController]    → LevelConfig will override camera's level_rect
```

### Debug Command (Press F9 In-Game)

Press **F9** while playing to see detailed bounds information:
- Which method is active (1, 2, or 3)
- Current camera limits and position
- LevelConfig settings
- Validation warnings

See **[BORDERS_VALIDATION.md](BORDERS_VALIDATION.md)** and **[BORDERS_QUICK_GUIDE.md](BORDERS_QUICK_GUIDE.md)** for full details.

---

## Troubleshooting

### "Camera won't scroll far enough"

**Cause**: Bounds too small

**Fix**: Increase `bounds_padding` or manually set larger `camera_bounds`

### "Camera scrolls into empty space"

**Cause**: Bounds too large

**Fix**: Decrease `bounds_padding` or set `auto_calculate_bounds = false` with exact bounds

### "Bounds don't update after moving towers"

**Cause**: Using manual bounds

**Fix**: Either:
1. Set `auto_calculate_bounds = true` (updates automatically)
2. Manually adjust `camera_bounds` to match new layout

### "Console says 'No content found for auto-calculation'"

**Cause**: No `TowerSpots`, `Path`, `Spawners`, or `Goals` nodes found

**Fix**: Check your level scene has these node groups, or use manual bounds instead

---

## Best Practices

### ✅ DO:
- Use auto-calculate for 90% of levels
- Set padding to 200-300 for comfortable scrolling
- Test bounds by scrolling to all corners in-game
- Use manual bounds for special camera areas (cutscenes, boss arenas)

### ❌ DON'T:
- Don't set bounds directly in camera_controller (use LevelConfig instead)
- Don't forget to assign LevelConfig to level_controller
- Don't set padding too small (<100) - feels cramped

---

## Code Reference

### Files Modified

1. **[level_config.gd](../scripts/resources/level_config.gd:56-69)** - Added camera bounds properties
2. **[level_controller.gd](../scripts/level_controller.gd:42-96)** - Added bounds setup logic
3. **[camera_controller_improved.gd](../scripts/camera/camera_controller_improved.gd:85-88)** - Updated comments

### Key Functions

**level_controller._setup_camera_bounds()** (line 42):
- Called automatically in `_ready()`
- Checks if auto-calculate or manual
- Calls camera.set_level_bounds()

**level_controller._calculate_bounds_from_content()** (line 64):
- Scans for TowerSpots, Path, Spawners, Goals
- Finds min/max positions
- Adds padding
- Returns Rect2

**camera_controller.set_level_bounds(rect: Rect2)** (line 669):
- Updates level_rect variable
- Recalculates camera limits
- Prints confirmation to console

---

## Migration Guide

### Old Way (Single Level)
```gdscript
# In camera_controller_improved.gd
@export var level_rect = Rect2(-200, 200, 2000, 800)
```

### New Way (Multi-Level)
```gdscript
# In level_01_config.tres
auto_calculate_bounds = true
bounds_padding = 200.0

# Camera automatically gets bounds from level_controller
```

**Migration steps:**
1. Note your current `level_rect` values from camera
2. Create LevelConfig resource
3. Set `camera_bounds` to your noted values (or use auto-calculate)
4. Assign LevelConfig to level_controller
5. Test - should work identically

---

## Summary

| **Aspect** | **Old System** | **New System** |
|------------|----------------|----------------|
| Where defined | camera_controller.gd | LevelConfig resource |
| Per-level? | ❌ No | ✅ Yes |
| Auto-calculate? | ❌ No | ✅ Yes |
| Scalability | Poor (1-2 levels) | Excellent (100+ levels) |
| Ease of use | Medium | Easy |

**Result**: You can now create 50 different levels, each with perfectly-fitted camera bounds, without touching any code!
