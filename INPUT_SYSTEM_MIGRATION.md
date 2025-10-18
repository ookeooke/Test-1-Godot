# INPUT SYSTEM MIGRATION GUIDE

## Summary
Removed ClickManager autoload system. Now using pure Godot patterns:
- **UI Buttons** → Button.pressed signals
- **Game World Objects** → Area2D.input_event signals

---

## REQUIRED SCENE CHANGES

### 1. Tower Spots (tower_spot.tscn)
**Add this node structure:**
```
TowerSpot (Node2D)
├── Sprite2D
└── ClickArea (Area2D) ← ADD THIS
    └── CollisionShape2D ← ADD THIS
        └── Shape: CircleShape2D (radius: 50px)
```

**Settings:**
- ClickArea.input_pickable = true
- ClickArea.monitoring = false
- CollisionShape2D.shape = CircleShape2D with radius 50-60px

---

### 2. Archer Tower (archer_tower.tscn)
**Add this node structure:**
```
ArcherTower (StaticBody2D)
├── TowerVisual (Sprite2D)
├── DetectionRange (Area2D) - already exists
└── ClickArea (Area2D) ← ADD THIS
    └── CollisionShape2D ← ADD THIS
        └── Shape: CircleShape2D (radius: 60px)
```

**Settings:**
- ClickArea.input_pickable = true
- ClickArea.monitoring = false
- CollisionShape2D.shape = CircleShape2D with radius 60-80px (larger for mobile)

---

### 3. Soldier Tower (soldier_tower.tscn)
**Same as Archer Tower** - add ClickArea with CollisionShape2D.

---

### 4. Heroes (ranger_hero.tscn)
**Add this node structure if not present:**
```
RangerHero (CharacterBody2D)
├── Sprite2D
├── AnimationPlayer
└── ClickArea (Area2D) ← ADD THIS if missing
    └── CollisionShape2D ← ADD THIS
        └── Shape: CircleShape2D (radius: 50px)
```

---

## CODE CHANGES COMPLETED

### Files Modified:
- ✅ `project.godot` - Removed ClickManager autoload
- ✅ `click_manager.gd` - DELETED
- ✅ `hero_button.gd` - Removed fallback _input() handler
- ✅ `build_menu.gd` - Removed debug gui_input handler
- ✅ `tower_spot.gd` - Converted to Area2D.input_event
- ⏳ `archer_tower.gd` - Need to add Area2D support
- ⏳ `soldier_tower.gd` - Need to add Area2D support
- ⏳ `ranger_hero.gd` - Need to add Area2D support
- ⏳ `base_enemy.gd` - Need to add Area2D hover (optional)

---

## THE ONE RULE

```
┌─────────────────────────────────────────┐
│  Is it FLAT on screen (UI/Menu)?       │
│  → Use Button                           │
│                                         │
│  Is it IN THE GAME WORLD?              │
│  → Use Area2D                           │
└─────────────────────────────────────────┘
```

### Adding New UI Button:
1. Create Button node in CanvasLayer
2. Connect `.pressed` signal
3. Done.

### Adding New Clickable Game Object:
1. Add Area2D as child
2. Add CollisionShape2D with CircleShape2D (radius 50-60px)
3. Set `input_pickable = true`
4. Connect `.input_event` signal
5. Done.

---

## Mobile Touch Targets

**Minimum sizes for comfortable touch:**
- UI Buttons: 44dp minimum (handled by UIScaleManager)
- Game Objects (Area2D): 50-60px radius minimum
- Important objects (towers): 60-80px radius

**Formula:** At 1080p, 44dp = ~88px, so 44px radius = 88px diameter

---

## Testing Checklist

After adding ClickArea nodes to scenes:

### UI Tests:
- [ ] Main menu buttons work
- [ ] Profile select buttons work
- [ ] World map level buttons work
- [ ] Build menu buttons work (Archer, Barracks)
- [ ] Hero button (bottom-left) works
- [ ] Victory/Defeat screen buttons work
- [ ] Speed control button (1x/2x/4x) works

### Game World Tests:
- [ ] Tower spots clickable (empty spots show build menu)
- [ ] Towers clickable (show tower info menu)
- [ ] Heroes clickable (selection works)
- [ ] Level nodes on world map clickable

### Mobile Tests:
- [ ] All buttons comfortable to tap with finger
- [ ] No accidental clicks when scrolling/dragging camera
- [ ] Hover states work (desktop) but don't break touch (mobile)

---

## Camera Drag Protection

The camera controller needs to check if mouse is over GUI before starting drag:

```gdscript
func _input(event):
    if event is InputEventMouseButton:
        # Don't drag camera when clicking UI
        var gui_element = get_viewport().gui_get_hovered_control()
        if gui_element:
            return  # Let GUI handle it

    # ... camera drag code
```

This prevents dragging camera when clicking buttons.

---

## No More ClickManager!

**DO NOT:**
- ❌ Register objects with ClickManager (it's deleted)
- ❌ Use ClickPriority enum (doesn't exist)
- ❌ Call ClickManager.register_clickable()
- ❌ Call ClickManager.unregister_clickable()
- ❌ Check ClickManager.currently_hovered
- ❌ Use on_clicked/on_hover_start callbacks (use Area2D signals)

**DO:**
- ✅ Use Button.pressed for UI
- ✅ Use Area2D.input_event for game objects
- ✅ Use Area2D.mouse_entered/exited for hover effects
- ✅ Set input_pickable to enable/disable clicking
