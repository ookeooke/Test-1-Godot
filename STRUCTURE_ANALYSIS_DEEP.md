# DEEP GAME STRUCTURE ANALYSIS
**Date**: October 24, 2025
**Analysis Type**: Complete structure audit and implementation verification

---

## EXECUTIVE SUMMARY

### Status: ⚠️ PARTIALLY IMPLEMENTED

**What's Working:**
- ✅ 16-wave system exists
- ✅ Starting gold increased to 200
- ✅ Campaign cleanup (level_manager.gd fixed)
- ✅ Duplicate campaigns deleted from disk

**What's Broken:**
- ❌ Balance changes NOT fully implemented
- ❌ Old wave files still exist (data/waves/)
- ❌ Scene hardcodes old waves (not using LevelConfig)
- ❌ level_02.tscn still exists on disk
- ❌ Wave manager still uses 20g bonuses (not 12/13/15g)

---

## 1. FILE STRUCTURE AUDIT

### ✅ CORRECT Structure

```
data/
  campaigns/
    main_campaign.tres ✓ (Only campaign remaining)

  level_configs/
    level_01_config.tres ✓ (Only config, references 16 waves)

  levels/
    level_01/
      waves/
        wave_01.tres through wave_16.tres ✓ (16 new balanced waves)
    level_01_data.tres ✓
    level_02_data.tres ✓
```

### ❌ INCORRECT Structure (Should Be Deleted)

```
data/
  waves/ ❌ STILL EXISTS
    wave_01.tres through wave_10.tres (Old fallback waves)
    example_mixed_wave.tres

scenes/
  levels/
    level_02.tscn ❌ STILL EXISTS (should be deleted)
```

---

## 2. CRITICAL ISSUE: DUAL WAVE LOADING SYSTEM

### The Problem

The game has TWO conflicting sources for wave data:

**Source 1: Hardcoded in Scene (OLD WAVES)**
- File: [level_01.tscn:60](scenes/levels/level_01.tscn#L60)
- References: `data/waves/wave_01.tres` through `wave_10.tres` (10 old waves)
- Status: ❌ **WRONG** - Points to old unbalanced waves

**Source 2: LevelConfig (NEW WAVES)**
- File: [level_01_config.tres:28](data/level_configs/level_01_config.tres#L28)
- References: `data/levels/level_01/waves/wave_01.tres` through `wave_16.tres`
- Status: ✅ **CORRECT** - Points to new 16-wave balanced version

### How It Currently Works

```
GAME START:
1. Scene loads → WaveManager has 10 old waves hardcoded
2. LevelManager loads level_01_config.tres
3. WaveManager._ready() checks if LevelManager.current_level exists
4. IF YES → Overwrites hardcoded waves with config waves ✓
5. IF NO (F5 quick test) → Uses hardcoded waves ❌
```

**Impact:**
- Normal gameplay (Menu → Level Select): Uses 16 new waves ✓
- F5 quick testing: Uses 10 old waves ❌
- Confusing for development and testing

---

## 3. BALANCE IMPLEMENTATION STATUS

### ✅ FULLY IMPLEMENTED

| Change | Planned | Actual | Status |
|--------|---------|--------|--------|
| **Starting Gold** | 200 | 200 | ✅ DONE |
| **Wave Count** | 16 | 16 | ✅ DONE |
| **Wave Files Created** | 16 | 16 | ✅ DONE |
| **Tower Base Damage** | 12 | 12 | ✅ DONE |
| **HP Scaling** | 1.0x→12.0x | 1.0x→12.0x | ✅ DONE |
| **Boss Wave** | Wave 16 | Wave 16 | ✅ DONE |

### ⚠️ PARTIALLY IMPLEMENTED

| Change | Planned | Actual | Status | File |
|--------|---------|--------|--------|------|
| **Tower Cost** | 80 | **100** | ❌ NOT DONE | archer_tower.gd:29 |
| **Hero Damage** | 12 | **10** | ❌ NOT DONE | ranger_hero.gd:30 |
| **Hero Attack Speed** | 0.55s | **0.6s** | ❌ NOT DONE | ranger_hero.gd:33 |
| **Tower L2 Damage** | 17 | **20** | ❌ NOT DONE | archer_tower.gd (upgrade logic) |
| **Tower L4 Cost** | 150 | **120** | ❌ NOT DONE | archer_tower.gd:980 |

### ❌ NOT IMPLEMENTED AT ALL

| Change | Planned | Actual | Status | File |
|--------|---------|--------|--------|------|
| **Wave Bonuses** | 12g/13g/15g progressive | **20g flat** | ❌ NOT DONE | wave_manager.gd:177 |
| **Spawn Delays** | System implemented | Not used by WaveManager | ❌ NOT DONE | wave_manager.gd |

---

## 4. DETAILED FILE ANALYSIS

### 4.1 Campaign System ✅

**File**: [scripts/autoloads/level_manager.gd:22](scripts/autoloads/level_manager.gd#L22)

```gdscript
const MAIN_CAMPAIGN = preload("res://data/campaigns/main_campaign.tres")
```

**Status**: ✅ **FIXED** - Now only loads main_campaign.tres

**Previous Issue**: Was trying to load deleted forest/desert/mountains campaigns
**Resolution**: Deleted old campaign files + updated level_manager.gd

---

### 4.2 Wave System ❌

**File**: [scenes/levels/level_01.tscn:60](scenes/levels/level_01.tscn#L60)

```gdscript
waves = Array[ExtResource("8_e6lid")]([
    ExtResource("9_3g50r"),   # res://data/waves/wave_01.tres ❌ OLD
    ExtResource("10_iu1m7"),  # res://data/waves/wave_02.tres ❌ OLD
    ...
    ExtResource("18_5t8rk")   # res://data/waves/wave_10.tres ❌ OLD (only 10!)
])
```

**Status**: ❌ **WRONG** - Scene still hardcodes OLD 10-wave version

**Should Be**:
- Either: Remove hardcoded waves entirely (use only LevelConfig)
- Or: Update to reference new 16-wave files from data/levels/level_01/waves/

---

### 4.3 Wave Bonuses ❌

**File**: [scripts/managers/wave_manager.gd:177](scripts/managers/wave_manager.gd#L177)

```gdscript
# Award wave completion bonus (20g per wave)
var wave_bonus = 20
```

**Status**: ❌ **NOT IMPLEMENTED**

**Should Be**:
```gdscript
var wave_bonus = 12
if current_wave >= 7:
    wave_bonus = 13
if current_wave >= 13:
    wave_bonus = 15
```

**Impact**: Economy is too generous (20g vs 12-15g planned)

---

### 4.4 Tower Balance ⚠️

**File**: [scenes/towers/archer_tower.gd:29](scenes/towers/archer_tower.gd#L29)

```gdscript
var build_cost = 100  # Cost to build this tower (for sell calculation)
```

**Status**: ❌ **NOT CHANGED** - Still 100g (planned 80g)

**File**: [scenes/towers/archer_tower.gd:980](scenes/towers/archer_tower.gd#L980)

```gdscript
return 120  # Level 3→4 path choice (Reduced from 150g -20%)
```

**Status**: ❌ **WRONG** - Should be 150g, currently 120g (opposite of plan)

**Impact**:
- Starting gold allows 2 towers (200/100 = 2.0x) instead of 2.5 towers (200/80 = 2.5x)
- Less strategic choice at game start

---

### 4.5 Hero Balance ❌

**File**: [scenes/heroes/ranger_hero.gd:30-33](scenes/heroes/ranger_hero.gd#L30-L33)

```gdscript
const BASE_RANGED_DAMAGE = 10.0  # Reduced from 14 (-29%) for balanced difficulty
const BASE_RANGED_ATTACK_SPEED = 0.6  # 23.3 DPS ranged (lower = faster)
```

**Status**: ❌ **NOT CHANGED**

**Should Be**:
```gdscript
const BASE_RANGED_DAMAGE = 12.0  # Buffed from 10.0 (+20%)
const BASE_RANGED_ATTACK_SPEED = 0.55  # Faster attacks (21.8 DPS)
```

**Current Hero DPS**: 10.0 / 0.6 = 16.7 DPS
**Planned Hero DPS**: 12.0 / 0.55 = 21.8 DPS
**Target Ratio**: 1.5-2.0x tower DPS (tower = 12 DPS)
**Current Ratio**: 16.7/12 = 1.39x ❌ (below target)
**Planned Ratio**: 21.8/12 = 1.82x ✅ (within target)

**Impact**: Hero too weak, doesn't feel impactful enough

---

### 4.6 Wave Files ✅

**Location**: `data/levels/level_01/waves/`

**Status**: ✅ All 16 waves exist with correct data

Example - Wave 16 (Final Boss):
```tres
wave_number = 16
wave_name = "EPIC FINAL BOSS"
is_boss_wave = true
hp_multiplier = 12.0
enemies = 5 trolls
spawn_delay = 8.0
```

**All waves have**:
- ✅ Correct HP multipliers (1.0x → 12.0x progression)
- ✅ Spawn delays implemented (2.0s - 8.0s)
- ✅ Progressive enemy counts
- ✅ Boss waves marked (5, 10, 16)

---

## 5. WHAT NEEDS TO BE FIXED

### Priority 1: Critical (Breaks Gameplay)

1. **Update scene wave references** ❌
   - File: `scenes/levels/level_01.tscn`
   - Action: Change hardcoded waves from `data/waves/` to `data/levels/level_01/waves/`
   - Or: Remove hardcoded waves entirely, rely only on LevelConfig
   - Impact: F5 testing currently plays old 10-wave version

2. **Implement progressive wave bonuses** ❌
   - File: `scripts/managers/wave_manager.gd:177`
   - Action: Replace flat 20g with 12g/13g/15g progressive system
   - Impact: Economy too generous (player gets +160g per game vs planned +192-232g)

### Priority 2: Balance (Affects Difficulty)

3. **Fix tower build cost** ⚠️
   - File: `scenes/towers/archer_tower.gd:29`
   - Action: Change `build_cost = 100` to `build_cost = 80`
   - Impact: Player can only build 2.0 towers at start vs planned 2.5

4. **Buff hero stats** ⚠️
   - File: `scenes/heroes/ranger_hero.gd:30-33`
   - Action: Change damage 10→12, attack speed 0.6→0.55
   - Impact: Hero DPS ratio 1.39x vs target 1.82x (hero feels weak)

5. **Fix tower L4 upgrade cost** ⚠️
   - File: `scenes/towers/archer_tower.gd:980`
   - Action: Change `return 120` to `return 150`
   - Impact: L4 upgrades too cheap (reversed from plan)

6. **Nerf tower L2 damage** ⚠️
   - File: `scenes/towers/archer_tower.gd` (upgrade logic)
   - Action: Find L2 upgrade, change damage 20→17
   - Impact: L2 upgrade too powerful (efficiency 2.17x vs target 1.84x)

### Priority 3: Cleanup (Technical Debt)

7. **Delete old wave files** 🧹
   - Location: `data/waves/`
   - Action: Delete entire directory
   - Impact: Confusing to have duplicate wave files

8. **Delete level_02.tscn** 🧹
   - Location: `scenes/levels/level_02.tscn`
   - Action: Delete file (scene exists but no config/campaign references it)
   - Impact: Unused file taking up space

9. **Delete nul file** 🧹
   - Location: Root directory
   - Action: `rm nul`
   - Impact: Weird untracked file (Windows artifact)

---

## 6. IMPLEMENTATION PLAN

### Step 1: Fix Wave References in Scene

**Option A: Remove Hardcoded Waves (Recommended)**
```gdscript
# In level_01.tscn, change WaveManager node:
waves = Array[ExtResource("8_e6lid")]([])  # Empty array
```
**Pros**: Clean, single source of truth (LevelConfig)
**Cons**: F5 quick test won't work (need to go through menu)

**Option B: Update to New Wave Files**
```gdscript
# Update all ExtResource references from:
# res://data/waves/wave_XX.tres
# To:
# res://data/levels/level_01/waves/wave_XX.tres
# And add waves 11-16
```
**Pros**: F5 quick test works
**Cons**: Duplicate data, can get out of sync

**Recommendation**: Option A - Remove hardcoded waves

---

### Step 2: Implement Progressive Wave Bonuses

**File**: `scripts/managers/wave_manager.gd`

**Find**:
```gdscript
# Award wave completion bonus (20g per wave)
var wave_bonus = 20
GameStateManager.add_gold(wave_bonus)
```

**Replace With**:
```gdscript
# Award wave completion bonus (progressive: 12g/13g/15g)
var wave_bonus = 12
if current_wave >= 7:
    wave_bonus = 13  # Mid-game bonus
if current_wave >= 13:
    wave_bonus = 15  # Late-game bonus

GameStateManager.add_gold(wave_bonus)
print("[WaveManager] Wave completion bonus: +%dg (wave %d)" % [wave_bonus, current_wave])
```

---

### Step 3: Fix Tower Balance

**File**: `scenes/towers/archer_tower.gd`

**Change 1 - Build Cost** (Line ~29):
```gdscript
var build_cost = 80  # Cost to build this tower (balanced for 2.5 towers at start)
```

**Change 2 - L4 Cost** (Line ~980):
```gdscript
return 150  # Level 3→4 path choice (increased from 120g for economy balance)
```

**Change 3 - L2 Damage** (Need to find upgrade logic):
```gdscript
# Search for "tower_level = 2" or "match tower_level: 2:"
# Change damage from 20 to 17
damage = 17  # Reduced from 20 for balance (prevents L2 power spike)
```

---

### Step 4: Buff Hero

**File**: `scenes/heroes/ranger_hero.gd`

**Change Lines 30-33**:
```gdscript
const BASE_RANGED_DAMAGE = 12.0  # Buffed from 10.0 (+20%) to hit 1.8x tower DPS ratio
const BASE_RANGED_ATTACK_SPEED = 0.55  # Faster attacks (21.8 DPS ranged, lower = faster)
```

---

### Step 5: Cleanup

```bash
# Delete old waves directory
rm -rf data/waves/

# Delete unused level scene
rm scenes/levels/level_02.tscn

# Delete Windows artifact
rm nul
```

---

## 7. TESTING PLAN

After implementing all fixes, test the following:

### Test 1: Godot Launch
- [ ] No errors in Output console
- [ ] No missing resource warnings
- [ ] Game loads to main menu

### Test 2: Level Load
- [ ] Click Level 1 from level select
- [ ] Game loads without errors
- [ ] Starting gold = 200g
- [ ] Can build 2 towers + hero (cost: 80g each = 160g total)

### Test 3: Wave Progression
- [ ] 16 waves play in sequence
- [ ] Wave bonuses: 12g (waves 1-6), 13g (waves 7-12), 15g (waves 13-16)
- [ ] Waves last 20-40 seconds (not 3-19s like before)
- [ ] Wave 16 boss appears (5 trolls)

### Test 4: Balance Feel
- [ ] Need 4-5 towers to win (not 2 like before)
- [ ] Must upgrade towers to L3-L4 (not just L1-L2)
- [ ] Gold is tight (not 2,588g surplus)
- [ ] Hero feels impactful (1.82x tower DPS)
- [ ] Final boss is challenging (75-90s fight)

### Test 5: F5 Quick Test
- [ ] If hardcoded waves removed: Shows error or doesn't load
- [ ] If hardcoded waves updated: Works with 16 waves

---

## 8. RISK ASSESSMENT

### Low Risk Changes ✅
- Progressive wave bonuses (isolated change)
- Delete unused files (no code dependencies)
- Tower/hero stat changes (numerical only)

### Medium Risk Changes ⚠️
- Scene wave references (must test both menu flow and F5)
- L2 damage change (need to find upgrade logic first)

### High Risk Changes 🔴
- None identified

---

## 9. SUMMARY

### What We Thought Was Done ❌

Based on BALANCE_OVERHAUL_SUMMARY.md and conversation history, we thought:
- ✅ Tower cost: 80g
- ✅ Hero buffed: 12 damage, 0.55s attack speed
- ✅ Wave bonuses: 12/13/15g progressive
- ✅ L2 tower damage: 17
- ✅ L4 tower cost: 150g
- ✅ Old waves deleted

### What Was Actually Done ✅

- ✅ Starting gold: 200g
- ✅ 16 wave files created with correct data
- ✅ level_01_config.tres references 16 waves
- ✅ Campaign cleanup (level_manager.gd)
- ✅ Duplicate campaign files deleted

### What Still Needs Implementation ❌

**Critical**:
1. Scene wave references (still use old 10-wave files)
2. Wave bonuses (still 20g flat)

**Balance**:
3. Tower cost (still 100g, not 80g)
4. Hero stats (still 10 damage, 0.6s speed)
5. L4 cost (120g, should be 150g)
6. L2 damage (likely still 20, should be 17)

**Cleanup**:
7. data/waves/ directory (still exists)
8. level_02.tscn (still exists)
9. nul file (artifact)

### Estimated Implementation Time

- Critical fixes: 15-20 minutes
- Balance fixes: 10-15 minutes
- Cleanup: 2 minutes
- Testing: 20-30 minutes
- **Total**: ~45-70 minutes

---

## 10. NEXT STEPS

1. Review this analysis with user
2. Confirm which fixes to implement
3. Execute fixes in priority order
4. Test after each priority tier
5. Commit changes when stable
6. Create final playtest session

---

**Generated by Claude Code**
**Date**: October 24, 2025
**Analysis Duration**: Deep structure audit
