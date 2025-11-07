# Hit Marker Visual Analysis

## ❌ PROBLEM: Hit Marker Position Is WRONG

Your hit marker is **NOT** appearing at the enemy's HitPoint. Let me show you why:

## 🔍 Current System Flow

### Where Arrow Detects Hit (Raycast):

```gdscript
// In _check_collision_along_path() - line 277-350

1. Raycast FROM: previous_arrow_position + arrow_tip_offset
2. Raycast TO: current_arrow_position + arrow_tip_offset
3. If raycast hits enemy → call _hit_enemy(enemy)
```

**Raycast checks collision along arrow's flight path** ✅

### Where Hit Marker Spawns (WRONG):

```gdscript
// In _hit_enemy() - line 352-381

var hit_position = global_position + visual_offset + rotated_collision_offset

1. global_position = arrow's CENTER position
2. visual_offset = sprite vertical offset (arc height)
3. rotated_collision_offset = Vector2(10, 0).rotated(rotation)

Result: hit_position = WHERE THE ARROW TIP IS VISUALLY
```

**Hit marker spawns at ARROW TIP POSITION, not at enemy HitPoint!** ❌

## 📊 Visual Diagram - Current Behavior

```
Enemy at (500, 300)
┌─────────────┐
│   GOBLIN    │
│      ●──────┼─→ HitPoint (500, 300) ← Target position
│             │
└─────────────┘

Arrow flying from left:
          Arrow center (450, 295)
               ↓
          ─────────→  Arrow tip (460, 295)
                         ↓
                    Hit marker spawns HERE ✗

But should spawn at HitPoint (500, 300) ✓
```

### Positional Error Example:

```
Scenario: Arrow traveling from left to right

Arrow global_position = (450, 295)
Arrow rotation = 0° (pointing right)
Arrow tip offset = Vector2(10, 0).rotated(0°) = (10, 0)

Hit position calculation:
= (450, 295) + (0, 0) + (10, 0)
= (460, 295)

Enemy HitPoint actual position:
= (500, 300)

ERROR: Hit marker is 40px to the LEFT and 5px ABOVE the HitPoint!
```

## 🎯 What SHOULD Happen

Hit marker should spawn at **enemy.get_node("HitPoint").global_position**, NOT at arrow tip!

### Correct Flow:

```
1. Raycast detects hit on enemy
2. Get enemy's HitPoint.global_position (500, 300)
3. Spawn hit marker at HitPoint position
4. Result: Hit marker appears at enemy center ✓
```

## 🔧 THE FIX

### Option 1: Use Enemy HitPoint Position (RECOMMENDED)

**File:** `scenes/projectiles/arrow.gd`, function `_hit_enemy()` at line 352

**Replace lines 354-368:**

```gdscript
func _hit_enemy(enemy):
	"""Deal damage to enemy"""
	# FIXED: Get the actual HitPoint position from the enemy
	var hit_position = enemy.global_position  # Default to enemy center

	# Check if enemy has HitPoint marker
	if enemy.has_node("HitPoint"):
		hit_position = enemy.get_node("HitPoint").global_position

	# Spawn red X hit marker at ENEMY'S HitPoint (not arrow tip!)
	if hit_marker_scene and enemy and is_instance_valid(enemy):
		var hit_marker = hit_marker_scene.instantiate()

		# Calculate hit position in enemy's LOCAL coordinate space
		var local_hit_position = hit_position - enemy.global_position

		# Attach marker as child of enemy (moves with enemy)
		enemy.add_child(hit_marker)
		hit_marker.position = local_hit_position
```

**Why this works:**
- ✅ Uses enemy's HitPoint.global_position (the target!)
- ✅ Hit marker spawns exactly where arrow was AIMING
- ✅ Matches visual expectation (center of enemy)
- ✅ Works with adjustable HitPoint offsets per enemy

### Option 2: Use Raycast Hit Point (ALTERNATIVE)

Store the exact raycast intersection point and use that:

**In `_check_collision_along_path()`, line 335-350:**

```gdscript
var result = space_state.intersect_ray(query)

if result and result.has("collider"):
	var hit_body = result.collider

	if hit_body.is_in_group("enemy"):
		# NEW: Store the exact intersection point
		var intersection_point = result.position
		_hit_enemy(hit_body, intersection_point)  # Pass intersection point
		return
```

**In `_hit_enemy()`, modify to accept intersection point:**

```gdscript
func _hit_enemy(enemy, intersection_point: Vector2 = Vector2.ZERO):
	# Use intersection point if provided, otherwise use HitPoint
	var hit_position = intersection_point

	if hit_position == Vector2.ZERO:
		# Fallback to HitPoint
		if enemy.has_node("HitPoint"):
			hit_position = enemy.get_node("HitPoint").global_position
		else:
			hit_position = enemy.global_position
```

**Why this works:**
- ✅ Uses EXACT raycast intersection point
- ✅ Most accurate possible position
- ✅ Accounts for collision shape variations

## 📸 Visual Comparison

### Before Fix (Current):

```
Enemy sprite (32×32)
┌─────────────┐
│   GOBLIN    │
│      ●      │ ← HitPoint (500, 300)
│             │
└─────────────┘

Arrow: ──────────→
              ↑
         Hit marker HERE (460, 295)
         40px to the LEFT of target!
         5px ABOVE target!
```

### After Fix (Correct):

```
Enemy sprite (32×32)
┌─────────────┐
│   GOBLIN    │
│      ●      │ ← HitPoint (500, 300)
│      ✗      │ ← Hit marker HERE (500, 300) ✓
└─────────────┘

Arrow: ────────────────●
                Hit marker exactly at HitPoint!
```

## 🧪 How to Test

### Step 1: Check Current Behavior
1. Run game (F5)
2. Build archer tower
3. Spawn enemies
4. Watch where red X appears
5. **Problem:** X appears slightly left/above enemy center

### Step 2: Apply Fix
Use Option 1 (recommended) - modify `_hit_enemy()` function

### Step 3: Test Fixed Behavior
1. Run game (F5)
2. Build archer tower
3. Spawn enemies
4. Watch where red X appears
5. **Result:** X appears exactly at enemy center (HitPoint)

### Step 4: Enable Debug Mode (F4)
You should see:
- Yellow crosshair = enemy HitPoint position
- Red X = hit marker spawning at SAME position as yellow crosshair ✓

## 📋 Code Locations

**Files to modify:**

1. `scenes/projectiles/arrow.gd`
   - Function: `_hit_enemy()` at line 352
   - Lines to replace: 354-368

**Changes needed:**
- Remove arrow tip position calculation
- Use `enemy.get_node("HitPoint").global_position` instead
- Hit marker spawns at enemy HitPoint, not arrow tip

## 💡 Why Current Code Does This

The current code calculates arrow tip position because:
1. It was designed for "impact point" visualization
2. Shows where the arrow PHYSICALLY struck
3. Matches older tower defense games (Bloons TD)

But your system uses **HitPoint markers** for targeting, so hit markers should match those!

## 🎯 Recommended Solution

**Use Option 1:** Change hit marker to spawn at enemy HitPoint.

**Reasoning:**
- Simpler code (no complex offset calculations)
- Matches targeting system (arrows aim at HitPoint)
- Visually clearer for players (center hit = good feedback)
- Works with adjustable HitPoints per enemy type
- Kingdom Rush style (hit effects at enemy center)

**Result:**
- Hit markers appear exactly where arrows were aiming
- Visual feedback matches expectations
- No confusing offset errors
