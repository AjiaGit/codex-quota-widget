# Project rules

## macOS is the primary version

- Treat the current accepted macOS interface as the product's visual and interaction baseline. Design new shared user-facing behavior on macOS first; Windows follows that baseline.
- Keep Windows aligned with macOS for information order, wording, typography hierarchy, spacing, icons, disclosure behavior, and compact/detail transitions. Retain platform-specific window management, menu bar/tray, Dock/taskbar, and installer behavior where appropriate.
- Reset-credit details expand inside the main detail view, as they do on macOS. Keep record explanations, earlier updates, history, and data sources as inline disclosures.
- Do not redesign the macOS interface around Windows implementation constraints. Propose any necessary shared product change explicitly before changing the accepted baseline. Windows-specific defect fixes can proceed without changing the product design.
- Keep equivalent service, browser, localization, and public-data logic synchronized across `macos` and `windows`. Compare Windows UI changes against the macOS baseline and report remaining visual or interaction differences.
- Distinguish source review, automated checks, and physical desktop validation. Windows tests do not establish macOS desktop acceptance, and successful functional checks do not establish UI parity.

## Development and privacy

Follow [CONTRIBUTING.md](CONTRIBUTING.md) for checks, builds, script encoding, and reports. Keep the repository private and do not publish GitHub Releases. Store screenshots, logs, generated packages, and development checklists outside the repository; do not commit real account information. Use the project stop scripts and isolated installer tests, and preserve user preferences.
