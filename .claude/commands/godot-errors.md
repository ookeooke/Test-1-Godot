# Godot Error Checker

Read the most recent Godot log file from:
`C:\Users\ollil\AppData\Roaming\Godot\app_userdata\Test 1\logs\godot.log`

Search for all ERROR and WARNING messages in the last 200 lines.

For each error/warning found:
1. Show the error message
2. Identify which script/scene caused it
3. Explain what it means in simple terms
4. Suggest a fix with code if applicable

If no errors found, report "✅ No errors in recent logs"

Format output as:
## 🔴 Errors
- [error details]

## ⚠️ Warnings
- [warning details]

## 🔧 Suggested Fixes
- [fixes]
