# Level Organization Guide

## Overview

Your project now uses a **Modular Asset-Based Structure** for organizing levels, waves, and campaigns. This system is designed to scale from a few levels to 50+ levels easily.

## Folder Structure

```
data/
├── levels/
│   └── level_01/
│       └── waves/
│           ├── wave_01.tres
│           ├── wave_02.tres
│           └── ... wave_10.tres
├── level_configs/
│   └── level_01_config.tres
└── campaigns/
    └── main_campaign.tres

scripts/
└── resources/
    ├── wave_data.gd           (Wave configuration)
    ├── enemy_spawn_data.gd    (Enemy spawn info)
    ├── level_config.gd        (Level metadata)
    └── campaign_data.gd       (Campaign progression)

scripts/autoloads/
└── level_manager.gd           (Manages loading/progression)
```

## How It Works

### 1. **Wave Files** (`data/levels/level_01/waves/`)
- Individual `.tres` files for each wave
- Contains enemy types, counts, spawn delays
- Organized by level folder

### 2. **Level Config** (`data/level_configs/level_01_config.tres`)
- Contains all metadata for a level:
  - Level name, description
  - Starting gold and lives
  - References to all wave files
  - Difficulty rating
  - Unlock requirements
  - Bonus gold rewards
- **Edit in Inspector**: Double-click to modify all properties

### 3. **Campaign Data** (`data/campaigns/main_campaign.tres`)
- Groups multiple levels together
- Defines level order and progression
- Campaign-wide settings (name, description, unlock requirements)

### 4. **Level Manager** (Autoload Singleton)
- Loads levels from LevelConfig
- Manages campaign progression
- Handles level completion and rewards
- Automatically sets starting gold/lives

---

## Adding a New Level

### Step 1: Create Wave Files
1. Create folder: `data/levels/level_02/waves/`
2. Copy wave files from level_01 or create new ones
3. Edit each wave in the Inspector

### Step 2: Create Level Scene
1. Duplicate `scenes/levels/level_01.tscn`
2. Rename to `level_02.tscn`
3. Modify the path, decorations, etc.
4. **Important**: Keep the WaveManager node

### Step 3: Create Level Config
1. In FileSystem, navigate to `data/level_configs/`
2. Right-click → **New Resource**
3. Search for "LevelConfig" and create it
4. Name it `level_02_config.tres`
5. **Configure in Inspector**:
   - Level ID: "level_02"
   - Level Name: "Desert Outpost"
   - Starting Gold: 120
   - Starting Lives: 20
   - **Waves**: Drag all 10 wave files from `level_02/waves/`
   - **Level Scene**: Drag `level_02.tscn`
   - Difficulty: 2
   - Required Stars: 3 (need 3 stars to unlock)

### Step 4: Add to Campaign
1. Open `data/campaigns/main_campaign.tres`
2. In Inspector, find **Levels** array
3. Increase **Size** from 1 to 2
4. Drag `level_02_config.tres` into slot [1]
5. Save (Ctrl+S)

---

## Loading Levels

### Method 1: Through LevelManager (Recommended)
```gdscript
# Load level by campaign and level ID
LevelManager.load_level("main", "level_01")

# Load next level in campaign
LevelManager.load_next_level()

# Quick load by level ID (searches all campaigns)
LevelManager.quick_load_level("level_02")
```

### Method 2: Direct Scene Load (Testing)
- Just load the level scene directly: `level_01.tscn`
- WaveManager will fallback to manually assigned waves if LevelManager.current_level is null

---

## Using LevelManager

### Setup (Do Once)
1. **Add LevelManager as Autoload**:
   - Project → Project Settings → Autoload
   - Path: `res://scripts/autoloads/level_manager.gd`
   - Node Name: `LevelManager`
   - Click "Add"

2. **Assign Campaigns**:
   - In the Scene tree, you'll see `LevelManager` node
   - In Inspector, find **Campaigns** array
   - Set Size to 1
   - Drag `main_campaign.tres` into slot [0]

### In Your Level Select Screen
```gdscript
# Get all campaigns
var campaigns = LevelManager.campaigns

# Get all unlocked campaigns
var player_stars = SaveManager.get_total_stars()
var unlocked = LevelManager.get_unlocked_campaigns(player_stars)

# When player clicks a level button:
func _on_level_button_pressed(level_id: String):
    LevelManager.load_level("main", level_id)
```

### In Victory Screen
```gdscript
# Go to next level
func _on_next_level_button_pressed():
    LevelManager.load_next_level()

# Return to level select
func _on_level_select_button_pressed():
    get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")
```

---

## Key Benefits

### ✅ **No Code Changes for New Levels**
- Create level config → Add to campaign → Done!

### ✅ **Easy Balancing**
- Edit starting gold/lives in Inspector
- Adjust star thresholds
- Modify bonus rewards

### ✅ **Reusable Waves**
- Copy wave files between levels
- Create "wave templates" for common patterns

### ✅ **Campaign Management**
- Easy to add new worlds/campaigns
- Control unlock progression
- Track player progress

### ✅ **Inspector-Friendly**
- All configuration done in Inspector
- No need to edit code
- Visual dropdowns and sliders

---

## Common Tasks

### Change Starting Gold for a Level
1. Open `data/level_configs/level_01_config.tres`
2. In Inspector, find **Starting Gold**
3. Change value (e.g., 100 → 150)
4. Save (Ctrl+S)

### Add a Wave to Existing Level
1. Create new wave file: `wave_11.tres` in `level_01/waves/`
2. Open `level_01_config.tres`
3. In Inspector, find **Waves** array
4. Increase Size from 10 to 11
5. Drag `wave_11.tres` into new slot [10]
6. Save

### Create Bonus/Special Campaign
1. Create `bonus_campaign.tres` in `data/campaigns/`
2. Set **Unlocked By Default** to `false`
3. Set **Required Stars** to 30 (need 30 stars to unlock)
4. Add your bonus levels
5. Add to LevelManager's Campaigns array

### Duplicate Level for Testing
1. Duplicate `level_01_config.tres` → `level_01_hard.tres`
2. Change settings:
   - Starting Gold: 50 (harder)
   - Starting Lives: 10
   - Difficulty: 5
3. Keep same waves and scene
4. Add to campaign for testing

---

## Migration from Old System

Your old system had:
- Waves hardcoded in `wave_manager.gd`
- Waves manually assigned in Inspector per level

New system:
- **Waves** stored in `.tres` files (✅ Already done)
- **Level Config** contains wave references (✅ Created)
- **Campaign** manages level progression (✅ Created)
- **LevelManager** loads everything automatically (✅ Created)

**Backward Compatibility**: The WaveManager still supports manually assigned waves in the Inspector. If LevelManager.current_level is null, it uses the old system.

---

## Next Steps

1. **Add LevelManager to Autoload** (see "Setup" section above)
2. **Test level loading** with `LevelManager.quick_load_level("level_01")`
3. **Create level_02** following the "Adding a New Level" guide
4. **Update level select screen** to use LevelManager
5. **Add campaign select screen** (optional, for multiple worlds)

---

## Tips

- **Name consistently**: Use `level_01`, `level_02`, not `forest_level`, `desert_level`
- **Group by campaign**: Create folders like `data/levels/forest/`, `data/levels/desert/`
- **Test often**: Use `LevelManager.quick_load_level()` for quick testing
- **Version control**: `.tres` files are text-based and Git-friendly
- **Backup waves**: Keep a `data/wave_templates/` folder with common wave patterns

---

## Troubleshooting

### "WaveManager: No waves assigned!"
- LevelManager.current_level is null
- Either load through LevelManager or manually assign waves in Inspector

### "Level scene not assigned!"
- Open level config
- Drag level `.tscn` file into **Level Scene** property

### Level loads but wrong settings
- Check LevelManager.current_level in debugger
- Verify LevelConfig has correct starting gold/lives
- Make sure LevelManager is set up as Autoload

---

For more help, see:
- `scripts/resources/level_config.gd` - Level configuration properties
- `scripts/resources/campaign_data.gd` - Campaign structure
- `scripts/autoloads/level_manager.gd` - Level loading logic
