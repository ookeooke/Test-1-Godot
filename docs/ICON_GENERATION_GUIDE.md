# Icon Generation Guide for ChatGPT/DALL-E 3

This guide provides optimized prompts for generating item icons using ChatGPT's DALL-E 3.

## General Icon Specifications

- **Format:** PNG with transparent background
- **Target size after resizing:** 128×192 pixels (but DALL-E generates 1024×1024, resize after)
- **Orientation:** Match item's inventory dimensions
- **Style:** Fantasy game pixel art or detailed icon style
- **Important:** Always request "transparent background" and "perfectly straight, no tilt"

## Aspect Ratio Guidelines by Item Size

| Inventory Size | Aspect Ratio | Recommended Pixels | Prompt Modifier |
|----------------|--------------|-------------------|-----------------|
| **1×1** (Ring, Amulet) | 1:1 (square) | 128×128 | "square format, centered" |
| **2×2** (Armor) | 1:1 (square) | 128×128 | "square format, armor piece" |
| **1×2** (Small bow - legacy) | 1:2 (vertical) | 64×128 | "vertical portrait, narrow" |
| **2×3** (Bow, Crossbow) | 2:3 (tall) | 128×192 | "vertical portrait, 2:3 aspect" |
| **1×3** (Spear) | 1:3 (very tall) | 64×192 | "very tall vertical format" |

## Weapon Icon Prompts

### Basic Bow (2×3, Common)
```
Create a fantasy game item icon of a simple wooden recurve bow.
Style: Warm brown wood tones, slightly weathered.
Orientation: Vertical portrait, 2:3 aspect ratio (taller than wide).
Composition: Single bow centered, string visible, no arrows.
Background: Completely transparent, no shadows outside the item.
Detail: Clean and clear for small display, suitable for beginner equipment.
Alignment: Perfectly straight vertical, no tilt or rotation.
Format: PNG with transparency.
```

### Fire Bow (2×3, Rare)
```
Create a fantasy game item icon of a powerful magical bow with flames.
Style: Dark wood with glowing orange-red fire effects, embers floating.
Orientation: Vertical portrait, 2:3 aspect ratio.
Composition: Ornate recurve bow with flame accents along limbs, fiery bowstring.
Background: Completely transparent.
Detail: Mystical and powerful appearance, warm color palette.
Alignment: Perfectly straight vertical, no tilt.
Format: PNG with transparency.
```

### Elven Longbow (2×3, Rare)
```
Create a fantasy game item icon of an elegant elven longbow.
Style: Polished light wood with silver filigree, nature motifs.
Orientation: Vertical portrait, 2:3 aspect ratio.
Composition: Graceful curved limbs, decorative carvings, thin string.
Background: Completely transparent.
Detail: Refined craftsmanship, green and silver accents.
Alignment: Perfectly straight vertical, no tilt.
Format: PNG with transparency.
```

### Epic Crossbow (2×3, Epic)
```
Create a fantasy game item icon of a heavy epic crossbow.
Style: Dark metal and reinforced wood, battle-worn but powerful.
Orientation: Vertical portrait, 2:3 aspect ratio.
Composition: Sturdy crossbow with mechanical details, thick bow string.
Background: Completely transparent.
Detail: Imposing and durable design, steel and iron tones.
Alignment: Perfectly straight vertical, no tilt.
Format: PNG with transparency.
```

## Armor Icon Prompts

### Leather Vest (2×2, Common)
```
Create a fantasy game item icon of a leather vest armor.
Style: Brown leather with simple stitching, functional design.
Orientation: Square format, 1:1 aspect ratio.
Composition: Front view of vest centered, visible straps and buckles.
Background: Completely transparent.
Detail: Practical beginner armor, earth tones.
Alignment: Straight and centered, no tilt.
Format: PNG with transparency.
```

### Epic Plate Armor (2×2, Epic)
```
Create a fantasy game item icon of epic plate armor chestpiece.
Style: Polished steel with gold trim, ornate engravings.
Orientation: Square format, 1:1 aspect ratio.
Composition: Front view of breastplate, shoulder pauldrons visible.
Background: Completely transparent.
Detail: Heroic and imposing, metallic sheen with battle marks.
Alignment: Straight and centered, no tilt.
Format: PNG with transparency.
```

## Accessory Icon Prompts

### Power Ring (1×1, Uncommon)
```
Create a fantasy game item icon of a magical power ring.
Style: Gold band with red gemstone, subtle glow effect.
Orientation: Square format, 1:1 aspect ratio.
Composition: Ring at slight angle to show both band and gem.
Background: Completely transparent.
Detail: Small but distinct, mystical aura around gem.
Alignment: Centered, slight 3D perspective.
Format: PNG with transparency.
```

### Epic Power Amulet (1×1, Epic)
```
Create a fantasy game item icon of an ancient arcane amulet.
Style: Dark metal pendant with purple crystal, intricate chains.
Orientation: Square format, 1:1 aspect ratio.
Composition: Amulet hanging vertically, chain visible at top.
Background: Completely transparent.
Detail: Pulsing magical energy, gothic fantasy aesthetic.
Alignment: Centered, straight vertical hang.
Format: PNG with transparency.
```

## Post-Generation Workflow

After ChatGPT generates the icon:

1. **Download** the 1024×1024 PNG from ChatGPT
2. **Resize** to target dimensions:
   - 2×3 items (bows): 128×192 pixels
   - 2×2 items (armor): 128×128 pixels
   - 1×1 items (accessories): 128×128 pixels
3. **Verify** transparent background
4. **Save** to appropriate folder:
   ```
   assets/icons/items/weapons/bows/basic_bow.png
   assets/icons/items/weapons/bows/fire_bow.png
   assets/icons/items/armor/leather_vest.png
   assets/icons/items/accessories/power_ring.png
   ```
5. **Reference** in .tres file:
   ```gdscript
   [ext_resource type="Texture2D" path="res://assets/icons/items/weapons/bows/basic_bow.png" id="2_icon"]
   icon = ExtResource("2_icon")
   ```

## Troubleshooting

**Icon looks tilted:** Add "perfectly straight, no rotation" to prompt
**Background not transparent:** Request "transparent background, no drop shadow"
**Too detailed for small size:** Add "clean simple design, suitable for 128px display"
**Wrong aspect ratio:** Specify exact ratio in prompt (e.g., "2:3 aspect ratio, taller than wide")

## Tips for Best Results

1. **Be specific about orientation** - DALL-E defaults to horizontal/landscape
2. **Request "no tilt"** - DALL-E loves dramatic angles
3. **Mention transparency explicitly** - Otherwise you'll get white/gray backgrounds
4. **Keep it simple** - Overly complex designs don't scale well to 128px
5. **Use natural language** - DALL-E 3 prefers conversational prompts over technical jargon
6. **Iterate** - If first result isn't perfect, ask ChatGPT to "regenerate with [specific change]"

## Example Iteration

If bow is too thin:
```
"Please regenerate the bow icon but make the bow wider and more visible,
filling more of the 2:3 vertical space while maintaining the tall aspect ratio."
```

If bow has wrong colors:
```
"Regenerate with warmer brown wood tones and remove any blue/green tints."
```
