# Contributing

Use English for default documentation and contributions; Simplified Chinese user guides live in `README.zh-CN.md` files. Describe the user-visible behavior and the checks you actually ran.

## Primary platform and UI baseline

macOS is the primary product version. Its current accepted interface is the baseline for shared layout and interaction; design shared user-facing changes on macOS first, then align Windows. Match information order, wording, typography hierarchy, spacing, icons, and expand/collapse behavior while keeping appropriate native system entry points.

Reset-credit details belong inline in the main detail view, following macOS. Record explanations, earlier updates, history, and data sources also expand inline. Windows implementation constraints must not silently change the accepted macOS design. Include a comparison against the macOS baseline when reviewing Windows UI changes, and distinguish functional checks from visual parity and real desktop validation. See [project rules](AGENTS.md).

## Develop and test

Use Node.js 24; packaged builds pin **24.19.0**. The service has no npm dependencies. From the repository root:

```sh
node scripts/check-docs.mjs
node scripts/core-test.mjs
```

The core command runs both platform copies of the service/browser tests. Keep equivalent `.mjs` and `public` changes synchronized. Native macOS tests require macOS and Apple Command Line Tools:

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

The builder accepts `-IsccPath` if `ISCC.exe` is installed elsewhere. The smoke test uses a fabricated local fixture. Pass `-UpgradeInstaller` pointing to a separately built newer version to exercise a version upgrade as well as install, service/UI startup, and uninstall. Windows output is `CodexQuotaWidget-0.1.0-windows-x64.exe` plus its checksum.

The [Build packages workflow](.github/workflows/build-packages.yml) tests both service copies on Windows x64, macOS Apple Silicon, and macOS Intel; it builds packages and uploads only package/checksum files as Actions artifacts. Artifacts follow the repository's access controls. The workflow has read-only repository permissions and does not create tags or GitHub releases. A hosted-runner pass does not certify physical Intel hardware, every OS version, or real-account login.

## Reports and translations

For bugs, include OS/architecture, Codex version, failing action, expected result, and a sanitized error. State whether `codex login status` succeeds without sharing account details. Do not upload `auth.json`, tokens, raw account responses, or personal account screenshots.

Update English and Chinese strings together. Use stable translation keys and localize native menus, errors, countdowns, dates, and the browser page. The saved language values are `auto`, `en`, and `zh-CN`; clients share the local service's settings file.
