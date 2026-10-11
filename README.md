# Codex Quota Widget

English | [简体中文](README.zh-CN.md)

A small Windows and macOS desktop widget for Codex quota. See remaining weekly quota, reset time and countdown, the last successful update, and available banked resets. Plus accounts also show the five-hour window when provided by Codex.

This is an independent, unofficial tool, with no OpenAI affiliation or endorsement.

## Install

Version **0.1.0** packages include Node.js **24.19.0** and its license. You do not need to install Node or developer tools to use a prebuilt package.

| Platform | Package | Installation guide |
| --- | --- | --- |
| macOS 13.5+, Apple Silicon | `CodexQuotaWidget-0.1.0-macos-arm64.zip` | [macOS](macos/README.md) |
| macOS 13.5+, Intel | `CodexQuotaWidget-0.1.0-macos-x64.zip` | [macOS](macos/README.md) |
| Windows x64 | `CodexQuotaWidget-0.1.0-windows-x64.exe` | [Windows](windows/README.md) |

Use the package and `SHA256SUMS` supplied for the same build. Private build artifacts are available to repository collaborators under **Actions → Build packages → a successful run → Artifacts**. The workflow does not publish a GitHub release.

Install the official [Codex desktop app](https://learn.chatgpt.com/docs/app) or [Codex CLI](https://learn.chatgpt.com/docs/codex/cli), then sign in with the ChatGPT account to monitor. The widget needs a discoverable Codex CLI/App Server. If your desktop installation is not detected, install the official CLI and run `codex login`. No Codex executable or login credentials are redistributed.

The macOS app is ad hoc signed, without Developer ID signing or Apple notarization. The Windows installer is unsigned. Your operating system may show a security prompt; verify the source and checksum before approving it.

To run from source, install Node.js 24+ and follow the platform guide. macOS source builds also need Apple Command Line Tools. Only run one copy per computer: the service uses `127.0.0.1:39224`.

## Use

- Switch between a compact percentage ring and detailed view; drag to move or resize. Each mode remembers its position and size. On macOS, the default detail height fits the content within the available screen; manually resizing keeps your chosen size.
- Use the Windows tray menu or macOS menu bar to show the window, refresh, change language, or quit. The macOS Dock icon also shows remaining weekly quota.
- A small amber dot in compact mode marks a new confirmed banked reset grant or global reset announcement. Hover for its type; open details to clear the notices shown there. Existing records on first use do not trigger the dot, and read notices stay read after a restart. There is no sound or flashing. The macOS Dock ring uses a number without a percent sign.
- Choose **Language → System / English / 简体中文**. System selects Chinese for a Chinese system language and English otherwise. The browser detail page and native UI share the saved choice.
- Open the **Banked resets / Details** row to see the authoritative available count and any grant or expiry dates Codex provides. Missing dates are shown as unavailable. The widget never spends a banked reset or predicts future grants. Banked resets are separate from paid usage credits and the normal reset countdown.
- **My quota recoveries** records increases between successful local quota observations, independently of public announcements. Recoveries appear alongside public reset news, newest first, with before/after percentages and the local detection time. After 24 hours they move into **History**, where the previous observation time is also available. No separate empty recovery section is shown. Tracking begins with the first observation; earlier changes require real saved observations and cannot be inferred from the current quota alone. Records survive restarts, are separated by account, and keep the latest 50 increases. Detection does not establish the exact reset time, its cause, or delivery to all users. Plan changes establish a new baseline.

Quota queries and cache checks run every **60 seconds**. Manual refresh, reopening, and waking the computer refresh promptly; simultaneous requests are combined. Temporary query failures retry after **15, 30, then 60 seconds**. Unavailable, expired, or stale quota is shown as `—`, rather than continuing to present an old percentage as current.

Confirmed banked reset grants and global reset announcements stay visible until delivery is confirmed, then remain for 24 hours before moving into history. Known pending announcements survive source outages and app restarts. Five-hour usage is shown only for a confirmed Plus plan; Pro and unknown plans hide that row.

Announcement cards and history show the newest publication first. The widget reads original announcement text from codex-reset.com and archived evidence from codexreset.dev. Narrow phrase rules recognize explicit promises and completion statements; tracker categories alone, conditions and teasers do not confirm a reset. Publication times are retained, and a completion statement is labelled **Completion statement posted**, not the exact delivery time for your account. Original-post links remain available.

One recent same-kind promise can be paired with a later completion statement within 48 hours; ambiguous multiple promises remain separate. Mirrored records are deduplicated by original-post URL. These partial feeds cannot withdraw cached announcements by omission. Pending original-feed announcements remain active until completion; old promises first discovered in the archive remain in history. An unspecified EOD deadline is never converted into a precise local time or timezone. Older cached schedules remain readable.

When mirror categories conflict, an explicit type in the complete original post also corrects the cached type for that URL. Later partial archive updates preserve that correction.

Historical announcements without delivery evidence say **Source did not provide a delivery record**. An account's personal grant date does not confirm delivery of a public announcement to every account.

After a scheduled time passes, a missing public completion record is shown neutrally as a monitoring-source status. Your account's quota updates independently; restored personal quota does not prove that a global reset has finished for all accounts.

Public reset announcements and delivery records from [codex-reset.com](https://codex-reset.com/) and [codexreset.dev](https://codexreset.dev/) refresh separately every **10 minutes**.

The footer states **Auto-refresh: quota every 1 min · public data every 10 min**. The widget reads structured tracker APIs; it does not search X or use an AI model. Phrase matching on the supplied original text is conservative and may miss unfamiliar wording. Provider records may be delayed or incomplete. See [terms and data sources](docs/TERMINOLOGY.md) for official reset names, translated labels and source boundaries.

## Privacy and troubleshooting

The local service uses the read-only `account/read` and `account/rateLimits/read` methods of [Codex App Server](https://learn.chatgpt.com/docs/app-server). It listens only on loopback. No OpenAI API key is required. Account quota and login information are not sent to the public reset sites; settings and logs stay on your computer.

Local recovery history stores quota percentages, observation times and a salted account fingerprint in `quota-recovery.json` in the widget's settings directory. It does not store the account email or login credentials. The latest five account histories are retained; tracking is unavailable if Codex provides no stable account identifier.

If quota is unavailable, follow the displayed instruction, check `codex login status`, and choose **Refresh**. The platform guides list log locations and restart/uninstall steps. Do not share credentials, raw account responses, unredacted logs, or personal account screenshots in bug reports.

App Server can change with Codex updates. Hosted-runner tests use fabricated data; they do not prove real-account login or physical Intel Mac/Windows desktop compatibility. The Windows installer offers startup at login as an optional unchecked task. System notifications and remote sync are not included.

## Development and license

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests and builds, and [CHANGELOG.md](CHANGELOG.md) for version notes.

macOS sets the shared product baseline; Windows follows it. [Project rules](AGENTS.md) define the maintenance and desktop-validation workflow. The core test command and package CI reject differences or missing counterparts in shared service, browser, and test files.

[MIT](LICENSE), copyright 2026 AjiaGit, applies to project code and documentation. Bundled dependencies and external services retain their own terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
