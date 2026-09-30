# Third-party notices

The project's [MIT license](LICENSE), copyright 2026 AjiaGit, covers its own code and documentation. It does not replace dependency, service, or trademark terms.

- **Node.js 24.19.0:** prebuilt packages bundle the official platform runtime. The complete upstream `LICENSE`, including notices for Node's incorporated dependencies, accompanies the bundled executable as `runtime/LICENSE` inside the macOS resources or Windows installation. Downloads are checked against the official [SHASUMS256.txt](https://nodejs.org/dist/v24.19.0/SHASUMS256.txt). Node.js is separately licensed; see the [upstream license](https://github.com/nodejs/node/blob/v24.19.0/LICENSE).
- **Codex CLI and App Server:** the widget calls the user's installed official Codex executable. Codex, OpenAI credentials, and private account data are not redistributed. These components retain their upstream licenses and applicable OpenAI terms; see [Codex](https://github.com/openai/codex) and [App Server documentation](https://learn.chatgpt.com/docs/app-server).
- **Inno Setup:** Windows installers are created with Inno Setup 6.7.3, copyright 1997–2026 Jordan Russell and portions copyright 2000–2026 Martijn Laan. Its installer engine retains the original notices. See [Inno Setup](https://jrsoftware.org/) and its [license](https://jrsoftware.org/files/is/license.txt).
- **Public reset sources:** [codexreset.ai](https://codexreset.ai/) and [whenreset.app](https://whenreset.app/) supply live public data and receive attribution in the UI. Their data and services are not relicensed under MIT. No snapshot of those datasets is bundled with the installers.
- **Platform components:** AppKit, WebKit, Windows PowerShell, and Windows Forms come from the operating system or developer environment and retain their own terms.

Codex and OpenAI names describe compatibility and do not imply endorsement. No official OpenAI logo or artwork license is claimed by this project's MIT license.
