# Input System Documentation

## Overview

This project implements a robust, cross-platform input system following Godot 4.5 best practices. The system correctly handles the input event flow, prevents overlapping input handlers, and supports both PC (mouse/keyboard) and mobile (touch) platforms.

## Table of Contents

1. [Input Event Flow](#input-event-flow)
2. [Key Concepts](#key-concepts)
3. [Implementation Guide](#implementation-guide)
4. [InputMap Actions](#inputmap-actions)
5. [Common Patterns](#common-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Input Event Flow

Godot processes input in **4 distinct stages**, in this exact order:

### Stage 1: `_input()` Handlers
- **When**: First stage, before any other processing
- **Who**: Nodes with `set_process_input(true)` (enabled by default)
- **Usage**: Global input handling, system-level shortcuts
- **Consumption**: Call `get_viewport().set_input_as_handled()` to stop propagation
- **⚠️ WARNING**: This blocks ALL subsequent stages, including UI and Area2D clicks!

### Stage 2: UI/Control Stage
- **When**: After `_input()`, if not consumed
- **Who**: Control nodes (Button, Panel, Label, etc.)
- **How**: Via `_gui_input(event)` or the `gui_input` signal
- **Consumption**: Call `accept_event()` to prevent further propagation
- **Note**: Controls automatically receive events when under the pointer

### Stage 3: `_unhandled_input()` Handlers
- **When**: After UI controls, if not consumed
- **Who**: Nodes with `set_process_unhandled_input(true)`
- **Usage**: Gameplay input that shouldn't interfere with UI
- **Consumption**: Call `get_viewport().set_input_as_handled()` to stop propagation
- **✅ RECOMMENDED**: Use this for most gameplay input!

### Stage 4: Physics/Collision Stage
- **When**: Last stage, if event still unhandled
- **Who**: CollisionObject2D (Area2D, PhysicsBody2D)
- **How**: Via `_input_event(camera, event, position)` callback or `input_event` signal
- **Consumption**: Automatic - if Area2D receives event, it's consumed
- **Note**: Only fires if camera exists and raycast hits the object

### Visual Diagram

```
OS Input Event
    ↓
┌─────────────────────────────┐
│ Stage 1: _input()           │ ← Can block everything!
│ - Level controller (pause)  │
│ - Global shortcuts          │
└─────────────────────────────┘
    ↓ (if not consumed)
┌─────────────────────────────┐
│ Stage 2: UI Controls        │ ← GUI elements
│ - Buttons                   │
│ - Panels                    │
│ - Item slots                │
└─────────────────────────────┘
    ↓ (if not consumed)
┌─────────────────────────────┐
│ Stage 3: _unhandled_input() │ ← ✅ Gameplay input
│ - Hero manager              │
│ - Camera controller         │
└─────────────────────────────┘
    ↓ (if not consumed)
┌─────────────────────────────┐
│ Stage 4: Physics            │ ← World objects
│ - Tower spots               │
│ - Towers                    │
│ - Hero spots                │
│ - Item pickups              │
└─────────────────────────────┘
```

---

## Key Concepts

### 1. Event Consumption

**Always consume events you handle to prevent unintended side effects!**

#### For UI Controls (Stage 2):
```gdscript
func _gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.pressed:
        # Handle the click
        my_button_clicked()
        accept_event()  # ✅ Prevents _unhandled_input and physics
```

#### For Gameplay (_unhandled_input, Stage 3):
```gdscript
func _unhandled_input(event):
    if Input.is_action_just_pressed("interact"):
        # Handle the action
        perform_action()
        get_viewport().set_input_as_handled()  # ✅ Prevents physics
```

#### For Area2D (Stage 4):
```gdscript
func _on_area_input_event(_viewport, event, _shape_idx):
    if event is InputEventMouseButton and event.pressed:
        on_clicked()
        get_viewport().set_input_as_handled()  # ✅ Good practice
```

### 2. Mouse vs Touch Input

**Support both for cross-platform compatibility!**

```gdscript
# BAD: Only supports mouse
if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
    handle_click()

# GOOD: Supports both mouse and touch
var is_interact = false

if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    is_interact = true
elif event is InputEventScreenTouch and event.pressed:
    is_interact = true

if is_interact:
    handle_click()
```

**Even better: Use InputMap actions!**

```gdscript
# BEST: Uses InputMap action (configured for both mouse and touch)
if Input.is_action_just_pressed("interact"):
    handle_click()
```

### 3. GUI Hover Detection

**Check if mouse is over UI before processing world clicks:**

```gdscript
func _unhandled_input(event):
    # Don't process if GUI is hovered
    var gui_element = get_viewport().gui_get_hovered_control()
    if gui_element:
        return  # Let GUI handle it

    # Process world input
    if Input.is_action_just_pressed("interact"):
        handle_world_click()
```

---

## InputMap Actions

The `InputActionsSetup` autoload configures these actions at runtime:

### Primary Actions
- **`interact`** - Primary click/tap (left-click or touch tap)
- **`deselect`** - Secondary action (right-click or ESC)
- **`camera_drag_start`** - Camera drag (middle/right mouse button)

### Camera Controls
- **`camera_up`** - Pan camera up (W, Up Arrow)
- **`camera_down`** - Pan camera down (S, Down Arrow)
- **`camera_left`** - Pan camera left (A, Left Arrow)
- **`camera_right`** - Pan camera right (D, Right Arrow)
- **`camera_zoom_in`** - Zoom in (mouse wheel up)
- **`camera_zoom_out`** - Zoom out (mouse wheel down)

### Game Speed
- **`speed_pause`** - Pause game (1 key)
- **`speed_normal`** - Normal speed (2 key)
- **`speed_fast`** - Fast speed (3 key)
- **`speed_ultra`** - Ultra speed (4 key)

### Ability Hotkeys
- **`ability_1` through `ability_9`** - Ability hotkeys (1-9 keys)

### Debug Keys
- **`debug_balance_hud`** - Toggle balance HUD (F3)
- **`debug_export_balance`** - Export balance data (F4)
- **`debug_reset_balance`** - Reset balance tracking (F5)

---

## Implementation Guide

### Adding Input to a New UI Element

```gdscript
extends Control

func _ready():
    # Connect gui_input signal
    gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
    # Handle both mouse and touch
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        on_clicked()
        accept_event()  # Important!
    elif event is InputEventScreenTouch and event.pressed:
        on_tapped()
        accept_event()  # Important!

func on_clicked():
    print("Clicked!")
```

### Adding Input to a New Area2D Object

```gdscript
extends Area2D

func _ready():
    input_pickable = true
    input_event.connect(_on_input_event)

func _on_input_event(_viewport, event, _shape_idx):
    # Support both mouse and touch
    var is_interact = false

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        is_interact = true
    elif event is InputEventScreenTouch and event.pressed:
        is_interact = true

    if is_interact:
        on_clicked()
        get_viewport().set_input_as_handled()

func on_clicked():
    print("Area2D clicked!")
```

### Adding Gameplay Input Handler

```gdscript
extends Node

func _unhandled_input(event):
    # IMPORTANT: Use _unhandled_input, NOT _input!
    # This allows UI and Area2D to process first

    # Check if GUI is hovered
    var gui_element = get_viewport().gui_get_hovered_control()
    if gui_element:
        return

    # Use InputMap actions for cross-platform support
    if Input.is_action_just_pressed("interact"):
        handle_interaction()
        get_viewport().set_input_as_handled()

func handle_interaction():
    print("Gameplay interaction!")
```

---

## Common Patterns

### Pattern 1: Close Menu on Outside Click

```gdscript
extends Control

func _gui_input(event):
    """Consume clicks inside the menu"""
    if event is InputEventMouseButton or event is InputEventScreenTouch:
        # Any click inside the menu is consumed
        accept_event()

func _unhandled_input(event):
    """Detect clicks outside the menu"""
    # If we get here, the click was outside this Control
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        close_menu()
        get_viewport().set_input_as_handled()
```

### Pattern 2: Hero Selection with Movement

```gdscript
func _unhandled_input(event):
    # Don't interfere with UI
    if get_viewport().gui_get_hovered_control():
        return

    # Use InputMap action
    if Input.is_action_just_pressed("interact"):
        if selected_hero:
            # Move hero
            move_hero_to_click()
            get_viewport().set_input_as_handled()
        # If no hero selected, let the click propagate to Area2D (hero selection)
```

### Pattern 3: Gesture Detection (Tap, Drag, Long-Press)

```gdscript
var gesture_detector: GestureDetector

func _ready():
    gesture_detector = GestureDetector.new()
    add_child(gesture_detector)

    gesture_detector.tap.connect(_on_tap)
    gesture_detector.drag_started.connect(_on_drag_started)
    gesture_detector.long_press.connect(_on_long_press)

func _unhandled_input(event):
    if gesture_detector.process_event(event):
        get_viewport().set_input_as_handled()

func _on_tap(position: Vector2):
    print("Tapped at: ", position)

func _on_drag_started(position: Vector2):
    print("Drag started at: ", position)

func _on_long_press(position: Vector2):
    print("Long press at: ", position)
```

---

## Troubleshooting

### Problem: Buttons Don't Respond

**Possible causes:**
1. `_input()` handler consuming events before UI stage
2. Another Control blocking the button (check `mouse_filter`)
3. Button not connected to signal

**Solutions:**
- Move input handling from `_input()` to `_unhandled_input()`
- Set `mouse_filter = MOUSE_FILTER_IGNORE` on decorative UI elements
- Verify Button `pressed` signal is connected

### Problem: Tower/Hero Clicks Not Working

**Possible causes:**
1. Event consumed in earlier stage (check `_input()` handlers)
2. UI element blocking (transparent panel with default mouse_filter)
3. Area2D not set to `input_pickable = true`

**Solutions:**
- Use `_unhandled_input()` instead of `_input()` for gameplay logic
- Set `mouse_filter = MOUSE_FILTER_IGNORE` on non-interactive UI
- Verify `input_pickable = true` on Area2D

### Problem: Mobile Touch Not Working

**Possible causes:**
1. Only checking for `InputEventMouseButton`
2. Not checking for `InputEventScreenTouch`

**Solution:**
```gdscript
# Check for both mouse and touch
var is_interact = false
if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
    is_interact = true
elif event is InputEventScreenTouch and event.pressed:
    is_interact = true

if is_interact:
    handle_click()
```

### Problem: Overlapping Input Handlers

**Cause:**
Multiple handlers responding to same event

**Solution:**
- Use correct stage: UI uses `_gui_input`, gameplay uses `_unhandled_input`, global uses `_input`
- Always call `accept_event()` or `set_input_as_handled()` after handling
- Check `gui_get_hovered_control()` before world input

---

## Best Practices Summary

✅ **DO:**
- Use `_unhandled_input()` for gameplay input
- Use `_gui_input()` and `accept_event()` for UI input
- Support both mouse and touch events
- Use InputMap actions for cross-platform support
- Check `gui_get_hovered_control()` before world input
- Always consume events you handle
- Set `mouse_filter = MOUSE_FILTER_IGNORE` on decorative UI

❌ **DON'T:**
- Use `_input()` for gameplay (it blocks everything!)
- Forget to call `accept_event()` or `set_input_as_handled()`
- Only support mouse (forget touch)
- Rely on implicit event ordering
- Leave `mouse_filter` at default on non-interactive elements

---

## Files Reference

- **`scripts/autoloads/input_actions_setup.gd`** - InputMap action configuration
- **`scripts/utils/gesture_detector.gd`** - Gesture detection utility
- **`scripts/managers/hero_manager.gd`** - Example of `_unhandled_input()` usage
- **`scripts/ui/tower_info_menu.gd`** - Example of `_gui_input()` + `_unhandled_input()`
- **`scripts/ui/item_slot.gd`** - Example of `accept_event()` usage
- **`scenes/spots/tower_spot.gd`** - Example of Area2D input handling
- **`scenes/towers/archer_tower.gd`** - Example of Area2D input handling

---

## Additional Resources

- [Godot Input Documentation](https://docs.godotengine.org/en/stable/tutorials/inputs/index.html)
- [InputEvent Class Reference](https://docs.godotengine.org/en/stable/classes/class_inputevent.html)
- [InputMap Documentation](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)
