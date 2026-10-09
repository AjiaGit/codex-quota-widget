param(
    [ValidateSet('System', 'Light', 'Dark')]
    [string]$Theme = 'System',
    [ValidatePattern('^http://127\.0\.0\.1:\d+$')]
    [string]$BaseUrl = 'http://127.0.0.1:39224'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Native.ps1')
$script:dataDirectory = Get-WidgetDataDirectory
Initialize-WidgetStorage $PSScriptRoot $script:dataDirectory
$script:languageSetting = Get-WidgetLanguageSetting $script:dataDirectory
$script:language = Resolve-WidgetLanguage $script:languageSetting
$script:announcementReadTask = $null
$script:announcementReadContent = $null
$script:noticeView = $null
$script:settingsTask = $null
$script:creditsExpanded = $false
$script:sourcesExpanded = $false
$script:earlierExpanded = $false
$script:creditRenderKey = ''
$script:creditRows = @()
$script:recordExpanded = @{}
function T([string]$key, [object[]]$values = @()) { Get-WidgetText $key $script:language $values }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
// Keep the saved 96-DPI coordinate model, but let Windows rasterize GDI text at
// each monitor's scale instead of stretching the original text bitmap.
public static class WidgetDisplay {
    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    public static bool EnableGdiScaling() {
        try { return SetThreadDpiAwarenessContext(new IntPtr(-5)) != IntPtr.Zero; }
        catch (EntryPointNotFoundException) { return false; }
    }
}
public class WidgetLabel : System.Windows.Forms.Label {
    public WidgetLabel() {
        // Match the GDI TextRenderer used to measure wrapped label layout.
        UseCompatibleTextRendering = false;
        // WinForms' DIB text buffer stays at 96 DPI and bypasses GDI scaling.
        // Paint to the window DC while preserving label layout and mouse events.
        SetStyle(System.Windows.Forms.ControlStyles.OptimizedDoubleBuffer |
                 System.Windows.Forms.ControlStyles.DoubleBuffer, false);
    }
}
public class WidgetLinkLabel : System.Windows.Forms.LinkLabel {
    public WidgetLinkLabel() {
        UseCompatibleTextRendering = false;
        SetStyle(System.Windows.Forms.ControlStyles.OptimizedDoubleBuffer |
                 System.Windows.Forms.ControlStyles.DoubleBuffer, false);
    }
}
public static class WidgetGlyph {
    public static void Draw(System.Drawing.Graphics g, string kind, System.Drawing.Rectangle bounds, System.Drawing.Color color) {
        if (String.IsNullOrEmpty(kind)) return;
        var state=g.Save();g.TranslateTransform(bounds.X,bounds.Y);g.ScaleTransform(bounds.Width/24f,bounds.Height/24f);
        g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using(var p=new System.Drawing.Pen(color,1.7f)) {
            p.StartCap=p.EndCap=System.Drawing.Drawing2D.LineCap.Round;p.LineJoin=System.Drawing.Drawing2D.LineJoin.Round;
            if(kind=="credits") {g.DrawRectangle(p,3,4,18,16);g.DrawLine(p,3,9,21,9);}
            else if(kind=="history") {g.DrawLines(p,new[]{new System.Drawing.Point(5,2),new System.Drawing.Point(14,2),new System.Drawing.Point(19,7),new System.Drawing.Point(19,22),new System.Drawing.Point(5,22),new System.Drawing.Point(5,2)});g.DrawLines(p,new[]{new System.Drawing.Point(14,2),new System.Drawing.Point(14,8),new System.Drawing.Point(19,8)});g.DrawLine(p,8,12,16,12);g.DrawLine(p,8,16,16,16);}
            else if(kind=="sources") {g.DrawArc(p,1,10,12,12,45,270);g.DrawArc(p,11,0,12,12,225,270);g.DrawLine(p,8,16,16,8);}
            else if(kind=="fiveHour") {g.DrawLines(p,new[]{new System.Drawing.Point(14,2),new System.Drawing.Point(4,14),new System.Drawing.Point(11,14),new System.Drawing.Point(10,22),new System.Drawing.Point(20,10),new System.Drawing.Point(13,10),new System.Drawing.Point(14,2)});}
            else if(kind=="recovery") {g.DrawArc(p,3,3,18,18,200,320);g.DrawLines(p,new[]{new System.Drawing.Point(3,5),new System.Drawing.Point(3,11),new System.Drawing.Point(9,11)});g.DrawLines(p,new[]{new System.Drawing.Point(12,7),new System.Drawing.Point(12,12),new System.Drawing.Point(15,14)});}
            else if(kind=="banked") {g.DrawRectangle(p,3,9,18,4);g.DrawRectangle(p,5,13,14,9);g.DrawLine(p,12,9,12,22);g.DrawEllipse(p,6,3,6,6);g.DrawEllipse(p,12,3,6,6);}
            else {g.DrawLines(p,new[]{new System.Drawing.Point(4,9),new System.Drawing.Point(8,9),new System.Drawing.Point(19,4),new System.Drawing.Point(19,20),new System.Drawing.Point(8,15),new System.Drawing.Point(4,15),new System.Drawing.Point(4,9)});g.DrawLine(p,8,9,8,15);g.DrawLines(p,new[]{new System.Drawing.Point(4,15),new System.Drawing.Point(6,22),new System.Drawing.Point(10,22),new System.Drawing.Point(8,15)});g.DrawLine(p,22,9,22,15);}
        }
        g.Restore(state);
    }
}
public class WidgetSectionIcon : System.Windows.Forms.Control {
    public string IconKind {get;set;}
    protected override void OnPaint(System.Windows.Forms.PaintEventArgs e) {WidgetGlyph.Draw(e.Graphics,IconKind,ClientRectangle,ForeColor);}
}
public class WidgetDisclosureButton : System.Windows.Forms.Button {
    public string IconKind {get;set;}public string TrailingText {get;set;}
    private bool expanded;public bool Expanded {get{return expanded;}set{if(expanded!=value){expanded=value;Invalidate();}}}public bool ShowChevron {get;set;}
    public System.Drawing.Color MutedColor {get;set;}public System.Drawing.Color HoverColor {get;set;}
    private bool hot;
    public WidgetDisclosureButton() {
        UseCompatibleTextRendering=false;FlatStyle=System.Windows.Forms.FlatStyle.Flat;FlatAppearance.BorderSize=0;
        SetStyle(System.Windows.Forms.ControlStyles.OptimizedDoubleBuffer|System.Windows.Forms.ControlStyles.DoubleBuffer,false);
        ShowChevron=true;TabStop=true;
    }
    protected override void OnMouseEnter(EventArgs e){hot=true;Invalidate();base.OnMouseEnter(e);}
    protected override void OnMouseLeave(EventArgs e){hot=false;Invalidate();base.OnMouseLeave(e);}
    protected override void OnKeyDown(System.Windows.Forms.KeyEventArgs e){
        if(e.KeyCode==System.Windows.Forms.Keys.Space||e.KeyCode==System.Windows.Forms.Keys.Enter){OnClick(EventArgs.Empty);e.Handled=true;e.SuppressKeyPress=true;return;}
        base.OnKeyDown(e);
    }
    protected override void OnPaint(System.Windows.Forms.PaintEventArgs e) {
        e.Graphics.Clear(hot?HoverColor:BackColor);int left=String.IsNullOrEmpty(IconKind)?0:36,right=ShowChevron?22:0;
        WidgetGlyph.Draw(e.Graphics,IconKind,new System.Drawing.Rectangle(0,(Height-24)/2,24,24),ForeColor);
        var flags=System.Windows.Forms.TextFormatFlags.VerticalCenter|System.Windows.Forms.TextFormatFlags.SingleLine|System.Windows.Forms.TextFormatFlags.NoPrefix|System.Windows.Forms.TextFormatFlags.EndEllipsis;
        if(!String.IsNullOrEmpty(TrailingText)) {
            int trailing=System.Windows.Forms.TextRenderer.MeasureText(TrailingText,Font).Width;
            System.Windows.Forms.TextRenderer.DrawText(e.Graphics,TrailingText,Font,new System.Drawing.Rectangle(Width-right-trailing,0,trailing,Height),MutedColor,flags);right+=trailing+12;
        }
        System.Windows.Forms.TextRenderer.DrawText(e.Graphics,Text,Font,new System.Drawing.Rectangle(left,0,Math.Max(1,Width-left-right),Height),ForeColor,flags);
        if(ShowChevron) {
            e.Graphics.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            using(var p=new System.Drawing.Pen(MutedColor,1.7f)) {
                int x=Width-12,y=Height/2;
                e.Graphics.DrawLines(p,Expanded?new[]{new System.Drawing.Point(x-4,y-2),new System.Drawing.Point(x,y+2),new System.Drawing.Point(x+4,y-2)}:new[]{new System.Drawing.Point(x-2,y-4),new System.Drawing.Point(x+2,y),new System.Drawing.Point(x-2,y+4)});
            }
        }
        if(Focused)System.Windows.Forms.ControlPaint.DrawFocusRectangle(e.Graphics,new System.Drawing.Rectangle(1,1,Width-2,Height-2),ForeColor,BackColor);
    }
}
public static class WidgetPower {
    private static int resumed;
    public static void Enable() { Microsoft.Win32.SystemEvents.PowerModeChanged += OnPowerModeChanged; }
    public static void Disable() { Microsoft.Win32.SystemEvents.PowerModeChanged -= OnPowerModeChanged; }
    private static void OnPowerModeChanged(object sender, Microsoft.Win32.PowerModeChangedEventArgs e) {
        if (e.Mode == Microsoft.Win32.PowerModes.Resume) System.Threading.Interlocked.Exchange(ref resumed, 1);
    }
    public static bool ConsumeResume() { return System.Threading.Interlocked.Exchange(ref resumed, 0) != 0; }
}
// Observe button presses without consuming input. The callback only queues UI work.
public static class WidgetOutsideClick {
    [StructLayout(LayoutKind.Sequential)] private struct Point { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct MouseData {
        public Point point; public uint mouseData, flags, time; public UIntPtr extraInfo;
    }
    private delegate IntPtr MouseProc(int code, IntPtr message, IntPtr data);
    private static readonly MouseProc procedure = OnMouse;
    private static readonly uint processId = (uint)System.Diagnostics.Process.GetCurrentProcess().Id;
    private static IntPtr hook;
    private static System.Windows.Forms.Control receiver;
    private static Action<System.Drawing.Point> clicked;
    [DllImport("user32.dll", CharSet = CharSet.Auto)] private static extern IntPtr SetWindowsHookEx(int kind, MouseProc proc, IntPtr module, uint thread);
    [DllImport("user32.dll")] private static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")] private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
    [DllImport("user32.dll")] private static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr window, out Rect bounds);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)] private static extern IntPtr GetModuleHandle(string name);
    // Hook points and this rectangle are physical pixels, including on scaled monitors.
    public static System.Drawing.Rectangle GetPhysicalBounds(System.Windows.Forms.Control control) {
        if (control == null || !control.IsHandleCreated || control.IsDisposed) return System.Drawing.Rectangle.Empty;
        var previous = SetThreadDpiAwarenessContext(new IntPtr(-3));
        if (previous == IntPtr.Zero) return System.Drawing.Rectangle.Empty;
        try {
            Rect bounds;
            if (!GetWindowRect(control.Handle, out bounds)) return System.Drawing.Rectangle.Empty;
            return System.Drawing.Rectangle.FromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom);
        } finally { SetThreadDpiAwarenessContext(previous); }
    }
    public static void Enable(System.Windows.Forms.Control control, Action<System.Drawing.Point> action) {
        if (hook != IntPtr.Zero) return;
        receiver = control; clicked = action;
        hook = SetWindowsHookEx(14, procedure, GetModuleHandle(null), 0);
    }
    public static void Disable() {
        if (hook != IntPtr.Zero) UnhookWindowsHookEx(hook);
        hook = IntPtr.Zero; receiver = null; clicked = null;
    }
    private static IntPtr OnMouse(int code, IntPtr message, IntPtr data) {
        int kind = message.ToInt32();
        var control = receiver; var action = clicked;
        if (code >= 0 && (kind == 0x0201 || kind == 0x0204 || kind == 0x0207 || kind == 0x020B)
            && control != null && action != null && control.IsHandleCreated && !control.IsDisposed) {
            var input = (MouseData)Marshal.PtrToStructure(data, typeof(MouseData));
            // WH_MOUSE_LL supplies physical coordinates. Do not let USER32 virtualize them.
            var previous = SetThreadDpiAwarenessContext(new IntPtr(-3));
            if (previous != IntPtr.Zero) {
                try {
                    uint targetProcess;
                    GetWindowThreadProcessId(WindowFromPoint(input.point), out targetProcess);
                    // Our menus and owned dialogs remain interactive, even outside the main form.
                    if (targetProcess != processId) {
                        var point = new System.Drawing.Point(input.point.x, input.point.y);
                        try { control.BeginInvoke(action, new object[] { point }); }
                        catch (InvalidOperationException) { }
                    }
                } finally { SetThreadDpiAwarenessContext(previous); }
            }
        }
        return CallNextHookEx(hook, code, message, data);
    }
}
public static class WidgetDrag {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr hIcon);
}
'@

[void][WidgetDisplay]::EnableGdiScaling()
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:baseUrl = $BaseUrl
$script:showRequest = Join-Path $script:dataDirectory 'show.request'
$script:positionPath = Join-Path $script:dataDirectory 'window.json'
$script:positionDirty = $false
$script:lastPositionSave = [DateTime]::MinValue
$script:client = New-Object System.Net.Http.HttpClient
$script:client.Timeout = [TimeSpan]::FromSeconds(25)
$script:requestTask = $null
$script:requestManual = $false
$script:queuedManual = $false
$script:externalTask = $null
$script:externalRequestContent = $null
$script:externalCachePath = Join-Path $script:dataDirectory 'native-public-cache.json'
$script:externalData = Merge-WidgetExternalData (Read-WidgetJson $script:externalCachePath) $null $true
$script:nextExternalPoll = [DateTime]::MinValue
$script:nextPoll = [DateTime]::MinValue
$script:lastRender = [DateTime]::MinValue
$script:lastThemeCheck = [DateTime]::MinValue
$script:data = $null
$script:remaining = $null
$script:message = (T 'reading')
$script:reallyExit = $false
$script:colors = @{}
$script:layoutPlus = $null
$script:layoutBusy = $false
$script:historyExpanded = $false
$script:visibleActivityView = $null
$script:announcementRenderKey = ''
$script:announcementRows = @()
$script:historyRows = @()
$script:mode = 'Detail'
$script:animating = $false
$script:targetMode = 'Detail'
$script:compactDragging = $false
$script:compactMoved = $false
$script:resizing = $false
$script:trayIconKey = ''
$script:setupCode = $null
$script:ownedTrayIcon = $null
$script:compactSize = [System.Drawing.Size]::new(52, 76)
$script:detailSize = [System.Drawing.Size]::new(606, 585)
$script:automaticDetailHeight = $true
$script:modePositions = @{ Detail = $null; Compact = $null }

function New-Color([string]$html) {
    [System.Drawing.ColorTranslator]::FromHtml($html)
}

function New-Label([string]$text, [int]$x, [int]$y, [int]$width, [int]$height, [float]$size, [bool]$bold = $false) {
    $label = New-Object WidgetLabel
    $label.Text = $text
    $label.Location = New-Object System.Drawing.Point($x, $y)
    $label.Size = New-Object System.Drawing.Size($width, $height)
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $label.AutoEllipsis = $true
    $label.UseMnemonic = $false
    return $label
}

$script:form = New-Object System.Windows.Forms.Form
$form.Text = (T 'app')
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.ShowInTaskbar = $false
$form.TopMost = $true
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$saved = $null
if (Test-Path -LiteralPath $script:positionPath) {
    try { $saved = Get-Content -LiteralPath $script:positionPath -Raw | ConvertFrom-Json } catch { }
}
if ($saved) {
    try {
        $maxSavedHeight=([Windows.Forms.Screen]::AllScreens | ForEach-Object {$_.WorkingArea.Height} | Measure-Object -Maximum).Maximum
        $cw = [int]$saved.compactWidth; $ch = [int]$saved.compactHeight
        if ($cw -ge 48 -and $cw -le 160 -and $ch -ge 64 -and $ch -le 200) {
            $script:compactSize = [System.Drawing.Size]::new($cw, $ch)
        }
        $dw = [int]$saved.detailWidth; $dh = [int]$saved.detailHeight
        if ($dw -ge 404 -and $dw -le 720 -and $dh -ge 390 -and $dh -le $maxSavedHeight) {
            $script:detailSize = [System.Drawing.Size]::new($dw, $dh)
        }
    } catch { }
}
if ($saved -and $null -ne $saved.topMost) { $form.TopMost = [bool]$saved.topMost }
if ($saved -and [int]$saved.detailLayoutVersion -ge 4) {
    if ($null -ne $saved.detailAutoHeight) { $script:automaticDetailHeight = [bool]$saved.detailAutoHeight }
} else {
    $script:detailSize = [Drawing.Size]::new([Math]::Max(560,$script:detailSize.Width),$script:detailSize.Height)
}
if ($saved -and $saved.mode -eq 'Compact') { $script:mode = 'Compact' }
foreach ($savedMode in @('Detail','Compact')) { $script:modePositions[$savedMode] = Get-WidgetModePosition $saved $savedMode }
$form.ClientSize = if ($script:mode -eq 'Compact') { $script:compactSize } else { $script:detailSize }
$form.Location = New-Object System.Drawing.Point(($bounds.Right - $form.Width - 24), ($bounds.Top + 88))
if ($saved) {
    try {
        $savedPosition = $script:modePositions[$script:mode]
        $x = if ($savedPosition) { [int]$savedPosition.x } else { [int]$saved.x }
        $y = if ($savedPosition) { [int]$savedPosition.y } else { [int]$saved.y }
        foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
            $area = $screen.WorkingArea
            if ($x -ge $area.Left -and $y -ge $area.Top -and $x -lt $area.Right -and $y -lt $area.Bottom) {
                $safeX = [Math]::Max($area.Left, [Math]::Min($x, $area.Right - $form.Width))
                $safeY = [Math]::Max($area.Top, [Math]::Min($y, $area.Bottom - $form.Height))
                $form.Location = New-Object System.Drawing.Point([int]$safeX, [int]$safeY)
                break
            }
        }
    } catch { }
}

function Set-RoundedRegion {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $right = $form.Width - 19
    $bottom = $form.Height - 19
    $path.AddArc(0, 0, 18, 18, 180, 90)
    $path.AddArc($right, 0, 18, 18, 270, 90)
    $path.AddArc($right, $bottom, 18, 18, 0, 90)
    $path.AddArc(0, $bottom, 18, 18, 90, 90)
    $path.CloseFigure()
    $previous = $form.Region
    $form.Region = New-Object System.Drawing.Region($path)
    if ($previous) { $previous.Dispose() }
    $path.Dispose()
}
Set-RoundedRegion

function New-ToolbarButton([string]$kind) {
    $button = New-Object Windows.Forms.Button
    $button.Name = 'toolbar-' + $kind
    $button.Tag = $kind
    $button.Text = ''
    $button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.Size = [Drawing.Size]::new(32,32)
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.TabStop = $true
    $button.Add_Paint({
        param($sender,$e)
        $e.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $pen = [Drawing.Pen]::new($script:colors.muted,1.5)
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $cx=[single]($sender.Width/2); $cy=[single]($sender.Height/2)
        try {
            switch ([string]$sender.Tag) {
                'refresh' {
                    $e.Graphics.DrawArc($pen,([Drawing.RectangleF]::new($cx-6,$cy-6,12,12)),45,285)
                    $e.Graphics.DrawLine($pen,([Drawing.PointF]::new($cx+6,$cy-7)),([Drawing.PointF]::new($cx+6,$cy-1)))
                    $e.Graphics.DrawLine($pen,([Drawing.PointF]::new($cx+6,$cy-1)),([Drawing.PointF]::new($cx+1,$cy-1)))
                }
                'compact' { $e.Graphics.DrawLine($pen,([Drawing.PointF]::new($cx-5,$cy)),([Drawing.PointF]::new($cx+5,$cy))) }
                'hide' {
                    $e.Graphics.DrawLine($pen,([Drawing.PointF]::new($cx-4,$cy-4)),([Drawing.PointF]::new($cx+4,$cy+4)))
                    $e.Graphics.DrawLine($pen,([Drawing.PointF]::new($cx-4,$cy+4)),([Drawing.PointF]::new($cx+4,$cy-4)))
                }
            }
            if ($sender.Focused) { [Windows.Forms.ControlPaint]::DrawFocusRectangle($e.Graphics,[Drawing.Rectangle]::new(3,3,$sender.Width-6,$sender.Height-6),$script:colors.muted,$sender.BackColor) }
        } finally { $pen.Dispose() }
    })
    return $button
}
function New-SectionIcon([string]$kind) {
    $icon=New-Object WidgetSectionIcon;$icon.IconKind=$kind;$icon.Size=[Drawing.Size]::new(24,24);$icon.Tag='strong';return $icon
}
function New-DisclosureButton([string]$kind, [string]$name) {
    $button=New-Object WidgetDisclosureButton;$button.Name=$name;$button.IconKind=$kind;$button.Font=[Drawing.Font]::new('Segoe UI',10.5,[Drawing.FontStyle]::Bold)
    $button.UseMnemonic=$false;$button.Cursor=[Windows.Forms.Cursors]::Hand;$button.Tag='strong';return $button
}
$title = New-Label (T 'app') 18 10 132 30 15 $true
$title.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $title.Tag='strong'
$status = New-Label (T 'loading') 18 42 364 24 9
$status.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $status.Name='quota-updated-age'
$refresh = New-ToolbarButton 'refresh'; $refresh.TabIndex=0
$compactButton = New-ToolbarButton 'compact'; $compactButton.TabIndex=1
$close = New-ToolbarButton 'hide'; $close.TabIndex=2
$body = New-Object Windows.Forms.Panel
$body.Name='detail-scroll-body'; $body.AutoScroll=$true; $body.TabStop=$false; $body.TabIndex=3
$content = New-Object Windows.Forms.Panel
$content.Name='detail-content'; [void]$body.Controls.Add($content)
$script:sectionPanels=@{}
foreach ($section in @('hero','fiveHour','credits','announcements','history','sources','footer')) {
    $panel=New-Object Windows.Forms.Panel; $panel.Name='section-'+$section
    $script:sectionPanels[$section]=$panel; [void]$content.Controls.Add($panel)
    if ($section -ne 'footer') {$panel.Add_Paint({param($sender,$e);if ($script:colors.line) {$pen=[Drawing.Pen]::new($script:colors.line,1);try {$e.Graphics.DrawLine($pen,0,$sender.Height-1,$sender.Width,$sender.Height-1)}finally{$pen.Dispose()}}})}
}
$heroPanel=$script:sectionPanels.hero; $fivePanel=$script:sectionPanels.fiveHour
$creditsPanel=$script:sectionPanels.credits; $announcementPanel=$script:sectionPanels.announcements
$historyPanel=$script:sectionPanels.history
$sourcesPanel=$script:sectionPanels.sources
$footerPanel=$script:sectionPanels.footer

$ring = New-Object System.Windows.Forms.Panel
$ring.Location = New-Object System.Drawing.Point(20, 58)
$ring.Size = New-Object System.Drawing.Size(110, 110)
$ring.Add_Paint({
    param($sender, $e)
    $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $compactVisual = $script:mode -eq 'Compact' -or ($script:animating -and $script:targetMode -eq 'Compact')
    $stroke = if ($compactVisual) { [Math]::Max(5, [Math]::Min(12, $sender.Width * 5.0 / 42)) } else { [Math]::Max(8, [Math]::Min(12, $sender.Width * 8.0 / 110)) }
    $inset = [Math]::Max(6, [Math]::Ceiling($stroke))
    $diameter = [Math]::Max(1, [Math]::Min($sender.Width, $sender.Height) - $inset * 2)
    $track = New-Object System.Drawing.Pen($script:colors.track, $stroke)
    $track.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $track.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $ringColor=if ($null -ne $script:remaining -and $script:remaining -le 10) {$script:colors.danger} else {$script:colors.accent}
    if (-not $ringColor) {$ringColor=$script:colors.accent}
    $arc = New-Object System.Drawing.Pen($ringColor, $stroke)
    $arc.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arc.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $e.Graphics.DrawArc($track, $inset, $inset, $diameter, $diameter, 0, 360)
    if ($null -ne $script:remaining -and $script:remaining -gt 0) {
        $e.Graphics.DrawArc($arc, $inset, $inset, $diameter, $diameter, -90, (360 * $script:remaining / 100))
    }
    if ($sender.Width -ge 40) {
        $text = if ($null -eq $script:remaining) { '—' } elseif ($compactVisual) { [string]$script:remaining } else { "$($script:remaining)%" }
        $fontSize = if ($compactVisual) { [Math]::Max(10, [Math]::Min(30, 11 * $sender.Width / 42.0)) } else { [Math]::Max(20, [Math]::Min(27, 20 * $sender.Width / 110.0)) }
        $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold)
        # GDI+ DrawString is bitmap-scaled; use the same GDI path as labels.
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::NoPadding -bor [Windows.Forms.TextFormatFlags]::NoPrefix -bor [Windows.Forms.TextFormatFlags]::PreserveGraphicsClipping -bor [Windows.Forms.TextFormatFlags]::PreserveGraphicsTranslateTransform
        try {
            [Windows.Forms.TextRenderer]::DrawText($e.Graphics, $text, $font, [Drawing.Rectangle]::new(0, 0, $sender.Width, $sender.Height), $script:colors.text, $flags)
        } finally { $font.Dispose() }
    }
    if ($compactVisual -and $script:noticeView.hasUnread) {
        $notice=Get-WidgetNoticeBounds $sender.Width $sender.Height
        $outline=[Drawing.Pen]::new($script:colors.back,2)
        $brush=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(246,202,105))
        $e.Graphics.DrawEllipse($outline,[single]$notice.x,[single]$notice.y,[single]$notice.width,[single]$notice.height)
        $e.Graphics.FillEllipse($brush,[single]$notice.x,[single]$notice.y,[single]$notice.width,[single]$notice.height)
        $outline.Dispose(); $brush.Dispose()
    }
    $track.Dispose(); $arc.Dispose()
})

$caption=New-Label (T 'untilReset') 160 10 250 26 12
$countdown=New-Label (T 'reading') 160 42 250 40 22.5 $true;$countdown.Tag='strong'
$reset=New-Label (T 'resetUnknown') 160 85 250 24 10.5
$updated=New-Label '' 160 113 250 24 10.5
$heroDivider=New-Object Windows.Forms.Panel;$heroDivider.Tag='line'
foreach ($control in @($ring,$caption,$countdown,$reset,$updated,$heroDivider)){[void]$heroPanel.Controls.Add($control)}
$fiveDivider=New-Object Windows.Forms.Panel;$fiveDivider.Tag='line';$fiveIcon=New-SectionIcon 'fiveHour'
$fiveTitle=New-Label (T 'fiveHour') 36 10 240 26 10.5 $true;$fiveTitle.Tag='strong'
$fiveValue=New-Label '' 270 10 70 26 10.5 $true;$fiveValue.Tag='strong';$fiveValue.TextAlign=[Drawing.ContentAlignment]::MiddleRight
$fiveReset=New-Label '' 36 40 346 24 9.75
foreach ($control in @($fiveDivider,$fiveIcon,$fiveTitle,$fiveValue,$fiveReset)){[void]$fivePanel.Controls.Add($control)}
$divider=New-Object Windows.Forms.Panel;$divider.Tag='line';[void]$creditsPanel.Controls.Add($divider)
$cards=New-DisclosureButton 'credits' 'reset-credit-details';$cards.TrailingText=T 'disclosureDetails';$cards.Add_Click({Toggle-ResetDetails})
$creditDetailsPanel=New-Object Windows.Forms.Panel;$creditDetailsPanel.Name='inline-reset-details'
$creditNote=New-Label '' 0 0 346 22 9.75;$creditRowsPanel=New-Object Windows.Forms.Panel
[void]$creditDetailsPanel.Controls.Add($creditNote);[void]$creditDetailsPanel.Controls.Add($creditRowsPanel)
[void]$creditsPanel.Controls.Add($cards);[void]$creditsPanel.Controls.Add($creditDetailsPanel)
$activityHeading=New-Label (T 'activityHeading') 0 10 346 24 12 $true;$activityHeading.Tag='strong'
$localTimeNote=New-Label '' 0 40 346 22 9.75
$publicStatusPanel=New-Object Windows.Forms.Panel;$publicStatusPanel.Name='public-data-status'
$publicStatusTitle=New-Label '' 12 10 300 22 9.75 $true;$publicStatusTitle.Tag='warning'
$publicStatusText=New-Label '' 12 36 300 22 9.75;$publicStatusFetched=New-Label '' 12 60 300 22 9.75
$publicRetry=New-DisclosureButton '' 'public-data-retry';$publicRetry.ShowChevron=$false;$oldFont=$publicRetry.Font;$publicRetry.Font=[Drawing.Font]::new('Segoe UI',9.75);$oldFont.Dispose();$publicRetry.Tag='warning';$publicRetry.Add_Click({Start-PublicRetry})
foreach ($control in @($publicStatusTitle,$publicStatusText,$publicStatusFetched,$publicRetry)){[void]$publicStatusPanel.Controls.Add($control)}
$publicStatusPanel.Add_Paint({param($sender,$e);$pen=[Drawing.Pen]::new($script:colors.warning,1);try {$e.Graphics.DrawRectangle($pen,0,0,$sender.Width-1,$sender.Height-1)}finally {$pen.Dispose()}})
$activityRowsPanel=New-Object Windows.Forms.Panel
$earlierButton=New-DisclosureButton 'history' 'earlier-updates-toggle';$earlierButton.Add_Click({$script:earlierExpanded=-not $script:earlierExpanded;Show-External})
$earlierRowsPanel=New-Object Windows.Forms.Panel
$activityEmpty=New-Label '' 0 0 346 22 10.5;$activityEmptyHelp=New-Label (T 'activityEmptyHelp') 0 0 346 22 9.75
$recoveryWarning=New-Label '' 0 0 346 22 10.5
foreach ($control in @($activityHeading,$localTimeNote,$publicStatusPanel,$recoveryWarning,$activityRowsPanel,$earlierButton,$earlierRowsPanel,$activityEmpty,$activityEmptyHelp)){[void]$announcementPanel.Controls.Add($control)}
$historyButton=New-DisclosureButton 'history' 'announcement-history-toggle';$historyButton.Add_Click({$script:historyExpanded=-not $script:historyExpanded;Show-External})
$historyRowsPanel=New-Object Windows.Forms.Panel
$historyAttribution=New-Object Windows.Forms.FlowLayoutPanel;$historyAttribution.WrapContents=$true
$historyLabel=New-Label (T 'historyAttribution') 0 0 200 24 9.75;$historyLabel.AutoSize=$true
$historyLink=New-Object WidgetLinkLabel;$historyLink.Text='codex-resets.com';$historyLink.Font=[Drawing.Font]::new('Segoe UI',9.75);$historyLink.AutoSize=$true;$historyLink.UseMnemonic=$false
[void]$historyLink.Links.Add(0,$historyLink.Text.Length,'https://codex-resets.com/');$historyLink.Add_LinkClicked({try{Start-Process -FilePath 'https://codex-resets.com/'}catch{}})
[void]$historyAttribution.Controls.Add($historyLabel);[void]$historyAttribution.Controls.Add($historyLink)
foreach ($control in @($historyButton,$historyRowsPanel,$historyAttribution)){[void]$historyPanel.Controls.Add($control)}
$sourcesButton=New-DisclosureButton 'sources' 'data-sources-toggle';$sourcesButton.Add_Click({Toggle-DataSources});[void]$sourcesPanel.Controls.Add($sourcesButton)
$sourceChecked=New-Label '' 0 0 346 24 9.75;[void]$sourcesPanel.Controls.Add($sourceChecked)
$attribution=New-Object Windows.Forms.FlowLayoutPanel
$attribution.WrapContents=$true; $attribution.Margin=[Windows.Forms.Padding]::Empty; $attribution.Padding=[Windows.Forms.Padding]::Empty
$script:attributionSiteLinks=@()
foreach ($site in @('codexreset.ai','whenreset.app')) {
    if ($script:attributionSiteLinks.Count) {
        $separator=New-Label ' / ' 0 0 20 22 9
        $separator.AutoSize=$true; $separator.Margin=[Windows.Forms.Padding]::Empty
        [void]$attribution.Controls.Add($separator)
    }
    # A complete single link uses GDI; partial/multiple links force GDI+.
    $siteLink=New-Object WidgetLinkLabel
    $siteLink.Text=$site; $siteLink.Font=[Drawing.Font]::new('Segoe UI',9)
    $siteLink.AutoSize=$true; $siteLink.Margin=[Windows.Forms.Padding]::Empty
    $siteLink.LinkBehavior=[Windows.Forms.LinkBehavior]::AlwaysUnderline; $siteLink.UseMnemonic=$false
    $siteLink.TabStop=$true; [void]$siteLink.Links.Add(0,$site.Length,('https://'+$site+'/'))
    $script:attributionSiteLinks+=,$siteLink; [void]$attribution.Controls.Add($siteLink)
}
[void]$sourcesPanel.Controls.Add($attribution)
$cadence=New-Label (T 'refreshCadence') 0 10 346 24 9; [void]$footerPanel.Controls.Add($cadence)
foreach ($control in @($title,$status,$refresh,$compactButton,$close,$body)) { [void]$form.Controls.Add($control) }
$script:resizeEdges = @{}
foreach ($edge in @('Top', 'Bottom', 'Left', 'Right', 'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight')) {
    $zone = New-Object System.Windows.Forms.Panel
    $zone.Tag = $edge
    $zone.Cursor = switch ($edge) {
        { $_ -in @('Left', 'Right') } { [System.Windows.Forms.Cursors]::SizeWE; break }
        { $_ -in @('Top', 'Bottom') } { [System.Windows.Forms.Cursors]::SizeNS; break }
        { $_ -in @('TopLeft', 'BottomRight') } { [System.Windows.Forms.Cursors]::SizeNWSE; break }
        default { [System.Windows.Forms.Cursors]::SizeNESW }
    }
    [void]$form.Controls.Add($zone)
    $script:resizeEdges[$edge] = $zone
}
$script:detailControls = @($title,$status,$refresh,$compactButton,$close,$body)

$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.SetToolTip($refresh, (T 'tipRefresh'))
$tooltip.SetToolTip($close, (T 'tipHide'))
$tooltip.SetToolTip($compactButton, (T 'tipCompact'))
$tooltip.SetToolTip($ring, (T 'tipExpand'))
foreach ($zone in $script:resizeEdges.Values) { $tooltip.SetToolTip($zone, (T 'tipResize')) }

function Set-ControlBox($control, [double]$x, [double]$y, [double]$width, [double]$height) {
    $control.Bounds = [System.Drawing.Rectangle]::new(
        [int][Math]::Round($x), [int][Math]::Round($y),
        [int][Math]::Max(1, [Math]::Round($width)), [int][Math]::Max(1, [Math]::Round($height)))
}

function Update-ResizeEdges([int]$width, [int]$height, [bool]$compact, [double]$scale = 1) {
    $edgeSize = if ($compact) { 6 } else { [int][Math]::Round(7 * $scale) }
    $cornerSize = if ($compact) { 13 } else { [int][Math]::Round(16 * $scale) }
    Set-ControlBox $script:resizeEdges.Top $cornerSize 0 ($width - 2 * $cornerSize) $edgeSize
    Set-ControlBox $script:resizeEdges.Bottom $cornerSize ($height - $edgeSize) ($width - 2 * $cornerSize) $edgeSize
    Set-ControlBox $script:resizeEdges.Left 0 $cornerSize $edgeSize ($height - 2 * $cornerSize)
    Set-ControlBox $script:resizeEdges.Right ($width - $edgeSize) $cornerSize $edgeSize ($height - 2 * $cornerSize)
    Set-ControlBox $script:resizeEdges.TopLeft 0 0 $cornerSize $cornerSize
    Set-ControlBox $script:resizeEdges.TopRight ($width - $cornerSize) 0 $cornerSize $cornerSize
    Set-ControlBox $script:resizeEdges.BottomLeft 0 ($height - $cornerSize) $cornerSize $cornerSize
    Set-ControlBox $script:resizeEdges.BottomRight ($width - $cornerSize) ($height - $cornerSize) $cornerSize $cornerSize
}

function Set-WrappedBox($control, [int]$x, [int]$y, [int]$width, [int]$minimumHeight = 22) {
    $control.AutoEllipsis=$false
    $measured=[Windows.Forms.TextRenderer]::MeasureText($control.Text,$control.Font,[Drawing.Size]::new([Math]::Max(1,$width),32767),([Windows.Forms.TextFormatFlags]::WordBreak -bor [Windows.Forms.TextFormatFlags]::NoPrefix))
    $height=[Math]::Max($minimumHeight,$measured.Height+4)
    Set-ControlBox $control $x $y $width $height
    return $height
}
function Layout-AnnouncementRows($parent, $rows, [int]$width, [int]$startY=0) {
    $y=$startY
    foreach ($row in $rows) {
        $row.Width=$width;$row.Location=[Drawing.Point]::new(0,$y);$parts=$row.Tag
        $left=if ($form.Width -le 420) {32} else {36};$mainWidth=$width-$left;$insideY=10
        Set-ControlBox $parts.icon 0 12 24 24
        $insideY+=(Set-WrappedBox $parts.label $left $insideY $mainWidth 20)
        $sourceWidth=if ($parts.source) {[Math]::Min($mainWidth,[Windows.Forms.TextRenderer]::MeasureText($parts.source.Text,$parts.source.Font).Width+6)} else {0}
        $stacked=$form.Width -le 420 -or $mainWidth-$sourceWidth-12 -lt 180
        $titleWidth=if ($sourceWidth -gt 0 -and -not $stacked) {$mainWidth-$sourceWidth-12} else {$mainWidth}
        $titleHeight=Set-WrappedBox $parts.title $left $insideY $titleWidth 22
        if ($parts.source -and -not $stacked) {Set-ControlBox $parts.source ($width-$sourceWidth) $insideY $sourceWidth $titleHeight}
        $insideY+=$titleHeight+2
        if ($parts.source -and $stacked) {$insideY+=(Set-WrappedBox $parts.source $left $insideY $mainWidth 20)+2}
        foreach ($control in @($parts.fact,$parts.missing,$parts.status) | Where-Object {$_ -and $_.Text}) {$insideY+=(Set-WrappedBox $control $left $insideY $mainWidth 20)+2}
        if ($parts.more) {
            Set-ControlBox $parts.more $left $insideY ([Math]::Min(180,$mainWidth)) 26;$insideY+=26
            $expanded=[bool]$script:recordExpanded[$parts.key];$parts.more.Expanded=$expanded;$parts.extraPanel.Visible=$expanded
            if ($expanded) {
                $extraY=0
                foreach ($control in $parts.extraPanel.Controls) {$extraY+=(Set-WrappedBox $control 0 $extraY $mainWidth 20)+4}
                Set-ControlBox $parts.extraPanel $left $insideY $mainWidth $extraY;$insideY+=$extraY
            }
        }
        $row.Height=$insideY+10;$y+=$row.Height
    }
    $parent.Height=[Math]::Max(1,$y);return $y
}
function Layout-ResetCreditRows([int]$width) {
    $y=0
    foreach ($row in $script:creditRows) {
        $parts=$row.Tag;$insideY=10;Set-ControlBox $parts.rule 0 0 $width 1
        foreach ($control in @($parts.title,$parts.description,$parts.granted,$parts.expires) | Where-Object {$_ -and $_.Text}) {$insideY+=(Set-WrappedBox $control 0 $insideY $width 20)+2}
        Set-ControlBox $row 0 $y $width ($insideY+10);$y+=$row.Height
    }
    Set-ControlBox $creditRowsPanel 0 $creditRowsPanel.Top $width ([Math]::Max(1,$y));return $y
}
function Update-ResponsiveLayout {
    if ($script:animating -or $script:layoutBusy) {return}
    $script:layoutBusy=$true
    try {
        $width=$form.ClientSize.Width;$height=$form.ClientSize.Height
        if ($script:mode -eq 'Compact') {
            if ($ring.Parent -ne $form) {$ring.Parent=$form}
            $ringSize=[Math]::Max(38,[Math]::Min($width-10,$height-20));Set-ControlBox $ring (($width-$ringSize)/2) (($height-$ringSize)/2) $ringSize $ringSize
            Update-ResizeEdges $width $height $true
        } else {
            $titleWidth=[Windows.Forms.TextRenderer]::MeasureText($title.Text,$title.Font).Width+6;$statusWidth=[Windows.Forms.TextRenderer]::MeasureText($status.Text,$status.Font).Width+6
            $header=Get-WidgetHeaderLayout $width $titleWidth $statusWidth
            Set-ControlBox $title $header.titleX $header.titleY $header.titleWidth 28;Set-ControlBox $status $header.statusX $header.statusY $header.statusWidth 22
            foreach ($button in $header.buttons) {$control=switch($button.kind){'refresh' {$refresh} 'compact' {$compactButton} 'hide' {$close}};Set-ControlBox $control $button.x $button.y $button.width $button.height}
            $scrollY=[Math]::Max(0,-$body.AutoScrollPosition.Y);Set-ControlBox $body 7 $header.height ($width-14) ($height-$header.height-10)
            $metrics=Get-WidgetDetailMetrics $width;$contentInset=$metrics.inset-7
            $cw=[Math]::Max(1,$body.Width-2*$contentInset-[Windows.Forms.SystemInformation]::VerticalScrollBarWidth)
            if ($ring.Parent -ne $heroPanel) {$ring.Parent=$heroPanel}
            Set-ControlBox $ring 0 10 $metrics.ring $metrics.ring
            $copyX=$metrics.copyX;$copyWidth=$cw-$copyX;Set-ControlBox $caption $copyX 10 $copyWidth 26
            $targetFont=[single]($metrics.countdownPixels*0.75)
            if ([Math]::Abs($countdown.Font.Size-$targetFont) -gt 0.1) {$old=$countdown.Font;$countdown.Font=[Drawing.Font]::new('Segoe UI',$targetFont,[Drawing.FontStyle]::Bold);$old.Dispose()}
            $countHeight=Set-WrappedBox $countdown $copyX 42 $copyWidth 38
            $resetY=42+$countHeight+4;$copyBottom=$resetY+(Set-WrappedBox $reset $copyX $resetY $copyWidth 22)
            if ($updated.Visible) {$copyBottom+=8+(Set-WrappedBox $updated $copyX ($copyBottom+8) $copyWidth 22)}
            $heroPanel.Height=[Math]::Max($metrics.ring+24,$copyBottom+14);Set-ControlBox $heroDivider $metrics.dividerX 10 1 ($heroPanel.Height-24)
            Set-ControlBox $fiveIcon 0 10 24 24
            if ($width -gt 520) {
                $resetWidth=[Windows.Forms.TextRenderer]::MeasureText($fiveReset.Text,$fiveReset.Font).Width+6
                $titleWidth=$cw-36-$resetWidth-70-24
                $fiveHeight=Set-WrappedBox $fiveTitle 36 10 $titleWidth 26
                Set-ControlBox $fiveValue (36+$titleWidth+12) 10 58 $fiveHeight
                Set-ControlBox $fiveReset ($cw-$resetWidth) 10 $resetWidth $fiveHeight
                $fivePanel.Height=$fiveHeight+20
            } else {
                $fiveHeight=[Math]::Max((Set-WrappedBox $fiveTitle 36 10 ($cw-126) 26),(Set-WrappedBox $fiveValue ($cw-80) 10 80 26))
                $fivePanel.Height=10+$fiveHeight+4+(Set-WrappedBox $fiveReset 36 (14+$fiveHeight) ($cw-36) 22)+10
            }
            Set-ControlBox $fiveDivider 0 0 $cw 1
            Set-ControlBox $cards 0 10 $cw 30;$cards.Expanded=$script:creditsExpanded
            $creditDetailsPanel.Visible=$script:creditsExpanded;$creditHeight=50
            if ($script:creditsExpanded) {
                $noteHeight=Set-WrappedBox $creditNote 0 0 $cw 20;Set-ControlBox $creditRowsPanel 0 ($noteHeight+8) $cw 1
                $creditRowsHeight=Layout-ResetCreditRows $cw;Set-ControlBox $creditDetailsPanel 0 48 $cw ($noteHeight+8+$creditRowsHeight);$creditHeight=48+$creditDetailsPanel.Height+10
            }
            $creditsPanel.Height=$creditHeight;Set-ControlBox $divider 0 0 $cw 1
            $aY=10+(Set-WrappedBox $activityHeading 0 10 $cw 24)+4;$aY+=(Set-WrappedBox $localTimeNote 0 $aY $cw 20)+4
            if ($publicStatusPanel.Visible) {
                $statusWidth=$cw-24;$noticeY=10
                foreach ($control in @($publicStatusTitle,$publicStatusText,$publicStatusFetched) | Where-Object {$_.Text}) {$noticeY+=(Set-WrappedBox $control 12 $noticeY $statusWidth 20)+2}
                Set-ControlBox $publicRetry 12 ($noticeY+4) ([Math]::Min(180,$statusWidth)) 26;Set-ControlBox $publicStatusPanel 0 ($aY+8) $cw ($noticeY+40);$aY+=$publicStatusPanel.Height+16
            }
            if ($recoveryWarning.Visible) {$aY+=(Set-WrappedBox $recoveryWarning 0 $aY $cw 20)+6}
            Set-ControlBox $activityRowsPanel 0 $aY $cw 1;$aY+=(Layout-AnnouncementRows $activityRowsPanel $script:announcementRows $cw)
            $activityEmpty.Visible=$script:activityIsEmpty -and -not $publicStatusPanel.Visible;$activityEmptyHelp.Visible=$activityEmpty.Visible
            if ($activityEmpty.Visible) {$aY+=(Set-WrappedBox $activityEmpty 0 $aY $cw 20)+4;$aY+=(Set-WrappedBox $activityEmptyHelp 0 $aY $cw 20)+4}
            $hasEarlier=$script:earlierRows.Count -gt 0;$earlierButton.Visible=$hasEarlier;$earlierRowsPanel.Visible=$hasEarlier -and $script:earlierExpanded
            if ($hasEarlier) {Set-ControlBox $earlierButton 0 $aY $cw 34;$aY+=34;if ($script:earlierExpanded) {Set-ControlBox $earlierRowsPanel 0 $aY $cw 1;$aY+=(Layout-AnnouncementRows $earlierRowsPanel $script:earlierRows $cw)}}
            $announcementPanel.Height=$aY+10
            Set-ControlBox $historyButton 0 10 $cw 30;$historyButton.Expanded=$script:historyExpanded
            $historyRowsPanel.Visible=$script:historyExpanded;$historyAttribution.Visible=$script:historyExpanded;$historyHeight=50
            if ($script:historyExpanded) {
                Set-ControlBox $historyRowsPanel 0 48 $cw 1;$rowsHeight=Layout-AnnouncementRows $historyRowsPanel $script:historyRows $cw
                if ($script:historyEmpty) {$rowsHeight=Set-WrappedBox $script:historyEmpty 0 0 $cw 22}
                $historyRowsPanel.Height=[Math]::Max(1,$rowsHeight);Set-ControlBox $historyAttribution 0 (48+$rowsHeight+8) $cw 24
                $historyAttribution.Height=[Math]::Max(24,$historyAttribution.GetPreferredSize([Drawing.Size]::new($cw,0)).Height);$historyHeight=$historyAttribution.Bottom+10
            }
            $historyPanel.Height=$historyHeight;Set-ControlBox $sourcesButton 0 10 $cw 30;$sourcesButton.Expanded=$script:sourcesExpanded
            $attribution.Visible=$script:sourcesExpanded;$sourceChecked.Visible=$script:sourcesExpanded -and [bool]$sourceChecked.Text;$sourcesHeight=50
            if ($script:sourcesExpanded) {
                Set-ControlBox $attribution 0 48 $cw 22;$attribution.Height=[Math]::Max(22,$attribution.GetPreferredSize([Drawing.Size]::new($cw,0)).Height);$sourcesHeight=$attribution.Bottom+8
                if ($sourceChecked.Text) {$sourcesHeight+=(Set-WrappedBox $sourceChecked 0 $sourcesHeight $cw 20)+4};$sourcesHeight+=10
            }
            $sourcesPanel.Height=$sourcesHeight;$footerPanel.Height=10+(Set-WrappedBox $cadence 0 10 $cw 20)+12
            $order=@(Get-WidgetDetailSectionOrder ([bool]$script:layoutPlus));$y=0
            foreach ($name in $script:sectionPanels.Keys){$script:sectionPanels[$name].Visible=$name -in $order}
            foreach ($name in $order){$panel=$script:sectionPanels[$name];Set-ControlBox $panel 0 $y $cw $panel.Height;$y+=$panel.Height}
            $body.AutoScrollPosition=[Drawing.Point]::Empty;Set-ControlBox $content $contentInset 0 $cw $y
            if ($script:automaticDetailHeight -and -not $script:historyExpanded -and -not $script:creditsExpanded -and -not $script:earlierExpanded -and -not $script:sourcesExpanded -and -not $script:resizing) {
                $screen=[Windows.Forms.Screen]::FromControl($form).WorkingArea;$fitted=Get-WidgetDetailFittedFrame $form.Bounds ($y+8) $header.height $screen
                if ($form.Bounds -ne $fitted) {$form.Bounds=$fitted;$height=$form.ClientSize.Height;$offset=if ($script:layoutPlus){62}else{0};$script:detailSize=[Drawing.Size]::new($width,($height-$offset));Set-ControlBox $body 7 $header.height ($width-14) ($height-$header.height-10);$script:positionDirty=$true}
            }
            $body.AutoScrollMinSize=[Drawing.Size]::new(0,$y+8);$body.AutoScrollPosition=[Drawing.Point]::new(0,[int]$scrollY);Update-ResizeEdges $width $height $false
        }
        Set-RoundedRegion;$ring.Invalidate()
    } finally {$script:layoutBusy=$false}
}
function Update-DetailFonts {
    # Text stays readable at the minimum width. Wrapped section heights, rather
    # than reduced font sizes or compressed rows, absorb content changes.
    Update-ResponsiveLayout
}
function Set-Layout([bool]$plus) {
    if ($null -ne $script:layoutPlus -and $script:layoutPlus -eq $plus) { return }
    $script:layoutPlus=$plus
    $fivePanel.Visible=$plus
    if ($script:mode -eq 'Detail' -and -not $script:animating) {
        $offset=if ($plus) {62} else {0}
        $form.ClientSize=[Drawing.Size]::new($script:detailSize.Width,$script:detailSize.Height+$offset)
        $screen=[Windows.Forms.Screen]::FromControl($form).WorkingArea
        if ($form.Bottom -gt $screen.Bottom) { $form.Top=[Math]::Max($screen.Top,$screen.Bottom-$form.Height) }
    }
    Update-ResponsiveLayout
}
function Set-ControlTheme($control) {
    $control.BackColor=$script:colors.back
    $control.ForeColor=if ($control.Tag -eq 'strong') {$script:colors.text} elseif ($control.Tag -eq 'warning') {$script:colors.warning} else {$script:colors.muted}
    if ($control -is [WidgetDisclosureButton]) {$control.MutedColor=$script:colors.muted;$control.HoverColor=$script:colors.hover}
    if ($control.Tag -eq 'line') { $control.BackColor=$script:colors.line }
    if ($control -is [Windows.Forms.LinkLabel]) {
        $control.LinkColor=$script:colors.link; $control.ActiveLinkColor=$script:colors.accent; $control.VisitedLinkColor=$script:colors.link
    }
    if ($control -is [Windows.Forms.Button]) {
        $control.FlatAppearance.MouseOverBackColor=$script:colors.hover
        $control.FlatAppearance.MouseDownBackColor=$script:colors.pressed
    }
    foreach ($child in $control.Controls) { Set-ControlTheme $child }
    $control.Invalidate()
}

function Set-Theme {
    $light = if ($Theme -eq 'Light') { $true } elseif ($Theme -eq 'Dark') { $false } else {
        try {
            (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme -eq 1
        } catch { $false }
    }
    if ($light) {
        $script:colors = @{
            back = (New-Color '#F7F8FB'); text = (New-Color '#17202D'); muted = (New-Color '#637083')
            danger=(New-Color '#C24C49'); warning=(New-Color '#916D00'); link=(New-Color '#315969'); accent = (New-Color '#1CA887'); track = (New-Color '#DFE5EB'); line = (New-Color '#DDE3E8'); hover = (New-Color '#EBEEF2'); pressed = (New-Color '#E1E6EC')
        }
    } else {
        $script:colors = @{
            back = (New-Color '#20252D'); text = (New-Color '#F3F5F7'); muted = (New-Color '#A1AAB6')
            danger=(New-Color '#FA7D79'); warning=(New-Color '#F4CF65'); link=(New-Color '#C8DCE5'); accent = (New-Color '#24D3A5'); track = (New-Color '#3D4855'); line = (New-Color '#343D48'); hover = (New-Color '#303944'); pressed = (New-Color '#3B4652')
        }
    }
    Set-ControlTheme $form
    $ring.Invalidate()
    Set-Tray-QuotaIcon
}

function Show-Quota {
    $now = [DateTimeOffset]::UtcNow
    $value = $script:data
    $fiveView=Get-WidgetFiveHourView $value $script:language $now
    Set-Layout $fiveView.visible
    $fiveValue.Text=$fiveView.percentText; $fiveReset.Text=$fiveView.compactResetText
    $valid = $false
    if ($value -and $value.status -eq 'ok') {
        try {
            $age = $now - [DateTimeOffset]::FromUnixTimeMilliseconds([long]$value.updatedAt)
            $resetAt = [DateTimeOffset]::FromUnixTimeSeconds([long]$value.resetsAt)
            $valid = $age.TotalMinutes -le 10 -and $age.TotalSeconds -ge -60 -and $resetAt -gt $now -and
                [double]$value.remainingPercent -ge 0 -and [double]$value.remainingPercent -le 100
        } catch { $valid = $false }
    }
    if ($valid) {
        $script:remaining = [int]$value.remainingPercent
        $span = $resetAt - $now
        $days = [int][Math]::Floor($span.TotalDays)
        $hours = $span.Hours
        $minutes = $span.Minutes
        $countdown.Text = Format-WidgetCountdown $span $script:language
        $reset.Text = (T 'reset' @((Format-WidgetCompactDate $resetAt $script:language)))
        $updated.Text = ''; $updated.Visible=$false
        $cards.Text = if ($null -ne $value.resetCards) { (T 'cards' @($value.resetCards)) } else { (T 'cardsUnknown') }
        $status.Text = Format-WidgetRelativeUpdate $value.updatedAt $script:language $now
        $caption.Text = (T 'untilReset')

    } else {
        $script:remaining = $null
        $countdown.Text = '—'
        $reset.Text = (T 'resetUnknown')
        $updated.Text = if ($value -and $value.status -eq 'ok') { (T 'stale') } else { $script:message }
        $cards.Text = (T 'cardsUnknown')
        $status.Text = if ($value -and $null -ne $value.updatedAt) { Format-WidgetRelativeUpdate $value.updatedAt $script:language $now } else { T 'unavailable' }
        $updated.Visible=$true
        $caption.Text = (T 'untilReset')
    }
    $ringTip = if ($script:mode -eq 'Compact') {
        if ($null -eq $script:remaining) { (T 'tipUnavailable') } else { (T 'tipRemaining' @($script:remaining)) }
    } else { (T 'tipDrag') }
    if ($script:mode -eq 'Compact' -and $script:noticeView.hasUnread) {$ringTip+="`n"+$script:noticeView.tooltip}
    $tooltip.SetToolTip($ring, $ringTip)
    $count=if ($valid -and $null -ne $value.resetCards) {if ($script:language -eq 'zh-CN') {[string]$value.resetCards+'次'} else {[string]$value.resetCards}} else {'—'}
    $cards.Text=(T 'resetLabel')+' '+$count;$cards.TrailingText=T 'disclosureDetails';$cards.AccessibleName=$cards.Text+' · '+(T 'disclosureDetails')
    $tooltip.SetToolTip($cards,(T 'openDetails'));$tooltip.SetToolTip($updated,$updated.Text);$tooltip.SetToolTip($status,$status.Text)
    Update-ResetCreditDetails
    $script:setupCode = if ($value -and $value.errorCode -in @('cli_missing','signed_out')) { [string]$value.errorCode } else { $null }
    if ($setupItem) { $setupItem.Visible = $null -ne $script:setupCode }
    $ring.Invalidate()
    Set-Tray-QuotaIcon
    Show-External
}

function New-ResetCreditControl($record) {
    $panel=New-Object Windows.Forms.Panel;$rule=New-Object Windows.Forms.Panel;$rule.Tag='line'
    $label=New-Label $record.title 0 10 346 22 10.5 $true;$label.Tag='strong'
    $description=New-Label $record.description 0 36 346 22 9.75;$description.Visible=[bool]$record.description
    $granted=New-Label $record.granted 0 62 346 22 9.75;$expires=New-Label $record.expires 0 88 346 22 9.75
    foreach ($control in @($rule,$label,$description,$granted,$expires)){[void]$panel.Controls.Add($control)}
    $panel.Tag=@{rule=$rule;title=$label;description=$description;granted=$granted;expires=$expires};Set-ControlTheme $panel;return $panel
}
function Update-ResetCreditDetails {
    $view=Get-WidgetResetDetailsView $script:data $script:language;$key=$view | ConvertTo-Json -Depth 6 -Compress
    if ($key -cne $script:creditRenderKey) {
        Clear-PanelControls $creditRowsPanel;$script:creditRows=@();$creditNote.Text=$view.note
        foreach ($record in $view.rows){$row=New-ResetCreditControl $record;[void]$creditRowsPanel.Controls.Add($row);$script:creditRows+=,$row}
        Set-ControlTheme $creditDetailsPanel;$script:creditRenderKey=$key
    }
}
function New-ActivityLink([string]$label, [string]$url) {
    $link=New-Object WidgetLinkLabel;$link.Text=$label;$link.Font=[Drawing.Font]::new('Segoe UI',9.75);$link.UseMnemonic=$false;$link.TabStop=$true;$link.LinkBehavior=[Windows.Forms.LinkBehavior]::AlwaysUnderline
    [void]$link.Links.Add(0,$label.Length,$url)
    $link.Add_LinkClicked({param($sender,$e);$target=[string]$e.Link.LinkData;if (Test-WidgetHttpsUrl $target){try{Start-Process -FilePath $target | Out-Null}catch{}}});return $link
}
function New-AnnouncementControl($row) {
    $view=Get-WidgetActivityPresentation $row $script:language;$panel=New-Object Windows.Forms.Panel
    $icon=New-SectionIcon $row.kind;$label=New-Label $view.label 36 10 346 20 9
    $heading=New-Label $view.title 36 30 346 22 11.25 $true;$heading.Tag='strong'
    $fact=New-Label $view.fact 36 54 346 22 10.5;$fact.Visible=[bool]$view.fact;$statusLine=New-Label $view.status 36 80 346 22 9.75;$statusLine.Visible=[bool]$view.status
    $missing=if ($view.missing) {New-Label (T 'completionNotProvided') 36 80 346 22 10.5} else {$null}
    $sourceLink=if ($row.sourceUrl) {New-ActivityLink (T 'announcementSource') $row.sourceUrl} else {$null}
    $more=$null;$extraPanel=$null;$key=if ($row.key) {[string]$row.key} else {[string]$row.sortAt+'/'+[string]$row.title}
    if ($view.extra -or $row.deliverySourceUrl) {
        $more=New-DisclosureButton '' 'record-details-toggle';$more.Text=T $(if ($row.kind -eq 'recovery') {'recoveryMore'} else {'moreMessage'});$oldFont=$more.Font;$more.Font=[Drawing.Font]::new('Segoe UI',9.75,[Drawing.FontStyle]::Underline);$oldFont.Dispose();$more.ShowChevron=$false;$more.Tag=@{key=$key}
        $more.Add_Click({param($sender,$e);$key=$sender.Tag.key;$script:recordExpanded[$key]=-not [bool]$script:recordExpanded[$key];Update-ResponsiveLayout})
        $extraPanel=New-Object Windows.Forms.Panel
        if ($view.extra){$extra=New-Label $view.extra 0 0 346 24 9.75;[void]$extraPanel.Controls.Add($extra)}
        if ($row.deliverySourceUrl){[void]$extraPanel.Controls.Add((New-ActivityLink (T 'deliverySource') $row.deliverySourceUrl))}
    }
    foreach ($control in @($icon,$label,$heading,$fact,$statusLine,$missing,$sourceLink,$more,$extraPanel) | Where-Object {$_}){[void]$panel.Controls.Add($control)}
    $panel.Add_Paint({param($sender,$e);$pen=[Drawing.Pen]::new($script:colors.line,1);try{$e.Graphics.DrawLine($pen,0,$sender.Height-1,$sender.Width,$sender.Height-1)}finally{$pen.Dispose()}})
    $panel.Tag=@{key=$key;icon=$icon;label=$label;title=$heading;fact=$fact;status=$statusLine;missing=$missing;source=$sourceLink;more=$more;extraPanel=$extraPanel};Set-ControlTheme $panel;return $panel
}
function Get-ControlOwnedFonts($control) {
    if ($control -is [Windows.Forms.Label] -or $control -is [Windows.Forms.Button]) {$control.Font}
    foreach ($child in $control.Controls){Get-ControlOwnedFonts $child}
}
function Clear-PanelControls($panel) {
    foreach ($control in @($panel.Controls)) {
        $fonts=@(Get-ControlOwnedFonts $control);$panel.Controls.Remove($control);$control.Dispose();foreach ($font in $fonts){$font.Dispose()}
    }
}
function Show-External {
    $view=Get-WidgetResetActivityView $script:data $script:externalData $script:language ([DateTimeOffset]::UtcNow)
    $partition=Get-WidgetActivityPartition $view.active
    $script:activityView=[pscustomobject]@{featured=$partition.featured;earlier=$partition.earlier;history=$view.history}
    $script:visibleActivityView=Get-WidgetVisibleActivityView $script:activityView $script:earlierExpanded $script:historyExpanded
    $key=$view | ConvertTo-Json -Depth 8 -Compress
    if ($key -cne $script:announcementRenderKey) {
        foreach ($panel in @($activityRowsPanel,$earlierRowsPanel,$historyRowsPanel)){Clear-PanelControls $panel}
        $script:announcementRows=@();$script:earlierRows=@();$script:historyRows=@();$script:historyEmpty=$null
        foreach ($row in $partition.featured){$panel=New-AnnouncementControl $row;[void]$activityRowsPanel.Controls.Add($panel);$script:announcementRows+=,$panel}
        foreach ($row in $partition.earlier){$panel=New-AnnouncementControl $row;[void]$earlierRowsPanel.Controls.Add($panel);$script:earlierRows+=,$panel}
        foreach ($row in $view.history){$panel=New-AnnouncementControl $row;[void]$historyRowsPanel.Controls.Add($panel);$script:historyRows+=,$panel}
        if (-not $view.history.Count){$script:historyEmpty=New-Label (T 'historyEmpty') 0 0 346 24 10.5;[void]$historyRowsPanel.Controls.Add($script:historyEmpty)}
        foreach ($panel in @($activityRowsPanel,$earlierRowsPanel,$historyRowsPanel)){Set-ControlTheme $panel};$script:announcementRenderKey=$key
    }
    $script:activityIsEmpty=$view.active.Count -eq 0
    $activityHeading.Text=T 'activityHeading';$localTimeNote.Text=Get-WidgetLocalTimeNote $script:language
    $activityEmpty.Text=T 'activityEmpty';$activityEmptyHelp.Text=T 'activityEmptyHelp'
    $notice=Get-WidgetPublicNoticeView $script:externalData $script:language
    $publicStatusPanel.Visible=$notice.visible;$publicStatusTitle.Text=T $(if ($notice.failed){'publicRefreshFailed'}else{'publicStale'})
    $publicStatusText.Text=T $(if ($notice.hasCache){'publicCache'}else{'publicNoCache'});$publicStatusFetched.Text=$notice.lastFetchedText;$publicStatusFetched.Visible=[bool]$publicStatusFetched.Text;$sourceChecked.Text=$notice.lastFetchedText
    $publicRetry.Text=T $(if ($script:externalTask -and -not $script:externalTask.IsCompleted){'publicRetrying'}else{'publicRetry'});$publicRetry.Enabled=$null -eq $script:externalTask
    $recoveryWarning.Text=if ($script:data.recoveryHistory.status -eq 'unsaved'){T 'recoveryUnsaved'}else{''};$recoveryWarning.Visible=[bool]$recoveryWarning.Text
    $earlierButton.Text=T 'earlierUpdates' @($partition.earlier.Count);$earlierButton.Expanded=$script:earlierExpanded
    $historyButton.Text=T 'announcementHistory';$historyButton.AccessibleName=T $(if ($script:historyExpanded){'collapseHistory'}else{'expandHistory'});$historyLabel.Text=T 'historyAttribution'
    $sourcesButton.Text=T 'dataSources';$sourcesButton.AccessibleName=$sourcesButton.Text;Set-AttributionLinks (T 'sourceLinks');$cadence.Text=T 'refreshCadence'
    Update-ResponsiveLayout;Update-AnnouncementIndicator;Start-AnnouncementRead
}
function Set-AttributionLinks([string]$text) {$attribution.AccessibleName=$text}
function Toggle-ResetDetails {$script:creditsExpanded=-not $script:creditsExpanded;Update-ResetCreditDetails;Update-ResponsiveLayout}
function Toggle-DataSources {$script:sourcesExpanded=-not $script:sourcesExpanded;Update-ResponsiveLayout}
function Start-PublicRetry {
    if ($script:externalTask){return}
    try {$script:externalRequestContent=[Net.Http.StringContent]::new('');$script:externalTask=$script:client.PostAsync(($script:baseUrl+'/api/external/refresh'),$script:externalRequestContent);$script:nextExternalPoll=[DateTime]::UtcNow.AddSeconds(60);$publicRetry.Enabled=$false;$publicRetry.Text=T 'publicRetrying'}catch{if($script:externalRequestContent){$script:externalRequestContent.Dispose();$script:externalRequestContent=$null};$script:externalTask=$null;Show-External}
}

function Start-SettingsRequest {
    if ($script:settingsTask -and -not $script:settingsTask.IsCompleted) { return }
    try { $script:settingsTask = $script:client.GetAsync("$script:baseUrl/api/settings") } catch { }
}
function Save-WidgetLanguage([string]$setting) {
    try {
        $body = @{ language = $setting } | ConvertTo-Json -Compress
        $result = Invoke-RestMethod -Uri "$script:baseUrl/api/settings" -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 3
        if ($result.language -notin @('auto','en','zh-CN')) { throw 'Invalid settings response' }
        $script:languageSetting = [string]$result.language
        Set-Language
    } catch {
        [void][Windows.Forms.MessageBox]::Show((T 'languageSaveFailed'), (T 'app'), [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning)
    }
}
function Set-Language {
    $script:language = Resolve-WidgetLanguage $script:languageSetting
    $form.Text = T 'app'; $title.Text = T 'app'; $fiveTitle.Text = T 'fiveHour'
    $refresh.AccessibleName=T 'tipRefresh'; $compactButton.AccessibleName=T 'tipCompact'; $close.AccessibleName=T 'tipHide'
    $showItem.Text = T 'show'; $modeItem.Text = T 'mode'; $hideItem.Text = T 'hide'; $refreshItem.Text = T 'refreshNow'; $topItem.Text = T 'onTop'; $exitItem.Text = T 'quit'
    $languageMenu.Text = T 'language'; $autoLanguageItem.Text = T 'languageAuto'; $englishLanguageItem.Text = T 'languageEn'; $chineseLanguageItem.Text = T 'languageZh'
    foreach ($item in @($autoLanguageItem,$englishLanguageItem,$chineseLanguageItem)) { $item.Checked = $item.Tag -eq $script:languageSetting }
    $detailsItem.Text = T 'openDetails'; $setupItem.Text = T 'setup'
    $tooltip.SetToolTip($refresh, (T 'tipRefresh')); $tooltip.SetToolTip($close, (T 'tipHide')); $tooltip.SetToolTip($compactButton, (T 'tipCompact'))
    foreach ($zone in $script:resizeEdges.Values) { $tooltip.SetToolTip($zone, (T 'tipResize')) }

    $script:message = if ($script:data) { Get-WidgetErrorText ([string]$script:data.errorCode) $script:language } else { T 'service_unavailable' }
    $script:trayIconKey = ''
    Show-Quota; Show-External
}
function Show-ResetDetails {
    $script:creditsExpanded=$true;$form.Show();$form.Activate();Update-ResetCreditDetails
    if ($script:mode -eq 'Compact') {Start-ModeTransition 'Detail'} else {Update-ResponsiveLayout;$body.ScrollControlIntoView($creditsPanel)}
}
function Show-Setup {
    if ($script:setupCode -eq 'cli_missing') {
        [void][Windows.Forms.MessageBox]::Show((T 'installHelp'), (T 'setup'))
        Start-Process 'https://developers.openai.com/codex/cli/'
    } else { [void][Windows.Forms.MessageBox]::Show((T 'signInHelp'), (T 'setup')) }
}

function Update-AnnouncementIndicator {
    $script:noticeView=Get-WidgetAnnouncementAlertView $script:externalData.announcementAlerts $script:language
    if ($script:mode -eq 'Compact') {
        $tip=if ($null -eq $script:remaining) {T 'tipUnavailable'} else {T 'tipRemaining' @($script:remaining)}
        if ($script:noticeView.hasUnread) {$tip+="`n"+$script:noticeView.tooltip}
        $tooltip.SetToolTip($ring,$tip); $ring.AccessibleName=$tip
    }
    $ring.Invalidate()
}
function Start-AnnouncementRead {
    if ($script:announcementReadTask -or $script:animating -or $script:mode -ne 'Detail' -or -not $form.Visible) {return}
    $ids=Get-WidgetAnnouncementReadIds $script:noticeView $script:visibleActivityView $true
    if (-not $ids.Count) {return}
    try {
        $json=@{ids=@($ids)} | ConvertTo-Json -Compress
        $script:announcementReadContent=[Net.Http.StringContent]::new($json,[Text.Encoding]::UTF8,'application/json')
        $script:announcementReadTask=$script:client.PostAsync("$script:baseUrl/api/announcement-alerts/read",$script:announcementReadContent)
    } catch {
        if ($script:announcementReadContent) {$script:announcementReadContent.Dispose();$script:announcementReadContent=$null}
        $script:announcementReadTask=$null
    }
}
function Start-ExternalRequest {
    if ($script:externalTask) { return }
    try {
        $script:externalTask = $script:client.GetAsync("$script:baseUrl/api/external")
        $script:nextExternalPoll = [DateTime]::UtcNow.AddSeconds(60)
    } catch {
        $script:externalTask = $null
        $script:externalData = Merge-WidgetExternalData $script:externalData $null $true
        Save-PublicSnapshot
        $script:nextExternalPoll = [DateTime]::UtcNow.AddSeconds(60)
        Show-External
    }
}

function Start-Request([bool]$manual) {
    if ($script:requestTask -and -not $script:requestTask.IsCompleted) { if ($manual) { $script:queuedManual = $true }; return }
    try {
        $script:requestManual = $manual
        $script:requestTask = if ($manual) {
            $content = New-Object System.Net.Http.StringContent('')
            $script:client.PostAsync("$script:baseUrl/api/refresh", $content)
        } else {
            $script:client.GetAsync("$script:baseUrl/api/usage")
        }
        $script:nextPoll = [DateTime]::UtcNow.AddSeconds(60)
        Start-SettingsRequest
        $status.Text = if ($script:data -and $null -ne $script:data.updatedAt) { Format-WidgetRelativeUpdate $script:data.updatedAt $script:language } else { T 'refreshing' }
    } catch {
        $script:requestTask = $null
        $script:data = $null
        $script:message = (T 'service_unavailable')
        Show-Quota
    }
}

function Set-Tray-QuotaIcon {
    if (-not $script:tray -or -not $script:colors.accent) { return }
    $key = "$(if ($null -eq $script:remaining) { '?' } else { $script:remaining })/$($script:colors.accent.ToArgb())"
    if ($key -eq $script:trayIconKey) { return }
    $bitmap = [System.Drawing.Bitmap]::new(32, 32)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $trackPen = $null; $arcPen = $null; $backBrush = $null; $textBrush = $null; $font = $null; $format = $null
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $backBrush = [System.Drawing.SolidBrush]::new($script:colors.back)
        $textBrush = [System.Drawing.SolidBrush]::new($script:colors.text)
        $trackPen = [System.Drawing.Pen]::new($script:colors.track, 3)
        $arcPen = [System.Drawing.Pen]::new($script:colors.accent, 3)
        $graphics.FillEllipse($backBrush, 0, 0, 31, 31)
        $graphics.DrawArc($trackPen, 3, 3, 25, 25, 0, 360)
        if ($null -ne $script:remaining -and $script:remaining -gt 0) {
            $graphics.DrawArc($arcPen, 3, 3, 25, 25, -90, (360 * $script:remaining / 100))
        }
        $text = if ($null -eq $script:remaining) { '—' } else { [string]$script:remaining }
        $size = if ($text.Length -ge 3) { 10 } else { 12 }
        $font = [System.Drawing.Font]::new('Segoe UI', $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $format = [System.Drawing.StringFormat]::new()
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $graphics.DrawString($text, $font, $textBrush, [System.Drawing.RectangleF]::new(3, 3, 26, 26), $format)
        $handle = $bitmap.GetHicon()
        try { $icon = [System.Drawing.Icon]::FromHandle($handle).Clone() }
        finally { [void][WidgetDrag]::DestroyIcon($handle) }
        $old = $script:ownedTrayIcon
        $script:tray.Icon = $icon
        $script:ownedTrayIcon = $icon
        if ($old) { $old.Dispose() }
        $script:tray.Text = if ($null -eq $script:remaining) { (T 'trayUnavailable') } else { (T 'trayRemaining' @($script:remaining)) }
        $script:trayIconKey = $key
    } finally {
        foreach ($resource in @($trackPen, $arcPen, $backBrush, $textBrush, $font, $format, $graphics, $bitmap)) {
            if ($resource) { $resource.Dispose() }
        }
    }
}

function Save-PublicSnapshot {
    try { Write-WidgetJson $script:externalCachePath $script:externalData } catch { }
}
$script:outsideClickAction = [Action[Drawing.Point]]{
    param($point)
    $physicalBounds = [WidgetOutsideClick]::GetPhysicalBounds($form)
    if (-not $physicalBounds.IsEmpty -and (Test-WidgetOutsideClick $script:mode $form.Visible $script:animating $physicalBounds $point)) {
        if ($script:resizing) { return }
        Start-ModeTransition 'Compact'
    }
}
function Update-OutsideClickMonitor {
    if ($form.Visible -and $script:mode -eq 'Detail' -and -not $script:animating -and -not $script:reallyExit) {
        [WidgetOutsideClick]::Enable($form,$script:outsideClickAction)
    } else { [WidgetOutsideClick]::Disable() }
}
function Set-ModeVisual([bool]$compact) {
    foreach ($control in $script:detailControls) { $control.Visible=-not $compact }
    foreach ($zone in $script:resizeEdges.Values) { $zone.Visible=$true }
    $tooltip.SetToolTip($ring,$(if ($compact) {T 'tipExpand'} else {T 'tipDrag'}))
    Update-ResponsiveLayout
    Update-AnnouncementIndicator
    Start-AnnouncementRead
    Update-OutsideClickMonitor
}

function Start-ModeTransition([string]$nextMode) {
    if ($script:animating -or $script:mode -eq $nextMode) { return }
    [WidgetOutsideClick]::Disable()
    $compact = $nextMode -eq 'Compact'
    $size = if ($compact) { $script:compactSize } else { [System.Drawing.Size]::new($script:detailSize.Width, ($script:detailSize.Height + $(if ($script:layoutPlus) { 62 } else { 0 }))) }
    $script:modePositions[$script:mode] = [pscustomobject]@{ x = $form.Left; y = $form.Top }
    $remembered = $script:modePositions[$nextMode]
    $screen = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    if ($remembered) {
        foreach ($display in [System.Windows.Forms.Screen]::AllScreens) {
            if ($display.WorkingArea.Contains([Drawing.Point]::new($remembered.x, $remembered.y))) { $screen = $display.WorkingArea; break }
        }
    }
    $placement = Get-WidgetTransitionPosition $form $remembered $size $screen
    $script:animationFrom = $form.Bounds
    $script:animationTo = [System.Drawing.Rectangle]::new($placement.x, $placement.y, $size.Width, $size.Height)
    $ringOrigin=$form.PointToClient($ring.Parent.PointToScreen($ring.Location))
    $ring.Parent=$form; $ring.Location=$ringOrigin; $ring.BringToFront()
    $script:ringFrom = $ring.Bounds
    if ($compact) {
        $targetRingSize = [Math]::Max(38, [Math]::Min($size.Width - 10, $size.Height - 20))
        $script:ringTo = [System.Drawing.Rectangle]::new([int](($size.Width - $targetRingSize) / 2), [int](($size.Height - $targetRingSize) / 2), [int]$targetRingSize, [int]$targetRingSize)
    } else {
        $targetHeader=Get-WidgetHeaderLayout $size.Width ([Windows.Forms.TextRenderer]::MeasureText($title.Text,$title.Font).Width+6) ([Windows.Forms.TextRenderer]::MeasureText($status.Text,$status.Font).Width+6)
        $targetMetrics=Get-WidgetDetailMetrics $size.Width
        $script:ringTo=[Drawing.Rectangle]::new($targetMetrics.inset,$targetHeader.height+10,$targetMetrics.ring,$targetMetrics.ring)
    }
    if (-not $compact) { $body.AutoScrollPosition=[Drawing.Point]::Empty }
    $script:targetMode = $nextMode
    $script:animationStart = [DateTime]::UtcNow
    $script:animating = $true
    foreach ($control in $script:detailControls) { $control.Visible = $false }
    foreach ($zone in $script:resizeEdges.Values) { $zone.Visible = $false }
    $script:animationTimer.Start()
}

$script:animationTimer = New-Object System.Windows.Forms.Timer
$script:animationTimer.Interval = 16
$script:animationTimer.Add_Tick({
    $t = [Math]::Min(1, ([DateTime]::UtcNow - $script:animationStart).TotalMilliseconds / 260)
    $ease = 1 - [Math]::Pow((1 - $t), 3)
    $from = $script:animationFrom; $to = $script:animationTo
    $form.Bounds = [System.Drawing.Rectangle]::new(
        [int][Math]::Round($from.X + ($to.X - $from.X) * $ease),
        [int][Math]::Round($from.Y + ($to.Y - $from.Y) * $ease),
        [int][Math]::Round($from.Width + ($to.Width - $from.Width) * $ease),
        [int][Math]::Round($from.Height + ($to.Height - $from.Height) * $ease))
    $ringFrom = $script:ringFrom; $ringTo = $script:ringTo
    $ring.Bounds = [System.Drawing.Rectangle]::new(
        [int][Math]::Round($ringFrom.X + ($ringTo.X - $ringFrom.X) * $ease),
        [int][Math]::Round($ringFrom.Y + ($ringTo.Y - $ringFrom.Y) * $ease),
        [int][Math]::Round($ringFrom.Width + ($ringTo.Width - $ringFrom.Width) * $ease),
        [int][Math]::Round($ringFrom.Height + ($ringTo.Height - $ringFrom.Height) * $ease))
    $form.Opacity = 0.92 + 0.08 * $ease
    Set-RoundedRegion
    $ring.Invalidate()
    if ($t -ge 1) {
        $script:animationTimer.Stop()
        $script:mode = $script:targetMode
        $script:animating = $false
        $form.Opacity = 1
        Set-ModeVisual ($script:mode -eq 'Compact')
        $script:positionDirty = $true
    }
})

$refresh.Add_Click({ Start-Request $true })
$compactButton.Add_Click({ Start-ModeTransition 'Compact' })
$close.Add_Click({ $form.Hide() })

foreach ($sourceLink in $script:attributionSiteLinks) {
$sourceLink.Add_LinkClicked({
    param($sender, $e)
    $url = [string]$e.Link.LinkData
    if ($url -in @('https://codexreset.ai/', 'https://whenreset.app/')) {
        try { Start-Process -FilePath $url | Out-Null } catch { }
    }
})
}
$drag = {
    param($sender, $e)
    if ($script:mode -eq 'Detail' -and -not $script:animating -and $e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [void][WidgetDrag]::ReleaseCapture()
        [void][WidgetDrag]::SendMessage($form.Handle, 0xA1, 2, [IntPtr]::Zero)
    }
}
foreach ($control in @($form,$title,$status,$ring,$caption,$countdown,$reset,$updated,$heroPanel,$fiveTitle,$fiveValue,$fiveReset)) {
    $control.Add_MouseDown($drag)
}
$compactDown = {
    param($sender, $e)
    if ($script:mode -ne 'Compact' -or $script:animating -or $e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $script:compactDragging = $true
    $script:compactMoved = $false
    $script:dragStart = [System.Windows.Forms.Cursor]::Position
    $script:dragOrigin = $form.Location
}
$compactMove = {
    if (-not $script:compactDragging) { return }
    $cursor = [System.Windows.Forms.Cursor]::Position
    $dx = $cursor.X - $script:dragStart.X
    $dy = $cursor.Y - $script:dragStart.Y
    if ([Math]::Abs($dx) + [Math]::Abs($dy) -ge 5) { $script:compactMoved = $true }
    if ($script:compactMoved) {
        $screen = [System.Windows.Forms.Screen]::FromPoint($cursor).WorkingArea
        $x = [Math]::Max($screen.Left, [Math]::Min($script:dragOrigin.X + $dx, $screen.Right - $form.Width))
        $y = [Math]::Max($screen.Top, [Math]::Min($script:dragOrigin.Y + $dy, $screen.Bottom - $form.Height))
        $form.Location = [System.Drawing.Point]::new([int]$x, [int]$y)
    }
}
$compactUp = {
    param($sender, $e)
    if (-not $script:compactDragging -or $e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $script:compactDragging = $false
    if (-not $script:compactMoved) { Start-ModeTransition 'Detail' }
}
foreach ($control in @($form, $ring)) {
    $control.Add_MouseDown($compactDown)
    $control.Add_MouseMove($compactMove)
    $control.Add_MouseUp($compactUp)
}
function Complete-Resize {
    if (-not $script:resizing) { return }
    $script:resizing = $false
    if ($script:resizeControl.Capture) { $script:resizeControl.Capture = $false }
    if ($script:mode -eq 'Compact') {
        $script:compactSize = $form.ClientSize
    } else {
        $offset = if ($script:layoutPlus) { 62 } else { 0 }
        $script:detailSize = [System.Drawing.Size]::new($form.ClientSize.Width, ($form.ClientSize.Height - $offset))
        Update-DetailFonts
    }
    $script:positionDirty = $true
}

$resizeDown = {
    param($sender, $e)
    if ($script:animating -or $e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    if ($script:mode -eq 'Detail') { $script:automaticDetailHeight=$false }
    $script:resizing = $true
    $script:resizeControl = $sender
    $script:resizeDirection = [string]$sender.Tag
    $script:resizeStart = [System.Windows.Forms.Cursor]::Position
    $script:resizeOrigin = $form.Bounds
    $script:resizeScreen = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $sender.Capture = $true
}
$resizeMove = {
    param($sender, $e)
    if (-not $script:resizing -or $sender -ne $script:resizeControl) { return }
    $cursor = [System.Windows.Forms.Cursor]::Position
    $dx = $cursor.X - $script:resizeStart.X
    $dy = $cursor.Y - $script:resizeStart.Y
    $origin = $script:resizeOrigin
    $screen = $script:resizeScreen
    $direction = $script:resizeDirection
    $compact = $script:mode -eq 'Compact'
    $offset = if ($script:layoutPlus) { 62 } else { 0 }
    $minWidth = if ($compact) { 48 } else { 404 }
    $minHeight = if ($compact) { 64 } else { 390 + $offset }
    $maxWidth = if ($compact) { 160 } else { 720 }
    $maxHeight = if ($compact) { 200 } else { 650 + $offset }
    $left = $origin.Left; $right = $origin.Right
    $top = $origin.Top; $bottom = $origin.Bottom
    if ($direction.Contains('Left')) {
        $left = [Math]::Max($screen.Left, [Math]::Max(($right - $maxWidth), [Math]::Min(($origin.Left + $dx), ($right - $minWidth))))
    } elseif ($direction.Contains('Right')) {
        $right = [Math]::Min($screen.Right, [Math]::Min(($left + $maxWidth), [Math]::Max(($origin.Right + $dx), ($left + $minWidth))))
    }
    if ($direction.Contains('Top')) {
        $top = [Math]::Max($screen.Top, [Math]::Max(($bottom - $maxHeight), [Math]::Min(($origin.Top + $dy), ($bottom - $minHeight))))
    } elseif ($direction.Contains('Bottom')) {
        $bottom = [Math]::Min($screen.Bottom, [Math]::Min(($top + $maxHeight), [Math]::Max(($origin.Bottom + $dy), ($top + $minHeight))))
    }
    $form.Bounds = [System.Drawing.Rectangle]::new([int]$left, [int]$top, [int]($right - $left), [int]($bottom - $top))
}
$resizeUp = {
    param($sender, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $sender -eq $script:resizeControl) { Complete-Resize }
}
$resizeCaptureChanged = {
    param($sender, $e)
    if ($script:resizing -and $sender -eq $script:resizeControl -and -not $sender.Capture) { Complete-Resize }
}
foreach ($zone in $script:resizeEdges.Values) {
    $zone.Add_MouseDown($resizeDown)
    $zone.Add_MouseMove($resizeMove)
    $zone.Add_MouseUp($resizeUp)
    $zone.Add_MouseCaptureChanged($resizeCaptureChanged)
}
$form.Add_SizeChanged({ Update-ResponsiveLayout })

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$showItem = $menu.Items.Add((T 'show'))
$modeItem = $menu.Items.Add((T 'mode'))
$hideItem = $menu.Items.Add((T 'hide'))
$refreshItem = $menu.Items.Add((T 'refreshNow'))
$topItem = $menu.Items.Add((T 'onTop'))
$topItem.Checked = $form.TopMost

$detailsItem = $menu.Items.Add((T 'openDetails'))
$detailsItem.Add_Click({ Show-ResetDetails })
$setupItem = $menu.Items.Add((T 'setup'))
$setupItem.Visible = $false
$setupItem.Add_Click({ Show-Setup })
$languageMenu = New-Object Windows.Forms.ToolStripMenuItem((T 'language'))
$autoLanguageItem = $languageMenu.DropDownItems.Add((T 'languageAuto')); $autoLanguageItem.Tag = 'auto'
$englishLanguageItem = $languageMenu.DropDownItems.Add((T 'languageEn')); $englishLanguageItem.Tag = 'en'
$chineseLanguageItem = $languageMenu.DropDownItems.Add((T 'languageZh')); $chineseLanguageItem.Tag = 'zh-CN'
foreach ($item in @($autoLanguageItem,$englishLanguageItem,$chineseLanguageItem)) { $item.Add_Click({ param($sender,$e) Save-WidgetLanguage ([string]$sender.Tag) }) }
[void]$menu.Items.Add($languageMenu)

[void]$menu.Items.Add('-')
$exitItem = $menu.Items.Add((T 'quit'))
$showItem.Add_Click({ $form.Show(); $form.Activate(); Start-Request $true })
$modeItem.Add_Click({
    $form.Show(); $form.Activate()
    if ($script:mode -eq 'Compact') { Start-ModeTransition 'Detail' } else { Start-ModeTransition 'Compact' }
})
$hideItem.Add_Click({ $form.Hide() })
$refreshItem.Add_Click({ Start-Request $true; $form.Show(); $form.Activate() })
$topItem.Add_Click({ $form.TopMost = -not $form.TopMost; $topItem.Checked = $form.TopMost; $script:positionDirty = $true })
$exitItem.Add_Click({
    $stopScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Stop.ps1'))
    $powershell = (Get-Command powershell.exe).Source
    Start-Process -FilePath $powershell `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $stopScript + '"')) `
        -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null
    $script:reallyExit = $true
    $form.Close()
})
$form.ContextMenuStrip = $menu
$ring.ContextMenuStrip = $menu
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Icon = [System.Drawing.SystemIcons]::Information
$script:tray.Text = (T 'app')
$script:tray.ContextMenuStrip = $menu
$script:tray.Visible = $true
$script:tray.Add_DoubleClick({ $form.Show(); $form.Activate(); Start-Request $true })
function Save-WindowPosition {
    if ($script:animating) { return }
    $script:modePositions[$script:mode] = [pscustomobject]@{ x = $form.Left; y = $form.Top }
    Write-WidgetJson $script:positionPath @{
        x = $form.Left; y = $form.Top; mode = $script:mode
        compactX = $script:modePositions.Compact.x; compactY = $script:modePositions.Compact.y
        detailX = $script:modePositions.Detail.x; detailY = $script:modePositions.Detail.y
        compactWidth = $script:compactSize.Width; compactHeight = $script:compactSize.Height
        detailWidth = $script:detailSize.Width; detailHeight = $script:detailSize.Height
        topMost = $form.TopMost
        detailAutoHeight = $script:automaticDetailHeight; detailLayoutVersion = 4
    }
    $script:positionDirty = $false
    $script:lastPositionSave = [DateTime]::UtcNow
}
$form.Add_FormClosing({
    param($sender, $e)
    Save-WindowPosition
    if (-not $script:reallyExit) { $e.Cancel = $true; $form.Hide() }
})
$form.Add_LocationChanged({ $script:positionDirty = $true })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$script:lastTick = [DateTime]::UtcNow
$timer.Add_Tick({
    $tickNow = [DateTime]::UtcNow
    if ([WidgetPower]::ConsumeResume() -or ($tickNow - $script:lastTick).TotalSeconds -gt 10) { Start-Request $true; Start-ExternalRequest }
    $script:lastTick = $tickNow
    $quitRequest = Join-Path $script:dataDirectory 'quit.request'
    if (Test-Path -LiteralPath $quitRequest) {
        Remove-Item -LiteralPath $quitRequest -ErrorAction SilentlyContinue
        $script:reallyExit = $true; $form.Close(); return
    }
    if (Test-Path -LiteralPath $script:showRequest) {
        Remove-Item -LiteralPath $script:showRequest -ErrorAction SilentlyContinue
        $form.Show()
        $form.Activate()
        Start-Request $true
        Start-ExternalRequest
    }
    if ($script:requestTask -and $script:requestTask.IsCompleted) {
        try {
            $response = $script:requestTask.GetAwaiter().GetResult()
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $json = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $script:data = $json | ConvertFrom-Json
                $script:message = Get-WidgetErrorText ([string]$script:data.errorCode) $script:language
            } finally { $response.Dispose() }
        } catch {
            $script:data = $null
            $script:message = (T 'service_unavailable')
        }
        $script:requestTask = $null
        Show-Quota
        if ($script:requestManual) { Start-ExternalRequest }
        $script:requestManual = $false
        if ($script:queuedManual) { $script:queuedManual = $false; Start-Request $true }
    }
    if ($script:settingsTask -and $script:settingsTask.IsCompleted) {
        try {
            $response = $script:settingsTask.GetAwaiter().GetResult()
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $settings = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                if ($settings.language -in @('auto','en','zh-CN') -and ($settings.language -ne $script:languageSetting -or (Resolve-WidgetLanguage $settings.language) -ne $script:language)) {
                    $script:languageSetting = [string]$settings.language; Set-Language
                }
            } finally { $response.Dispose() }
        } catch { }
        $script:settingsTask = $null
    }
    if ($script:announcementReadTask -and $script:announcementReadTask.IsCompleted) {
        try {
            $response=$script:announcementReadTask.GetAwaiter().GetResult()
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $alerts=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
                $script:externalData | Add-Member -NotePropertyName announcementAlerts -NotePropertyValue $alerts -Force
                Save-PublicSnapshot
                Update-AnnouncementIndicator
            } finally {$response.Dispose()}
        } catch { }
        finally {
            if ($script:announcementReadContent) {$script:announcementReadContent.Dispose();$script:announcementReadContent=$null}
            $script:announcementReadTask=$null
        }
    }
    if ($script:externalTask -and $script:externalTask.IsCompleted) {
        try {
            $response = $script:externalTask.GetAwaiter().GetResult()
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $incoming=($response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json)
                $script:externalData=Merge-WidgetExternalData $script:externalData $incoming $false
            } finally { $response.Dispose() }
        } catch { $script:externalData=Merge-WidgetExternalData $script:externalData $null $true }
        if ($script:externalRequestContent) {$script:externalRequestContent.Dispose();$script:externalRequestContent=$null}
        $script:externalTask = $null
        Save-PublicSnapshot
        Show-External
    }
    $now = [DateTime]::UtcNow
    if ($script:positionDirty -and -not $script:animating -and ($now - $script:lastPositionSave).TotalSeconds -ge 1) {
        Save-WindowPosition
    }
    if (-not $script:requestTask -and $now -ge $script:nextPoll) { Start-Request $false }
    if (-not $script:externalTask -and $now -ge $script:nextExternalPoll) { Start-ExternalRequest }
    if (($now - $script:lastRender).TotalSeconds -ge 30) { Show-Quota; Show-External; $script:lastRender = $now }
    if (($now - $script:lastThemeCheck).TotalMinutes -ge 1) { Set-Theme; $script:lastThemeCheck = $now }
})

$form.Add_VisibleChanged({if ($form.Visible) {Update-ResponsiveLayout;Start-AnnouncementRead}; Update-OutsideClickMonitor})
$form.Add_Shown({
    if ($script:mode -eq 'Compact') {
        $form.Bounds = [System.Drawing.Rectangle]::new($form.Left, $form.Top, $script:compactSize.Width, $script:compactSize.Height)
        Set-RoundedRegion
    }
    Start-Request $true
    Start-ExternalRequest
})
$form.Add_FormClosed({
    [WidgetOutsideClick]::Disable()
    $timer.Stop()
    $script:animationTimer.Stop()
    $script:tray.Visible = $false
    $script:tray.Dispose()
    if ($script:ownedTrayIcon) { $script:ownedTrayIcon.Dispose() }

    $client.Dispose()
    if ($script:externalRequestContent) {$script:externalRequestContent.Dispose()}
})
Set-Theme
Show-Quota
Show-External
Set-ModeVisual ($script:mode -eq 'Compact')
Set-Language
# The event handler only sets a thread-safe flag; the UI timer consumes it.
[WidgetPower]::Enable()
$timer.Start()
try { [System.Windows.Forms.Application]::Run($form) }
finally { [WidgetOutsideClick]::Disable(); [WidgetPower]::Disable() }
