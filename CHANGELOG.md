# Changelog

## 0.1.0

- Compact and detailed floating quota views, with saved size and position, Windows tray controls, and macOS menu bar/Dock controls.
- English, Simplified Chinese, and system-language selection shared by the native UI and browser detail page.
- Available banked-reset count plus optional grant and expiry details, without exposing reset identifiers or using a reset.
- One-minute quota updates, prompt manual/reopen/wake refresh, and automatic 15/30/60-second retries for temporary failures.
- Standalone macOS Apple Silicon/Intel app packages and a per-user Windows x64 installer, each including Node.js 24.19.0 and its license.
- Confirmed banked reset grants and global reset notices remain visible through source outages; evidenced completion is retained for 24 hours before moving to history.
- Detailed views show relative update ages, Plus-only five-hour usage, historical odds, and separate quota/public refresh intervals. The macOS default detail height fits its content within the screen.
- Consistent refresh, compact, and hide toolbar icons, with narrow-window layouts and localized accessibility labels.
- Official English reset names, consistent Chinese translations and explicit automatic-refresh labels; bilingual documentation explains third-party source delays and announcement boundaries.
- Windows runtime detection waits for the native version probe to finish, preventing a valid bundled Node.js 24 runtime from being rejected during startup or upgrade.

The macOS app is ad hoc signed and is not Developer ID signed or notarized. The Windows installer is unsigned. A signed-in official Codex installation is required.
