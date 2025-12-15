# ⏱️ Level Duration & Pacing Research

> **Executive Summary:**
> *   **Mobile Sweet Spot:** 12-18 minutes per level.
> *   **PC Expectation:** 20-40 minutes per level.
> *   **Your Target:** Aim for **15-20 minutes** (Wave 12-15). This bridges the gap between casual mobile play and PC depth.

## 📊 Industry Benchmarks

### 🛡️ Kingdom Rush (The "Gold Standard")
*   **Campaign Length:** ~8 Hours for 12-15 levels.
*   **Avg Level Time:** **30-40 Minutes**.
*   **Context:** Kingdom Rush was released when mobile games were deeper. Today, 40 minutes is considered "Long" for mobile but perfect for Steam.

### 🎈 Bloons TD 6 (The "Replayability King")
*   **Easy (40 Rounds):** ~6-10 Minutes.
*   **Medium (60 Rounds):** ~15-20 Minutes.
*   **Hard (80 Rounds):** ~25-30 Minutes.
*   **Context:** Offers variable lengths. Players choose how much time to commit.

### 📱 Modern Mobile Habits (2024 Data)
*   **Avg Session:** 4-5 minutes (Casual) vs 15-25 minutes (Mid-Core Strategy).
*   **Optimization:** Mobile players often play during commutes or breaks. A 40-minute level without "Save & Quit" is a churn risk.

---

## 📐 Recommendations for Your Game

Since you are targeting **Mobile First**, later **Steam**:

### 1. The "15-Minute Rule" (Recommended)
Design levels to be consistently beatable in **15 to 18 minutes**.
*   **Why?** Long enough to feel "epic" and strategic (PC friendly), but short enough for a long bus ride or lunch break (Mobile friendly).

### 2. Wave Count Guidelines
To achieve these times (assuming 1 min per wave + setup time):

| Stage of Game | Target Time | Wave Count | Purpose |
| :--- | :--- | :--- | :--- |
| **Tutorial / L1** | 3-5 Mins | 3-5 Waves | "Snackable" hook. Teach mechanics fast. |
| **Early Game** | 8-12 Mins | 8-10 Waves | Low commitment. distinct experimentation. |
| **Mid Game** | **15-18 Mins**| **12-15 Waves**| **The Core Loop.** Standard difficulty. |
| **Boss Level** | 20-25 Mins| 15+ Boss | The "Sit Down" experience. Epic finale. |

### 3. Feature Suggestions
*   **2x Speed Button:** ABSOLUTELY ESSENTIAL. PC players hate waiting. Mobile players value their time.
*   **Wave "Call Early" Button:** Allows skilled players to speed up the game manually (and maybe earn extra gold).
*   **Mid-Level Save:** If levels > 20 mins, you *must* save state. If < 15 mins, you can get away without it.

---

## 💡 Implementation for `Level_02`
*   **Current State:** Level 1 was ~3 waves.
*   **Recommendation for Level 2:**
    *   **Target:** 8-10 Minutes.
    *   **Waves:** 8 Waves.
    *   **Pacing:** Intro new enemy (Wolf) -> Mix (Goblin+Wolf) -> Mini-Swarm.
