# 🗂️ Project Reorganization Plan

## Current State: MESSY ❌
25 files scattered in root folder - hard to navigate!

## Target State: ORGANIZED ✅
Professional folder structure - easy to find everything!

---

## NEW FOLDER STRUCTURE

```
res://
├── scripts/
│   ├── autoloads/              # Global singletons (3 files)
│   │   ├── game_manager.gd
│   │   ├── click_manager.gd
│   │   └── camera_effects.gd
│   │
│   ├── managers/               # Game system managers (3 files)
│   │   ├── wave_manager.gd
│   │   ├── placement_manager.gd
│   │   └── hero_manager.gd
│   │
│   ├── camera/                 # Camera system (3 files)
│   │   ├── camera_controller_improved.gd
│   │   ├── camera_controller.gd (old - can delete later)
│   │   └── camera_settings_ui.gd
│   │
│   └── ui/                     # UI controllers (3 files)
│       ├── ui.gd
│       ├── build_menu.gd
│       └── tower_info_menu.gd
│
├── scenes/
│   ├── levels/                 # Main game levels (1 file)
│   │   └── level_01.tscn (renamed from node_2d.tscn)
│   │
│   ├── enemies/                # Enemy scenes + scripts (4 files)
│   │   ├── goblin_scout.tscn
│   │   ├── goblin_scout.gd
│   │   ├── orc_warrior.tscn
│   │   └── orc_warrior.gd
│   │
│   ├── towers/                 # Already exists! (2 files)
│   │   ├── archer_tower.tscn
│   │   └── archer_tower.gd
│   │
│   ├── heroes/                 # Already exists! (2 files)
│   │   ├── ranger_hero.tscn
│   │   └── ranger_hero.gd
│   │
│   ├── projectiles/            # Already exists! (2 files)
│   │   ├── arrow.tscn
│   │   └── arrow.gd
│   │
│   ├── ui/                     # UI scenes (2 files)
│   │   ├── build_menu.tscn
│   │   └── tower_info_menu.tscn
│   │
│   ├── spots/                  # Placement spots (4 files)
│   │   ├── tower_spot.tscn
│   │   ├── tower_spot.gd
│   │   ├── hero_spot.tscn
│   │   └── hero_spot.gd
│   │
│   └── managers/               # Manager scenes (1 file)
│       └── game_manager.tscn
│
└── docs/                       # Documentation (keep existing)
	├── SETUP_COMPLETE.md
	├── CAMERA_UPGRADE_GUIDE.md
	└── CAMERA_RECOMMENDED_SETTINGS.md
```

---

## DETAILED MOVE PLAN

### Phase 1: Move Autoload Scripts
```
FROM                          TO
────────────────────────────────────────────────────────────
game_manager.gd        →     scripts/autoloads/game_manager.gd
click_manager.gd       →     scripts/autoloads/click_manager.gd
camera_effects.gd      →     scripts/autoloads/camera_effects.gd
```

### Phase 2: Move Manager Scripts
```
FROM                          TO
────────────────────────────────────────────────────────────
wave_manager.gd        →     scripts/managers/wave_manager.gd
placement_manager.gd   →     scripts/managers/placement_manager.gd
hero_manager.gd        →     scripts/managers/hero_manager.gd
```

### Phase 3: Move Camera Scripts
```
FROM                          TO
────────────────────────────────────────────────────────────
camera_controller_improved.gd → scripts/camera/camera_controller_improved.gd
camera_controller.gd          → scripts/camera/camera_controller_old.gd (rename)
camera_settings_ui.gd         → scripts/camera/camera_settings_ui.gd
```

### Phase 4: Move UI Scripts
```
FROM                          TO
────────────────────────────────────────────────────────────
ui.gd                  →     scripts/ui/ui.gd
build_menu.gd          →     scripts/ui/build_menu.gd
tower_info_menu.gd     →     scripts/ui/tower_info_menu.gd
```

### Phase 5: Move Enemy Files
```
FROM                          TO
────────────────────────────────────────────────────────────
goblin_scout.tscn      →     scenes/enemies/goblin_scout.tscn
goblin_scout.gd        →     scenes/enemies/goblin_scout.gd
orc_warrior.tscn       →     scenes/enemies/orc_warrior.tscn
orc_warrior.gd         →     scenes/enemies/orc_warrior.gd
```

### Phase 6: Move UI Scenes
```
FROM                          TO
────────────────────────────────────────────────────────────
build_menu.tscn        →     scenes/ui/build_menu.tscn
tower_info_menu.tscn   →     scenes/ui/tower_info_menu.tscn
```

### Phase 7: Move Spot Files
```
FROM                          TO
────────────────────────────────────────────────────────────
tower_spot.tscn        →     scenes/spots/tower_spot.tscn
tower_spot.gd          →     scenes/spots/tower_spot.gd
hero_spot.tscn         →     scenes/spots/hero_spot.tscn
hero_spot.gd           →     scenes/spots/hero_spot.gd
```

### Phase 8: Rename & Move Main Level
```
FROM                          TO
────────────────────────────────────────────────────────────
node_2d.tscn           →     scenes/levels/level_01.tscn
node_2d.gd             →     DELETE (empty/unused)
```

### Phase 9: Move Manager Scene
```
FROM                          TO
────────────────────────────────────────────────────────────
game_manager.tscn      →     scenes/managers/game_manager.tscn
```

---

## WHAT NEEDS TO BE UPDATED AFTER MOVING

### 1. Project Settings (autoloads)
```
OLD PATH                       NEW PATH
────────────────────────────────────────────────────────────
res://game_manager.tscn   →   res://scenes/managers/game_manager.tscn
res://click_manager.gd    →   res://scripts/autoloads/click_manager.gd
res://camera_effects.gd   →   res://scripts/autoloads/camera_effects.gd
```

### 2. Main Scene Reference
```
OLD: res://node_2d.tscn
NEW: res://scenes/levels/level_01.tscn
```

### 3. Scene Internal References
Godot should auto-update these, but verify:
- tower_spot.tscn → script path
- hero_spot.tscn → script path
- build_menu.tscn → script path
- All enemy scenes → script paths

---

## IMPLEMENTATION OPTIONS

### OPTION A: Manual (Safest, 15 minutes)
**Do this in Godot Editor** - Godot auto-updates references!

1. Create folders in FileSystem panel (right-click → New Folder)
2. Drag files from root to new folders
3. Godot will ask "Update dependencies?" → Click YES
4. Update Project Settings → Autoload paths
5. Update Project Settings → Main Scene
6. Test game (F5)

**PROS:**
- ✅ Godot auto-fixes all references
- ✅ Safest method
- ✅ See what's happening

**CONS:**
- ⏱️ Takes 15 minutes of dragging

---

### OPTION B: Script-Assisted (Faster, 5 minutes)
I write a script that:
1. Moves all files via command line
2. Updates all .tscn files automatically
3. Updates project.godot automatically
4. You test in Godot

**PROS:**
- ✅ Fast (5 minutes)
- ✅ Accurate
- ✅ Can undo if needed

**CONS:**
- ⚠️ Requires trusting the script
- ⚠️ Must close Godot first

---

### OPTION C: Start Fresh (Nuclear, 30 minutes)
Keep existing project, but:
1. Create new Godot project with proper structure
2. Copy files to new locations
3. Import scenes one by one
4. Rebuild connections

**PROS:**
- ✅ Guaranteed clean structure
- ✅ Good learning experience

**CONS:**
- ⏱️ Takes 30-45 minutes
- 🔧 More work

---

## MY RECOMMENDATION

### For Your Project: **OPTION A (Manual in Godot)**

Here's why:
1. **Safest** - Godot handles all reference updates
2. **You learn** - See how Godot organizes projects
3. **No risk** - Can undo (Ctrl+Z) at any step
4. **Only 15 minutes** - Not that long

I'll give you a **step-by-step visual guide** to do this in Godot!

---

## BENEFITS AFTER REORGANIZATION

### Before (Current)
```
📁 res://
   📄 25 files scattered everywhere
   😵 "Where is tower_spot.gd?"
   😵 "Which scene is the main level?"
   😵 "Is this a script or scene?"
```

### After (Organized)
```
📁 scripts/
   📁 autoloads/    ← Singletons here
   📁 managers/     ← Game systems here
   📁 camera/       ← Camera stuff here
   📁 ui/           ← UI scripts here

📁 scenes/
   📁 levels/       ← Main levels here
   📁 enemies/      ← All enemies here
   📁 towers/       ← All towers here
   📁 heroes/       ← All heroes here

😊 "Easy to find everything!"
😊 "Clear what each folder contains!"
😊 "Professional structure!"
```

### Benefits:
- ✅ Find files instantly
- ✅ Easier to add new content
- ✅ Team members understand structure
- ✅ Scales to 100+ files
- ✅ Industry-standard organization
- ✅ Asset packs drop into correct folders

---

## COMPARISON TO PROFESSIONAL GAMES

Your structure will match:
- **Hollow Knight** (indie hit)
- **Celeste** (award winner)
- **Dead Cells** (commercial success)

All use similar folder structures!

---

## READY TO REORGANIZE?

Choose your option:

**A) Manual in Godot** (Recommended)
→ Say: "Give me the step-by-step guide"
→ I'll write a detailed visual guide

**B) Script-Assisted**
→ Say: "Run the reorganization script"
→ I'll write and run the script for you

**C) Keep as-is for now**
→ Say: "I'll organize later"
→ We can do it when you have more time

What do you want to do? 🚀
