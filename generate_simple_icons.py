#!/usr/bin/env python3
"""
Simple Icon Generator for Godot Items
Generates 64x64 colored PNG icons with borders
Run: python generate_simple_icons.py
"""

from PIL import Image, ImageDraw
import os

ICON_SIZE = 64
BORDER_SIZE = 4

def create_colored_icon(bg_color, border_color, output_path):
    """Create a simple colored square icon with border"""
    img = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), bg_color)
    draw = ImageDraw.Draw(img)

    # Draw border
    draw.rectangle([0, 0, ICON_SIZE-1, ICON_SIZE-1], outline=border_color, width=BORDER_SIZE)

    img.save(output_path)
    print(f"✓ Created: {output_path}")

def main():
    # Create directory
    os.makedirs("assets/icons/items", exist_ok=True)

    # Define items with colors (R, G, B, A)
    items = {
        # Weapons - Red tones
        "basic_bow": ((200, 50, 50, 255), (120, 30, 30, 255)),
        "fire_bow": ((230, 80, 30, 255), (150, 50, 20, 255)),
        "elven_longbow": ((150, 200, 80, 255), (90, 120, 50, 255)),

        # Armor - Blue/Brown tones
        "leather_vest": ((150, 100, 50, 255), (90, 60, 30, 255)),

        # Accessories - Purple tones
        "power_ring": ((150, 80, 200, 255), (90, 50, 120, 255)),

        # Potions - Red/Orange tones
        "health_potion": ((200, 50, 80, 255), (120, 30, 50, 255)),
        "damage_buff_potion": ((230, 150, 50, 255), (150, 90, 30, 255)),

        # Materials - Various tones
        "dragon_scale": ((230, 130, 30, 255), (150, 80, 20, 255)),
        "iron_ore": ((130, 130, 130, 255), (80, 80, 80, 255)),
        "magic_essence": ((100, 180, 230, 255), (60, 110, 150, 255))
    }

    for item_id, (bg_color, border_color) in items.items():
        output_path = f"assets/icons/items/{item_id}.png"
        create_colored_icon(bg_color, border_color, output_path)

    print(f"\n✓ Generated {len(items)} icons successfully!")
    print("IMPORTANT: Restart Godot or click 'Project -> Reload Current Project' to see the new icons")

if __name__ == "__main__":
    try:
        main()
    except ImportError:
        print("ERROR: PIL (Pillow) not installed. Install it with: pip install Pillow")
