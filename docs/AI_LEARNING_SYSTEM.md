# 🧠 AI Learning System - User Guide

## What It Does

The AI Learning System plays **Level 1 hundreds of times** with different strategies to discover:
- **Best hero positions** (frontline vs backline)
- **Best tower placements** (early path vs late path)
- **Best upgrade strategies** (rush upgrades vs save gold)
- **Balance issues** (level too easy/hard)

After all games complete, it generates a **detailed report** with:
- ✅ Best strategies discovered
- ✅ Win rates for each approach
- ✅ AI suggestions for balance improvements

## How to Use

### Option 1: Learning Mode (100+ games)

1. Open `scenes/levels/level_01.tscn` in Godot
2. Find the `AILearning` node in the scene tree
3. Set `total_games_to_play` to desired number (default: 100)
4. Set `show_progress` to `true` to see updates
5. Press **F5** to run the level
6. **Wait** - it will play automatically (may take 10-30 minutes for 100 games)
7. Check console for final report
8. Find detailed report in: `AppData/Roaming/Godot/app_userdata/Test 1/balance_debug/exports/AI_LEARNING_REPORT_*.txt`

### Option 2: Single Game Test Mode

1. Open `scenes/levels/level_01.tscn`
2. Find the `AILearning` node
3. Set `total_games_to_play` to `1` (this disables learning mode)
4. Press **F5**
5. AI will play level once with default strategy

### Option 3: Quick Test (No Learning)

1. Delete or disable the `AILearning` node
2. The `AITest` node will activate automatically
3. AI plays with fixed "Archer Rush" strategy

## Configuration

### AILearning Node Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `total_games_to_play` | 100 | How many times to replay Level 1 |
| `show_progress` | true | Show progress updates every 10 games |

**Recommended settings:**
- **Quick test**: 10 games (~2-3 minutes)
- **Normal learning**: 50-100 games (~10-20 minutes)
- **Deep learning**: 200+ games (~40+ minutes)

## What the AI Tests

### Hero Positions
- **20%** along path (defensive, near exit)
- **30%** along path
- **40%** along path (midline)
- **50%** along path
- **60%** along path
- **70%** along path (aggressive, frontline)
- **80%** along path (very aggressive)

### Tower Strategies
- **Frontload**: Build towers at path start
- **Backload**: Build towers at path end
- **Center Focus**: Build towers at path middle
- **Balanced**: Use default coverage calculation

### Upgrade Strategies
- **Rush to 4**: Upgrade towers to level 4 quickly
- **Balanced**: Mix of building and upgrading
- **Save for Quality**: Build fewer, upgrade more

## Understanding the Report

### Example Output

```
🏆 BEST STRATEGY DISCOVERED
Hero Position: 60% along path (frontline)
Tower Focus: frontload
Upgrade Strategy: balanced
Path Choice: damage

Performance:
  - Win Rate: 95.0% (19/20 games)
  - Average Lives Remaining: 16.8

🦸 HERO POSITION ANALYSIS
Best Position: 60% along path (95.0% win rate)

All Positions Tested:
  20%: 5 wins/12 games (41.7% WR, 8.2 avg lives) ← Too defensive
  40%: 8 wins/15 games (53.3% WR, 12.1 avg lives)
  60%: 19 wins/20 games (95.0% WR, 16.8 avg lives) ← BEST
  80%: 3 wins/10 games (30.0% WR, 5.4 avg lives) ← Too aggressive

💡 AI BALANCE SUGGESTIONS
🦸 Hero performs best in AGGRESSIVE position (60% along path)
   This suggests hero damage is very effective
   Consider: Reduce hero damage or increase enemy HP

🏰 Early tower placement is most effective
   This suggests enemies need more HP in later waves
```

### What to Look For

**If win rate > 95%:**
- ⚠️ Level is TOO EASY
- Fix: Increase enemy HP, add more enemies, or reduce starting gold

**If win rate < 50%:**
- ⚠️ Level is TOO HARD
- Fix: Reduce enemy HP, give more starting gold, or add more tower spots

**If hero works best at frontline (>60%):**
- Hero is too strong
- Consider: Reduce hero damage or range

**If hero works best at backline (<30%):**
- Enemies are too strong early
- Consider: Reduce early wave difficulty

## File Outputs

After learning completes, you'll find:

### 1. AI Learning Report (TXT)
**Location**: `AppData/Roaming/Godot/app_userdata/Test 1/balance_debug/exports/AI_LEARNING_REPORT_*.txt`

**Contains:**
- Best strategy summary
- Hero position analysis
- Tower strategy analysis
- AI balance suggestions

### 2. Raw Learning Data (JSON)
**Location**: `AppData/Roaming/Godot/app_userdata/Test 1/balance_debug/exports/AI_LEARNING_DATA_*.json`

**Contains:**
- Every game result
- All strategies tested
- Performance statistics
- Can be imported into Excel/Python for custom analysis

## Tips

1. **Start with 10 games** to test the system works
2. **Run 100+ games** overnight for deep analysis
3. **Compare reports** before/after balance changes
4. **Adjust level based on suggestions**, then re-run learning
5. **Check raw JSON** if you want to do custom data analysis

## Troubleshooting

**Learning system doesn't start:**
- Check that `AILearning` node has `total_games_to_play > 1`
- Make sure `AITest` node is disabled or detects learning mode

**Games run too slow:**
- Press **1, 2, 3, or 4** during gameplay to speed up (1x, 2x, 4x, 8x)
- Reduce `total_games_to_play` for faster results

**No report generated:**
- Check console for errors
- Verify `BalanceExporter` autoload exists
- Check export folder permissions

**AI plays poorly:**
- This is expected! AI tests random strategies
- Some will fail - that's how it learns what doesn't work
- Focus on the final report, not individual games

## Example Use Case

**Problem**: You think Level 1 might be too easy

**Solution**:
1. Run AI Learning with 100 games
2. Check report - finds 98% win rate
3. Report suggests: "Level too easy - increase enemy HP"
4. Increase goblin HP from 40 to 60
5. Run AI Learning again with 100 games
6. Check new report - finds 75% win rate ✅
7. Level is now balanced!

## Next Steps

After using the learning system:
1. **Read the AI suggestions** in the report
2. **Make balance changes** based on data
3. **Re-run learning** to verify improvements
4. **Iterate** until win rate is 60-80% (sweet spot for tower defense)

---

**Need help?** Check the console output for detailed progress and error messages.
