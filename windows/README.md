# Windows setup

English | [简体中文](README.zh-CN.md)

The Windows version uses a floating window and system tray controls. The current application interface is in Simplified Chinese.

## Requirements

Install [Node.js 24 or later](https://nodejs.org/en/download) and [Codex CLI](https://learn.chatgpt.com/docs/codex/cli). In PowerShell, check:

```powershell
node --version
codex --version
codex login status
```

If not signed in, run `codex login` with the ChatGPT account to monitor.

## Install and start

1. Download **Code → Download ZIP** from the repository and extract it into a permanent folder.
2. Open the `windows` subfolder and double-click `Start.cmd`.
3. Keep the complete folder together. The current source distribution is not a standalone installer.

For a desktop shortcut, right-click `Start.cmd`, choose **Show more options → Send to → Desktop (create shortcut)**. Recreate the shortcut if you move the installation folder. Startup at login is not configured.

## Daily use

- Click “极简” (Compact) to collapse the detailed view. Click the compact ring to expand.
- Drag window content to move it. Drag left/right edges to change width, top/bottom edges to change height, or corners to change both. Both modes support resizing.
- Click `×` to hide the detailed window to the tray. Double-click the tray icon to show it again. The tray menu also offers display, mode, refresh, always-on-top, and quit controls.
- The detailed view shows weekly quota, reset time, countdown, update time, and available rate-limit reset count. Plus accounts also show a five-hour window when available.
- Public reset announcements and probability estimates appear below account data. Their source links open in your browser. These estimates are not guaranteed reset times.
- Double-click `Stop.cmd` to stop the window and service. The scripts verify process ownership before stopping them.

## Troubleshooting

If data is unavailable, check `codex login status` and refresh. If the service stops, run `Stop.cmd` followed by `Start.cmd`.

Logs and current runtime records are stored in `%TEMP%\CodexWeeklyMonitor`. The local service uses `127.0.0.1:39224`; only run one copy at a time. Do not include those logs or private account responses in public bug reports.

Quota is queried every five minutes. Values older than ten minutes or past their reset time are not treated as current quota. Windows UI behavior must be verified on a Windows machine when making platform-specific changes.
