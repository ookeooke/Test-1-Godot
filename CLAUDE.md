# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Type:** 2D Tower Defense Game
**Engine:** Godot 4.5
**Language:** GDScript
**Platform:** PC (Windows) + Mobile (Android/iOS)

## Development Commands

### Running the Game
- Press **F5** in Godot editor to run
- Main scene: `res://scenes/ui/main_menu.tscn`
- Test level: `res://scenes/levels/level_01.tscn`

### Debug Keys (In-Game)
- **F3** - Toggle balance HUD (FPS, metrics)
- **F4** - Export balance data to CSV/JSON
- **1-4** - Game speed (1x, 2x, 4x, 8x)
- **I** - Toggle inventory
- **ESC** - Pause / close panels

### Balance Data Export Location
```
C:\Users\ollil\AppData\Roaming\Godot\app_userdata\Test 1\balance_debug\exports\
```

## Architecture: Autoload Singleton Pattern

This project uses **19 autoload singletons** as the architectural foundation. All major systems are globally accessible via autoloads (see [project.godot:18-42](project.godot#L18-L42)).

### Critical Autoloads

**State & Game Flow:**
- `GameStateManager` - Central state with modifier system (gold, lives, stat calculation)
- `LevelManager` - Campaign & level progression
- `EnemyManager` - Centralized enemy tracking (90% performance improvement vs per-tower searches)

**Data & Resources:**
- `HeroDatabase` / `ItemDatabase` - Pre-loaded resource databases for O(1) lookup
- `TowerData` - Single source of truth for tower stats

**Progression Systems:**
- `InventoryManager` - Account-wide inventory (Dungeon Defenders pattern)
- `SaveManager` - Profile save/load system (`user://saves/{profile_name}.save`)
- `LootManager` - Tiered loot generation with rarity weights

**Gameplay:**
- `WaveManager` - Enemy spawning orchestration
- `HeroManager` - Hero selection & movement
- `PlacementManager` - Tower placement validation

**Debug & Tools:**
- `BalanceTracker` / `BalanceExporter` / `BalanceAnalyzer` - Real-time metrics tracking

**UI & Interface:**
- `UIScaleManager` - DPI-aware UI scaling system with theme-based scaling
- `WebFullscreenManager` - Web platform fullscreen and mobile detection

## UI Scaling System

This project implements **professional-grade UI scaling** via `UIScaleManager` that automatically adapts interface elements to different screen resolutions and DPI densities.

### Key Features

- **Design Resolution:** 1920x1080 baseline (industry standard)
- **Height-Based Scaling:** Maintains consistent vertical framing across aspect ratios
- **Theme System:** Automatically scales fonts, spacing, and margins
- **Touch Target Compliance:** Ensures 44-48dp minimum for mobile usability
- **Scale Constraints:** 0.5x to 2.0x prevents extreme distortions
- **Debounced Resize:** 100ms delay prevents performance issues during window resizing

### Usage Examples

```gdscript
# Get current UI scale (1.0 at 1080p, 0.67 at 720p, 2.0 at 4K)
var current_scale = UIScaleManager.ui_scale

# Scale individual values (useful for custom UI elements)
var button_width = UIScaleManager.get_scaled_value(100.0)  # Returns 100px at 1080p, 200px at 4K
var button_size = UIScaleManager.get_scaled_size(Vector2(80, 60))  # Scales both dimensions

# Validate touch targets meet 44x44dp minimum
var is_valid = UIScaleManager.is_valid_touch_target(Vector2(60, 60))  # Returns true

# Listen for scale changes (useful for dynamic layouts)
UIScaleManager.scale_changed.connect(_on_ui_scale_changed)

func _on_ui_scale_changed(new_scale: float):
    # Recalculate custom UI element sizes
    update_layout()
```

### When to Use UIScaleManager

**Use `get_scaled_value()` for:**
- Custom-drawn UI elements (not using Control nodes)
- Procedurally generated layouts
- Canvas-based UI (CanvasItem not Control)
- Dynamic positioning calculations

**Don't use for:**
- Standard Control nodes with Theme (already auto-scaled)
- Elements using `custom_minimum_size` (theme handles these)
- Most game UI (theme system is sufficient)

### Resolution Behavior

| Resolution | Scale | Use Case |
|------------|-------|----------|
| 1280x720 | 0.67x | Budget laptops, low-end |
| 1920x1080 | 1.0x | Baseline (most common) |
| 2560x1440 | 1.33x | High-end desktop |
| 3840x2160 | 2.0x | 4K monitors |

**Mobile:** Scale adapts to device height, typically 0.7x to 1.5x depending on screen size.

### Platform-Specific Behavior

- **Desktop:** Responds to window resize in real-time
- **Mobile:** Adapts to device resolution and orientation changes
- **Web:** Uses browser window size, handles fullscreen transitions

See: [scripts/autoloads/ui_scale_manager.gd](scripts/autoloads/ui_scale_manager.gd)

## Key Architectural Patterns

### 1. Separated Resource Loading
- **LevelConfig** (gameplay data: waves, gold, lives) ≠ **LevelNodeData** (UI metadata: map position)
- Allows world map to load without parsing wave data for 100+ levels
- See: [scripts/resources/level_config.gd](scripts/resources/level_config.gd)

### 2. Three-Phase Modifier System
All stats calculated as: `(base + flat_mods + additive_mods) × multiplicative_mods`
- **Flat** - Direct addition (+10 damage)
- **Additive** - Percentage of base (+20% = base × 0.20)
- **Multiplicative** - Final multiplier (1.5× total)

Implemented in: [scripts/autoloads/game_state_manager.gd](scripts/autoloads/game_state_manager.gd)

### 3. Dual Navigation Systems
Both systems supported via `use_waypoint_system` flag:
- **Path2D** - Legacy curve-based pathfinding
- **PathWaypoint** - Manual placement with visual road rendering

**Full documentation:** [docs/WAYPOINT_SYSTEM_GUIDE.md](docs/WAYPOINT_SYSTEM_GUIDE.md)

### 4. Input Event Flow (4-Stage System)

```
Stage 1: _input()           → Pause menu, global shortcuts
Stage 2: GUI Controls       → Buttons, panels (Control nodes)
Stage 3: _unhandled_input() → Hero movement, camera (RECOMMENDED for gameplay)
Stage 4: Physics Area2D     → Tower/hero click detection
```

**Critical:** Use `_unhandled_input()` for gameplay input, NOT `_input()` (blocks everything!)

**Full documentation:** [docs/INPUT_SYSTEM.md](docs/INPUT_SYSTEM.md)

## File Organization

```
scripts/
├── autoloads/          # 19 singletons
├── managers/           # Gameplay managers (waves, heroes, enemies, placement)
├── resources/          # Resource classes (HeroData, ItemData, LevelConfig, etc.)
├── ui/                 # UI scripts (29 files)
├── debug/              # Balance tracking tools
├── pathfinding/        # Waypoint/road systems
└── enemies/            # base_enemy.gd

scenes/
├── levels/             # Level scenes
├── towers/             # Tower prefabs
├── enemies/            # Enemy prefabs (goblin, orc, wolf, troll, bat)
├── heroes/             # Hero prefabs
└── ui/                 # UI scenes

resources/
├── heroes/             # *.tres HeroData
├── items/              # *.tres ItemData (by category)
└── skills/             # *.tres HeroSkillData

docs/                   # Detailed system documentation
```

## Common Development Tasks

### Adding a New Enemy
1. Duplicate existing enemy scene (e.g., `scenes/enemies/goblin_scout.tscn`)
2. Adjust stats: speed, max_health, gold_reward, armor, life_damage
3. Add to `EnemySpawnData` in wave configurations

### Adding a New Hero
1. Create HeroData resource in `resources/heroes/`
2. Set: hero_id, hero_class, base stats, equipment restrictions
3. Create hero scene in `scenes/heroes/`
4. Add to HeroDatabase preload list

### Adding a New Item
1. Create ItemData resource in `resources/items/{category}/`
2. Set: item_id, item_type, rarity, stat bonuses
3. Add to loot tables in LootManager
4. Icon auto-generated by IconGeneratorAutoload

### Adding a New Wave
1. Edit level's LevelConfig resource
2. Add WaveData to waves array
3. Define EnemySpawnData array (enemy_type + count)
4. Set hp_multiplier, gold_multiplier for difficulty scaling

### Adding a New Level
1. Duplicate `scenes/levels/level_01.tscn`
2. Create LevelConfig resource in `data/level_configs/`
3. Place waypoints, tower spots, spawn points
4. Add to campaign's levels array
5. Create LevelNodeData for world map position

## Critical Systems

### Wave System
- **WaveManager** flattens `Array[EnemySpawnData]` into spawn queue
- Supports "Call Next Wave" buttons (Kingdom Rush pattern) with gold bonuses
- Emits `combat_started()` / `combat_ended()` for UI coordination
- See: [scripts/managers/wave_manager.gd](scripts/managers/wave_manager.gd)

### Loot System
Tiered drop rates:
- **Tier 1** (Goblin): 15% drop, 70% Common / 25% Uncommon / 5% Rare
- **Tier 2** (Orc/Wolf): 30% drop, includes Epic (5%)
- **Tier 3** (Troll): 50% drop, includes Epic (9%)
- **Boss**: 100% guaranteed + 3 items, includes Legendary (5%)

### Save System
- Location: `user://saves/{profile_name}.save`
- Stores: progress, inventory (with upgrade levels), hero equipment, settings, stats
- See: [scripts/autoloads/save_manager.gd](scripts/autoloads/save_manager.gd)

### Balance Tracking
- **BalanceTracker** records damage, kills, tower placement, economy
- **BalanceExporter** exports to CSV/JSON for analysis
- Tracks tower efficiency, enemy difficulty, gold economy
- See: [scripts/debug/balance_tracker.gd](scripts/debug/balance_tracker.gd)

## Important Gotchas

1. **Autoload order matters** - Dependencies require specific initialization order
2. **Always consume input events** - Use `accept_event()` in UI, `set_input_as_handled()` in gameplay
3. **Modifier cleanup** - Clean up modifiers by source_id when removing equipment/skills
4. **Cross-platform input** - Support both `InputEventMouseButton` and `InputEventScreenTouch`
5. **Resource preloading** - Add new resources to database preload lists
6. **Scene instancing** - Use `instantiate()`, not `instance()` (Godot 4 syntax)

## Documentation

- **Input System:** [docs/INPUT_SYSTEM.md](docs/INPUT_SYSTEM.md)
- **Waypoint System:** [docs/WAYPOINT_SYSTEM_GUIDE.md](docs/WAYPOINT_SYSTEM_GUIDE.md)
- **Project Summary:** [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)
- **Camera Bounds:** [docs/BORDERS_README.md](docs/BORDERS_README.md)

## Code Quality

- **Total:** ~20,260 lines across 101 GDScript files
- **Architecture:** Excellent (signal-based, loose coupling, separation of concerns)
- **Documentation:** Extensive (detailed file headers, 30+ docs)
- **Performance:** Optimized (centralized queries, event-driven)
