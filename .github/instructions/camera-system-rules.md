# Camera System - DO NOT MODIFY Rules

## ⚠️ CRITICAL: Camera System is LOCKED

The camera system has been **simplified and finalized**. Do NOT add new features, abstractions, or "improvements" unless explicitly requested.

---

## 📋 What EXISTS and How to USE It

### **Current Camera Controller**
- **File:** `scripts/camera/camera_controller_improved.gd`
- **Lines:** 706 lines (down from 726 - already simplified)
- **Status:** Production-ready, tested, working

### **Available Features (USE THESE)**

#### **1. Camera Shake**
```gdscript
# Direct call - NO wrappers
var camera = get_viewport().get_camera_2d()
if camera and camera.has_method("add_shake"):
    camera.add_shake(5.0)   # Small shake
    camera.add_shake(15.0)  # Medium shake
    camera.add_shake(30.0)  # Large shake
```

#### **2. Snap to Position**
```gdscript
var camera = get_viewport().get_camera_2d()
if camera:
    camera.snap_to_position(world_position)
    # Optional: camera.snap_to_position(world_position, zoom_level, duration)
```

#### **3. Snap to Object**
```gdscript
var camera = get_viewport().get_camera_2d()
if camera:
    camera.snap_to_object(tower_node)
    # Optional: camera.snap_to_object(tower_node, zoom_level)
```

#### **4. Reset Camera**
```gdscript
var camera = get_viewport().get_camera_2d()
if camera:
    camera.reset_to_center()  # Centers and resets zoom
```

#### **5. Set Level Bounds**
```gdscript
var camera = get_viewport().get_camera_2d()
if camera:
    camera.set_level_bounds(Rect2(x, y, width, height))
```

---

## 🚫 What You MUST NOT Do

### **DO NOT Create:**
- ❌ Event bus for camera
- ❌ Signal-based camera architecture
- ❌ CameraService autoload
- ❌ CameraManager singleton
- ❌ Camera state machine
- ❌ Priority systems
- ❌ Camera mode enums
- ❌ Multi-target follow systems
- ❌ AI director camera
- ❌ Wrapper functions (like old CameraEffects)
- ❌ Abstract base classes for camera
- ❌ Camera interface/protocol

### **DO NOT Add:**
- ❌ New signals to camera controller
- ❌ New autoloads related to camera
- ❌ New helper scripts for camera
- ❌ New animation systems for camera
- ❌ New interpolation methods
- ❌ New input handlers
- ❌ New platform detection (already handles PC, Mobile, Web, Console)

### **DO NOT Refactor:**
- ❌ "Let me decouple the camera from gameplay"
- ❌ "Let me add observer pattern"
- ❌ "Let me make it more scalable"
- ❌ "Let me add better architecture"
- ❌ "Let me implement best practices"

---

## ✅ What You CAN Do

### **Allowed Modifications (if requested):**

1. **Bug fixes only**
   - Fix broken functionality
   - Fix platform-specific issues
   - Fix performance problems

2. **Use existing features**
   - Call existing methods
   - Adjust existing export variables
   - Change timing/intensity values

3. **Simple gameplay integration**
   ```gdscript
   # Example: Victory screen wants to center camera
   var camera = get_viewport().get_camera_2d()
   if camera:
       camera.reset_to_center()  # ✅ Use existing method
   ```

4. **Adjust values**
   ```gdscript
   # In camera inspector or via code:
   camera.keyboard_pan_speed = 600.0  # ✅ Tune existing values
   camera.edge_scroll_margin = 60     # ✅ Adjust existing settings
   ```

---

## 📐 Architecture Principles

### **Keep It Simple**
- Current system: **Direct calls**
- Enemy dies → Enemy calls `camera.add_shake(5.0)`
- Tower placed → TowerSpot calls `camera.snap_to_object(tower)`
- **This is FINE for a tower defense game**

### **Why No Event Bus?**
- Tower defense is single-player
- Camera interactions are simple
- Event bus adds:
  - +3 files
  - +50 lines of code
  - +Indirection (harder to debug)
  - +Learning curve for team
- **Trade-off not worth it for this project**

### **Why No Signals?**
- Signals good for: inter-node communication, UI updates, game state
- Camera is **tool/utility**, not **game entity**
- Direct calls are:
  - ✅ Easier to trace
  - ✅ Easier to debug
  - ✅ Fewer failure points
  - ✅ Clear call stack

---

## 🎯 How to Respond to Feature Requests

### **User Says: "Add victory camera sequence"**
**CORRECT Response:**
```gdscript
# Use existing methods
var camera = get_viewport().get_camera_2d()
if camera:
    camera.reset_to_center()  # Zoom out
    await get_tree().create_timer(0.5).timeout
    # Done - uses what exists
```

**WRONG Response:**
```gdscript
# Don't create new systems:
# ❌ "Let me create a CameraSequencer"
# ❌ "Let me add a cutscene_mode signal"
# ❌ "Let me implement a camera state machine"
```

---

### **User Says: "Camera should shake when wave starts"**
**CORRECT Response:**
```gdscript
# In WaveManager:
var camera = get_viewport().get_camera_2d()
if camera:
    camera.add_shake(10.0)  # Direct call
```

**WRONG Response:**
```gdscript
# ❌ "Let me create an EventBus for screen shake"
# ❌ "Let me decouple this with signals"
# ❌ "Let me add a shake request queue"
```

---

### **User Says: "Make camera follow selected hero"**
**CORRECT Response:**
```gdscript
# Use existing snap_to_object
var camera = get_viewport().get_camera_2d()
if camera:
    camera.snap_to_object(hero)  # Existing method
```

**WRONG Response:**
```gdscript
# ❌ "Let me implement a follow system"
# ❌ "Let me add a target tracking mode"
# ❌ "Let me create a CameraFollowBehavior class"
```

---

## 🔧 Maintenance Guidelines

### **If User Reports a Bug:**
1. ✅ Fix the bug in existing code
2. ✅ Test the fix
3. ❌ Don't "improve while you're there"
4. ❌ Don't suggest refactoring

### **If User Wants New Camera Behavior:**
1. ✅ Check if existing methods can do it
2. ✅ If yes, show how to use them
3. ✅ If no, ask: "Do you want me to extend the existing system?"
4. ❌ Don't auto-create new abstractions

### **If You Think Architecture is Wrong:**
1. ❌ Don't fix it unprompted
2. ✅ Ask user: "Current code works but could be simplified. Want me to?"
3. ✅ Wait for explicit permission
4. ✅ If user says no, drop it

---

## 📊 Complexity Budget

Current camera system complexity: **Appropriate for tower defense**

| Feature | Complexity | Status |
|---------|------------|--------|
| Pan/drag | Simple | ✅ Good |
| Inertia | Simple | ✅ Good |
| Edge scroll | Simple | ✅ Good |
| Shake | Simple | ✅ Good |
| Snap-to | Simple | ✅ Good |
| Bounds | Automated | ✅ Good |
| **Event bus** | **Medium** | ❌ **Overkill** |
| **Signals** | **Medium** | ❌ **Overkill** |
| **State machine** | **High** | ❌ **Overkill** |
| **AI director** | **Very High** | ❌ **Overkill** |

**Budget rule:** Keep complexity at "Simple" tier.

---

## 🎓 Learning from Past Mistakes

### **What We Did Wrong Before:**
1. Created `camera_effects.gd` wrapper (152 lines)
   - Added zero value
   - Made code harder to trace
   - **Fixed:** Deleted it

2. Suggested event bus architecture
   - Good for large teams
   - Overkill for solo dev
   - **Fixed:** Didn't implement

3. Suggested signal-based decoupling
   - Textbook "best practice"
   - Added complexity for this project
   - **Fixed:** Didn't implement

### **Lessons Learned:**
- ✅ "Best practices" ≠ "Best for this project"
- ✅ Simple > "Scalable" for small games
- ✅ Direct calls > Abstractions for solo dev
- ✅ Working code > "Proper" architecture

---

## 🔒 Final Rules (TL;DR)

1. **Camera controller is LOCKED** - don't modify without explicit request
2. **Use existing methods** - don't create new abstractions
3. **Direct calls are fine** - don't add event buses/signals
4. **Keep it simple** - tower defense doesn't need complex camera architecture
5. **Ask before "improving"** - user might not want it
6. **If it works, leave it** - working > "correct"

---

## 📞 When in Doubt

**Ask yourself:**
> "Does this request require a NEW camera feature, or can I use EXISTING methods?"

**If EXISTING methods work → Use them**
**If NEW feature needed → Ask user before creating**

**Default answer to "Should I refactor the camera?"**
→ **NO, unless explicitly requested**

---

## ✅ Approved Camera Architecture

```
Level Scene
    └── Camera2D (camera_controller_improved.gd)
            ↑
            │ Direct calls
            │
    Enemy.die() ─────→ camera.add_shake(5.0)
    TowerSpot.place() → camera.snap_to_object(tower)
    WaveManager.win() → camera.reset_to_center()
```

**This is CORRECT architecture for this project.**
**Don't "improve" it.**

---

*Last updated: After simplification refactor (removed camera_effects.gd, -172 lines)*
*Status: Production-ready, locked, do not modify*
