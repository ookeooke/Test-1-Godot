# Godot MCP Server

This MCP server enables Claude Code to directly communicate with your Godot project.

## Features

The server provides the following tools:

### 🎮 **godot_open_editor**
Opens the Godot editor for this project.

**Example:** "Open the Godot editor"

### ▶️ **godot_run_main**
Runs the main scene (equivalent to pressing F5 in the editor).

**Example:** "Run the game"

### 🎬 **godot_run_scene**
Runs a specific scene file.

**Parameters:**
- `scene_path`: Path to the .tscn file (e.g., "scenes/levels/level_01.tscn")

**Example:** "Run the level_01 scene"

### 📁 **godot_list_scenes**
Lists all .tscn scene files in the project.

**Parameters:**
- `filter` (optional): Filter scenes by keyword (e.g., "levels")

**Example:** "List all level scenes"

### ℹ️ **godot_get_project_info**
Displays project information from project.godot.

**Example:** "Show me the project settings"

### 📦 **godot_export_project**
Exports the project for a specific platform.

**Parameters:**
- `platform`: Platform name (e.g., "Windows Desktop", "Android")
- `output_path`: Output file path

**Example:** "Export the game for Windows"

## Configuration

**Godot Path:** `C:\Users\ollil\Downloads\Godot_v4.5.1-stable_win64.exe (1)`
**Project Path:** `C:\Users\ollil\Test-1-Godot`

## Installation

Dependencies are already installed:
- Python 3.13.3
- MCP SDK 1.21.2

## Usage

After restarting VS Code, the MCP server will automatically connect when you open Claude Code.

You can then ask Claude to:
- "Open Godot editor"
- "Run the main scene"
- "List all scenes in the project"
- "Run level_01.tscn"
- And more!

## Files

- `godot_server.py` - MCP server implementation
- `requirements.txt` - Python dependencies
- `../.claude/mcp.json` - MCP configuration

## Troubleshooting

If the server doesn't connect:
1. Check VS Code Output panel (View → Output → "Claude Code")
2. Ensure Python is in your PATH
3. Verify Godot path is correct in `godot_server.py`
4. Reload VS Code window (Ctrl+Shift+P → "Reload Window")
