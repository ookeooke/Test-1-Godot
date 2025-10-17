# Setup Checklist - New Level System

## ✅ What's Been Done

- ✅ Created LevelConfig resource class
- ✅ Created CampaignData resource class
- ✅ Created LevelManager autoload script
- ✅ Reorganized wave files into `data/levels/level_01/waves/`
- ✅ Created `level_01_config.tres` with all waves
- ✅ Created `main_campaign.tres`
- ✅ Updated WaveManager to use LevelConfig
- ✅ Created documentation (LEVEL_ORGANIZATION_GUIDE.md)

## 🔧 What You Need to Do in Godot

### Step 1: Add LevelManager as Autoload (Required)

1. **Open Godot**
2. **Go to**: Project → Project Settings → Autoload tab
3. **Click the folder icon** next to "Path"
4. **Navigate to**: `res://scripts/autoloads/level_manager.gd`
5. **Set Node Name**: `LevelManager` (exactly this name!)
6. **Click "Add"**
7. **Click "Close"**

### Step 2: Assign Campaign to LevelManager (Required)

1. **In Scene tree**, click on the **"(Global)" section** at the bottom
2. You should see **LevelManager** node
3. **Select it**
4. **In Inspector**, find the **Campaigns** property
5. **Set Size to 1**
6. **Drag** `data/campaigns/main_campaign.tres` into slot [0]
7. **Save** (Ctrl+S)

### Step 3: Fix Level Scene Wave References (Choose One)

**Option A: Use LevelManager (Recommended)**
1. Open `scenes/levels/level_01.tscn`
2. Select **WaveManager** node
3. In Inspector, find **Waves** array
4. **Clear it** (set Size to 0)
   - WaveManager will automatically load from LevelConfig
5. Save scene

**Option B: Keep Manual Assignment (Testing)**
1. Keep waves manually assigned in Inspector
2. Level will use manual waves if LevelManager.current_level is null
3. Useful for testing without full system

### Step 4: Test the System

**Test Method 1: Quick Load**
1. Open Godot Script Editor
2. Create a test script or use debug console:
```gdscript
LevelManager.quick_load_level("level_01")
```

**Test Method 2: Direct Scene Load**
1. Just run `level_01.tscn` (F6)
2. Should work with either manual waves or LevelConfig

**Test Method 3: From Level Select**
1. Update your level select screen to use:
```gdscript
func _on_level_button_pressed():
    LevelManager.load_level("main", "level_01")
```

## ⚠️ Common Issues

### "LevelManager: No waves assigned!"
**Solution**: Make sure you completed Step 2 (Assign Campaign)

### "Invalid get index 'current_level' (on base: 'Nil')"
**Solution**: LevelManager not added as Autoload (Step 1)

### Level loads but no enemies spawn
**Solution**: Check that `level_01_config.tres` has all 10 waves assigned

### Wrong starting gold/lives
**Solution**:
- Check `level_01_config.tres` → Starting Gold/Lives
- Make sure LevelManager is loading the level

## 🎮 Testing Checklist

Once setup is complete, verify:

- [ ] LevelManager appears in Autoload list
- [ ] Campaign is assigned to LevelManager
- [ ] Level loads without errors
- [ ] Starting gold is 100 (from config)
- [ ] Starting lives is 20 (from config)
- [ ] Wave 1 starts after 2 seconds
- [ ] Enemies spawn correctly
- [ ] All 10 waves play
- [ ] Victory screen shows at the end
- [ ] Console shows: "WaveManager: Loading waves from LevelConfig: Forest Path"

## 📚 Next Steps

After everything works:

1. **Create level_02** following LEVEL_ORGANIZATION_GUIDE.md
2. **Update level select screen** to use LevelManager
3. **Update victory screen** to use `LevelManager.load_next_level()`
4. **Add more campaigns** (bonus levels, challenge modes, etc.)

## 🆘 Need Help?

- Read [LEVEL_ORGANIZATION_GUIDE.md](LEVEL_ORGANIZATION_GUIDE.md) for detailed instructions
- Read [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for file organization
- Check console output for error messages
- Verify LevelManager is in Autoload list
- Ensure all `.tres` files are properly saved
