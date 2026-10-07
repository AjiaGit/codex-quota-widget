# macOS 使用步骤

[English](README.md) | 简体中文

## 预编译应用

1. 系统需为 **macOS 13.5 或更新版本**。在**苹果菜单 → 关于本机**查看芯片：Apple Silicon 下载 `arm64` ZIP，Intel 下载 `x64` ZIP。
2. 安装官方 [Codex 桌面应用](https://learn.chatgpt.com/docs/app)或 [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)并登录。若工具未找到桌面应用的 CLI，请单独安装 CLI 后运行 `codex login`。
3. 用 `shasum -a 256 <文件名>` 核对 ZIP 与随包提供的 `SHA256SUMS`。解压后，把 **Codex Quota Widget.app** 移到 `/Applications` 或个人应用目录 `~/Applications`。
4. 打开应用，需要时拖到程序坞。应用内置 Node.js 24.19.0，无需另外安装 Node 或编译工具。

应用仅有临时签名，没有 Developer ID 签名或 Apple 公证。若 macOS 阻止打开，请先核对来源及校验值，再使用系统**隐私与安全性 → 仍要打开**（若显示该选项）。不要关闭整个系统的安全保护。

同一台电脑只运行一份；本机服务使用 `127.0.0.1:39224`。

## 日常使用

- 点击菜单栏百分比，可显示／隐藏窗口、切换极简／详细、刷新、打开浏览器详细页、选择语言或退出。
- 在**语言 → 跟随系统 / English / 简体中文**中选择；设置会保存，与浏览器详细页共用。
- 点击极简圆环展开；点击详细窗外部，可回到极简原来的位置和大小。拖动窗体移动，拖动边缘或四角缩放。默认详细窗会在屏幕允许的范围内按内容调整高度；历史较长或手动缩小窗口时仍可滚动。
- 打开**可用重置 / 查看明细**查看可用重置次数及 Codex 提供的发放／到期时间。工具只读取，不消耗可用重置次数。
- 程序坞图标显示本周剩余，不可用时显示 `—`；点击可重新打开窗口。
- 展开**我的额度恢复**，查看本机观测的恢复前后百分比、上次观测与本次检测时间。从启用后开始记录，重启后保留；这类记录不代表全局重置确认。默认折叠，减少详细窗占用空间。

额度和缓存检查每 60 秒进行；手动刷新、重新打开和唤醒后及时更新。临时失败按 15／30／60 秒重试，公开站点数据单独每 10 分钟更新。

## 更新、退出与卸载

先从菜单选择**退出**，再用新版本替换原位置的应用并重新打开。语言与窗口位置保存在 `~/Library/Application Support/CodexWeeklyMonitor/`，更新后保留。

卸载时先退出，再把应用移到废纸篓。若也要删除偏好和日志，请在退出后删除 `~/Library/Application Support/CodexWeeklyMonitor/`。工具不会设置开机启动。

## 排查与源码启动

若界面提示登录，检查 `codex login status`，需要时运行 `codex login` 后刷新。启动问题查看 `~/Library/Application Support/CodexWeeklyMonitor/monitor.log`；源码编译日志为同目录下的 `build.log` 和 `launcher-build.log`。反馈时仅提供已脱敏内容。

源码启动需 [Node.js 24+](https://nodejs.org/en/download)、已登录的 Codex 和 Apple 命令行工具（`xcode-select --install`）。保留整个仓库，双击 [Start.command](Start.command) 启动，[Stop.command](Stop.command) 停止。源码启动器在本机编译，生成的入口仍依赖旁边的服务文件。若 Finder 只显示文本，可在终端用 `bash` 执行脚本。

独立应用构建方法见 [CONTRIBUTING.md](../CONTRIBUTING.md)。原生 CI 覆盖 Apple Silicon 与 Intel 运行环境构建，不代表实体 Intel 硬件或每个 macOS 版本的真实账号登录均已验证。
