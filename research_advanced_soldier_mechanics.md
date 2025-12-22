# Research: Advanced Soldier Mechanics Options
**Context:** The user wants "Ultra Hard Thinking" on how to evolve the current simple soldier mechanics into something professional-grade (ala Kingdom Rush or Iron Marines). The goal is to maximize "Game Feel" and "Strategic Depth".

## Option 1: The "Engagement Slot" System (The Kingdom Rush Model)
*The Industry Standard for Precision Defense.*

**Concept:**
Instead of checking distance, enemies have specific "Slots" (North, South, East, West) around them. Soldiers reserve a slot and pathfind to that *exact point*.

**Why it works (The Math):**
*   **Readability:** It prevents unit stacking. You can always see exactly how many soldiers are fighting an enemy.
*   **Predictability:** Players know that 1 Goblin = 2 Slots. If they send 3 soldiers, one will just wait. This adds strategic depth to unit count.
*   **The "Snap":** When a soldier locks a slot, they switch to a `CHARGING` state (2x speed), creating a satisfying "snap" into combat.

**Technical Reference:**
*   See *Kingdom Rush* wiki on "Blocking": "Enemies have a block count. Unblocked enemies move at full speed. Blocked enemies stop."
*   See *Warcraft 3* "Surround" mechanics: Units try to fill the collision circle perimeter.

**Pros:** Cleanest visuals, best for "puzzle" gameplay.
**Cons:** Can feel rigid if not animated well.

## Option 2: The "Aggro & Kite" System (The MMORPG/RTS Model)
*The Choice for Dynamic Combat.*

**Concept:**
Soldiers act like MMO Tanks. They have an "Aggro Radius" and a "Leash Range".
*   **Taunt:** Upon entering combat, they "Taunt" the enemy, forcing the enemy to attack *them* instead of the base.
*   **Kiting:** If the soldier's health gets low, they can "Backstep" (retreat 50px) to lure the enemy further back or stall for regen.

**Why it works:**
*   **Emergent Gameplay:** A low-HP soldier might naturally pull an enemy back into tower range while trying to save itself.
*   **Hero Synergy:** Works perfectly with Healers or Buff mages.

**Technical Reference:**
*   *Iron Marines*: Units have active skills and can be repositioned mid-combat to "kite" shots.
*   *World of Warcraft*: Threat tables and leash ranges.

**Pros:** Extremely dynamic, feels "alive".
**Cons:** High cognitive load for player (micromanagement), complex to code (AI behavior trees).

## Option 3: The "Physics Boids" System (The Total War Model)
*The Choice for Epic Scale.*

**Concept:**
Abandon direct 1v1 targeting. Use `NavigationAgent2D` with `avoidance` turned up.
*   **The Mosh Pit:** Soldiers and Enemies push each other. Large enemies have high "mass" and push soldiers aside unless there are enough soldiers to "brace" (sum of mass).
*   **Momentum:** Charges deal damage based on Velocity * Mass.

**Why it works:**
*   **Visceral:** You *feel* the weight of a Troll pushing through a line of weak Militia.
*   **Scale:** Handles 50 vs 50 battles easily.

**Technical Reference:**
*   *Total War*: Unit mass and bracing.
*   *They Are Billions*: Collision-based flow.

**Pros:** Looks amazing for hordes.
**Cons:** Messy, hard to predict (enemies might "slip" through), demanding on physics engine.

---

## The Recommendation: "Hybrid Slot System" (Option 1+)

We should implement **Option 1 (Slots)** because it fits the *Kingdom Rush* aesthetic the user loves, but add a touch of **Option 2 (Aggro)** for the "Ultra Hard" feel.

**Specific Implementation steps for Godot:**
1.  **Enemies:** Add a `EngagementSlotManager` (Node). It manages 2-4 `Marker2D` points orbiting the enemy.
2.  **Soldiers:**
    *   Find nearest enemy with `free_slot`.
    *   `request_slot(enemy)` -> Returns the specific `Vector2` of the slot.
    *   **State Change:** `INTERCEPT` (Speed 300). Sprint to that point.
    *   **Arrival:** Snap to position, play `Attack_Initiate` animation.
3.  **The Juice:** When a soldier *arrives* at a slot, shake the screen (1px) and flash the enemy. This sells the impact.
