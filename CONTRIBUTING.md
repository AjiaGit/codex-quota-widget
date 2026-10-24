# Contributing

Use English for default documentation and contributions; Simplified Chinese user guides live in `README.zh-CN.md` files. Describe the user-visible behavior and the checks you actually ran.

## Primary platform and UI baseline

macOS is the primary product version. Its current accepted interface is the baseline for shared layout and interaction; design shared user-facing changes on macOS first, then align Windows. Match information order, wording, typography hierarchy, spacing, icons, and expand/collapse behavior while keeping appropriate native system entry points.

Reset-credit details belong inline in the main detail view, following macOS. Personal recovery explanations and data sources expand inline. Public message text and estimated time are directly visible with one original-post link. Current messages and personal recoveries share one activity section. Keep all valid quota-reset previews visible and prioritize recent linked corrections; automatically move expired previews and older records into history without inferring completion. History starts folded, opens with three records, appends three per step, and can collapse. With healthy sources and no current records, show “No new messages” / “暂无新消息”. Current ordinary records also use three-record batches. Keep the latest locally detected recovery time in the quota area, independent of public message order. Label public messages and website monitoring observations separately, retain source attribution and the three message categories, and keep verification labels visible without redundant links. Only trusted active quota-reset previews and explicitly linked important changes create new dots; completed reports, website hints and reset-credit grants stay quiet. Windows implementation constraints must not silently change the accepted macOS design. Include a comparison against the macOS baseline when reviewing Windows UI changes, and distinguish functional checks from visual parity and real desktop validation. See [project rules](AGENTS.md).

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

The builder accepts `-IsccPath` if `ISCC.exe` is installed elsewhere. The smoke test uses a fabricated local fixture. Pass `-UpgradeInstaller` pointing to a separately built newer version to exercise a version upgrade as well as install, service/UI startup, and uninstall. In English and Chinese, it activates the installed native controls to check inline reset details, message details, unified activity batches, data sources, refresh, compact/detail transitions, and hide/reopen. Fabricated screenshots and scoped native-control traces are saved outside the repository and uploaded as public workflow artifacts. These hosted-runner checks do not replace physical Windows desktop acceptance. Windows output is `CodexQuotaWidget-0.1.0-windows-x64.exe` plus its checksum.

The [Build packages workflow](.github/workflows/build-packages.yml) tests both service copies on Windows x64, macOS Apple Silicon, and macOS Intel; it uploads packages, checksums, and fabricated Windows UI previews/traces as Actions artifacts. This repository is public, so workflow logs and artifacts are publicly accessible. Never use real account responses or personal screenshots in CI. The package jobs have read-only repository permissions and do not create tags or GitHub releases. The optional existing-private-draft upload job is restricted to private repositories and does not run here. A hosted-runner pass does not certify physical Intel hardware, every OS version, or real-account login.

## Verified local Mac updates and retention

For authorized updates to an existing Mac installation, use [the maintained updater](scripts/update-macos.mjs) instead of making another per-release installation script or app copy. This is a maintainer command in the checkout, not a background auto-updater. It needs Node.js 24+, an authenticated `gh`, the exact commit available in local Git, and a completed successful **Build packages** run for that commit on all three platforms. Eligible events are `push` and `workflow_dispatch`; a PR run builds a synthetic merge and cannot certify the requested head commit. It uses the CI artifact for this Mac's architecture; the updater does not build another local app.

Save a private configuration outside Git (replace the commit and numeric run with the approved values):

```json
{
  "appPath": "/Users/your-name/Applications/Codex Quota Widget.app",
  "dataPath": "/Users/your-name/Library/Application Support/CodexWeeklyMonitor",
  "workspace": "/Users/your-name/Library/Caches/CodexQuotaWidget-updates",
  "evidencePath": "/Users/your-name/Documents/QuotaWidget-update-records",
  "commit": "FULL_40_CHARACTER_COMMIT_SHA",
  "run": 123456789
}
```

Use absolute, real paths: `dataPath` must be the current user's actual `~/Library/Application Support/CodexWeeklyMonitor`, which the native app and Stop script use. The four roots must be disjoint, the cache and evidence must be outside the checkout, and app/cache must be on the same filesystem. The cache must initially be empty or missing. On the **first managed update**, add `previousRollback` with the absolute path of the one retained legacy `.app` from the previous installation receipt, if present. The updater validates and moves only that bundle into its registry; surrounding test records stay put. Do not import an arbitrary collection of old apps. Omit this field after migration.

```sh
node scripts/update-macos.mjs prepare --config /absolute/private/update-config.json
# Open the installed app normally, at its existing path.
node scripts/update-macos.mjs verify --receipt /absolute/path/printed/by/prepare/transaction.json
```

`prepare` checks exact CI provenance, the artifact digest, inner package SHA256, bundle identities, signatures, bundled runtime and architecture. It uses the existing Stop script, saves data and native preferences, then swaps the app at the original location. It leaves all earlier artifacts in place. A handled replacement failure restores the original app when its identity is intact. It does not restart the app itself; launch it normally before verification.

`verify` checks installed files and the immediate rollback, exact process ownership and one process per role, local service health, fresh readable quota, settings, native preferences, recovery records and public-history source lineage qualified by reset kind. Same-kind consolidation is allowed when its source aliases remain; a regular-reset record cannot stand in for a lost reset-credit record from the same post. A category change requires inspection instead of silently authorizing cleanup. After these checks succeed it **automatically** removes the registered downloaded ZIPs, extracted app copies and older rollback bundles. Only the current installation and its immediate pre-update rollback remain among managed apps. The rollback belongs to the prior installation, even if installing the same commit again. Active settings/history, every saved data snapshot, receipts, test logs and screenshots remain. Historical receipts may therefore refer to app artifacts intentionally removed later.

Cleanup selects fixed artifact leaves from the owned registry; it does not scan other projects, the home directory, or arbitrary output folders. A running, modified or symlinked app blocks cleanup, as does an unfinished extracted app lacking a saved manifest. Exit code `2` means the new app passed verification but cleanup is blocked: inspect the private receipt, resolve the cause, and rerun the same `verify` command. Exit code `1` means an update/check failed; no successful validation is inferred. Do not bypass a failure by editing a receipt or setting a “passed” flag. A pending update prevents another `prepare`. If preparation stopped the app before failing, reopen the restored original app normally.

After interruption, inspect the receipt/catalog and the sibling `.update-lock` file before removing a stale lock. A completed installation can resume with `verify`; an interrupted replacement or `needs-recovery` requires checking the recorded app/rollback manifests and restoring the original path before proceeding. There is no automatic crash-recovery or destructive force option. Retain all evidence until recovery is understood. Cleanup is part of verified updates, not a scheduled job. Manually created unregistered builds are outside its scope; keep experimental output temporary and remove it after its checks. Windows keeps using its fixed-location installer; this command does not change Windows installation or backup behavior.

## Reports and translations

For bugs, include OS/architecture, Codex version, failing action, expected result, and a sanitized error. State whether `codex login status` succeeds without sharing account details. Do not upload `auth.json`, tokens, raw account responses, or personal account screenshots.

Update English and Chinese strings together. Use stable translation keys and localize native menus, errors, countdowns, dates, and the browser page. The saved language values are `auto`, `en`, and `zh-CN`; clients share the local service's settings file.
