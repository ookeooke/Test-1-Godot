# AGENTS.md

This file provides guidance to AI agents (Claude, Cursor, GitHub Copilot, Aider, etc.) when working with code in this repository.

**Purpose:** Defines AI agent behavior rules, project context, tech stack, coding conventions, architecture constraints, and technical reference for this Godot tower defense game.

## Table of Contents
- [🚫 Critical Rules (Read First)](#-critical-rules-read-first)
- [🎮 Project Overview](#-project-overview)
- [🏗️ Architecture: Autoload Singleton Pattern](#️-architecture-autoload-singleton-pattern)
- [🔑 Key Systems](#-key-systems)
- [📁 File Organization](#-file-organization)
- [🔧 Common Development Tasks](#-common-development-tasks)
- [⚠️ Important Gotchas](#️-important-gotchas)
- [🧪 Testing & Debug Workflow](#-testing--debug-workflow)
- [💻 GDScript Code Style](#-gdscript-code-style)
- [📝 Naming Conventions](#-naming-conventions)
- [📚 Detailed Documentation](#-detailed-documentation)
- [🔒 Camera System (LOCKED)](#-camera-system-locked)
- [🎨 Equipment System Reference](#-equipment-system-reference)

---

## 🚫 Critical Rules (Read First)

**⚠️ NON-NEGOTIABLE: These rules override all other instructions.**

If the user asks you to do something that conflicts with these rules, you MUST:
1. Point out the conflict
2. Explain why the rule exists
3. Ask for explicit permission to break the rule
4. If permission granted, note it in your response

### Code Philosophy
- **Keep it simple** - Simple > "scalable" for this project
- **No premature optimization** - Optimize when needed, not speculatively
- **No "best practices" unless requested** - Working code > "proper" architecture
- **Ask before refactoring** - Don't change working code without permission
- **Explain trade-offs** - Simple vs scalable, direct vs abstracted
- **Default to keeping existing code** - If it works, leave it

### Forbidden Actions (Without Permission)
- ❌ Creating event buses or signal systems
- ❌ Refactoring working code
- ❌ Adding abstractions or wrapper functions
- ❌ "Improving" code architecture unprompted
- ❌ Quick workarounds (fix properly or ask)

### Platform Requirements
- **ALWAYS LANDSCAPE ORIENTATION** - Isometric game, never portrait mode
- **Mobile-first design** - All UI must work perfectly on touch
- **Base resolution**: 1920x1080 (16:9)
- **Wide phone support**: Up to 2340x1080+ (19.5:9 modern flagships)
- **Touch targets**: Minimum 48dp (Android Material Design)

### Git Safety Rules
- ❌ NEVER use `git reset --hard` without explicit approval
- ❌ NEVER use force commands (`push --force`, etc.)
- ✅ Always use `git stash` to preserve uncommitted work
- ✅ If something breaks → revert immediately, don't "fix forward"

### Error Checking Protocol
When checking for errors in the project:
1. **Always check Godot's Output/Console** - Runtime and parse errors only appear when Godot loads scripts
2. **Check VS Code Problems panel** - For LSP-detected issues
3. **Static analysis** - Check file syntax and configuration
4. **Git status** - Check for conflicts or uncommitted issues

**IMPORTANT**: Static code analysis alone is NOT sufficient. Many GDScript errors (parse errors, missing identifiers, invalid UIDs) only appear when Godot actually loads the project.

---

## 🎮 Project Overview

**Type:** 2D Tower Defense Game (Kingdom Rush-style with RPG elements)
**Engine:** Godot 4.5.1 Stable
**Language:** GDScript
**Platform:** PC (Windows/Steam) + Mobile (Android/iOS)

### Development Commands

#### Running the Game
- Press **F5** in Godot editor to run
- Main scene: `res://scenes/ui/main_menu.tscn`
- Test level: `res://scenes/levels/level_01.tscn`

#### Debug Keys (In-Game)
- **F3** - Toggle balance HUD (FPS, metrics)
- **F4** - Export balance data to CSV/JSON
- **1-4** - Game speed (1x, 2x, 4x, 8x)
- **I** - Toggle inventory
- **ESC** - Pause / close panels

#### Balance Data Export Location
```
C:\Users\ollil\AppData\Roaming\Godot\app_userdata\Test 1\balance_debug\exports\
```

---

## 🏗️ Architecture: Autoload Singleton Pattern

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

---

## 🔑 Key Systems

### 1. Input Event Flow (4-Stage System)

```
Stage 1: _input()           → Pause menu, global shortcuts
Stage 2: GUI Controls       → Buttons, panels (Control nodes)
Stage 3: _unhandled_input() → Hero movement, camera (RECOMMENDED for gameplay)
Stage 4: Physics Area2D     → Tower/hero click detection
```

**Critical:** Use `_unhandled_input()` for gameplay input, NOT `_input()` (blocks everything!)

**Full documentation:** [docs/INPUT_SYSTEM.md](docs/INPUT_SYSTEM.md)

### 2. Camera System (LOCKED)

**File:** `scripts/camera/camera_controller_improved.gd`
**Status:** Production-ready, locked, do not modify

#### How to Use Camera:
```gdscript
# Get camera reference
var camera = get_viewport().get_camera_2d()

# Camera shake
if camera and camera.has_method("add_shake"):
    camera.add_shake(5.0)   # Small shake
    camera.add_shake(15.0)  # Medium shake
    camera.add_shake(30.0)  # Large shake

# Snap to position/object
if camera:
    camera.snap_to_position(world_position)
    camera.snap_to_object(tower_node)
    camera.reset_to_center()
    camera.set_level_bounds(Rect2(x, y, width, height))
```

**What NOT to Do:**
- ❌ Create event buses for camera
- ❌ Add signal-based architecture
- ❌ Create wrapper functions
- ❌ Suggest refactoring
- ✅ Use existing methods directly

**See full camera rules:** [Camera System Lockdown](#-camera-system-lockdown-full-rules) below

### 3. UI Scaling System

**Autoload:** `UIScaleManager`
**Design Resolution:** 1920x1080 baseline
**Scaling Method:** Height-based (maintains vertical framing)

#### When to Use UIScaleManager:
```gdscript
# Get current UI scale (1.0 at 1080p, 0.67 at 720p, 2.0 at 4K)
var current_scale = UIScaleManager.ui_scale

# Scale individual values (for custom UI elements)
var button_width = UIScaleManager.get_scaled_value(100.0)
var button_size = UIScaleManager.get_scaled_size(Vector2(80, 60))

# Validate touch targets meet 44x44dp minimum
var is_valid = UIScaleManager.is_valid_touch_target(Vector2(60, 60))

# Listen for scale changes
UIScaleManager.scale_changed.connect(_on_ui_scale_changed)
```

**Use `get_scaled_value()` for:**
- Custom-drawn UI elements (not using Control nodes)
- Procedurally generated layouts
- Canvas-based UI (CanvasItem not Control)

**Don't use for:**
- Standard Control nodes with Theme (already auto-scaled)
- Elements using `custom_minimum_size` (theme handles these)

**Resolution Behavior:**
| Resolution | Scale | Use Case |
|------------|-------|----------|
| 1280x720 | 0.67x | Budget laptops, low-end |
| 1920x1080 | 1.0x | Baseline (most common) |
| 2560x1440 | 1.33x | High-end desktop |
| 3840x2160 | 2.0x | 4K monitors |

See: [scripts/autoloads/ui_scale_manager.gd](scripts/autoloads/ui_scale_manager.gd)

### 4. Three-Phase Modifier System

All stats calculated as: `(base + flat_mods + additive_mods) × multiplicative_mods`

- **Flat** - Direct addition (+10 damage)
- **Additive** - Percentage of base (+20% = base × 0.20)
- **Multiplicative** - Final multiplier (1.5× total)

Implemented in: [scripts/autoloads/game_state_manager.gd](scripts/autoloads/game_state_manager.gd)

### 5. Dual Navigation Systems

Both systems supported via `use_waypoint_system` flag:
- **Path2D** - Legacy curve-based pathfinding
- **PathWaypoint** - Manual placement with visual road rendering

**Full documentation:** [docs/WAYPOINT_SYSTEM_GUIDE.md](docs/WAYPOINT_SYSTEM_GUIDE.md)

### 6. Wave System

- **WaveManager** flattens `Array[EnemySpawnData]` into spawn queue
- Supports "Call Next Wave" buttons (Kingdom Rush pattern) with gold bonuses
- Emits `combat_started()` / `combat_ended()` for UI coordination
- See: [scripts/managers/wave_manager.gd](scripts/managers/wave_manager.gd)

### 7. Loot System

Tiered drop rates:
- **Tier 1** (Goblin): 15% drop, 70% Common / 25% Uncommon / 5% Rare
- **Tier 2** (Orc/Wolf): 30% drop, includes Epic (5%)
- **Tier 3** (Troll): 50% drop, includes Epic (9%)
- **Boss**: 100% guaranteed + 3 items, includes Legendary (5%)

### 8. Save System

- Location: `user://saves/{profile_name}.save`
- Stores: progress, inventory (with upgrade levels), hero equipment, settings, stats
- See: [scripts/autoloads/save_manager.gd](scripts/autoloads/save_manager.gd)

### 9. Balance Tracking

- **BalanceTracker** records damage, kills, tower placement, economy
- **BalanceExporter** exports to CSV/JSON for analysis
- Tracks tower efficiency, enemy difficulty, gold economy
- See: [scripts/debug/balance_tracker.gd](scripts/debug/balance_tracker.gd)

---

## 🏰 Tower Upgrade Architecture

### Split Path System (Level 3 → 4)
Towers branch into two distinct paths at Level 3. This is handled by the `RingUpgradeMenu` and `BaseTower` logic.

**Requirements for New Towers:**
1. **`needs_path_choice()`**: Must return `true` at Level 3.
2. **`get_path_choices()`**: Must return Array of 2 dictionaries:
   ```gdscript
   [
       {"id": "path_a", "emoji": "🔥", "name": "Inferno"},
       {"id": "path_b", "emoji": "❄️", "name": "Frost"}
   ]
   ```
3. **Path Methods**: Must implement `choose_path_a()` and `choose_path_b()` returning `bool`.
4. **Stats**: `TowerData` must have `path_a_path` and `path_b_path` entries for Level 4+.

---

## 📁 File Organization

```
scripts/
├── autoloads/          # 19 singletons
├── managers/           # Gameplay managers (waves, heroes, enemies, placement)
├── resources/          # Resource classes (HeroData, ItemData, LevelConfig, etc.)
├── ui/                 # UI scripts (29 files)
├── debug/              # Balance tracking tools
├── pathfinding/        # Waypoint/road systems
├── camera/             # camera_controller_improved.gd (LOCKED)
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

---

## 🔧 Common Development Tasks

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

---

## ⚠️ Important Gotchas

1. **Autoload order matters** - Dependencies require specific initialization order
2. **Always consume input events** - Use `accept_event()` in UI, `set_input_as_handled()` in gameplay
3. **Modifier cleanup** - Clean up modifiers by source_id when removing equipment/skills
4. **Cross-platform input** - Support both `InputEventMouseButton` and `InputEventScreenTouch`
5. **Resource preloading** - Add new resources to database preload lists
6. **Scene instancing** - Use `instantiate()`, not `instance()` (Godot 4 syntax)
7. **Separated resource loading** - LevelConfig (gameplay) ≠ LevelNodeData (UI metadata)

---

## 🧪 Testing & Debug Workflow

### Running Tests
- **Run game:** Press F5 in Godot editor
- **Test specific level:** Open level scene → F5 (skips main menu)
- **Check errors:** Always check Godot Output/Console (parse errors only appear when Godot loads)

### Debug Tools (In-Game)
- **F3** - Toggle balance HUD (FPS, DPS, economy metrics)
- **F4** - Export balance data → CSV/JSON for analysis
- **1-4** - Adjust game speed (1x, 2x, 4x, 8x)

### Balance Data Location
Exports saved to: `C:\Users\ollil\AppData\Roaming\Godot\app_userdata\Test 1\balance_debug\exports\`

---

## 💻 GDScript Code Style

### Static Typing (Required)
```gdscript
# ✅ CORRECT - Always use static typing
var health: int = 100
var speed: float = 5.0
func get_damage() -> int:
    return base_damage

# ❌ WRONG - Untyped vars
var health = 100
func get_damage():
    return base_damage
```

### Signals & Communication
```gdscript
# ✅ CORRECT - Use signals for UI updates
signal health_changed(new_health: int)
health_changed.emit(current_health)

# ❌ WRONG - Direct get_node() chains across tree
get_node("/root/UI/HealthBar").update(health)
```

### Autoloads & Singletons
```gdscript
# ✅ CORRECT - Use autoload singletons for global state
InventoryManager.add_item("iron_sword", 1)
GameStateManager.modify_stat("gold", 50, "additive")

# ❌ WRONG - Ad-hoc global variables or get_node("/root/...")
```

---

## 📝 Naming Conventions

### Files & Resources
- **Scenes:** `snake_case.tscn` (tower_spot.tscn, level_01.tscn)
- **Scripts:** `snake_case.gd` (wave_manager.gd, base_enemy.gd)
- **Resources:** `snake_case.tres` (iron_sword.tres, goblin_scout_data.tres)
- **Autoloads:** `PascalCase` class names (GameStateManager, InventoryManager)

### Code Elements
- **Signals:** `past_tense` (enemy_died, wave_completed, combat_started)
- **Variables:** `snake_case` (max_health, movement_speed, gold_reward)
- **Constants:** `UPPER_SNAKE_CASE` (MAX_INVENTORY_SLOTS, DEFAULT_SPEED)
- **Functions:** `snake_case` (calculate_damage, spawn_enemy, add_modifier)
- **Classes:** `PascalCase` when using class_name (ItemData, HeroData, LevelConfig)

### Directory Structure
Follow existing organization in `scripts/`, `scenes/`, `resources/` folders (see File Organization section).

---

## 📚 Detailed Documentation

- **Input System:** [docs/INPUT_SYSTEM.md](docs/INPUT_SYSTEM.md)
- **Waypoint System:** [docs/WAYPOINT_SYSTEM_GUIDE.md](docs/WAYPOINT_SYSTEM_GUIDE.md)
- **Project Summary:** [docs/PROJECT_SUMMARY.md](docs/PROJECT_SUMMARY.md)
- **Camera Bounds:** [docs/BORDERS_README.md](docs/BORDERS_README.md)

**GitHub Repository:** https://github.com/ookeooke/Test-1-Godot

---

## Maintaining This File

When adding major new systems, update relevant sections:
- New autoload → Add to Architecture section
- New common task → Add to Common Development Tasks
- New constraint → Add to Critical Rules

Keep this file focused and concise. Per industry research (GitHub analyzed 2,500+ repos), effective agent files are 300-500 lines with clear examples, not exhaustive documentation.

---

## 🔒 Camera System (LOCKED)

**File:** `scripts/camera/camera_controller_improved.gd` | **Status:** Production-ready, do not modify

### Quick Usage
```gdscript
var camera = get_viewport().get_camera_2d()
if camera and camera.has_method("add_shake"):
    camera.add_shake(5.0)              # Shake effect
    camera.snap_to_position(pos)       # Jump to position
    camera.snap_to_object(node)        # Follow object
    camera.reset_to_center()           # Reset view
    camera.set_level_bounds(rect)      # Set boundaries
```

### Critical Rules
**DO:**
- ✅ Use existing methods directly (see above)
- ✅ Call camera methods from gameplay code
- ✅ Adjust existing export variables if needed

**DON'T:**
- ❌ Create event buses, signals, or wrapper functions
- ❌ Add CameraManager, CameraService, or similar abstractions
- ❌ Suggest refactoring "for better architecture"
- ❌ Create state machines, priority systems, or camera modes

### Why Direct Calls?
Simple tower defense game doesn't need event bus complexity. Enemy dies → `camera.add_shake(5.0)`. That's it.

**If user requests camera changes:** Check if existing methods work first. If not, ask before extending.

---

## 🎨 Equipment System Reference

### Design Philosophy
- **Diablo Immortal mobile** - Reference for UI/UX patterns
- **Dungeon Defenders** - Account-wide inventory pattern
- **Mobile-first**: Touch targets, tap-to-equip, long-press menus
- **Simplicity**: No complex tabs, minimal UI, streamlined interactions

### Hero & Equipment Balance Philosophy
- **Zero Base Damage**: Heroes MUST have 0 base damage. They are blank slates.
- **Gear-Based Scaling**: 100% of a hero's power comes from items.
- **Starter Power**: Starter weapons (sword, staff, bow) must match **Level 1-2 Tower** power (~10-12 Damage).
- **Loot Incentive**: Because heroes start weak, finding new items feels impactful.

### Key Components

#### DualPanelScreen (`scenes/ui/dual_panel_screen.tscn`)
- Main equipment/inventory screen (opened from world map, NOT during gameplay)
- **Left panel**: Equipment view (fixed)
- **Right panel**: Inventory view (fixed)
- **NO TABS** - Each panel shows only one view permanently

#### InventoryView (`scenes/ui/views/inventory_view.tscn`)
- **SINGLE UNIFIED GRID** - All items (equipment, consumables, materials) together
- **NO CATEGORY TABS** - Everything in one scrollable grid
- Total slots: 60 items (configurable)
- Grid columns: Auto-adjust based on screen width
- Item slots: 80x80px (exceeds 48dp minimum)

#### InventoryManager (`scripts/autoloads/inventory_manager.gd`)
- Autoload singleton managing account-wide inventory
- Storage: Dictionary `{item_id: {quantity, upgrade_level}}`
- **Important methods**:
  - `get_all_items()` - Returns ALL items (all categories combined)
  - `get_items_by_category(category)` - Equipment/Consumables/Materials
  - `add_item(item_id, quantity)` - Add to inventory
  - `remove_item(item_id, quantity)` - Remove from inventory

### Dual Input System (Mobile + PC)

#### Mobile (Touch) Input
- **Tap** on inventory item → Auto-equips to correct slot
- **Long-press** (0.5s hold) → Context menu (sell, drop, etc.)
- Smart slot detection: Accessories go to first empty accessory slot

#### PC (Mouse) Input
- **Hover** over item → Tooltip appears
- **Drag-drop** item → Move between inventory/equipment
- **Right-click** item → Context menu
- Drag preview shows semi-transparent item icon

### Touch Target Guidelines
- **Minimum**: 48dp (Android Material Design)
- **Inventory slots**: 80x80px
- **Equipment slots**: 100x100px
- **Buttons**: 48px minimum height
- **Spacing**: 5px between interactive elements

### Important "Don't Do" List
1. ❌ NEVER add portrait mode support - game is always landscape
2. ❌ NEVER add category tabs back to inventory - unified grid only
3. ❌ NEVER make Equipment/Inventory views switchable - they're fixed
4. ❌ NEVER create separate mobile and PC codebases - unified dual input only
5. ❌ NEVER use separate inventories per category - single `get_all_items()`

### Inventory Grid Architecture (Diablo 2 / Path of Exile Style)

**Pattern:** Static Grid + ItemSprite Overlay
- `ItemSlot` nodes form a STATIC 8×8 grid (never modified, no item data)
- `ItemSprite` nodes render items as overlays on top (z_index=10)
- Items can span multiple cells (e.g., 2×4 armor, 1×2 weapons)

**Key Components:**
| Component | File | Role |
|-----------|------|------|
| `InventoryContainer` | `scripts/logic/inventory_container.gd` | Tetris logic, grid state, UUID tracking |
| `InventoryGridContainer` | `scripts/ui/inventory_grid_container.gd` | Visual grid, drag highlighting, coordinate conversion |
| `ItemSprite` | `scripts/ui/item_sprite.gd` | Item rendering, drag initiation, tooltip |
| `ItemSlot` | `scripts/ui/item_slot.gd` | Static grid cell, drop handling |
| `InventoryRegistry` | `scripts/autoloads/inventory_registry.gd` | Container lookup by ID |
| `ItemTransactionService` | `scripts/autoloads/item_transaction_service.gd` | Move/equip/swap operations |

### Professional UX Features

#### Real-Time Drag Highlighting
- Green overlay shows valid drop positions during drag
- Updates every frame via `_process()` + `NOTIFICATION_DRAG_BEGIN/END`
- File: `inventory_grid_container.gd:58-107`

#### Smart Edge Clamping
- `screen_to_grid()` clamps coordinates considering item dimensions
- Prevents multi-cell items from extending outside grid
- Creates "magnetic snap to edge" feel (Diablo 2 style)
- File: `inventory_grid_container.gd:203-246`

#### Auto-Sort with Audio
- Greedy bin-packing: largest items first
- Priority: Size > Category > Rarity > Name
- Rollback safety if sort fails
- Audio feedback on success/failure
- File: `inventory_container.gd:429-502`

### Debug Flags (All default to `false`)
- `DEBUG_INVENTORY` - Verbose logging for inventory actions
- `DEBUG_TRANSACTIONS` - Detailed transaction logs (ItemTransactionService)
- `DEBUG_DRAG_DROP` - Visual debug markers (Red Dot/Blue Box) for drag operations

### Professional Drag & Drop Standards (Diablo 2 / PoE Style)

#### 1. Cell-Snapped Dragging
- **Behavior**: When dragging, the item preview snaps so the cursor is at the **Center of the Grabbed Cell**.
- **Why**: Allows precise "point-and-shoot" aiming at slots.
- **Visuals**: Debug mode shows Red Dot (Cursor) aligned with Green Cross (Cell Center).
- **Implementation**: `ItemSprite._get_drag_data` calculates `snap_offset`.

#### 2. Anchor Point Correction ("The Jump Fix")
- **Problem**: Dropping a large item (e.g., 2x3 Bow) by the bottom handle causes it to "jump" down if using cursor position as origin.
- **Solution**: `Target Origin = Cursor Slot - Grab Offset`.
- **Implementation**: `InventoryGridSlot` subtracts `grab_offset` from drop coordinates.
- **Result**: Item stays exactly where visually placed.

#### 3. No Absolute Centering
- **Rule**: NEVER implement "Hold by Center" for even-sized items (2x2).
- **Reason**: Causes grid misalignment (the "Drift" problem). Always snap to a specific cell.

#### 4. Smart Edge Clamping ("The Magnet")
- **Problem**: Dragging an item partially off-screen (e.g., x=-1) causes drop failure, even if visual highlight snaps to edge.
- **Solution**: `Target = clamp(Target, 0, MaxValid)`.
- **Implementation**: `InventoryGridSlot` clamps the calculated target to valid grid bounds.
- **Result**: "Magnetic" feel at edges - if the green box is visible, the drop works.

### Debug Flags (All default to `false`)

| Flag | File | Purpose |
|------|------|---------|
| `DEBUG_TRANSACTIONS` | `item_transaction_service.gd` | Move/equip operation logging |
| `DEBUG_DRAG_DROP` | `item_sprite.gd`, `item_slot.gd` | Drag-drop event logging |
| `DEBUG_LOGGING` | `inventory_grid_container.gd` | Grid resize/gap drop logging |
| `DEBUG_SORT` | `inventory_container.gd` | Sort operation logging |
| `debug_logging` | `inventory_view.gd` | Inventory refresh logging (F3 toggle) |

### File Locations
```
scenes/ui/
  ├── dual_panel_screen.tscn      # Main equipment screen
  ├── flexible_panel.tscn          # Panel container
  └── views/
      ├── equipment_view.tscn      # Hero equipment panel
      └── inventory_view.tscn      # Unified inventory grid

scripts/ui/
  ├── dual_panel_screen.gd         # Responsive logic
  ├── flexible_panel.gd            # Single view loader
  ├── inventory_grid_container.gd  # Grid layout, drag highlighting
  ├── item_slot.gd                 # Static grid cell, drop handling
  ├── item_sprite.gd               # Item overlay rendering, drag initiation
  └── views/
      ├── equipment_view.gd        # Equipment display, stats
      └── inventory_view.gd        # Unified inventory, sort button

scripts/logic/
  └── inventory_container.gd       # Tetris grid logic (RefCounted)

scripts/autoloads/
  ├── inventory_manager.gd         # Global inventory storage
  ├── inventory_registry.gd        # Container lookup by ID
  ├── item_database.gd             # Item definitions
  ├── item_transaction_service.gd  # Item movement controller
  └── hero_database.gd             # Hero definitions
```

---

## Code Quality

- **Total:** ~20,260 lines across 101 GDScript files
- **Architecture:** Excellent (signal-based, loose coupling, separation of concerns)
- **Documentation:** Extensive (detailed file headers, comprehensive docs)
- **Performance:** Optimized (centralized queries, event-driven)

---


---

## ⚔️ Combat & Animation Standards

### Shadow System
- **Hybrid Approach:** Supports both manual `Shadow` nodes (Editor) and auto-generated ones (Code).
- **Smart Scaling:** `BaseEnemy` and `BaseHero` automatically scale shadows based on `CollisionShape2D` size.
- **Critical Rule:** When finding the main sprite (e.g. for flipping), **ALWAYS ignore the "Shadow" node**.
  ```gdscript
  if child.name == "Shadow": continue # Skip shadow
  ```

### Animation Logic
- **Dynamic Speed:** Animations must scale with attack speed.
  - Formula: `speed_scale = 1.0 / attack_cooldown`
- **State Management:**
  - **Walk:** Explicitly request "walk" animation in movement loops (`_continue_movement`).
  - **Attack:** Do NOT interrupt "attack" animation with "walk" requests.
- **Ghost Attacks:**
  - Attack functions (`perform_melee_attack`) MUST return `bool` (true = hit, false = miss/dead).
  - **NEVER** play attack animation if the target is dead or the attack failed.

---

## 📦 Asset Management & Exporting

### The "Dynamic Loading" Problem
Godot's export system excludes files that are not explicitly referenced in scenes or scripts. Since this project uses `DirAccess` to scan folders for Heroes and Items, these files are often excluded from the exported build, causing "Loaded 0 items" errors.

### ⚠️ CRITICAL RULE: Adding New Content
When adding a new **Hero**, **Item**, or **Icon**, you MUST perform these 2 steps to ensure it appears in the exported game:

#### 1. Add to `ResourcePreloader.gd`
Open `scripts/autoloads/resource_preloader.gd` and add a `preload()` line:
```gdscript
var _new_item = preload("res://resources/items/weapons/new_super_sword.tres")
```
*Why? This forces Godot to see the file as a dependency and include it in the .pck file.*

#### 2. Add to Database Fallback List
Open `HeroDatabase.gd` or `ItemDatabase.gd` and add the ID/path to the fallback list:
```gdscript
var known_items = [
    ...,
    "weapons/new_super_sword"
]
```
*Why? `DirAccess` often fails to list files in exported builds. This fallback allows the code to load the file directly by name.*

---

*Last updated: Optimized based on industry research (GitHub's analysis of 2,500+ repos)*
*Length: ~400 lines (industry standard 300-500) | Sections: GitHub's 6 core areas + project-specific*
*AI Compatibility: Claude, Cursor, GitHub Copilot, Aider, and all AI coding assistants*
