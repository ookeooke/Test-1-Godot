# AI Setup Guide - Step-by-Step Instructions

## Table of Contents
1. [Quick Setup (2 Minutes)](#method-1-quick-setup-2-minutes) ⭐ **START HERE**
2. [Manual Code Setup](#method-2-manual-code-setup-5-minutes)
3. [Advanced: Godot Editor Setup](#method-3-godot-editor-setup-visual)
4. [Testing & Verification](#testing--verification)
5. [Troubleshooting](#troubleshooting)

---

# METHOD 1: Quick Setup (2 Minutes) ⭐ **EASIEST**

This is the fastest way to see AI playing your game.

## Step 1: Open Your Level Scene

1. In Godot, open `scenes/levels/level_01.tscn`
2. You should see your level with:
   - WaveManager
   - PlacementManager
   - TowerSpots
   - EnemyPath
   - Camera2D

## Step 2: Add AI Test Node

### Option A: Using Scene Tree (Recommended)

1. In the **Scene Tree** panel (left side), right-click on **TestLevel** (root node)
2. Select **"Add Child Node"**
3. Search for **Node** and select it
4. Name it **"AITest"**
5. Click **"Create"**

![Add Node](https://i.imgur.com/example1.png)

### Option B: Quick Add

1. Select the **TestLevel** node in Scene Tree
2. Press **Ctrl+A** (Windows/Linux) or **Cmd+A** (Mac)
3. Type **"Node"** and press Enter
4. Rename to **"AITest"**

## Step 3: Attach the AI Script

1. With **AITest** node selected:
2. In the **Inspector** panel (right side), click the **"Script"** dropdown
3. Select **"Load"**
4. Navigate to: `res://scripts/ai/ai_test_simple.gd`
5. Click **"Open"**

**OR** drag and drop:
1. Open **FileSystem** panel (bottom left)
2. Navigate to `scripts/ai/ai_test_simple.gd`
3. **Drag** the file onto the **AITest** node
4. Drop it

![Attach Script](https://i.imgur.com/example2.png)

## Step 4: Configure AI Strategy (Optional)

With **AITest** node selected, look at **Inspector** panel:

```
Script Variables:
├─ Strategy: "Archer Rush"    ← Change this!
└─ Show Debug Info: ✓ (checked)
```

**Available Strategies:**
- `"Archer Rush"` - Aggressive archer spam (default)
- `"Soldier Wall"` - Defensive soldiers + archers
- `"Greedy Economy"` - Save gold, heavy upgrades

Change it by typing in the text field!

## Step 5: Save and Run!

1. Press **Ctrl+S** to save the scene
2. Press **F5** to run the project
3. Select **level_01** when prompted
4. **Watch the AI play!**

### What You'll See:

**In the Console (Output panel at bottom):**
```
==================================================
🤖 SIMPLE AI TEST STARTING
==================================================

✅ AI IS NOW PLAYING!
   Strategy: Archer Rush
   Watch the console to see AI decisions
==================================================

🤖 AI Decision: build_tower (archer_rush_build)
  ✅ Built archer tower at spot 2
🤖 AI Decision: build_tower (archer_rush_build)
  ✅ Built archer tower at spot 1
🤖 AI Decision: upgrade_tower (archer_rush_upgrade)
  ✅ Upgraded tower to level 2
```

**In the Game:**
- Towers will be built automatically
- Upgrades will happen automatically
- AI follows the strategy you selected

## Step 6: View Results

When the game ends, you'll see:

```
==================================================
🏁 GAME ENDED
==================================================
   AI made 15 decisions
   Result: victory
   Stars: 3
   Lives remaining: 18
   Duration: 180.5s
==================================================
```

**That's it! The AI is now playing your game!** 🎉

---

# METHOD 2: Manual Code Setup (5 Minutes)

If you want more control, you can add AI directly via code.

## Step 1: Create AI Initialization Script

Create a new script in your level's **script** (e.g., `level_controller.gd` or create a new one):

```gdscript
# Add to your level's _ready() function

extends Node2D

func _ready():
	# Wait for level to fully load
	await get_tree().process_frame
	await get_tree().process_frame

	# Setup AI
	_setup_ai()

func _setup_ai():
	"""Initialize AI to play the level"""
	print("🤖 Setting up AI player...")

	# Create AI controller
	var ai = preload("res://scripts/ai/ai_controller.gd").new()
	ai.name = "AIController"
	add_child(ai)

	# Choose strategy
	ai.set_strategy("Archer Rush")  # Change this to test different strategies!

	# Initialize (this analyzes map and starts decision-making)
	await ai.initialize()

	print("✅ AI initialized and playing!")
```

## Step 2: Run Your Level

1. Press **F5** (or F6 to run current scene)
2. AI will play automatically
3. Watch console for decision logs

---

# METHOD 3: Godot Editor Setup (Visual)

For those who prefer using the Godot editor completely.

## Step 1: Open Level Scene

`scenes/levels/level_01.tscn` in Godot editor

## Step 2: Scene Tree Structure

Your scene should look like this:

```
TestLevel (Node2D) ← Root
├─ WaveManager (Node2D)
├─ Camera2D
├─ EnemyPath (Path2D)
├─ UI (CanvasLayer)
├─ PlacementManager (Node2D)
├─ TowerSpots (Node2D)
│  ├─ TowerSpot1
│  ├─ TowerSpot2
│  ├─ TowerSpot3
│  └─ TowerSpot4
├─ HeroManager (Node2D)
├─ HeroSpots (Node2D)
└─ AITest (Node) ← ADD THIS
```

## Step 3: Add AITest Node

**Detailed Instructions:**

1. Click **TestLevel** in Scene Tree
2. Click **+** icon (or right-click → Add Child Node)
3. In the "Create New Node" dialog:
   - Search: `Node`
   - Select: **Node** (basic node type)
   - Click **Create**
4. Rename to `AITest`:
   - Right-click the new node
   - Select **Rename**
   - Type `AITest`
   - Press Enter

## Step 4: Attach Script

**Method A: Load Existing Script**
1. Select **AITest** node
2. Inspector panel → **Script** section
3. Click folder icon next to **Script:** field
4. Navigate: `res://scripts/ai/ai_test_simple.gd`
5. Click **Open**

**Method B: Drag & Drop**
1. FileSystem panel (bottom-left)
2. Navigate: `scripts/ai/ai_test_simple.gd`
3. **Drag** file onto **AITest** node
4. Release mouse

## Step 5: Configure in Inspector

With **AITest** selected, Inspector shows:

```
Node
├─ Name: AITest
└─ Transform: (default)

Script
├─ Script: res://scripts/ai/ai_test_simple.gd
│
└─ Script Variables:
    ├─ Strategy: [Text Field]
    │  └─ "Archer Rush" ← Type here
    │
    └─ Show Debug Info: [Checkbox]
       └─ ✓ Enabled
```

**To Change Strategy:**
1. Click in **Strategy** text field
2. Delete current text
3. Type one of:
   - `Archer Rush`
   - `Soldier Wall`
   - `Greedy Economy`
4. Press Enter

## Step 6: Save Scene

- **Ctrl+S** (Windows/Linux)
- **Cmd+S** (Mac)

Or: **Scene menu → Save Scene**

## Step 7: Test Run

### Run Project:
- Press **F5**
- Or: Click **▶** button (top-right)

### Run Current Scene:
- Press **F6**
- Or: Click **📁▶** button (top-right)

---

# Testing & Verification

## How to Confirm AI is Working

### ✅ **Console Output Checklist**

When you run the game, you should see:

```
✅ "🤖 SIMPLE AI TEST STARTING"
✅ "AIController initialized"
✅ "Strategy set to: Archer Rush"
✅ "Tower spots found: 4"
✅ "Path found: Yes"
✅ "AI IS NOW PLAYING!"
```

If you see all of these → AI is working!

### ✅ **Visual Checklist**

Watch the game and confirm:

1. **Towers Build Automatically** (no clicks needed)
   - Towers appear on spots without you clicking
   - Usually starts building around wave 1-2

2. **Upgrades Happen Automatically**
   - Tower visuals change (bigger, different color)
   - Console shows "Upgraded tower to level X"

3. **AI Makes Decisions Every ~0.5 Seconds**
   - Console shows "AI Decision:" messages
   - Each message shows action and reason

### ✅ **Decision Log Example**

You should see messages like:

```
🤖 AI Decision: build_tower (archer_rush_build)
  ✅ Built archer tower at spot 2

🤖 AI Decision: build_tower (archer_rush_build)
  ✅ Built archer tower at spot 1

🤖 AI Decision: wait (saving_gold)

🤖 AI Decision: upgrade_tower (archer_rush_upgrade)
  ✅ Upgraded tower to level 2

🤖 AI Decision: choose_damage_path (archer_rush_damage_focus)
  ✅ Chose damage path
```

---

# Troubleshooting

## ❌ Problem: "AIController initialized" never appears

**Cause**: Script not attached correctly

**Fix**:
1. Select AITest node
2. Inspector → Script section
3. Verify `res://scripts/ai/ai_test_simple.gd` is loaded
4. If not, click folder icon and load it

---

## ❌ Problem: "Tower spots found: 0"

**Cause**: Tower spots not in correct group

**Fix**:
1. Select each TowerSpot in Scene Tree
2. Inspector → Node tab (top-right)
3. Find **Groups** section
4. Add to group: `tower_spot`
5. Click **Add**

---

## ❌ Problem: "Path found: No"

**Cause**: Enemy path not in correct group

**Fix**:
1. Select **EnemyPath** node
2. Inspector → Node tab
3. Groups section
4. Add to group: `enemy_path`
5. Save scene

---

## ❌ Problem: "AI Decision: build_tower" but nothing happens

**Cause**: Tower scene path incorrect

**Fix**: Check console for exact error. Likely one of:

1. **"Tower scene not found"**
   - AI looks for: `res://scenes/towers/archer_tower.tscn`
   - Verify this file exists
   - If named differently, update path in ai_controller.gd line ~500

2. **"Not enough gold"**
   - AI tried to build but no gold available
   - This is normal, AI will wait and try later

3. **"Invalid spot"**
   - Tower spot node is invalid
   - Usually fixes itself next frame

---

## ❌ Problem: AI builds but never upgrades

**Cause**: Tower doesn't have upgrade methods

**Fix**:
1. Open your tower script (e.g., `archer_tower.gd`)
2. Verify it has these methods:
   ```gdscript
   func can_upgrade() -> bool:
       return tower_level < 3  # Or your max level

   func upgrade_tower() -> bool:
       # Your upgrade logic
       return true
   ```

---

## ❌ Problem: Game runs too slow/fast

**Fix**: Adjust time scale in AI test script

Edit `ai_test_simple.gd`, add this to `_ready()`:

```gdscript
func _ready():
	# ... existing code ...

	# Set game speed
	Engine.time_scale = 1.0  # Normal speed
	# Engine.time_scale = 2.0  # 2x speed
	# Engine.time_scale = 0.5  # Half speed (slow-mo)
```

---

## ❌ Problem: "Class AIController not found"

**Cause**: AIController script not recognized as class

**Fix**:
1. Open `scripts/ai/ai_controller.gd`
2. Verify first line is:
   ```gdscript
   extends Node
   class_name AIController
   ```
3. **Important**: Save the file
4. **Important**: Restart Godot editor (File → Quit)
5. Reopen project

**Why**: Godot caches class names, restart refreshes them

---

# Quick Reference

## File Locations

```
Your Project/
├─ scenes/levels/
│  └─ level_01.tscn ← Add AITest node here
│
├─ scripts/ai/
│  ├─ ai_controller.gd ← Core AI brain
│  └─ ai_test_simple.gd ← Simple test wrapper
│
└─ docs/
   └─ AI_SETUP_GUIDE.md ← This file
```

## Strategy Comparison

| Strategy       | Play Style | Best For Testing |
|----------------|------------|------------------|
| Archer Rush    | Aggressive, builds fast | Tower DPS balance |
| Soldier Wall   | Defensive, blocking | Enemy difficulty |
| Greedy Economy | Conservative, upgrades | Economy balance |

## Console Commands Checklist

✅ Should see:
- "🤖 SIMPLE AI TEST STARTING"
- "Strategy set to: [name]"
- "Tower spots found: [number]"
- "AI IS NOW PLAYING!"
- "AI Decision: [action]"

❌ Should NOT see:
- Errors about missing files
- "Tower spots found: 0" (unless level has no spots)
- Lua/Python errors (wrong language!)

---

# Next Steps

Once AI is working:

1. **Try Different Strategies**
   - Change `strategy` in Inspector
   - Run game multiple times
   - See which strategy wins

2. **Watch AI Decisions**
   - Read console logs
   - Understand why AI builds where it does
   - See if AI choices make sense

3. **Collect Data**
   - Run game 3-5 times per strategy
   - Note win rate
   - Note which towers AI uses most

4. **Manual Balance Testing**
   - If AI wins 100% → Level too easy
   - If AI loses 100% → Level too hard
   - If AI wins ~50-70% → Good balance!

5. **Ready for Automation**
   - Once manual testing works
   - Move to auto-playtest runner (next phase)
   - Run 100+ games automatically

---

# Example: Complete Setup Session

Here's what a successful first-time setup looks like:

```
TIME: 0:00 - Open Godot
TIME: 0:15 - Open level_01.tscn
TIME: 0:30 - Add Node, rename to AITest
TIME: 1:00 - Attach ai_test_simple.gd script
TIME: 1:30 - Set strategy to "Archer Rush"
TIME: 1:45 - Save scene (Ctrl+S)
TIME: 2:00 - Press F5 to run

CONSOLE OUTPUT:
==================================================
🤖 SIMPLE AI TEST STARTING
==================================================
AIController initialized
Strategy set to: Archer Rush
Tower spots found: 4
Path found: Yes
✅ AI IS NOW PLAYING!
==================================================

🤖 AI Decision: build_tower (archer_rush_build)
  ✅ Built archer tower at spot 2

[Game plays automatically...]

==================================================
🏁 GAME ENDED
==================================================
   Result: victory
   Stars: 2
   Lives remaining: 15
   Duration: 210.5s
==================================================

TIME: 5:30 - Game finished
✅ SUCCESS! AI played and won!
```

---

# Support

If you still have issues:

1. **Check Console First**
   - Look for red error messages
   - Copy exact error text

2. **Verify Files Exist**
   ```
   ✓ scripts/ai/ai_controller.gd
   ✓ scripts/ai/ai_test_simple.gd
   ✓ scenes/levels/level_01.tscn
   ```

3. **Common Fixes**
   - Restart Godot editor
   - Re-save all scenes
   - Verify tower/enemy scenes exist

4. **Test Basic Level First**
   - Make sure level works without AI
   - Run manually and complete a wave
   - Then add AI

---

**Last Updated**: 2025-10-21
**Tested On**: Godot 4.x
**Difficulty**: Beginner-Friendly ⭐
