# Contributing

Use English for default documentation and contributions; Simplified Chinese user guides live in `README.zh-CN.md` files. Describe the user-visible behavior and the checks you actually ran.

## Primary platform and UI baseline

macOS is the primary product version. Its current accepted interface is the baseline for shared layout and interaction; design shared user-facing changes on macOS first, then align Windows. Match information order, wording, typography hierarchy, spacing, icons, and expand/collapse behavior while keeping appropriate native system entry points.

Reset-credit details belong inline in the main detail view, following macOS. Record explanations, earlier updates, history, and data sources also expand inline. Windows implementation constraints must not silently change the accepted macOS design. Include a comparison against the macOS baseline when reviewing Windows UI changes, and distinguish functional checks from visual parity and real desktop validation. See [project rules](AGENTS.md).

For each shared change, check the current branch/commit and local changes, implement against the approved Mac baseline, and synchronize Windows in the same change. The Windows follow-up uses that repository change, adapts the native implementation, updates the installed app, and verifies it on a real Windows desktop while preserving settings and history. Report the validated commit and distinguish automated checks, native checks, and desktop results. These rules apply without a repeated reminder; they do not automatically start Codex on another computer or update its installation.

## Develop and test

Use Node.js 24; packaged builds pin **24.19.0**. The service has no npm dependencies. From the repository root:

```sh
node scripts/check-docs.mjs
node scripts/core-test.mjs
```

The core command first checks shared-file equality, then runs the repository tooling tests and both platform copies of the service/browser tests. The same command gates the Mac and Windows package jobs in CI. The equality check covers platform-root `.mjs` modules, all files recursively under `public/`, and `.mjs` test files except `native*` tests. It compares bytes and reports changed or missing counterparts, including newly added files. It excludes only `.DS_Store` and `Thumbs.db` system metadata and rejects symbolic links in shared files or directories. It does not rewrite files. Run it separately with `node scripts/check-shared.mjs` when investigating drift.

Keep shared changes synchronized in the same change. Native code, native tests, and platform packaging remain separate. If an intentional difference is needed in a shared location, explain it and review the checker contract change; do not suppress a mismatch as a shortcut. The check establishes source equality, not desktop UI parity. Native macOS tests require macOS and Apple Command Line Tools:

```sh
node --test macos/test/native*.mjs
```

On Windows, run the native tests with Windows PowerShell:

```powershell
Get-ChildItem windows/test/native*.ps1 | ForEach-Object {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Native test failed: $($_.Name)" }
}
```

Preserve the UTF-8 BOM and CRLF convention for Windows PowerShell scripts; see `.gitattributes`. Use fabricated account and reset-credit data. Keep credentials, raw account responses, personal screenshots, logs, and generated packages out of commits.

## Build packages

Download the full official Node **24.19.0** archive for the target platform, verify it against [SHASUMS256.txt](https://nodejs.org/dist/v24.19.0/SHASUMS256.txt), and extract it. The build needs the upstream `LICENSE` along with `bin/node` on macOS or `node.exe` on Windows. Use an output folder outside the repository.

On macOS, with Apple Command Line Tools installed:

```sh
NODE_ROOT=/path/to/node-v24.19.0-darwin-arm64 \
OUTPUT_DIR=/path/outside/repository/output \
ARCH=arm64 VERSION=0.1.0 bash scripts/build-macos.sh
```

For Intel, use `ARCH=x86_64` and the `darwin-x64` Node archive. Output is `Codex Quota Widget.app`. The native code targets macOS 13; the bundled Node runtime requires **macOS 13.5+**. Package the app using `ditto -c -k --sequesterRsrc --keepParent` to preserve bundle permissions.

On Windows, install [Inno Setup 6.7.3](https://jrsoftware.org/isdl.php), then run:

```powershell
& installer/windows/Build.ps1 -NodeRoot C:\path\node-v24.19.0-win-x64 `
    -OutputDir C:\path\outside\repository\output -Version 0.1.0
& installer/windows/InstallerSmoke.ps1 `
    -Installer C:\path\outside\repository\output\CodexQuotaWidget-0.1.0-windows-x64.exe
```

The builder accepts `-IsccPath` if `ISCC.exe` is installed elsewhere. The smoke test uses a fabricated local fixture. Pass `-UpgradeInstaller` pointing to a separately built newer version to exercise a version upgrade as well as install, service/UI startup, and uninstall. In English and Chinese, it activates the installed native controls to check inline reset details, message details, earlier updates, history, data sources, refresh, compact/detail transitions, and hide/reopen. Fabricated screenshots and scoped native-control traces are saved outside the repository and uploaded as public workflow artifacts. These hosted-runner checks do not replace physical Windows desktop acceptance. Windows output is `CodexQuotaWidget-0.1.0-windows-x64.exe` plus its checksum.

The [Build packages workflow](.github/workflows/build-packages.yml) tests both service copies on Windows x64, macOS Apple Silicon, and macOS Intel; it uploads packages, checksums, and fabricated Windows UI previews/traces as Actions artifacts. This repository is public, so workflow logs and artifacts are publicly accessible. Never use real account responses or personal screenshots in CI. The package jobs have read-only repository permissions and do not create tags or GitHub releases. The optional existing-private-draft upload job is restricted to private repositories and does not run here. A hosted-runner pass does not certify physical Intel hardware, every OS version, or real-account login.

## Reports and translations

For bugs, include OS/architecture, Codex version, failing action, expected result, and a sanitized error. State whether `codex login status` succeeds without sharing account details. Do not upload `auth.json`, tokens, raw account responses, or personal account screenshots.

Update English and Chinese strings together. Use stable translation keys and localize native menus, errors, countdowns, dates, and the browser page. The saved language values are `auto`, `en`, and `zh-CN`; clients share the local service's settings file.
