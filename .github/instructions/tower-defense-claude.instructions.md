If something is unclear, ask one short clarification question.  investigation of ALL sources of problem, not just the tweens and modulation.

applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes. Don't create any documentation files. Just implement the code and explain changes in your message.Game is for mobile and steam platforms. Godot v4.5.1 stable.official 

## Code Style
- Keep it simple
- No premature optimization
- No "best practices" unless requested

## When Suggesting Changes
- Ask before refactoring
- Explain trade-offs (simple vs scalable)
- Default to keeping existing code

## Forbidden Actions
- Creating event buses without permission
- Adding signal systems without permission
- Refactoring working code without permission

**IMPORTANT:** Camera system is LOCKED. See `camera-system-rules.md` for details.

**DO NOT:**
- Create event buses for camera
- Add signal-based architecture
- Create wrapper functions
- Suggest refactoring

**DO:**
- Use existing camera methods directly
- Call `camera.add_shake()`, `camera.snap_to_object()`, etc.

if you need to change somethign here tell me why and ask for permission first. 

Never make quick workaround.
[876b29033]

## Git Safety Rules:
- NEVER use `git reset --hard` without my explicit approval
- NEVER use force commands (push --force, etc.)
- Always use `git stash` to preserve uncommitted work
- If something breaks → revert immediately, don't try to "fix forward"

If you need to check histyry data: 

https://github.com/ookeooke/Test-1-Godot

## Error Checking Protocol

When checking for errors in the project:

1. **Always check Godot's Output/Console** - Runtime and parse errors only appear when Godot loads scripts
2. **Check VS Code Problems panel** - For LSP-detected issues
3. **Static analysis** - Check file syntax and configuration
4. **Git status** - Check for conflicts or uncommitted issues

**IMPORTANT**: Static code analysis alone is NOT sufficient. Many GDScript errors (parse errors, missing identifiers, invalid UIDs) only appear when Godot actually loads the project.

### How to Check Godot Errors:
- Look for error count indicators in Godot's output panel (🔴 red X icon)
- Check warning count (⚠️ yellow triangle icon)
- Read the actual error messages in the output console
- Pay attention to UID warnings for resources