# Multi-Hitbox Enemy System - Implementation Complete

## Overview

We've successfully implemented a three-layer enemy collision system that separates:
- **Pink Ground Circle**: Footprint for tower detection (CharacterBody2D Layer 1)
- **Blue Hitboxes**: Multiple hitbox layers for different projectile types (Area2D Layers 5-7)
- **Yellow Visual Sprite**: Artistic freedom, any size/shape (no collision)

## Changes Made

### 1. `scripts/enemies/base_enemy.gd`

**New Export Variables:**
```gdscript
@export var ground_circle_size: Vector2 = Vector2(16, 16)  # Oval footprint
@export var ground_hitbox_radius: float = 8.0  # Layer 5
@export var elevated_hitbox_radius: float = 10.0  # Layer 6
@export var elevated_hitbox_offset: Vector2 = Vector2(0, -16)  # Where hitbox is
@export var enable_ground_hitbox: bool = true
@export var enable_elevated_hitbox: bool = true
```

**New Functions:**
- `_setup_multiple_hitboxes()` - Creates ground (Layer 5) and elevated (Layer 6) hitboxes
- `_setup_debug_visualization()` - Pink/Blue debug outlines (F4 mode)
- `_on_ground_hitbox_hit()` - Callback for ground hits
- `_on_elevated_hitbox_hit()` - Callback for elevated hits

**Debug Visualization:**
- Pink Line2D shows ground circle (oval)
- Blue Line2D shows elevated hitbox
- Toggles with F4 debug mode

### 2. `scenes/projectiles/arrow.gd`

**New Export Variable:**
```gdscript
@export_enum("Ground:16", "Elevated:32", "Both:48", "Special:64") var hitbox_layer_mask: int = 32
```

**Key Changes:**
- Arrows now detect **Area2D hitboxes** (Layers 5-7) instead of CharacterBody2D (Layer 1)
- Raycast changed: `collide_with_areas = true`, `collide_with_bodies = false`
- Signal changed: `area_entered` instead of `body_entered`
- Function renamed: `_on_hitbox_entered()` instead of `_on_body_entered()`
- Collision mask set dynamically in `_ready()`: `collision_mask = hitbox_layer_mask`

## Collision Layer Reference

| Layer | Bit | Value | Name | What's On It |
|-------|-----|-------|------|--------------|
| 1 | 0 | 1 | Enemy Footprints | CharacterBody2D ground circles (detected by towers/heroes) |
| 2 | 1 | 2 | Hero Units | Hero CharacterBody2D |
| 4 | 2 | 4 | Projectiles | Arrow Area2D |
| **5 (NEW)** | **4** | **16** | **Ground Hitboxes** | Enemy ground hitbox Area2D (for ground arrows) |
| **6 (NEW)** | **5** | **32** | **Elevated Hitboxes** | Enemy body hitbox Area2D (for air arrows) **DEFAULT** |
| **7 (NEW)** | **6** | **64** | **Special Hitboxes** | Boss/flying specific hitboxes |

## Projectile Targeting Options

In Godot editor, select an arrow and set `Hitbox Targeting` export variable:

- **Ground (16)**: Only hits Layer 5 ground hitboxes
  - Use for: Ground-targeting arrows, anti-ground abilities
  - Flying enemies: IMMUNE

- **Elevated (32)**: Only hits Layer 6 elevated hitboxes ⭐ DEFAULT
  - Use for: Standard arrows, anti-air projectiles
  - Best for: General purpose combat

- **Both (48)**: Hits Layers 5+6 combined (16+32=48)
  - Use for: AOE magic, universal projectiles
  - Hits: All enemies regardless of height

- **Special (64)**: Only hits Layer 7 special hitboxes
  - Use for: Boss weak point targeting, special abilities

## Enemy Configuration

Each enemy type can now configure:

```gdscript
# Example: Goblin Scout
ground_circle_size = Vector2(16, 10)  # Small oval footprint
ground_hitbox_radius = 8.0  # Small ground target
elevated_hitbox_radius = 10.0  # Body hitbox
elevated_hitbox_offset = Vector2(0, -16)  # Chest level

# Example: Flying Bat
ground_circle_size = Vector2(12, 8)  # Shadow on ground
enable_ground_hitbox = false  # Immune to ground arrows!
elevated_hitbox_radius = 12.0
elevated_hitbox_offset = Vector2(0, -40)  # High in air
```

## Next Steps (MUST DO IN GODOT EDITOR)

### Step 1: Test Current Implementation

1. Open project in Godot
2. Run a level with enemies
3. Check console for:
   ```
   [Enemy] Ground hitbox created: radius=8.0, layer=5
   [Enemy] Elevated hitbox created: radius=10.0, pos=(0, -16), layer=6
   [Arrow] Direct collision with ElevatedHitbox
   ```
4. Press F4 to enable debug mode
5. You should see **pink ground circles** and **blue elevated hitboxes**

### Step 2: Adjust Enemy Scenes (Optional but Recommended)

For each enemy scene (`scenes/enemies/*.tscn`):

1. Open in Godot editor
2. Select root enemy node
3. In Inspector, find "Collision & Hitboxes" section
4. Adjust values:
   - `Ground Circle Size`: Make ovals (e.g., 20×12 for wide footprint)
   - `Elevated Hitbox Offset`: Position where you want arrows to hit
   - `Elevated Hitbox Radius`: Size of body hitbox

**Recommended Settings:**
```
Goblin Scout:
- ground_circle_size: (16, 10)
- elevated_hitbox_offset: (0, -12)
- elevated_hitbox_radius: 8

Orc Warrior:
- ground_circle_size: (20, 12)
- elevated_hitbox_offset: (0, -16)
- elevated_hitbox_radius: 12

Wolf Runner:
- ground_circle_size: (24, 10) # Long oval
- elevated_hitbox_offset: (0, -10)
- elevated_hitbox_radius: 10

Bat Flyer:
- ground_circle_size: (12, 8)
- enable_ground_hitbox: false # IMMUNE to ground arrows!
- elevated_hitbox_offset: (0, -30)
- elevated_hitbox_radius: 10

Troll Boss:
- ground_circle_size: (30, 18)
- elevated_hitbox_offset: (0, -24)
- elevated_hitbox_radius: 20
```

### Step 3: Update Tower Projectiles (Optional)

Different tower types can shoot different arrow types:

1. Create new arrow scene variants:
   - `arrow_ground.tscn` (hitbox_layer_mask = 16)
   - `arrow_air.tscn` (hitbox_layer_mask = 32)
   - `arrow_universal.tscn` (hitbox_layer_mask = 48)

2. Or use single arrow scene and set in Inspector

3. Tower upgrades can change arrow type:
   ```gdscript
   # In archer_tower.gd upgrade function
   if upgrade_path == "anti_air":
	   # Ensure arrows target elevated hitboxes
	   projectile_scene = preload("res://scenes/projectiles/arrow_air.tscn")
   ```

## Debug Mode (F4)

When DebugConfig.visual_debug_enabled is true:

- **Pink circles**: Ground footprint (what towers detect)
- **Blue circles**: Elevated hitbox (where arrows hit)
- **Yellow outline**: Visual sprite bounds (future enhancement)
- **Cyan raycasts**: Arrow collision detection rays
- **Green raycasts**: Successful hits

## Benefits

✅ **Visual Freedom**: Sprites can be any size without affecting gameplay
✅ **Strategic Depth**: Ground vs air targeting creates tower variety
✅ **Flying Enemies**: Properly immune to ground-targeting projectiles
✅ **Realistic Hits**: Arrows hit visual body, not ground shadow
✅ **Professional Polish**: Matches AAA tower defense games
✅ **Future-Proof**: Easy to add boss weak points, shields, etc.

## Known Limitations

⚠️ **Ground circle collision shape**: Currently still uses original CircleShape2D
   - To make it oval, manually edit CollisionShape2D in each enemy scene
   - Scale the CollisionShape2D node (not the shape itself)

⚠️ **Yellow visual outline**: Not yet implemented
   - Add in future update using sprite bounds detection

⚠️ **Melee combat**: Still uses Layer 1 ground circle detection
   - This is intentional (heroes block footsteps, not elevated bodies)

## Testing Checklist

- [ ] Arrows hit enemies and deal damage
- [ ] F4 debug shows pink ground circles
- [ ] F4 debug shows blue elevated hitboxes
- [ ] Console shows "Elevated hitbox created" messages
- [ ] Console shows "Direct collision with ElevatedHitbox" when arrows hit
- [ ] Enemies die correctly (hitboxes disabled during death animation)
- [ ] Towers still detect enemies via ground circle (Layer 1)
- [ ] Multiple enemies can be hit simultaneously

## Future Enhancements

1. **Visual Sprite Bounds (Yellow)**: Add debug visualization for sprite size
2. **Oval Ground Collision**: Convert CircleShape2D to custom oval shape
3. **Boss Weak Points**: Add Layer 7 special hitboxes for boss mechanics
4. **Shield Hitboxes**: Add Layer 8 for shield/armor mechanics
5. **Particle Effects**: Different hit effects for ground vs elevated hits
6. **Tower Upgrades**: "Anti-Air" upgrade path that changes arrow targeting

---

**Implementation Date**: 2025-10-24
**Status**: ✅ Core system complete, ready for testing
**Next Step**: Open Godot editor and test!
