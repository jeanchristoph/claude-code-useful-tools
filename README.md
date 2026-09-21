# claude-code-useful-tools

Small utilities around [Claude Code](https://code.claude.com) on Windows. Each tool lives in its own folder and is
self-contained: no installer, no registry write, no scheduled task — launch it by hand, stop it when you are done.

## Tools

### `mute-call-while-dictating/`

Mutes the current Teams/Zoom call while Claude Code records a voice prompt, and unmutes it when the recording ends.

Claude Code exposes no hook for voice recording, but Windows records when each application opens the microphone.
The script polls those timestamps for `claude.exe` (read-only) and sends the Windows 11 global call-mute shortcut
(`Win+Alt+K`) on each transition. That shortcut only affects call applications subscribed to the Windows call-mute
API — Claude Code keeps hearing you.

```
mute-call-while-dictating\mute-call-while-dictating.bat
```

Double-click the `.bat` (or run the `.ps1` with `-ExecutionPolicy Bypass`), keep the window open, dictate as usual.
Start dictating while you are **unmuted** in the call: `Win+Alt+K` is a toggle and Windows does not expose the
current mute state.

Tests: `Invoke-Pester -Path .\mute-call-while-dictating\mute-call-while-dictating.tests.ps1` (Pester 3.x, shipped
with Windows PowerShell 5.1).
