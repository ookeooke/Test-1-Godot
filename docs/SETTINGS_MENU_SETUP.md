# Settings Menu Setup Guide

This guide explains how to create and integrate the UI Scale Settings menu into your game.

## Step 1: Create Settings Menu Scene

1. Open Godot Editor
2. Create new scene (Scene → New Scene)
3. Add root node: **Control** (rename to "SettingsMenu")
4. Set anchors: **Full Rect** (fills screen)
5. Set mouse filter: **Stop** (blocks clicks to game behind it)

### Node Structure

```
SettingsMenu (Control)
├─ Panel (Panel)
│  ├─ VBox (VBoxContainer)
│  │  ├─ TitleLabel (Label)
│  │  ├─ UIScaleControl (HBoxContainer)
│  │  │  ├─ NameLabel (Label)
│  │  │  ├─ Slider (HSlider)
│  │  │  └─ ValueLabel (Label)
│  │  ├─ Spacer (Control)
│  │  └─ CloseButton (Button)
```

### Node Configuration

**SettingsMenu (Control):**
- Anchors: All = 0.5
- Offsets: Left=-400, Top=-300, Right=400, Bottom=300
- Theme: Use main_theme.tres

**Panel (Panel):**
- Anchors: Full Rect
- Theme Type Variation: "PopupPanel" (if available)

**VBox (VBoxContainer):**
- Anchors: Full Rect
- Margins: All = 20
- Separation: 20

**TitleLabel (Label):**
- Text: "Settings"
- Horizontal Alignment: Center
- Font Size: 48 (will auto-scale)

**UIScaleControl (HBoxContainer):**
- Separation: 10

**NameLabel (Label):**
- Text: "UI Scale:"
- Minimum Size: X = 150

**Slider (HSlider):**
- Min Value: 0.5
- Max Value: 2.0
- Step: 0.1
- Size Flags Horizontal: Expand Fill

**ValueLabel (Label):**
- Text: "100%"
- Horizontal Alignment: Right
- Minimum Size: X = 60

**CloseButton (Button):**
- Text: "Close"
- Minimum Size: Y = 60

## Step 2: Attach Script

1. Select root node (SettingsMenu)
2. Click "Attach Script" button
3. Choose existing script: `res://scripts/ui/settings_menu.gd`
4. Click "Load"

## Step 3: Connect to SaveManager

If you don't have `SaveManager.get_setting()` and `save_setting()` yet, add these functions:

### Option A: Add to Existing SaveManager

```gdscript
# In scripts/autoloads/save_manager.gd

## Store for temporary settings (not saved to profile)
var game_settings: Dictionary = {}

## Get a game setting value
func get_setting(key: String, default_value = null):
    if game_settings.has(key):
        return game_settings[key]
    return default_value

## Save a game setting value
func save_setting(key: String, value):
    game_settings[key] = value
    _save_settings_to_disk()

## Save settings to disk
func _save_settings_to_disk():
    var settings_path = "user://settings.cfg"
    var config = ConfigFile.new()

    # Save all settings
    for key in game_settings.keys():
        config.set_value("Settings", key, game_settings[key])

    # Write to disk
    var err = config.save(settings_path)
    if err != OK:
        push_error("[SaveManager] Failed to save settings: %d" % err)

## Load settings from disk (call in _ready)
func load_settings():
    var settings_path = "user://settings.cfg"
    var config = ConfigFile.new()

    var err = config.load(settings_path)
    if err != OK:
        print("[SaveManager] No settings file found (first launch)")
        return

    # Load all settings
    for key in config.get_section_keys("Settings"):
        game_settings[key] = config.get_value("Settings", key)

    print("[SaveManager] Settings loaded: %s" % game_settings)
```

### Option B: Simplified (If No SaveManager)

If you don't want to modify SaveManager, create a simple settings file:

```gdscript
# Create: scripts/autoloads/settings.gd
extends Node

var ui_scale_multiplier: float = 1.0

func _ready():
    load_settings()

func load_settings():
    var config = ConfigFile.new()
    var err = config.load("user://settings.cfg")
    if err == OK:
        ui_scale_multiplier = config.get_value("UI", "scale_multiplier", 1.0)

func save_settings():
    var config = ConfigFile.new()
    config.set_value("UI", "scale_multiplier", ui_scale_multiplier)
    config.save("user://settings.cfg")
```

Then in `settings_menu.gd`, replace SaveManager calls with:
```gdscript
# Load
var saved_multiplier = Settings.ui_scale_multiplier

# Save
Settings.ui_scale_multiplier = value
Settings.save_settings()
```

## Step 4: Add to Game

### From Main Menu

Add a "Settings" button to your main menu:

```gdscript
# In main_menu.gd
@onready var settings_button: Button = $Panel/VBox/SettingsButton

func _ready():
    settings_button.pressed.connect(_on_settings_pressed)

func _on_settings_pressed():
    var settings = preload("res://scenes/ui/settings_menu.tscn").instantiate()
    get_tree().root.add_child(settings)
```

### From Pause Menu

Add a "Settings" button to pause menu:

```gdscript
# In pause_menu.gd
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton

func _ready():
    settings_button.pressed.connect(_on_settings_pressed)

func _on_settings_pressed():
    var settings = preload("res://scenes/ui/settings_menu.tscn").instantiate()
    get_tree().root.add_child(settings)
    # Optional: Don't remove pause menu, just hide it
    visible = false
```

### Keyboard Shortcut

Add a dedicated settings key (F12):

```gdscript
# In a always-active autoload or main game script
func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F12:
            var settings = preload("res://scenes/ui/settings_menu.tscn").instantiate()
            get_tree().root.add_child(settings)
            get_viewport().set_input_as_handled()
```

## Step 5: Save Scene

1. Save scene as: `res://scenes/ui/settings_menu.tscn`
2. Test in-game:
   - Press F5 to run
   - Open settings menu
   - Adjust UI scale slider
   - Verify UI resizes in real-time
   - Close and reopen game
   - Verify preference was saved

## Testing Checklist

- [ ] Slider moves smoothly from 50% to 200%
- [ ] Label updates to show percentage (50%, 60%, ..., 200%)
- [ ] UI scales in real-time as slider moves
- [ ] Text remains readable at all scales
- [ ] Buttons remain clickable at all scales
- [ ] Preference saves when changed
- [ ] Preference loads correctly on next launch
- [ ] ESC key closes settings menu
- [ ] Close button works
- [ ] Settings menu blocks clicks to game behind it

## Advanced: Add More Settings

Once the basic structure is in place, you can add more settings:

```gdscript
# Example: Master volume slider
@onready var volume_slider: HSlider = $Panel/VBox/VolumeControl/Slider

func _ready():
    # ... existing code ...

    # Setup volume slider
    volume_slider.min_value = 0.0
    volume_slider.max_value = 1.0
    volume_slider.value = AudioServer.get_bus_volume_db(0)
    volume_slider.value_changed.connect(_on_volume_changed)

func _on_volume_changed(value: float):
    AudioServer.set_bus_volume_db(0, value)
    if SaveManager:
        SaveManager.save_setting("master_volume", value)
```

## Troubleshooting

**Issue:** Slider doesn't affect UI size
**Fix:** Verify UIScaleManager is an autoload in Project Settings

**Issue:** Settings don't save
**Fix:** Check that SaveManager.save_setting() is called when slider changes

**Issue:** UI too large/small at startup
**Fix:** Ensure SaveManager.load_settings() is called before UIScaleManager initializes

**Issue:** Slider hard to use (jumps around)
**Fix:** Set slider step to 0.1 or smaller for smoother control

---

## Result

You now have a fully functional UI scale settings menu that:
- ✅ Allows players to adjust UI size (50%-200%)
- ✅ Saves preferences between sessions
- ✅ Works on all platforms (desktop, mobile, web)
- ✅ Integrates seamlessly with existing UI system
- ✅ Follows industry standards for accessibility

**Impact:** Players with 4K monitors can enlarge UI, players with small screens can shrink it, improving accessibility and user satisfaction.
