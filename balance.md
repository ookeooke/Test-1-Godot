# ⚖️ Game Balance Matrix

> **Core Philosophy:** "Impactful & Strategic"
> Similar to *Kingdom Rush: Vengeance*. Towers hit hard but fire slower. Enemies are durable.
> Every tower placement and upgrade should feel like a significant power spike.

## 🏹 Towers (Level 1 Baseline)
*Live values from `tower_data.gd`*

| Tower | Role | Damage | Rate | DPS | Range | Cost | Special |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Archer** | Single Target DPS | **8** | 1.2s | 6.6 | 280 | **70g** | High consistent damage. |
| **Barracks**| Blocker / Stalin | **10** | 1.0s | 10 | 250 | **70g** | Spawns 3 Soldiers (100 HP). |
| **Mage** | Armor Pierce / AoE | **6** | 0.8s | 4.8 | 300 | **75g** | Small splash (80px). Ignores armor. |
| **Artillery**| Crowd Control | **20** | 0.4s | 8.0 | 350 | **100g**| Slow fire, big AoE. |

### 📈 Progression Scaling (Archer Example)
| Level | Dmg | DPS | Cost | Efficiency |
| :--- | :--- | :--- | :--- | :--- |
| **L1** | 8 | 6.6 | 70 | 1.00 |
| **L2** | 12 | 16.8 | +60 | 1.80 (Big jump!) |
| **L3** | 18 | 28.8 | +90 | 2.50 |
| **L4** | 28 / 18 | varies | +200 | Specialization |

## 👹 Bestiary (Enemies)
*Live values from `goblin_scout.gd` / `wolf_runner.gd`*

| Enemy | Archetype | HP | Speed | Armor | Gold | TTK (Archer L1) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Goblin** | Grunt | **35** | 45 | 0% | 5 | 5 hits (6.0s) |
| **Wolf** | Speedster | **80** | 81 | 10% | 7 | 12 hits (14.4s) |
| **Troll** | Boss/Tank | **200+**| ~30 | High | 50+ | Requires DPS focus. |

> **Balance Note:**
> *   **Goblins** are quite tanky (5 hits). Consider reducing to 25 HP for faster "trash mob" clearing.
> *   **Wolves** are very dangerous: Fast + High HP. They are the primary threat to leaks.

## 🌊 Waves & Economy

### 💰 Gold Economy
*   **Starting Gold:** 500
*   **Tower Cost:** ~70-100 Gold.
*   **Kill Reward:** ~5-7 Gold.
*   **Ratio:** ~14 kills = 1 new tower.

### ⚔️ Difficulty Tuning
*   **Early Game:** Relies on Barracks to stall wolves while Archers chip away HP.
*   **Mid Game:** Requires AOE (Mage/Artillery) as enemy density increases.
