# Multi-Hitbox System - Verification Checklist

## Current Configuration Analysis

### ✅ Arrow Configuration (CORRECT)
```
Arrow (Area2D):
- collision_layer = 4 (Layer 3 - projectiles)
- collision_mask = 32 (Layer 6 - elevated hitboxes) [Set in _ready()]
- Detects: Area2D hitboxes via area_entered signal
- Raycast: collide_with_areas=true, collide_with_bodies=false
```

### ✅ Enemy Hitbox Configuration (CORRECT)
```
Elevated Hitbox (Area2D):
- collision_layer = 32 (Layer 6)
- collision_mask = 0
- monitoring = false (doesn't detect anything)
- monitorable = true (can be detected by arrows)
```

### ✅ Detection Logic (CORRECT)
```
Arrow → Hitbox Detection:
  Arrow.collision_mask (32) & Hitbox.collision_layer (32) = 32 ✅ MATCH!

Hitbox → Arrow Detection:
  Hitbox.collision_mask (0) & Arrow.collision_layer (4) = 0 ✅ CORRECT (no reverse detection)
```

## Potential Issues & Verification

### Issue 1: ⚠️ Timing - Arrow _ready() vs setup()
**Question:** Does `_ready()` run before `setup()`?

**Answer:** YES ✅
- Arrow is instantiated
- Arrow._ready() runs → sets collision_mask = 32
- Tower calls arrow.setup() → sets target/damage
- No issue here

### Issue 2: ⚠️ Area2D vs Area2D detection
**Question:** Can two Area2D nodes detect each other?

**Answer:** YES, but only if **at least one** has `monitoring = true`

**Current Settings:**
- Arrow: monitoring = true (default for Area2D) ✅
- Hitbox: monitoring = false (we set this)

**Result:** Arrow will detect hitbox, but hitbox won't detect arrow ✅ CORRECT

### Issue 3: ⚠️ area_entered signal connection
**Question:** Is the signal connected correctly?

**Current Code (arrow.gd:144):**
```gdscript
area_entered.connect(_on_hitbox_entered)
```

**Callback (arrow.gd:411):**
```gdscript
func _on_hitbox_entered(area: Area2D):
    if area and area.get_parent():
        var enemy = area.get_parent()
        if enemy.is_in_group("enemy"):
            _hit_enemy(enemy)
```

✅ CORRECT

### Issue 4: ⚠️ Raycast might still be hitting CharacterBody2D
**Question:** Is raycast ONLY detecting Area2D hitboxes?

**Current Code (arrow.gd:332-333):**
```gdscript
query.collision_mask = hitbox_layer_mask  # 32 for elevated
query.collide_with_areas = true  # ✅ CHECK AREAS
query.collide_with_bodies = false  # ✅ IGNORE BODIES
```

✅ CORRECT - Only detects Area2D on layer 32

## What Could Go Wrong?

### Scenario A: Arrows pass through enemies
**Possible Causes:**
1. Hitbox not created (check console for "[Enemy] Elevated hitbox created")
2. Hitbox collision shape not added to scene tree
3. Hitbox position is way off (check elevated_hitbox_offset)
4. Arrow collision_mask not set (should be 32)

**Debug Steps:**
1. Run game and check console output
2. Press F4 to see debug visualization
3. Look for blue circles (elevated hitboxes)
4. Check if arrows are spawning at all

### Scenario B: Arrows hit but no damage
**Possible Causes:**
1. `_hit_enemy()` not being called
2. `enemy.take_damage()` failing
3. Hitbox parent is not the enemy

**Debug Steps:**
1. Add print statement in `_on_hitbox_entered()`: ✅ Already has one!
2. Check console for "[Arrow] Direct collision with ElevatedHitbox"
3. Add print in `_hit_enemy()` to confirm it's called

### Scenario C: Console spam with hitbox errors
**Possible Causes:**
1. Hitboxes being created multiple times
2. Signal connections happening twice

**Debug Steps:**
1. Check if `_setup_multiple_hitboxes()` is called multiple times
2. Verify signal connections with `is_connected()`

## Quick Test Script

Add this to `arrow.gd` in `_ready()` for debugging:

```gdscript
func _ready():
    area_entered.connect(_on_hitbox_entered)
    collision_mask = hitbox_layer_mask

    # DEBUG: Print arrow configuration
    print("[Arrow] Spawned with:")
    print("  - collision_layer: %d" % collision_layer)
    print("  - collision_mask: %d" % collision_mask)
    print("  - hitbox_layer_mask: %d" % hitbox_layer_mask)
    print("  - monitoring: %s" % monitoring)
```

Add this to `base_enemy.gd` in `_setup_multiple_hitboxes()` for debugging:

```gdscript
# Already has print statements! ✅
print("[Enemy] Elevated hitbox created: radius=%.1f, pos=%s, layer=6" % [elevated_hitbox_radius, elevated_hitbox_offset])
```

## Expected Console Output (Normal Operation)

```
[Enemy] Ground hitbox created: radius=8.0, layer=5
[Enemy] Elevated hitbox created: radius=10.0, pos=(0, -16), layer=6
[Enemy] Ground hitbox created: radius=8.0, layer=5
[Enemy] Elevated hitbox created: radius=10.0, pos=(0, -16), layer=6
...
🏹 Hero shooting arrow at: Goblin
[Arrow] Direct collision with ElevatedHitbox
✅ Multi-raycast HIT: ElevatedHitbox (offset=(0, 0))
[Enemy] Elevated hitbox hit by: Arrow
...
```

## Manual Verification Steps

### Step 1: Check Enemy Hitboxes Exist
1. Run game
2. Spawn an enemy
3. Console should show:
   ```
   [Enemy] Ground hitbox created: radius=8.0, layer=5
   [Enemy] Elevated hitbox created: radius=10.0, pos=(0, -16), layer=6
   ```

### Step 2: Check Debug Visualization
1. Press F4 during gameplay
2. Should see:
   - Pink circles = ground detection
   - Blue circles = elevated hitboxes
   - Cyan raycasts from arrows
   - Green raycasts when arrows hit

### Step 3: Check Arrow Hits
1. Place archer tower
2. Tower shoots arrow
3. Arrow flies toward enemy
4. Console should show:
   ```
   [Arrow] Direct collision with ElevatedHitbox
   ```
5. Enemy should take damage and health bar decreases

### Step 4: Verify Damage is Applied
1. Enemy health bar should decrease
2. Enemy should eventually die
3. No more "[Enemy] Elevated hitbox hit by:" messages after death

## If Nothing Works - Emergency Reset

If arrows aren't hitting at all, try this temporary fix in `arrow.gd`:

```gdscript
func _ready():
    # TEMPORARY: Force detect both old and new systems
    area_entered.connect(_on_hitbox_entered)
    body_entered.connect(_on_body_entered_legacy)

    collision_mask = 33  # Layers 1 + 32 (old enemies + new hitboxes)
    print("[Arrow] EMERGENCY MODE: Detecting both layers 1 and 32")

func _on_body_entered_legacy(body):
    if body.is_in_group("enemy"):
        print("[Arrow] Hit via LEGACY CharacterBody2D system")
        _hit_enemy(body)
```

This will let you know if the problem is:
- New hitbox system (no hit at all)
- vs. Arrow targeting (hits via legacy but not hitboxes)

## Summary

Based on the code analysis:
- ✅ Arrow configuration is CORRECT
- ✅ Hitbox configuration is CORRECT
- ✅ Collision layers match properly
- ✅ Signals are connected
- ✅ Raycast settings are correct

**The system SHOULD work!**

If it doesn't:
1. Check console output for hitbox creation messages
2. Press F4 to verify blue hitboxes are visible
3. Add debug print statements to trace execution
4. Try emergency reset mode above

---

**Next Step:** Run the game and report what you see in console!
