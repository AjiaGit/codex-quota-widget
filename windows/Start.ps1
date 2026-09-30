param([switch]$NoUi)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Native.ps1')
$runtimeDir = Get-WidgetDataDirectory
$language = Resolve-WidgetLanguage (Get-WidgetLanguageSetting $runtimeDir)
$mutex = $null
try {
    $mutex = Enter-WidgetLifecycleLock $runtimeDir $language
    Initialize-WidgetStorage $PSScriptRoot $runtimeDir
    $language = Resolve-WidgetLanguage (Get-WidgetLanguageSetting $runtimeDir)
    $port = 39224
    $url = "http://127.0.0.1:$port/"
    $statePath = Join-Path $runtimeDir 'state.json'
    $scriptPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'monitor.mjs'))
    $floatingScript = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Floating.ps1'))
    $state = Read-WidgetJson $statePath
    if ($state -and -not [string]::Equals([string]$state.script, $scriptPath, [StringComparison]::OrdinalIgnoreCase)) {
        Throw-WidgetError 'foreignState' $language
    }
    function Get-MonitorHealth {
        try { Invoke-RestMethod -Uri "${url}health" -TimeoutSec 2 } catch { $null }
    }
    $health = Get-MonitorHealth
    $existingService = $null
    if ($state -and $state.pid -and [int]$state.pid -gt 0) {
        $existingService = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$state.pid)" -ErrorAction SilentlyContinue
        if ($existingService -and -not (Test-WidgetProcessOwnership $existingService $state.node $scriptPath $state.startedAt)) {
            Throw-WidgetError 'foreignService' $language
        }
    }
    if ($state -and $state.storageVersion -ne 2) {
        # Legacy clients read TEMP. Restart only validated owned processes after migration.
        $oldFloating = if ($state.floatingPid -and [int]$state.floatingPid -gt 0) { Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$state.floatingPid)" -ErrorAction SilentlyContinue } else { $null }
        if ($oldFloating -and -not (Test-WidgetProcessOwnership $oldFloating $state.powershell $floatingScript $state.floatingStartedAt)) { Throw-WidgetError 'foreignFloating' $language }
        if ($oldFloating) { Stop-Process -Id ([int]$state.floatingPid) -ErrorAction Stop }
        if ($existingService) { Stop-Process -Id ([int]$state.pid) -ErrorAction Stop; $existingService = $null; $health = $null }
        if ($state.floatingPid) { $state.floatingPid = $null }
    }
    if ($health -and $health.app -eq 'codex-weekly-monitor') {
        if (-not $state -or -not $existingService) { Throw-WidgetError 'missingState' $language }
    } else {
        # A healthy owned process may still be finishing startup. Never launch a duplicate.
        if ($existingService) { Throw-WidgetError 'startFailed' $language @((Join-Path $runtimeDir 'stderr.log')) }
        $socket = New-Object Net.Sockets.TcpClient
        $portBusy = $false
        try { $socket.Connect('127.0.0.1', $port); $portBusy = $true } catch [Net.Sockets.SocketException] { } finally { $socket.Dispose() }
        if ($portBusy) { Throw-WidgetError 'portBusy' $language @($port) }
        $node = Find-WidgetNode $PSScriptRoot
        if (-not $node) { Throw-WidgetError 'nodeMissing' $language }
        $codex = Find-WidgetCodex
        if ($codex) { $env:CODEX_CLI_PATH = $codex }
        $stdout = Join-Path $runtimeDir 'stdout.log'
        $stderr = Join-Path $runtimeDir 'stderr.log'
        $process = Start-Process -FilePath $node -ArgumentList ('"' + $scriptPath + '"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if (-not $state) { $state = [pscustomobject]@{} }
        $state | Add-Member -NotePropertyName storageVersion -NotePropertyValue 2 -Force
        $state | Add-Member -NotePropertyName pid -NotePropertyValue $process.Id -Force
        $state | Add-Member -NotePropertyName node -NotePropertyValue $node -Force
        $state | Add-Member -NotePropertyName script -NotePropertyValue $scriptPath -Force
        $state | Add-Member -NotePropertyName startedAt -NotePropertyValue $process.StartTime.ToUniversalTime().ToString('o') -Force
        Write-WidgetJson $statePath $state
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Milliseconds 250
            $health = Get-MonitorHealth
            if ($health -and $health.app -eq 'codex-weekly-monitor') { break }
            if ($process.HasExited) { break }
        }
        if (-not ($health -and $health.app -eq 'codex-weekly-monitor')) { Throw-WidgetError 'startFailed' $language @($stderr) }
    }
    if (-not $NoUi) {
        $floatingActive = $false
        if ($state.floatingPid -and [int]$state.floatingPid -gt 0) {
            $existing = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$state.floatingPid)" -ErrorAction SilentlyContinue
            if ($existing) {
                if (-not (Test-WidgetProcessOwnership $existing $state.powershell $floatingScript $state.floatingStartedAt)) {
                    Throw-WidgetError 'foreignFloating' $language
                }
                $floatingActive = $true
            }
        }
        if (-not $floatingActive) {
            $powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
            $floatingOut = Join-Path $runtimeDir 'floating-stdout.log'; $floatingErr = Join-Path $runtimeDir 'floating-stderr.log'
            $floating = Start-Process -FilePath $powershell -ArgumentList @('-NoProfile','-Sta','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"' + $floatingScript + '"')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $floatingOut -RedirectStandardError $floatingErr
            $state | Add-Member -NotePropertyName floatingPid -NotePropertyValue $floating.Id -Force
            $state | Add-Member -NotePropertyName powershell -NotePropertyValue $powershell -Force
            $state | Add-Member -NotePropertyName floatingScript -NotePropertyValue $floatingScript -Force
            $state | Add-Member -NotePropertyName floatingStartedAt -NotePropertyValue $floating.StartTime.ToUniversalTime().ToString('o') -Force
            Write-WidgetJson $statePath $state
            Start-Sleep -Milliseconds 1200
            if ($floating.HasExited) { Throw-WidgetError 'floatingFailed' $language @($floatingErr) }
        }
        [IO.File]::WriteAllText((Join-Path $runtimeDir 'show.request'), [DateTimeOffset]::UtcNow.ToString('o'))
    }
    # Reopening also requests an immediate remote refresh. The service coalesces it.
    if ($NoUi) { try { Invoke-RestMethod -Method Post -Uri "${url}api/refresh" -TimeoutSec 25 | Out-Null } catch { } }
    Write-Output (Get-WidgetText 'opened' $language)
} catch {
    $safeMessage = if ($_.Exception.Data['widgetSafeMessage']) { $_.Exception.Message } else { Get-WidgetText 'startFailed' $language @((Join-Path $runtimeDir 'stderr.log')) }
    if (-not $NoUi) { Show-WidgetFailure $safeMessage $language }
    else { Write-Error $safeMessage -ErrorAction Continue }
    exit 1
} finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
}
