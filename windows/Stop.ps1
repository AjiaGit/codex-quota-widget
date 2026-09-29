$ErrorActionPreference = 'Stop'

$runtimeDir = Join-Path $env:TEMP 'CodexWeeklyMonitor'
$statePath = Join-Path $runtimeDir 'state.json'
$expectedScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'monitor.mjs'))
$expectedFloating = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Floating.ps1'))

if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Output '没有本工具的运行记录。'
    exit 0
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if (-not [string]::Equals([string]$state.script, $expectedScript, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw '运行记录指向另一个脚本，已停止操作。'
}

$process = Get-CimInstance Win32_Process -Filter "ProcessId = $($state.pid)" -ErrorAction Stop
$floating = if ($state.floatingPid) { Get-CimInstance Win32_Process -Filter "ProcessId = $($state.floatingPid)" -ErrorAction Stop } else { $null }

if ($process) {
    $sameExecutable = [string]::Equals([string]$process.ExecutablePath, [string]$state.node, [System.StringComparison]::OrdinalIgnoreCase)
    $sameScript = ([string]$process.CommandLine).IndexOf($expectedScript, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    if (-not ($sameExecutable -and $sameScript)) { throw '服务进程身份与本工具不符，已停止操作。' }
}
if ($floating) {
    $sameExecutable = [string]::Equals([string]$floating.ExecutablePath, [string]$state.powershell, [System.StringComparison]::OrdinalIgnoreCase)
    $sameScript = ([string]$floating.CommandLine).IndexOf($expectedFloating, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    if (-not ($sameExecutable -and $sameScript)) { throw '悬浮窗进程身份与本工具不符，已停止操作。' }
}

if ($floating) { Stop-Process -Id ([int]$state.floatingPid) -ErrorAction Stop }
if ($process) { Stop-Process -Id ([int]$state.pid) -ErrorAction Stop }
Remove-Item -LiteralPath $statePath
Remove-Item -LiteralPath (Join-Path $runtimeDir 'show.request') -ErrorAction SilentlyContinue
Write-Output 'Codex 周额度悬浮窗和服务已停止。'
