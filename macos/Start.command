#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
STATE="$HOME/Library/Application Support/CodexWeeklyMonitor"
WIDGET_ONLY=0
[[ "${1:-}" == "--widget-only" ]] && WIDGET_ONLY=1
mkdir -p "$STATE"
PATH="$ROOT/runtime:/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS:/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
export PATH

# The release has an enclosed helper; source checkouts retain the two generated apps.
if [[ -x "$ROOT/../../Helpers/QuotaWidget.app/Contents/MacOS/CodexQuota" ]]; then
  APP="$(cd "$ROOT/../../Helpers/QuotaWidget.app" && pwd -P)"
  LAUNCHER="$(cd "$ROOT/../../.." && pwd -P)"
else
  APP="$ROOT/Codex 周额度.app"
  LAUNCHER="$ROOT/Codex Quota Widget.app"
fi
EXE="$APP/Contents/MacOS/CodexQuota"
LAUNCH_EXE="$LAUNCHER/Contents/MacOS/Launch"

LANGUAGE="$(/usr/bin/plutil -extract language raw -o - "$STATE/settings.json" 2>/dev/null || true)"
if [[ "$LANGUAGE" != "en" && "$LANGUAGE" != "zh-CN" ]]; then
  SYSTEM_LANGUAGE="$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2p' || true)"
  LANGUAGE="en"
  [[ "$SYSTEM_LANGUAGE" == *zh* ]] && LANGUAGE="zh-CN"
fi

notice() {
  local message="$1" title="Codex Quota Widget" button="OK"
  if [[ "$LANGUAGE" == "zh-CN" ]]; then message="$2"; title="Codex 周额度"; button="好"; fi
  printf '\n%s\n' "$message"
  /usr/bin/osascript -e 'on run argv' -e 'display dialog (item 1 of argv) buttons {item 3 of argv} default button (item 3 of argv) with title (item 2 of argv)' -e 'end run' "$message" "$title" "$button" >/dev/null 2>&1 || true
}

owned_pid() {
  local file="$1" expected_executable="$2" expected_script="${3:-}" pid
  [[ -f "$file" ]] || return 1
  pid="$(cat "$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  [[ -x "$LAUNCH_EXE" ]] && /usr/bin/grep -aFq 'CodexQuotaProcessGuard/1' "$LAUNCH_EXE" || return 1
  if [[ -n "$expected_script" ]]; then
    "$LAUNCH_EXE" --owns-process "$pid" "$expected_executable" "$expected_script" || return 1
  else
    "$LAUNCH_EXE" --owns-process "$pid" "$expected_executable" || return 1
  fi
  printf '%s' "$pid"
}

if [[ -x "$ROOT/runtime/node" ]]; then
  NODE="$ROOT/runtime/node"
elif command -v node >/dev/null 2>&1; then
  NODE="$(command -v node)"
else
  notice 'Node.js was not found. Install Node.js 24 or newer, then reopen Start.command. The prebuilt app includes Node.js.' '未找到 Node.js。请安装 Node.js 24 或更新版本，再双击 Start.command。预编译应用已内置 Node.js。'
  exit 1
fi
if ! NODE_MAJOR="$("$NODE" -p 'Number(process.versions.node.split(".")[0])')" || [[ ! "$NODE_MAJOR" =~ ^[0-9]+$ || "$NODE_MAJOR" -lt 24 ]]; then
  notice 'Node.js could not run or is older than version 24. Reinstall Node.js 24 or use the prebuilt app.' 'Node.js 无法运行或版本低于 24。请重新安装 Node.js 24，或使用预编译应用。'
  exit 1
fi

if [[ ! -x "$EXE" || ( -f "$ROOT/MacWidget.swift" && "$ROOT/MacWidget.swift" -nt "$EXE" ) || ( -f "$ROOT/NativeSupport.swift" && "$ROOT/NativeSupport.swift" -nt "$EXE" ) || ! -x "$LAUNCH_EXE" || ( -f "$ROOT/DockLauncher.swift" && "$ROOT/DockLauncher.swift" -nt "$LAUNCH_EXE" ) || ( -f "$ROOT/NativeSupport.swift" && "$ROOT/NativeSupport.swift" -nt "$LAUNCH_EXE" ) ]]; then
  if [[ ! -f "$ROOT/MacWidget.swift" || ! -f "$ROOT/DockLauncher.swift" || ! -f "$ROOT/NativeSupport.swift" ]]; then
    notice 'The app is incomplete. Download a fresh prebuilt app and replace this copy.' '应用文件不完整。请重新下载预编译应用，并替换当前副本。'
    exit 1
  fi
  if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
    notice 'Apple command line tools are required for the source version. Run xcode-select --install, or download the prebuilt app.' '源码版需要 Apple 命令行工具。请运行 xcode-select --install，或下载预编译应用。'
    exit 1
  fi
  mkdir -p "$APP/Contents/MacOS" "$LAUNCHER/Contents/MacOS" "$LAUNCHER/Contents/Resources" "$STATE/clang-cache" "$STATE/swift-cache"
  export CLANG_MODULE_CACHE_PATH="$STATE/clang-cache"
  export SWIFT_MODULE_CACHE_PATH="$STATE/swift-cache"
  SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
  [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]] && SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
  swift_args=(-parse-as-library -O -target "$(uname -m)-apple-macosx13.0" -sdk "$SDK" -module-cache-path "$STATE/swift-cache" -framework AppKit)
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>CodexQuota</string>
  <key>CFBundleIdentifier</key><string>local.codex.weeklymonitor</string>
  <key>CFBundleName</key><string>Codex Quota Widget</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.5</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
  cat > "$LAUNCHER/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Launch</string>
  <key>CFBundleIdentifier</key><string>local.codex.weeklymonitor.launcher</string>
  <key>CFBundleName</key><string>Codex Quota Widget</string>
  <key>CFBundleDisplayName</key><string>Codex Quota Widget</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleIconFile</key><string>CodexQuota.icns</string>
  <key>LSMinimumSystemVersion</key><string>13.5</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
  if [[ "$LANGUAGE" == "zh-CN" ]]; then printf '%s\n' '正在编译源码版原生应用…'; else printf '%s\n' 'Building the native apps for this source checkout…'; fi
  if ! /usr/bin/xcrun swiftc "${swift_args[@]}" -framework WebKit -o "$EXE" "$ROOT/NativeSupport.swift" "$ROOT/MacWidget.swift" >"$STATE/build.log" 2>&1; then
    notice "The widget could not be built. Check $STATE/build.log." "悬浮窗编译失败，请查看 $STATE/build.log。"
    exit 1
  fi
  if ! /usr/bin/xcrun swiftc "${swift_args[@]}" -o "$LAUNCH_EXE" "$ROOT/NativeSupport.swift" "$ROOT/DockLauncher.swift" >"$STATE/launcher-build.log" 2>&1; then
    notice "The Dock app could not be built. Check $STATE/launcher-build.log." "程序坞入口编译失败，请查看 $STATE/launcher-build.log。"
    exit 1
  fi
  "$LAUNCH_EXE" --icon-png "$STATE/CodexQuota.png"
  /usr/bin/sips -s format icns "$STATE/CodexQuota.png" --out "$LAUNCHER/Contents/Resources/CodexQuota.icns" >/dev/null
  /usr/bin/codesign --force --sign - "$APP" >/dev/null 2>&1
  /usr/bin/codesign --force --sign - "$LAUNCHER" >/dev/null 2>&1
fi

# A missing CLI or signed-out account is shown by the running UI, using service error codes.
if ! owned_pid "$STATE/monitor.pid" "$NODE" "$ROOT/monitor.mjs" >/dev/null; then
  if /usr/bin/curl --silent --max-time 2 http://127.0.0.1:39224/health | /usr/bin/grep -q 'codex-weekly-monitor'; then
    notice 'Another installation is using port 39224. Quit that widget or run its Stop.command, then reopen this app.' '另一份工具正在使用端口 39224。请退出旧工具或运行它的 Stop.command，然后重新打开当前应用。'
    exit 1
  fi
  nohup "$NODE" "$ROOT/monitor.mjs" >"$STATE/monitor.log" 2>&1 </dev/null &
  MONITOR_PID="$!"
  printf '%s\n' "$MONITOR_PID" > "$STATE/monitor.pid"
  ready=0
  for ((i=0; i<20; i++)); do
    if /usr/bin/curl --silent --max-time 1 http://127.0.0.1:39224/health | /usr/bin/grep -q 'codex-weekly-monitor'; then ready=1; break; fi
    sleep 0.5
  done
  if [[ "$ready" != 1 ]]; then
    if owned_pid "$STATE/monitor.pid" "$NODE" "$ROOT/monitor.mjs" >/dev/null; then kill "$MONITOR_PID" 2>/dev/null || true; rm -f "$STATE/monitor.pid"; fi
    notice "The local service did not start. Check $STATE/monitor.log." "本机额度服务没有启动，请查看 $STATE/monitor.log。"
    exit 1
  fi
fi

if [[ "$WIDGET_ONLY" == 1 ]]; then
  /usr/bin/open "$APP"
else
  /usr/bin/open "$LAUNCHER"
fi
if [[ "$LANGUAGE" == "zh-CN" ]]; then printf '%s\n' '已启动 Codex 周额度。'; else printf '%s\n' 'Codex Quota Widget is running.'; fi
