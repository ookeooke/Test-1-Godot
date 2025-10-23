# **AI Learning System - Implementation Plan**

## **Overview**

Your AI is currently **rule-based** (follows fixed strategies). This document explains **3 different approaches** to make the AI "learn" and improve over time.

---

## **PART 1: Current AI Capabilities**

### **What the AI Can Do NOW:**
✅ Plays levels automatically (level 1 → level 2 → level 3...)
✅ Builds towers based on strategy rules
✅ Upgrades towers and chooses paths
✅ Positions heroes strategically
✅ Records all decisions in BalanceTracker

### **Current Limitations:**
❌ Doesn't learn from mistakes
❌ Always builds ALL towers immediately (wastes gold)
❌ Uses same strategy every time
❌ Doesn't discover new tactics

---

## **PART 2: Three Approaches to Make AI Learn**

### **Option A: Analytics-Based Improvement** ⭐ RECOMMENDED
**Difficulty:** Easy
**Time:** 2-4 hours
**Type:** You analyze data, then manually improve AI rules

#### **How It Works:**
1. AI plays 100+ games automatically
2. System records:
   - Tower placement heatmaps (which spots win most?)
   - Hero position success rates
   - Gold efficiency (spending vs waste)
   - Win rate per strategy
3. YOU analyze the data
4. YOU update AI rules based on findings

#### **Example:**
```
DATA SHOWS:
- Spot 2 has 85% win rate
- Spot 0 has 45% win rate
- Building all 4 towers immediately = 60% win rate
- Building 2 towers, then upgrading = 75% win rate

YOU CHANGE RULES:
- Prioritize Spot 2 first
- Build only 2 towers early, save gold for upgrades
```

#### **Implementation Steps:**
1. **Run AI 100+ times** (already working!)
2. **Export data** from BalanceTracker (already exists!)
3. **Create analytics viewer** - graphs, heatmaps, tables
4. **YOU analyze** and find patterns
5. **YOU edit ai_controller.gd** with better rules

#### **Pros:**
- ✅ Simple to implement
- ✅ You understand WHY changes work
- ✅ Predictable results
- ✅ Works with existing BalanceTracker

#### **Cons:**
- ❌ AI doesn't improve automatically
- ❌ Requires manual analysis

---

### **Option B: Genetic Algorithm** 🧬
**Difficulty:** Medium
**Time:** 1-2 days
**Type:** AI evolves strategies through "natural selection"

#### **How It Works:**
1. Create 50 AI variants with randomized parameters:
   - AI #1: Build 2 towers early, prioritize upgrades
   - AI #2: Build 4 towers early, minimal upgrades
   - AI #3: Build 1 tower, heavy hero focus
   - etc.

2. Let all 50 AIs play the game
3. Rank them by win rate
4. Top 10 "breed" to create new generation:
   - Take traits from AI #1 + AI #5 = New AI #51
   - Mutate some parameters randomly

5. Repeat for 100 generations
6. Best AI emerges!

#### **Parameters to Evolve:**
```gdscript
class AIGenome:
    var early_tower_count: int = 2  # How many towers to build early?
    var upgrade_threshold: int = 150  # When to start upgrading?
    var hero_aggression: float = 0.6  # How far forward to position hero?
    var tower_priority: Array = [1, 0, 2, 3]  # Which spots to build first?
    var path_choice: String = "damage"  # Damage or range path?
```

#### **Implementation Steps:**
1. Create `AIGenome` class (parameters above)
2. Create population of 50 genomes
3. Run games in parallel (fast!)
4. Rank by fitness (win rate, lives remaining)
5. Crossover + mutation
6. Repeat 100 generations

#### **Pros:**
- ✅ AI discovers NEW strategies you didn't think of
- ✅ Fully automatic improvement
- ✅ Fun to watch evolution happen

#### **Cons:**
- ❌ Takes 500-5000 games to converge
- ❌ May find "cheese" strategies (exploits)
- ❌ Results can be unpredictable

---

### **Option C: Machine Learning (Reinforcement Learning)** 🤖
**Difficulty:** HARD
**Time:** 1-4 weeks
**Type:** Neural network learns to play

#### **How It Works:**
1. Use Godot RL Agents framework
2. Train neural network with PPO algorithm
3. Network learns: "If I see enemies here, build tower there"
4. Requires 10,000-100,000 games to train
5. Network discovers optimal strategy

#### **What It Learns:**
- When to build towers vs upgrade
- Best tower placements
- Hero positioning
- Resource management

#### **Implementation:**
- Install Godot RL Agents
- Define observation space (game state)
- Define action space (build, upgrade, move hero)
- Define reward function (win = +1000, life lost = -50, etc.)
- Train for days/weeks

#### **Pros:**
- ✅ Can discover superhuman strategies
- ✅ Adapts to game changes automatically
- ✅ Research-grade AI

#### **Cons:**
- ❌ Extremely complex to set up
- ❌ Training takes days/weeks
- ❌ Requires powerful GPU
- ❌ Hard to understand WHY it works
- ❌ May not work at all if badly configured

---

## **PART 3: Quick Fix - Improve Tower Placement**

### **Problem:**
AI builds ALL towers immediately, wasting gold that could be used for upgrades.

### **Solution:**
Add "wave-based" building logic:

```gdscript
func _decide_archer_rush(state: Dictionary) -> Dictionary:
    # Count existing towers
    var tower_count = _count_all_towers(state.tower_spots)

    # RULE: Build towers based on wave number
    var desired_towers = min(state.wave, 4)  # Wave 1 = 1 tower, Wave 2 = 2 towers, etc.

    # RULE 2: Build if we need more towers
    if tower_count < desired_towers and state.gold >= 100:
        var best_spot = _find_best_empty_spot(state.tower_spots)
        if best_spot:
            return {
                "action": "build_tower",
                "tower_type": "archer",
                "spot": best_spot,
                "reason": "wave_based_expansion"
            }

    # RULE 3: Otherwise prioritize upgrades
    if state.gold >= 80:
        var tower = _find_tower_to_upgrade(state.tower_spots)
        if tower:
            return {"action": "upgrade_tower", "tower": tower}

    return {"action": "wait", "reason": "saving_gold"}
```

**Result:**
- Wave 1: Build 1 tower only
- Wave 2: Build 2nd tower
- Wave 3: Build 3rd tower
- Wave 4+: All towers built, focus on upgrades

---

## **PART 4: Hero Learning - Best Positions**

### **Problem:**
AI always puts hero at "60% along path" - but is that optimal?

### **Solution (Analytics Approach):**

1. **Collect data** from 100+ games:
```gdscript
# In BalanceTracker:
func record_hero_position_success(hero_pos: Vector2, wave_survived: bool):
    hero_position_data.append({
        "position": hero_pos,
        "survived": wave_survived,
        "lives_remaining": GameStateManager.lives
    })
```

2. **Analyze** which positions have highest survival rate:
```
RESULTS:
- Position (1071, 116) = 75% survival, avg 15 lives
- Position (800, 300) = 85% survival, avg 17 lives  ← BETTER!
- Position (1200, 50) = 50% survival, avg 10 lives
```

3. **Update AI** to use better position:
```gdscript
func _get_optimal_hero_position(hero: Node2D) -> Vector2:
    # OLD: 60% along path
    # NEW: Data-driven position
    return Vector2(800, 300)  # Best position from analytics
```

---

## **PART 5: Recommendations**

### **For Quick Results (Today):**
1. ✅ **Fix tower placement** - Use wave-based building (see PART 3)
2. ✅ **Run 10 games** manually and watch - note what fails
3. ✅ **Adjust AI rules** based on observations

### **For Data-Driven Improvement (This Week):**
1. ✅ **Implement Option A (Analytics)**
2. Run AI 100 times overnight
3. Create simple analytics viewer
4. Update rules based on data

### **For Automatic Learning (Next Month):**
1. ✅ **Implement Option B (Genetic Algorithm)**
2. Let it run for 1000+ games
3. Watch strategies evolve
4. Use best genome as new AI

### **For Research Project (Long Term):**
1. Learn about reinforcement learning
2. Implement Option C (ML)
3. Train for weeks
4. Publish results!

---

## **Next Steps**

**What should I implement first?**

1. **Quick fix** → Wave-based tower building (5 minutes)
2. **Analytics system** → Data viewer for BalanceTracker (2 hours)
3. **Genetic algorithm** → Evolving AI (1 day)
4. **Machine learning** → RL training (weeks)

Let me know which approach you want to try!
