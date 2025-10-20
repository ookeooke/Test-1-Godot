# Enemy Sprites - Replacement Guide

## Current Setup (Goblin Scout)

The Goblin Scout enemy now has **Battle Brothers-style animation** using:
- **Single static 32x32 sprite** (placeholder)
- **Effect-based animation** (no walk cycles needed!)
- **3 animation states**: idle, hit, attack

---

## How to Replace Placeholder Sprites

### Option 1: Use Your Own 32x32 Sprites

1. **Create your sprite** (32x32 pixels, PNG format)
   - Use any pixel art tool (Aseprite, Piskel, Photoshop, etc.)
   - Transparent background
   - Draw your enemy facing RIGHT (will be used for all directions)

2. **Save to this folder**:
   ```
   assets/sprites/enemies/goblin_idle.png
   ```

3. **Update the scene**:
   - Open `scenes/enemies/goblin_scout.tscn` in Godot
   - Select the "Sprite" node
   - In Inspector, under "Texture", click the dropdown
   - Choose "Load" → navigate to your `goblin_idle.png`
   - Done! The animation system will use your sprite

---

## Animation States Explained

### 1. **Idle Animation** (2 seconds, loops)
- Sprite bobs up and down slightly (0 → -2px → 0)
- Gives a "breathing" effect
- Plays automatically when enemy spawns

### 2. **Hit Animation** (0.3 seconds)
- Flash white (modulate effect)
- Scale down briefly (100% → 90% → 100%)
- Red particle burst (blood effect)
- Triggers when enemy takes damage

### 3. **Attack Animation** (0.4 seconds)
- Scale up slightly (100% → 110% → 100%)
- Rotate 10 degrees and back
- Triggers when attacking hero in melee

---

## Advanced: Multiple Frames (Optional)

If you want MORE animation (Battle Brothers uses 2-3 frames):

1. **Create additional sprites**:
   - `goblin_idle.png` - neutral pose
   - `goblin_attack.png` - weapon raised (optional)
   - `goblin_hurt.png` - damaged expression (optional)

2. **Update AnimationPlayer**:
   - Open `goblin_scout.tscn`
   - Select "AnimationPlayer" node
   - Edit the animations to swap textures instead of just effects
   - Example: In "attack" animation, change Sprite texture to `goblin_attack.png` at frame 0.2

---

## Current Placeholder

The current green square with "Goblin" text is just a placeholder using `PlaceholderTexture2D`.

When you replace it with your own sprite:
- Keep it **32x32 pixels**
- Use **transparent background**
- **Pixel art style** recommended (use texture_filter = 1 for crisp pixels)
- Facing **RIGHT** is standard

---

## Battle Brothers Style Tips

From the Battle Brothers dev blog:

> "We could still go with a painted and detailed look and include all the customization we wanted by just layering everything. While we're only showing the top half of characters without any animations, we made what we do show as detailed as possible."

**What this means for you:**
- You don't need walk cycles!
- Focus on ONE good static frame
- The animation system creates dynamism through effects
- Can add variety by layering (different heads, armor, weapons as separate sprites)

---

## Example Sprite Specs

**Goblin Scout (Placeholder)**:
- Size: 32x32px
- Colors: Green skin (0.4, 0.6, 0.2), brown clothes
- Features: Pointy ears, yellow eyes, crude blade
- Collision: 16px radius circle

**To Match**:
- Your sprite should fit within a 32x32 canvas
- Main body should be within central 24x24 area
- Leave 4px padding on edges for effects

---

## Testing Your Sprite

1. Replace `goblin_idle.png` with your sprite
2. Run the game
3. Start a level
4. Watch the goblin:
   - Should bob gently (idle)
   - Flash white when hit by arrows (hit animation)
   - Grow and rotate when attacking hero (attack animation)
   - Red particles when damaged

---

## Next Steps

Once Goblin looks good, apply the same system to:
- `orc_warrior.tscn` - larger, tougher enemy
- `wolf_runner.tscn` - fast runner
- `bat_flyer.tscn` - flying enemy (no blocking)
- `troll_boss.tscn` - boss enemy

All use the same animation system!

---

## Credits

Animation system inspired by **Battle Brothers** by Overhype Studios.

> "Characters make use of few unique frames in their animation, achieving a dynamic effect through the movement of the model itself, impact effects and the quick switching between neutral frames and attack frames."
