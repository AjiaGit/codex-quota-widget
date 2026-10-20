#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd -P)"
STATE="$HOME/Library/Application Support/CodexWeeklyMonitor"
PATH="$ROOT/runtime:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
export PATH
if [[ -d "$ROOT/../../Helpers/QuotaWidget.app" ]]; then
  APP="$(cd "$ROOT/../../Helpers/QuotaWidget.app" && pwd -P)"
  LAUNCHER="$(cd "$ROOT/../../.." && pwd -P)"
else
  # Keep the legacy source-helper path for process ownership compatibility.
  APP="$ROOT/Codex 周额度.app"
  LAUNCHER="$ROOT/Codex Quota Widget.app"
fi
NODE="$(command -v node 2>/dev/null || true)"
GUARD=""
GUARD_CHECKED=0
GUARD_UNAVAILABLE=0

ensure_guard() {
  if [[ "$GUARD_CHECKED" == 1 ]]; then [[ -n "$GUARD" ]]; return; fi
  GUARD_CHECKED=1
  GUARD="$LAUNCHER/Contents/MacOS/Launch"
  if [[ -x "$GUARD" ]] && /usr/bin/grep -aFq 'CodexQuotaProcessGuard/1' "$GUARD"; then return 0; fi
  # Older generated source apps lack the guard mode. Compile only the Foundation guard
  # instead of invoking an unknown flag on an old GUI launcher. Releases use the prebuilt mode.
  GUARD="$STATE/process-guard"
  if [[ -f "$ROOT/NativeSupport.swift" && ( ! -x "$GUARD" || "$ROOT/NativeSupport.swift" -nt "$GUARD" ) ]]; then
    if /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
      mkdir -p "$STATE/guard-cache"
      local sdk guard_temp
      sdk="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
      [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]] && sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
      guard_temp="$STATE/process-guard.$$.tmp"
      if /usr/bin/xcrun swiftc -parse-as-library -O -D PROCESS_GUARD_ONLY -target "$(uname -m)-apple-macosx13.0" -sdk "$sdk" -module-cache-path "$STATE/guard-cache" "$ROOT/NativeSupport.swift" -o "$guard_temp" >"$STATE/guard-build.log" 2>&1; then
        mv "$guard_temp" "$GUARD"
      else rm -f "$guard_temp"; fi
    fi
  fi
  if [[ -x "$GUARD" ]] && /usr/bin/grep -aFq 'CodexQuotaProcessGuard/1' "$GUARD"; then return 0; fi
  GUARD=""
  GUARD_UNAVAILABLE=1
  return 1
}

stop_owned() {
  local file="$1" expected_executable="$2" expected_script="${3:-}" pid
  [[ -f "$file" ]] || return 0
  pid="$(cat "$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  ensure_guard || return 0
  if [[ -n "$expected_script" ]]; then
    "$GUARD" --owns-process "$pid" "$expected_executable" "$expected_script" || return 0
  else
    "$GUARD" --owns-process "$pid" "$expected_executable" || return 0
  fi
  if kill "$pid" 2>/dev/null; then
    # A different installation may have started while this one was stopping.
    if [[ -f "$file" && "$(cat "$file")" == "$pid" ]]; then rm -f "$file"; fi
  fi
}

stop_owned "$STATE/widget.pid" "$APP/Contents/MacOS/CodexQuota"
stop_owned "$STATE/monitor.pid" "$NODE" "$ROOT/monitor.mjs"
if [[ "${1:-}" != "--from-launcher" ]]; then
  stop_owned "$STATE/launcher.pid" "$LAUNCHER/Contents/MacOS/Launch"
fi
LANGUAGE="$(/usr/bin/plutil -extract language raw -o - "$STATE/settings.json" 2>/dev/null || true)"
if [[ "$LANGUAGE" != "en" && "$LANGUAGE" != "zh-CN" ]]; then
  SYSTEM_LANGUAGE="$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2p' || true)"
  LANGUAGE="en"
  [[ "$SYSTEM_LANGUAGE" == *zh* ]] && LANGUAGE="zh-CN"
fi
if [[ "$GUARD_UNAVAILABLE" == 1 ]]; then
  if [[ "$LANGUAGE" == "zh-CN" ]]; then printf '%s\n' '无法验证进程归属。请先运行 Start.command 更新原生工具，再重试停止。' >&2; else printf '%s\n' 'Process ownership could not be verified. Run Start.command to update the native tools, then retry Stop.command.' >&2; fi
  exit 1
fi
if [[ "$LANGUAGE" == "zh-CN" ]]; then printf '%s\n' 'Codex 额度悬浮窗已停止。'; else printf '%s\n' 'Codex Quota Widget has stopped.'; fi
