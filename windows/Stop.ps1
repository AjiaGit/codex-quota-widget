param([switch]$Quiet, [switch]$RemovePreferences)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Native.ps1')
$runtimeDir = Get-WidgetDataDirectory
$language = Resolve-WidgetLanguage (Get-WidgetLanguageSetting $runtimeDir)
$mutex = $null
try {
    $mutex = Enter-WidgetLifecycleLock $runtimeDir $language
    Initialize-WidgetStorage $PSScriptRoot $runtimeDir
    $statePath = Join-Path $runtimeDir 'state.json'
    $expectedScript = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'monitor.mjs'))
    $expectedFloating = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Floating.ps1'))
    $state = Read-WidgetJson $statePath
    if ($state) {
        if (-not [string]::Equals([string]$state.script, $expectedScript, [StringComparison]::OrdinalIgnoreCase)) { Throw-WidgetError 'foreignState' $language }
        $service = if ($state.pid -and [int]$state.pid -gt 0) { Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$state.pid)" -ErrorAction SilentlyContinue } else { $null }
        $floating = if ($state.floatingPid -and [int]$state.floatingPid -gt 0) { Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$state.floatingPid)" -ErrorAction SilentlyContinue } else { $null }
        if ($service -and -not (Test-WidgetProcessOwnership $service $state.node $expectedScript $state.startedAt)) { Throw-WidgetError 'foreignService' $language }
        if ($floating -and -not (Test-WidgetProcessOwnership $floating $state.powershell $expectedFloating $state.floatingStartedAt)) { Throw-WidgetError 'foreignFloating' $language }
        # Validate both processes before stopping either one.
        if ($floating) {
            [IO.File]::WriteAllText((Join-Path $runtimeDir 'quit.request'), 'quit')
            for ($attempt = 0; $attempt -lt 8; $attempt++) {
                if (-not (Get-Process -Id ([int]$state.floatingPid) -ErrorAction SilentlyContinue)) { break }
                Start-Sleep -Milliseconds 250
            }
            # Graceful close saves geometry; force only an owned process that did not exit.
            $stillFloating = Get-CimInstance Win32_Process -Filter "ProcessId = $([int]$state.floatingPid)" -ErrorAction SilentlyContinue
            if ($stillFloating) {
                if (-not (Test-WidgetProcessOwnership $stillFloating $state.powershell $expectedFloating $state.floatingStartedAt)) { Throw-WidgetError 'foreignFloating' $language }
                Stop-Process -Id ([int]$state.floatingPid) -ErrorAction Stop
            }
        }
        if ($service) { Stop-Process -Id ([int]$state.pid) -ErrorAction Stop }
        Remove-Item -LiteralPath $statePath -Force
        Remove-Item -LiteralPath (Join-Path $runtimeDir 'show.request') -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $runtimeDir 'quit.request') -ErrorAction SilentlyContinue
        Write-Output (Get-WidgetText 'stopped' $language)
    } else { Write-Output (Get-WidgetText 'noState' $language) }
    if ($RemovePreferences) {
        foreach ($name in @('settings.json','window.json')) { Remove-Item -LiteralPath (Join-Path $runtimeDir $name) -Force -ErrorAction SilentlyContinue }
    }
} catch {
    $safeMessage = if ($_.Exception.Data['widgetSafeMessage']) { $_.Exception.Message } else { Get-WidgetText 'stopFailed' $language }
    if (-not $Quiet) { Show-WidgetFailure $safeMessage $language }
    else { Write-Error $safeMessage -ErrorAction Continue }
    exit 1
} finally {
    if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
}
