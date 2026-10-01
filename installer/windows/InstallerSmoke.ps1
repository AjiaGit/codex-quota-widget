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
$savedPidFile = $env:QUOTA_SMOKE_PID_FILE; $savedWrapperPidFile = $env:QUOTA_SMOKE_WRAPPER_PID_FILE
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
function Read-UiText($element) {
    [object]$pattern = $null
    if ($element.TryGetCurrentPattern([Windows.Automation.TextPattern]::Pattern, [ref]$pattern)) {
        return ([Windows.Automation.TextPattern]$pattern).DocumentRange.GetText(-1)
    }
    $pattern = $null
    if ($element.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern, [ref]$pattern)) {
        return ([Windows.Automation.ValuePattern]$pattern).Current.Value
    }
    return $null
}
function Save-UiEvidence($element, [string]$language, [string]$phase) {
    # Only call for windows belonging to the completely fabricated local UI fixture.
    try {
        $rectangle = $element.Current.BoundingRectangle
        if ($rectangle.Width -gt 0 -and $rectangle.Height -gt 0) {
            $bitmap = [Drawing.Bitmap]::new([int]$rectangle.Width, [int]$rectangle.Height)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.CopyFromScreen([int]$rectangle.X, [int]$rectangle.Y, 0, 0, $bitmap.Size)
                $bitmap.Save((Join-Path $OutputDir ("$phase-$language.png")), [Drawing.Imaging.ImageFormat]::Png)
            } finally { $graphics.Dispose(); $bitmap.Dispose() }
        }
    } catch { Write-Output "UI screenshot unavailable: $phase / $language" }
    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($control in @($element) + @($element.FindAll([Windows.Automation.TreeScope]::Descendants, [Windows.Automation.Condition]::TrueCondition))) {
        try {
            $current = $control.Current
            $text = try { Read-UiText $control } catch { $null }
            $rows.Add([pscustomobject]@{
                name = $current.Name; controlType = $current.ControlType.ProgrammaticName
                className = $current.ClassName; automationId = $current.AutomationId
                frameworkId = $current.FrameworkId; nativeHandle = $current.NativeWindowHandle
                isOffscreen = $current.IsOffscreen
                patterns = @($control.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
                actualText = $text
            })
        } catch { }
    }
    $nativeEdit = $null
    try {
        $snapshot = [QuotaSmokeWindows]::ReadOwnedEdit([IntPtr]$element.Current.NativeWindowHandle, $ui.Id)
        if ($snapshot) {
            $nativeEdit = @{
                nativeHandle = $snapshot.Handle.ToInt64(); className = $snapshot.ClassName
                style = ('0x{0:X8}' -f $snapshot.Style); actualText = $snapshot.Text
            }
        }
    } catch { }
    Write-WidgetJson (Join-Path $OutputDir ("ui-trace-$phase-$language.json")) @{
        phase = $phase; language = $language; capturedAt = [DateTimeOffset]::UtcNow.ToString('o')
        controls = $rows.ToArray(); nativeEdit = $nativeEdit
    }
    $summary = @($rows | ForEach-Object { "$($_.controlType) [$($_.className)] patterns=$($_.patterns -join ',')" }) -join '; '
    Write-Output "Fabricated UI provider trace ($phase / $language): $summary"
}
function Assert-NoFixtureProcesses([string]$phase) {
    Wait-Until {
        @(Get-CimInstance Win32_Process -Filter "Name='codex.exe'" -ErrorAction SilentlyContinue | Where-Object {
            [string]::Equals([string]$_.ExecutablePath, $nativeFixtureExe, [StringComparison]::OrdinalIgnoreCase)
        }).Count -eq 0
    } "Native Codex fixture left an orphan process $phase" 15
    Assert-True (-not (Test-Path -LiteralPath $env:QUOTA_SMOKE_WRAPPER_PID_FILE)) 'Service used the npm JavaScript wrapper rather than its native executable.'
    $recordedPids = @(Get-Content -LiteralPath $env:QUOTA_SMOKE_PID_FILE | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique)
    Assert-True ($recordedPids.Count -gt 0) 'Native fixture PID records were not generated.'
    foreach ($recordedPid in $recordedPids) {
        $recordedProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$recordedPid" -ErrorAction SilentlyContinue
        Assert-True (-not $recordedProcess -or ($recordedProcess.ExecutablePath -and -not [string]::Equals([string]$recordedProcess.ExecutablePath, $nativeFixtureExe, [StringComparison]::OrdinalIgnoreCase))) "Recorded native fixture PID $recordedPid remained $phase"
    }
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
    $env:QUOTA_SMOKE_PID_FILE = Join-Path $fixtureRoot 'native-pids.txt'
    $env:QUOTA_SMOKE_WRAPPER_PID_FILE = Join-Path $fixtureRoot 'wrapper-pids.txt'
    $nativeDirectory = Join-Path $fixtureRoot 'node_modules/@openai/codex-win32-x64/vendor/x86_64-pc-windows-msvc/bin'
    [void][IO.Directory]::CreateDirectory($nativeDirectory)
    $nativeFixtureExe = Join-Path $nativeDirectory 'codex.exe'
    $fixtureSource = Join-Path $fixtureRoot 'FakeCodex.cs'
    $nativeFixture = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Web.Script.Serialization;
internal static class FakeCodex {
    private static int Main(string[] args) {
        if (args.Length != 1 || args[0] != "app-server") return 41;
        File.AppendAllText(Environment.GetEnvironmentVariable("QUOTA_SMOKE_PID_FILE"), Process.GetCurrentProcess().Id + "\n");
        Console.InputEncoding = new System.Text.UTF8Encoding(false);
        Console.OutputEncoding = new System.Text.UTF8Encoding(false);
        if (File.ReadAllText(Environment.GetEnvironmentVariable("QUOTA_SMOKE_MODE_FILE")).Trim() == "timeout") {
            Thread.Sleep(Timeout.Infinite);
            return 0;
        }
        var serializer = new JavaScriptSerializer();
        long now = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc)).TotalSeconds;
        string line;
        while ((line = Console.ReadLine()) != null) {
            var request = (Dictionary<string, object>)serializer.DeserializeObject(line);
            string method = (string)request["method"];
            if (method == "initialized") continue;
            object id = request["id"];
            object result;
            if (method == "initialize") result = new Dictionary<string, object>();
            else if (method == "account/rateLimits/read") result = new {
                rateLimits = new {
                    primary = new { usedPercent = 61, windowDurationMins = 10080, resetsAt = now + 3600 * 72 },
                    secondary = new { usedPercent = 25, windowDurationMins = 300, resetsAt = now + 3600 }
                },
                rateLimitResetCredits = new {
                    availableCount = 2,
                    credits = new[] { new {
                        id = "fixture-id-must-never-be-shown", title = "Sample grant / 示例发放", description = "Fabricated test data / 虚构测试数据",
                        grantedAt = now - 86400, expiresAt = now + 86400
                    } }
                }
            };
            else if (method == "account/read") result = File.ReadAllText(Environment.GetEnvironmentVariable("QUOTA_SMOKE_MODE_FILE")).Trim() == "signed_out"
                ? (object)new { account = (object)null, requiresOpenaiAuth = true }
                : (object)new { account = new { type = "chatgpt", planType = "plus" }, requiresOpenaiAuth = true };
            else return 42;
            Console.WriteLine(serializer.Serialize(new { id = id, result = result }));
            Console.Out.Flush();
        }
        // Deliberately remain alive after stdin closes: killing only an npm
        // JavaScript wrapper would leave this native child behind.
        Thread.Sleep(Timeout.Infinite);
        return 0;
    }
}
'@
    [IO.File]::WriteAllText($fixtureSource, $nativeFixture, [Text.UTF8Encoding]::new($true))
    $csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework/v4.0.30319/csc.exe' }
    & $csc /nologo /target:exe /platform:x64 ('/out:' + $nativeFixtureExe) /reference:System.Web.Extensions.dll $fixtureSource
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $nativeFixtureExe)) 'Native RPC fixture compilation failed.'
    # Models the upstream npm wrapper's child-process structure. The service
    # must discover the optional package binary and bypass this wrapper.
    $fixture = @'
const {spawn}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
fs.appendFileSync(process.env.QUOTA_SMOKE_WRAPPER_PID_FILE,process.pid+'\n');
const native=path.join(__dirname,'..','..','codex-win32-x64','vendor','x86_64-pc-windows-msvc','bin','codex.exe');
const child=spawn(native,process.argv.slice(2),{stdio:'inherit',windowsHide:true});
for(const signal of ['SIGINT','SIGTERM','SIGHUP'])process.on(signal,()=>child.kill(signal));
child.on('exit',(code)=>process.exit(code??1));
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
    Assert-True (Test-Path -LiteralPath $env:QUOTA_SMOKE_PID_FILE) 'Native fixture was not executed.'
    Assert-NoFixtureProcesses 'after a successful quota query'
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
    [IO.File]::WriteAllText($env:QUOTA_SMOKE_MODE_FILE, 'timeout')
    try {
        $timedOut = Invoke-RestMethod "$serviceUrl/api/refresh" -Method Post -TimeoutSec 35
        Assert-True ($timedOut.errorCode -eq 'timeout') 'Hung native CLI did not report the timeout state.'
        Assert-NoFixtureProcesses 'after the native query timed out'
    } finally { [IO.File]::WriteAllText($env:QUOTA_SMOKE_MODE_FILE, 'ok') }
    [void](Invoke-RestMethod "$serviceUrl/api/refresh" -Method Post -TimeoutSec 30)
    # Upgrade while owned processes are running; the installer must stop them before copying.
    $preferences = Read-WidgetJson (Join-Path $dataDir 'window.json')
    if ($UpgradeInstaller) { Install-Widget $UpgradeInstaller 'upgrade.log' }
    else { Install-Widget $Installer 'reinstall.log' }
    Assert-True ((Read-WidgetJson (Join-Path $dataDir 'settings.json')).language -eq 'zh-CN') 'Upgrade lost language.'
    Assert-True ((Read-WidgetJson (Join-Path $dataDir 'window.json')).detailWidth -eq $preferences.detailWidth) 'Upgrade lost geometry.'
    Start-Installed
    Stop-Installed
    Assert-NoFixtureProcesses 'after quitting the monitor'
    Assert-True (Test-Path (Join-Path $dataDir 'settings.json')) 'Quit deleted preferences.'
    # Completely fabricated native screenshots use a local fixture, including external data.
    $uiFixturePath = Join-Path $fixtureRoot 'ui-fixture.js'
    $uiFixture = @'
const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const settingsFile=path.join(process.env.LOCALAPPDATA,'CodexWeeklyMonitor','settings.json');
const refreshFile=path.join(__dirname,'ui-refreshes.txt');
const fixtureNow=Date.now(),sourceUpdatedAt=fixtureNow-180000;
const completed={id:'fixture-announcement-regular-id',kind:'regular',announcedAt:new Date(fixtureNow-86400000).toISOString(),scheduledAt:new Date(fixtureNow-3600000).toISOString(),scheduledDate:null,deliveredAt:new Date(fixtureNow-600000).toISOString(),scope:'all',scopeLabel:null,sourceUrl:'https://example.org/regular-announcement',deliverySourceUrl:'https://example.org/regular-delivery',summary:'Confirmed public reset delivery record',summaryZh:'已确认全局临时重置送达记录'};
http.createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');
  if(req.url==='/api/settings') {
    if(req.method==='POST'){let text='';for await(const chunk of req)text+=chunk;fs.writeFileSync(settingsFile,text);res.end(text);}
    else res.end(fs.readFileSync(settingsFile,'utf8'));
  } else if(req.url==='/api/external') {
    const now=fixtureNow;
    res.end(JSON.stringify({status:'ok',lastGlobal:null,forecast:{next24h:12,next48h:25,next7d:61,sourceUpdatedAt:new Date(now).toISOString()},announcements:{status:'ok',stale:false,sourceUpdatedAt:new Date(now).toISOString(),history:[completed],items:[
      {id:'fixture-announcement-banked-id',kind:'banked',announcedAt:new Date(now-86400000).toISOString(),scheduledAt:new Date(now+86400000).toISOString(),scheduledDate:null,deliveredAt:null,scope:'paid',scopeLabel:null,sourceUrl:'https://example.org/banked-announcement',deliverySourceUrl:null,summary:'Confirmed credit grant for paid accounts',summaryZh:'已确认向付费账号赠送重置卡'},
      completed
    ]}}));
  }
  else {if(req.url==='/api/refresh'&&req.method==='POST')fs.appendFileSync(refreshFile,'1\n');const now=Math.floor(fixtureNow/1000);res.end(JSON.stringify({status:'ok',plan:'plus',remainingPercent:39,resetsAt:now+259200,updatedAt:sourceUpdatedAt,resetCards:2,resetDetails:[{title:'Sample grant / 示例发放',description:'Fabricated test data / 虚构测试数据',grantedAt:now-86400,expiresAt:now+86400}],fiveHour:{remainingPercent:75,resetsAt:now+3600}}));}
}).listen(39225,'127.0.0.1');
'@
    [IO.File]::WriteAllText($uiFixturePath, $uiFixture, [Text.UTF8Encoding]::new($false))
    $uiService = Start-Process -FilePath (Join-Path $installDir 'runtime/node.exe') -ArgumentList ('"'+$uiFixturePath+'"') -PassThru -WindowStyle Hidden
    $testProcesses.Add($uiService)
    Wait-Until { (Invoke-RestMethod 'http://127.0.0.1:39225/api/usage' -TimeoutSec 1).status -eq 'ok' } 'UI fixture failed.'
    $uiExpected=Invoke-RestMethod 'http://127.0.0.1:39225/api/external' -TimeoutSec 3
    $uiExpectedQuota=Invoke-RestMethod 'http://127.0.0.1:39225/api/usage' -TimeoutSec 3
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic;
public static class QuotaSmokeWindows {
    private delegate bool EnumProc(IntPtr hWnd, IntPtr param);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr param);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumProc callback, IntPtr param);
    [StructLayout(LayoutKind.Sequential)] public struct WindowBounds {
        public int Left, Top, Right, Bottom;
        public int Width { get { return Right-Left; } }
        public int Height { get { return Bottom-Top; } }
    }
    public sealed class HeaderButton { public IntPtr Handle; public WindowBounds Bounds; }
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out WindowBounds bounds);
    [DllImport("user32.dll")] private static extern bool IsChild(IntPtr parent, IntPtr child);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW", ExactSpelling=true)] private static extern int GetWindowStyle(IntPtr hWnd, int index);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", EntryPoint="SendMessageW", CharSet=CharSet.Unicode, ExactSpelling=true)] private static extern IntPtr SendMessageText(IntPtr hWnd, uint msg, IntPtr wParam, StringBuilder text);
    public sealed class EditSnapshot {
        public IntPtr Handle;
        public string ClassName;
        public uint Style;
        public string Text;
    }
    private static bool IsOwned(IntPtr window, int pid) {
        uint owner;
        return window != IntPtr.Zero && GetWindowThreadProcessId(window, out owner) != 0 && owner == (uint)pid;
    }
    public static EditSnapshot ReadOwnedEdit(IntPtr parent, int pid) {
        if (!IsOwned(parent, pid)) return null;
        EditSnapshot result = null;
        EnumChildWindows(parent, delegate(IntPtr child, IntPtr unused) {
            if (!IsChild(parent, child) || !IsOwned(child, pid)) return true;
            var name = new StringBuilder(256);
            GetClassName(child, name, name.Capacity);
            if (!name.ToString().StartsWith("WindowsForms10.EDIT.", StringComparison.OrdinalIgnoreCase)) return true;
            // WM_GETTEXT is marshalled by Windows for this owned child control;
            // GetWindowText cannot reliably read another process's edit text.
            long length = SendMessage(child, 0x000E, IntPtr.Zero, IntPtr.Zero).ToInt64();
            if (length < 0 || length > 1024 * 1024) return true;
            var text = new StringBuilder((int)length + 1);
            SendMessageText(child, 0x000D, new IntPtr(text.Capacity), text);
            result = new EditSnapshot {
                Handle = child, ClassName = name.ToString(),
                Style = unchecked((uint)GetWindowStyle(child, -16)), Text = text.ToString()
            };
            return false;
        }, IntPtr.Zero);
        return result;
    }
    public static WindowBounds OwnedBounds(IntPtr window, int pid) {
        WindowBounds bounds;
        if (!IsOwned(window,pid) || !GetWindowRect(window,out bounds)) throw new InvalidOperationException("Unowned fixture window");
        return bounds;
    }
    public static HeaderButton[] Toolbar(IntPtr parent, int pid) {
        var root=OwnedBounds(parent,pid);
        var found=new List<HeaderButton>();
        EnumChildWindows(parent,delegate(IntPtr child,IntPtr unused) {
            if (!IsChild(parent,child) || !IsOwned(child,pid)) return true;
            var name=new StringBuilder(256); GetClassName(child,name,name.Capacity);
            WindowBounds bounds;
            if (IsWindowVisible(child) && name.ToString().StartsWith("WindowsForms10.BUTTON.",StringComparison.OrdinalIgnoreCase) && GetWindowRect(child,out bounds)
                && bounds.Top >= root.Top && bounds.Bottom <= root.Top+54) found.Add(new HeaderButton {Handle=child,Bounds=bounds});
            return true;
        },IntPtr.Zero);
        found.Sort(delegate(HeaderButton a,HeaderButton b) {return a.Bounds.Left.CompareTo(b.Bounds.Left);});
        return found.ToArray();
    }
    public static IntPtr ScrollBody(IntPtr parent, int pid) {
        if (!IsOwned(parent,pid)) return IntPtr.Zero;
        IntPtr result=IntPtr.Zero;
        EnumChildWindows(parent,delegate(IntPtr child,IntPtr unused) {
            if (!IsChild(parent,child) || !IsOwned(child,pid)) return true;
            var name=new StringBuilder(256); GetClassName(child,name,name.Capacity);
            if (name.ToString().StartsWith("WindowsForms10.Window.",StringComparison.OrdinalIgnoreCase)
                && (unchecked((uint)GetWindowStyle(child,-16)) & 0x00200000) != 0) {result=child;return false;}
            return true;
        },IntPtr.Zero); return result;
    }
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
        # Screenshots must contain only the completely fabricated UI response.
        Remove-Item -LiteralPath (Join-Path $dataDir 'native-public-cache.json') -ErrorAction SilentlyContinue
        [void](Invoke-RestMethod 'http://127.0.0.1:39225/api/settings' -Method Post -ContentType 'application/json' -Body ('{"language":"'+$language+'"}'))
        $ui = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList @('-NoProfile','-Sta','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+(Join-Path $installDir 'Floating.ps1')+'"'),'-BaseUrl','http://127.0.0.1:39225') -PassThru -WindowStyle Hidden
        $testProcesses.Add($ui)
        $title = Get-WidgetText 'app' $language
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$title) -ne [IntPtr]::Zero } "Localized native window missing: $language"
        $handle = [QuotaSmokeWindows]::Find($ui.Id,$title)
        [void][QuotaSmokeWindows]::SetForegroundWindow($handle)
        $element = [Windows.Automation.AutomationElement]::FromHandle($handle)
        $creditText = Get-WidgetText 'creditDetailsRow' $language @((Get-WidgetText 'cards' $language @(2)))
        $creditCondition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$creditText)
        Wait-Until { $null -ne $element.FindFirst([Windows.Automation.TreeScope]::Descendants,$creditCondition) } "Native quota failed to render: $language"
        $labels = $element.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
        $names = @($labels | ForEach-Object { $_.Current.Name }) -join "`n"
        Assert-True ($names.Contains((Get-WidgetText 'fiveHour' $language))) "5-hour title untranslated: $language"
        Assert-True (-not $names.Contains('fixture-id-must-never-be-shown') -and -not $names.Contains('fixture-announcement-banked-id') -and -not $names.Contains('fixture-announcement-regular-id')) 'Native UI leaked an ID.'
        Wait-Until {
            $script:layoutNames=@($element.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition) | ForEach-Object {$_.Current.Name}) -join "`n"
            $script:layoutNames.Contains((Get-WidgetText 'confirmedBanked' $language)) -and $script:layoutNames.Contains((Get-WidgetText 'confirmedRegular' $language))
        } "Confirmed announcement rows did not render: $language"
        Save-UiEvidence $element $language 'native'
        Assert-True ($script:layoutNames -match $(if ($language -eq 'en') {'Updated \d+ minutes ago'} else {'\d+分钟前更新'})) 'Header used paint time instead of quota source age.'
        $completedExpected=@($uiExpected.announcements.items | Where-Object {$_.kind -eq 'regular'})[0]
        $plannedText=Get-WidgetText 'originalScheduled' $language @((Format-WidgetDate ([DateTimeOffset]$completedExpected.scheduledAt) $language))
        $completedText=Get-WidgetText 'deliveredOn' $language @((Format-WidgetDate ([DateTimeOffset]$completedExpected.deliveredAt) $language))
        Assert-True ($script:layoutNames.Contains($plannedText) -and $script:layoutNames.Contains($completedText) -and $script:layoutNames.Contains((Get-WidgetText 'all' $language))) 'Completed announcement omitted original plan, completion timestamp or scope.'
        $displayedNames=@($element.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition) | ForEach-Object {$_.Current.Name})
        Assert-True (@($displayedNames | Where-Object {$_ -ceq (Get-WidgetText 'confirmedRegular' $language)}).Count -eq 1) 'Service active/history duplicate hid or duplicated the completed announcement.'
        Assert-True ($script:layoutNames.Contains((Get-WidgetText 'announcementSource' $language)) -and $script:layoutNames.Contains((Get-WidgetText 'deliverySource' $language))) 'Announcement or delivery record link missing.'
        $fiveExpected=Get-WidgetFiveHourView $uiExpectedQuota $language
        Assert-True ($script:layoutNames.Contains($fiveExpected.percentText) -and $script:layoutNames.Contains($fiveExpected.resetText)) 'Plus five-hour percentage or reset time missing.'
        Assert-True ($script:layoutNames.Contains((Get-WidgetText 'sourceLinks' $language)) -and $script:layoutNames.Contains((Get-WidgetText 'refreshCadence' $language))) 'Source links or separate quota/public cadence missing.'
        $buttons=@([QuotaSmokeWindows]::Toolbar($handle,$ui.Id))
        Assert-True ($buttons.Count -eq 3) 'Fixed header did not contain exactly three icon buttons.'
        foreach ($button in $buttons) { Assert-True ($button.Bounds.Width -eq 32 -and $button.Bounds.Height -eq 32) 'Toolbar hit targets were inconsistent.' }
        $beforeRefresh=if (Test-Path (Join-Path $fixtureRoot 'ui-refreshes.txt')) {[IO.File]::ReadAllText((Join-Path $fixtureRoot 'ui-refreshes.txt')).Length} else {0}
        [void][QuotaSmokeWindows]::SendMessage($buttons[0].Handle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
        Wait-Until { [IO.File]::ReadAllText((Join-Path $fixtureRoot 'ui-refreshes.txt')).Length -gt $beforeRefresh } 'First toolbar icon did not refresh quota.'
        $scrollBody=[QuotaSmokeWindows]::ScrollBody($handle,$ui.Id)
        Assert-True ($scrollBody -ne [IntPtr]::Zero) 'Two announcements and Plus quota did not have a scrollable body.'
        $oddsControls=@()
        foreach ($percent in @('12%','25%','61%')) {
            $condition=[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$percent)
            $oddsControl=$element.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
            Assert-True ($null -ne $oddsControl) 'Permanent probability column was missing.'
            $oddsControls+=,[QuotaSmokeWindows]::OwnedBounds([IntPtr]$oddsControl.Current.NativeWindowHandle,$ui.Id)
        }
        Assert-True ($oddsControls[0].Top -eq $oddsControls[1].Top -and $oddsControls[1].Top -eq $oddsControls[2].Top -and $oddsControls[0].Right -le $oddsControls[1].Left -and $oddsControls[1].Right -le $oddsControls[2].Left) 'Probability columns overlapped or stacked.'
        $footerBounds=@()
        foreach ($text in @((Get-WidgetText 'sourceLinks' $language),(Get-WidgetText 'refreshCadence' $language))) {
            $condition=[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$text)
            $control=$element.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
            Assert-True ($null -ne $control) 'Readable footer line was missing.'
            $footerBounds+=,[QuotaSmokeWindows]::OwnedBounds([IntPtr]$control.Current.NativeWindowHandle,$ui.Id)
        }
        Assert-True ($footerBounds[0].Bottom -le $footerBounds[1].Top) 'Source links and refresh cadence overlapped instead of using separate lines.'
        $noteCondition=[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,(Get-WidgetText 'oddsNote' $language))
        $noteElement=$element.FindFirst([Windows.Automation.TreeScope]::Descendants,$noteCondition)
        Assert-True ($null -ne $noteElement) 'Historical estimate explanation missing.'
        $noteBounds=[QuotaSmokeWindows]::OwnedBounds([IntPtr]$noteElement.Current.NativeWindowHandle,$ui.Id)
        Assert-True ($oddsControls[0].Bottom -le $noteBounds.Top -and $noteBounds.Bottom -le $footerBounds[0].Top) 'Estimate explanation was not below probability and before the source footer.'
        [void][QuotaSmokeWindows]::SendMessage($scrollBody,0x115,[IntPtr]7,[IntPtr]::Zero)
        Save-UiEvidence $element $language 'native-content-bottom'
        [void][QuotaSmokeWindows]::SendMessage($scrollBody,0x115,[IntPtr]6,[IntPtr]::Zero)
        # Click the disclosure portion of the merged credit row.
        $creditElement = $element.FindFirst([Windows.Automation.TreeScope]::Descendants,$creditCondition)
        $creditHandle = [IntPtr]$creditElement.Current.NativeWindowHandle
        $fontHandle=[QuotaSmokeWindows]::SendMessage($creditHandle,0x31,[IntPtr]::Zero,[IntPtr]::Zero)
        $linkFont=if ($fontHandle -ne [IntPtr]::Zero) {[Drawing.Font]::FromHfont($fontHandle)} else {[Drawing.Font]::new('Segoe UI',10.5)}
        try {
            $prefix=$creditText.Substring(0,$creditText.IndexOf(' · ')+3)
            $linkX=[Windows.Forms.TextRenderer]::MeasureText($prefix,$linkFont).Width+4
        } finally {$linkFont.Dispose()}
        $linkPoint=[IntPtr]((10 -shl 16) -bor $linkX)
        # LinkLabel activates the link hit by WM_MOUSEMOVE before mouse-down;
        # a down/up pair alone never puts its link into the Hover state.
        [void][QuotaSmokeWindows]::SendMessage($creditHandle,0x200,[IntPtr]::Zero,$linkPoint)
        [void][QuotaSmokeWindows]::SendMessage($creditHandle,0x201,[IntPtr]1,$linkPoint)
        [void][QuotaSmokeWindows]::SendMessage($creditHandle,0x202,[IntPtr]0,$linkPoint)
        $detailsTitle = Get-WidgetText 'detailsTitle' $language
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$detailsTitle) -ne [IntPtr]::Zero } "Reset details window missing: $language"
        $detailsHandle = [QuotaSmokeWindows]::Find($ui.Id,$detailsTitle)
        $detailsElement = [Windows.Automation.AutomationElement]::FromHandle($detailsHandle)
        Assert-True ($null -eq [QuotaSmokeWindows]::ReadOwnedEdit($detailsHandle, 0)) 'Native text reader accepted an unrelated process.'
        Assert-True ($null -eq [QuotaSmokeWindows]::ReadOwnedEdit($handle, $ui.Id)) 'Native text reader escaped the details dialog.'
        Save-UiEvidence $detailsElement $language 'reset-details'
        # Hosted CI can expose every WinForms control as a generic Pane without
        # text patterns. Keep UIA text when available; otherwise read WM_GETTEXT
        # from the EDIT descendant owned by this exact dialog and process.
        $editCondition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Edit)
        $documentCondition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty, [Windows.Automation.ControlType]::Document)
        $textCondition = [Windows.Automation.OrCondition]::new($editCondition, $documentCondition)
        $script:detailValue = $null; $script:detailNative = $null; $script:detailReadMethod = $null
        Wait-Until {
            $script:detailNative = [QuotaSmokeWindows]::ReadOwnedEdit($detailsHandle, $ui.Id)
            if (-not $script:detailNative) { return $false }
            $script:detailValue = try {
                $textControl = $detailsElement.FindFirst([Windows.Automation.TreeScope]::Descendants, $textCondition)
                if ($textControl) { Read-UiText $textControl } else { $null }
            } catch { $null }
            $script:detailReadMethod = 'UIA'
            if ([string]::IsNullOrWhiteSpace($script:detailValue)) {
                $script:detailValue = $script:detailNative.Text
                $script:detailReadMethod = 'Win32 WM_GETTEXT'
            }
            -not [string]::IsNullOrWhiteSpace($script:detailValue)
        } "Owned reset details textbox did not expose readable text: $language" 15
        # ES_MULTILINE | ES_READONLY | WS_VSCROLL proves this is the actual
        # scrollable, read-only native text area, regardless of the UIA proxy.
        $requiredStyles = [uint32]0x00200804
        Assert-True (($script:detailNative.Style -band $requiredStyles) -eq $requiredStyles) 'Reset details textbox was not multiline, read-only and vertically scrollable.'
        Write-Output ("Fabricated reset details text ($language): $($script:detailReadMethod), $($script:detailNative.ClassName), style=0x{0:X8}" -f $script:detailNative.Style)
        $detailValue = $script:detailValue
        $expectedCount = if ($language -eq 'en') { 'Available reset credits: 2' } else { '可用重置卡：2张' }
        $expectedGrant = if ($language -eq 'en') { 'Granted:' } else { '发放：' }
        $expectedExpiry = if ($language -eq 'en') { 'Expires:' } else { '到期：' }
        Assert-True ($detailValue.Contains($expectedCount)) 'Reset details changed authoritative count.'
        Assert-True ($detailValue.Contains($expectedGrant) -and $detailValue.Contains($expectedExpiry)) 'Grant or expiry fields were not localized.'
        Assert-True (-not $detailValue.Contains('fixture-id-must-never-be-shown')) 'Reset details exposed an ID.'
        Save-UiEvidence $detailsElement $language 'reset-details'
        [void][QuotaSmokeWindows]::SendMessage($detailsHandle,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
        [void][QuotaSmokeWindows]::SendMessage($buttons[1].Handle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
        Wait-Until { [QuotaSmokeWindows]::OwnedBounds($handle,$ui.Id).Width -le 160 } 'Dash did not return to the compact widget.'
        Start-Sleep -Milliseconds 300 # Let the existing 260ms transition finish before clicking the compact surface.
        [void][QuotaSmokeWindows]::SendMessage($handle,0x201,[IntPtr]1,[IntPtr]0x001A001A)
        [void][QuotaSmokeWindows]::SendMessage($handle,0x202,[IntPtr]::Zero,[IntPtr]0x001A001A)
        Wait-Until { [QuotaSmokeWindows]::OwnedBounds($handle,$ui.Id).Width -ge 404 -and @([QuotaSmokeWindows]::Toolbar($handle,$ui.Id)).Count -eq 3 } 'Compact click did not restore the detail window.'
        $buttons=@([QuotaSmokeWindows]::Toolbar($handle,$ui.Id))
        [void][QuotaSmokeWindows]::SendMessage($buttons[2].Handle,0xF5,[IntPtr]::Zero,[IntPtr]::Zero)
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$title) -eq [IntPtr]::Zero } 'X did not hide the widget.'
        Assert-True (-not $ui.HasExited) 'Hide terminated the native widget process.'
        [IO.File]::WriteAllText((Join-Path $dataDir 'show.request'),'')
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$title) -ne [IntPtr]::Zero } 'Hidden widget did not reopen.'
        Save-UiEvidence ([Windows.Automation.AutomationElement]::FromHandle($handle)) $language 'native-restored'
        Stop-Process -Id $ui.Id -Force
        $ui.WaitForExit(10000) | Out-Null
    }
    Stop-Process -Id $uiService.Id -Force
    Start-Installed
    $uninstaller = Join-Path $installDir 'unins000.exe'
    $uninstall = Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="' + (Join-Path $OutputDir 'uninstall.log') + '"')) -Wait -PassThru
    Assert-True ($uninstall.ExitCode -eq 0) 'Uninstall failed.'
    $uninstalled = $true
    Assert-NoFixtureProcesses 'after uninstall'
    Assert-True (-not (Test-Path (Join-Path $dataDir 'state.json'))) 'Uninstall left running state.'
    Assert-True (Test-Path (Join-Path $dataDir 'settings.json')) 'Uninstall lost language preference.'
    Assert-True (Test-Path (Join-Path $dataDir 'window.json')) 'Uninstall lost window geometry.'
    Assert-True (-not (Test-Path (Join-Path $installDir 'CodexQuotaWidget.exe'))) 'Uninstall left application payload.'
    Assert-True (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Codex Quota Widget.lnk'))) 'Uninstall left Start Menu shortcut.'
    Assert-True (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Codex Quota Widget.lnk'))) 'Uninstall left desktop shortcut.'
    Write-Output 'PASS Windows install, bundled startup, health, fixture quota, localization, reopen, upgrade/reinstall, quit, uninstall and preference preservation'
    Write-Output "Fabricated native screenshots: $OutputDir"
} catch {
    $failure = $_
    if ($ui -and $language -and ('QuotaSmokeWindows' -as [type])) {
        foreach ($entry in @(@('app','native-failure'), @('detailsTitle','reset-details-failure'))) {
            try {
                $failureHandle = [QuotaSmokeWindows]::Find($ui.Id, (Get-WidgetText $entry[0] $language))
                if ($failureHandle -ne [IntPtr]::Zero) {
                    Save-UiEvidence ([Windows.Automation.AutomationElement]::FromHandle($failureHandle)) $language $entry[1]
                }
            } catch { }
        }
    }
    throw $failure
} finally {
    foreach ($process in $testProcesses) { try { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null } } catch { } }
    if (-not $uninstalled -and (Test-Path (Join-Path $installDir 'Stop.ps1'))) {
        try { & (Join-Path $installDir 'Stop.ps1') -Quiet | Out-Null } catch { }
        if (Test-Path (Join-Path $installDir 'unins000.exe')) { try { Start-Process -FilePath (Join-Path $installDir 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait | Out-Null } catch { } }
    }
    if ($nativeFixtureExe) {
        foreach ($native in @(Get-CimInstance Win32_Process -Filter "Name='codex.exe'" -ErrorAction SilentlyContinue | Where-Object { [string]::Equals([string]$_.ExecutablePath, $nativeFixtureExe, [StringComparison]::OrdinalIgnoreCase) })) {
            Stop-Process -Id ([int]$native.ProcessId) -Force -ErrorAction SilentlyContinue
        }
    }
    $env:QUOTA_SMOKE_PID_FILE=$savedPidFile; $env:QUOTA_SMOKE_WRAPPER_PID_FILE=$savedWrapperPidFile
    $env:LOCALAPPDATA=$savedLocal; $env:TEMP=$savedTemp; $env:TMP=$savedTmp; $env:PATH=$savedPath; $env:CODEX_CLI_PATH=$savedCli; $env:QUOTA_SMOKE_MODE_FILE=$savedModeFile
}
