# Codex Quota Widget

English | [简体中文](README.zh-CN.md)

A lightweight floating widget for checking Codex usage on Windows and macOS. View remaining weekly quota, the next reset, a countdown, the last successful update, and available rate-limit resets. Plus accounts also show a five-hour window when that data is available.

This is an independent, unofficial tool. It is not affiliated with or endorsed by OpenAI.

## Features

- Compact percentage ring and a detailed view.
- Movable, resizable windows that remember their position and size.
- Windows system tray and macOS menu bar controls.
- A macOS Dock icon showing the current remaining percentage.
- Manual refresh and automatic quota checks every five minutes.
- Read-only display of available rate-limit resets; the widget does not redeem them.
- Optional public reset announcements and historical probability estimates from [codexreset.ai](https://codexreset.ai/) and [whenreset.app](https://whenreset.app/). These estimates are not promised reset times.

## Installation

The current distribution runs from source. There are no prebuilt installers in this repository. Download **Code → Download ZIP**, extract it, and keep the complete folder together.

| Platform | Requirements | Start | Stop |
| --- | --- | --- | --- |
| Windows | Node.js 24+ and Codex CLI signed in with ChatGPT | [windows/Start.cmd](windows/Start.cmd) | [windows/Stop.cmd](windows/Stop.cmd) |
| macOS | Node.js 24+, signed-in Codex CLI, Apple Command Line Tools | [macos/Start.command](macos/Start.command) | [macos/Stop.command](macos/Stop.command) |

Follow the [Windows guide](windows/README.md) or [macOS guide](macos/README.md) before starting. Only run one copy per computer: the local service uses `127.0.0.1:39224`.

English and Simplified Chinese documentation are available. The application interface currently uses Simplified Chinese. Runtime language selection is planned; English documentation does not yet mean an English interface.

## Data and privacy

The local service queries Codex CLI through the read-only `account/read` and `account/rateLimits/read` App Server methods. No OpenAI API key is required, and the widget does not modify the Codex desktop app.

- Account quota is queried every five minutes. Cached values older than ten minutes, expired reset windows, and failed queries are not displayed as current quota.
- The detailed page reads the local cache every minute. The macOS menu bar and Dock icon read it every thirty seconds.
- Public reset sources are checked separately every ten minutes. Account quota and login credentials are not sent to those sites.
- The HTTP service listens only on loopback. Runtime logs and settings stay on your computer.
- Login credentials, private account responses, generated apps, and runtime logs must not be included in repository contributions or release archives.
- Startup at login, notifications, and remote synchronization are not implemented.

## Rate-limit reset terminology

The user-facing name used by the [official App Server documentation](https://learn.chatgpt.com/docs/app-server) is **rate-limit reset**; the API field is `rateLimitResetCredits`. The Chinese interface currently uses “重置卡” as a short label. Reset credits are separate from paid usage credits and from the regular reset countdown.

The current widget displays the authoritative `availableCount`. Showing grant and expiry dates from optional detail rows is planned. A missing detail list does not mean zero available resets, and the API does not provide a schedule for future grants.

## Troubleshooting

Run `codex login status` and use the widget's refresh command. If the local service has stopped, stop and restart the widget using the platform scripts. The platform guides include log locations and build diagnostics.

Codex App Server is an experimental interface. Codex updates can require compatibility checks. This project currently supports the weekly window and conditionally shows five-hour data for Plus; it does not promise coverage of every plan or every quota bucket.

## Development and support

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests, development notes, and useful bug reports. Before publishing a release, follow the [release checklist](docs/RELEASE_CHECKLIST.md).

macOS interaction was previously verified on an Apple Silicon Mac. Windows was previously exercised in its development environment. Other operating-system versions and Mac architectures need their own verification before being advertised as supported.

## License

[MIT](LICENSE), copyright 2026 AjiaGit. Third-party services, trademarks, and separately distributed dependencies retain their own terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
