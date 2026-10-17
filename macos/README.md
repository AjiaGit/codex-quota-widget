# macOS setup

English | [简体中文](README.zh-CN.md)

## Prebuilt app

1. Use macOS **13.5 or later**. In **Apple menu → About This Mac**, choose the `arm64` ZIP for Apple Silicon or `x64` ZIP for Intel.
2. Install the official [Codex desktop app](https://learn.chatgpt.com/docs/app) or [Codex CLI](https://learn.chatgpt.com/docs/codex/cli), and sign in. If the widget cannot find the desktop app's CLI, install the CLI separately and run `codex login`.
3. Verify the ZIP against the supplied `SHA256SUMS` with `shasum -a 256 <filename>`. Extract it and move **Codex Quota Widget.app** to `/Applications` or `~/Applications`.
4. Open the app, then drag it to the Dock if desired. Its bundled Node.js 24.19.0 runs the local service; no Node installation or compiler is needed.

This app is ad hoc signed, without Developer ID signing or notarization. If macOS blocks it, verify the source and checksum, then use the system's **Privacy & Security → Open Anyway** control if available. Do not disable system-wide security protections.

Only run one copy. The service uses `127.0.0.1:39224`.

## Daily use

- Click the menu-bar percentage to show or hide the window, select compact/detail mode, refresh, open the browser detail page, change language, or quit.
- Choose **Language → System / English / 简体中文**. The choice is saved and shared with the browser detail page.
- Click the compact ring to expand; click outside the detailed window to return to its saved compact position and size. Drag the window to move it, or its edges/corners to resize. The default detail window fits its content when screen space permits; long history or a manually reduced window can scroll.
- Open **Available resets / Details** for the available reset count and any provided grant/expiry dates. The widget only reads this information.
- The Dock icon shows remaining weekly quota, or `—` when data is unavailable. Clicking it reopens the widget.
- **Your quota has recovered** appears in the same list as public reset news, with the local detection time; before/after percentages are shown in **About this record**. After 24 hours it moves into folded history in the activity section. History opens three records at a time and can collapse. Tracking starts when enabled and persists across restarts; a personal recovery does not confirm a global reset.

Messages and records automatically move older entries into folded history. All valid quota-reset previews stay visible; expired previews retain their uncertain completion status. History opens three records at a time and can collapse. With healthy sources and no current records, the section says **No new messages**. Important linked changes resurface and can remind again.

Quota and cache checks run every 60 seconds. Refresh, reopening, and wake trigger a prompt update. Temporary failures retry at 15/30/60 seconds; public preview sources refresh about every minute with source backoff, and the compact indicator cache refreshes about every 15 seconds.

## Update, quit, and uninstall

Choose **Quit** before replacing the app with a newer copy in the same location. Reopen it afterwards; saved language and window geometry remain in `~/Library/Application Support/CodexWeeklyMonitor/`.

To uninstall, quit and move the app to Trash. To remove saved preferences and logs as well, delete `~/Library/Application Support/CodexWeeklyMonitor/` after quitting. The widget does not configure startup at login.

## Troubleshooting and source use

If the UI asks you to sign in, check `codex login status`, run `codex login` if needed, then refresh. For startup errors, inspect `monitor.log` in `~/Library/Application Support/CodexWeeklyMonitor/`; source compilation logs are `build.log` and `launcher-build.log`. Share only sanitized excerpts.

Source use requires [Node.js 24+](https://nodejs.org/en/download), signed-in Codex, and Apple Command Line Tools (`xcode-select --install`). Keep the whole repository together and double-click [Start.command](Start.command); use [Stop.command](Stop.command) to stop it. The source launcher compiles locally and its generated launcher depends on neighboring service files. If Finder opens a script as text, run it with `bash` in Terminal.

See [CONTRIBUTING.md](../CONTRIBUTING.md) to build a standalone app. Native CI covers Apple Silicon and Intel runner builds; it does not certify physical Intel hardware or real-account login on every macOS version.
