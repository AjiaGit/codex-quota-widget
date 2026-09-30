# macOS setup

English | [简体中文](README.zh-CN.md)

The macOS widget shows remaining weekly Codex quota in the menu bar and provides compact and detailed floating windows. The current application interface is in Simplified Chinese.

## Requirements

- Node.js 24 or later.
- Codex CLI installed and signed in with the ChatGPT account to monitor.
- Apple Command Line Tools for compiling the native widget on first launch.

A Codex desktop-app session does not necessarily establish a separate CLI login. Check `node -v`, `codex --version`, and `codex login status`; run `codex login` if needed.

## Install and start

1. Download **Code → Download ZIP** from the repository and extract it.
2. Move the complete `codex-quota-widget-main` folder into `~/Applications/` or another permanent folder. Keep the generated apps, scripts, and source files together.
3. Run `xcode-select --install` if Apple Command Line Tools are missing.
4. Open the `macos` subfolder in Finder and double-click `Start.command`. It compiles the widget and Dock launcher on first launch. If the script opens as text, run `bash ` in Terminal, drag the script into Terminal, and press Return. Resolve any macOS security prompt through the normal system controls.
5. The script creates `启动 Codex 周额度.app` in the `macos` folder. Drag this launcher to the Dock. Clicking it starts the widget or shows its window again.

The repository does not include a ready-to-install, signed and notarized app. Source builds currently require the steps above.

## Daily use

- Click the menu-bar percentage to show/hide the floating window, switch compact/detail mode, refresh, open the detailed page in a browser, or quit.
- Click the compact ring to expand. Drag the window to move it; drag its edges or corners to resize it. The minimum compact size is 36×36.
- In detailed mode, click “极简” (Compact) to collapse, “刷新” (Refresh) to query quota, or `×` to hide the window.
- Each mode remembers its own position and size. Moving and resizing are constrained to the screen's usable area. The detailed content can scroll.
- The Dock icon displays remaining weekly quota. Unavailable data displays `—`.
- Double-click `Stop.command` to stop the tool, or use the menu's quit command. Start it again through `Start.command` or the Dock launcher. Startup at login is not configured.

## Refresh and troubleshooting

The service queries Codex every five minutes. The detailed page reads the cache every minute; the menu bar and Dock read it every thirty seconds. Public-source data is checked every ten minutes. Account data is not sent to those sources.

If the widget displays `—`, check `codex login status` and refresh. If necessary, stop and start the tool. Logs are stored in `~/Library/Application Support/CodexWeeklyMonitor/`: `monitor.log`, `build.log`, and `launcher-build.log`.

Keep the installation folder in place: the Dock launcher relies on its neighboring scripts and service files. Only run one installation at a time because the service uses `127.0.0.1:39224`.

The native widget has been compiled and exercised on Apple Silicon. Intel Macs and other macOS versions require separate verification.
