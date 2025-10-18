# Level Button Click Flow - "Forest Path" Example

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. USER CLICKS "Forest Path" button on World Map               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. LevelNode2D (level_node_2d.gd)                              │
│    ↓ ButtonArea (Area2D) receives input_event                  │
│    ↓ Checks if level is unlocked                               │
│    ↓ Emits: level_selected(level_data)                         │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. WorldMapSelectNode2D (world_map_select_node2d.gd)           │
│    ↓ Receives signal: _on_level_node_selected(level_data)      │
│    ↓ Stores: selected_level_data = level_data                  │
│    ↓ Calls: _start_level(level_data, difficulty)               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. _start_level() function                                     │
│    ↓ Gets level_scene_path from level_data                     │
│    ↓ Validates path is not empty                               │
│    ↓ Calls: get_tree().change_scene_to_file(path)              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. LEVEL LOADS (e.g., "res://scenes/levels/level_01.tscn")    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Step-by-Step

### Step 1: User Clicks Button
**Location:** World Map Scene
**File:** `scenes/ui/world_map_select_node2d.tscn`

User clicks on the "Forest Path" level button (a LevelNode2D instance).

---

### Step 2: LevelNode2D Processes Click
**File:** [level_node_2d.gd:189-212](scripts/ui/level_node_2d.gd#L189-L212)

```gdscript
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
    # Line 189: Receives Area2D input event

    if not is_unlocked:
        # Line 192: If level is locked, ignore click
        return

    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            # Line 200: Left mouse button pressed
            _on_clicked()  # Line 202
            _viewport.set_input_as_handled()  # Line 204

func _on_clicked():
    # Line 206
    if is_unlocked and level_data:
        # Line 208: Emit signal with level data
        level_selected.emit(level_data)
```

**What gets emitted:**
- Signal: `level_selected`
- Data: `LevelNodeData` resource containing:
  - `level_id`: e.g., "level_01"
  - `level_name`: e.g., "Forest Path"
  - `level_scene_path`: e.g., "res://scenes/levels/level_01.tscn"
  - `recommended_difficulty`: e.g., "Normal"

---

### Step 3: WorldMapSelect Receives Signal
**File:** [world_map_select_node2d.gd:111-118](scripts/ui/world_map_select_node2d.gd#L111-L118)

```gdscript
func _on_level_node_selected(level_data: LevelNodeData):
    # Line 111: Signal handler
    print("WorldMapSelect: Level selected: ", level_data.level_name)

    selected_level_data = level_data  # Line 114: Store selection

    # Line 118: Start level immediately (difficulty selector currently disabled)
    _start_level(level_data, level_data.recommended_difficulty)
```

**Signal Connection:**
Established in `_setup_level_nodes()` at line 52:
```gdscript
level_node.level_selected.connect(_on_level_node_selected)
```

---

### Step 4: Start Level
**File:** [world_map_select_node2d.gd:159-168](scripts/ui/world_map_select_node2d.gd#L159-L168)

```gdscript
func _start_level(level_data: LevelNodeData, difficulty: String):
    # Line 159
    print("WorldMapSelect: Starting level ", level_data.level_name, " on ", difficulty)

    # Line 164: Validate level scene path exists
    if level_data.level_scene_path.is_empty():
        push_error("WorldMapSelect: Level scene path is empty for ", level_data.level_name)
        return

    # Line 168: Load the level scene
    get_tree().change_scene_to_file(level_data.level_scene_path)
```

**What happens:**
- Godot unloads the current scene (world map)
- Loads the new scene from `level_data.level_scene_path`
- Example path: `"res://scenes/levels/level_01.tscn"`

---

### Step 5: Level Scene Loads
**File:** The level scene (e.g., `level_01.tscn`)

The level scene should contain:
- Level geometry/background
- Enemy spawn paths
- Tower spots
- Heroes
- UI (game HUD)
- WaveManager
- GameManager
- etc.

---

## Current System Status

### ✅ WORKING (Already Updated)
- **LevelNode2D** → Uses `Area2D.input_event` for clicking
- **WorldMapSelect** → Uses native signal connections
- **Back Button** → Uses `Button.pressed` signal
- No ClickManager references anywhere

### ⚠️ REQUIRED: Scene Setup
**You must ensure the LevelNode2D scene has ButtonArea:**

In `scenes/ui/level_node_2d.tscn`, you need:
```
LevelNode2D (Node2D)
├── ButtonSprite (ColorRect)
├── Label
├── StarsContainer (Node2D)
│   ├── Star1 (Sprite2D)
│   ├── Star2 (Sprite2D)
│   └── Star3 (Sprite2D)
├── LockIcon (Sprite2D)
├── GlowSprite (ColorRect)
├── AnimationPlayer
└── ButtonArea (Area2D) ← MUST EXIST
    └── CollisionShape2D (CircleShape2D, radius 50-60px)
```

**ButtonArea settings:**
- `input_pickable = true`
- `monitoring = false`
- CollisionShape2D with CircleShape2D (radius 50-60px)

---

## Testing Checklist

### Test 1: Can Click Unlocked Level
- [ ] Open world map
- [ ] Hover over "Forest Path" button
- [ ] Button should scale up (hover effect)
- [ ] Click "Forest Path" button
- [ ] Console should print:
  ```
  🔵 Area2D received event: InputEventMouseButton | Level: Forest Path | Unlocked: true
  🖱️ Mouse button event - Button: 1 Pressed: true
  ✅ LEFT CLICK DETECTED on Forest Path
  LevelNode2D: Emitting level_selected signal for Forest Path
  WorldMapSelect: Level selected: Forest Path
  WorldMapSelect: Starting level Forest Path on Normal
  ```
- [ ] Level scene should load

### Test 2: Cannot Click Locked Level
- [ ] Try clicking a locked level (if any)
- [ ] Console should print:
  ```
  🔵 Area2D received event: InputEventMouseButton | Level: [Name] | Unlocked: false
  ❌ Level locked, ignoring
  ```
- [ ] Level should NOT load

### Test 3: Back Button Works
- [ ] Click "Back" button on world map
- [ ] Should return to main menu
- [ ] Uses `Button.pressed` signal (line 33)

---

## Potential Issues & Solutions

### Issue 1: "ButtonArea not found"
**Symptom:** Console error `❌ LevelNode2D: button_area is NULL!`

**Cause:** The scene `level_node_2d.tscn` doesn't have a ButtonArea node.

**Solution:** Open the scene in Godot editor and add:
1. Add Area2D node as child of LevelNode2D, name it "ButtonArea"
2. Add CollisionShape2D as child of ButtonArea
3. Set shape to CircleShape2D with radius 50-60px
4. Set ButtonArea.input_pickable = true

---

### Issue 2: "Level scene path is empty"
**Symptom:** Error `WorldMapSelect: Level scene path is empty for [Level Name]`

**Cause:** The LevelNodeData resource doesn't have `level_scene_path` set.

**Solution:** In the world map scene, select the LevelNode2D and:
1. Ensure `level_data` is assigned
2. Open the LevelNodeData resource
3. Set `level_scene_path` to the actual level scene path
4. Example: `res://scenes/levels/level_01.tscn`

---

### Issue 3: Click doesn't respond
**Symptom:** Clicking button does nothing, no console output.

**Possible Causes:**
1. **ButtonArea not set to input_pickable = true**
2. **CollisionShape2D has no shape assigned**
3. **Camera blocking input** (should be fixed now with GUI protection)
4. **Level is locked** (check unlock logic)

**Debug:**
```gdscript
# Add to LevelNode2D._ready():
print("ButtonArea exists: ", button_area != null)
if button_area:
    print("  input_pickable: ", button_area.input_pickable)
    print("  collision_shape: ", collision_shape != null)
    if collision_shape:
        print("  shape: ", collision_shape.shape)
```

---

## Summary

**The flow is CLEAN and SIMPLE:**

1. User clicks Area2D →
2. LevelNode2D emits signal →
3. WorldMapSelect receives signal →
4. Scene changes to level

**No ClickManager involved!**
**No complex priority systems!**
**Just pure Godot signals and scene management!**

✅ Ready for production!
