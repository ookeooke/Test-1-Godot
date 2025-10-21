# Camera Borders Validation System

## What This Does

The system **automatically checks** when you start a level to make sure you're not accidentally using multiple border configuration methods at once.

---

## Automatic Validation (On Level Start)

Every time a level starts, you'll see console output like this:

### ✅ Perfect Configuration (No Issues)

```
[LevelController] ✅ Bounds configuration validated - no conflicts detected
[LevelController] ✅ Auto-calculated camera bounds: (-400, 0, 2400, 1200) (padding: 200)
```

**Meaning**: Everything is set up correctly!

---

### ⚠️ Warning: Multiple Methods Active

```
[LevelController] ⚠️ CONFIGURATION WARNINGS:
[LevelController]    Both auto_calculate_bounds=true AND manual camera_bounds are set
[LevelController]    → Auto-calculate will be used (manual bounds will be ignored)
```

**What happened**: You set BOTH auto-calculate AND manual bounds in LevelConfig

**Fix**:
1. Open your LevelConfig resource
2. Choose ONE method:
   - **Auto**: Set `auto_calculate_bounds = true`, leave `camera_bounds` empty
   - **Manual**: Set `auto_calculate_bounds = false`, set `camera_bounds` to your values

---

### ⚠️ Warning: Camera + LevelConfig Conflict

```
[LevelController] ⚠️ CONFIGURATION WARNINGS:
[LevelController]    Camera has custom level_rect AND LevelConfig is assigned
[LevelController]    → LevelConfig will override camera's level_rect (camera bounds will be ignored)
```

**What happened**: You set bounds in BOTH the camera AND the LevelConfig

**Fix**: Choose ONE:
- **Use LevelConfig** (recommended): Leave camera's `level_rect` at default, use LevelConfig only
- **Use camera only**: Remove the LevelConfig assignment (not recommended for multi-level games)

---

### ⚠️ Warning: No LevelConfig

```
[LevelController] ⚠️ WARNING: No level_config assigned!
[LevelController] → Using camera's default fallback bounds (NOT recommended for multi-level games)
[LevelController] → Solution: Create a LevelConfig resource and assign it to this level_controller
```

**What happened**: You don't have a LevelConfig resource assigned

**Fix**: Create a LevelConfig:
1. Right-click in FileSystem → New Resource → LevelConfig
2. Save it (e.g., `level_01_config.tres`)
3. Assign it to your level's root node → "Level Config" property

---

## Manual Debug Check (Press F9 In-Game)

While playing your level, press **F9** to see detailed bounds information:

### Example Output:

```
========================================
CAMERA BOUNDS DEBUG INFO
========================================

[1] CONFIGURATION:
  ✅ LevelConfig assigned: res://resources/levels/level_01_config.tres
     - auto_calculate_bounds: true
     - camera_bounds: (0, 0, 0, 0)
     - bounds_padding: 200

[2] CAMERA STATE:
  ✅ Camera found
     - level_rect: (-400, 0, 2400, 1200)
     - limit_left: 560
     - limit_right: 1840
     - limit_top: 540
     - limit_bottom: 660
     - current position: (1200, 600)

[3] ACTIVE METHOD:
  📌 Method 1 (Auto-Calculate) - Bounds from content + padding

[4] VALIDATION:
[LevelController] ✅ Bounds configuration validated - no conflicts detected

========================================
```

---

## What Each Section Means

### [1] CONFIGURATION
Shows your LevelConfig settings:
- **auto_calculate_bounds**: true = automatic, false = manual
- **camera_bounds**: Your manual bounds (or 0,0,0,0 if auto)
- **bounds_padding**: Extra space when auto-calculating

### [2] CAMERA STATE
Shows the actual camera limits in use:
- **level_rect**: The playable area rectangle
- **limit_left/right/top/bottom**: The actual pixel limits where camera CENTER can move
- **current position**: Where the camera is right now

### [3] ACTIVE METHOD
Tells you which of the 3 methods is currently being used:
- **Method 1**: Auto-calculate from content
- **Method 2**: Manual bounds from LevelConfig
- **Method 3**: Camera fallback (old way)

### [4] VALIDATION
Shows any warnings or conflicts detected

---

## Common Warnings & Fixes

| Warning | Cause | Fix |
|---------|-------|-----|
| "Both auto AND manual are set" | You set both methods in LevelConfig | Choose one: turn off auto OR clear manual bounds |
| "Camera has custom level_rect AND LevelConfig" | You set bounds in both places | Clear camera's level_rect, use LevelConfig only |
| "No level_config assigned" | No LevelConfig resource | Create and assign a LevelConfig resource |
| "Using camera's default fallback" | Using old method | Create a LevelConfig for better multi-level support |

---

## Quick Debug Checklist

**When starting a level**, check the console for:

1. ✅ Green checkmark = good!
2. ⚠️ Yellow warning = works but not ideal
3. ❌ Red error = something is broken

**While playing**, press **F9** to see:
- Which method is active
- Current camera limits
- Any configuration conflicts

---

## Best Practices

### ✅ DO:
- Use ONE method per level (either auto or manual in LevelConfig)
- Press F9 in-game to verify borders work correctly
- Check console on level start for warnings

### ❌ DON'T:
- Don't set both auto_calculate AND manual bounds
- Don't set bounds in both camera AND LevelConfig
- Don't ignore warnings in the console

---

## Summary

The validation system automatically checks for:
1. **Overlapping methods** (auto + manual in same LevelConfig)
2. **Conflicting sources** (camera + LevelConfig both set)
3. **Missing configuration** (no LevelConfig assigned)

You can:
- **See warnings automatically** on level start
- **Press F9 in-game** for detailed debug info
- **Fix issues** by choosing only ONE border configuration method

**Result**: You'll always know exactly which method is being used and if there are any conflicts!
