# AI Quick Start - 60 Second Setup ⚡

**Goal**: Get AI playing your game in under 1 minute!

---

## ✅ CHECKLIST (Follow in Order)

### ☐ Step 1: Open Level (10 seconds)
```
Godot → Open Scene → scenes/levels/level_01.tscn
```

### ☐ Step 2: Add Node (15 seconds)
```
Scene Tree → Right-click "TestLevel" → Add Child Node
→ Search "Node" → Create → Rename to "AITest"
```

### ☐ Step 3: Attach Script (15 seconds)
```
Select AITest → Inspector → Script → Load
→ Navigate to: scripts/ai/ai_test_simple.gd → Open
```

### ☐ Step 4: Choose Strategy (10 seconds)
```
Inspector → Script Variables → Strategy: "Archer Rush"
(Options: "Archer Rush", "Soldier Wall", "Greedy Economy")
```

### ☐ Step 5: Save (5 seconds)
```
Ctrl+S (or Cmd+S on Mac)
```

### ☐ Step 6: RUN! (5 seconds)
```
F5 (or click ▶ button)
```

---

## ✅ EXPECTED RESULT

### Console Output:
```
==================================================
🤖 SIMPLE AI TEST STARTING
==================================================
✅ AI IS NOW PLAYING!
   Strategy: Archer Rush
==================================================

🤖 AI Decision: build_tower (archer_rush_build)
  ✅ Built archer tower at spot 2
```

### In-Game:
- Towers build automatically ✓
- No manual clicking needed ✓
- AI plays the level ✓

---

## ❌ TROUBLESHOOTING (If AI Doesn't Work)

### Problem: Nothing happens after F5

**Fix 1**: Restart Godot
```
File → Quit → Reopen project → Try again
```

**Fix 2**: Verify script attached
```
Select AITest node → Inspector → Check "Script:" field shows ai_test_simple.gd
```

### Problem: Error "Class AIController not found"

**Fix**: Add class_name to ai_controller.gd
```
Open scripts/ai/ai_controller.gd
First line should be:
  extends Node
  class_name AIController

Save file → Restart Godot
```

### Problem: "Tower spots found: 0"

**Fix**: Add spots to group
```
Select TowerSpot1 → Inspector → Node tab → Groups
→ Add group: "tower_spot" → Add
Repeat for all TowerSpot nodes
```

---

## 📊 WHAT TO WATCH

### Good Signs ✅
- Console shows "AI Decision:" messages
- Towers appear without clicking
- Gold decreases automatically
- Towers upgrade automatically

### Bad Signs ❌
- Red errors in console
- No "AI IS NOW PLAYING!" message
- Game runs but no towers build
- "Invalid spot" or "Scene not found" errors

---

## 🎯 NEXT STEPS

### Once AI Works:

1. **Try Different Strategies**
   ```
   Change "Archer Rush" to "Soldier Wall"
   Run again → See different playstyle
   ```

2. **Watch Multiple Games**
   ```
   Run game 3-5 times
   Note which strategy wins more
   ```

3. **Check Balance**
   ```
   If AI wins 100% → Level too easy
   If AI loses 100% → Level too hard
   If AI wins 50-70% → Good balance!
   ```

4. **Read Full Guide**
   ```
   docs/AI_SETUP_GUIDE.md → Detailed instructions
   docs/AI_PLAYTEST_SYSTEM.md → Complete documentation
   ```

---

## 🔧 ADVANCED: Custom Strategy

Want to tweak AI behavior? Edit `scripts/ai/ai_controller.gd`:

```gdscript
# Find this function (around line 370):
func _decide_archer_rush(state: Dictionary) -> Dictionary:
    # Change this number to adjust build threshold:
    if state.gold >= 100:  # ← Change to 150 to be more conservative
        # Build archer logic
```

Save → Run → AI uses new behavior!

---

## 📁 FILE STRUCTURE

```
Test-1-Godot/
├─ scripts/ai/
│  ├─ ai_controller.gd       ← Core AI brain
│  └─ ai_test_simple.gd      ← What you attach to scene
│
├─ scenes/levels/
│  └─ level_01.tscn          ← Where you add AITest node
│
└─ docs/
   ├─ AI_QUICK_START.md      ← THIS FILE (60s setup)
   ├─ AI_SETUP_GUIDE.md      ← Detailed guide
   └─ AI_PLAYTEST_SYSTEM.md  ← Full documentation
```

---

## ⏱️ TIME ESTIMATE

- First time setup: **1-2 minutes**
- Subsequent tests: **10 seconds** (just change strategy + F5)
- Per game duration: **3-5 minutes** (normal speed)

---

## 🎮 CONTROLS

While AI is playing:

- **SpeedButton** (top-right): Change game speed (1x, 2x, 4x)
- **ESC**: Pause game
- **Console**: Watch AI decisions in real-time

---

**That's it! You're now watching AI play your tower defense game!** 🎉

For more control and automation, continue to the full setup guide.

---

**Last Updated**: 2025-10-21
**Setup Time**: ~60 seconds
**Difficulty**: Beginner ⭐
