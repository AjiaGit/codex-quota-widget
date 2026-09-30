# Windows 使用步骤

[English](README.md) | 简体中文

## 安装程序

1. 使用具备 Windows PowerShell 5.1 和 Windows Forms 的 64 位 Windows（Windows 10／11）。先安装官方 [Codex 桌面应用](https://learn.chatgpt.com/docs/app)或 [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)，用要监控的 ChatGPT 账号登录。
2. 在 PowerShell 运行 `Get-FileHash .\CodexQuotaWidget-0.1.0-windows-x64.exe -Algorithm SHA256`，与提供的 `SHA256SUMS` 核对。
3. 打开 **CodexQuotaWidget-0.1.0-windows-x64.exe**。程序安装到当前用户目录，内置 Node.js 24.19.0 并创建开始菜单入口，无需另装 Node。
4. 从开始菜单打开 **Codex Quota Widget**。若提示未找到 Codex 或需要登录，请按界面提供的安装／登录操作处理。单独安装 CLI 时，运行 `codex login` 后点击**刷新**。

安装程序未签名，Windows 可能显示未知发布者或 SmartScreen 提示。核对来源与校验值后再决定运行。同一台电脑只运行一份，本机服务使用 `127.0.0.1:39224`。

## 日常使用

- 详细窗点**极简**收起，点击圆环展开；拖动窗体移动，拖动边缘或四角缩放。
- 点 `×` 隐藏到托盘，双击托盘图标显示；托盘菜单可切换模式、刷新、设置置顶、选择语言或退出。
- 在**语言 → 跟随系统 / English / 简体中文**中选择，原生界面与浏览器详细页共用已保存的设置。
- 打开**重置详情**查看可用数量与 Codex 提供的发放／到期时间。工具不会使用重置卡。

额度与缓存检查每 60 秒进行；手动刷新、重新打开和唤醒后及时更新。临时失败按 15／30／60 秒重试；公开重置数据每 10 分钟更新，历史概率不是未来重置承诺。

## 更新与卸载

先退出工具，再运行新安装程序更新当前用户的同一份安装。卸载可从**设置 → 应用 → 已安装的应用 → Codex Quota Widget**进行，语言与窗口偏好会保留。若需先删除偏好，请在安装目录打开 PowerShell 并运行 `.\Stop.ps1 -RemovePreferences`。安装程序的登录时启动为可选项，默认不勾选。

语言、窗口位置和日志位于 `%LOCALAPPDATA%\CodexWeeklyMonitor`。旧源码安装会从 `%TEMP%\CodexWeeklyMonitor` 迁移偏好，并保留原文件。反馈问题时仅提供脱敏日志。

## 排查与源码启动

若显示不可用，按界面提示处理，检查 `codex login status` 后刷新。源码安装需要重启时，先运行 [Stop.cmd](Stop.cmd)，再运行 [Start.cmd](Start.cmd)。日志包括数据目录下的 `stderr.log` 和 `floating-stderr.log`。

源码启动需 [Node.js 24+](https://nodejs.org/en/download)和已登录的 Codex。保留整个仓库，双击 [Start.cmd](Start.cmd) 启动；桌面快捷方式可指向这个文件，移动文件夹后需更新快捷方式。[Stop.cmd](Stop.cmd) 只停止核对为本安装所有的进程。

安装包构建说明见 [CONTRIBUTING.md](../CONTRIBUTING.md)。Windows 托管运行环境的冒烟测试使用虚构数据并验证安装生命周期，不代表已验证你的账号登录或所有实体 Windows 桌面。
