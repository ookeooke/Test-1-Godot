# Collision & Setup Guide - Visual Reference

## Layer System (project.godot)

```
Layer 1 - enemies        (Enemies' CharacterBody2D)
Layer 2 - towers         (Towers' StaticBody2D)
Layer 3 - projectiles    (Arrows' Area2D)
Layer 4 - tower_range    (Tower detection Area2D)
Layer 5 - click_spots    (Tower spots clickable area)
Layer 6 - click_towers   (Tower clickable area)
Layer 7 - click_heroes   (Hero clickable area)
```

## Enemy Setup (Goblin Scout Example)

### Scene Structure
```
GoblinScout (CharacterBody2D)          ← Layer 1 (enemies)
├── HealthBar (Control)
├── Sprite (Sprite2D)
├── Label (Label)
├── CollisionShape2D                   ← CapsuleShape2D, radius 15.0
├── HitPoint (Marker2D)                ← TARGET for projectiles (adjustable offset)
├── AnimationPlayer
└── HitParticles (CPUParticles2D)
```

### Collision Settings
```gdscript
# In base_enemy.gd _ready()
collision_layer = 1   # Enemy IS on layer 1
collision_mask = 0    # Enemy detects NOTHING (pure target)
```

**Why mask = 0?**
- Enemies don't need to detect collisions
- They follow paths/waypoints
- Towers/arrows detect THEM, not the other way around

### HitPoint System
- **Yellow crosshair** visible in editor (position adjustable per enemy type)
- Arrows aim at `enemy.get_node("HitPoint").global_position`
- Allows artistic control (aim at head, chest, etc.)
- Falls back to `enemy.global_position` if no HitPoint exists

## Tower Setup (Archer Tower Example)

### Scene Structure
```
ArcherTower (StaticBody2D)
├── TowerVisual (ColorRect)
├── Archer (Node2D)
│   ├── Body (ColorRect)
│   ├── Head (ColorRect)
│   └── Weapon (Node2D)               ← Rotates toward target
│       ├── Bow (ColorRect)
│       └── MuzzleFlash (CPUParticles2D)
├── DetectionRange (Area2D)           ← Layer 4, Mask 1 (detects enemies)
│   └── CollisionShape2D              ← CircleShape2D, radius 300
├── RangeIndicator (Polygon2D)        ← Visual range circle (filled)
└── ClickArea (Area2D)                ← Layer 6 (click_towers)
    └── CollisionShape2D              ← CircleShape2D, radius 40
```

### Collision Settings
```gdscript
# DetectionRange (finds enemies)
collision_layer = 8   # Layer 4 (tower_range)
collision_mask = 1    # Detects layer 1 (enemies)
monitoring = true

# ClickArea (player clicks)
collision_layer = 64  # Layer 6 (click_towers)
collision_mask = 0    # Doesn't detect anything
input_pickable = true
```

### How Tower Tracking Works

1. **Detection** (DetectionRange Area2D)
```gdscript
func _on_enemy_entered_range(body):
    if body.is_in_group("enemy"):
        enemies_in_range.append(body)

func _on_enemy_exited_range(body):
    enemies_in_range.erase(body)
```

2. **Target Selection** (shoot_timer timeout)
```gdscript
# Every 1.0 / attack_speed seconds:
func _on_shoot_timer_timeout():
    # Pick best target based on mode:
    match targeting_mode:
        FIRST:  # Furthest along path
        STRONG: # Highest HP
        WEAK:   # Lowest HP
        CLOSE:  # Nearest to tower
        LAST:   # Closest to path start

    if target_found:
        shoot_at(target)
```

3. **Weapon Rotation** (_process every frame)
```gdscript
func _process(delta):
    if current_target and is_instance_valid(current_target):
        archer_weapon.look_at(current_target.global_position)
```

## Arrow Setup (Projectile)

### Scene Structure
```
Arrow (Area2D)                        ← Layer 3 (projectiles)
├── Shadow (ColorRect)                ← Visual shadow at ground level
├── ColorRect                         ← Arrow shaft (22px long)
│   ├── Polygon2D                     ← Feathers
│   ├── ColorRect (×4)                ← Fletching details
│   └── ColorRect (tip)               ← Arrowhead
├── CollisionShape2D                  ← CircleShape2D, radius 8.0, offset (2,0)
└── Trail (CPUParticles2D)            ← Smoke trail
```

### Collision Settings
```gdscript
collision_layer = 4   # Layer 3 (projectiles)
collision_mask = 1    # Detects layer 1 (enemies)
```

### Arrow Physics (Ballistic Arc)

**Visual Position (Parabolic Arc):**
```gdscript
# Progress from 0.0 (launch) to 1.0 (impact)
var progress = travel_time / flight_time

# Ground position (linear interpolation)
var ground_pos = start_position.lerp(target_position, progress)

# Arc offset (parabola formula)
var arc_height = distance * (arc_height_export / 200.0)
var arc_offset_y = 4.0 * arc_height * progress * (1.0 - progress)

# Final position (Godot: -Y is up)
global_position = ground_pos + Vector2(0, -arc_offset_y)
```

**Rotation (Velocity-Based):**
```gdscript
# Horizontal velocity: constant forward
var horizontal_velocity = direction * flight_speed

# Vertical velocity: derivative of parabola
# d/dt[4h * t * (1-t)] = 4h * (1 - 2t) / flight_time
var vertical_velocity = 4.0 * arc_height * (1.0 - 2.0 * progress) / flight_time

# Arrow points along velocity vector
var velocity_2d = Vector2(horizontal_velocity.x,
                         horizontal_velocity.y - vertical_velocity)
rotation = velocity_2d.angle()
```

**Result:**
- Arrow launches upward (positive rotation)
- Reaches horizontal at arc peak (0° rotation)
- Falls downward at target (negative rotation)
- Natural "gravity" feel

### Arrow Collision Detection (Multi-Point Raycast)

**Problem:** Fast enemies + arc trajectory = potential "tunneling"

**Solution:** 5 raycasts per frame in radial pattern

```gdscript
func _check_collision_along_path(from_pos, to_pos):
    # Get arrow tip position in world space
    var local_offset = Vector2(10, 0)  # Tip in local coords
    var tip_offset = local_offset.rotated(rotation)  # World coords

    # Check 5 points: center + 4 radial
    var check_points = [
        Vector2.ZERO,       # Center
        Vector2(12, 0),     # Right
        Vector2(-12, 0),    # Left
        Vector2(0, 12),     # Down
        Vector2(0, -12)     # Up
    ]

    for offset in check_points:
        var rotated_offset = offset.rotated(rotation)
        var from = from_pos + tip_offset + rotated_offset
        var to = to_pos + tip_offset + rotated_offset

        # Raycast from previous frame to current frame
        var result = space_state.intersect_ray(from, to, mask=1)

        if result.collider.is_in_group("enemy"):
            _hit_enemy(result.collider)
            return
```

**Visualization (F4 Debug Mode):**
- Green lines = raycasts checking for enemies
- Red circle = detection range
- Yellow line = current targeting line

### Arrow Prediction System

**Dynamic Flight Time Calculation:**
```gdscript
func _calculate_target_position():
    var base_pos = enemy.get_node("HitPoint").global_position

    # Calculate ACTUAL flight time based on distance
    var distance = global_position.distance_to(base_pos)
    var flight_time = distance / flight_speed  # Real time to arrive

    # Get enemy velocity (from PathFollow2D rotation)
    var path_direction = path_follower.get_transform().x.normalized()
    var enemy_velocity = path_direction * enemy.speed

    # Predict future position
    var predicted_pos = base_pos + (enemy_velocity * flight_time)
    return predicted_pos
```

**Why it works:**
- Short shots (100px) → 0.2s flight → small prediction
- Long shots (500px) → 1.0s flight → large prediction
- Accounts for enemy speed AND tower range

## Level Setup (level_01.tscn Example)

### Required Nodes
```
Level_01 (Node2D)
├── Camera2D                          ← Player camera
├── Waypoints (Node2D)                ← Path system
│   ├── WP_Start (PathWaypoint)
│   ├── WP_01 (PathWaypoint)
│   └── ... (more waypoints)
├── RoadRenderer (Node2D)             ← Visual road between waypoints
├── WaveManager (Node)                ← Enemy spawning
├── TowerSpots (Node2D)               ← Tower placement markers
│   ├── TowerSpot1 (Area2D)           ← Layer 5 (click_spots)
│   └── ...
├── EnemySpawnPoint (Marker2D)        ← Where enemies appear
├── UI (CanvasLayer)                  ← Game UI (zoom-independent)
└── LevelController (Node)            ← Level logic
```

### EnemyManager Tracking

**Central Registry Pattern:**
```gdscript
# EnemyManager (autoload singleton)
var living_enemies: Array[BaseEnemy] = []
var living_bosses: Array[BaseEnemy] = []

func register_enemy(enemy: BaseEnemy):
    living_enemies.append(enemy)
    if enemy.is_boss:
        living_bosses.append(enemy)

func unregister_enemy(enemy: BaseEnemy):
    living_enemies.erase(enemy)
    living_bosses.erase(enemy)
```

**Tower queries EnemyManager (not scene tree):**
```gdscript
# OLD WAY (slow): 10 towers × 50 enemies = 500 checks/frame
for enemy in get_tree().get_nodes_in_group("enemy"):
    check_distance()

# NEW WAY (fast): 50 checks/frame total
for enemy in EnemyManager.living_enemies:
    if global_position.distance_to(enemy.global_position) < range:
        enemies_in_range.append(enemy)
```

**90% performance improvement!**

## Common Collision Issues & Fixes

### Issue 1: "Tower doesn't detect enemies"

**Check:**
1. DetectionRange Area2D: `collision_mask = 1` (layer 1 = enemies)
2. DetectionRange: `monitoring = true`
3. Enemy CharacterBody2D: `collision_layer = 1`
4. Enemy has `"enemy"` group assigned

**Fix:**
```gdscript
# In archer_tower.gd _ready()
detection_range.collision_mask = 1
detection_range.monitoring = true

# In base_enemy.gd _ready()
collision_layer = 1
add_to_group("enemy")
```

### Issue 2: "Arrow passes through enemy"

**Likely cause:** Fast enemy + single raycast = tunneling

**Check:**
1. Arrow CollisionShape2D radius (should be 8-12)
2. Multi-point raycast enabled (5 check points)
3. Continuous collision detection (`_check_collision_along_path`)

**Fix:**
```gdscript
# In arrow.gd
const COLLISION_RADIUS = 12.0  # Increased from 6.0

# Multi-raycast with 5 points
var check_points = [
    Vector2.ZERO,
    Vector2(12, 0), Vector2(-12, 0),
    Vector2(0, 12), Vector2(0, -12)
]
```

### Issue 3: "Arrow aims at wrong spot"

**Check:**
1. Enemy has HitPoint Marker2D child
2. HitPoint position matches visual center
3. Arrow uses `enemy.get_node("HitPoint").global_position`

**Fix:**
```gdscript
# In base_enemy.gd _setup_hit_point_marker()
if has_node("HitPoint"):
    hit_point_marker = get_node("HitPoint")
else:
    hit_point_marker = Marker2D.new()
    add_child(hit_point_marker)

hit_point_marker.position = hit_point_offset  # Exported variable
```

### Issue 4: "Tower clickable area blocks enemy clicks"

**Check:**
1. ClickArea layer: Should be 64 (layer 6 = click_towers)
2. ClickArea mask: Should be 0 (doesn't detect anything)
3. UI panels: `mouse_filter = MOUSE_FILTER_IGNORE` on non-interactive elements

**Fix:**
```gdscript
# In archer_tower.gd
click_area.collision_layer = 64  # Layer 6
click_area.collision_mask = 0    # No detection
click_area.input_pickable = true # Enable input
```

### Issue 5: "Corpse blocks arrows"

**Already fixed in base_enemy.gd _play_death_animation():**
```gdscript
# Disable ALL collisions on death
collision_layer = 0  # Remove from all layers
collision_mask = 0   # Detect nothing

# Disable Area2D children (detection zones)
for child in get_children():
    if child is Area2D:
        child.monitoring = false
        child.monitorable = false
```

## Debug Tools

### F4 - Visual Debug Mode

**Enables:**
- Tower range circles (green)
- Targeting lines (red line to current target)
- Arrow raycasts (cyan lines, green on hit)
- Enemy progress/health labels
- Boss highlights (red circles)

**Toggle:**
```gdscript
# In-game: Press F4
DebugConfig.visual_debug_enabled = !DebugConfig.visual_debug_enabled
```

### Balance Tracking

**Metrics:**
- Damage per tower (who's effective?)
- Kill attribution (which tower got the kill?)
- Enemy leaked vs killed
- Gold economy flow

**Export:**
- F4 key: Export CSV/JSON to AppData folder

## Summary - Quick Reference

### Enemies
- **Layer:** 1 (enemies)
- **Mask:** 0 (detects nothing)
- **Collider:** CapsuleShape2D on CharacterBody2D
- **Target Point:** HitPoint Marker2D (adjustable offset)

### Towers
- **Layer:** 2 (towers)
- **Detection:** Area2D on layer 4, mask 1 (finds enemies)
- **Click:** Area2D on layer 6, mask 0 (player clicks)
- **Targeting:** Queries EnemyManager.living_enemies

### Arrows
- **Layer:** 3 (projectiles)
- **Mask:** 1 (detects enemies)
- **Collision:** Multi-point raycast (5 points)
- **Movement:** Parabolic arc with velocity-based rotation
- **Prediction:** Dynamic flight time calculation

### Performance
- **Old:** 10 towers × 50 enemies = 500 checks/frame
- **New:** EnemyManager centralized = 50 checks/frame
- **Improvement:** 90% reduction
