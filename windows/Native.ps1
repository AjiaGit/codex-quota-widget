# Shared native helpers. Dot-source this file; it does not start a service or UI.
$script:WidgetStrings = @{
    en = @{
        app = 'Codex Quota'; loading = 'Loading'; reading = 'Reading quota'; updated = 'Updated'; unavailable = 'Unavailable'; refreshing = 'Refreshing'
        compact = 'Mini'; refresh = 'Refresh'; weekly = 'Weekly remaining'; untilReset = 'Until reset'; reset = 'Resets {0}'; resetUnknown = 'Reset time —'
        lastUpdated = 'Updated {0}'; stale = 'Data is stale. Refresh to update.'; cards = 'Credits: {0}'; cardsUnknown = 'Credits —'
        fiveHour = '5-hour quota'; percentRemaining = '{0}% remaining'; external = 'Public global resets'; lastAnnouncement = 'Announced {0} · {1}'
        paid = 'Paid accounts'; all = 'All accounts'; unknownScope = 'Scope unknown'; delivered = 'Delivered {0}'; deliveryUnknown = 'Delivery not confirmed'
        publicUnavailable = 'Public reset data unavailable'; deliveryEmpty = 'Delivery time —'; probability = 'Estimated odds: 24h {0}% · 48h {1}% · 7d {2}%'
        oddsUnknown = 'Estimated odds unavailable'; attribution = 'Historical estimate · codexreset.ai / whenreset.app'; publicSource = 'Public data · codexreset.ai'
        tipRefresh = 'Refresh quota now'; tipHide = 'Hide to tray'; tipCompact = 'Switch to mini widget'; tipExpand = 'Click to expand; drag to move'
        tipResize = 'Drag the edge to resize'; tipOdds = 'Estimate from public global reset history; not an account reset time or an OpenAI promise.'
        tipRemaining = 'Weekly remaining {0}% · click to expand'; tipUnavailable = 'Quota unavailable · click to expand'; tipDrag = 'Drag to move'
        show = 'Show widget'; mode = 'Switch mini / detail'; hide = 'Hide to tray'; refreshNow = 'Refresh now'; onTop = 'Always on top'; quit = 'Quit quota widget'
        language = 'Language'; languageAuto = 'System'; languageEn = 'English'; languageZh = '简体中文'; languageSaveFailed = 'Could not save the language. Try again.'
        trayRemaining = 'Codex weekly remaining {0}%'; trayUnavailable = 'Codex quota unavailable'; dayHour = '{0}d {1}h'; hourMinute = '{0}h {1}m'; minute = '{0}m'
        detailsTitle = 'Reset credit details'; detailsCount = 'Available reset credits: {0}'; detailsUnknownCount = 'Available reset credits: Not provided'
        detailsUnavailable = 'Grant and expiry details were not provided.'; detailsEmpty = 'No grant or expiry rows were provided.'
        detailsScope = 'Only details returned by Codex are shown. This is not a complete history or a prediction.'; grant = 'Granted: {0}'; expiry = 'Expires: {0}'; notProvided = 'Not provided'; unnamedGrant = 'Reset credit'
        openDetails = 'View reset credit details'; setup = 'Set up Codex'; setupTip = 'Install Codex CLI or sign in, then refresh.'
        cli_missing = 'Codex CLI was not found. Install Codex CLI, then refresh.'; signed_out = 'Sign in to Codex: run codex login, then refresh.'
        timeout = 'Codex took too long to reply. Refresh to try again.'; network = 'Codex could not connect. Check your connection, then refresh.'
        unsupported = 'This account did not provide a weekly quota.'; service_unavailable = 'Local service unavailable. Open Codex Quota again.'; query_failed = 'Quota is unavailable. Open Codex, confirm sign-in, then refresh.'
        foreignState = 'The runtime record belongs to another copy of this tool. No process was changed.'; missingState = 'A local service is running without an owned runtime record.'
        foreignService = 'The service process does not match this tool. No process was changed.'; foreignFloating = 'The widget process does not match this tool. No process was changed.'
        portBusy = 'Port {0} is already in use. Close the other local service and try again.'; nodeMissing = 'Node.js 24 or later is required. Use the bundled installer or install Node.js 24.'
        startFailed = 'The local service could not start. Diagnostic file: {0}'; floatingFailed = 'The widget could not start. Diagnostic file: {0}'; opened = 'Codex Quota is open.'; stopped = 'Codex Quota and its service stopped.'
        stopFailed = 'Codex Quota could not stop. Close its window and try again.'; noState = 'No owned runtime record was found.'; lockBusy = 'Codex Quota is already starting or stopping. Try again shortly.'
        signInHelp = 'Open a terminal and run codex login. Complete sign-in, then click Refresh.'; installHelp = 'Install Codex CLI using the official instructions, then click Refresh.'
        clearPrefs = 'Remove saved window position and language?'; preferencesTitle = 'Codex Quota preferences'
    }
    'zh-CN' = @{
        app = 'Codex 周额度'; loading = '读取中'; reading = '正在读取额度'; updated = '数据已更新'; unavailable = '暂不可用'; refreshing = '正在刷新'
        compact = '极简'; refresh = '刷新'; weekly = '本周剩余'; untilReset = '距离重置'; reset = '重置 {0}'; resetUnknown = '重置时间 —'
        lastUpdated = '最近更新 {0}'; stale = '数据已过期，请刷新'; cards = '重置卡 {0}张'; cardsUnknown = '重置卡 —'
        fiveHour = '5小时额度'; percentRemaining = '{0}% 剩余'; external = '公开全局临时重置'; lastAnnouncement = '上次公告 {0} · {1}'
        paid = '付费账号'; all = '全部账号'; unknownScope = '范围未明'; delivered = '记录送达 {0}'; deliveryUnknown = '送达时间未确认'
        publicUnavailable = '上次公开重置暂不可用'; deliveryEmpty = '送达时间 —'; probability = '历史估计 24h {0}% · 48h {1}% · 7天 {2}%'
        oddsUnknown = '历史概率估计暂不可用'; attribution = '历史频率估计 · codexreset.ai / whenreset.app'; publicSource = '公开数据 · codexreset.ai'
        tipRefresh = '立即刷新额度'; tipHide = '隐藏到系统托盘'; tipCompact = '切换到极简悬浮窗'; tipExpand = '单击展开，拖动可调整位置'
        tipResize = '拖动边缘调整大小'; tipOdds = '公开全局临时重置的历史频率估计，不是账号每周重置时间，也不是 OpenAI 承诺。'
        tipRemaining = '本周剩余 {0}% · 单击展开'; tipUnavailable = '额度暂不可用 · 单击展开'; tipDrag = '拖动悬浮窗'
        show = '显示悬浮窗'; mode = '切换极简 / 详细'; hide = '隐藏到托盘'; refreshNow = '立即刷新'; onTop = '始终置顶'; quit = '退出额度工具'
        language = '语言'; languageAuto = '跟随系统'; languageEn = 'English'; languageZh = '简体中文'; languageSaveFailed = '语言设置保存失败，请重试。'
        trayRemaining = 'Codex 本周剩余 {0}%'; trayUnavailable = 'Codex 周额度暂不可用'; dayHour = '{0}天 {1}小时'; hourMinute = '{0}小时 {1}分'; minute = '{0}分钟'
        detailsTitle = '重置卡明细'; detailsCount = '可用重置卡：{0}张'; detailsUnknownCount = '可用重置卡：未提供'
        detailsUnavailable = 'Codex 未提供发放和到期明细。'; detailsEmpty = '未提供发放或到期记录。'
        detailsScope = '仅显示 Codex 返回的明细，不代表完整历史或未来发放。'; grant = '发放：{0}'; expiry = '到期：{0}'; notProvided = '未提供'; unnamedGrant = '重置卡'
        openDetails = '查看重置卡明细'; setup = '设置 Codex'; setupTip = '安装 Codex CLI 或登录后，再刷新。'
        cli_missing = '未找到 Codex CLI。请安装 Codex CLI 后刷新。'; signed_out = '请在终端运行 codex login 登录，然后刷新。'
        timeout = 'Codex 查询超时，请刷新重试。'; network = 'Codex 无法连接，请检查网络后刷新。'
        unsupported = '当前账号未提供七天 Codex 额度。'; service_unavailable = '本机服务未连接，请重新打开 Codex 周额度。'; query_failed = '额度暂不可用，请打开 Codex 确认已登录后刷新。'
        foreignState = '运行记录指向另一份工具，未修改任何进程。'; missingState = '本机服务正在运行，但缺少本工具的运行记录。'
        foreignService = '服务进程身份与本工具不符，未修改任何进程。'; foreignFloating = '悬浮窗进程身份与本工具不符，未修改任何进程。'
        portBusy = '端口 {0} 已被占用，请关闭其他本机服务后重试。'; nodeMissing = '需要 Node.js 24 或以上版本。请使用含运行环境的安装包，或安装 Node.js 24。'
        startFailed = '本机服务启动失败，诊断文件：{0}'; floatingFailed = '悬浮窗启动失败，诊断文件：{0}'; opened = 'Codex 周额度悬浮窗已打开。'; stopped = 'Codex 周额度悬浮窗和服务已停止。'
        stopFailed = 'Codex 周额度停止失败，请关闭悬浮窗后重试。'; noState = '没有本工具的运行记录。'; lockBusy = 'Codex 周额度正在启动或停止，请稍后重试。'
        signInHelp = '请打开终端运行 codex login，完成登录后点击刷新。'; installHelp = '请按官方说明安装 Codex CLI，安装后点击刷新。'
        clearPrefs = '删除保存的窗口位置和语言设置？'; preferencesTitle = 'Codex 周额度偏好设置'
    }
}

function Resolve-WidgetLanguage([string]$setting = 'auto', [string]$systemLanguage = [Globalization.CultureInfo]::CurrentUICulture.Name) {
    if ($setting -in @('en', 'zh-CN')) { return $setting }
    if ($systemLanguage -match '^zh(?:-|$)') { return 'zh-CN' }
    return 'en'
}
function Get-WidgetText([string]$key, [string]$language = 'en', [object[]]$values = @()) {
    $resolved = Resolve-WidgetLanguage $language
    $template = $script:WidgetStrings[$resolved][$key]
    if ($null -eq $template) { $template = $script:WidgetStrings.en[$key] }
    if ($null -eq $template) { throw "Unknown localization key: $key" }
    return [string]::Format([Globalization.CultureInfo]::InvariantCulture, $template, $values)
}
function Get-WidgetErrorText([string]$errorCode, [string]$language) {
    if ($errorCode -notin @('cli_missing','signed_out','timeout','network','unsupported','service_unavailable','query_failed')) { $errorCode = 'query_failed' }
    Get-WidgetText $errorCode $language
}
function Format-WidgetCountdown([TimeSpan]$span, [string]$language) {
    if ($span.TotalDays -ge 1) { return Get-WidgetText 'dayHour' $language @([int][Math]::Floor($span.TotalDays), $span.Hours) }
    if ($span.TotalHours -ge 1) { return Get-WidgetText 'hourMinute' $language @([int][Math]::Floor($span.TotalHours), $span.Minutes) }
    return Get-WidgetText 'minute' $language @([Math]::Max(0, [int][Math]::Floor($span.TotalMinutes)))
}
function Format-WidgetDate([DateTimeOffset]$date, [string]$language) {
    $cultureName = if ((Resolve-WidgetLanguage $language) -eq 'zh-CN') { 'zh-CN' } else { 'en-US' }
    $format = if ($cultureName -eq 'zh-CN') { 'M月d日 HH:mm' } else { 'MMM d HH:mm' }
    $date.ToLocalTime().ToString($format, [Globalization.CultureInfo]::GetCultureInfo($cultureName))
}
function Format-WidgetResetDetails($data, [string]$language) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    if ($data -and $null -ne $data.resetCards) { $lines.Add((Get-WidgetText 'detailsCount' $language @($data.resetCards))) }
    else { $lines.Add((Get-WidgetText 'detailsUnknownCount' $language)) }
    $lines.Add('')
    if (-not $data -or $null -eq $data.resetDetails) { $lines.Add((Get-WidgetText 'detailsUnavailable' $language)) }
    elseif (@($data.resetDetails).Count -eq 0) { $lines.Add((Get-WidgetText 'detailsEmpty' $language)) }
    else {
        foreach ($row in @($data.resetDetails)) {
            $title = if ($row.title) { [string]$row.title } else { Get-WidgetText 'unnamedGrant' $language }
            $lines.Add($title)
            if ($row.description) { $lines.Add([string]$row.description) }
            foreach ($field in @(@('grantedAt','grant'), @('expiresAt','expiry'))) {
                $dateText = Get-WidgetText 'notProvided' $language
                if ($null -ne $row.($field[0])) {
                    try { $dateText = Format-WidgetDate ([DateTimeOffset]::FromUnixTimeSeconds([long]$row.($field[0]))) $language } catch { }
                }
                $lines.Add((Get-WidgetText $field[1] $language @($dateText)))
            }
            $lines.Add('')
        }
    }
    $lines.Add('')
    $lines.Add((Get-WidgetText 'detailsScope' $language))
    return $lines -join [Environment]::NewLine
}
function Read-WidgetJson([string]$path) {
    try { if (Test-Path -LiteralPath $path) { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } } catch { }
    return $null
}
function Write-WidgetJson([string]$path, $value) {
    $directory = Split-Path $path -Parent
    [void][System.IO.Directory]::CreateDirectory($directory)
    $temporary = Join-Path $directory ('.' + [IO.Path]::GetFileName($path) + '.' + [guid]::NewGuid() + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, ($value | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $path) { [IO.File]::Replace($temporary, $path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $path) }
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}
function Get-WidgetDataDirectory {
    $local = $env:LOCALAPPDATA
    if (-not $local) { $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData) }
    Join-Path $local 'CodexWeeklyMonitor'
}
function Initialize-WidgetStorage([string]$repositoryPath, [string]$dataDirectory = (Get-WidgetDataDirectory), [string]$legacyDirectory = (Join-Path $env:TEMP 'CodexWeeklyMonitor')) {
    [void][IO.Directory]::CreateDirectory($dataDirectory)
    if (-not $legacyDirectory -or -not (Test-Path -LiteralPath $legacyDirectory)) { return }
    $migrationMarker = Join-Path $dataDirectory '.migrated-from-temp.json'
    if (Test-Path -LiteralPath $migrationMarker) { return }
    foreach ($name in @('window.json', 'settings.json', 'state.json')) {
        $source = Join-Path $legacyDirectory $name; $destination = Join-Path $dataDirectory $name
        if ((Test-Path -LiteralPath $destination) -or -not (Test-Path -LiteralPath $source)) { continue }
        $value = Read-WidgetJson $source
        if (-not $value) { continue }
        if ($name -eq 'state.json') {
            $expected = [IO.Path]::GetFullPath((Join-Path $repositoryPath 'monitor.mjs'))
            if (-not [string]::Equals([string]$value.script, $expected, [StringComparison]::OrdinalIgnoreCase)) { continue }
        }
        # Keep the source intact so an interrupted migration is recoverable.
        Write-WidgetJson $destination $value
    }
    Write-WidgetJson $migrationMarker @{ version = 1 }
}
function Get-WidgetLanguageSetting([string]$dataDirectory = (Get-WidgetDataDirectory)) {
    $settings = Read-WidgetJson (Join-Path $dataDirectory 'settings.json')
    if ($settings -and $settings.language -in @('auto','en','zh-CN')) { return [string]$settings.language }
    return 'auto'
}
function Test-WidgetProcessOwnership($process, [string]$executable, [string]$scriptPath, [string]$startedAt) {
    if (-not $process -or -not $executable -or -not $scriptPath) { return $false }
    if (-not [string]::Equals([string]$process.ExecutablePath, $executable, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    # Accept only the unambiguous launch forms produced by Start.ps1. An owned
    # script mentioned in another program's arguments does not identify ownership.
    $commandLine = [string]$process.CommandLine
    if ($commandLine -match '[\r\n]') { return $false }
    $options = [Text.RegularExpressions.RegexOptions]::IgnoreCase
    $launch = [regex]::Match($commandLine, '^\s*(?:"(?<executable>[^"]+)"|(?<executable>[^\s"]+))\s+(?<arguments>.+?)\s*$', $options)
    if (-not $launch.Success) { return $false }
    $executableName = [regex]::Match($executable, '[^\\/]+$').Value
    $launchExecutable = $launch.Groups['executable'].Value
    if (-not [string]::Equals($launchExecutable, $executable, [StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::Equals($launchExecutable, $executableName, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    $arguments = $launch.Groups['arguments'].Value
    $scriptToken = '(?:"(?<script>[^"]+)"|(?<script>[^\s"]+))(?:\s+.*)?$'
    if ($executableName -ieq 'node.exe') {
        # Node options such as -e are rejected; our monitor launch has a script
        # as its first argument, followed only by any script arguments.
        $scriptArgument = [regex]::Match($arguments, '^' + $scriptToken, $options)
    } elseif ($executableName -ieq 'powershell.exe') {
        # Only known non-execution switches may precede -File. In particular,
        # -Command / -EncodedCommand must never masquerade as a -File launch.
        $switches = '(?:(?:-(?:NoProfile|Sta|NonInteractive|NoLogo))\s+|' +
            '-ExecutionPolicy\s+(?:"(?:Bypass|RemoteSigned|AllSigned|Restricted|Unrestricted|Default|Undefined)"|(?:Bypass|RemoteSigned|AllSigned|Restricted|Unrestricted|Default|Undefined))\s+|' +
            '-WindowStyle\s+(?:"(?:Hidden|Normal|Minimized|Maximized)"|(?:Hidden|Normal|Minimized|Maximized))\s+)*'
        $scriptArgument = [regex]::Match($arguments, '^' + $switches + '-File\s+' + $scriptToken, $options)
    } else { return $false }
    if (-not $scriptArgument.Success -or -not [string]::Equals($scriptArgument.Groups['script'].Value, $scriptPath, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if ($startedAt -and $process.CreationDate) {
        try {
            $recorded = [DateTimeOffset]::Parse($startedAt)
            $created = [DateTimeOffset]([datetime]$process.CreationDate)
            if ([Math]::Abs(($created - $recorded).TotalSeconds) -gt 10) { return $false }
        } catch { return $false }
    }
    return $true
}
function Find-WidgetNode([string]$repositoryPath) {
    $bundled = Join-Path $repositoryPath 'runtime/node.exe'
    $candidates = @($bundled)
    $command = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        try {
            $version = (& $candidate --version 2>$null | Select-Object -First 1)
            if ($LASTEXITCODE -eq 0 -and $version -match '^v(\d+)\.' -and [int]$Matches[1] -ge 24) { return [IO.Path]::GetFullPath($candidate) }
        } catch { }
    }
    return $null
}
function Find-WidgetCodex {
    if ($env:CODEX_CLI_PATH -and (Test-Path -LiteralPath $env:CODEX_CLI_PATH -PathType Leaf)) { return $env:CODEX_CLI_PATH }
    foreach ($name in @('codex.exe','codex.cmd')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    $candidates = @()
    if ($env:APPDATA) { $candidates += Join-Path $env:APPDATA 'npm/codex.cmd' }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs/Codex/resources/codex.exe'
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs/Codex/resources/app.asar.unpacked/node_modules/@openai/codex/vendor/x86_64-pc-windows-msvc/codex/codex.exe'
    }
    foreach ($candidate in $candidates) { if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [IO.Path]::GetFullPath($candidate) } }
    if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
        foreach ($package in @(Get-AppxPackage '*Codex*' -ErrorAction SilentlyContinue)) {
            if (-not $package.InstallLocation) { continue }
            $candidate = Get-ChildItem -LiteralPath $package.InstallLocation -Filter codex.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candidate) { return $candidate.FullName }
        }
    }
    return $null
}
function Enter-WidgetLifecycleLock([string]$dataDirectory, [string]$language) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($dataDirectory.ToLowerInvariant())))).Replace('-','').Substring(0,16) }
    finally { $hash.Dispose() }
    $mutex = New-Object System.Threading.Mutex($false, ('Local\CodexQuotaWidget-' + $key))
    $acquired = $false
    try { $acquired = $mutex.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { $mutex.Dispose(); Throw-WidgetError 'lockBusy' $language }
    return $mutex
}
function Show-WidgetFailure([string]$message, [string]$language) {
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show($message, (Get-WidgetText 'app' $language), [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error)
}

function Throw-WidgetError([string]$key, [string]$language, [object[]]$values = @()) {
    $error = [InvalidOperationException]::new((Get-WidgetText $key $language $values))
    $error.Data['widgetSafeMessage'] = $true
    throw $error
}
