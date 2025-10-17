# 30 Level Workflow Guide

Complete workflow for creating and managing 30 unique tower defense levels.

---

## 🎯 Overview

You now have a **world-based structure** for 30 levels:
- **Forest Campaign** (10 levels) - Tutorial & Learning
- **Desert Campaign** (10 levels) - Challenge Mode
- **Mountains Campaign** (10 levels) - Expert Mode

Each level has **unique enemy compositions** managed through `.tres` resource files.

---

## 📂 Current Structure

```
data/
├── levels/
│   ├── forest/
│   │   ├── forest_01/waves/          ✅ DONE (10 waves)
│   │   ├── forest_02/waves/          ✅ DONE (10 waves)
│   │   ├── forest_03/waves/          ⬜ TODO
│   │   └── ... (forest_04 to forest_10)
│   ├── desert/
│   │   ├── desert_01/waves/          ⬜ TODO
│   │   └── ... (desert_02 to desert_10)
│   └── mountains/
│       ├── mountain_01/waves/        ⬜ TODO
│       └── ... (mountain_02 to mountain_10)
│
├── level_configs/
│   ├── forest/
│   │   ├── forest_01_config.tres     ✅ DONE
│   │   ├── forest_02_config.tres     ✅ DONE
│   │   └── ... (forest_03 to forest_10)
│   ├── desert/
│   └── mountains/
│
└── campaigns/
    ├── forest_campaign.tres          ✅ DONE (2 levels added)
    ├── desert_campaign.tres          ✅ DONE (empty, ready for levels)
    └── mountains_campaign.tres       ✅ DONE (empty, ready for levels)
```

---

## 🔄 Workflow: Creating a New Level

### **Step 1: Plan the Level (5-10 minutes)**

Open `LEVEL_PLANNING_TEMPLATE.md` and design your waves:

```markdown
### Forest 03 - "Goblin Stronghold"
- Difficulty: 2/10
- Starting Gold: 110 | Lives: 20

| Wave | Composition | Count |
|------|-------------|-------|
| 1    | 10G         | 10    |
| 2    | 8G + 6W     | 14    |
| ...  | ...         | ...   |
| 10   | 1T + 20G    | 21    |
```

**Planning Checklist:**
- [ ] Wave 1-3: Simple, 1-2 enemy types
- [ ] Wave 4-7: Mixed, 2-3 enemy types
- [ ] Wave 8-9: Challenging, 3+ enemy types
- [ ] Wave 10: Boss wave with minions
- [ ] Total difficulty feels fair compared to previous level

---

### **Step 2: Create Folder Structure (30 seconds)**

In File Explorer or Godot:
```
Create folder: data/levels/forest/forest_03/waves/
```

Or via command:
```bash
mkdir -p "data/levels/forest/forest_03/waves"
```

---

### **Step 3: Create Wave Files (20-30 minutes)**

#### **Method A: Copy & Modify (Fastest)**

1. **Copy existing waves:**
   - Copy `forest_02/waves/` folder
   - Paste as `forest_03/waves/`

2. **Open in Godot:**
   - Navigate to `data/levels/forest/forest_03/waves/`
   - Double-click `wave_01.tres`
   - **In Inspector:**
     - Change **Count** from 8 → 10 (based on your plan)
     - Save (Ctrl+S)

3. **Repeat for all 10 waves**

**Time:** ~20 minutes for 10 waves

#### **Method B: Create from Scratch**

1. **In Godot FileSystem:**
   - Navigate to `data/levels/forest/forest_03/waves/`
   - Right-click → **New Resource**
   - Search: "WaveData"
   - Name: `wave_01.tres`

2. **Configure in Inspector:**
   - Wave Number: 1
   - Break Time: 3.0
   - **Enemies → Size: 1**
   - [0] → New EnemySpawnData:
     - Enemy Type: goblin (dropdown)
     - Count: 10
     - Spawn Delay: 0.5

3. **For Mixed Waves:**
   - Enemies → **Size: 2** (or more)
   - [0]: goblin, count 8
   - [1]: wolf, count 6

**Time:** ~30-40 minutes for 10 waves

---

### **Step 4: Create Level Config (2 minutes)**

1. **In Godot FileSystem:**
   - Navigate to `data/level_configs/forest/`
   - **Copy** `forest_02_config.tres`
   - **Paste** and rename to `forest_03_config.tres`

2. **Open in Inspector and edit:**
   - **Level ID:** "forest_03"
   - **Level Name:** "Goblin Stronghold"
   - **Level Description:** "..."
   - **Difficulty:** 3 (up from 2)
   - **Starting Gold:** 110
   - **Required Stars:** 4 (need 4 stars to unlock)
   - **Level Index:** 3
   - **Waves → Size: 10**
     - Drag all 10 wave files from `forest_03/waves/` into slots

3. **Save (Ctrl+S)**

---

### **Step 5: Add to Campaign (1 minute)**

1. **Open:** `data/campaigns/forest_campaign.tres`
2. **In Inspector:**
   - **Levels → Size:** 3 (was 2, now 3)
   - **Slot [2]:** Drag `forest_03_config.tres`
3. **Save**

---

### **Step 6: Test the Level (5-10 minutes)**

#### **Option A: Quick Test (No Scene)**
1. Open Godot Script Editor
2. Add to any script or debug console:
```gdscript
LevelManager.quick_load_level("forest_03")
```
3. Run

#### **Option B: With Scene**
1. Duplicate `level_01.tscn` → `forest_03.tscn`
2. Modify path/decorations (optional for testing)
3. Update `forest_03_config.tres`:
   - **Level Scene:** Drag `forest_03.tscn`
4. Load via LevelManager

---

### **Step 7: Balance & Iterate**

**Playtest Checklist:**
- [ ] Starting gold feels appropriate
- [ ] Early waves aren't too hard
- [ ] Mid-waves provide challenge
- [ ] Boss wave is exciting but fair
- [ ] 3 stars is achievable with good play
- [ ] 1 star is possible for struggling players

**Adjust:**
- Too hard? → Increase starting gold or reduce enemy counts
- Too easy? → Reduce gold or increase enemies
- Boss too weak? → Add more minions or extra boss

---

## ⚡ Time Estimates

| Task | Time per Level | Total for 30 Levels |
|------|----------------|---------------------|
| Planning | 5-10 min | 2.5-5 hours |
| Creating waves | 20-30 min | 10-15 hours |
| Creating config | 2 min | 1 hour |
| Adding to campaign | 1 min | 30 min |
| Testing & balancing | 10-20 min | 5-10 hours |
| **TOTAL** | **~40-60 min** | **~20-30 hours** |

**Realistic Timeline:**
- **Week 1:** Plan all 30 levels (5 hours)
- **Week 2-3:** Create Forest Campaign (10 levels, ~10 hours)
- **Week 4-5:** Create Desert Campaign (10 levels, ~10 hours)
- **Week 6-7:** Create Mountains Campaign (10 levels, ~10 hours)
- **Week 8:** Final balancing and polish

---

## 🎨 Level Design Tips

### **Variety is Key**

Don't just increase numbers - change the composition:

**Bad (boring):**
- Level 1: 10 goblins
- Level 2: 15 goblins
- Level 3: 20 goblins

**Good (interesting):**
- Level 1: 10 goblins (learn basic defense)
- Level 2: 8 goblins + 4 wolves (learn to handle speed)
- Level 3: 15 goblins + 8 wolves + 5 orcs (juggle multiple threats)

### **Wave Archetypes**

Create memorable waves:

| Archetype | Example | Purpose |
|-----------|---------|---------|
| **Speed Test** | 30 wolves | Tests player's DPS |
| **Tank Wall** | 20 orcs | Tests sustained damage |
| **Air Assault** | 25 bats | Forces anti-air towers |
| **Horde** | 50 goblins | Overwhelming numbers |
| **Mixed Chaos** | 15G + 15W + 10O + 10B | Tests adaptability |
| **Boss Rush** | 3 trolls + 30 minions | Epic finale |

### **Difficulty Curve Guidelines**

| Levels | Enemy Count Range | Notes |
|--------|-------------------|-------|
| 1-3 | 80-150 total | Tutorial, forgiving |
| 4-6 | 150-250 total | Steady challenge |
| 7-10 | 250-400 total | Forest finale |
| 11-13 | 300-450 total | Desert intro (harder than forest) |
| 14-16 | 400-550 total | Mid-desert challenge |
| 17-20 | 500-700 total | Desert finale |
| 21-23 | 600-800 total | Mountain intro (hardest) |
| 24-26 | 750-950 total | Late mountain |
| 27-30 | 900-1200+ total | Final gauntlet |

---

## 🔧 Batch Operations

### **Creating Multiple Levels Quickly**

**Day 1: Create Wave Folders**
```bash
# Create all forest level folders at once
for i in {03..10}; do
    mkdir -p "data/levels/forest/forest_$i/waves"
done
```

**Day 2-3: Copy & Modify Waves**
- Copy `forest_02/waves/` to `forest_03/waves/`
- Edit counts in Inspector
- Repeat for each level

**Day 4: Batch Create Configs**
- Copy `forest_02_config.tres` 8 times
- Rename to `forest_03` through `forest_10`
- Edit properties in Inspector

**Day 5: Add All to Campaign**
- Open `forest_campaign.tres`
- Set Levels → Size: 10
- Drag all 10 configs

---

## 📊 Tracking Progress

Use this checklist:

### Forest Campaign
- [x] Forest 01 ✅
- [x] Forest 02 ✅
- [ ] Forest 03
- [ ] Forest 04
- [ ] Forest 05 (Boss)
- [ ] Forest 06
- [ ] Forest 07
- [ ] Forest 08
- [ ] Forest 09
- [ ] Forest 10 (Final Boss)

### Desert Campaign
- [ ] Desert 01
- [ ] Desert 02
- [ ] Desert 03
- [ ] Desert 04
- [ ] Desert 05 (Boss)
- [ ] Desert 06
- [ ] Desert 07
- [ ] Desert 08
- [ ] Desert 09
- [ ] Desert 10 (Final Boss)

### Mountains Campaign
- [ ] Mountain 01
- [ ] Mountain 02
- [ ] Mountain 03
- [ ] Mountain 04
- [ ] Mountain 05 (Boss)
- [ ] Mountain 06
- [ ] Mountain 07
- [ ] Mountain 08
- [ ] Mountain 09
- [ ] Mountain 10 (Ultimate Boss)

**Progress:** 2/30 levels (6.7%)

---

## 🎮 Loading Levels in Game

### **From Main Menu**
```gdscript
# In level select screen
func _on_level_button_pressed(level_id: String):
    LevelManager.quick_load_level(level_id)

# Examples:
LevelManager.quick_load_level("forest_01")
LevelManager.quick_load_level("forest_02")
LevelManager.quick_load_level("desert_05")
```

### **From Victory Screen**
```gdscript
func _on_next_level_pressed():
    LevelManager.load_next_level()  # Automatically loads next in campaign
```

### **Campaign Select**
```gdscript
# Show campaigns based on player progress
var player_stars = SaveManager.get_total_stars()
var unlocked_campaigns = LevelManager.get_unlocked_campaigns(player_stars)

for campaign in unlocked_campaigns:
    create_campaign_button(campaign)
```

---

## 🐛 Troubleshooting

### "No waves spawning!"
- Check: Did you drag wave files into level config?
- Check: Is level config added to campaign?
- Check: Console shows "Loading waves from LevelConfig"?

### "Wrong starting gold/lives"
- Edit `level_config.tres` → Starting Gold/Lives

### "Level won't unlock"
- Check `required_stars` in level config
- Lower value if too restrictive

### "Enemies too weak/strong"
- Edit individual wave files
- Adjust enemy counts
- Change starting gold

---

## 📝 Quick Reference

### File Locations
```
Waves:        data/levels/{world}/{level}/waves/wave_XX.tres
Level Config: data/level_configs/{world}/{level}_config.tres
Campaign:     data/campaigns/{world}_campaign.tres
```

### Common Values
```
Starting Gold: 100-150 (increase for harder levels)
Starting Lives: 20 (standard)
Break Time: 3.0 seconds (standard), 4.0 (boss waves)
Spawn Delay: 0.3-0.8 (randomized automatically)
```

### Enemy Counts (Guidelines)
```
Early waves:  5-15 enemies
Mid waves:    15-30 enemies
Late waves:   30-60 enemies
Boss waves:   Boss + 10-40 minions
```

---

## ✅ Completion Checklist

When you finish all 30 levels:

- [ ] All 30 level folders created
- [ ] All 300 wave files created (30 levels × 10 waves)
- [ ] All 30 level configs created
- [ ] All 3 campaigns have 10 levels each
- [ ] All levels tested and balanced
- [ ] Difficulty curve feels fair
- [ ] Each world has unique theme/challenge
- [ ] Boss levels feel epic
- [ ] All levels accessible via level select screen

---

## 🎯 Next Steps

1. **Read LEVEL_PLANNING_TEMPLATE.md** - Complete the enemy composition plan
2. **Create Forest 03** - Follow this workflow guide
3. **Test Forest 03** - Make sure it works
4. **Repeat for Forest 04-10** - Build momentum
5. **Move to Desert Campaign** - New enemies, new challenges
6. **Finish with Mountains** - Ultimate difficulty

---

**You've got this!** With the foundation in place, creating 30 unique levels is just a matter of following the workflow. Take it one level at a time, and you'll have an amazing tower defense game! 🎮🏰

