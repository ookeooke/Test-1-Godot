# Waypoint System Setup Guide

## Overview

The new **Waypoint Grid System** allows you to:
- ✅ **Manually define enemy paths** by placing waypoint nodes
- ✅ **Adjust road width** at each waypoint for narrow/wide sections
- ✅ **See the road visually** rendered automatically in the editor
- ✅ **Natural enemy spread** - enemies take random positions within road width
- ✅ **Place soldier towers only on roads** - easy validation
- ✅ **Support branching paths** - enemies can choose between multiple routes

---

## Quick Start (5 Minutes)

### Step 1: Create Waypoint Nodes

1. In your level scene (e.g., `level_01.tscn`), create a new `Node2D` called **"Waypoints"**
2. Add a child `Node2D` to Waypoints, name it **"Waypoint_Start"**
3. Attach the script: `res://scripts/pathfinding/path_waypoint.gd`
4. Position it where enemies should spawn (click and drag in editor)

### Step 2: Create the Path

1. Duplicate **Waypoint_Start** (Ctrl+D) several times
2. Rename them: `Waypoint_01`, `Waypoint_02`, etc.
3. Position them along your desired enemy path
4. **Connect waypoints:**
   - Select `Waypoint_Start`
   - In inspector, find `Next Waypoints` array
   - Click `+` to add element
   - Drag `Waypoint_01` into the array slot
   - Repeat for each waypoint in sequence

### Step 3: Add Road Renderer

1. In your level scene, add a new `Node2D` called **"RoadRenderer"**
2. Attach script: `res://scripts/pathfinding/road_renderer.gd`
3. **Done!** The road will automatically draw between waypoints

### Step 4: Configure Wave Manager

1. Select your **WaveManager** node
2. In inspector, find these properties:
   - **Use Waypoint System:** ☑️ Check this!
   - **Start Waypoint:** Drag `Waypoint_Start` here
   - **Enemy Path:** Leave empty (not used with waypoints)

### Step 5: Test!

Press F5 to run your level. Enemies should now:
- Spawn at the first waypoint
- Move to each waypoint in sequence
- Spread out naturally within the road width
- Stay inside the visible road area

---

## Detailed Configuration

### PathWaypoint Properties

Select any waypoint and adjust these in the Inspector:

#### **Waypoint Connection**
- **Next Waypoints** - Array of waypoints this one connects to
  - Leave empty for the final waypoint (enemies reach end)
  - Add multiple for branching paths (enemies choose randomly)

#### **Road Width**
- **Road Width** - How wide the road is at this waypoint (pixels)
  - Default: `100.0`
  - Small road: `60-80`
  - Wide road: `120-180`
  - Varies per waypoint - create narrow/wide sections!

#### **Visual Settings**
- **Waypoint Color** - Color of the marker in editor
- **Visible In Game** - Show waypoint marker during gameplay (usually off)
- **Marker Radius** - Size of the waypoint circle in editor

#### **Soldier Tower Placement**
- **Allows Soldier Placement** - Can garrison towers be placed at this waypoint?
  - ☑️ Checked - Soldiers can be placed here
  - ☐ Unchecked - This waypoint doesn't allow soldiers

---

### RoadRenderer Properties

Select the RoadRenderer node:

#### **Road Visual Settings**
- **Road Color** - Color of the road (default: brown)
- **Road Border Color** - Color of road edges (darker brown)
- **Visible In Game** - Show road during gameplay?
  - ☑️ Checked - Players see the road
  - ☐ Unchecked - Road only visible in editor
- **Segments Per Connection** - Smoothness of road curves (default: 20)

#### **Road Style**
- **Draw Border** - Draw dark outline around road?
- **Border Width** - Width of border in pixels
- **Draw Grid Lines** - Draw decorative grid on road?

---

## Creating Branching Paths

### Example: Two Routes

```
        Waypoint_01
             |
        Waypoint_02
         /       \
  WP_North      WP_South  (Enemies randomly choose)
       |            |
  WP_North_02   WP_South_02
         \       /
        Waypoint_End
```

**Setup:**
1. Create `Waypoint_02` normally
2. Create `WP_North` and `WP_South`
3. In `Waypoint_02` inspector:
   - Next Waypoints → Add 2 elements
   - Slot [0]: Drag `WP_North`
   - Slot [1]: Drag `WP_South`
4. Enemies will randomly pick north or south!

---

## Adjusting Road Width

### Variable Width Example

Create interesting paths with varying widths:

```gdscript
Waypoint_Start   - road_width: 80   (narrow spawn)
Waypoint_01      - road_width: 120  (opens up)
Waypoint_02      - road_width: 160  (wide area - easy for archer towers)
Waypoint_03      - road_width: 60   (bottleneck - good for soldiers)
Waypoint_End     - road_width: 100  (normal width)
```

**Visual Effect:**
- Road automatically tapers between waypoints
- Narrow sections force enemies together (good soldier chokepoints)
- Wide sections spread enemies out (better for ranged towers)

---

## Soldier Tower Placement

### Checking if Position is On Road

The RoadRenderer has a helper function:

```gdscript
# In placement_manager.gd or tower_spot.gd
var road_renderer = get_tree().get_first_node_in_group("road_renderer")

func can_place_soldier(world_position: Vector2) -> bool:
    if not road_renderer:
        return false

    return road_renderer.is_point_on_road(world_position, 20.0)  # 20px tolerance

# Use in placement logic
func try_place_soldier_tower(position: Vector2):
    if not can_place_soldier(position):
        show_error("Garrison towers must be placed on the road!")
        return false

    # Place tower...
```

---

## Enemy Behavior with Waypoints

### How Enemies Move

1. **Spawn** - Enemy starts at first waypoint's random position
2. **Target** - Picks a random position within next waypoint's road width
3. **Move** - Walks toward target with natural side-to-side wander
4. **Reach** - When close enough (30px), moves to next waypoint
5. **Repeat** - Until reaching final waypoint (no next waypoints)

### Natural Spread

Enemies naturally spread out because:
- Random starting position in road width
- Random target position at each waypoint
- Small lateral wander while moving
- Different speeds (if enabled in wave config)

### Blocking/Combat

- When hero blocks an enemy, it stops moving
- Hero combat works identically to Path2D system
- After combat, enemy continues to next waypoint

---

## Converting From Path2D

### Option 1: Keep Both Systems

You can have **both** Path2D and Waypoint levels!

**Path2D Level:**
- WaveManager: `use_waypoint_system = false`
- Assign `enemy_path`

**Waypoint Level:**
- WaveManager: `use_waypoint_system = true`
- Assign `start_waypoint`

### Option 2: Convert Existing Path2D

1. Look at your existing `Path2D` curve
2. Place waypoints along the curve
3. Match road width to your visual path
4. Enable waypoint system in WaveManager
5. Remove old Path2D (or keep for reference)

---

## Tips & Best Practices

### 🎨 Visual Design

1. **Name waypoints sequentially** - `WP_01`, `WP_02`, etc.
2. **Use colors to indicate types:**
   - Yellow (default) - normal waypoints
   - Orange - soldier placement waypoints
   - Red - dangerous/narrow sections
3. **Road width should match visual design**
   - If you have a dirt road sprite that's 100px wide, set road_width to 100

### 🎮 Gameplay Design

1. **Create bottlenecks** - Narrow sections (60px) where enemies bunch up
2. **Create arenas** - Wide sections (180px) where enemies spread out
3. **Soldier placement** - Mark waypoints on road as `allows_soldier_placement = true`
4. **Strategic branching** - Let players adapt based on which path enemies take

### ⚡ Performance

1. **Waypoint count** - 10-20 waypoints per path is good
2. **Too few waypoints** - Enemies cut corners, path looks angular
3. **Too many waypoints** - Unnecessary, no visual improvement
4. **Road renderer** - Auto-updates in editor, disabled in game for performance

---

## Troubleshooting

### "No start waypoint assigned!"

**Problem:** Wave manager can't find starting waypoint
**Solution:**
1. Select WaveManager node
2. Check `use_waypoint_system` is enabled
3. Drag first waypoint to `start_waypoint` field

### "Road doesn't appear"

**Problem:** RoadRenderer not drawing
**Solution:**
1. Check RoadRenderer has script attached
2. Check waypoints have `path_waypoint.gd` script
3. Check waypoints are connected (next_waypoints array)
4. Check RoadRenderer is a child of level root (not inside Waypoints node)

### "Enemies walk in straight line"

**Problem:** Not using waypoint navigation
**Solution:**
1. Verify `use_waypoint_system = true` in WaveManager
2. Check `start_waypoint` is assigned
3. Make sure enemies have `set_waypoint_navigation()` method (should be in base_enemy.gd)

### "Enemies don't spread out"

**Problem:** Road width too narrow
**Solution:**
1. Increase `road_width` on waypoints (try 120-150)
2. Enemies spread randomly within road width
3. More width = more natural-looking spread

### "Soldiers can be placed anywhere"

**Problem:** No validation for soldier placement
**Solution:**
1. Add placement check to your placement_manager.gd
2. Use `road_renderer.is_point_on_road(position)`
3. See "Soldier Tower Placement" section above

---

## Example Level Setup

Here's a complete example for a simple level:

### Scene Tree
```
Level_01 (Node2D)
├── Waypoints (Node2D)
│   ├── WP_Start (PathWaypoint)
│   ├── WP_01 (PathWaypoint)
│   ├── WP_02 (PathWaypoint)
│   ├── WP_03 (PathWaypoint)
│   └── WP_End (PathWaypoint)
├── RoadRenderer (Node2D)
├── WaveManager (Node2D)
├── TowerSpots (Node2D)
└── ... (rest of level)
```

### Waypoint Configuration

**WP_Start:**
- Position: `Vector2(-200, 400)`
- Road Width: `80`
- Next Waypoints: `[WP_01]`

**WP_01:**
- Position: `Vector2(200, 400)`
- Road Width: `120`
- Next Waypoints: `[WP_02]`

**WP_02:**
- Position: `Vector2(500, 200)`
- Road Width: `100`
- Next Waypoints: `[WP_03]`

**WP_03:**
- Position: `Vector2(800, 300)`
- Road Width: `140`
- Next Waypoints: `[WP_End]`

**WP_End:**
- Position: `Vector2(1200, 400)`
- Road Width: `100`
- Next Waypoints: `[]` (empty - this is the end!)

### WaveManager Configuration

- **Use Waypoint System:** ☑️
- **Start Waypoint:** `WP_Start`
- **Enemy Path:** (leave empty)

---

## Advanced: Weighted Branch Selection

Currently, enemies choose randomly between branches. To add weighted selection:

```gdscript
# In path_waypoint.gd, add:
@export var branch_weights: Array[float] = []

func get_next_waypoint() -> PathWaypoint:
    if next_waypoints.is_empty():
        return null

    if next_waypoints.size() == 1:
        return next_waypoints[0]

    # Use weights if provided
    if branch_weights.size() == next_waypoints.size():
        return _weighted_random_choice()

    # Otherwise random
    return next_waypoints.pick_random()

func _weighted_random_choice() -> PathWaypoint:
    var total_weight = 0.0
    for weight in branch_weights:
        total_weight += weight

    var random_value = randf() * total_weight
    var cumulative = 0.0

    for i in branch_weights.size():
        cumulative += branch_weights[i]
        if random_value <= cumulative:
            return next_waypoints[i]

    return next_waypoints[0]
```

**Usage:**
- North path: 70% chance → weight: `0.7`
- South path: 30% chance → weight: `0.3`

---

## Summary

✅ **Waypoint system gives you:**
- Full manual control over enemy paths
- Visual road rendering in editor
- Natural enemy spread within road boundaries
- Easy soldier tower placement validation
- Flexible branching paths
- Variable road widths

✅ **Best for:**
- Games where you want to hand-craft enemy routes
- Levels with narrow/wide sections
- Soldier/garrison tower mechanics
- Artistic control over path shape and width

✅ **Setup time:** 5-10 minutes per level

**Need help?** Check the example in `level_01.tscn` or see the scripts:
- `scripts/pathfinding/path_waypoint.gd`
- `scripts/pathfinding/road_renderer.gd`
- `scripts/enemies/base_enemy.gd` (waypoint movement functions)
- `scripts/managers/wave_manager.gd` (waypoint spawning)
