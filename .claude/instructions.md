# Tower Defense Game - Claude Instructions

## Project Overview
This is an isometric tower defense game built in Godot 4.5, similar to Kingdom Rush, with RPG elements like Diablo. The game is **mobile-first** (designed for touch) but also supports PC (Steam release planned).

## Critical Platform Requirements
- **ALWAYS LANDSCAPE ORIENTATION** - This is an isometric game, never portrait mode
- **Mobile-first design** - All UI must work perfectly on touch
- **Base resolution**: 1920x1080 (16:9)
- **Wide phone support**: Up to 2340x1080+ (19.5:9 modern flagships)
- **Responsive design**: UI adapts to different widths, not heights

## Equipment & Inventory System Architecture

### Design Philosophy
- **Diablo Immortal mobile** is the reference for UI/UX patterns
- **Dungeon Defenders** pattern for shared account-wide inventory
- **Mobile-first**: Touch targets, tap-to-equip, long-press menus
- **Simplicity**: No complex tabs, minimal UI, streamlined interactions

### Key Components

#### 1. DualPanelScreen (`scenes/ui/dual_panel_screen.tscn`)
- Main equipment/inventory screen opened from world map (NOT during gameplay)
- **Left panel**: Equipment view (fixed)
- **Right panel**: Inventory view (fixed)
- **NO TABS** - Each panel shows only one view permanently
- Responsive breakpoints:
  - Width ≥2340px: Equipment 600px, Inventory 1200px
  - Width ≥1920px: Equipment 600px, Inventory 1100px
  - Width <1920px: Equipment 500px, Inventory 900px

#### 2. FlexiblePanel (`scenes/ui/flexible_panel.tscn`)
- Simplified panel container (tabs removed)
- Only supports two view types: Equipment or Inventory
- Set via `default_view` export (0=Equipment, 1=Inventory)
- **DO NOT** add Stats, Skills, or Comparison views

#### 3. EquipmentView (`scenes/ui/views/equipment_view.tscn`)
- Shows hero's equipped items (weapon, armor, 2 accessories)
- Equipment slots: 100x100px each
- Hero portrait: 80x80px
- "Switch Hero" button: 48px height minimum
- Equipment stats panel below slots
- **Hero switching**: Button exists but hero selection UI is TODO

#### 4. InventoryView (`scenes/ui/views/inventory_view.tscn`)
- **SINGLE UNIFIED GRID** - All items (equipment, consumables, materials) together
- **NO CATEGORY TABS** - Everything in one scrollable grid
- Total slots: 60 items (configurable via `total_slots` export)
- Grid columns: 8 (default), responsive based on screen width
- Item slots: 80x80px (exceeds 48dp minimum touch target)

#### 5. InventoryManager (`scripts/autoloads/inventory_manager.gd`)
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
- **Tap** on equipment slot → (Currently does nothing, could unequip)
- Smart slot detection: Accessories go to first empty accessory slot

#### PC (Mouse) Input
- **Hover** over item → Tooltip appears (Godot built-in system)
- **Drag-drop** item → Move between inventory/equipment
- **Right-click** item → Context menu (sell, drop, etc.)
- Drag preview shows semi-transparent item icon

#### Implementation Details
- ItemSlot (`scripts/ui/item_slot.gd`) handles both input types
- `InputEventScreenTouch` for mobile touch
- `InputEventMouseButton` for PC clicks
- Long-press detection: Timer starts on touch down, checks duration on release
- Auto-equip logic in `inventory_view.gd` → `_try_auto_equip_item()`

### Touch Target Guidelines
- **Minimum**: 48dp (Android Material Design)
- **Inventory slots**: 80x80px
- **Equipment slots**: 100x100px
- **Buttons**: 48px minimum height
- **Spacing**: 5px between interactive elements

### Important "Don't Do" List
1. **NEVER** add portrait mode support - game is always landscape
2. **NEVER** add category tabs back to inventory - unified grid only
3. **NEVER** add tabs to FlexiblePanel - single view only
4. **NEVER** make Equipment/Inventory views switchable - they're fixed
5. **NEVER** create separate mobile and PC codebases - unified dual input only
6. **NEVER** use separate inventories per category - single `get_all_items()`

### Common Patterns

#### Adding New Items to Inventory
```gdscript
# Add item
InventoryManager.add_item("iron_sword", 1)

# The unified inventory will automatically show it in InventoryView
# No need to specify category - it's all in one grid
```

#### Auto-Equip Logic Flow
1. Player taps item in inventory
2. `inventory_view.gd` → `_on_item_slot_clicked()`
3. Checks if item is equipment type
4. Calls `_try_auto_equip_item(item_id, item_data)`
5. Determines correct slot (weapon/armor/accessory_1/accessory_2)
6. Checks if slot is occupied
7. If empty → Equip directly
8. If occupied → Swap with confirmation (TODO: add dialog)

#### Responsive Layout Updates
- DualPanelScreen listens to `get_viewport().size_changed`
- `_on_viewport_resized()` adjusts panel widths based on breakpoints
- InventoryGrid columns can be adjusted (future: 6-9 columns based on width)

### File Locations Quick Reference
```
scenes/ui/
  ├── dual_panel_screen.tscn      # Main equipment screen
  ├── flexible_panel.tscn          # Panel container (simplified)
  └── views/
      ├── equipment_view.tscn      # Hero equipment panel
      └── inventory_view.tscn      # Unified inventory grid

scripts/ui/
  ├── dual_panel_screen.gd         # Responsive logic, hero switching
  ├── flexible_panel.gd            # Single view loader
  ├── item_slot.gd                 # Dual input, tooltips, drag-drop
  └── views/
      ├── equipment_view.gd        # Equipment display, stats
      └── inventory_view.gd        # Unified inventory, auto-equip

scripts/autoloads/
  ├── inventory_manager.gd         # Global inventory storage
  ├── item_database.gd             # Item definitions
  └── hero_database.gd             # Hero definitions
```

### Testing Checklist
When making changes to equipment/inventory UI:
- [ ] Test at 1920x1080 resolution
- [ ] Test at 2340x1080 wide resolution
- [ ] Test with "Emulate Touch From Mouse" enabled (Project Settings)
- [ ] Verify all touch targets are ≥48px
- [ ] Test tap-to-equip functionality
- [ ] Test long-press (0.5s hold) for context menu
- [ ] Test drag-drop on PC
- [ ] Verify tooltips show on hover
- [ ] Check that ALL items appear in single unified inventory grid

### Recently Implemented Features ✅

#### 1. Dynamic Column Adjustment (2025-10-23)
- Inventory grid columns automatically adjust based on viewport width
- **Wide (≥2340px)**: 9 columns - for modern flagship phones
- **Standard (≥1920px)**: 8 columns - default desktop/mobile
- **Compact (<1920px)**: 6 columns - tablets or smaller
- **Implementation**: `inventory_view.gd` → `_on_viewport_resized()`
- Listens to `get_viewport().size_changed` signal
- Maximizes screen space usage across all devices

#### 2. Swap Confirmation Dialog (2025-10-23)
- Visual confirmation popup when replacing equipped items
- **Prevents accidental swaps** on mobile (common issue with touch)
- Shows **side-by-side comparison**:
  - Currently equipped item (left)
  - New item to equip (right)
- **Stat comparison** with colored arrows:
  - Green ↑ for improvements
  - Red ↓ for downgrades
- **Touch-friendly buttons**: 50px height (exceeds 48dp minimum)
- **Files**:
  - Scene: `scenes/ui/swap_confirmation_dialog.tscn`
  - Script: `scripts/ui/swap_confirmation_dialog.gd`
- **Signals**:
  - `confirmed(new_item_id, slot_name)` - User confirms swap
  - `cancelled()` - User cancels swap
- Instantiated in `inventory_view.gd` → `_setup_swap_dialog()`

### Future TODOs (Not Yet Implemented)
- Hero selection UI (for "Switch Hero" button)
- Proper context menu UI (currently auto-sells on right-click)
- Hero stats view integration
- Advanced item comparison tooltips in swap dialog (currently shows basic stats)

## Game Context
- Kingdom Rush-style tower defense with hero units
- Heroes have equipment (Diablo-style: weapon, armor, accessories)
- Loot drops from enemies/bosses
- Multiple heroes unlockable (like Dungeon Defenders)
- Equipment persists across levels (account-wide inventory)

Last updated: 2025-10-23
