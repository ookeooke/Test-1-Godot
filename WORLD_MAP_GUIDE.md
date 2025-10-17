# Kingdom Rush Style World Map System - Setup Guide (Node2D Version)

## Overview

Your tower defense game now has a complete Kingdom Rush-style world map system with:

- **Animated level nodes** (bounce, glow when unlocked)
- **Star display system** (1-3 stars per level)
- **Visual locked/unlocked states**
- **Camera panning and zooming** for large maps
- **Difficulty selector** per level
- **Hero/character selection** before levels
- **Campaign progress tracking**
- **Path connections** between levels

**✨ Node2D-based scene!** The world map uses the same Node2D format as your level scenes, making it super easy to position elements by **dragging them directly in the editor**!

## Quick Start - Visual Positioning

### 1. Open the World Map

1. Open Godot
2. Navigate to `scenes/ui/world_map_select_node2d.tscn`
3. Double-click to open
4. You'll see a 2D scene just like your levels!

### 2. Set Map Background

1. Select **MapBackground** (Sprite2D) in scene tree
2. In Inspector → **Texture** → drag your map image
3. Uncheck **Centered** so map starts at (0,0)

### 3. Position Levels Visually

Levels spawn automatically from level data resources, but you can adjust positions:

1. Open a level data file (e.g., `data/levels/level_01_data.tres`)
2. Change **position** (Vector2) - coordinates on your map
3. Save and run scene (F6) to see it!

**Or drag them in the editor** for testing positions first.

## Adding Your Map Image

1. Import your map image into the project (drag into FileSystem)
2. Open `world_map_select_node2d.tscn`
3. Select **MapBackground** node
4. Drag image to **Texture** property
5. Your map appears in the 2D viewport!

**Recommended sizes:** 1920x1080 minimum, 3840x2160 for large scrolling maps

## Positioning Level Nodes

### Method 1: Edit Resources (Permanent)

Each level has a data resource file defining its properties.

**Edit** `data/levels/level_01_data.tres`:
```
position = Vector2(300, 400)  ← Level appears here on the map
```

Coordinates are pixels from top-left corner (0,0) of your map image.

### Method 2: Visual Testing

1. Run `world_map_select_node2d.tscn` (F6)
2. Note where levels appear
3. Adjust positions in level data resources
4. Re-run to verify

## Creating Path Connections

Paths draw automatically between levels based on unlock requirements!

**How it works:**
- Level 2 has `required_level_id = "level_01"`
- System draws path from Level 1 → Level 2
- Uses `path_to_next_level` waypoints from Level 1

**Example curved path:**

In `level_01_data.tres`:
```
path_to_next_level = [Vector2(450, 450), Vector2(600, 500)]
```

Creates: Level 1 → (450,450) → (600,500) → Level 2

**Empty array** = straight line between levels

## Camera Controls

**In-game:**
- Right-click and drag to pan
- Middle mouse button also pans

**Editor setup:**
1. Select **Camera2D** node
2. Adjust **Zoom** (0.8 = zoomed out a bit)
3. Set **Position** (starting camera location)

## Adding New Levels

### Step 1: Create Level Scene
1. Duplicate `level_01.tscn` → `level_03.tscn`
2. Modify enemies, waves, etc.

### Step 2: Create Level Data
1. FileSystem → Right-click → New Resource
2. Choose **LevelNodeData**
3. Save as `data/levels/level_03_data.tres`

### Step 3: Configure Level Data
```
level_id = "level_03"
level_name = "Dark Forest"
level_scene_path = "res://scenes/levels/level_03.tscn"
position = Vector2(1200, 400)  ← Where on map
required_level_id = "level_02"  ← Must complete Level 2 first
path_to_next_level = [Vector2(1000, 420)]  ← Path waypoints
```

### Step 4: Add to World Map
1. Open `world_map_select_node2d.tscn`
2. Select root **WorldMapSelect** node
3. Inspector → **Level Nodes Data** → increase size
4. Drag `level_03_data.tres` into new slot

Done! Level 3 will appear on your map.

## Customizing Visuals

### Level Button Appearance

Edit `scenes/ui/level_node_2d.tscn`:

- **ButtonSprite**: Replace texture with your own button image
- **GlowSprite**: Custom glow effect sprite
- **Label**: Change font, size, color
- **Stars**: Replace Star1/2/3 textures with your own

### Animations

Edit `scripts/ui/level_node_2d.gd`:

- Bounce height: Line with `-10.0` (higher = bigger bounce)
- Bounce speed: `2.0` seconds duration
- Glow pulse: `1.5` seconds duration
- Hover scale: `1.1` (110% size)

## File Structure

```
scenes/ui/
  └── world_map_select_node2d.tscn  ← Main world map (USE THIS)
  └── level_node_2d.tscn             ← Level button component

scripts/ui/
  └── world_map_select_node2d.gd     ← World map logic
  └── level_node_2d.gd                ← Level button logic

data/levels/
  └── level_01_data.tres              ← Level 1 config (position, unlock, etc.)
  └── level_02_data.tres              ← Level 2 config
```

## Complete Example Setup

**Scenario:** Create a 3-level forest campaign

### Level 1 (Starting level)
`data/levels/level_01_data.tres`:
```
level_id = "level_01"
level_name = "Forest Entrance"
position = Vector2(300, 500)
required_level_id = ""  ← Always unlocked
path_to_next_level = [Vector2(500, 480), Vector2(700, 500)]
```

### Level 2 (Unlocks after Level 1)
`data/levels/level_02_data.tres`:
```
level_id = "level_02"
level_name = "Deep Woods"
position = Vector2(900, 500)
required_level_id = "level_01"
path_to_next_level = [Vector2(1100, 450), Vector2(1300, 400)]
```

### Level 3 (Unlocks after Level 2)
`data/levels/level_03_data.tres`:
```
level_id = "level_03"
level_name = "Forest Heart"
position = Vector2(1500, 350)
required_level_id = "level_02"
path_to_next_level = []  ← No next level
```

This creates a winding path through your forest!

## Common Issues

**Levels don't appear**
- Check level data resources are in **Level Nodes Data** array
- Run scene (F6) and check console for errors

**Wrong positions**
- `position` is from top-left (0,0)
- Make sure **MapBackground** has **Centered** OFF

**Paths don't draw**
- `required_level_id` must exactly match previous level's `level_id`
- Check spelling

**Can't drag camera**
- Right-click or middle-mouse to drag (built-in feature)

## Testing Your Map

1. Press F5 (run game)
2. Create/load profile
3. World map loads automatically
4. Level 1 unlocked, others locked
5. Complete Level 1
6. Return to map → Level 2 unlocks!

---

**That's it!** Your Kingdom Rush-style map is ready. Just drag level nodes around in the editor like you would tower spots in your levels!
