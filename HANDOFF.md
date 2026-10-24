# Project maintenance notes

## 2026-10-24 — Fixed widget appearance and independent system entry points

- Applies to the compact widget and expanded page on macOS and Windows.
- Symptom: Windows in dark mode could still show a light widget when its separate app mode was light. The native window followed `AppsUseLightTheme`, while the shared browser page already used a fixed dark palette.
- Keep widget surfaces on the accepted macOS dark-gray palette (`#20252D`). On Windows, legacy `-Theme System/Light/Dark` inputs remain accepted for compatibility and all select the fixed appearance. Dynamic inline controls must receive the same palette without rebuilding the visible tree on repeated checks.
- On macOS, pin only the content root to Dark Aqua. Do not set the entire application's appearance: native menus and menu-bar numerals should retain system behavior.
- Windows tray numeral contrast follows `SystemUsesLightTheme` independently. Preserve this lookup when changing window styling; taskbar and app modes can differ.
- Verification: `windows/test/native-appearance.tests.ps1` executes palette selection with fabricated modes; `windows/test/native-ui-parity.tests.ps1` checks actual WinForms surfaces and tray pixels on Windows. `macos/test/native-appearance.test.mjs` executes production content setup and compact drawing under Aqua/Dark Aqua. Follow CONTRIBUTING for full core and native suites.
- These automated checks do not establish physical Windows/macOS theme-switch acceptance or absence of transient white flashes. Verify those on the target desktop before reporting them as passed; keep private evidence outside this repository.

## 2026-10-24 — AppKit bitmap tests on wide-gamut displays

- Applies when comparing rendered AppKit pixels with literal sRGB palette values.
- Symptom: a Display P3 compact-view bitmap sampled through `colorAt(...).usingColorSpace(.sRGB)` returned `[44,49,58]` for the intended dark background; the unconverted bitmap carried `[33,37,44]` and a Display P3 profile.
- Convert the bitmap with `converting(to: .sRGB, renderingIntent: .default)` before `getPixel`. The same saved bitmap then returned the exact sRGB `[32,37,45,255]`. Sample clear canvas outside the ring's antialiased edge.
- This corrects the test's color-space handling, without changing the shipped palette. The native appearance regression uses the profile-aware path and keeps the literal background assertion.
