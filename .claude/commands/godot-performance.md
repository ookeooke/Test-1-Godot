# Balance & Performance Check

Check the balance debug exports directory for recent performance data:

`C:\Users\ollil\AppData\Roaming\Godot\app_userdata\Test 1\balance_debug\exports\`

Steps:
1. List all files in the exports directory (sorted by date)
2. If CSV/JSON files exist:
   - Read the most recent export file
   - Analyze the data for performance issues:
     - Low FPS (below 30)
     - Towers with low DPS
     - Enemies that are too tanky or too weak
     - Gold economy imbalances
   - Suggest specific optimizations or balance tweaks
3. If no exports exist:
   - Report "⚠️ No balance data found"
   - Remind user: "Press F4 in-game to export balance data"

Format output as:
## 📊 Performance Metrics
- [FPS, frame times, etc.]

## ⚖️ Balance Issues
- [towers, enemies, economy]

## 🔧 Recommendations
- [specific fixes with values]
