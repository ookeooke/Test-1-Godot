# AI Playtest System - Implementation Status

## Overview

This document tracks the implementation of an AI system that automatically plays your tower defense game to analyze balance and gameplay strategies.

## ✅ Completed Components

### 1. AI Controller (`scripts/ai/ai_controller.gd`)

**Status**: IMPLEMENTED ✅

The core AI brain that makes decisions and executes actions.

**Features**:
- Game state observation (gold, lives, enemies, waves, tower spots)
- Map analysis and strategic spot evaluation
- 3 distinct strategies implemented
- Decision-making based on game state
- Action execution (build/upgrade towers)
- Decision logging for analytics

**Strategies Implemented**:

#### Strategy 1: Archer Rush (Aggressive)
- Always builds archers when gold available
- Upgrades frontline towers first
- Chooses damage path at level 3
- Prioritizes fast expansion

#### Strategy 2: Soldier Wall (Defensive)
- Builds 3 soldier towers first for blocking
- Fills remaining spots with archers for support
- Upgrades soldiers first for tankiness
- Creates defensive formation

#### Strategy 3: Greedy Economy (Conservative)
- Waits until wave 3 before building
- Emergency defense if enemies get close
- Only builds with excess gold (>200g)
- Heavily invests in upgrades for maximum value

**Usage Example**:
```gdscript
# Create and initialize AI
var ai = AIController.new()
add_child(ai)
ai.set_strategy("Archer Rush")  # or "Soldier Wall" or "Greedy Economy"
await ai.initialize()

# AI will automatically:
# - Analyze the map
# - Make decisions every 0.5 seconds
# - Build towers, upgrade them, choose paths
# - Log all decisions for later analysis
```

**Strategic Features**:
- **Map Discovery**: Automatically finds all tower spots and enemy paths
- **Spot Evaluation**: Calculates strategic value (0.0-1.0) based on:
  - Path coverage (40% weight)
  - Distance to exit/frontline (30% weight)
  - Early damage potential (20% weight)
  - Chokepoint detection (10% bonus)
- **Smart Decision-Making**: Different logic per strategy with priority rules

---

### 2. BalanceTracker Extension

**Status**: EXTENDED ✅

Your existing `BalanceTracker` has been enhanced with AI-specific logging.

**New Features Added**:

```gdscript
# AI decision logging
BalanceTracker.record_ai_decision(action, target, reason, gold_before)

# Tower placement heatmap data
BalanceTracker.record_tower_placement_position(position, tower_type)
```

**New Data Tracked**:
- `ai_decision_log`: Array of all AI decisions with timestamps
- `tower_placement_positions`: Array of tower positions for heatmap generation

**Decision Log Format**:
```json
{
  "time": 12.5,           // Seconds since run start
  "wave": 3,              // Current wave number
  "action": "build_tower", // Action taken
  "target": 2,            // Spot index or tower ID
  "reason": "archer_rush_build", // Why AI made this decision
  "gold_before": 150,     // Gold before action
  "gold_after": 50        // Gold after action
}
```

**Integration**:
- No changes needed to existing BalanceTracker code
- All your existing tracking (towers, enemies, waves, economy) still works
- AI data is additive, not disruptive

---

## 🚧 In Progress

### 3. Auto-Playtest Runner

**Status**: IN PROGRESS 🔨

This system will automate running hundreds of games.

**Planned Features**:
- Load level → Run AI → Record results → Repeat
- Headless mode for 10x-50x speed
- Progress tracking
- Crash recovery
- Timeout protection

**Planned Usage**:
```gdscript
var runner = AutoPlaytester.new()
runner.run_mass_playtest({
  "strategy": "Archer Rush",
  "runs": 100,
  "level": "level_01",
  "headless": true,
  "speed_multiplier": 10.0
})

# Output: 100 games completed in ~30 minutes
# Data saved to user://ai_results/
```

---

## 📋 Planned Components

### 4. AI Control Panel UI

**Status**: PLANNED 📝

In-game visual control interface.

**Planned Features**:
- Dropdown to select strategy
- Slider for number of runs
- Speed control (1x to 50x)
- Real-time progress bar
- Live stats display (wins, losses, current game)
- Export button

**Access**: Press F9 to open panel

---

### 5. Analytics System

**Status**: PLANNED 📝

Data aggregation and visualization.

**Planned Outputs**:

#### Win Rate Analysis
```
Strategy        | Wins  | Win % | Avg Stars | Avg Lives
Archer Rush     | 87/100| 87%   | 2.3       | 14.2
Soldier Wall    | 62/100| 62%   | 1.8       | 8.1
Greedy Economy  | 91/100| 91%   | 2.7       | 15.3
```

#### Tower Placement Heatmap
- Visual map showing which spots are used most
- Color-coded by usage frequency
- PNG image output

#### Wave Difficulty Curve
```
Wave | Lives Lost | Win Rate | Enemy Count
1    | 0.2        | 100%     | 8
2    | 0.5        | 100%     | 12
3    | 1.8        | 98%      | 15
4    | 3.2        | 92%      | 18  ← SPIKE!
5    | 1.1        | 95%      | 12
```

#### Tower Effectiveness
```
Tower Type    | Avg Kills | Gold Efficiency | Usage %
Archer L1     | 8.2       | 0.82 kills/gold | 100%
Archer L2     | 14.5      | 0.79 kills/gold | 85%
Soldier L1    | 12.3      | 0.41 kills/gold | 40%
```

---

### 6. Console Commands

**Status**: PLANNED 📝

Quick command-line interface for power users.

**Planned Commands**:
```
ai_test archer_rush          # Single test with strategy
ai_test greedy_economy 100   # 100 runs
ai_mass_test 50              # All strategies, 50 each
ai_visual archer_rush        # Watch AI play (slow)
ai_speed 10                  # Set speed multiplier
ai_stats                     # Show current stats
ai_export                    # Export last results
```

---

### 7. Configuration File

**Status**: PLANNED 📝

JSON config for batch testing.

**Example**:
```json
{
  "strategies": [
    {
      "name": "Archer Rush",
      "enabled": true,
      "runs": 100
    },
    {
      "name": "Soldier Wall",
      "enabled": true,
      "runs": 100
    }
  ],
  "execution": {
    "headless_mode": true,
    "time_scale": 10.0,
    "auto_export": true
  },
  "levels": [
    {
      "level_id": "level_01",
      "enabled": true
    }
  ]
}
```

---

## How to Use (Current State)

### Quick Test (Manual)

1. Open your level scene
2. Add an AIController node:
   ```gdscript
   var ai = preload("res://scripts/ai/ai_controller.gd").new()
   add_child(ai)
   ai.set_strategy("Archer Rush")
   await ai.initialize()
   ```
3. Run the game
4. AI will play automatically
5. Check console for decision logs

### Data Collection

AI decisions are automatically logged via BalanceTracker. After the game ends:

```gdscript
var run_data = BalanceTracker.get_current_run_data()

# Contains:
# - All tower placements, upgrades, kills
# - All enemy spawns, deaths, leaks
# - All wave timing and gold flow
# - ALL AI DECISIONS with reasoning

# Export to file
var file = FileAccess.open("user://ai_test_run.json", FileAccess.WRITE)
file.store_string(JSON.stringify(run_data, "\t"))
file.close()
```

---

## Technical Architecture

### Data Flow

```
Game Start
  ↓
AI Controller.initialize()
  ├─ Find managers (WaveManager, PlacementManager)
  ├─ Analyze map (tower spots, enemy path)
  └─ Calculate strategic values
  ↓
Game Loop (every 0.5s)
  ├─ observe_state() → Get gold, lives, enemies, spots
  ├─ make_decision(state) → Apply strategy rules
  ├─ execute_decision() → Build/upgrade towers
  └─ _record_decision() → Log to BalanceTracker
  ↓
Game End
  ├─ BalanceTracker.end_run(result, stars)
  └─ Data includes: towers, enemies, waves, AI decisions
```

### Strategy Decision Tree Example (Archer Rush)

```
IF gold >= 100 AND empty_spot_exists:
  → Build archer at highest-value spot

ELSE IF gold >= 80 AND wave >= 2:
  → Upgrade frontline tower

ELSE IF tower_level == 3:
  → Choose damage path

ELSE:
  → Wait (save gold)
```

---

## Next Steps

To complete the system:

1. **Auto-Playtest Runner** (next priority)
   - Game loop automation
   - Headless mode implementation
   - Progress tracking

2. **Simple Control Script**
   - Command-line test runner
   - No UI needed for first version

3. **Basic Analytics**
   - Win rate calculator
   - CSV export of results
   - Simple stats summary

4. **Visual UI** (later)
   - Control panel
   - Live stats display
   - Heatmap visualization

---

## Performance Expectations

### Normal Mode (No Speed-Up)
- 1 game: 3-5 minutes
- 100 games: 5-8 hours
- Visual feedback available

### Headless Mode (10x speed)
- 1 game: 20-30 seconds
- 100 games: 30-50 minutes
- No visual rendering

### Headless Mode (50x speed - aggressive)
- 1 game: 4-6 seconds
- 100 games: 7-10 minutes
- Maximum performance

---

## Balance Insights You'll Get

After running 300 games (100 per strategy):

### 1. Tower Balance
- Which towers are too strong? (high win rate correlation)
- Which are too weak? (never used by AI)
- Upgrade value analysis (is Level 4 worth 150g?)

### 2. Level Difficulty
- Is level too easy? (all strategies win >90%)
- Is level too hard? (all strategies win <10%)
- Wave spikes (which waves cause most deaths?)

### 3. Economy Balance
- Starting gold optimal? (AI always has excess vs. always broke)
- Tower costs fair? (gold efficiency metrics)
- Income rate appropriate? (leftover gold analysis)

### 4. Strategic Depth
- Multiple viable strategies? (win rates similar)
- Dominant strategy exists? (one strategy dominates all others)
- Skill expression possible? (difference between strategies)

---

## File Structure

```
Test-1-Godot/
├─ scripts/
│  └─ ai/
│     ├─ ai_controller.gd       ✅ DONE - Core AI brain
│     ├─ ai_autorun.gd          🚧 IN PROGRESS - Test automation
│     ├─ ai_analytics.gd        📝 PLANNED - Data analysis
│     └─ ai_console.gd          📝 PLANNED - Console commands
│
├─ scripts/debug/
│  └─ balance_tracker.gd        ✅ EXTENDED - AI logging added
│
├─ scenes/ui/
│  └─ ai_control_panel.tscn     📝 PLANNED - Control UI
│
├─ data/
│  ├─ ai_config.json            📝 PLANNED - Configuration
│  └─ ai_results/               📝 AUTO-CREATED - Test outputs
│
└─ docs/
   ├─ AI_PLAYTEST_SYSTEM.md     ✅ THIS FILE
   └─ AI_USAGE_GUIDE.md          📝 PLANNED - User manual
```

---

## Credits

Built using:
- **Godot RL Agents** research (inspiration)
- **Kingdom Rush / Bloons TD** methodologies (industry standard)
- **PPO algorithm** concepts (academic research)
- **Your existing BalanceTracker** (foundation)

---

## Support

For questions or issues:
1. Check console logs for AI decision reasoning
2. Review BalanceTracker data exports
3. Test with visual mode first (ai_visual command)
4. Verify tower/enemy scenes load correctly

---

**Last Updated**: 2025-10-21
**Version**: 1.0 (Core systems completed)
**Status**: Ready for testing (manual mode) | Auto-runner in development
