#!/usr/bin/env python3
"""
Godot MCP Server
Provides tools for Claude Code to interact with Godot Engine
"""

import asyncio
import json
import os
import subprocess
from pathlib import Path
from typing import Any

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# Godot configuration
GODOT_PATH = r"C:\Users\ollil\Downloads\Godot_v4.5.1-stable_win64.exe (1)"
PROJECT_PATH = r"C:\Users\ollil\Test-1-Godot"

# Create MCP server instance
app = Server("godot-server")


@app.list_tools()
async def list_tools() -> list[Tool]:
    """List available Godot tools."""
    return [
        Tool(
            name="godot_open_editor",
            description="Open the Godot editor for this project",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": [],
            },
        ),
        Tool(
            name="godot_run_scene",
            description="Run a specific scene in Godot",
            inputSchema={
                "type": "object",
                "properties": {
                    "scene_path": {
                        "type": "string",
                        "description": "Path to the .tscn file (e.g., 'scenes/levels/level_01.tscn')",
                    }
                },
                "required": ["scene_path"],
            },
        ),
        Tool(
            name="godot_run_main",
            description="Run the main scene (F5 in editor)",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": [],
            },
        ),
        Tool(
            name="godot_list_scenes",
            description="List all .tscn scene files in the project",
            inputSchema={
                "type": "object",
                "properties": {
                    "filter": {
                        "type": "string",
                        "description": "Optional filter (e.g., 'levels' to find level scenes)",
                    }
                },
                "required": [],
            },
        ),
        Tool(
            name="godot_get_project_info",
            description="Get project information from project.godot",
            inputSchema={
                "type": "object",
                "properties": {},
                "required": [],
            },
        ),
        Tool(
            name="godot_export_project",
            description="Export the project for a specific platform",
            inputSchema={
                "type": "object",
                "properties": {
                    "platform": {
                        "type": "string",
                        "description": "Platform to export (e.g., 'Windows Desktop', 'Android')",
                    },
                    "output_path": {
                        "type": "string",
                        "description": "Output file path for the export",
                    }
                },
                "required": ["platform", "output_path"],
            },
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: Any) -> list[TextContent]:
    """Handle tool calls."""

    if name == "godot_open_editor":
        return await open_editor()
    elif name == "godot_run_scene":
        return await run_scene(arguments["scene_path"])
    elif name == "godot_run_main":
        return await run_main()
    elif name == "godot_list_scenes":
        filter_text = arguments.get("filter", "")
        return await list_scenes(filter_text)
    elif name == "godot_get_project_info":
        return await get_project_info()
    elif name == "godot_export_project":
        return await export_project(arguments["platform"], arguments["output_path"])
    else:
        raise ValueError(f"Unknown tool: {name}")


async def open_editor() -> list[TextContent]:
    """Open Godot editor."""
    try:
        # Start Godot editor (non-blocking)
        subprocess.Popen(
            [GODOT_PATH, "--path", PROJECT_PATH, "--editor"],
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )
        return [TextContent(
            type="text",
            text=f"✓ Opening Godot editor for project: {PROJECT_PATH}"
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to open editor: {str(e)}"
        )]


async def run_scene(scene_path: str) -> list[TextContent]:
    """Run a specific scene."""
    try:
        full_path = Path(PROJECT_PATH) / scene_path
        if not full_path.exists():
            return [TextContent(
                type="text",
                text=f"✗ Scene not found: {scene_path}"
            )]

        # Run the scene
        subprocess.Popen(
            [GODOT_PATH, "--path", PROJECT_PATH, scene_path],
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )
        return [TextContent(
            type="text",
            text=f"✓ Running scene: {scene_path}"
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to run scene: {str(e)}"
        )]


async def run_main() -> list[TextContent]:
    """Run the main scene (F5)."""
    try:
        subprocess.Popen(
            [GODOT_PATH, "--path", PROJECT_PATH],
            creationflags=subprocess.CREATE_NEW_CONSOLE
        )
        return [TextContent(
            type="text",
            text="✓ Running main scene (F5)"
        )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to run main scene: {str(e)}"
        )]


async def list_scenes(filter_text: str = "") -> list[TextContent]:
    """List all .tscn files in the project."""
    try:
        scenes = []
        for root, dirs, files in os.walk(PROJECT_PATH):
            # Skip hidden and build directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['build', 'exports']]

            for file in files:
                if file.endswith('.tscn'):
                    rel_path = os.path.relpath(os.path.join(root, file), PROJECT_PATH)
                    if not filter_text or filter_text.lower() in rel_path.lower():
                        scenes.append(rel_path)

        scenes.sort()
        result = f"Found {len(scenes)} scene(s)"
        if filter_text:
            result += f" matching '{filter_text}'"
        result += ":\n\n" + "\n".join(f"  - {s}" for s in scenes)

        return [TextContent(type="text", text=result)]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to list scenes: {str(e)}"
        )]


async def get_project_info() -> list[TextContent]:
    """Read project.godot configuration."""
    try:
        project_file = Path(PROJECT_PATH) / "project.godot"
        if not project_file.exists():
            return [TextContent(
                type="text",
                text="✗ project.godot not found"
            )]

        with open(project_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract key information
        info = []
        for line in content.split('\n'):
            if any(key in line for key in ['config/name=', 'config/version=', 'run/main_scene=', 'config/features=']):
                info.append(line.strip())

        result = "Godot Project Information:\n\n" + "\n".join(info)
        return [TextContent(type="text", text=result)]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to read project info: {str(e)}"
        )]


async def export_project(platform: str, output_path: str) -> list[TextContent]:
    """Export the project."""
    try:
        result = subprocess.run(
            [GODOT_PATH, "--path", PROJECT_PATH, "--export", platform, output_path, "--headless"],
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )

        if result.returncode == 0:
            return [TextContent(
                type="text",
                text=f"✓ Exported to: {output_path}\n\n{result.stdout}"
            )]
        else:
            return [TextContent(
                type="text",
                text=f"✗ Export failed:\n{result.stderr}"
            )]
    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to export: {str(e)}"
        )]


async def main():
    """Run the MCP server."""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    asyncio.run(main())
