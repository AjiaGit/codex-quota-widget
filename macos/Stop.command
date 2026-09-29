#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
STATE="$HOME/Library/Application Support/CodexWeeklyMonitor"
EXE="$ROOT/Codex 周额度.app/Contents/MacOS/CodexQuota"

stop_owned() {
  local file="$1" expected="$2" pid command
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file")"
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    if [[ "$command" == *"$expected"* ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$file"
}

stop_owned "$STATE/widget.pid" "$EXE"
stop_owned "$STATE/monitor.pid" "$ROOT/monitor.mjs"
echo 'Codex 周额度工具已停止。'
