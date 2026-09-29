# macOS 使用步骤

macOS 版在菜单栏显示本周剩余百分比，并提供始终置顶的极简／详细悬浮窗。极简窗只有圆环和环内数字；单击展开。两种窗口都可拖动右下角边缘调整大小，没有可见的缩放手柄。

## 第一次启动

1. 在 GitHub 点 **Code → Download ZIP** 并解压。把解压得到的 `codex-quota-widget-main` 文件夹改名为 `codex-quota-widget`，再把整个文件夹放到个人应用目录 `~/Applications/`。在 Finder 按 `Shift + Command + H` 可打开个人文件夹；若没有 `Applications`，新建一个。工具不会自动移动文件夹。
2. 按 `Command + 空格`，输入“终端”并打开。运行 `node -v` 和 `codex --version`。若缺少 Node.js，请安装 [24 或更新的 LTS 版本](https://nodejs.org/en/download)；若缺少 Codex CLI，可按[官方说明](https://learn.chatgpt.com/docs/codex/cli)安装。然后运行 `codex login`，用要监控的 ChatGPT 账号登录。
3. 在终端运行 `xcode-select --install`，按[Apple 的安装提示](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools)安装命令行工具；如提示已经安装，直接继续。
4. 在 Finder 打开 `~/Applications/codex-quota-widget/macos/`，双击 `Start.command`。首次启动会在这台 Mac 上编译悬浮窗，可能需要一两分钟。若系统阻止打开，在 Finder 右键 `Start.command` →“打开”；若双击只显示脚本文本，在终端输入 `bash `（末尾保留空格），把 `Start.command` 拖进终端窗口，再按回车。
5. 右上角菜单栏出现 `数字%` 即启动成功。首次成功后，本文件夹会生成 `启动 Codex 周额度.app`，可以拖到 Dock；之后不要单独搬动这个 app，也不要改名或移动整个工程文件夹。

## 日常使用

- 点菜单栏百分比，可显示悬浮窗、切换极简／详细、刷新或退出。
- 极简窗单击展开；拖动窗体移动；拖动右下角边缘调整大小。
- 详细窗顶部“极简”可缩小；顶部空白区域可拖动；详细内容可滚动。两种尺寸分别记住。
- 双击 `Stop.command` 可完全停止；再次双击 `Start.command` 可恢复。没有开机启动项。

工具本体留在本文件夹；运行记录和日志保存在 `~/Library/Application Support/CodexWeeklyMonitor/`。显示 `—` 时先运行 `codex login status`，再从菜单栏刷新。若无法启动，请查看该目录的 `build.log` 或 `monitor.log`。

Mac 原生窗口尚未在真实 Mac 上完成编译、深浅色和拖拽验收。账号额度取自本机 Codex CLI；Codex 桌面 app 已登录不保证 CLI 也已登录。
