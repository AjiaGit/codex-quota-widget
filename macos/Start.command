#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
STATE="$HOME/Library/Application Support/CodexWeeklyMonitor"
APP="$ROOT/Codex 周额度.app"
EXE="$APP/Contents/MacOS/CodexQuota"
mkdir -p "$STATE"
PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
export PATH

notice() {
  printf '\n%s\n' "$1"
  /usr/bin/osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {"好"} default button "好" with title "Codex 周额度"' -e 'end run' "$1" >/dev/null 2>&1 || true
}

owned_pid() {
  local file="$1" expected="$2" pid command
  [[ -f "$file" ]] || return 1
  pid="$(cat "$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$command" == *"$expected"* ]] || return 1
  printf '%s' "$pid"
}

if ! command -v node >/dev/null 2>&1; then
  notice "未找到 Node.js。请先安装 Node.js 24 或更新版本，再双击 Start.command。详见此文件夹的 README.md。"
  exit 1
fi
NODE="$(command -v node)"
NODE_MAJOR="$("$NODE" -p 'Number(process.versions.node.split(".")[0])')"
if [[ "$NODE_MAJOR" -lt 24 ]]; then
  notice "Node.js 版本过旧（当前 $NODE_MAJOR）。请安装 Node.js 24 或更新版本。"
  exit 1
fi
if ! command -v codex >/dev/null 2>&1; then
  notice "未找到 Codex CLI。请按 README.md 的一次性准备步骤安装并登录。"
  exit 1
fi
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  notice "未找到 Apple 命令行工具。请在终端运行 xcode-select --install，安装完成后重新打开 Start.command。"
  exit 1
fi

if [[ ! -x "$EXE" || "$ROOT/MacWidget.swift" -nt "$EXE" ]]; then
  mkdir -p "$APP/Contents/MacOS"
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>CodexQuota</string>
  <key>CFBundleIdentifier</key><string>local.codex.weeklymonitor</string>
  <key>CFBundleName</key><string>Codex 周额度</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
  echo '首次运行：正在编译 Mac 悬浮窗（可能需要 1～2 分钟）…'
  if ! /usr/bin/xcrun swiftc -O -framework AppKit -framework WebKit \
      -o "$EXE" "$ROOT/MacWidget.swift" >"$STATE/build.log" 2>&1; then
    notice "Mac 悬浮窗编译失败。请打开 $STATE/build.log 查看错误，或把该文件发给我。"
    exit 1
  fi
fi

# Create the Dock launcher on this Mac, avoiding a downloaded app bundle's translocation.
LAUNCHER="$ROOT/启动 Codex 周额度.app"
if [[ ! -x "$LAUNCHER/Contents/MacOS/Launch" ]]; then
  mkdir -p "$LAUNCHER/Contents/MacOS"
  cat > "$LAUNCHER/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Launch</string>
  <key>CFBundleIdentifier</key><string>local.codex.weeklymonitor.launcher</string>
  <key>CFBundleName</key><string>启动 Codex 周额度</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
  cat > "$LAUNCHER/Contents/MacOS/Launch" <<'LAUNCH'
#!/bin/bash
ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
exec /bin/bash "$ROOT/Start.command"
LAUNCH
  chmod 755 "$LAUNCHER/Contents/MacOS/Launch"
fi

if ! owned_pid "$STATE/monitor.pid" "$ROOT/monitor.mjs" >/dev/null; then
  if /usr/bin/curl --silent --max-time 2 http://127.0.0.1:39224/health | /usr/bin/grep -q 'codex-weekly-monitor'; then
    notice "端口 39224 已有另一份监控服务。请先停止旧版本，再重新启动。"
    exit 1
  fi
  nohup "$NODE" "$ROOT/monitor.mjs" >"$STATE/monitor.log" 2>&1 </dev/null &
  printf '%s\n' "$!" > "$STATE/monitor.pid"
  ready=0
  for ((i=0; i<20; i++)); do
    if /usr/bin/curl --silent --max-time 1 http://127.0.0.1:39224/health | /usr/bin/grep -q 'codex-weekly-monitor'; then
      ready=1
      break
    fi
    sleep 0.5
  done
  if [[ "$ready" != 1 ]]; then
    notice "本机额度服务没有启动。请查看 $STATE/monitor.log。"
    exit 1
  fi
fi

if owned_pid "$STATE/widget.pid" "$EXE" >/dev/null; then
  notice "悬浮窗已在运行。请点 Mac 屏幕右上角菜单栏里的百分比，选择“显示悬浮窗”。"
else
  /usr/bin/open "$APP"
  echo '已启动。屏幕右上角菜单栏会显示本周剩余百分比。'
fi
