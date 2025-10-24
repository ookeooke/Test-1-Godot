---
applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes. Don't create any documentation files. Just implement the code and explain changes in your message.Game is for mobile and steam platforms. Godot v4.5.stable.official 

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