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
