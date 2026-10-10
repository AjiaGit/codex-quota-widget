# Windows setup

English | [简体中文](README.zh-CN.md)

## Installer

1. Use 64-bit Windows with Windows PowerShell 5.1 and Windows Forms (Windows 10/11). Install the official [Codex desktop app](https://learn.chatgpt.com/docs/app) or [Codex CLI](https://learn.chatgpt.com/docs/codex/cli), and sign in with the ChatGPT account to monitor.
2. Compare the installer with the supplied `SHA256SUMS`: in PowerShell, run `Get-FileHash .\CodexQuotaWidget-0.1.0-windows-x64.exe -Algorithm SHA256`.
3. Run **CodexQuotaWidget-0.1.0-windows-x64.exe**. The per-user installer includes Node.js 24.19.0 and creates a Start Menu entry. A separate Node installation is not needed.
4. Open **Codex Quota Widget** from Start. If the widget cannot find Codex or requests sign-in, use the displayed installation/login action. For a separate CLI installation, run `codex login`, then choose **Refresh**.

While running, the widget adds an icon to the notification area near the clock; Windows may place it in the hidden-icons overflow. Installing without launching does not show that icon. A pinned taskbar shortcut is an optional launcher, independent of the notification-area icon.

The widget installer is unsigned, so Windows may display an unknown-publisher or SmartScreen prompt. Check the source and checksum before deciding to run it. Only run one copy; the local service uses `127.0.0.1:39224`.

## Daily use

- Click the **minus icon** or outside the detailed window to collapse; click the ring to expand. Each mode remembers its position and size. Drag the window to move it or its edges/corners to resize. The detail window fits current content, including inline disclosures, within the screen and opens at the top. Content longer than the screen or a manually reduced window can scroll. This update restores automatic height for older Windows layouts while preserving positions, widths, and the compact size; subsequent manual resizing is remembered.
- Click `×` to hide to the tray. Double-click the tray icon to show it again. The tray menu includes mode, refresh, always-on-top, language, and quit controls.
- Choose **Language → System / English / 简体中文**. Native UI and browser detail page share the saved choice.
- Open **Banked resets / Details** to expand the available grant/expiry information inside the main window. Click again to collapse it. The widget never uses a banked reset.
- **Your quota recovered** appears alongside public reset news with the local detection time. Expand **About this record** for before/after percentages, the previous reading time, and the explanation. After 24 hours it moves into **History**. Tracking starts with the first observation and survives restarts, separately for each account. It does not confirm delivery of a global reset.

The Windows interface follows the accepted macOS layout: ring and countdown, the Plus-only five-hour row, inline banked-reset details, activity cards, history, data sources, and refresh cadence. Expand **Message details**, **Earlier updates**, **History**, or **Data sources** in place. Announcement time and scheduled/delivered time remain separate; the local UTC offset is shown above the activity list.

Quota and cache checks run every 60 seconds. Manual refresh, reopening, and wake trigger a prompt update. Temporary failures retry at 15/30/60 seconds. Public reset data refreshes every 10 minutes.

## Update and uninstall

Quit the widget, then run the newer installer to update the same per-user installation. Uninstall through **Settings → Apps → Installed apps → Codex Quota Widget**. Uninstall preserves language and window preferences. To remove them first, open PowerShell in the installation folder and run `.\Stop.ps1 -RemovePreferences`. Startup at login is an optional installer task, unchecked by default.

Settings, geometry, and logs live in `%LOCALAPPDATA%\CodexWeeklyMonitor`. Existing source installations migrate saved preferences from `%TEMP%\CodexWeeklyMonitor` while preserving the old files. Share only sanitized logs.

## Troubleshooting and source use

If quota is unavailable, follow the displayed instruction, check `codex login status`, and refresh. To restart a source installation, run [Stop.cmd](Stop.cmd) then [Start.cmd](Start.cmd). Logs include `stderr.log` and `floating-stderr.log` in the data folder.

Source use requires [Node.js 24+](https://nodejs.org/en/download) and signed-in Codex. Keep the complete repository together and double-click [Start.cmd](Start.cmd). A desktop shortcut can point to that file; moving the folder requires updating the shortcut. [Stop.cmd](Stop.cmd) stops only the processes identified as belonging to this installation.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for installer builds. Windows hosted-runner smoke tests use fabricated data and cover installation lifecycle; they do not verify your account's login or every physical Windows desktop.
