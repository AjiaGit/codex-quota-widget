param(
    [ValidateSet('System', 'Light', 'Dark')]
    [string]$Theme = 'System',
    [ValidatePattern('^http://127\.0\.0\.1:\d+$')]
    [string]$BaseUrl = 'http://127.0.0.1:39224'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WidgetDrag {
    [DllImport("user32.dll")] public static extern bool ReleaseCapture();
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr hIcon);
}
'@

[System.Windows.Forms.Application]::EnableVisualStyles()
$script:baseUrl = $BaseUrl
$script:showRequest = Join-Path (Join-Path $env:TEMP 'CodexWeeklyMonitor') 'show.request'
$script:positionPath = Join-Path (Join-Path $env:TEMP 'CodexWeeklyMonitor') 'window.json'
$script:positionDirty = $false
$script:lastPositionSave = [DateTime]::MinValue
$script:client = New-Object System.Net.Http.HttpClient
$script:client.Timeout = [TimeSpan]::FromSeconds(25)
$script:requestTask = $null
$script:requestManual = $false
$script:externalTask = $null
$script:externalData = $null
$script:nextExternalPoll = [DateTime]::MinValue
$script:nextPoll = [DateTime]::MinValue
$script:lastRender = [DateTime]::MinValue
$script:lastThemeCheck = [DateTime]::MinValue
$script:data = $null
$script:remaining = $null
$script:message = '正在读取'
$script:reallyExit = $false
$script:colors = @{}
$script:layoutPlus = $null
$script:mode = 'Detail'
$script:animating = $false
$script:targetMode = 'Detail'
$script:compactDragging = $false
$script:compactMoved = $false
$script:resizing = $false
$script:trayIconKey = ''
$script:ownedTrayIcon = $null
$script:compactSize = [System.Drawing.Size]::new(52, 76)
$script:detailSize = [System.Drawing.Size]::new(404, 390)

function New-Color([string]$html) {
    [System.Drawing.ColorTranslator]::FromHtml($html)
}

function New-Label([string]$text, [int]$x, [int]$y, [int]$width, [int]$height, [float]$size, [bool]$bold = $false) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text
    $label.Location = New-Object System.Drawing.Point($x, $y)
    $label.Size = New-Object System.Drawing.Size($width, $height)
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $label.Font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
    $label.AutoEllipsis = $true
    return $label
}

$script:form = New-Object System.Windows.Forms.Form
$form.Text = 'Codex 周额度'
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
        $cw = [int]$saved.compactWidth; $ch = [int]$saved.compactHeight
        if ($cw -ge 48 -and $cw -le 160 -and $ch -ge 64 -and $ch -le 200) {
            $script:compactSize = [System.Drawing.Size]::new($cw, $ch)
        }
        $dw = [int]$saved.detailWidth; $dh = [int]$saved.detailHeight
        if ($dw -ge 404 -and $dw -le 720 -and $dh -ge 390 -and $dh -le 650) {
            $script:detailSize = [System.Drawing.Size]::new($dw, $dh)
        }
    } catch { }
}
if ($saved -and $saved.mode -eq 'Compact') { $script:mode = 'Compact' }
$form.ClientSize = if ($script:mode -eq 'Compact') { $script:compactSize } else { $script:detailSize }
$form.Location = New-Object System.Drawing.Point(($bounds.Right - $form.Width - 24), ($bounds.Top + 88))
if ($saved) {
    try {
        $x = [int]$saved.x; $y = [int]$saved.y
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

$title = New-Label 'Codex 周额度' 18 10 132 30 11.5 $true
$title.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$status = New-Label '读取中' 155 10 100 30 9
$status.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$compactButton = New-Label '极简' 261 10 46 30 9
$compactButton.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$refresh = New-Object System.Windows.Forms.Button
$refresh.Text = '刷新'
$refresh.Location = New-Object System.Drawing.Point(315, 10)
$refresh.Size = New-Object System.Drawing.Size(48, 30)
$refresh.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$refresh.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$refresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$refresh.FlatAppearance.BorderSize = 0
$refresh.TabStop = $false
$close = New-Label '×' 370 10 26 30 16
$close.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$compactButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$refresh.Cursor = [System.Windows.Forms.Cursors]::Hand
$close.Cursor = [System.Windows.Forms.Cursors]::Hand

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
    $arc = New-Object System.Drawing.Pen($script:colors.accent, $stroke)
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
        $brush = New-Object System.Drawing.SolidBrush($script:colors.text)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $e.Graphics.DrawString($text, $font, $brush, [System.Drawing.RectangleF]::new(0, 0, $sender.Width, $sender.Height), $format)
        $font.Dispose(); $brush.Dispose(); $format.Dispose()
    }
    $track.Dispose(); $arc.Dispose()
})

$caption = New-Label '本周剩余' 156 63 224 26 10.5
$countdown = New-Label '正在读取' 154 94 230 45 20 $true
$reset = New-Label '重置时间 —' 156 144 224 25 10
$divider = New-Object System.Windows.Forms.Panel
$divider.Location = New-Object System.Drawing.Point(20, 182)
$divider.Size = New-Object System.Drawing.Size(364, 1)
$updated = New-Label '最近更新 —' 20 194 240 25 9.5
$cards = New-Label '重置卡 —' 281 194 103 25 9.5
$cards.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight

$fiveDivider = New-Object System.Windows.Forms.Panel
$fiveDivider.Location = New-Object System.Drawing.Point(20, 226)
$fiveDivider.Size = New-Object System.Drawing.Size(364, 1)
$fiveTitle = New-Label '5小时额度' 20 238 138 26 10.5 $true
$fiveValue = New-Label '暂不可用' 238 238 146 26 10.5 $true
$fiveValue.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$fiveReset = New-Label '重置时间 —' 20 267 364 22 9.5

$externalDivider = New-Object System.Windows.Forms.Panel
$externalDivider.Location = New-Object System.Drawing.Point(20, 226)
$externalDivider.Size = New-Object System.Drawing.Size(364, 1)
$externalTitle = New-Label '公开全局临时重置' 20 238 364 26 10.5 $true
$lastGlobal = New-Label '上次公告 —' 20 270 364 24 9.5
$delivery = New-Label '送达时间 —' 20 297 364 24 9.5
$odds = New-Label '未来概率暂不可用' 20 326 364 26 9.5 $true
$attribution = New-Object System.Windows.Forms.LinkLabel
$attribution.Text = '历史频率估计 · codexreset.ai'
$attribution.Location = New-Object System.Drawing.Point(20, 356)
$attribution.Size = New-Object System.Drawing.Size(364, 22)
$attribution.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$attribution.LinkBehavior = [System.Windows.Forms.LinkBehavior]::HoverUnderline
$attribution.TabStop = $false

foreach ($control in @($title, $status, $compactButton, $refresh, $close, $ring, $caption, $countdown, $reset, $divider, $updated, $cards,
    $fiveDivider, $fiveTitle, $fiveValue, $fiveReset, $externalDivider, $externalTitle, $lastGlobal, $delivery, $odds, $attribution)) {
    [void]$form.Controls.Add($control)
}
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
$script:detailControls = @($title, $status, $compactButton, $refresh, $close, $caption, $countdown, $reset, $divider, $updated, $cards,
    $fiveDivider, $fiveTitle, $fiveValue, $fiveReset, $externalDivider, $externalTitle, $lastGlobal, $delivery, $odds, $attribution)

$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.SetToolTip($refresh, '立即刷新额度')
$tooltip.SetToolTip($close, '隐藏到系统托盘')
$tooltip.SetToolTip($compactButton, '切换到极简悬浮窗')
$tooltip.SetToolTip($ring, '极简模式可单击展开，拖动可调整位置')
foreach ($zone in $script:resizeEdges.Values) { $tooltip.SetToolTip($zone, '拖动边缘调整大小') }
$tooltip.SetToolTip($odds, '公开全局临时重置的历史频率估计，不是账号每周重置时间，也不是 OpenAI 承诺。')

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

function Update-ResponsiveLayout {
    if ($script:animating) { return }
    $width = $form.ClientSize.Width
    $height = $form.ClientSize.Height
    if ($script:mode -eq 'Compact') {
        $ringSize = [Math]::Max(38, [Math]::Min($width - 10, $height - 20))
        Set-ControlBox $ring (($width - $ringSize) / 2) (($height - $ringSize) / 2) $ringSize $ringSize
        Update-ResizeEdges $width $height $true
    } else {
        $offset = if ($script:layoutPlus) { 62 } else { 0 }
        $baseHeight = 390 + $offset
        $scale = [Math]::Max(1, [Math]::Min(1.3, [Math]::Min(($width / 404.0), ($height / [double]$baseHeight))))
        $vertical = $height / [double]$baseHeight
        $margin = 20 * $scale
        $contentWidth = $width - 2 * $margin
        Set-ControlBox $title (18 * $scale) (10 * $scale) (132 * $scale) (30 * $scale)
        Set-ControlBox $status ($width - 249 * $scale) (10 * $scale) (100 * $scale) (30 * $scale)
        Set-ControlBox $compactButton ($width - 143 * $scale) (10 * $scale) (46 * $scale) (30 * $scale)
        Set-ControlBox $refresh ($width - 89 * $scale) (10 * $scale) (48 * $scale) (30 * $scale)
        Set-ControlBox $close ($width - 34 * $scale) (10 * $scale) (26 * $scale) (30 * $scale)
        $ringSize = 110 * $scale
        Set-ControlBox $ring $margin (58 * $vertical) $ringSize $ringSize
        $rightX = 156 * $scale
        $rightWidth = $width - $rightX - $margin
        Set-ControlBox $caption $rightX (63 * $vertical) $rightWidth (26 * $scale)
        Set-ControlBox $countdown (154 * $scale) (94 * $vertical) ($width - 154 * $scale - $margin) (45 * $scale)
        Set-ControlBox $reset $rightX (144 * $vertical) $rightWidth (25 * $scale)
        Set-ControlBox $divider $margin (182 * $vertical) $contentWidth 1
        Set-ControlBox $updated $margin (194 * $vertical) ($width - 155 * $scale) (25 * $scale)
        Set-ControlBox $cards ($width - 123 * $scale) (194 * $vertical) (103 * $scale) (25 * $scale)
        Set-ControlBox $fiveDivider $margin (226 * $vertical) $contentWidth 1
        Set-ControlBox $fiveTitle $margin (238 * $vertical) (138 * $scale) (26 * $scale)
        Set-ControlBox $fiveValue ($width - 166 * $scale) (238 * $vertical) (146 * $scale) (26 * $scale)
        Set-ControlBox $fiveReset $margin (267 * $vertical) $contentWidth (22 * $scale)
        Set-ControlBox $externalDivider $margin ((226 + $offset) * $vertical) $contentWidth 1
        Set-ControlBox $externalTitle $margin ((238 + $offset) * $vertical) $contentWidth (26 * $scale)
        Set-ControlBox $lastGlobal $margin ((270 + $offset) * $vertical) $contentWidth (24 * $scale)
        Set-ControlBox $delivery $margin ((297 + $offset) * $vertical) $contentWidth (24 * $scale)
        Set-ControlBox $odds $margin ((326 + $offset) * $vertical) $contentWidth (26 * $scale)
        Set-ControlBox $attribution $margin ((356 + $offset) * $vertical) $contentWidth (22 * $scale)
        Update-ResizeEdges $width $height $false $scale
    }
    Set-RoundedRegion
    $ring.Invalidate()
}

$script:fontScale = 1.0
$script:fontSpecs = @(
    @{ Control = $title; Size = 11.5; Bold = $true; Family = 'Segoe UI' },
    @{ Control = $status; Size = 9; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $compactButton; Size = 9; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $refresh; Size = 9; Bold = $false; Family = 'Microsoft YaHei UI' },
    @{ Control = $close; Size = 16; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $caption; Size = 10.5; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $countdown; Size = 20; Bold = $true; Family = 'Segoe UI' },
    @{ Control = $reset; Size = 10; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $updated; Size = 9.5; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $cards; Size = 9.5; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $fiveTitle; Size = 10.5; Bold = $true; Family = 'Segoe UI' },
    @{ Control = $fiveValue; Size = 10.5; Bold = $true; Family = 'Segoe UI' },
    @{ Control = $fiveReset; Size = 9.5; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $externalTitle; Size = 10.5; Bold = $true; Family = 'Segoe UI' },
    @{ Control = $lastGlobal; Size = 9.5; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $delivery; Size = 9.5; Bold = $false; Family = 'Segoe UI' },
    @{ Control = $odds; Size = 9.5; Bold = $true; Family = 'Segoe UI' },
    @{ Control = $attribution; Size = 9.5; Bold = $false; Family = 'Segoe UI' }
)

function Update-DetailFonts {
    if ($script:mode -ne 'Detail' -or $script:animating) { return }
    $offset = if ($script:layoutPlus) { 62 } else { 0 }
    $scale = [Math]::Max(1, [Math]::Min(1.3, [Math]::Min(($form.ClientSize.Width / 404.0), ($form.ClientSize.Height / [double](390 + $offset)))))
    if ([Math]::Abs($scale - $script:fontScale) -lt 0.025) { return }
    foreach ($spec in $script:fontSpecs) {
        $style = if ($spec.Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
        $newFont = [System.Drawing.Font]::new($spec.Family, [float]($spec.Size * $scale), $style)
        $oldFont = $spec.Control.Font
        $spec.Control.Font = $newFont
        if ($oldFont) { $oldFont.Dispose() }
    }
    $script:fontScale = $scale
}

function Set-Layout([bool]$plus) {
    if ($null -ne $script:layoutPlus -and $script:layoutPlus -eq $plus) { return }
    $script:layoutPlus = $plus
    $offset = if ($plus) { 62 } else { 0 }
    foreach ($control in @($fiveDivider, $fiveTitle, $fiveValue, $fiveReset)) { $control.Visible = $plus }
    $externalDivider.Top = 226 + $offset
    $externalTitle.Top = 238 + $offset
    $lastGlobal.Top = 270 + $offset
    $delivery.Top = 297 + $offset
    $odds.Top = 326 + $offset
    $attribution.Top = 356 + $offset
    if ($script:mode -eq 'Detail' -and -not $script:animating) {
        $form.ClientSize = New-Object System.Drawing.Size($script:detailSize.Width, ($script:detailSize.Height + $offset))
        $screen = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
        if ($form.Bottom -gt $screen.Bottom) { $form.Top = $screen.Bottom - $form.Height }
    }
    Update-ResponsiveLayout
    Update-DetailFonts
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
            accent = (New-Color '#1CA887'); track = (New-Color '#DFE5EB'); line = (New-Color '#DDE3E8')
        }
    } else {
        $script:colors = @{
            back = (New-Color '#20242C'); text = (New-Color '#F3F5F7'); muted = (New-Color '#AFB8C5')
            accent = (New-Color '#32D5A6'); track = (New-Color '#3C4550'); line = (New-Color '#3B444E')
        }
    }
    $form.BackColor = $script:colors.back
    $ring.BackColor = $script:colors.back
    foreach ($zone in $script:resizeEdges.Values) { $zone.BackColor = $script:colors.back }
    $divider.BackColor = $script:colors.line
    $fiveDivider.BackColor = $script:colors.line
    $externalDivider.BackColor = $script:colors.line
    foreach ($control in @($title, $countdown, $fiveTitle, $fiveValue, $externalTitle, $odds)) { $control.ForeColor = $script:colors.text; $control.BackColor = $script:colors.back }
    foreach ($control in @($status, $refresh, $close, $caption, $reset, $updated, $cards, $fiveReset, $lastGlobal, $delivery, $attribution)) { $control.ForeColor = $script:colors.muted; $control.BackColor = $script:colors.back }
    $compactButton.ForeColor = $script:colors.accent
    $compactButton.BackColor = $script:colors.back
    $attribution.LinkColor = $script:colors.accent
    $attribution.ActiveLinkColor = $script:colors.text
    $attribution.VisitedLinkColor = $script:colors.accent
    $ring.Invalidate()
    Set-Tray-QuotaIcon
}

function Show-Quota {
    $now = [DateTimeOffset]::UtcNow
    $value = $script:data
    Set-Layout ($value -and $value.status -eq 'ok' -and $value.plan -eq 'plus')
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
        $countdown.Text = if ($days -gt 0) { "${days}天 ${hours}小时" } elseif ($hours -gt 0) { "${hours}小时 ${minutes}分" } else { "${minutes}分钟" }
        $reset.Text = '重置 ' + $resetAt.ToLocalTime().ToString('MM/dd HH:mm')
        $updated.Text = '最近更新 ' + ([DateTimeOffset]::FromUnixTimeMilliseconds([long]$value.updatedAt)).ToLocalTime().ToString('MM/dd HH:mm')
        $cards.Text = if ($null -ne $value.resetCards) { "重置卡 $($value.resetCards)张" } else { '重置卡 —' }
        $status.Text = '数据已更新'
        $caption.Text = '距离重置'
        if ($value.plan -eq 'plus') {
            $five = $value.fiveHour
            try {
                $fiveTime = [DateTimeOffset]::FromUnixTimeSeconds([long]$five.resetsAt)
                if ($fiveTime -gt $now -and [double]$five.remainingPercent -ge 0 -and [double]$five.remainingPercent -le 100) {
                    $fiveValue.Text = "$([int]$five.remainingPercent)% 剩余"
                    $fiveReset.Text = '重置 ' + $fiveTime.ToLocalTime().ToString('MM/dd HH:mm')
                } else { $fiveValue.Text = '暂不可用'; $fiveReset.Text = '重置时间 —' }
            } catch { $fiveValue.Text = '暂不可用'; $fiveReset.Text = '重置时间 —' }
        }
    } else {
        $script:remaining = $null
        $countdown.Text = '暂不可用'
        $reset.Text = '重置时间 —'
        $updated.Text = if ($value -and $value.status -eq 'ok') { '数据已过期，请刷新' } else { $script:message }
        $cards.Text = '重置卡 —'
        $status.Text = '暂不可用'
        $caption.Text = '本周剩余'
    }
    $ringTip = if ($script:mode -eq 'Compact') {
        if ($null -eq $script:remaining) { '额度暂不可用 · 单击展开' } else { "本周剩余 $($script:remaining)% · 单击展开" }
    } else { '拖动悬浮窗' }
    $tooltip.SetToolTip($ring, $ringTip)
    $ring.Invalidate()
    Set-Tray-QuotaIcon
}

function Show-External {
    $value = $script:externalData
    $last = if ($value -and $value.status -eq 'ok') { $value.lastGlobal } else { $null }
    $forecast = if ($value -and $value.status -eq 'ok') { $value.forecast } else { $null }
    if ($last) {
        try {
            $time = [DateTimeOffset]::Parse([string]$last.announcedAt).ToLocalTime()
            $scope = if ($last.scope -eq 'paid') { '付费账号' } elseif ($last.scope -eq 'all') { '全部账号' } else { '范围未明' }
            $lastGlobal.Text = '上次公告 ' + $time.ToString('MM/dd HH:mm') + " · $scope"
            $delivery.Text = if ($last.deliveredAt) {
                '记录送达 ' + ([DateTimeOffset]::Parse([string]$last.deliveredAt).ToLocalTime().ToString('MM/dd HH:mm'))
            } else { '送达时间未确认' }
        } catch { $lastGlobal.Text = '上次公开重置暂不可用'; $delivery.Text = '送达时间 —' }
    } else {
        $lastGlobal.Text = '上次公开重置暂不可用'
        $delivery.Text = '送达时间 —'
    }
    if ($forecast) {
        $odds.Text = "未来概率 24h $($forecast.next24h)% · 48h $($forecast.next48h)% · 7天 $($forecast.next7d)%"
        Set-AttributionLinks '历史频率估计 · codexreset.ai / whenreset.app'
    } else {
        $odds.Text = '未来概率暂不可用'
        Set-AttributionLinks '公开数据 · codexreset.ai'
    }
}

function Set-AttributionLinks([string]$text) {
    $attribution.Text = $text
    $attribution.Links.Clear()
    foreach ($entry in @(@('codexreset.ai', 'https://codexreset.ai/'), @('whenreset.app', 'https://whenreset.app/'))) {
        $index = $text.IndexOf($entry[0], [System.StringComparison]::Ordinal)
        if ($index -ge 0) { [void]$attribution.Links.Add($index, $entry[0].Length, $entry[1]) }
    }
}

function Start-ExternalRequest {
    if ($script:externalTask -and -not $script:externalTask.IsCompleted) { return }
    try {
        $script:externalTask = $script:client.GetAsync("$script:baseUrl/api/external")
        $script:nextExternalPoll = [DateTime]::UtcNow.AddMinutes(10)
    } catch {
        $script:externalTask = $null
        $script:externalData = $null
        Show-External
    }
}

function Start-Request([bool]$manual) {
    if ($script:requestTask -and -not $script:requestTask.IsCompleted) { return }
    try {
        $script:requestManual = $manual
        $script:requestTask = if ($manual) {
            $content = New-Object System.Net.Http.StringContent('')
            $script:client.PostAsync("$script:baseUrl/api/refresh", $content)
        } else {
            $script:client.GetAsync("$script:baseUrl/api/usage")
        }
        $script:nextPoll = [DateTime]::UtcNow.AddMinutes(1)
        $status.Text = '正在刷新'
    } catch {
        $script:requestTask = $null
        $script:data = $null
        $script:message = '本机服务未连接'
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
        $script:tray.Text = if ($null -eq $script:remaining) { 'Codex 周额度暂不可用' } else { "Codex 本周剩余 $($script:remaining)%" }
        $script:trayIconKey = $key
    } finally {
        foreach ($resource in @($trackPen, $arcPen, $backBrush, $textBrush, $font, $format, $graphics, $bitmap)) {
            if ($resource) { $resource.Dispose() }
        }
    }
}

function Set-ModeVisual([bool]$compact) {
    foreach ($control in $script:detailControls) { $control.Visible = -not $compact }
    if (-not $compact -and $script:layoutPlus -ne $true) {
        foreach ($control in @($fiveDivider, $fiveTitle, $fiveValue, $fiveReset)) { $control.Visible = $false }
    }
    foreach ($zone in $script:resizeEdges.Values) { $zone.Visible = $true }
    $modeTip = if ($compact) { '单击展开，拖动可调整位置' } else { '拖动悬浮窗' }
    $tooltip.SetToolTip($ring, $modeTip)
    Update-ResponsiveLayout
    Update-DetailFonts
}

function Start-ModeTransition([string]$nextMode) {
    if ($script:animating -or $script:mode -eq $nextMode) { return }
    $compact = $nextMode -eq 'Compact'
    $size = if ($compact) { $script:compactSize } else { [System.Drawing.Size]::new($script:detailSize.Width, ($script:detailSize.Height + $(if ($script:layoutPlus) { 62 } else { 0 }))) }
    $screen = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
    $rightAnchor = ($form.Left + $form.Width / 2) -gt ($screen.Left + $screen.Width / 2)
    $bottomAnchor = ($form.Top + $form.Height / 2) -gt ($screen.Top + $screen.Height / 2)
    $x = if ($rightAnchor) { $form.Right - $size.Width } else { $form.Left }
    $y = if ($bottomAnchor) { $form.Bottom - $size.Height } else { $form.Top }
    $x = [Math]::Max($screen.Left, [Math]::Min($x, $screen.Right - $size.Width))
    $y = [Math]::Max($screen.Top, [Math]::Min($y, $screen.Bottom - $size.Height))
    $script:animationFrom = $form.Bounds
    $script:animationTo = [System.Drawing.Rectangle]::new([int]$x, [int]$y, $size.Width, $size.Height)
    $script:ringFrom = $ring.Bounds
    if ($compact) {
        $targetRingSize = [Math]::Max(38, [Math]::Min($size.Width - 10, $size.Height - 20))
        $script:ringTo = [System.Drawing.Rectangle]::new([int](($size.Width - $targetRingSize) / 2), [int](($size.Height - $targetRingSize) / 2), [int]$targetRingSize, [int]$targetRingSize)
    } else {
        $offset = if ($script:layoutPlus) { 62 } else { 0 }
        $targetScale = [Math]::Max(1, [Math]::Min(1.3, [Math]::Min(($size.Width / 404.0), ($size.Height / [double](390 + $offset)))))
        $targetVertical = $size.Height / [double](390 + $offset)
        $script:ringTo = [System.Drawing.Rectangle]::new([int][Math]::Round(20 * $targetScale), [int][Math]::Round(58 * $targetVertical), [int][Math]::Round(110 * $targetScale), [int][Math]::Round(110 * $targetScale))
    }
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
$attribution.Add_LinkClicked({
    param($sender, $e)
    $url = [string]$e.Link.LinkData
    if ($url -in @('https://codexreset.ai/', 'https://whenreset.app/')) {
        try { Start-Process -FilePath $url | Out-Null } catch { }
    }
})
$drag = {
    param($sender, $e)
    if ($script:mode -eq 'Detail' -and -not $script:animating -and $e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [void][WidgetDrag]::ReleaseCapture()
        [void][WidgetDrag]::SendMessage($form.Handle, 0xA1, 2, [IntPtr]::Zero)
    }
}
foreach ($control in @($form, $title, $status, $ring, $caption, $countdown, $reset, $divider, $updated, $cards,
    $fiveDivider, $fiveTitle, $fiveValue, $fiveReset, $externalDivider, $externalTitle, $lastGlobal, $delivery, $odds)) {
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
$showItem = $menu.Items.Add('显示悬浮窗')
$modeItem = $menu.Items.Add('切换极简 / 详细')
$hideItem = $menu.Items.Add('隐藏到托盘')
$refreshItem = $menu.Items.Add('立即刷新')
$topItem = $menu.Items.Add('始终置顶')
$topItem.Checked = $true
[void]$menu.Items.Add('-')
$exitItem = $menu.Items.Add('退出额度工具')
$showItem.Add_Click({ $form.Show(); $form.Activate() })
$modeItem.Add_Click({
    $form.Show(); $form.Activate()
    if ($script:mode -eq 'Compact') { Start-ModeTransition 'Detail' } else { Start-ModeTransition 'Compact' }
})
$hideItem.Add_Click({ $form.Hide() })
$refreshItem.Add_Click({ Start-Request $true; $form.Show(); $form.Activate() })
$topItem.Add_Click({ $form.TopMost = -not $form.TopMost; $topItem.Checked = $form.TopMost })
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
$script:tray.Text = 'Codex 周额度'
$script:tray.ContextMenuStrip = $menu
$script:tray.Visible = $true
$script:tray.Add_DoubleClick({ $form.Show(); $form.Activate() })
$form.Add_FormClosing({
    param($sender, $e)
    if (-not $script:reallyExit) { $e.Cancel = $true; $form.Hide() }
})
$form.Add_LocationChanged({ $script:positionDirty = $true })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500
$timer.Add_Tick({
    if (Test-Path -LiteralPath $script:showRequest) {
        Remove-Item -LiteralPath $script:showRequest -ErrorAction SilentlyContinue
        $form.Show()
        $form.Activate()
        Start-Request $false
        Start-ExternalRequest
    }
    if ($script:requestTask -and $script:requestTask.IsCompleted) {
        try {
            $response = $script:requestTask.GetAwaiter().GetResult()
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $json = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                $script:data = $json | ConvertFrom-Json
                $script:message = if ($script:data.message) { [string]$script:data.message } else { '额度暂不可用' }
            } finally { $response.Dispose() }
        } catch {
            $script:data = $null
            $script:message = '本机服务未连接'
        }
        $script:requestTask = $null
        Show-Quota
        if ($script:requestManual) { Start-ExternalRequest }
        $script:requestManual = $false
    }
    if ($script:externalTask -and $script:externalTask.IsCompleted) {
        try {
            $response = $script:externalTask.GetAwaiter().GetResult()
            try {
                $response.EnsureSuccessStatusCode() | Out-Null
                $script:externalData = ($response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json)
            } finally { $response.Dispose() }
        } catch { $script:externalData = $null }
        $script:externalTask = $null
        Show-External
    }
    $now = [DateTime]::UtcNow
    if ($script:positionDirty -and -not $script:animating -and ($now - $script:lastPositionSave).TotalSeconds -ge 1) {
        @{
            x = $form.Left; y = $form.Top; mode = $script:mode
            compactWidth = $script:compactSize.Width; compactHeight = $script:compactSize.Height
            detailWidth = $script:detailSize.Width; detailHeight = $script:detailSize.Height
        } | ConvertTo-Json | Set-Content -LiteralPath $script:positionPath -Encoding UTF8
        $script:positionDirty = $false
        $script:lastPositionSave = $now
    }
    if (-not $script:requestTask -and $now -ge $script:nextPoll) { Start-Request $false }
    if (-not $script:externalTask -and $now -ge $script:nextExternalPoll) { Start-ExternalRequest }
    if (($now - $script:lastRender).TotalSeconds -ge 30) { Show-Quota; $script:lastRender = $now }
    if (($now - $script:lastThemeCheck).TotalMinutes -ge 1) { Set-Theme; $script:lastThemeCheck = $now }
})

$form.Add_Shown({
    if ($script:mode -eq 'Compact') {
        $form.Bounds = [System.Drawing.Rectangle]::new($form.Left, $form.Top, $script:compactSize.Width, $script:compactSize.Height)
        Set-RoundedRegion
    }
    Start-Request $false
    Start-ExternalRequest
})
$form.Add_FormClosed({
    $timer.Stop()
    $script:animationTimer.Stop()
    $script:tray.Visible = $false
    $script:tray.Dispose()
    if ($script:ownedTrayIcon) { $script:ownedTrayIcon.Dispose() }
    $client.Dispose()
})
Set-Theme
Show-Quota
Show-External
Set-ModeVisual ($script:mode -eq 'Compact')
$timer.Start()
[System.Windows.Forms.Application]::Run($form)
