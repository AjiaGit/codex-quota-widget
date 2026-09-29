$ErrorActionPreference = 'Stop'

$port = 39224
$url = "http://127.0.0.1:$port/"
$healthUrl = "${url}health"
$runtimeDir = Join-Path $env:TEMP 'CodexWeeklyMonitor'
$statePath = Join-Path $runtimeDir 'state.json'
$scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'monitor.mjs'))
$floatingScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Floating.ps1'))
$showRequest = Join-Path $runtimeDir 'show.request'
$state = if (Test-Path -LiteralPath $statePath) { Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } else { $null }
if ($state -and -not [string]::Equals([string]$state.script, $scriptPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw '运行记录指向另一份工具，已停止操作。'
}

function Get-MonitorHealth {
    try {
        return Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2
    } catch {
        return $null
    }
}

$health = Get-MonitorHealth
if ($health -and $health.app -eq 'codex-weekly-monitor') {
    if (-not $state) { throw '服务已运行，但缺少本工具的运行记录。' }
    # A service launched before a Codex session/environment change can keep failing
    # while a fresh App Server query succeeds. Recover it once per 20 minutes.
    $usage = try { Invoke-RestMethod -Uri "${url}api/usage" -TimeoutSec 3 } catch { $null }
    if ($usage -and $usage.status -eq 'unavailable') {
        $lastRecovery = [DateTimeOffset]::MinValue
        try { if ($state.lastRecoveryAt) { $lastRecovery = [DateTimeOffset]::Parse([string]$state.lastRecoveryAt) } } catch { }
        if (([DateTimeOffset]::Now - $lastRecovery).TotalMinutes -ge 20) {
            $existingService = Get-CimInstance Win32_Process -Filter "ProcessId = $($state.pid)"
            if (-not $existingService -or
                -not [string]::Equals([string]$existingService.ExecutablePath, [string]$state.node, [System.StringComparison]::OrdinalIgnoreCase) -or
                ([string]$existingService.CommandLine).IndexOf($scriptPath, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw '旧服务进程身份与运行记录不符，未自动恢复。'
            }
            Stop-Process -Id ([int]$state.pid) -ErrorAction Stop
            $state | Add-Member -NotePropertyName lastRecoveryAt -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
            $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
            $health = $null
        }
    }
}
if (-not ($health -and $health.app -eq 'codex-weekly-monitor')) {
    $socket = New-Object System.Net.Sockets.TcpClient
    $portBusy = $false
    try {
        $socket.Connect('127.0.0.1', $port)
        $portBusy = $true
    } catch [System.Net.Sockets.SocketException] {
        $portBusy = $false
    } finally {
        $socket.Dispose()
    }
    if ($portBusy) { throw "端口 $port 已被其他程序占用。" }

    $node = (Get-Command node.exe -ErrorAction Stop).Source
    New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
    $stdoutPath = Join-Path $runtimeDir 'stdout.log'
    $stderrPath = Join-Path $runtimeDir 'stderr.log'
    $process = Start-Process -FilePath $node -ArgumentList ('"' + $scriptPath + '"') `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (-not $state) { $state = [PSCustomObject]@{} }
    $state | Add-Member -NotePropertyName pid -NotePropertyValue $process.Id -Force
    $state | Add-Member -NotePropertyName node -NotePropertyValue $node -Force
    $state | Add-Member -NotePropertyName script -NotePropertyValue $scriptPath -Force
    $state | Add-Member -NotePropertyName startedAt -NotePropertyValue (Get-Date).ToString('o') -Force
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8

    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Milliseconds 250
        $health = Get-MonitorHealth
        if ($health -and $health.app -eq 'codex-weekly-monitor') { break }
        if ($process.HasExited) { break }
    }
    if (-not ($health -and $health.app -eq 'codex-weekly-monitor')) {
        $diagnostic = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Tail 5 } else { @() }
        throw "服务启动失败。请查看 $stderrPath。$($diagnostic -join ' ')"
    }
}

$floatingActive = $false
if ($state.floatingPid) {
    $existing = Get-CimInstance Win32_Process -Filter "ProcessId = $($state.floatingPid)"
    if ($existing) {
        $sameExecutable = [string]::Equals([string]$existing.ExecutablePath, [string]$state.powershell, [System.StringComparison]::OrdinalIgnoreCase)
        $sameScript = ([string]$existing.CommandLine).IndexOf($floatingScript, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        if (-not ($sameExecutable -and $sameScript)) { throw '悬浮窗进程身份与运行记录不符。' }
        $floatingActive = $true
    }
}

if (-not $floatingActive) {
    $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $floatingOut = Join-Path $runtimeDir 'floating-stdout.log'
    $floatingErr = Join-Path $runtimeDir 'floating-stderr.log'
    $floating = Start-Process -FilePath $powershell `
        -ArgumentList @('-NoProfile', '-Sta', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $floatingScript + '"')) `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $floatingOut -RedirectStandardError $floatingErr
    Start-Sleep -Milliseconds 1200
    if ($floating.HasExited) {
        $diagnostic = if (Test-Path -LiteralPath $floatingErr) { Get-Content -LiteralPath $floatingErr -Tail 8 } else { @() }
        throw "悬浮窗启动失败。请查看 $floatingErr。$($diagnostic -join ' ')"
    }
    $state | Add-Member -NotePropertyName floatingPid -NotePropertyValue $floating.Id -Force
    $state | Add-Member -NotePropertyName powershell -NotePropertyValue $powershell -Force
    $state | Add-Member -NotePropertyName floatingScript -NotePropertyValue $floatingScript -Force
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
}

(Get-Date).ToString('o') | Set-Content -LiteralPath $showRequest -Encoding ASCII
Write-Output 'Codex 周额度悬浮窗已打开。'
