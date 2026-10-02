$ErrorActionPreference = 'Stop'
$windows = Split-Path $PSScriptRoot -Parent
. (Join-Path $windows 'Native.ps1')
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $windows 'Floating.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Floating script failed to parse.' }
$save = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Save-WindowPosition'}, $true)
. ([scriptblock]::Create($save.Extent.Text))
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('quota-position-test-' + [guid]::NewGuid())
try {
    $script:positionPath = Join-Path $scratch 'window.json'
    $script:modePositions = @{ Detail = $null; Compact = $null }
    $script:compactSize = [pscustomobject]@{Width=64;Height=80}
    $script:detailSize = [pscustomobject]@{Width=510;Height=480}
    $script:animating = $false
    $form = [pscustomobject]@{Left=40;Top=70;TopMost=$true}
    $script:mode = 'Detail'; Save-WindowPosition
    $form.Left=900; $form.Top=120
    $script:mode = 'Compact'; Save-WindowPosition
    $saved = Read-WidgetJson $script:positionPath
    if ($saved.detailX -ne 40 -or $saved.detailY -ne 70 -or $saved.compactX -ne 900 -or $saved.compactY -ne 120) {
        throw 'Saving compact geometry erased the independent detail position.'
    }
    if ($saved.detailWidth -ne 510 -or $saved.compactWidth -ne 64) { throw 'Mode sizes changed.' }
    foreach ($mode in @('Detail','Compact')) {
        $restored = Get-WidgetModePosition $saved $mode
        $expectedX = if ($mode -eq 'Detail') {40} else {900}
        if ($restored.x -ne $expectedX) { throw 'A restart lost a mode position.' }
    }
    $legacy = [pscustomobject]@{x=10;y=20;mode='Compact'}
    if ((Get-WidgetModePosition $legacy 'Compact').x -ne 10) { throw 'Legacy active position lost.' }
    if ($null -ne (Get-WidgetModePosition $legacy 'Detail')) { throw 'Unseen legacy mode fabricated a saved position.' }
    $bad = [pscustomobject]@{compactX='NaN';compactY=20;mode='Detail';x=10;y=20}
    if ($null -ne (Get-WidgetModePosition $bad 'Compact')) { throw 'Malformed position accepted.' }
    Write-Output 'PASS independent detail and compact positions survive saving, restart and legacy migration'
    $screen = [pscustomobject]@{Left=0;Top=0;Right=1000;Bottom=800;Width=1000;Height=800}
    $current = [pscustomobject]@{Left=10;Top=10;Width=64;Height=80;Right=74;Bottom=90}
    $size = [pscustomobject]@{Width=404;Height=390}
    $target = Get-WidgetTransitionPosition $current ([pscustomobject]@{x=950;y=-20}) $size $screen
    if ($target.x -ne 596 -or $target.y -ne 0) { throw 'Remembered position was not clamped to the current screen.' }
    $target = Get-WidgetTransitionPosition $current $null $size $screen
    if ($target.x -ne 10 -or $target.y -ne 10) { throw 'First transition changed the existing anchor behavior.' }
    Write-Output 'PASS mode transition restores saved placement within screen bounds and preserves first-use anchoring'
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
