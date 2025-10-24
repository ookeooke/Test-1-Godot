# Project Cleanup Summary
**Date:** October 24, 2025
**Purpose:** Remove duplicate/conflicting level configurations and establish single level path

## What Was Deleted

### Wave Directories (4 locations)
- `data/waves/` - Old fallback 10-wave version (hardcoded in scene)
- `data/levels/forest/` - Forest campaign waves
- `data/levels/desert/` - Unused desert campaign
- `data/levels/mountains/` - Unused mountains campaign

### Config Files (3 campaigns + configs)
- `data/level_configs/forest/` - forest_01_config.tres, forest_02_config.tres
- `data/level_configs/desert/` - All desert configs
- `data/level_configs/mountains/` - All mountains configs
- `data/level_configs/level_02_config.tres` - Duplicate level config

### Campaign Files (3 campaigns)
- `data/campaigns/forest_campaign.tres`
- `data/campaigns/desert_campaign.tres`
- `data/campaigns/mountains_campaign.tres`

### Scene Files (1 level)
- `scenes/levels/level_02.tscn` - Duplicate level scene

## Final Project Structure

```
data/
  campaigns/
    main_campaign.tres ✓ (VERIFIED - references level_01_config.tres)

  level_configs/
    level_01_config.tres ✓ (ONLY config - references 16 waves)

  levels/
    level_01/
      waves/
        wave_01.tres through wave_16.tres ✓ (All 16 waves present)
    level_01_data.tres ✓ (Level node display data)
    level_02_data.tres (Level node data - scene deleted but data kept)

scenes/
  levels/
    level_01.tscn ✓ (ONLY level scene)
```

## Verified References

### main_campaign.tres → level_01_config.tres
```tres
levels = Array[Resource("res://scripts/resources/level_config.gd")]([ExtResource("2_level01")])
```
Reference: `res://data/level_configs/level_01_config.tres` ✓

### level_01_config.tres → 16 waves
```tres
waves = Array[Resource("res://scripts/resources/wave_data.gd")]([
  ExtResource("3_w01"),   # wave_01.tres
  ExtResource("4_w02"),   # wave_02.tres
  ...
  ExtResource("18_w16")   # wave_16.tres
])
```
All references point to: `res://data/levels/level_01/waves/wave_XX.tres` ✓

## Game Flow (Now Unambiguous)

1. **Menu** → Level Select Screen
2. **Level Select** → User clicks Level 1 node
3. **LevelManager** loads `level_01_config.tres`
4. **Scene loads** `level_01.tscn`
5. **WaveManager._ready()** overwrites hardcoded waves with config waves
6. **Game plays** 16-wave balanced version with 200g start

## Why This Works

The game has a dual loading system:
- **Fallback**: Scene hardcodes waves for F5 quick testing
- **Runtime**: WaveManager dynamically loads from LevelConfig (overwrites hardcoded)

Since all normal gameplay goes through Level Select → LevelManager, the config's waves are always used. There is now only ONE config and ONE set of waves, eliminating all ambiguity.

## Testing Checklist

- [ ] Launch game (no resource errors)
- [ ] Level Select displays Level 1
- [ ] Click Level 1 → game loads correctly
- [ ] Starting gold = 200 (was 150)
- [ ] All 16 waves play in sequence
- [ ] Wave progression works (HP multipliers scale correctly)
- [ ] Final boss wave (Wave 16) triggers
- [ ] Victory screen shows after Wave 16

## Balance Changes Recap

The cleanup preserves all balance changes from the overhaul:
- **Starting gold**: 200 (was 150)
- **Tower cost**: 80 (was 100)
- **Hero damage**: 12 (was 10)
- **Hero attack speed**: 0.55s (was 0.6s)
- **Wave count**: 16 waves (was 10)
- **HP scaling**: 1.0x → 12.0x progression
- **Wave bonuses**: 12g/13g/15g progressive (was 20g flat)

See `BALANCE_OVERHAUL_SUMMARY.md` for full details.

## Rollback Instructions (If Needed)

If something breaks:
1. Check git status: `git status`
2. Revert cleanup: `git checkout HEAD -- data/ scenes/levels/`
3. The old structure will restore with all duplicate levels

Current git branch: `main`
Last commit before cleanup: Check `git log` for hash
