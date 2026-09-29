# Codex 周额度悬浮窗

一个在 Windows 和 macOS 桌面查看 Codex 额度的小工具。它显示本周剩余百分比、重置时间和倒计时、最近更新时间、可用重置卡数量；Plus 账号另显示 5 小时额度，Pro 账号只显示周额度。悬浮窗有极简和详细两种模式，可拖动与调整大小。Windows 可收进系统托盘，macOS 可从菜单栏打开。

详细窗还读取 [codexreset.ai](https://codexreset.ai/) 的公开全局临时重置记录，以及 [whenreset.app](https://whenreset.app/) 的历史频率估计。这些公开记录与个人账号的固定额度周期不同；**未来概率不是已确定的重置时间或承诺**。

## 开始使用

| 系统 | 准备 | 启动 | 停止 |
| --- | --- | --- | --- |
| Windows | Node.js 24+；已用 ChatGPT 账号登录 Codex CLI | 双击 [`windows/Start.cmd`](windows/Start.cmd) | 双击 [`windows/Stop.cmd`](windows/Stop.cmd) |
| macOS | Node.js 24+；已登录 Codex CLI；Apple 命令行工具 | 双击 [`macos/Start.command`](macos/Start.command) | 双击 [`macos/Stop.command`](macos/Stop.command) |

第一次使用，请先阅读 [Windows 步骤](windows/README.md)或 [macOS 步骤](macos/README.md)。下载时在 GitHub 页面点 **Code → Download ZIP**，解压后保留整个文件夹。不要同时运行同一台电脑上的两份副本：本机服务固定使用 `127.0.0.1:39224`。

## 工作方式

- 本机 Node.js 服务通过 Codex CLI 的 `app-server` 只读 `account/read` 与 `account/rateLimits/read` 获取账号额度；不需要 API Key，也不修改 Codex 客户端文件。
- 额度每 5 分钟读取一次；超过 10 分钟未更新、旧重置时间已到或登录失效时，旧百分比不再当作当前数据展示。
- 外部公开站点的记录单独读取，不发送你的登录信息或个人额度。工具只显示重置卡数量，不使用重置卡。
- 没有开机启动、主动提醒或远程同步。运行记录保存在本机。

## 验证状态

Windows 版本已在本机运行验证。两套 Node 核心代码和页面测试可分别在 `windows`、`macos` 文件夹运行：

```text
node --test test/quota.test.mjs test/rpc.test.mjs test/presentation.test.mjs test/external.test.mjs
```

macOS 原生悬浮窗源码已提供，但尚未在真实 Mac 上编译和操作验收。首次运行时会在该 Mac 上编译；若编译失败，可查看 `~/Library/Application Support/CodexWeeklyMonitor/build.log`。

这是独立的非官方工具，与 OpenAI 无关联。Codex `app-server` 当前为实验性命令；客户端升级后请重新核对实际额度显示。

