$ErrorActionPreference = 'Stop'
$helper = Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1'
if (Test-Path -LiteralPath $helper) { . $helper }
$script:failures = 0
function Assert-Equal($actual, $expected, [string]$reason) {
    if ($actual -cne $expected) { throw "$reason. Expected [$expected], got [$actual]" }
}
function Test-Case([string]$name, [scriptblock]$body) {
    try { & $body; Write-Output "PASS $name" }
    catch { $script:failures++; Write-Output "FAIL $name : $($_.Exception.Message)" }
}
Test-Case 'auto language resolves Chinese OS cultures and English fallback' {
    Assert-Equal (Resolve-WidgetLanguage 'auto' 'zh-Hans-CN') 'zh-CN' 'Chinese auto language'
    Assert-Equal (Resolve-WidgetLanguage 'auto' 'fr-FR') 'en' 'Fallback language'
    Assert-Equal (Resolve-WidgetLanguage 'en' 'zh-CN') 'en' 'Explicit setting'
    Assert-Equal (Resolve-WidgetLanguage 'zh-CN' 'en-US') 'zh-CN' 'Explicit setting'
}
Test-Case 'countdown handles minutes hours and days in both languages' {
    Assert-Equal (Format-WidgetCountdown ([TimeSpan]::FromMinutes(30)) 'en') '30m' 'Minutes'
    Assert-Equal (Format-WidgetCountdown ([TimeSpan]::FromMinutes(150)) 'en') '2h 30m' 'Hours'
    Assert-Equal (Format-WidgetCountdown ([TimeSpan]::FromHours(49)) 'zh-CN') '2天 1小时' 'Days'
}
Test-Case 'reset cards stay authoritative and unavailable details stay explicit' {
    $data = [pscustomobject]@{ resetCards = 2; resetDetails = $null }
    $text = Format-WidgetResetDetails $data 'en'
    if (-not $text.Contains('Available reset credits: 2')) { throw 'Count was not displayed' }
    if (-not $text.Contains('Grant and expiry details were not provided.')) { throw 'Missing details claimed complete history' }
}
Test-Case 'reset summary includes grant and expiry but never credit IDs' {
    $data = [pscustomobject]@{ resetCards = 0; resetDetails = @([pscustomobject]@{
        id = 'secret-credit-id'; title = 'Sample grant'; description = 'Fabricated details'; grantedAt = 1790726400; expiresAt = $null
    }) }
    $text = Format-WidgetResetDetails $data 'en'
    if (-not $text.Contains('Available reset credits: 0')) { throw 'Detail count replaced authoritative count' }
    if (-not $text.Contains('Sample grant') -or -not $text.Contains('Granted:') -or -not $text.Contains('Expires: Not provided')) { throw 'Grant/expiry omitted' }
    if ($text.Contains('secret-credit-id')) { throw 'Credit ID exposed' }
}
Test-Case 'all service error codes have actionable localized messages' {
    foreach ($code in @('cli_missing','signed_out','timeout','network','unsupported','service_unavailable','query_failed')) {
        foreach ($language in @('en','zh-CN')) {
            $text = Get-WidgetErrorText $code $language
            if ([string]::IsNullOrWhiteSpace($text) -or $text.Contains($code)) { throw "Untranslated error $code / $language" }
        }
    }
    if (-not (Get-WidgetErrorText 'signed_out' 'en').Contains('codex login')) { throw 'Login action omitted' }
}
Test-Case 'process ownership requires executable exact script and process creation time' {
    $process = [pscustomobject]@{ ExecutablePath = 'C:\Node\node.exe'; CommandLine = '"C:\Node\node.exe" "C:\Widget\monitor.mjs"'; CreationDate = [datetime]'2026-09-30T08:00:00Z' }
    Assert-Equal (Test-WidgetProcessOwnership $process 'C:\Node\node.exe' 'C:\Widget\monitor.mjs' '2026-09-30T08:00:01Z') $true 'Owned process'
    $process.CommandLine = 'node.exe "C:\Widget\monitor.mjs-foreign"'
    Assert-Equal (Test-WidgetProcessOwnership $process 'C:\Node\node.exe' 'C:\Widget\monitor.mjs' $null) $false 'Script prefix spoof'
    $process.CommandLine = 'node.exe "C:\Widget\monitor.mjs"'
    Assert-Equal (Test-WidgetProcessOwnership $process 'C:\Node\node.exe' 'C:\Widget\monitor.mjs' '2026-09-29T08:00:00Z') $false 'Reused process ID'
}
Test-Case 'migration preserves geometry and preferences and rejects foreign process records' {
    $base = Join-Path ([System.IO.Path]::GetTempPath()) ('quota-native-test-' + [guid]::NewGuid())
    try {
        $old = Join-Path $base 'old'; $new = Join-Path $base 'new'; $repo = Join-Path $base 'repo'
        [void][System.IO.Directory]::CreateDirectory($old)
        [void][System.IO.Directory]::CreateDirectory($repo)
        '{"x":10,"y":20,"mode":"Compact","detailWidth":510}' | Set-Content (Join-Path $old 'window.json')
        [IO.File]::WriteAllText((Join-Path $old 'settings.json'), '{"language":"zh-CN"}', [Text.UTF8Encoding]::new($true))
        '{"script":"foreign-monitor.mjs","pid":123}' | Set-Content (Join-Path $old 'state.json')
        Initialize-WidgetStorage $repo $new $old
        $window = Read-WidgetJson (Join-Path $new 'window.json')
        Assert-Equal $window.detailWidth 510 'Window geometry'
        Assert-Equal (Read-WidgetJson (Join-Path $new 'settings.json')).language 'zh-CN' 'Language preference'
        $settingsBytes = [IO.File]::ReadAllBytes((Join-Path $new 'settings.json'))
        Assert-Equal $settingsBytes[0] ([byte]123) 'Settings must be readable by the Node JSON parser without a BOM'
        Assert-Equal (Test-Path (Join-Path $new 'state.json')) $false 'Foreign state'
        Assert-Equal (Test-Path (Join-Path $old 'window.json')) $true 'Migration backup'
        Write-WidgetJson (Join-Path $new 'window.json') @{ x = 99 }
        Initialize-WidgetStorage $repo $new $old
        Assert-Equal (Read-WidgetJson (Join-Path $new 'window.json')).x 99 'Current file wins'
        Remove-Item (Join-Path $new 'settings.json')
        Initialize-WidgetStorage $repo $new $old
        Assert-Equal (Test-Path (Join-Path $new 'settings.json')) $false 'Explicit preference removal must not resurrect a migration backup'
    } finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($script:failures) { throw "$script:failures native helper tests failed" }
