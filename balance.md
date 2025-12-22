# ⚖️ Game Balance: The Kingdom Rush Standard

This document defines the "Source of Truth" for game balance, adopted on 2025-12-21.
We have moved away from abstract DPG models to a **Kingdom Rush 1 Clone** philosophy.

## 1. Core Philosophy
*   **Decimated Numbers:** Level 1 towers deal ~5-15 damage. Enemies have ~40-60 HP.
*   **Economy Dictates Survival:** Gold is scarce. You cannot upgrade everything.
*   **Zero to Hero:** The Hero starts weak (10 dmg) and scales to a God (100+ dmg).

## 2. Tower Stats (The Sacred Tables)

### 🏹 Archer Tower (Physical DPS)
| Level | Name | Cost | Damage | Speed | Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Archer | 70g | 6 | 0.8s | 280 |
| **2** | Marksman | 110g | 10 | 0.7s | 300 |
| **3** | Sharpshooter | 160g | 15 | 0.6s | 320 |
| **4A** | **Ranger** | +230g | 18 | 0.4s | 350 |
| **4B** | **Musketeer** | +230g | 50 | 1.5s | 450 |
| **5A** | **Elite Ranger** | +350g | 24 | 0.3s | 380 |
| **5B** | **Royal Musketeer** | +350g | 80 | 1.4s | 500 |

### ⚡ Mage Tower (Armor Piercing)
| Level | Name | Cost | Damage | Speed | Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Mage | 100g | 15 | 1.5s | 280 |
| **2** | Adept | 160g | 35 | 1.5s | 300 |
| **3** | Wizard | 240g | 60 | 1.5s | 320 |
| **4A** | **Arcane** | +300g | 100 | 1.7s | 350 |
| **4B** | **Sorcerer** | +300g | 40 | 1.2s | 320 |

### 💣 Artillery (Splash)
| Level | Name | Cost | Damage | Speed | Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | Bombard | 125g | 8 | 3.0s | 320 |
| **2** | Artillery | 220g | 15 | 3.0s | 340 |
| **3** | Howitzer | 320g | 30 | 3.0s | 360 |
| **4A** | **Big Bertha** | +500g | 70 | 3.0s | 400 |
| **4B** | **Tesla** | +500g | 45 | 2.5s | 380 |

### 🛡️ Barracks (Holding Power)
| Level | HP | Armor |
| :--- | :--- | :--- |
| **1** | 60 | None |
| **2** | 100 | None |
| **3** | 150 | Low |
| **4** | 250 (Paladin) | High |

## 3. Economy Settings
*   **Gold Drop Chance:** 20%
*   **Goblin Gold:** 3g
*   **Starting Gold (Level 3):** 250g

## 4. Derived Difficulty
*   **Goblin HP:** 40
*   **Archer Shots to Kill:** 7 shots (5.6 seconds).
*   **Conclusion:** One L1 tower cannot hold a lane. You need Barracks + multiple towers.

This is **HARD MODE**.

## 5. Verified Insights (2025-12-22)
### The "Archer vs Wolf" Reality Check
*   **Observation:** A Level 1 Archer (6 dmg, 0.8s speed) requires **11 shots** to kill a single Wolf (80 HP).
    *   This takes ~9.0 seconds of continuous uptime.
*   **Conclusion:** Archers cannot solo defend against speed units. They require **Barracks** to act as a "Time Multiplier" (holding enemies in place).

### Level 4 Upgrades (Verified)
The following stats have been implemented and verified in-game:

| Path | Name | Role | Damage | Speed | Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Left** | **Rangers Hideout** | Machine Gun | **18** | **0.4s** | 350 |
| **Right** | **Musketeer Garrison** | Sniper | **50** | **1.5s** | 450 |

*   **Ranger:** Shreds unarmored swarms (Goblins/Wolves).
*   **Musketeer:** Essential for high-armor targets (Orcs) due to huge per-shot damage.

### Observed Benchmarks (Level 1 vs Level 2)
*Data from Run 2 (Wave 6).*
*   **Level 1 Archer:** Averaged ~500 Total Damage.
*   **Level 2 Archer:** Averaged ~1,500 Total Damage.
*   **Efficiency:** Upgrading to Level 2 (110g) provided **3x the damage output** of a Level 1 tower (70g).
*   **Strategy:** It is significantly more efficient to upgrade existing towers than to build new Level 1 towers.

## 6. The Economic Model (Gold vs Enemies)
*Derived from Run 2 (Level 3 Rush).*

### A. Player Income (GPM)
*   **Starting Gold:** 250g
*   **Gold Per Minute:** ~280g (from kills + waves).
*   **Purchasing Power:**
    *   One **Level 3 Archer** costs ~340g.
    *   Therefore, the player can build **~0.8 Level 3 Towers per Minute**.

### B. DPS Cap per Minute
*   A Level 3 Archer deals ~4,000 damage/minute (Observed).
*   **Max New DPS per Minute:** ~3,200 Damage/min added to the field.

### C. Enemy "HP Budget"
To ensure the player can win, the **Total Enemy HP per Minute** must not exceed the Player's DPS.
*   **Formula:** `Spawn Rate * Enemy HP < Player Total DPS`
*   **Current Reality (Wave 4 Leak):**
    *   **Wolf HP:** 80
    *   **Spawn Rate:** High (10 wolves in 30s) = 800 Total HP.
    *   **Required DPS:** 800 HP / 30s = **26.6 DPS**.
    *   **Player Actual DPS:** ~40 (Single Level 3 Tower).
    *   **Result:** The Player *should* have won, but leaked due to targeting/stun/overkill inefficiency.

### D. Conclusion
*   **The Math Works:** 280g/min is enough to kill the waves.
*   **The Problem is Mechanical:** Towers waste shots, or enemies move too fast between shots.
*   **Solution:** We do not need more Gold. We need **Better Containment (Barracks)** or **Slower Enemies**.

## 7. The Efficiency Curve (Quality vs Quantity)
*Comparison of Runs 1 & 2.*

We have proven that **Upgrading is exponentially better** than building wide.

| Tower Level | Cumulative Cost | Avg Dmg (Run 1/2) | Damage Per Gold (DPG) |
| :--- | :--- | :--- | :--- |
| **Level 1** | 70g | ~500 | **7.1** |
| **Level 2** | 180g | ~1,542 | **8.5** |
| **Level 3** | 340g | ~4,290 | **12.6** |

### Key Findings
1.  **The "Level 3 Spike":** A Level 3 Archer is nearly **2x more efficient** per gold spent than a Level 1 Archer.
2.  **Strategy Implication:** The optimal strategy is to rush a key tower to Level 3/4 immediately, rather than building multiple Level 1 towers.
3.  **The "Wolf Check":** Despite this high DPS, both strategies failed against Wolves because they *ran past* the DPS window.
    *   **Actionable Item:** We must verify if **Mage Towers (Armor/Slow?)** or **Barracks (Block)** are the answer to Wolves.

## 8. Artillery Benchmark (Observed)
*Data from Run 3 (Artillery Only).*

| Tower Type | Level | Cost | Total Dmg | Kills | Efficiency |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Artillery** | 1 | 125g | 944 | 6 | **~7.5 DPG** |

*   **Observed Behavior:** High damage per hit (~8.0), but very slow fire rate.
*   **Result:** Leaked significantly.
*   **Data Point:** Currently performs worse than Archer L1 (700 dmg) despite higher cost. **Do not change stats yet.** We need to see if it scales with density.

## 9. Mage Benchmark (Observed)
*Data from Run 4 (Mage Only).*

| Tower Type | Level | Cost | Total Dmg | Kills | Efficiency |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mage** | 2 | 290g | **3,445** | **17** | **~11.8 DPG** |

*   **Observed Behavior:** Extremely high damage per shot (~35), but slow.
*   **Result:** Surprisingly effective. The "Armor Piercing" (or just high raw damage) nearly matched the Level 3 Archer in efficiency.
*   **Verdict:** Balanced. High cost, high reward.

## 10. The Speed Problem (Wolf Analysis)
*   **Consensus:** All 4 runs failed due to Wolves leaking.
*   **Math:** Wolf Speed > Tower Range / Damage Window.
*   **Conclusion:** Towers are fine. **Wolves are too fast.** We should consider reducing their speed by 10-20%.

## 11. The Master Balance Plan (Proposed)
*We have enough data to balance the entire game mathematically.*

### The Formula
`Wave HP Budget` = (`Player Gold` * `DPG Efficiency`) / `Safety Margin`

## 11. The Master Balance Plan (Verified)
*Formula:* `Total Player DPS` (Towers + Hero) vs `Wave Flow` (HP / Duration).

### The Hero Factor
*   **Observed DPS:** ~30 DPS (Level 1).
*   **Gold Value:** Equivalent to ~300g of Tower Power.
*   **Role:** The "Safety Net". The Hero covers leaks.
*   **Balance Limit:** Hero DPS must NOT exceed Wave Flow, or the game plays itself.

### The "HP Flow" Chart (Multipliers Included)
| Wave | HP Mult | Raw HP | **Total HP Budget** | Flow (HP/sec) | Difficulty |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | 1.0x | 800 | 800 | 40 | Easy |
| **3** | 1.2x | 800 | 960 | 32 | Easy |
| **4** | 1.5x | 640 | 960 | 32 | Medium |
| **6** | 2.1x | **1,344 (Modified)** | 1,344 | **45** | **Hard** |

*Note: Wave 6 was previously 2,016 HP (Flow 67/sec), which was impossible.*

### Changes Applied
1.  **Wave 6 Nerf:** Reduced Wolves from 12 to 8.
    *   This smooths the difficulty curve significantly.
2.  **Next Step:** Verify if the Hero + Towers can handle the "45 HP/sec" flow of Wave 6.
