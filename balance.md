# ⚖️ Game Balance Matrix (Arcade Mode)

> **Core Philosophy:** "High Impact & Chaos"
> We have shifted to an **Arcade-style balance**.
> *   **Towers:** High Damage (40+ DPS). Strong immediate impact.
> *   **Enemies:** High HP (200+ base). Numerous but killable.
> *   **Economy:** Gold is scarce relative to HP (2-5% ratio). rely on defeating mass numbers.

## 🏹 Towers (High-DPS Standard)
*Live values from `tower_data.gd`*

| Tower | Role | Damage | Rate | DPS | Range | Cost | Efficiency |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Archer** | Single Target | **40** | 1.0s | **40** | 280 | **50g** | **0.80** Dmg/Gold |
| **Mage** | Armor Pierce | **60** | 1.5s | **40** | 300 | **75g** | **0.53** Dmg/Gold |
| **Artillery**| Area Damage | **30** | 2.0s | **15** | 350 | **120g** | High AoE Value |

### 📈 Progression Scaling (Archer Example)
| Level | Dmg | Attack Speed | DPS | Cost | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **L1** | 40 | 1.0s | 40 | 50g | Base |
| **L2** | 60 | 0.9s | 66 | +80g | ~65% DPS increase |
| **L3** | 90 | 0.8s | 112 | +120g | Massive spike |

## 👹 Bestiary (Enemies)
*Live values from `goblin_scout.gd` etc.*

| Enemy | Archetype | Base HP | Speed | Gold | Threat |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Goblin** | Swarm | **200** | 45 | **5g** | Low individually, dangerous in groups. |
| **Wolf** | Runner | **150** | 100 | **8g** | Fast! Requires stalling. |
| **Troll** | Tank | **800** | 30 | **20g** | Sponges damage. |

> **Wave 8 Scaling:** In Arcade Mode, Wave 8 enemies can have up to **15x Base HP** (e.g., 3000 HP Goblins).

## 📊 Balance Analyzer Targets
*Configured in `scripts/debug/balance_analyzer.gd`*

| Metric | Target Range | Description |
| :--- | :--- | :--- |
| **Gold / HP** | `0.02 - 0.05` | Enemies drop 2% to 5% of their Max HP in Gold. |
| **Tower Efficiency** | `30.0` | 1 Gold spent should yield ~30 Damage over time. |
| **Uptime** | `> 50%` | Towers should be firing constantly in Arcade mode. |

## 📂 Project Structure & Data

### 🌊 Wave Configuration
Waves are now stored as individual Resources (`.tres`) for modularity.

*   **Location:** `res://data/levels/level_XX/waves/`
*   **Format:** `wave_01.tres`, `wave_02.tres`...
*   **Editor:** Editable via Inspector. Contains:
    *   `wave_number`
    *   `enemies` (List of scenes + counts)
    *   `interval` (Spawn rate)
    *   `hp_multiplier` (Difficulty scaling)

### 🦸 Hero Metrics (Post-Game)
We track detailed stats to find the MVP:
1.  **Total Damage:** Raw output.
2.  **DPM (Damage Per Minute):** Consisteny metric.
3.  **Kill Count:** Last-hit tracking.
4.  **Boss Damage:** Specific damage to Boss-type units.
5.  **MVP Badge:** Given to the hero with highest damage in a specific wave.

## 📝 Future Agenda
*   **Hero Skills:** Re-balance cooldowns for 20s-90s wave durations.
*   **Boss Mechanics:** Add unique boss abilities (Stun towers, Summon minions).
*   **Shop System:** Implement between-level upgrades using Stars.
