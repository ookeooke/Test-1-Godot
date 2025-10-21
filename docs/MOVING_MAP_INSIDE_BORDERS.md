# Moving the Map Inside Borders - Complete Guide

**Question:** "Can I move the map inside borders?"

**Short Answer:** ✅ **YES! You have 3 ways to do it:**

1. **Move everything in the scene** (simplest - drag in editor)
2. **Adjust the `level_rect` position** (adjust borders to fit map)
3. **Move camera starting position** (change what player sees first)

---

## Understanding the System

### **What Actually Moves?**

```
Your Level Has 3 Coordinate Spaces:

1. World Space (Your Game Objects):
   - EnemyPath at (5, -2)
   - TowerSpot1 at (356, 433)
   - TowerSpot2 at (984, 271)
   - Camera starts at (900, 450)

2. Border Space (level_rect):
   - Currently: Rect2(-200, 200, 2000, 800)
   - Defines playable area boundaries

3. Camera View:
   - What player actually sees
   - Controlled by camera position and borders
```

**Key Concept:** The "map" doesn't move - you're choosing what part of world space is visible and where borders are.

---

## Method 1: Move Everything in Scene (Easiest)

### **Use Case:** "I want the whole level shifted to a different position"

**Example:** Move entire level 200 pixels right and 100 pixels down

### **Steps:**

1. Open `level_01.tscn` in Godot
2. In Scene Tree, **select multiple nodes:**
   - Hold Ctrl and click:
     - EnemyPath
     - TowerSpots (parent node)
     - HeroSpots (parent node)
     - Any decoration/background nodes
   - **DON'T select:** Camera2D, UI, WaveManager, PlacementManager

3. In 2D viewport or Inspector:
   - Drag to new position, OR
   - Inspector → Node2D → Position → Add offset (200, 100)

4. **Update camera start position:**
   ```gdscript
   # In level_01.tscn Camera2D node:
   position = Vector2(1100, 550)  # Was (900, 450), now +200, +100
   ```

5. **Optional:** Adjust `level_rect` if needed:
   ```gdscript
   # Camera2D → Level Bounds → level_rect
   level_rect = Rect2(0, 300, 2000, 800)  # Shifted +200, +100
   ```

**Result:** Entire playable area moves together!

### **Diagram:**

```
BEFORE:
  ┌────────────────────┐
  │  level_rect        │
  │  (-200, 200)       │
  │                    │
  │   🗼 Towers here   │
  │   🛤️ Path here     │
  │                    │
  └────────────────────┘

AFTER (shifted +200, +100):
       ┌────────────────────┐
       │  level_rect        │
       │  (0, 300)          │
       │                    │
       │   🗼 Towers here   │
       │   🛤️ Path here     │
       │                    │
       └────────────────────┘
```

---

## Method 2: Adjust Border Position (Keep Objects, Move Borders)

### **Use Case:** "My towers are already placed, I just want borders to fit them better"

**Example:** You have towers at various positions, want to center borders around them

### **Steps:**

1. **Calculate your current object bounds:**
   ```gdscript
   # Tower positions from level_01:
   TowerSpot1: (356, 433)
   TowerSpot2: (984, 271)
   TowerSpot3: (1200, 600)
   TowerSpot4: (1500, 300)

   # Enemy path:
   Start: (-179, 142)
   End: (1769, 701)
   ```

2. **Find min/max:**
   ```
   min_x = -179  (path start)
   max_x = 1769  (path end)
   min_y = 142   (path start)
   max_y = 701   (path end)
   ```

3. **Add padding:**
   ```
   padding = 200

   final_x = min_x - padding = -179 - 200 = -379
   final_y = min_y - padding = 142 - 200 = -58
   final_width = (max_x - min_x) + (padding * 2) = 1948 + 400 = 2348
   final_height = (max_y - min_y) + (padding * 2) = 559 + 400 = 959
   ```

4. **Set in Camera Inspector:**
   ```gdscript
   level_rect = Rect2(-379, -58, 2348, 959)
   ```

5. **Update camera start position to center:**
   ```gdscript
   # Center of new bounds:
   center_x = -379 + (2348 / 2) = 795
   center_y = -58 + (959 / 2) = 421.5

   position = Vector2(795, 422)
   ```

**Result:** Borders now perfectly fit your existing objects!

---

## Method 3: Change Camera Starting Position Only

### **Use Case:** "Borders and objects are fine, I just want player to start looking at a different area"

**Example:** Start camera focused on hero spot instead of center

### **Steps:**

1. Find the position you want to focus on:
   ```gdscript
   # Hero spot position from level_01:
   HeroSpot: (761, 675)
   ```

2. Open `level_01.tscn`

3. Select Camera2D node

4. Inspector → Transform → Position:
   ```gdscript
   position = Vector2(761, 675)
   ```

**Result:** Game starts with camera looking at that position, but player can still scroll to see entire level_rect area!

---

## Interactive Editor Method (Visual)

### **Best for:** Quick adjustments while seeing results

### **Steps:**

1. **Open level_01.tscn in Godot**

2. **Enable 2D view** (top toolbar)

3. **Zoom to see entire level:**
   - Mouse wheel scroll or
   - View menu → Zoom to Fit

4. **Visual feedback:**
   - Pink/magenta rectangle = where camera can move
   - Your objects (towers, paths) = what player interacts with

5. **Select and drag objects:**
   ```
   Click TowerSpots (parent) → Drag
   Click EnemyPath → Drag
   Click HeroSpots (parent) → Drag
   ```

6. **See magenta rectangle update:**
   - If objects go outside pink rectangle → increase level_rect size
   - If too much empty space → decrease level_rect size

7. **Adjust Camera2D → level_rect in Inspector** until pink rectangle perfectly fits your objects

**Time:** 30 seconds ⏱️

---

## Practical Examples

### **Example 1: Center Map at Origin (0, 0)**

**Current:** Map is offset at random positions
**Goal:** Everything centered at (0, 0)

```gdscript
# Current setup (level_01):
level_rect = Rect2(-200, 200, 2000, 800)
Camera at (900, 450)

# Centered setup:
level_rect = Rect2(-1000, -400, 2000, 800)
Camera at (0, 0)

# How to convert existing positions:
# All objects shift by: (-900, -450)
TowerSpot1: (356, 433) → (-544, -17)
TowerSpot2: (984, 271) → (84, -179)
etc.
```

**Steps:**
1. Select all gameplay nodes (not UI/Camera)
2. Inspector → Position → Subtract (900, 450) from each
3. Update level_rect: `Rect2(-1000, -400, 2000, 800)`
4. Update Camera position: `Vector2(0, 0)`

---

### **Example 2: Fit to Content (Auto-Calculate)**

**Goal:** Borders automatically fit all towers and paths

**Script Solution (Add to level_controller.gd):**

```gdscript
func fit_camera_to_content():
    """Auto-calculate optimal camera bounds"""
    var camera = $Camera2D
    var min_pos = Vector2(INF, INF)
    var max_pos = Vector2(-INF, -INF)

    # Find all tower spots
    for spot in $TowerSpots.get_children():
        var pos = spot.global_position
        min_pos.x = min(min_pos.x, pos.x)
        min_pos.y = min(min_pos.y, pos.y)
        max_pos.x = max(max_pos.x, pos.x)
        max_pos.y = max(max_pos.y, pos.y)

    # Find enemy path bounds
    var path = $EnemyPath
    if path and path.curve:
        for i in range(path.curve.point_count):
            var point = path.curve.get_point_position(i) + path.position
            min_pos.x = min(min_pos.x, point.x)
            min_pos.y = min(min_pos.y, point.y)
            max_pos.x = max(max_pos.x, point.x)
            max_pos.y = max(max_pos.y, point.y)

    # Add padding
    var padding = 200
    min_pos -= Vector2(padding, padding)
    max_pos += Vector2(padding, padding)

    # Calculate rect
    var new_rect = Rect2(min_pos, max_pos - min_pos)

    # Apply to camera
    camera.set_level_bounds(new_rect)

    # Center camera on content
    var center = (min_pos + max_pos) / 2
    camera.position = center

    print("✅ Camera bounds fitted to content:", new_rect)
    print("   Camera centered at:", center)
```

**Usage:**
```gdscript
# In level_controller.gd _ready():
fit_camera_to_content()
```

**Or add as tool script button:**
```gdscript
@tool
extends Node2D

# ... existing code ...

@export var auto_fit_bounds: bool = false :
    set(value):
        if value and Engine.is_editor_hint():
            fit_camera_to_content()
            auto_fit_bounds = false
```

Then in Inspector: Check "Auto Fit Bounds" → bounds automatically calculated!

---

### **Example 3: Different Starting Views**

**Scenario:** Want different camera positions for different moments

```gdscript
# In Camera2D:
func start_at_hero():
    position = Vector2(761, 675)  # Hero spot

func start_at_entrance():
    position = Vector2(-179, 142)  # Enemy spawn

func start_at_exit():
    position = Vector2(1769, 701)  # Enemy exit

func start_at_center():
    var center_x = (limit_left + limit_right) / 2.0
    var center_y = (limit_top + limit_bottom) / 2.0
    position = Vector2(center_x, center_y)
```

**Usage in level_controller:**
```gdscript
func _ready():
    await get_tree().process_frame
    $Camera2D.start_at_entrance()  # Start at enemy spawn

    # Or animate:
    $Camera2D.snap_to_position(Vector2(761, 675), -1, 2.0)  # Smooth pan to hero
```

---

## Common Questions

### **Q: "Will moving objects break my game?"**
**A:** No! As long as:
- Path points are in correct order
- Towers are inside level_rect
- Camera can see the important areas

Everything is **relative** - absolute positions don't matter.

### **Q: "Do I need to update level_rect when I move objects?"**
**A:** Only if:
- Objects go outside current borders (player won't see them)
- Too much empty space (wasted scrolling)

Otherwise, borders can stay the same.

### **Q: "Can I animate the map moving during gameplay?"**
**A:** Not really. You can:
- ✅ Animate the camera (use `snap_to_position()`)
- ✅ Add camera shake (use `add_shake()`)
- ❌ Don't move level_rect during gameplay (causes glitches)
- ❌ Don't move all objects during gameplay (performance issue)

### **Q: "How do I make the map bigger/smaller?"**
**A:**
- **Bigger:** Increase level_rect size, spread objects further apart
- **Smaller:** Decrease level_rect size, move objects closer together

Example:
```gdscript
# Current (medium):
level_rect = Rect2(-200, 200, 2000, 800)

# Bigger (2x):
level_rect = Rect2(-700, -200, 4000, 1600)
# Also move towers 2x further apart

# Smaller (0.5x):
level_rect = Rect2(0, 300, 1000, 400)
# Also move towers 0.5x closer
```

---

## Best Practices

### ✅ **DO:**
1. **Keep objects within level_rect** - otherwise player can't see them
2. **Add padding** - don't place towers right at border edges
3. **Center camera on interesting content** - hero spot, first tower, etc.
4. **Test scrolling** - make sure player can see all important areas
5. **Use consistent coordinate system** - either center at (0,0) or use positive coords

### ❌ **DON'T:**
1. **Don't place towers outside level_rect** - camera can't reach them
2. **Don't make borders too big** - wasted scrolling, confusing
3. **Don't move objects during gameplay** - performance issue
4. **Don't change level_rect during gameplay** - causes camera glitches
5. **Don't forget to update camera start position** - player sees wrong area

---

## Quick Reference: Common Setups

### **Setup 1: Centered at Origin**
```gdscript
# Everything centered at (0, 0)
level_rect = Rect2(-1000, -400, 2000, 800)
camera.position = Vector2(0, 0)
```

### **Setup 2: Top-Left Origin**
```gdscript
# Everything starts at (0, 0) going positive
level_rect = Rect2(0, 0, 2000, 800)
camera.position = Vector2(1000, 400)  # Center
```

### **Setup 3: Single Screen (No Scrolling)**
```gdscript
# Viewport = 1920x1080, no scrolling
level_rect = Rect2(0, 0, 1920, 1080)
camera.position = Vector2(960, 540)  # Center
```

### **Setup 4: Vertical Mobile**
```gdscript
# Optimized for mobile portrait
level_rect = Rect2(-300, -500, 1280, 2000)
camera.position = Vector2(340, 500)
```

---

## Visual Guide

```
Method 1: Move Everything
══════════════════════════
   Original:                   After Moving Objects:
   ┌─────────┐                      ┌─────────┐
   │ Border  │                      │ Border  │
   │  🗼🗼   │       →               │         │
   │         │                      │  🗼🗼   │
   └─────────┘                      └─────────┘

Method 2: Move Borders
══════════════════════════
   Original:                   After Adjusting Rect:
   ┌─────────┐                ┌───────────────┐
   │ Border  │                │   New Border  │
   │  🗼🗼   │       →         │   🗼🗼        │
   │         │                │               │
   └─────────┘                └───────────────┘

Method 3: Move Camera Only
══════════════════════════
   Original View:             New Starting View:
   ┏━━━━━━━━━┓                ┏━━━━━━━━━┓
   ┃ Camera  ┃                ┃         ┃
   ┃  🗼🗼   ┃       →         ┃  🗼🗼   ┃Camera
   ┃         ┃                ┃         ┃
   ┗━━━━━━━━━┛                ┗━━━━━━━━━┛
   (Objects don't move, player just starts looking elsewhere)
```

---

## Conclusion

**Yes, you can absolutely move the map inside borders!**

**Easiest method:** Select all gameplay nodes in editor and drag them to new position.

**Time required:** 1-2 minutes

**Risk level:** Very low (Godot's undo works perfectly)

**Recommendation:**
1. Start with Method 3 (camera position) - safest, quickest
2. If that's not enough, use Method 1 (move objects) - still easy
3. Use Method 2 (adjust borders) when you want perfect fit

All methods work great - choose based on your specific need!

