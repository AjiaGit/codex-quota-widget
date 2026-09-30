#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
STATE="$HOME/Library/Application Support/CodexWeeklyMonitor"
if [[ -d "$ROOT/../../Helpers/QuotaWidget.app" ]]; then
  APP="$(cd "$ROOT/../../Helpers/QuotaWidget.app" && pwd -P)"
  LAUNCHER="$(cd "$ROOT/../../.." && pwd -P)"
else
  APP="$ROOT/Codex 周额度.app"
  LAUNCHER="$ROOT/Codex Quota Widget.app"
fi

stop_owned() {
  local file="$1" expected="$2" pid command
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
  if [[ "$command" == "$expected" || "$command" == "$expected "* || "$command" == *" $expected" || "$command" == *" $expected "* ]]; then
    kill "$pid" 2>/dev/null || true
    # A different installation may have started while this one was stopping.
    if [[ -f "$file" && "$(cat "$file")" == "$pid" ]]; then rm -f "$file"; fi
  fi
}

stop_owned "$STATE/widget.pid" "$APP/Contents/MacOS/CodexQuota"
stop_owned "$STATE/monitor.pid" "$ROOT/monitor.mjs"
if [[ "${1:-}" != "--from-launcher" ]]; then
  stop_owned "$STATE/launcher.pid" "$LAUNCHER/Contents/MacOS/Launch"
fi
LANGUAGE="$(/usr/bin/plutil -extract language raw -o - "$STATE/settings.json" 2>/dev/null || true)"
if [[ "$LANGUAGE" != "en" && "$LANGUAGE" != "zh-CN" ]]; then
  SYSTEM_LANGUAGE="$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2p' || true)"
  LANGUAGE="en"
  [[ "$SYSTEM_LANGUAGE" == *zh* ]] && LANGUAGE="zh-CN"
fi
if [[ "$LANGUAGE" == "zh-CN" ]]; then printf '%s\n' 'Codex 周额度工具已停止。'; else printf '%s\n' 'Codex Quota Widget has stopped.'; fi
