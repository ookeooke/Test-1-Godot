# Ranger Hero Skills

This folder contains skill resources for the Ranger hero.

## Creating Skill Resources

### In Godot Editor:

1. Right-click in this folder
2. Select "New Resource"
3. Search for "HeroSkillData"
4. Configure as shown below

---

## Skill Configurations

### ranger_multishot.tres (ACTIVE SKILL)

```
skill_id: "ranger_multishot"
skill_name: "Multishot"
description: "Fire 5-7 arrows at random enemies in range. Deals 100-150% damage per arrow."
skill_type: ACTIVE
category: COMBAT

unlock_cost: 500
max_upgrade_level: 3
upgrade_costs: [300, 500]

cooldown: 30.0
duration: 0.0 (instant)

# Upgrade scaling
damage_multiplier_per_level: [1.0, 1.2, 1.5]
cooldown_per_level: [30.0, 25.0, 20.0]
```

**Implementation:**
Already implemented in `ranger_hero._execute_multishot()`
- Fires 5 arrows at level 1, 7 at level 2, 9 at level 3
- Targets random enemies
- Visual flash effect

---

### ranger_damage_boost.tres (PASSIVE SKILL)

```
skill_id: "ranger_damage_boost"
skill_name: "Sharp Arrows"
description: "Increases ranged damage by 10/20/30/50/80%"
skill_type: PASSIVE
category: COMBAT

unlock_cost: 200
max_upgrade_level: 5
upgrade_costs: [200, 300, 500, 800]

# Effects
damage_multiplier_per_level: [1.1, 1.2, 1.3, 1.5, 1.8]
```

**Implementation:**
Automatically applied by SkillManager when unlocked.
- Level 1: +10% damage
- Level 2: +20% damage
- Level 3: +30% damage
- Level 4: +50% damage
- Level 5: +80% damage

---

### ranger_health_boost.tres (PASSIVE SKILL)

```
skill_id: "ranger_health_boost"
skill_name: "Vitality"
description: "Increases maximum health"
skill_type: PASSIVE
category: DEFENSE

unlock_cost: 150
max_upgrade_level: 3
upgrade_costs: [150, 300]

# Effects
max_health_bonus: 50.0 (level 1)
```

**Note:** Currently only level 1 implemented.
For per-level scaling, add:
```
max_health_bonus_per_level: [50, 100, 200]
```

And modify SkillManager to use this array.

---

### ranger_speed_boost.tres (PASSIVE SKILL)

```
skill_id: "ranger_speed_boost"
skill_name: "Swift Feet"
description: "Increases movement speed by 10/20/30%"
skill_type: PASSIVE
category: MOBILITY

unlock_cost: 100
max_upgrade_level: 3
upgrade_costs: [100, 200]

# Effects
movement_speed_multiplier: 1.1 (level 1)
```

**Note:** For per-level, you can use multiple resources or modify SkillManager to handle arrays.

---

## Additional Skill Ideas

### ranger_crit_chance.tres (PASSIVE)
```
skill_id: "ranger_crit_chance"
skill_name: "Deadeye"
description: "10/20/30% chance to deal double damage"
crit_chance: 0.1 per level
```

### ranger_attack_speed.tres (PASSIVE)
```
skill_id: "ranger_attack_speed"
skill_name: "Rapid Fire"
description: "Attack 10/20/30% faster"
attack_speed_multiplier: 1.1 per level
```

### ranger_smoke_bomb.tres (ACTIVE)
```
skill_id: "ranger_smoke_bomb"
skill_name: "Smoke Bomb"
description: "Disengage from melee combat and become untargetable for 3s"
cooldown: 45.0
duration: 3.0
```

### ranger_rally_call.tres (ACTIVE)
```
skill_id: "ranger_rally_call"
skill_name: "Rally Call"
description: "Boost nearby towers' attack speed by 25% for 10 seconds"
cooldown: 60.0
duration: 10.0
```

---

## Cost Balancing

Recommended unlock costs:
- **Passive Tier 1** (small bonuses): 100-200 gold
- **Passive Tier 2** (medium bonuses): 300-500 gold
- **Passive Tier 3** (large bonuses): 600-1000 gold
- **Active Tier 1** (utility): 300-500 gold
- **Active Tier 2** (powerful): 600-1000 gold

Recommended currency rewards:
- **Complete level (1 star)**: 100 gold
- **Complete level (2 stars)**: 150 gold
- **Complete level (3 stars)**: 200 gold

---

## Testing Commands

Open Godot's console during gameplay and run:

```gdscript
# Give yourself gold
SaveManager.add_currency(1000)

# Unlock a skill manually
SaveManager.unlock_hero_skill("ranger", "ranger_multishot")

# Check skill level
print(SaveManager.get_hero_skill_level("ranger", "ranger_multishot"))

# Upgrade skill
SaveManager.upgrade_hero_skill("ranger", "ranger_multishot")
```

---

## Icon Resources

Recommended icon size: **64x64 pixels**

You can use:
- Godot's built-in icons (for prototyping)
- Free icon packs (e.g., Kenney.nl)
- Custom pixel art

Assign icon in resource inspector:
```
icon: [drag PNG file here]
```
