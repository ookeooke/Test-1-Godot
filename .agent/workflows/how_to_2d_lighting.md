---
description: How to implement the "2D Lighting Cheat" (Normal Maps)
---

# How to find and use "2D Lighting" (Normal Maps)

For future reference, here are the keywords and steps to achieve this effect.

## 1. The Keywords to Search
If you are looking for tutorials or assets, search for:
*   **"Normal Maps"** (The technical term)
*   **"2D Lighting"** or **"2D Dynamic Lights"**
*   **"Godot CanvasTexture"**

## 2. The Tools
*   **Laigter** (Free): Drag & drop your sprite to auto-generate normal maps.
*   **Aseprite**: Can draw them manually (Red = Right, Green = Down, Blue = Flat).

## 3. The Godot Setup
1.  **Sprite2D**:
    *   Texture -> **New CanvasTexture**
    *   Diffuse -> Your Art (`.png`)
    *   Normal Map -> Your Purple Map (`_n.png`)
2.  **PointLight2D**:
    *   Add this node to see the effect.
    *   Texture -> Assign a "light texture" (a white fuzzy circle).
