$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
# Run the real palette selection with fabricated registry values. No live settings or UI.
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $PSScriptRoot -Parent) 'Floating.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Floating script failed to parse'}
foreach($name in @('New-Color','Set-Theme')) {
    $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    if(-not $definition){throw "Missing production function: $name"}
    Invoke-Expression $definition.Extent.Text
}
# Drawing and control-tree integration are covered by native-ui-parity on Windows.
function Set-ControlTheme($control) {}
function Set-Tray-QuotaIcon {}
$ring=[pscustomobject]@{}
$ring | Add-Member ScriptMethod Invalidate {}
function Get-ItemProperty {
    [CmdletBinding()]param([string]$Path,[string]$Name)
    if($Path -ne 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'){throw 'Unexpected registry path'}
    if($Name -eq 'AppsUseLightTheme'){return [pscustomobject]@{AppsUseLightTheme=$script:fixtureAppLight}}
    if($Name -eq 'SystemUsesLightTheme'){return [pscustomobject]@{SystemUsesLightTheme=$script:fixtureSystemLight}}
    throw 'Unexpected registry value'
}
$failures=0
foreach($Theme in @('System','Light','Dark')) {
    foreach($systemLight in @(0,1)) {foreach($appLight in @(0,1)) {
        $script:fixtureSystemLight=$systemLight;$script:fixtureAppLight=$appLight
        $script:themeIsLight=$null;$script:themeApplied=$false;$script:colors=$null
        Set-Theme
        $expected=@{back='#20252D';text='#F3F5F7';muted='#A1AAB6';accent='#24D3A5';danger='#FA7D79';warning='#F4CF65'}
        $wrong=@($expected.Keys | Where-Object {$script:colors[$_].ToArgb() -ne ([Drawing.ColorTranslator]::FromHtml($expected[$_])).ToArgb()})
        if($wrong.Count){$failures++;Write-Output "FAIL fixed dark palette Theme=$Theme system=$systemLight app=$appLight : $($wrong -join ',')"}
        else{Write-Output "PASS fixed dark palette Theme=$Theme system=$systemLight app=$appLight"}
    }}
}
if($failures){throw "$failures fixed appearance cases failed"}
