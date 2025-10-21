# Camera Borders - Quick Visual Guide

## The 3 Methods (Simple Explanation)

```
┌─────────────────────────────────────────────────────────┐
│ METHOD 1: AUTO-CALCULATE (Recommended)                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [LevelConfig Resource]                                 │
│   ├─ auto_calculate_bounds = ✅ TRUE                    │
│   └─ bounds_padding = 200                               │
│                                                         │
│  System finds all towers, paths, spawners               │
│  → Calculates perfect fit                               │
│  → Adds padding                                         │
│                                                         │
│  ✅ Automatic                                           │
│  ✅ Updates when you move objects                       │
│  ✅ Different padding per level                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ METHOD 2: MANUAL (Full Control)                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [LevelConfig Resource]                                 │
│   ├─ auto_calculate_bounds = ❌ FALSE                   │
│   └─ camera_bounds = Rect2(-500, 0, 3000, 1500)        │
│                                                         │
│  You set exact coordinates:                             │
│   - Position X, Y (top-left corner)                     │
│   - Size X, Y (width, height)                           │
│                                                         │
│  ✅ Full control                                        │
│  ⚠️ Must update manually if level changes               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ METHOD 3: CAMERA FALLBACK (Old Way - Not Recommended)  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  [No LevelConfig]                                       │
│  [Camera2D]                                             │
│   └─ level_rect = Rect2(-200, 200, 2000, 800)          │
│                                                         │
│  Camera uses its default fallback                       │
│                                                         │
│  ⚠️ Only works for single-level games                   │
│  ⚠️ All levels share same bounds                        │
└─────────────────────────────────────────────────────────┘
```

---

## Validation System (Automatic Checks)

### When Level Starts:

```
┌──────────────────────────┐
│ Level Loads              │
└───────────┬──────────────┘
            │
            ↓
┌──────────────────────────┐
│ Validation Check Runs    │
│                          │
│ Checks for:              │
│ 1. Multiple methods      │
│ 2. Conflicting settings  │
│ 3. Missing configuration │
└───────────┬──────────────┘
            │
            ↓
    ┌───────┴────────┐
    │                │
    ↓                ↓
┌────────┐      ┌──────────┐
│ ✅ OK  │      │ ⚠️ Warning│
└────────┘      └──────────┘
                     ↓
            See console for details
```

### Console Output Examples:

**Perfect setup:**
```
✅ Bounds configuration validated - no conflicts detected
✅ Auto-calculated camera bounds: (-400, 0, 2400, 1200)
```

**Warning - Multiple methods:**
```
⚠️ CONFIGURATION WARNINGS:
   Both auto_calculate_bounds=true AND manual camera_bounds are set
   → Auto-calculate will be used (manual bounds will be ignored)
```

---

## Quick Decision Tree

```
Do you have multiple levels?
    │
    ├─ YES → Use LevelConfig (Method 1 or 2)
    │         │
    │         ├─ Want automatic? → Method 1 (auto-calculate)
    │         └─ Want exact control? → Method 2 (manual)
    │
    └─ NO (single level) → Method 3 is OK (camera fallback)
```

---

## Press F9 For Debug Info

```
┌─────────────────────────────────────────┐
│  Press F9 while playing level           │
└──────────────┬──────────────────────────┘
               │
               ↓
┌──────────────────────────────────────────┐
│ Console shows:                           │
│                                          │
│ [1] Your configuration                   │
│     - LevelConfig settings               │
│     - Which method is active             │
│                                          │
│ [2] Current camera state                 │
│     - Actual limits in use               │
│     - Current camera position            │
│                                          │
│ [3] Active method                        │
│     - Which of the 3 methods is running  │
│                                          │
│ [4] Validation results                   │
│     - Any warnings or conflicts          │
└──────────────────────────────────────────┘
```

---

## Common Scenarios (Visual)

### Scenario A: New Level (Best Practice)

```
1. Create level scene
   ↓
2. Create LevelConfig resource
   ↓
3. Set: auto_calculate_bounds = true
   ↓
4. Assign to level_controller
   ↓
5. ✅ Done! Borders are automatic
```

### Scenario B: Multiple Levels (Different Sizes)

```
Level 1:                Level 2:                Level 3:
  LevelConfig 1           LevelConfig 2           LevelConfig 3
  auto = true             auto = true             auto = true
  padding = 200           padding = 400           padding = 150
  ↓                       ↓                       ↓
  Small borders           Large borders           Tight borders
```

### Scenario C: Special Level (Exact Control)

```
Boss Arena Level:
  LevelConfig
  auto = false
  camera_bounds = Rect2(0, 0, 1920, 1080)  ← Exact screen size
  ↓
  Camera can't scroll (fixed arena)
```

---

## Visual: What Gets Checked

```
┌───────────────────────────────────────────────────┐
│ VALIDATION CHECKS                                 │
├───────────────────────────────────────────────────┤
│                                                   │
│ ✓ Is LevelConfig assigned?                       │
│   └─ NO → ⚠️ Using camera fallback                │
│                                                   │
│ ✓ Is auto_calculate_bounds = true?               │
│   └─ AND camera_bounds also set?                 │
│       └─ YES → ⚠️ Both methods active             │
│                                                   │
│ ✓ Does camera have custom level_rect?            │
│   └─ AND LevelConfig assigned?                   │
│       └─ YES → ⚠️ Conflict detected               │
│                                                   │
│ ✓ Using default camera bounds?                   │
│   └─ AND no LevelConfig?                         │
│       └─ YES → ⚠️ Multi-level warning             │
│                                                   │
└───────────────────────────────────────────────────┘
```

---

## Summary Cheatsheet

| **What You Want** | **Which Method** | **Settings** |
|-------------------|------------------|--------------|
| Automatic borders | Method 1 | LevelConfig: auto=true, padding=200 |
| Exact control | Method 2 | LevelConfig: auto=false, bounds=Rect2(...) |
| Quick test (1 level) | Method 3 | No LevelConfig, use camera defaults |
| Different borders per level | Method 1 or 2 | Each level gets its own LevelConfig |
| Debug/check setup | Press F9 | See detailed info in console |

---

## Status Indicators

When you see these in console:

- **✅ Green checkmark** = Perfect! No issues
- **⚠️ Yellow warning** = Works, but not ideal (check the warning)
- **❌ Red error** = Something is broken (must fix)
- **📌 Blue pin** = Information (shows which method is active)

---

## One-Line Summary

**Use LevelConfig with auto_calculate_bounds=true for 95% of levels, press F9 to debug!**
