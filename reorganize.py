#!/usr/bin/env python3
"""
Godot Project Reorganization Script
Safely moves files to organized folder structure and updates all references
"""

import os
import shutil
import re
from pathlib import Path

# Project root
PROJECT_ROOT = Path(__file__).parent

# File move map: source -> destination
MOVE_MAP = {
    # Autoload scripts
    "game_manager.gd": "scripts/autoloads/game_manager.gd",
    "click_manager.gd": "scripts/autoloads/click_manager.gd",
    "camera_effects.gd": "scripts/autoloads/camera_effects.gd",

    # Manager scripts
    "wave_manager.gd": "scripts/managers/wave_manager.gd",
    "placement_manager.gd": "scripts/managers/placement_manager.gd",
    "hero_manager.gd": "scripts/managers/hero_manager.gd",

    # Camera scripts
    "camera_controller_improved.gd": "scripts/camera/camera_controller_improved.gd",
    "camera_controller.gd": "scripts/camera/camera_controller_old.gd",
    "camera_settings_ui.gd": "scripts/camera/camera_settings_ui.gd",

    # UI scripts
    "ui.gd": "scripts/ui/ui.gd",
    "build_menu.gd": "scripts/ui/build_menu.gd",
    "tower_info_menu.gd": "scripts/ui/tower_info_menu.gd",

    # Enemy files
    "goblin_scout.tscn": "scenes/enemies/goblin_scout.tscn",
    "goblin_scout.gd": "scenes/enemies/goblin_scout.gd",
    "orc_warrior.tscn": "scenes/enemies/orc_warrior.tscn",
    "orc_warrior.gd": "scenes/enemies/orc_warrior.gd",

    # UI scenes
    "build_menu.tscn": "scenes/ui/build_menu.tscn",
    "tower_info_menu.tscn": "scenes/ui/tower_info_menu.tscn",

    # Spot files
    "tower_spot.tscn": "scenes/spots/tower_spot.tscn",
    "tower_spot.gd": "scenes/spots/tower_spot.gd",
    "hero_spot.tscn": "scenes/spots/hero_spot.tscn",
    "hero_spot.gd": "scenes/spots/hero_spot.gd",

    # Main level (rename)
    "node_2d.tscn": "scenes/levels/level_01.tscn",

    # Manager scene
    "game_manager.tscn": "scenes/managers/game_manager.tscn",
}

# Path replacements for updating references
PATH_REPLACEMENTS = {}
for old_path, new_path in MOVE_MAP.items():
    PATH_REPLACEMENTS[f'res://{old_path}'] = f'res://{new_path}'
    PATH_REPLACEMENTS[f'path="res://{old_path}"'] = f'path="res://{new_path}"'
    PATH_REPLACEMENTS[f'"{old_path}"'] = f'"{new_path}"'

def create_directories():
    """Create all necessary directories"""
    dirs = [
        "scripts/autoloads",
        "scripts/managers",
        "scripts/camera",
        "scripts/ui",
        "scenes/levels",
        "scenes/enemies",
        "scenes/ui",
        "scenes/spots",
        "scenes/managers",
    ]

    for dir_path in dirs:
        full_path = PROJECT_ROOT / dir_path
        full_path.mkdir(parents=True, exist_ok=True)
        print(f"✓ Created: {dir_path}/")

def move_files():
    """Move files to new locations"""
    print("\n📦 Moving files...")

    moved_count = 0
    for source, dest in MOVE_MAP.items():
        source_path = PROJECT_ROOT / source
        dest_path = PROJECT_ROOT / dest

        if source_path.exists():
            # Create parent directory if needed
            dest_path.parent.mkdir(parents=True, exist_ok=True)

            # Move file
            shutil.move(str(source_path), str(dest_path))
            print(f"  {source} → {dest}")
            moved_count += 1
        else:
            print(f"  ⚠️ Not found: {source}")

    print(f"\n✓ Moved {moved_count} files")

def update_file_references(file_path):
    """Update path references in a file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        changes = 0

        # Replace all path references
        for old_ref, new_ref in PATH_REPLACEMENTS.items():
            if old_ref in content:
                content = content.replace(old_ref, new_ref)
                changes += 1

        # Only write if changed
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return changes

        return 0
    except Exception as e:
        print(f"  ⚠️ Error updating {file_path}: {e}")
        return 0

def update_all_references():
    """Update references in all .tscn and .gd files"""
    print("\n🔄 Updating file references...")

    total_changes = 0
    files_updated = 0

    # Update all .tscn and .gd files
    for ext in ['*.tscn', '*.gd', '*.tres']:
        for file_path in PROJECT_ROOT.rglob(ext):
            # Skip .godot folder
            if '.godot' in str(file_path):
                continue

            changes = update_file_references(file_path)
            if changes > 0:
                print(f"  ✓ {file_path.name}: {changes} references updated")
                files_updated += 1
                total_changes += changes

    print(f"\n✓ Updated {total_changes} references in {files_updated} files")

def update_project_godot():
    """Update project.godot with new autoload paths"""
    print("\n⚙️ Updating project.godot...")

    project_file = PROJECT_ROOT / "project.godot"

    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Update autoload paths
    updates = {
        'GameManager="*res://game_manager.tscn"': 'GameManager="*res://scenes/managers/game_manager.tscn"',
        'ClickManager="*res://click_manager.gd"': 'ClickManager="*res://scripts/autoloads/click_manager.gd"',
        'CameraEffects="*res://camera_effects.gd"': 'CameraEffects="*res://scripts/autoloads/camera_effects.gd"',
    }

    for old, new in updates.items():
        if old in content:
            content = content.replace(old, new)
            print(f"  ✓ Updated: {new.split('=')[0]}")

    # Update main scene reference (find UID line and update if node_2d)
    # We'll keep the UID but it will now point to level_01.tscn

    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print("✓ project.godot updated")

def verify_reorganization():
    """Verify that files were moved correctly"""
    print("\n🔍 Verifying reorganization...")

    all_good = True

    # Check that all destination files exist
    for source, dest in MOVE_MAP.items():
        dest_path = PROJECT_ROOT / dest
        if not dest_path.exists():
            print(f"  ❌ Missing: {dest}")
            all_good = False

    # Check that old files don't exist
    old_files_remaining = []
    for source in MOVE_MAP.keys():
        source_path = PROJECT_ROOT / source
        if source_path.exists():
            old_files_remaining.append(source)

    if old_files_remaining:
        print(f"  ⚠️ Old files still in root: {len(old_files_remaining)}")
        all_good = False

    if all_good:
        print("✓ All files moved successfully!")

    return all_good

def print_summary():
    """Print summary of changes"""
    print("\n" + "="*60)
    print("📊 REORGANIZATION SUMMARY")
    print("="*60)

    print("\n✅ NEW FOLDER STRUCTURE:")
    print("""
res://
├── scripts/
│   ├── autoloads/     (3 files)
│   ├── managers/      (3 files)
│   ├── camera/        (3 files)
│   └── ui/            (3 files)
│
└── scenes/
    ├── levels/        (1 file)
    ├── enemies/       (4 files)
    ├── towers/        (already existed)
    ├── heroes/        (already existed)
    ├── projectiles/   (already existed)
    ├── ui/            (2 files)
    ├── spots/         (4 files)
    └── managers/      (1 file)
    """)

    print("\n📝 NEXT STEPS:")
    print("1. Open Godot")
    print("2. Click 'Reimport' if Godot asks")
    print("3. Press F5 to test your game")
    print("4. If everything works → Delete backup folder")
    print("5. If something broke → Restore from backup")

    print("\n💾 BACKUP LOCATION:")
    print("   c:\\Users\\ollil\\Test-1-Godot-BACKUP")

    print("\n" + "="*60)

def main():
    """Main reorganization process"""
    print("="*60)
    print("🗂️  GODOT PROJECT REORGANIZATION")
    print("="*60)
    print(f"\nProject: {PROJECT_ROOT}")
    print(f"Files to move: {len(MOVE_MAP)}")

    print("\n⚠️  IMPORTANT: Close Godot before continuing!")
    input("Press ENTER when Godot is closed...")

    try:
        # Step 1: Create directories
        print("\n📁 Creating folders...")
        create_directories()

        # Step 2: Move files
        move_files()

        # Step 3: Update references
        update_all_references()

        # Step 4: Update project.godot
        update_project_godot()

        # Step 5: Verify
        verify_reorganization()

        # Step 6: Summary
        print_summary()

        print("\n✅ REORGANIZATION COMPLETE!")
        print("\nYou can now open Godot and test your project.")

    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        print("\nTo restore backup:")
        print("1. Close Godot")
        print("2. Delete Test-1-Godot folder")
        print("3. Rename Test-1-Godot-BACKUP to Test-1-Godot")

if __name__ == "__main__":
    main()
