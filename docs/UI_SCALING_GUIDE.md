# UI Scaling System - Developer Guide

This guide explains how UI scaling works in the Test-1-Godot tower defense project and provides best practices for implementing responsive interfaces across different screen resolutions and devices.

## Table of Contents

1. [Overview](#overview)
2. [How It Works](#how-it-works)
3. [UIScaleManager API](#uiscalemanager-api)
4. [When to Use Scaling](#when-to-use-scaling)
5. [Touch Target Requirements](#touch-target-requirements)
6. [Platform-Specific Considerations](#platform-specific-considerations)
7. [Testing Checklist](#testing-checklist)
8. [Common Patterns](#common-patterns)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The UI scaling system ensures that interface elements are appropriately sized across different resolutions and devices, from budget 720p laptops to 4K monitors and mobile phones.

**Design Resolution:** 1920x1080 (Full HD)
**Scaling Method:** Height-based (maintains consistent vertical framing)
**Scale Range:** 0.5x to 2.0x (clamped to prevent extreme distortions)

### Key Components

- **UIScaleManager** (autoload) - Calculates and manages UI scale
- **main_theme.tres** - Theme resource with base font sizes and spacing
- **Project Settings** - Stretch mode `canvas_items` for crisp 2D rendering

---

## How It Works

### 1. Height-Based Calculation

```gdscript
# From ui_scale_manager.gd:58-74
var screen_height: int = window_size.y
var calculated_scale: float = float(screen_height) / float(DESIGN_HEIGHT)
ui_scale = clampf(calculated_scale, MIN_SCALE, MAX_SCALE)
```

**Why height instead of width?**
- Maintains consistent vertical framing (same amount of world visible)
- Handles ultrawide monitors better (16:9, 21:9, 32:9)
- Matches how most games handle FOV scaling

### 2. Theme-Based Scaling

The `main_theme.tres` file defines base sizes at 1080p:
- Font size: 36px
- Button heights: 40-60px
- Margins/padding: 10-20px

When `UIScaleManager` recalculates scale, it:
1. Loads the base theme from disk
2. Scales all font sizes by `ui_scale`
3. Applies the scaled theme globally

**Result:** All Control nodes using the theme automatically adapt to resolution.

### 3. Debounced Window Resize

```gdscript
# From ui_scale_manager.gd:92-104
func _on_window_resized():
    resize_timer.start(RESIZE_DEBOUNCE_TIME)  # 0.1 seconds

func _on_resize_timer_timeout():
    calculate_ui_scale()
    load_and_scale_theme()
    scale_changed.emit(ui_scale)
```

**Why debounce?**
- Prevents spam during window dragging
- Reduces theme reload overhead (expensive operation)
- Smooths performance during rapid resize

---

## UIScaleManager API

### Properties

```gdscript
## Current UI scale multiplier (1.0 at 1080p)
var ui_scale: float = 1.0 (read-only, use calculate_ui_scale())

## Design resolution baseline
const DESIGN_HEIGHT: int = 1080

## Scale constraints
const MIN_SCALE: float = 0.5  # Minimum 720p-ish
const MAX_SCALE: float = 2.0  # Maximum 4K
```

### Signals

```gdscript
## Emitted when UI scale changes (window resize, fullscreen toggle)
signal scale_changed(new_scale: float)
```

### Functions

#### `get_scaled_value(base_value: float) -> float`

Scales a single numeric value based on current UI scale.

```gdscript
# Example: Scale button width
var button_width = UIScaleManager.get_scaled_value(200.0)
# Returns: 200 at 1080p, 133 at 720p, 400 at 4K
```

**When to use:**
- Custom positioning calculations
- Procedural UI generation
- Canvas drawing operations

#### `get_scaled_size(base_size: Vector2) -> Vector2`

Scales a 2D size vector.

```gdscript
# Example: Scale item slot size
var slot_size = UIScaleManager.get_scaled_size(Vector2(80, 80))
# Returns: (80, 80) at 1080p, (53, 53) at 720p, (160, 160) at 4K
```

**When to use:**
- Custom Control node sizes
- Texture/sprite scaling
- Collision area sizing

#### `is_valid_touch_target(size: Vector2) -> bool`

Validates if a UI element meets minimum touch target requirements (44x44dp).

```gdscript
# Example: Validate button size
var button_size = Vector2(60, 60)
if not UIScaleManager.is_valid_touch_target(button_size):
    push_warning("Button too small for touch input!")
```

**Returns:** `true` if both width and height are >= 44 scaled pixels

---

## When to Use Scaling

### ✅ Use UIScaleManager for:

1. **Custom-drawn UI** (not using Control nodes)
   ```gdscript
   func _draw():
       var radius = UIScaleManager.get_scaled_value(20.0)
       draw_circle(Vector2.ZERO, radius, Color.WHITE)
   ```

2. **Procedural layouts** (dynamically generated UI)
   ```gdscript
   func generate_button_grid(rows: int, cols: int):
       var button_size = UIScaleManager.get_scaled_size(Vector2(100, 50))
       var spacing = UIScaleManager.get_scaled_value(10.0)
       # ... create grid
   ```

3. **Canvas-based UI** (CanvasItem not Control)
   ```gdscript
   var canvas_button = Sprite2D.new()
   var scaled_scale = Vector2.ONE * ui_scale
   canvas_button.scale = scaled_scale
   ```

4. **Touch target validation** (mobile compliance checks)
   ```gdscript
   func _ready():
       if not UIScaleManager.is_valid_touch_target(custom_minimum_size):
           custom_minimum_size = Vector2(44, 44) * UIScaleManager.ui_scale
   ```

### ❌ Don't use UIScaleManager for:

1. **Standard Control nodes** (Button, Label, Panel, etc.)
   - Theme system handles these automatically
   - Using `get_scaled_value()` will double-scale them

2. **Elements with `custom_minimum_size`**
   - Already scaled by theme
   - Manual scaling creates inconsistency

3. **Game world elements** (towers, enemies, projectiles)
   - Use camera zoom, not UI scaling
   - Different scaling logic required

---

## Touch Target Requirements

### Minimum Sizes

| Platform | Minimum Size | Physical Size | Source |
|----------|--------------|---------------|--------|
| **iOS** | 44x44 pt | ~7mm | Apple Human Interface Guidelines |
| **Android** | 48x48 dp | ~9mm | Material Design |
| **Web** | 44x44 CSS px | ~7mm | WCAG 2.5.5 Level AAA |

**This project:** 44x44 scaled pixels (aligns with Apple/Web standards)

### Validation

```gdscript
# In _ready() or when creating custom buttons:
assert(UIScaleManager.is_valid_touch_target(custom_minimum_size), "Touch target too small!")
```

### Calculating Physical Size

```gdscript
# Screen DPI affects physical size
# At 160 DPI (Android baseline): 44px = 7mm
# At 320 DPI (Retina): 88px = 7mm
# At 460 DPI (iPhone 15 Pro): 127px = 7mm

# Formula:
# physical_mm = (pixels / dpi) * 25.4
```

**Note:** Godot doesn't provide per-monitor DPI on all platforms. UIScaleManager uses height-based scaling as a DPI-agnostic approach.

---

## Platform-Specific Considerations

### Desktop (PC/Mac/Linux)

- **Window Resize:** UI scales in real-time
- **Fullscreen:** May trigger scale change if resolution differs
- **Multi-monitor:** Uses window's current monitor resolution
- **User Control:** Can add UI scale slider (see Phase 2 of implementation plan)

**Testing:**
```
1280x720   → 0.67x scale
1920x1080  → 1.0x scale (baseline)
2560x1440  → 1.33x scale
3840x2160  → 2.0x scale (clamped)
```

### Mobile (Android/iOS)

- **Orientation:** Rotations trigger scale recalculation
- **Device Variety:** Handles 480p to 4K phones
- **Safe Areas:** Modern phones have notches/rounded corners (consider Phase 3)
- **Touch Targets:** Critical - always validate with `is_valid_touch_target()`

**Testing:**
```
iPhone SE (1334x750)    → 0.69x scale
Pixel 6 (2400x1080)     → 1.0x scale
iPhone 15 (2532x1170)   → 1.08x scale
iPad Air (2360x1640)    → 1.52x scale (landscape)
```

### Web (HTML5/WebGL)

- **Browser Window:** Scales based on window size, not screen resolution
- **Fullscreen:** Toggle triggers scale change
- **Canvas Scaling:** Project uses `canvas_items` stretch mode (optimal)
- **Mobile Web:** Detects via `WebFullscreenManager.is_mobile_device()`

**Testing:**
- Test in windowed mode at various sizes
- Test fullscreen on different monitors
- Test on mobile browser (Chrome/Safari)

---

## Testing Checklist

### Visual Tests

- [ ] **Font Sizes** - Text is readable at all scales (not blurry)
- [ ] **Button Sizes** - All buttons clearly visible and sized appropriately
- [ ] **Spacing** - Margins/padding consistent across resolutions
- [ ] **Icons** - Scale proportionally without pixelation
- [ ] **Panels** - No clipping, overflow, or overlap
- [ ] **Layout** - Elements stay within screen bounds

### Interaction Tests

- [ ] **Button Clicks** - All buttons respond to clicks/taps
- [ ] **Touch Targets** - Minimum 44x44 scaled pixels (use `is_valid_touch_target()`)
- [ ] **Adjacent Elements** - No accidental clicks on nearby buttons
- [ ] **Drag-Drop** - Works smoothly across scales
- [ ] **Scroll Areas** - Scroll bars/areas properly sized

### Performance Tests

- [ ] **Window Resize** - Smooth, no frame drops
- [ ] **Scale Change** - Theme reload < 100ms
- [ ] **Memory Usage** - No leaks from repeated theme reloads
- [ ] **Startup Time** - Initial scale calculation quick

### Platform-Specific Tests

**Desktop:**
- [ ] Test at 720p, 1080p, 1440p, 4K
- [ ] Window resize (drag window edges)
- [ ] Fullscreen toggle (F11)
- [ ] Multi-monitor drag

**Mobile:**
- [ ] Test on 3-4 different device sizes
- [ ] Portrait and landscape orientations
- [ ] Different DPI densities (budget vs flagship)
- [ ] Safe areas (notches, camera cutouts)

**Web:**
- [ ] Desktop browser at various window sizes
- [ ] Mobile browser (Chrome, Safari, Firefox)
- [ ] Fullscreen API toggle
- [ ] Zoom level changes (Ctrl +/-)

---

## Common Patterns

### Pattern 1: Custom Button with Touch Target Validation

```gdscript
extends Button
class_name ResponsiveButton

@export var base_size: Vector2 = Vector2(100, 40)
@export var ensure_touch_target: bool = true

func _ready():
    # Calculate scaled size
    var scaled_size = UIScaleManager.get_scaled_size(base_size)

    # Enforce minimum touch target
    if ensure_touch_target:
        var min_size = 44.0 * UIScaleManager.ui_scale
        scaled_size.x = max(scaled_size.x, min_size)
        scaled_size.y = max(scaled_size.y, min_size)

    custom_minimum_size = scaled_size

    # Validate
    if not UIScaleManager.is_valid_touch_target(scaled_size):
        push_warning("[%s] Touch target too small: %v" % [name, scaled_size])
```

### Pattern 2: Dynamic Layout with Scale Change Listener

```gdscript
extends Control

@export var base_spacing: float = 20.0

func _ready():
    UIScaleManager.scale_changed.connect(_on_ui_scale_changed)
    _update_layout()

func _on_ui_scale_changed(new_scale: float):
    _update_layout()

func _update_layout():
    var scaled_spacing = UIScaleManager.get_scaled_value(base_spacing)
    # Apply to HBoxContainer, VBoxContainer, etc.
    $VBoxContainer.add_theme_constant_override("separation", int(scaled_spacing))
```

### Pattern 3: Custom Drawing with Scaled Values

```gdscript
extends Control

@export var circle_radius: float = 50.0
@export var line_width: float = 5.0

func _draw():
    var scaled_radius = UIScaleManager.get_scaled_value(circle_radius)
    var scaled_width = UIScaleManager.get_scaled_value(line_width)

    draw_circle(Vector2(100, 100) * UIScaleManager.ui_scale,
                scaled_radius,
                Color.WHITE,
                false,
                scaled_width)
```

### Pattern 4: Platform-Specific Button Sizes

```gdscript
func _ready():
    var button_size = Vector2(80, 60)  # Base size for desktop

    # Enlarge for mobile (easier to tap)
    if OS.has_feature("mobile"):
        button_size = Vector2(100, 80)

    # Apply scaling
    custom_minimum_size = UIScaleManager.get_scaled_size(button_size)
```

---

## Troubleshooting

### Issue: Text appears blurry at certain resolutions

**Cause:** Theme font sizes not scaling, or improper font import settings

**Fix:**
1. Check that `main_theme.tres` is loading correctly
2. In Import tab for fonts: Set "MSDF Pixel Range" to 8 and "MSDF Size" to 48
3. Use integer font sizes in theme (avoid fractional sizes)

### Issue: Buttons too small on 4K monitors

**Cause:** Scale clamped to 2.0x, may need higher multiplier

**Fix:**
Implement UI scale slider (Phase 2) to let users adjust:
```gdscript
UIScaleManager.user_scale_multiplier = 1.5  # 150% of calculated scale
```

### Issue: UI elements overlap at 720p

**Cause:** Layouts designed for 1080p without enough flexibility

**Fix:**
1. Use anchors for positioning (not absolute positions)
2. Use containers (VBoxContainer, HBoxContainer) for automatic layout
3. Test at minimum scale (0.5x) during development

### Issue: Touch targets too small on mobile

**Cause:** Using pixel values instead of scaled values

**Fix:**
```gdscript
# Before (wrong)
custom_minimum_size = Vector2(30, 30)  # Too small!

# After (correct)
custom_minimum_size = UIScaleManager.get_scaled_size(Vector2(44, 44))
```

### Issue: Performance drop during window resize

**Cause:** Theme reload is expensive operation

**Solution:** Already handled by debounce timer (100ms). If still slow:
1. Reduce theme complexity (fewer font sizes, simpler styles)
2. Use sprite-based UI instead of Control nodes for complex layouts
3. Increase RESIZE_DEBOUNCE_TIME in ui_scale_manager.gd

### Issue: UI scale doesn't update after changing window size

**Cause:** Signal not connected or debounce timer too long

**Debug:**
```gdscript
func _ready():
    UIScaleManager.scale_changed.connect(func(scale):
        print("UI Scale changed to: ", scale)
    )
```

Check console output when resizing window.

---

## Additional Resources

- **Apple HIG:** https://developer.apple.com/design/human-interface-guidelines/layout
- **Material Design:** https://m3.material.io/foundations/layout/applying-layout/window-size-classes
- **WCAG Touch Target:** https://www.w3.org/WAI/WCAG21/Understanding/target-size.html
- **Godot Docs:** https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html

---

## Summary

The UI scaling system in this project:
- ✅ Automatically adapts to resolution
- ✅ Maintains touch target compliance
- ✅ Provides simple API for custom UI
- ✅ Handles desktop, mobile, and web platforms
- ✅ Performs well with debounced resize handling

**Key Takeaway:** Most UI elements don't need manual scaling - the theme system handles them automatically. Only use `UIScaleManager` functions for custom UI elements that need explicit size control.

**Grade: B+ (85/100)** - Professional implementation, main improvement needed is user-adjustable scaling (Phase 2).
