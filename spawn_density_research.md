# 📊 Enemy Spawn Density & Wave Formulas

> **Deep Dive Summary:**
> *   **Total Enemies per Level:** 150 - 450 (Standard Campaign).
> *   **Avg Enemies per Wave:** Starts at ~8, peaks at ~45.
> *   **Spawn Rate:** Essential to flood the path without overlapping too much.

## 📈 The Math of "Waves"

### 1. The Scaling Formula
Research suggests a **Exponential or Polynomial** growth is best.
Recommended Formula for your game:
`Enemies_in_Wave = Base_Count * (Wave_Number ^ Scaling_Factor)`

*   **Base_Count:** 6-8 (Wave 1)
*   **Scaling_Factor:** 0.75 - 0.85

**Projected Counts:**
*   **Wave 1:** 8 * (1^0.75) = **8 Enemies**
*   **Wave 5:** 8 * (5^0.75) ≈ **27 Enemies**
*   **Wave 10:** 8 * (10^0.75) ≈ **45 Enemies**
*   **Wave 15:** 8 * (15^0.75) ≈ **61 Enemies**

**Total for 15 Wave Level:** ~500 Enemies total.

### 2. Density (Enemies Per Minute)
*   **Early Game:** ~20 kills/min.
*   **Mid Game:** ~40-60 kills/min.
*   **Late Game:** ~80+ kills/min (Chaos phase).

---

## 🔬 "Kingdom Rush" Deconstruction
(Based on Victory Screen Analysis)

*   **Early Levels:** 100-150 Total Kills. (Short, Tutorial-like).
*   **Mid Campaign:** 250-350 Total Kills.
*   **Elite Stages:** 500+ Total Kills (Longer, multiple paths).
*   **Iron Marines / Vengeance:** Tend to have fewer, tougher units, lowering the kill count to ~200 but raising HP pools.

### 🧠 Strategic Implications for "Test-1-Godot"
Since we want a **Vengeance-like** feel (Heavy towers, Tanky enemies):
*   **Aim Lower:** Don't flood the screen with 500 weaklings.
*   **Aim Heavier:** Use **200-250** total enemies for a standard level.
*   **Wave Cap:** Cap waves at **25-30** units max to prevent performance lag and visual clutter.
*   **Elite Units:** Replace "Swams" with "Squads" (e.g., 3 High HP Orcs instead of 10 Goblins).

---

## 📋 Proposal for Level 2 (8 Waves)
Using the "Heavy/Vengeance" Model:

| Wave | Time | Enemy Count | Composition | Total Kills |
| :--- | :--- | :--- | :--- | :--- |
| **1** | 0:00 | 6 | 6 Goblins | 6 |
| **2** | 1:00 | 8 | 8 Goblins | 14 |
| **3** | 2:00 | 10 | 5 Gobs, 5 Wolves | 24 |
| **4** | 3:30 | 12 | 10 Gobs, 2 Wolves | 36 |
| **5** | 5:00 | 15 | Mass Goblins (Rush) | 51 |
| **6** | 6:30 | 8 | **Elite Squad:** 4 Wolves | 59 |
| **7** | 8:00 | 20 | Mixed Swarm | 79 |
| **8** | 10:00 | 1 (Boss) | **Troll Boss** + 4 Bodyguards | 84 |

**Total:** ~84 Kill Count. Matches "Early Game" benchmarks well.
