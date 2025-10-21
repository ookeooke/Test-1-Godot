# Camera Borders System - README

## Quick Start

Your game now has a **smart validation system** that prevents overlapping border configurations!

---

## What Changed?

### Before (Problem):
- Borders were hardcoded in camera
- No way to check if multiple methods were active
- Easy to accidentally set borders in 2 places

### After (Solution):
- ✅ Automatic validation on level start
- ✅ Clear warnings when methods overlap
- ✅ Press F9 to debug borders anytime
- ✅ Console shows which method is active

---

## The 3 Methods

| Method | Where | Best For | Validation |
|--------|-------|----------|------------|
| **1. Auto-Calculate** | LevelConfig | 95% of levels | ✅ Checked |
| **2. Manual** | LevelConfig | Special levels | ✅ Checked |
| **3. Camera Fallback** | Camera node | Single-level games | ⚠️ Warning shown |

---

## How It Works

### On Every Level Start:

```
1. Level loads
   ↓
2. Validation runs automatically
   ↓
3. Console shows status:
   - ✅ No conflicts
   - ⚠️ Warnings (overlapping methods)
   - ❌ Errors (broken setup)
```

### While Playing:

```
Press F9
   ↓
See detailed debug info:
- Which method is active
- Current camera limits
- LevelConfig settings
- Any warnings
```

---

## What Gets Checked?

The system automatically detects:

1. **Multiple methods in same LevelConfig**
   - Both auto-calculate AND manual bounds set
   - Warning shown, auto-calculate wins

2. **Conflicting sources**
   - Camera has custom bounds AND LevelConfig assigned
   - Warning shown, LevelConfig wins

3. **Missing configuration**
   - No LevelConfig assigned
   - Warning shown, camera fallback used

---

## Console Messages Explained

### ✅ Perfect Setup
```
[LevelController] ✅ Bounds configuration validated - no conflicts detected
[LevelController] ✅ Auto-calculated camera bounds: (-400, 0, 2400, 1200)
```
**What it means**: Everything is correct, no action needed!

---

### ⚠️ Warning: Both Auto + Manual
```
[LevelController] ⚠️ CONFIGURATION WARNINGS:
[LevelController]    Both auto_calculate_bounds=true AND manual camera_bounds are set
[LevelController]    → Auto-calculate will be used (manual bounds will be ignored)
```

**What it means**: You set both methods in LevelConfig

**How to fix**:
1. Open your LevelConfig resource
2. Choose ONE:
   - Keep `auto_calculate_bounds = true`, clear `camera_bounds`
   - Set `auto_calculate_bounds = false`, keep `camera_bounds`

---

### ⚠️ Warning: Camera + LevelConfig
```
[LevelController] ⚠️ CONFIGURATION WARNINGS:
[LevelController]    Camera has custom level_rect AND LevelConfig is assigned
[LevelController]    → LevelConfig will override camera's level_rect
```

**What it means**: You set borders in both camera AND LevelConfig

**How to fix**:
1. Open level scene
2. Select Camera2D node
3. Reset `level_rect` to default: `Rect2(-200, 200, 2000, 800)`
4. Use LevelConfig only

---

### ⚠️ Warning: No LevelConfig
```
[LevelController] ⚠️ WARNING: No level_config assigned!
[LevelController] → Using camera's default fallback bounds
[LevelController] → Solution: Create a LevelConfig resource
```

**What it means**: You don't have a LevelConfig (old method)

**How to fix** (for multi-level games):
1. Create LevelConfig resource
2. Set `auto_calculate_bounds = true`
3. Assign to level_controller

---

## Debug Command (F9)

Press **F9** while playing to see:

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
     - current position: (1200, 600)

[3] ACTIVE METHOD:
  📌 Method 1 (Auto-Calculate)

[4] VALIDATION:
[LevelController] ✅ No conflicts detected

========================================
```

---

## Quick Fix Guide

| Problem | Fix |
|---------|-----|
| Multiple methods warning | Choose ONE method in LevelConfig |
| Camera + LevelConfig conflict | Reset camera's level_rect to default |
| No LevelConfig warning | Create and assign LevelConfig |
| Can't scroll far enough | Increase `bounds_padding` |
| Too much empty space | Decrease `bounds_padding` |

---

## Documentation Files

For detailed guides, see:

1. **[BORDERS_QUICK_GUIDE.md](BORDERS_QUICK_GUIDE.md)** - Visual guide to all 3 methods
2. **[BORDERS_VALIDATION.md](BORDERS_VALIDATION.md)** - Complete validation system docs
3. **[MULTI_LEVEL_CAMERA_BOUNDS.md](MULTI_LEVEL_CAMERA_BOUNDS.md)** - Full technical reference

---

## Recommended Workflow

### For Each New Level:

1. **Create level scene**
2. **Create LevelConfig resource**
   - Set `auto_calculate_bounds = true`
   - Set `bounds_padding = 200`
3. **Assign to level_controller**
4. **Test the level**
5. **Check console** for ✅ or ⚠️
6. **Press F9** if you want to see details

### If You See Warnings:

1. **Read the warning message** in console
2. **Follow the fix suggestion** (shown after →)
3. **Restart the level**
4. **Verify** ✅ appears

---

## Summary

**New Features:**
- ✅ Automatic validation on level start
- ✅ Clear warnings when methods overlap
- ✅ F9 debug command for detailed info
- ✅ Tells you which method is active
- ✅ Prevents common mistakes

**Result:** You'll always know exactly how your borders are configured and if there are any conflicts!

---

## Need Help?

1. **Start level** → Check console for ✅ or ⚠️
2. **Press F9** in-game → See detailed debug info
3. **See warnings?** → Read [BORDERS_VALIDATION.md](BORDERS_VALIDATION.md)
4. **Want visual guide?** → Read [BORDERS_QUICK_GUIDE.md](BORDERS_QUICK_GUIDE.md)
5. **Full technical docs?** → Read [MULTI_LEVEL_CAMERA_BOUNDS.md](MULTI_LEVEL_CAMERA_BOUNDS.md)
