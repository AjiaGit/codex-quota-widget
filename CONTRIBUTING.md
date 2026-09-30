# Contributing

Bug reports, documentation improvements, and focused pull requests are welcome. Use English for public issues, pull requests, and default documentation. Chinese documentation lives in `README.zh-CN.md` files.

## Development

Use Node.js 24 or later. No npm dependencies are required for the current service tests.

Run the tests from the repository root:

```sh
node --test macos/test/quota.test.mjs macos/test/rpc.test.mjs macos/test/presentation.test.mjs macos/test/external.test.mjs
node --test windows/test/quota.test.mjs windows/test/rpc.test.mjs windows/test/presentation.test.mjs windows/test/external.test.mjs
```

The native macOS UI needs Apple Command Line Tools. The Windows UI uses Windows PowerShell and Windows Forms and needs a Windows machine for interaction testing.

The service and presentation logic currently have copies under both platform folders. Keep equivalent changes synchronized until the shared core is consolidated. Preserve the UTF-8 BOM and CRLF convention for Windows PowerShell scripts; see `.gitattributes`.

## Bug reports

Include the operating system and architecture, Node and Codex CLI versions, the failing action, expected behavior, and a sanitized error message. Say whether `codex login status` succeeds without sharing credentials or account details.

Do not upload `auth.json`, access tokens, refresh tokens, raw account responses, unredacted logs, or personal account screenshots. Do not report a credential exposure by posting the credential in a public issue. A private security-reporting channel must be configured before the first public release; see the release checklist.

## Pull requests

Explain the user-visible behavior, keep the change focused, and list the checks you actually ran. Do not claim Windows UI or Intel Mac support based only on tests run on an Apple Silicon Mac. Use fabricated quota and reset-credit fixtures in tests.

## Translations

English is the default documentation language. Runtime localization is planned, starting with English and Simplified Chinese. New UI strings should eventually use stable translation keys with an English fallback. Dates, countdowns, plural forms, native menus, and error messages need localization as well as HTML labels.
