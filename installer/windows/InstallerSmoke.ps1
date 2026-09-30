param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [string]$UpgradeInstaller,
    [string]$OutputDir
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Installer smoke requires Windows.' }
if (-not $env:CI) { throw 'Run installer smoke in isolated Windows CI or a disposable CI test user.' }
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $OutputDir) { $OutputDir = Join-Path $env:TEMP ('codex-quota-smoke-' + [guid]::NewGuid()) }
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
if ($OutputDir.StartsWith($repository.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Smoke artifacts must stay outside the repository.' }
[void][IO.Directory]::CreateDirectory($OutputDir)
$Installer = [IO.Path]::GetFullPath($Installer)
if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) { throw 'Installer file does not exist.' }
if ($UpgradeInstaller) { $UpgradeInstaller = [IO.Path]::GetFullPath($UpgradeInstaller) }
$savedLocal = $env:LOCALAPPDATA; $savedTemp = $env:TEMP; $savedTmp = $env:TMP; $savedPath = $env:PATH
$savedCli = $env:CODEX_CLI_PATH; $savedModeFile = $env:QUOTA_SMOKE_MODE_FILE
$env:LOCALAPPDATA = Join-Path $OutputDir 'AppData'
$env:TEMP = Join-Path $OutputDir 'Temp'; $env:TMP = $env:TEMP
[void][IO.Directory]::CreateDirectory($env:TEMP)
$env:PATH = "$env:SystemRoot\System32;$env:SystemRoot\System32\WindowsPowerShell\v1.0"
$installDir = Join-Path $OutputDir 'installed'
$dataDir = Join-Path $env:LOCALAPPDATA 'CodexWeeklyMonitor'
$testProcesses = New-Object 'System.Collections.Generic.List[System.Diagnostics.Process]'
$serviceUrl = 'http://127.0.0.1:39224'
$uninstalled = $false
function Assert-True([bool]$condition, [string]$message) { if (-not $condition) { throw $message } }
function Wait-Until([scriptblock]$condition, [string]$message, [int]$seconds = 40) {
    $deadline = [DateTime]::UtcNow.AddSeconds($seconds)
    do { try { if (& $condition) { return } } catch { }; Start-Sleep -Milliseconds 250 } while ([DateTime]::UtcNow -lt $deadline)
    throw $message
}
function Install-Widget([string]$path, [string]$logName) {
    $arguments = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-','/TASKS=desktopicon',('/DIR="' + $installDir + '"'),('/LOG="' + (Join-Path $OutputDir $logName) + '"'))
    $installerProcess = Start-Process -FilePath $path -ArgumentList $arguments -Wait -PassThru
    Assert-True ($installerProcess.ExitCode -eq 0) "Installation failed: $logName"
}
function Start-Installed {
    [void](Start-Process -FilePath (Join-Path $installDir 'CodexQuotaWidget.exe') -PassThru)
    Wait-Until { (Invoke-RestMethod "$serviceUrl/health" -TimeoutSec 2).app -eq 'codex-weekly-monitor' } 'Installed service did not become healthy.'
    Wait-Until { $state = Read-WidgetJson (Join-Path $dataDir 'state.json'); $state -and $state.floatingPid -and (Get-Process -Id $state.floatingPid -ErrorAction SilentlyContinue) } 'Native floating window did not stay running.'
    Wait-Until { (Invoke-RestMethod "$serviceUrl/api/usage" -TimeoutSec 2).status -eq 'ok' } 'Fabricated Codex fixture did not supply quota.'
}
function Stop-Installed {
    $stop = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + (Join-Path $installDir 'Stop.ps1') + '"'),'-Quiet') -Wait -PassThru -WindowStyle Hidden
    Assert-True ($stop.ExitCode -eq 0) 'Owned monitor stop failed.'
    Wait-Until { -not (Test-Path -LiteralPath (Join-Path $dataDir 'state.json')) } 'Runtime state remained after quit.'
    $healthy = $false
    try { Invoke-RestMethod "$serviceUrl/health" -TimeoutSec 1 | Out-Null; $healthy = $true } catch { }
    Assert-True (-not $healthy) 'Service remained after quit.'
}
try {
    # Fabricated npm shim: no credentials, access token, auth file, or real account.
    $fixtureRoot = Join-Path $OutputDir 'fixture'
    $bin = Join-Path $fixtureRoot 'node_modules/@openai/codex/bin'
    [void][IO.Directory]::CreateDirectory($bin)
    $env:CODEX_CLI_PATH = Join-Path $fixtureRoot 'codex.cmd'
    [IO.File]::WriteAllText($env:CODEX_CLI_PATH, '@echo off' + "`r`n")
    $env:QUOTA_SMOKE_MODE_FILE = Join-Path $fixtureRoot 'mode.txt'
    [IO.File]::WriteAllText($env:QUOTA_SMOKE_MODE_FILE, 'ok')
    $fixture = @'
const readline = require('node:readline');
const fs = require('node:fs');
const now = Math.floor(Date.now()/1000);
const answer = (id, result) => process.stdout.write(JSON.stringify({id,result})+'\n');
readline.createInterface({input:process.stdin}).on('line', line => {
  const request = JSON.parse(line);
  if(request.method==='initialize') answer(request.id,{});
  else if(request.method==='account/rateLimits/read') answer(request.id,{
    rateLimits:{primary:{usedPercent:61,windowDurationMins:10080,resetsAt:now+3600*72},secondary:{usedPercent:25,windowDurationMins:300,resetsAt:now+3600}},
    rateLimitResetCredits:{availableCount:2,credits:[{id:'fixture-id-must-never-be-shown',title:'Sample grant / 示例发放',description:'Fabricated test data / 虚构测试数据',grantedAt:now-86400,expiresAt:now+86400}]}
  });
  else if(request.method==='account/read') answer(request.id,fs.readFileSync(process.env.QUOTA_SMOKE_MODE_FILE,'utf8').trim()==='signed_out'
    ? {account:null,requiresOpenaiAuth:true}
    : {account:{type:'chatgpt',planType:'plus'},requiresOpenaiAuth:true});
});
'@
    [IO.File]::WriteAllText((Join-Path $bin 'codex.js'), $fixture, [Text.UTF8Encoding]::new($false))
    Install-Widget $Installer 'install.log'
    . (Join-Path $installDir 'Native.ps1')
    foreach ($name in @('CodexQuotaWidget.exe','Floating.ps1','Native.ps1','monitor.mjs','cli.mjs','public/i18n.mjs','runtime/node.exe','runtime/LICENSE','LICENSE')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $installDir $name)) "Installed payload missing $name"
    }
    # PowerShell 5.1 requires a BOM for Chinese literals; source checkout and installed payload must preserve CRLF.
    foreach ($file in @(Get-ChildItem -LiteralPath $installDir -Filter '*.ps1' -File)) {
        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        Assert-True ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) "UTF-8 BOM missing: $($file.Name)"
        $text = [Text.Encoding]::UTF8.GetString($bytes,3,$bytes.Length-3)
        Assert-True (-not $text.Replace("`r`n",'').Contains("`n")) "CRLF missing: $($file.Name)"
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $installDir -Filter '*.cmd' -File)) {
        $text = [IO.File]::ReadAllText($file.FullName)
        Assert-True (-not $text.Replace("`r`n",'').Contains("`n")) "CRLF missing: $($file.Name)"
    }
    Assert-True (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Quota Widget.lnk')) 'Start Menu shortcut missing.'
    Assert-True (Test-Path (Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Codex Quota Widget.lnk')) 'Optional desktop shortcut missing.'
    Write-WidgetJson (Join-Path $dataDir 'window.json') @{ x=100; y=100; mode='Detail'; compactWidth=52; compactHeight=76; detailWidth=510; detailHeight=460; topMost=$true }
    Start-Installed
    $state = Read-WidgetJson (Join-Path $dataDir 'state.json')
    Assert-True ([string]::Equals($state.node, (Join-Path $installDir 'runtime/node.exe'), [StringComparison]::OrdinalIgnoreCase)) 'Launcher did not use the bundled runtime.'
    $usage = Invoke-RestMethod "$serviceUrl/api/usage"
    Assert-True ($usage.remainingPercent -eq 39 -and $usage.resetCards -eq 2 -and @($usage.resetDetails).Count -eq 1) 'Fixture quota or authoritative count was changed.'
    Assert-True (-not ($usage | ConvertTo-Json -Depth 8).Contains('fixture-id-must-never-be-shown')) 'Credit ID leaked from service.'
    $settings = Invoke-RestMethod "$serviceUrl/api/settings" -Method Post -ContentType 'application/json' -Body '{"language":"zh-CN"}'
    Assert-True ($settings.language -eq 'zh-CN') 'Language API failed.'
    $firstPid = $state.pid; $firstFloatingPid = $state.floatingPid
    Start-Installed
    $state = Read-WidgetJson (Join-Path $dataDir 'state.json')
    Assert-True ($state.pid -eq $firstPid -and $state.floatingPid -eq $firstFloatingPid) 'Reopening launched duplicate processes.'
    [IO.File]::WriteAllText($env:QUOTA_SMOKE_MODE_FILE, 'signed_out')
    $signedOut = Invoke-RestMethod "$serviceUrl/api/refresh" -Method Post -TimeoutSec 30
    Assert-True ($signedOut.errorCode -eq 'signed_out') 'Signed-out setup state is not actionable.'
    [IO.File]::WriteAllText($env:QUOTA_SMOKE_MODE_FILE, 'ok')
    Move-Item -LiteralPath $env:CODEX_CLI_PATH -Destination ($env:CODEX_CLI_PATH + '.disabled')
    try {
        $missingCli = Invoke-RestMethod "$serviceUrl/api/refresh" -Method Post -TimeoutSec 30
        Assert-True ($missingCli.errorCode -eq 'cli_missing') 'Missing CLI was not reported with setup guidance.'
    } finally { Move-Item -LiteralPath ($env:CODEX_CLI_PATH + '.disabled') -Destination $env:CODEX_CLI_PATH }
    [void](Invoke-RestMethod "$serviceUrl/api/refresh" -Method Post -TimeoutSec 30)
    # Upgrade while owned processes are running; the installer must stop them before copying.
    $preferences = Read-WidgetJson (Join-Path $dataDir 'window.json')
    if ($UpgradeInstaller) { Install-Widget $UpgradeInstaller 'upgrade.log' }
    else { Install-Widget $Installer 'reinstall.log' }
    Assert-True ((Read-WidgetJson (Join-Path $dataDir 'settings.json')).language -eq 'zh-CN') 'Upgrade lost language.'
    Assert-True ((Read-WidgetJson (Join-Path $dataDir 'window.json')).detailWidth -eq $preferences.detailWidth) 'Upgrade lost geometry.'
    Start-Installed
    Stop-Installed
    Assert-True (Test-Path (Join-Path $dataDir 'settings.json')) 'Quit deleted preferences.'
    # Completely fabricated native screenshots use a local fixture, including external data.
    $uiFixturePath = Join-Path $fixtureRoot 'ui-fixture.js'
    $uiFixture = @'
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const settingsFile=path.join(process.env.LOCALAPPDATA,'CodexWeeklyMonitor','settings.json');
http.createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');
  if(req.url==='/api/settings') {
    if(req.method==='POST'){let text='';for await(const chunk of req)text+=chunk;fs.writeFileSync(settingsFile,text);res.end(text);}
    else res.end(fs.readFileSync(settingsFile,'utf8'));
  } else if(req.url==='/api/external')res.end(JSON.stringify({status:'unavailable',lastGlobal:null,forecast:null}));
  else {const now=Math.floor(Date.now()/1000);res.end(JSON.stringify({status:'ok',plan:'plus',remainingPercent:39,resetsAt:now+259200,updatedAt:Date.now(),resetCards:2,resetDetails:[{title:'Sample grant / 示例发放',description:'Fabricated test data / 虚构测试数据',grantedAt:now-86400,expiresAt:now+86400}],fiveHour:{remainingPercent:75,resetsAt:now+3600}}));}
}).listen(39225,'127.0.0.1');
'@
    [IO.File]::WriteAllText($uiFixturePath, $uiFixture, [Text.UTF8Encoding]::new($false))
    $uiService = Start-Process -FilePath (Join-Path $installDir 'runtime/node.exe') -ArgumentList ('"'+$uiFixturePath+'"') -PassThru -WindowStyle Hidden
    $testProcesses.Add($uiService)
    Wait-Until { (Invoke-RestMethod 'http://127.0.0.1:39225/api/usage' -TimeoutSec 1).status -eq 'ok' } 'UI fixture failed.'
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public static class QuotaSmokeWindows {
    private delegate bool EnumProc(IntPtr hWnd, IntPtr param);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr param);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    public static IntPtr Find(int pid, string title) {
        IntPtr result=IntPtr.Zero;
        EnumWindows(delegate(IntPtr window, IntPtr unused) {
            uint owner; GetWindowThreadProcessId(window, out owner);
            if(owner==(uint)pid && IsWindowVisible(window)) {
                var text=new StringBuilder(256); GetWindowText(window,text,text.Capacity);
                if(text.ToString()==title) { result=window; return false; }
            } return true;
        },IntPtr.Zero); return result;
    }
}
'@
    foreach ($language in @('en','zh-CN')) {
        [void](Invoke-RestMethod 'http://127.0.0.1:39225/api/settings' -Method Post -ContentType 'application/json' -Body ('{"language":"'+$language+'"}'))
        $ui = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList @('-NoProfile','-Sta','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+(Join-Path $installDir 'Floating.ps1')+'"'),'-BaseUrl','http://127.0.0.1:39225') -PassThru -WindowStyle Hidden
        $testProcesses.Add($ui)
        $title = Get-WidgetText 'app' $language
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$title) -ne [IntPtr]::Zero } "Localized native window missing: $language"
        $handle = [QuotaSmokeWindows]::Find($ui.Id,$title)
        [void][QuotaSmokeWindows]::SetForegroundWindow($handle)
        $element = [Windows.Automation.AutomationElement]::FromHandle($handle)
        $creditText = Get-WidgetText 'cards' $language @(2)
        $creditCondition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$creditText)
        Wait-Until { $null -ne $element.FindFirst([Windows.Automation.TreeScope]::Descendants,$creditCondition) } "Native quota failed to render: $language"
        $labels = $element.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
        $names = @($labels | ForEach-Object { $_.Current.Name }) -join "`n"
        Assert-True ($names.Contains((Get-WidgetText 'fiveHour' $language))) "5-hour title untranslated: $language"
        Assert-True (-not $names.Contains('fixture-id-must-never-be-shown')) 'Native UI leaked an ID.'
        $rectangle = $element.Current.BoundingRectangle
        $bitmap = [Drawing.Bitmap]::new([int]$rectangle.Width,[int]$rectangle.Height)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.CopyFromScreen([int]$rectangle.X,[int]$rectangle.Y,0,0,$bitmap.Size); $bitmap.Save((Join-Path $OutputDir ("native-$language.png")),[Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
        # Label click opens the actual scrollable credit details window.
        $creditElement = $element.FindFirst([Windows.Automation.TreeScope]::Descendants,$creditCondition)
        $creditHandle = [IntPtr]$creditElement.Current.NativeWindowHandle
        [void][QuotaSmokeWindows]::SendMessage($creditHandle,0x201,[IntPtr]1,[IntPtr]0x00050005)
        [void][QuotaSmokeWindows]::SendMessage($creditHandle,0x202,[IntPtr]0,[IntPtr]0x00050005)
        $detailsTitle = Get-WidgetText 'detailsTitle' $language
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$detailsTitle) -ne [IntPtr]::Zero } "Reset details window missing: $language"
        $detailsElement = [Windows.Automation.AutomationElement]::FromHandle([QuotaSmokeWindows]::Find($ui.Id,$detailsTitle))
        $editCondition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Edit)
        $edit = $detailsElement.FindFirst([Windows.Automation.TreeScope]::Descendants,$editCondition)
        Assert-True ($null -ne $edit) 'Scrollable reset details text was missing.'
        $detailValue = ([Windows.Automation.ValuePattern]$edit.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern)).Current.Value
        Assert-True ($detailValue.Contains((Get-WidgetText 'detailsCount' $language @(2)))) 'Reset details changed authoritative count.'
        Assert-True ($detailValue.Contains((Get-WidgetText 'grant' $language @('')).Trim()) -and $detailValue.Contains((Get-WidgetText 'expiry' $language @('')).Trim())) 'Grant or expiry fields were not localized.'
        Assert-True (-not $detailValue.Contains('fixture-id-must-never-be-shown')) 'Reset details exposed an ID.'
        $rectangle = $detailsElement.Current.BoundingRectangle
        $bitmap = [Drawing.Bitmap]::new([int]$rectangle.Width,[int]$rectangle.Height); $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.CopyFromScreen([int]$rectangle.X,[int]$rectangle.Y,0,0,$bitmap.Size); $bitmap.Save((Join-Path $OutputDir ("reset-details-$language.png")),[Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bitmap.Dispose() }
        Stop-Process -Id $ui.Id -Force
        $ui.WaitForExit(10000) | Out-Null
    }
    Stop-Process -Id $uiService.Id -Force
    Start-Installed
    $uninstaller = Join-Path $installDir 'unins000.exe'
    $uninstall = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="' + (Join-Path $OutputDir 'uninstall.log') + '"')) -Wait -PassThru
    Assert-True ($uninstall.ExitCode -eq 0) 'Uninstall failed.'
    $uninstalled = $true
    Assert-True (-not (Test-Path (Join-Path $dataDir 'state.json'))) 'Uninstall left running state.'
    Assert-True (Test-Path (Join-Path $dataDir 'settings.json')) 'Uninstall lost language preference.'
    Assert-True (Test-Path (Join-Path $dataDir 'window.json')) 'Uninstall lost window geometry.'
    Assert-True (-not (Test-Path (Join-Path $installDir 'CodexQuotaWidget.exe'))) 'Uninstall left application payload.'
    Assert-True (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Quota Widget.lnk'))) 'Uninstall left Start Menu shortcut.'
    Assert-True (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Codex Quota Widget.lnk'))) 'Uninstall left desktop shortcut.'
    Write-Output 'PASS Windows install, bundled startup, health, fixture quota, localization, reopen, upgrade/reinstall, quit, uninstall and preference preservation'
    Write-Output "Fabricated native screenshots: $OutputDir"
} finally {
    foreach ($process in $testProcesses) { try { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null } } catch { } }
    if (-not $uninstalled -and (Test-Path (Join-Path $installDir 'Stop.ps1'))) {
        try { & (Join-Path $installDir 'Stop.ps1') -Quiet | Out-Null } catch { }
        if (Test-Path (Join-Path $installDir 'unins000.exe')) { try { Start-Process -FilePath (Join-Path $installDir 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait | Out-Null } catch { } }
    }
    $env:LOCALAPPDATA=$savedLocal; $env:TEMP=$savedTemp; $env:TMP=$savedTmp; $env:PATH=$savedPath; $env:CODEX_CLI_PATH=$savedCli; $env:QUOTA_SMOKE_MODE_FILE=$savedModeFile
}
