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
    [DllImport("user32.dll")] private static extern IntPtr GetParent(IntPtr window);
    public sealed class ControlSnapshot {
        public IntPtr Handle, ParentHandle;
        public string ClassName, Text;
        public bool Visible;
        public WindowBounds Bounds;
    }
    private static bool IsOwned(IntPtr window, int pid) {
        uint owner;
        return window != IntPtr.Zero && GetWindowThreadProcessId(window, out owner) != 0 && owner == (uint)pid;
    }
    public static ControlSnapshot[] ReadOwnedControls(IntPtr parent, int pid) {
        var found = new List<ControlSnapshot>();
        if (!IsOwned(parent, pid)) return found.ToArray();
        EnumChildWindows(parent, delegate(IntPtr child, IntPtr unused) {
            if (!IsChild(parent, child) || !IsOwned(child, pid)) return true;
            var name = new StringBuilder(256); GetClassName(child, name, name.Capacity);
            // Hosted CI can expose WinForms controls as generic UIA Panes.
            // Read their actual captions, restricted to this fixture subtree.
            long length = SendMessage(child, 0x000E, IntPtr.Zero, IntPtr.Zero).ToInt64();
            if (length < 0 || length > 1024 * 1024) throw new InvalidOperationException("Invalid fixture caption length");
            var caption = new StringBuilder((int)length + 1);
            SendMessageText(child, 0x000D, new IntPtr(caption.Capacity), caption);
            WindowBounds bounds;
            if (!GetWindowRect(child, out bounds)) throw new InvalidOperationException("Fixture control has no bounds");
            found.Add(new ControlSnapshot {
                Handle = child, ParentHandle = GetParent(child), ClassName = name.ToString(),
                Text = caption.ToString(), Visible = IsWindowVisible(child), Bounds = bounds
            });
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
    public static void ClickOwnedButton(IntPtr parent, IntPtr button, int pid) {
        var name = new StringBuilder(256); GetClassName(button, name, name.Capacity);
        if (!IsOwned(parent, pid) || !IsOwned(button, pid) || !IsChild(parent, button)
            || !IsWindowVisible(button) || !name.ToString().StartsWith("WindowsForms10.BUTTON.", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Click escaped the owned visible fixture button");
        SendMessage(button, 0x00F5, IntPtr.Zero, IntPtr.Zero); // BM_CLICK
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
    public static string ReadOwnedDialogText(IntPtr dialog, int pid) {
        if (!IsOwned(dialog,pid)) return null;
        var values=new List<string>();
        EnumChildWindows(dialog,delegate(IntPtr child,IntPtr unused) {
            if (!IsOwned(child,pid) || !IsChild(dialog,child)) return true;
            var text=new StringBuilder(8192); GetWindowText(child,text,text.Capacity);
            if (text.Length>0) values.Add(text.ToString());
            return true;
        },IntPtr.Zero);
        return string.Join(" | ",values.ToArray());
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
$fixtureLaunches=New-Object 'System.Collections.Generic.List[int]'
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
    $fixtureLauncher=Start-Process -FilePath (Join-Path $installDir 'CodexQuotaWidget.exe') -PassThru
    $fixtureLaunches.Add($fixtureLauncher.Id)
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
    # Allow the queued native paint after an asserted disclosure/layout change.
    Start-Sleep -Milliseconds 150
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
    $nativeControls = @([QuotaSmokeWindows]::ReadOwnedControls([IntPtr]$element.Current.NativeWindowHandle, $ui.Id) | ForEach-Object {
        [pscustomobject]@{
            nativeHandle=$_.Handle.ToInt64(); parentHandle=$_.ParentHandle.ToInt64()
            className=$_.ClassName; actualText=$_.Text; visible=$_.Visible; bounds=$_.Bounds
        }
    })
    Write-WidgetJson (Join-Path $OutputDir ("ui-trace-$phase-$language.json")) @{
        phase = $phase; language = $language; capturedAt = [DateTimeOffset]::UtcNow.ToString('o')
        controls = $rows.ToArray(); nativeControls = $nativeControls
    }
    Write-Output "Fabricated UI trace ($phase / $language): UIA controls=$($rows.Count), owned native controls=$($nativeControls.Count)"

}
function Get-VisibleControls([IntPtr]$parent, [int]$processId) {
    @([QuotaSmokeWindows]::ReadOwnedControls($parent,$processId) | Where-Object {$_.Visible})
}
function Get-VisibleText([IntPtr]$parent, [int]$processId) {
    @(Get-VisibleControls $parent $processId | ForEach-Object {$_.Text}) -join "`n"
}
function Find-VisibleControl([IntPtr]$parent, [int]$processId, [string]$caption) {
    $found=@(Get-VisibleControls $parent $processId | Where-Object {$_.Text -ceq $caption})
    Assert-True ($found.Count -eq 1) "Expected one visible fixture control: [$caption]; found $($found.Count)"
    $found[0]
}
function Invoke-UiButton([IntPtr]$window, [IntPtr]$parent, [int]$processId, [string]$caption) {
    $button=Find-VisibleControl $parent $processId $caption
    $scroll=[QuotaSmokeWindows]::ScrollBody($window,$processId)
    if ($scroll -ne [IntPtr]::Zero) {
        # Reveal the real control before activating it, including after relayout.
        $viewport=[QuotaSmokeWindows]::OwnedBounds($scroll,$processId)
        for ($attempt=0; $attempt -lt 200; $attempt++) {
            $bounds=[QuotaSmokeWindows]::OwnedBounds($button.Handle,$processId)
            if ($bounds.Top -ge $viewport.Top -and $bounds.Bottom -le $viewport.Bottom) {break}
            $direction=if ($bounds.Top -lt $viewport.Top) {0} else {1}
            [void][QuotaSmokeWindows]::SendMessage($scroll,0x115,[IntPtr]$direction,[IntPtr]::Zero)
        }
        $bounds=[QuotaSmokeWindows]::OwnedBounds($button.Handle,$processId)
        Assert-True ($bounds.Top -ge $viewport.Top -and $bounds.Bottom -le $viewport.Bottom) "Fixture button could not be scrolled into view: $caption"
    }
    [QuotaSmokeWindows]::ClickOwnedButton($parent,$button.Handle,$processId)
}
function Assert-InlineWindow([IntPtr]$window, [int]$processId, [string]$language) {
    Assert-True ([QuotaSmokeWindows]::Find($processId,(Get-WidgetText 'app' $language)) -eq $window) 'Inline disclosure replaced the main window.'
    Assert-True ([QuotaSmokeWindows]::Find($processId,(Get-WidgetText 'detailsTitle' $language)) -eq [IntPtr]::Zero) 'Inline disclosure opened the obsolete details dialog.'
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
const completed={id:'fixture-announcement-regular-id',kind:'regular',certainty:'announced',announcedAt:new Date(fixtureNow-7200000).toISOString(),scheduledAt:new Date(fixtureNow-3600000).toISOString(),scheduledDate:null,deliveredAt:new Date(fixtureNow-600000).toISOString(),scope:'all',scopeLabel:null,sourceUrl:'https://example.org/regular-announcement',deliverySourceUrl:'https://example.org/regular-delivery',summary:'Confirmed public reset delivery record',summaryZh:'已确认全局额度重置送达记录'};
const earlier={...completed,id:'fixture-earlier-id',kind:'banked',announcedAt:new Date(fixtureNow-172800000).toISOString(),scheduledAt:new Date(fixtureNow-32400000).toISOString(),deliveredAt:new Date(fixtureNow-28800000).toISOString(),sourceUrl:'https://example.org/earlier',deliverySourceUrl:null,summary:'Earlier grant fixture',summaryZh:'较早赠送测试记录'};
const archived={...completed,id:'fixture-history-id',announcedAt:new Date(fixtureNow-345600000).toISOString(),scheduledAt:new Date(fixtureNow-262800000).toISOString(),deliveredAt:new Date(fixtureNow-259200000).toISOString(),sourceUrl:'https://example.org/history',deliverySourceUrl:null,summary:'Historical reset fixture',summaryZh:'历史重置测试记录'};
http.createServer(async(req,res)=>{
  res.setHeader('Content-Type','application/json');
  if(req.url==='/api/settings') {
    if(req.method==='POST'){let text='';for await(const chunk of req)text+=chunk;fs.writeFileSync(settingsFile,text);res.end(text);}
    else res.end(fs.readFileSync(settingsFile,'utf8'));
  } else if(req.url==='/api/external') {
    const now=fixtureNow;
    res.end(JSON.stringify({status:'ok',lastGlobal:null,forecast:{next24h:12,next48h:25,next7d:61,sourceUpdatedAt:new Date(now).toISOString()},announcements:{status:'ok',stale:false,sourceUpdatedAt:new Date(now).toISOString(),history:[completed,archived],items:[
      {id:'fixture-announcement-banked-id',kind:'banked',certainty:'announced',announcedAt:new Date(now-86400000).toISOString(),scheduledAt:new Date(now+86400000).toISOString(),scheduledDate:null,deliveredAt:null,scope:'paid',scopeLabel:null,sourceUrl:'https://example.org/banked-announcement',deliverySourceUrl:null,summary:'Confirmed banked reset grant for paid accounts',summaryZh:'已确认向付费账号赠送重置次数'},
      completed,earlier
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
    foreach ($language in @('en','zh-CN')) {
        # Screenshots must contain only the completely fabricated UI response.
        Remove-Item -LiteralPath (Join-Path $dataDir 'native-public-cache.json') -ErrorAction SilentlyContinue
        [void](Invoke-RestMethod 'http://127.0.0.1:39225/api/settings' -Method Post -ContentType 'application/json' -Body ('{"language":"'+$language+'"}'))
        # Fixed geometry deliberately exercises scrolling without changing the
        # product's default automatic height. This is isolated fixture data.
        Write-WidgetJson (Join-Path $dataDir 'window.json') @{ x=100; y=100; mode='Detail'; compactWidth=52; compactHeight=76; detailWidth=606; detailHeight=460; detailLayoutVersion=5; detailAutoHeight=$false; topMost=$true }
        $uiOut=Join-Path $OutputDir ('native-'+$language+'-stdout.log')
        $uiError=Join-Path $OutputDir ('native-'+$language+'-stderr.log')
        $ui = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList @('-NoProfile','-Sta','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+(Join-Path $installDir 'Floating.ps1')+'"'),'-BaseUrl','http://127.0.0.1:39225') -PassThru -WindowStyle Hidden -RedirectStandardOutput $uiOut -RedirectStandardError $uiError
        $testProcesses.Add($ui)
        $title = Get-WidgetText 'app' $language
        Wait-Until { [QuotaSmokeWindows]::Find($ui.Id,$title) -ne [IntPtr]::Zero } "Localized native window missing: $language"
        $handle = [QuotaSmokeWindows]::Find($ui.Id,$title)
        [void][QuotaSmokeWindows]::SetForegroundWindow($handle)
        $element = [Windows.Automation.AutomationElement]::FromHandle($handle)
        $creditText=if ($language -eq 'en') {'Banked resets 2'} else {'可用重置 2次'}
        $regularTitle=Get-WidgetText 'deliveredResetTitle' $language
        $grantTitle=Get-WidgetText 'deliveredGrantTitle' $language
        $pendingTitle=Get-WidgetText 'upcomingGrantTitle' $language
        $moreText=Get-WidgetText 'moreMessage' $language
        $earlierText=Get-WidgetText 'earlierUpdates' $language @(1)
        $historyText=Get-WidgetText 'announcementHistory' $language
        $sourcesText=Get-WidgetText 'dataSources' $language
        Wait-Until {
            $script:layoutNames=Get-VisibleText $handle $ui.Id
            $script:layoutNames.Contains($creditText) -and $script:layoutNames.Contains($regularTitle) -and $script:layoutNames.Contains($pendingTitle)
        } "Current native quota and announcement rows failed to render: $language"
        Assert-True (@([QuotaSmokeWindows]::ReadOwnedControls($handle,0)).Count -eq 0) 'Native reader accepted an unrelated process.'
        $creditControl=Find-VisibleControl $handle $ui.Id $creditText
        $wrongProcessRejected=$false
        try {[QuotaSmokeWindows]::ClickOwnedButton($handle,$creditControl.Handle,0)} catch {$wrongProcessRejected=$true}
        Assert-True $wrongProcessRejected 'Native click accepted an unrelated process.'
        $wrongSubtreeRejected=$false
        try {[QuotaSmokeWindows]::ClickOwnedButton($creditControl.Handle,$creditControl.Handle,$ui.Id)} catch {$wrongSubtreeRejected=$true}
        Assert-True $wrongSubtreeRejected 'Native click escaped its descendant subtree.'
        Assert-True ($script:layoutNames.Contains((Get-WidgetText 'fiveHour' $language)) -and $script:layoutNames.Contains('75%')) 'Plus five-hour quota was missing or untranslated.'
        $fiveReset=Get-WidgetText 'reset' $language @((Format-WidgetCompactDate ([DateTimeOffset]::FromUnixTimeSeconds([long]$uiExpectedQuota.fiveHour.resetsAt)) $language))
        Assert-True ($script:layoutNames.Contains($fiveReset)) 'Plus five-hour reset time missing.'
        Assert-True ($script:layoutNames -match $(if ($language -eq 'en') {'Updated \d+ minutes ago'} else {'\d+分钟前更新'})) 'Header used paint time instead of quota source age.'
        Assert-True ($script:layoutNames.Contains((Get-WidgetText 'activityHeading' $language)) -and $script:layoutNames.Contains((Get-WidgetLocalTimeNote $language))) 'Activity heading or local timezone note missing.'
        Assert-True ($script:layoutNames.Contains((Get-WidgetText 'refreshCadence' $language))) 'Separate quota/public refresh cadence missing.'
        foreach ($obsolete in @('12%','25%','61%')) {Assert-True (-not $script:layoutNames.Contains($obsolete)) 'Obsolete forecast probability column was rendered.'}
        Assert-True (-not $script:layoutNames.Contains('Sample grant / 示例发放') -and -not $script:layoutNames.Contains($grantTitle) -and -not $script:layoutNames.Contains('codex-resets.com') -and -not $script:layoutNames.Contains('codexreset.dev')) 'A disclosure was expanded by default.'
        Assert-True (@(Get-VisibleControls $handle $ui.Id | Where-Object {$_.Text -ceq $regularTitle}).Count -eq 1) 'Active/history duplication hid or duplicated the recent completed announcement.'
        $completedExpected=@($uiExpected.announcements.items | Where-Object {$_.id -eq 'fixture-announcement-regular-id'})[0]
        $completedText=Get-WidgetText 'deliveredOn' $language @((Format-WidgetCompactDate ([DateTimeOffset]$completedExpected.deliveredAt) $language))
        $completedFact=$completedText+' · '+(Get-WidgetText 'all' $language)
        Assert-True ($script:layoutNames.Contains($completedFact)) 'Recent announcement omitted completion timestamp or account scope.'
        $creditBounds=$creditControl.Bounds
        $activityBounds=(Find-VisibleControl $handle $ui.Id (Get-WidgetText 'activityHeading' $language)).Bounds
        $historyBounds=(Find-VisibleControl $handle $ui.Id $historyText).Bounds
        $sourcesBounds=(Find-VisibleControl $handle $ui.Id $sourcesText).Bounds
        $cadenceBounds=(Find-VisibleControl $handle $ui.Id (Get-WidgetText 'refreshCadence' $language)).Bounds
        Assert-True ($creditBounds.Bottom -le $activityBounds.Top -and $activityBounds.Bottom -le $historyBounds.Top -and $historyBounds.Bottom -le $sourcesBounds.Top -and $sourcesBounds.Bottom -le $cadenceBounds.Top) 'Current detail sections overlapped or changed order.'
        Save-UiEvidence $element $language 'native'
        $buttons=@([QuotaSmokeWindows]::Toolbar($handle,$ui.Id))
        Assert-True ($buttons.Count -eq 3) 'Fixed header did not contain exactly three icon buttons.'
        foreach ($button in $buttons) {Assert-True ($button.Bounds.Width -eq 32 -and $button.Bounds.Height -eq 32) 'Toolbar hit targets were inconsistent.'}
        $beforeRefresh=if (Test-Path (Join-Path $fixtureRoot 'ui-refreshes.txt')) {[IO.File]::ReadAllText((Join-Path $fixtureRoot 'ui-refreshes.txt')).Length} else {0}
        [QuotaSmokeWindows]::ClickOwnedButton($handle,$buttons[0].Handle,$ui.Id)
        Wait-Until {[IO.File]::ReadAllText((Join-Path $fixtureRoot 'ui-refreshes.txt')).Length -gt $beforeRefresh} 'First toolbar icon did not refresh quota.'
        $scrollBody=[QuotaSmokeWindows]::ScrollBody($handle,$ui.Id)
        Assert-True ($scrollBody -ne [IntPtr]::Zero) 'Fixed fixture detail window did not have a scrollable body.'

        # Count and actual grant/expiry fields expand inside the main window.
        Invoke-UiButton $handle $handle $ui.Id $creditText
        Wait-Until {(Get-VisibleText $handle $ui.Id).Contains('Sample grant / 示例发放')} "Inline reset details did not expand: $language"
        Assert-InlineWindow $handle $ui.Id $language
        $grantRow=(Find-VisibleControl $handle $ui.Id 'Sample grant / 示例发放').ParentHandle
        $grantValue=Get-VisibleText $grantRow $ui.Id
        foreach ($field in @(@('grantedAt','grant'),@('expiresAt','expiry'))) {
            $date=Format-WidgetCompactDate ([DateTimeOffset]::FromUnixTimeSeconds([long]$uiExpectedQuota.resetDetails[0].($field[0]))) $language
            Assert-True ($grantValue.Contains((Get-WidgetText $field[1] $language @($date)))) 'Inline grant or expiry field was missing or untranslated.'
        }
        Assert-True ($grantValue.Contains('Fabricated test data / 虚构测试数据') -and (Get-VisibleText $handle $ui.Id).Contains((Get-WidgetText 'detailsPartial' $language))) 'Inline reset details omitted description or authoritative-count explanation.'
        [void](Find-VisibleControl $handle $ui.Id $creditText)
        Save-UiEvidence $element $language 'reset-details-inline'
        Invoke-UiButton $handle $handle $ui.Id $creditText
        Wait-Until {-not (Get-VisibleText $handle $ui.Id).Contains('Sample grant / 示例发放')} 'Inline reset details did not collapse.'
        [void](Find-VisibleControl $handle $ui.Id $creditText)

        # The recent record exposes its original plan and delivery link on demand.
        $recentPanel=(Find-VisibleControl $handle $ui.Id $regularTitle).ParentHandle
        Assert-True (-not (Get-VisibleText $recentPanel $ui.Id).Contains((Get-WidgetText 'deliverySource' $language))) 'Delivery link was expanded by default.'
        Invoke-UiButton $handle $recentPanel $ui.Id $moreText
        $summary=if ($language -eq 'en') {'Confirmed public reset delivery record'} else {'已确认全局额度重置送达记录'}
        Wait-Until {(Get-VisibleText $recentPanel $ui.Id).Contains($summary)} 'Message details did not expand in their record.'
        $plannedText=Get-WidgetText 'originalReset' $language @((Format-WidgetCompactDate ([DateTimeOffset]$completedExpected.scheduledAt) $language))
        $recentText=Get-VisibleText $recentPanel $ui.Id
        Assert-True ($recentText.Contains($plannedText) -and $recentText.Contains($completedFact) -and $recentText.Contains((Get-WidgetText 'announcementSource' $language)) -and $recentText.Contains((Get-WidgetText 'deliverySource' $language))) 'Expanded message omitted original plan, completion, scope or source links.'
        Assert-InlineWindow $handle $ui.Id $language
        Save-UiEvidence $element $language 'message-details-inline'
        Invoke-UiButton $handle $recentPanel $ui.Id $moreText
        Wait-Until {-not (Get-VisibleText $recentPanel $ui.Id).Contains($summary)} 'Message details did not collapse.'

        # One earlier active record and one historical record are distinct from
        # the recent completed record duplicated in the service history feed.
        Invoke-UiButton $handle $handle $ui.Id $earlierText
        Wait-Until {(Get-VisibleText $handle $ui.Id).Contains($grantTitle)} 'Earlier updates did not expand.'
        $earlierExpected=@($uiExpected.announcements.items | Where-Object {$_.id -eq 'fixture-earlier-id'})[0]
        $earlierFact=(Get-WidgetText 'deliveredOn' $language @((Format-WidgetCompactDate ([DateTimeOffset]$earlierExpected.deliveredAt) $language)))+' · '+(Get-WidgetText 'all' $language)
        [void](Find-VisibleControl $handle $ui.Id $earlierFact)
        Assert-InlineWindow $handle $ui.Id $language
        Save-UiEvidence $element $language 'earlier-updates-inline'
        Invoke-UiButton $handle $handle $ui.Id $earlierText
        Wait-Until {-not (Get-VisibleText $handle $ui.Id).Contains($grantTitle)} 'Earlier updates did not collapse.'
        Invoke-UiButton $handle $handle $ui.Id $historyText
        Wait-Until {(Get-VisibleText $handle $ui.Id).Contains('codex-resets.com')} 'History did not expand inline.'
        $historyExpected=@($uiExpected.announcements.history | Where-Object {$_.id -eq 'fixture-history-id'})[0]
        $historyFact=(Get-WidgetText 'deliveredOn' $language @((Format-WidgetCompactDate ([DateTimeOffset]$historyExpected.deliveredAt) $language)))+' · '+(Get-WidgetText 'all' $language)
        [void](Find-VisibleControl $handle $ui.Id $historyFact)
        Assert-True (@(Get-VisibleControls $handle $ui.Id | Where-Object {$_.Text -ceq $regularTitle}).Count -eq 2) 'Expanded history duplicated the recent completed record or omitted the archived record.'
        Assert-InlineWindow $handle $ui.Id $language
        Save-UiEvidence $element $language 'history-inline'
        Invoke-UiButton $handle $handle $ui.Id $historyText
        Wait-Until {-not (Get-VisibleText $handle $ui.Id).Contains('codex-resets.com')} 'History did not collapse.'
        Assert-True (@(Get-VisibleControls $handle $ui.Id | Where-Object {$_.Text -ceq $regularTitle}).Count -eq 1) 'Collapsing history changed the recent activity record.'

        Invoke-UiButton $handle $handle $ui.Id $sourcesText
        Wait-Until {(Get-VisibleText $handle $ui.Id).Contains('codexreset.dev')} 'Data sources did not expand inline.'
        $sourceOne=(Find-VisibleControl $handle $ui.Id 'codex-reset.com').Bounds
        $sourceTwo=(Find-VisibleControl $handle $ui.Id 'codexreset.dev').Bounds
        $cadenceBounds=(Find-VisibleControl $handle $ui.Id (Get-WidgetText 'refreshCadence' $language)).Bounds
        Assert-True ($sourceOne.Top -eq $sourceTwo.Top -and $sourceOne.Right -le $sourceTwo.Left -and $sourceTwo.Bottom -le $cadenceBounds.Top) 'Source links overlapped each other or the separate refresh cadence.'
        Assert-InlineWindow $handle $ui.Id $language
        [void][QuotaSmokeWindows]::SendMessage($scrollBody,0x115,[IntPtr]7,[IntPtr]::Zero)
        Save-UiEvidence $element $language 'data-sources-inline'
        Invoke-UiButton $handle $handle $ui.Id $sourcesText
        Wait-Until {-not (Get-VisibleText $handle $ui.Id).Contains('codexreset.dev')} 'Data sources did not collapse.'
        foreach ($control in @([QuotaSmokeWindows]::ReadOwnedControls($handle,$ui.Id))) {
            Assert-True ($control.Text -notmatch 'fixture-(?:id|announcement|earlier|history)') 'Native UI leaked a fixture ID.'
        }
        [void][QuotaSmokeWindows]::SendMessage($scrollBody,0x115,[IntPtr]6,[IntPtr]::Zero)
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
    Write-Output ("Original Windows smoke failure: "+$failure.Exception.Message)
    Write-Output $failure.ScriptStackTrace
    # Capture only this isolated install's startup helpers and logs. An owned
    # startup error dialog can retain the lifecycle mutex until it is closed.
    foreach ($logName in @('stdout.log','stderr.log','floating-stdout.log','floating-stderr.log')) {
        $nativeLog=Join-Path $dataDir $logName
        if (Test-Path -LiteralPath $nativeLog) { Write-Output ("Isolated installed log: "+$logName); Get-Content -LiteralPath $nativeLog | Select-Object -Last 30 | Write-Output }
    }
    $starterScript=Join-Path $installDir 'Start.ps1'
    $starterExe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    foreach ($starter in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {$_.ParentProcessId -in $fixtureLaunches})) {
        if (-not $starter.CreationDate -or -not (Test-WidgetProcessOwnership $starter $starterExe $starterScript $starter.CreationDate.ToUniversalTime().ToString('o'))) {continue}
        foreach ($starterLanguage in @('en','zh-CN')) {
            $starterDialog=[QuotaSmokeWindows]::Find([int]$starter.ProcessId,(Get-WidgetText 'app' $starterLanguage))
            if ($starterDialog -ne [IntPtr]::Zero) {
                Write-Output ('Isolated owned startup dialog: '+[QuotaSmokeWindows]::ReadOwnedDialogText($starterDialog,[int]$starter.ProcessId))
                [void][QuotaSmokeWindows]::SendMessage($starterDialog,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
            }
        }
    }
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
    foreach ($uiLog in @($uiOut,$uiError)) {
        if ($uiLog -and (Test-Path -LiteralPath $uiLog)) { Write-Output ("Fabricated native process log: "+[IO.Path]::GetFileName($uiLog)); Get-Content -LiteralPath $uiLog | Select-Object -Last 30 | Write-Output }
    }
    throw $failure
} finally {
    foreach ($process in $testProcesses) { try { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null } } catch { } }
    if (-not $uninstalled -and (Test-Path (Join-Path $installDir 'Stop.ps1'))) {
        try { & (Join-Path $installDir 'Stop.ps1') -Quiet | Out-Null } catch { }
        if (Test-Path (Join-Path $installDir 'unins000.exe')) {
            try {
                $cleanup=Start-Process -FilePath (Join-Path $installDir 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -PassThru
                if (-not $cleanup.WaitForExit(30000)) { $cleanup.Kill(); Write-Output 'Isolated smoke cleanup timed out; original failure retained.' }
            } catch { Write-Output ('Isolated smoke cleanup failed: '+$_.Exception.Message) }
        }
    }
    if ($nativeFixtureExe) {
        foreach ($native in @(Get-CimInstance Win32_Process -Filter "Name='codex.exe'" -ErrorAction SilentlyContinue | Where-Object { [string]::Equals([string]$_.ExecutablePath, $nativeFixtureExe, [StringComparison]::OrdinalIgnoreCase) })) {
            Stop-Process -Id ([int]$native.ProcessId) -Force -ErrorAction SilentlyContinue
        }
    }
    $env:QUOTA_SMOKE_PID_FILE=$savedPidFile; $env:QUOTA_SMOKE_WRAPPER_PID_FILE=$savedWrapperPidFile
    $env:LOCALAPPDATA=$savedLocal; $env:TEMP=$savedTemp; $env:TMP=$savedTmp; $env:PATH=$savedPath; $env:CODEX_CLI_PATH=$savedCli; $env:QUOTA_SMOKE_MODE_FILE=$savedModeFile
}
