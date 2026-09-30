# Windows 使用步骤

[English](README.md) | 简体中文

1. 安装 [Node.js 24 或更新版本](https://nodejs.org/en/download)，并安装 [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)。打开 PowerShell，运行 `node --version`、`codex --version` 和 `codex login status`；如未登录，运行 `codex login`，使用要监控的 ChatGPT 账号登录。
2. 在本文件夹双击 `Start.cmd`。悬浮窗会在桌面出现，系统托盘图标显示本周剩余百分比。
3. 详细窗点“极简”可缩成圆环；单击圆环展开。按住窗口内容可移动，拖动上下左右边缘可分别调整高度或宽度，拖动四角可同时调整。极简窗和详细窗都支持，边缘没有可见手柄。详细窗点 `×` 会隐藏到托盘；双击托盘图标可找回。
4. 要完全停止工具，双击 `Stop.cmd`。它会核对进程身份，只停止本工具的悬浮窗和本机服务。

详细窗显示本周剩余、重置时间和倒计时、更新时刻、重置卡数量。Plus 账号另显示 5 小时额度；Pro 账号不显示。底部的公开临时重置记录和历史概率来自外部公开站点，点站点名称可在浏览器打开。刷新按钮可手动重新读取。

若想放到桌面，可右键 `Start.cmd` →“显示更多选项”→“发送到”→“桌面快捷方式”。这个快捷方式要与本文件夹保持关联；移动工程文件夹后需要重新创建。工具不会自动添加开机启动项。

显示“暂不可用”时，先检查 `codex login status`，再点刷新；如本机服务中断，运行 `Stop.cmd` 后重新运行 `Start.cmd`。日志在 `%TEMP%\CodexWeeklyMonitor`。本机服务只监听 `127.0.0.1:39224`。
