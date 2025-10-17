# Project Structure - Tower Defense Game

## Complete File Organization

```
Test-1-Godot/
│
├── 📁 data/                                    # Game data (resources)
│   ├── 📁 levels/                             # Level-specific data
│   │   └── 📁 level_01/
│   │       └── 📁 waves/                      # Waves for level_01
│   │           ├── wave_01.tres
│   │           ├── wave_02.tres
│   │           └── ... (wave_03 to wave_10)
│   │
│   ├── 📁 level_configs/                      # Level metadata
│   │   └── level_01_config.tres              # 🔧 Edit in Inspector
│   │
│   └── 📁 campaigns/                          # Campaign progression
│       └── main_campaign.tres                # 🔧 Edit in Inspector
│
├── 📁 scenes/                                  # Visual scenes (.tscn)
│   ├── 📁 enemies/
│   │   ├── goblin_scout.tscn
│   │   ├── orc_warrior.tscn
│   │   ├── wolf_runner.tscn
│   │   ├── troll_boss.tscn
│   │   └── bat_flyer.tscn
│   │
│   ├── 📁 heroes/
│   │   └── ranger_hero.tscn
│   │
│   ├── 📁 towers/
│   │   └── archer_tower.tscn
│   │
│   ├── 📁 levels/
│   │   └── level_01.tscn                     # 🎮 The actual level scene
│   │
│   ├── 📁 ui/
│   │   ├── main_menu.tscn
│   │   ├── level_select.tscn
│   │   ├── victory_screen.tscn
│   │   └── ... (other UI)
│   │
│   └── 📁 projectiles/
│       └── arrow.tscn
│
├── 📁 scripts/                                 # GDScript files
│   ├── 📁 resources/                          # 📦 Custom Resource Classes
│   │   ├── wave_data.gd                      # Wave configuration
│   │   ├── enemy_spawn_data.gd               # Enemy spawn info
│   │   ├── level_config.gd                   # ⭐ NEW: Level metadata
│   │   └── campaign_data.gd                  # ⭐ NEW: Campaign data
│   │
│   ├── 📁 autoloads/                          # 🌐 Singleton scripts
│   │   ├── game_manager.gd                   # Game state (gold, lives)
│   │   ├── save_manager.gd                   # Save/load progress
│   │   ├── click_manager.gd                  # Input handling
│   │   ├── camera_effects.gd                 # Camera shake/effects
│   │   └── level_manager.gd                  # ⭐ NEW: Level loading
│   │
│   ├── 📁 managers/
│   │   ├── wave_manager.gd                   # ✏️ UPDATED: Spawns enemies
│   │   ├── hero_manager.gd                   # Manages hero placement
│   │   └── placement_manager.gd              # Tower/hero placement
│   │
│   ├── 📁 enemies/
│   │   └── base_enemy.gd                     # Base enemy logic
│   │
│   ├── 📁 camera/
│   │   └── camera_controller_improved.gd
│   │
│   └── 📁 ui/
│       ├── ui.gd
│       ├── health_bar.gd
│       └── ... (other UI scripts)
│
├── 📄 LEVEL_ORGANIZATION_GUIDE.md             # ⭐ NEW: How to use system
├── 📄 PROJECT_STRUCTURE.md                    # ⭐ NEW: This file
└── 📄 project.godot
```

## Key Files Explained

### 🔧 Files You Edit in Inspector

| File | Purpose | How to Edit |
|------|---------|-------------|
| `wave_01.tres` | Single wave configuration | Double-click → Edit in Inspector |
| `level_01_config.tres` | Level metadata (gold, lives, waves) | Double-click → Edit in Inspector |
| `main_campaign.tres` | Campaign with all levels | Double-click → Edit in Inspector |

### 📦 Resource Classes (Scripts)

| File | Purpose | When to Edit |
|------|---------|-------------|
| `wave_data.gd` | Defines wave properties | Add new wave features |
| `enemy_spawn_data.gd` | Defines enemy spawn properties | Add spawn features |
| `level_config.gd` | Defines level properties | Add level settings |
| `campaign_data.gd` | Defines campaign properties | Add campaign features |

### 🌐 Autoload Singletons (Always Available)

| Singleton | Access With | Purpose |
|-----------|-------------|---------|
| GameManager | `GameManager.gold` | Game state (gold, lives) |
| SaveManager | `SaveManager.save_game()` | Save/load progress |
| LevelManager | `LevelManager.load_level()` | Load levels/campaigns |
| ClickManager | `ClickManager.register_clickable()` | Click handling |
| CameraEffects | `CameraEffects.shake()` | Camera effects |

## Data Flow

```
main_campaign.tres
    │
    ├── Contains → level_01_config.tres
    │                   │
    │                   ├── Contains → wave_01.tres
    │                   ├── Contains → wave_02.tres
    │                   └── ... (wave_03 to wave_10)
    │                   │
    │                   └── References → level_01.tscn
    │
    └── (Future) level_02_config.tres
```

## How Levels Load

1. **Player clicks level button** in level select screen
2. **LevelManager.load_level("main", "level_01")** is called
3. LevelManager finds the level config
4. Sets `GameManager.gold` and `GameManager.lives` from config
5. Loads the level scene (`level_01.tscn`)
6. **WaveManager** reads waves from `LevelManager.current_level`
7. Waves spawn enemies automatically

## Scaling to More Levels

### For 5-15 Levels (Current Approach)
```
data/levels/
├── level_01/waves/
├── level_02/waves/
└── level_03/waves/
```

### For 20-50 Levels (Group by World)
```
data/levels/
├── forest/
│   ├── forest_01/waves/
│   ├── forest_02/waves/
│   └── forest_03/waves/
├── desert/
│   ├── desert_01/waves/
│   └── desert_02/waves/
└── mountains/
    └── mountain_01/waves/
```

### For 50+ Levels (Full Modular)
```
data/
├── campaigns/
│   ├── main_campaign.tres
│   ├── bonus_campaign.tres
│   └── endless_campaign.tres
├── level_configs/
│   ├── forest_01_config.tres
│   └── ... (all level configs)
└── wave_presets/
    ├── goblin_rush.tres
    └── mixed_assault.tres  (reusable waves)
```

## Quick Reference

### Add New Level
1. Create `level_02/waves/` folder
2. Create `level_02.tscn` scene
3. Create `level_02_config.tres`
4. Add to `main_campaign.tres`

### Edit Level Settings
1. Open `level_01_config.tres`
2. Edit in Inspector
3. Save

### Test Level
```gdscript
LevelManager.quick_load_level("level_01")
```

## See Also

- 📖 [LEVEL_ORGANIZATION_GUIDE.md](LEVEL_ORGANIZATION_GUIDE.md) - Detailed usage guide
- 📖 [tower-defense-claude.instructions.md](.github/instructions/) - Project instructions
