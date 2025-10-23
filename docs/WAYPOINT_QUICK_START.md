# Waypoint System - QUICK START ⚡

## 5-Minute Setup

### 1. Add Waypoints to Your Level (2 minutes)

**In Godot Editor:**

1. Open your level scene (e.g., `level_01.tscn`)
2. Add these nodes:
   ```
   Level_01
   ├── Waypoints (Node2D)
   │   └── (waypoints go here)
   └── RoadRenderer (Node2D)
   ```

3. **Add Waypoints:**
   - Right-click **Waypoints** → **Instantiate Child Scene**
   - Browse to: `res://scenes/pathfinding/path_waypoint.tscn`
   - Rename it: `WP_Start`
   - **Repeat** 5-10 times for your path
   - Name them: `WP_01`, `WP_02`, `WP_03`, `WP_End`

4. **Add Road Renderer:**
   - Right-click level root → **Instantiate Child Scene**
   - Browse to: `res://scenes/pathfinding/road_renderer.tscn`

### 2. Position Waypoints (1 minute)

1. Select each waypoint in Scene tree
2. Click and drag in viewport to position along desired path
3. **Tip:** Use grid snap (View → Snap to Grid) for aligned paths

### 3. Connect Waypoints (1 minute)

For each waypoint (except the last):

1. Select waypoint (e.g., `WP_Start`)
2. In Inspector, find **"Next Waypoints"**
3. Click **Array size +** button
4. Drag next waypoint into the slot (e.g., `WP_01`)
5. **Repeat** for all waypoints

**Result:** Arrows appear showing connections!

### 4. Configure Wave Manager (1 minute)

1. Select **WaveManager** node
2. In Inspector:
   - **Use Waypoint System:** ☑️ **CHECK THIS**
   - **Start Waypoint:** Drag `WP_Start` here
   - **Enemy Path:** Leave empty

### 5. Test! (Press F5)

✅ Enemies spawn at first waypoint
✅ Road appears between waypoints
✅ Enemies spread out naturally
✅ Enemies stay inside road

---

## Adjust Road Width

Select any waypoint:
- **Inspector → Road Width:** Change number
- Default: `100`
- Narrow: `60-80`
- Wide: `120-180`

**The road automatically adjusts in real-time!**

---

## Quick Tips

### ✅ DO:
- Name waypoints sequentially
- Use 8-15 waypoints per path
- Vary road width for strategy
- Test early and often

### ❌ DON'T:
- Forget to connect waypoints (no arrows = broken)
- Make road width too small (< 50px)
- Skip the last waypoint's empty array
- Place waypoints too close together (< 50px)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No road appears | Check waypoints have `path_waypoint.gd` script |
| Enemies don't spawn | Check `use_waypoint_system = true` |
| Enemies walk straight line | Not enough waypoints, add more |
| Road not visible in game | RoadRenderer → `visible_in_game = true` |

---

## Next Steps

✅ **Read full guide:** [docs/WAYPOINT_SYSTEM_GUIDE.md](WAYPOINT_SYSTEM_GUIDE.md)
✅ **Add branching paths** - Multiple "next waypoints"
✅ **Customize road colors** - RoadRenderer inspector
✅ **Add soldier placement** - Already implemented!

---

## Visual Example

```
Your Level:

    👾 [WP_Start] -----> [WP_01] -----> [WP_02]
         road_width:80    road_width:120    road_width:100
                                              |
                                              v
                                           [WP_03] -----> 🏁 [WP_End]
                                         road_width:60     road_width:100
```

**The brown road automatically draws between them!**

---

## File Locations

- **Waypoint Scene:** `scenes/pathfinding/path_waypoint.tscn`
- **Road Renderer:** `scenes/pathfinding/road_renderer.tscn`
- **Script Files:**
  - `scripts/pathfinding/path_waypoint.gd`
  - `scripts/pathfinding/road_renderer.gd`

---

## That's It! 🎉

Your waypoint system is ready!

**Enemies will now:**
- ✅ Spread out naturally
- ✅ Stay inside the road
- ✅ Look organic and alive

**And you can:**
- ✅ Manually design any path shape
- ✅ Adjust road width per section
- ✅ See the road visually
- ✅ Place soldiers only on roads (automatic validation)
