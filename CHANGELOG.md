# Changelog

## 0.1.0

- Windows follows the primary macOS interface with inline reset-credit details, responsive activity cards and section icons, earlier-update/history/source disclosures, and a separate refresh-cadence footer. Direct GDI text and website links remain intact.
- Native Windows announcement acknowledgements use the service record ID and include only displayed records; pending public responses are consumed before another request starts.

- Windows CLI discovery rejects desktop GUI hosts and prefers an extracted console CLI only when its SHA-256 matches the installed Store package, restoring quota reads from the Start menu or taskbar without Codex-injected environment variables.

- Windows outside-click detection uses physical screen coordinates on scaled monitors, so the reset-details link and owned dialogs stay interactive. Native regressions exercise the production hook and floating handler in multiple DPI contexts.

- Local account quota recovery history with before/after percentages, observation and detection times, persistent account isolation, and a combined newest-first list with public reset news. Older recoveries share the history section. Public delivery status remains independent.
- Clicking outside the detail widget returns to its saved compact geometry. Tighter detail spacing and automatic default sizing reduce scrolling while keeping long records accessible.
- Windows compact and detailed views remember separate positions across switches and restarts, preserving legacy placement and keeping restored windows within the available screen.
- Quiet unread-announcement dot in compact mode, with localized hover text, persistent read state, and no first-use alerts for existing records.
- Neutral labels for historical announcements without delivery records; macOS Dock quota numbers omit the percent sign and leave space inside the ring.
- Compact and detailed floating quota views, with saved size and position, Windows tray controls, and macOS menu bar/Dock controls.
- English, Simplified Chinese, and system-language selection shared by the native UI and browser detail page.
- Available banked-reset count plus optional grant and expiry details, without exposing reset identifiers or using a reset.
- One-minute quota updates, prompt manual/reopen/wake refresh, and automatic 15/30/60-second retries for temporary failures.
- Standalone macOS Apple Silicon/Intel app packages and a per-user Windows x64 installer, each including Node.js 24.19.0 and its license.
- Confirmed banked reset grants and global reset notices remain visible through source outages; evidenced completion is retained for 24 hours before moving to history.
- Detailed views show relative update ages, Plus-only five-hour usage, announcement and delivery history, and separate quota/public refresh intervals. The macOS default detail height fits its content within the screen.
- Consistent refresh, compact, and hide toolbar icons, with narrow-window layouts and localized accessibility labels.
- Official English reset names, consistent Chinese translations and explicit automatic-refresh labels; bilingual documentation explains third-party source delays and announcement boundaries.
- Windows runtime detection waits for the native version probe to finish, preventing a valid bundled Node.js 24 runtime from being rejected during startup or upgrade.

The macOS app is ad hoc signed and is not Developer ID signed or notarized. The Windows installer is unsigned. A signed-in official Codex installation is required.
