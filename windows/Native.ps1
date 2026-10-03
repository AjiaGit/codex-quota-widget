# Shared native helpers. Dot-source this file; it does not start a service or UI.
$script:WidgetStrings = @{
    en = @{
        newGrant = 'New banked reset grant announcement · Click for details'; newGlobalReset = 'New global reset announcement · Click for details'; newAnnouncements = 'New banked reset grant and global reset announcements · Click for details'
        app = 'Codex Quota'; loading = 'Loading'; reading = 'Reading quota'; updated = 'Updated'; unavailable = 'Unavailable'; refreshing = 'Refreshing'
        compact = 'Mini'; refresh = 'Refresh'; weekly = 'Weekly remaining'; untilReset = 'Until reset'; reset = 'Resets {0}'; resetUnknown = 'Reset time —'
        lastUpdated = 'Updated {0}'; stale = 'Data is stale. Refresh to update.'; cards = 'Banked resets {0}'; cardsUnknown = 'Banked resets —'
        fiveHour = 'Plus · 5-hour quota'; percentRemaining = '{0}% remaining'; external = 'Public global resets'; lastAnnouncement = 'Announced {0} · {1}'
        paid = 'Paid accounts'; all = 'All accounts'; unknownScope = 'Account scope: see announcement'; delivered = 'Delivered {0}'; deliveryUnknown = 'Delivery not confirmed'
        publicUnavailable = 'Public reset data unavailable'; deliveryEmpty = 'Delivery time —'; probability = 'Estimated odds: 24h {0}% · 48h {1}% · 7d {2}%'
        oddsUnknown = 'Estimated odds unavailable'; attribution = 'Historical estimate · codexreset.ai / whenreset.app'; publicSource = 'Public data · codexreset.ai'
        tipRefresh = 'Refresh quota now'; tipHide = 'Hide to tray'; tipCompact = 'Switch to mini widget'; tipExpand = 'Click to expand; drag to move'
        tipResize = 'Drag the edge to resize'; tipOdds = 'Estimate from public global reset history; not an account reset time or an OpenAI promise.'
        tipRemaining = 'Weekly remaining {0}% · click to expand'; tipUnavailable = 'Quota unavailable · click to expand'; tipDrag = 'Drag to move'
        show = 'Show widget'; mode = 'Switch mini / detail'; hide = 'Hide to tray'; refreshNow = 'Refresh now'; onTop = 'Always on top'; quit = 'Quit quota widget'
        language = 'Language'; languageAuto = 'System'; languageEn = 'English'; languageZh = '简体中文'; languageSaveFailed = 'Could not save the language. Try again.'
        trayRemaining = 'Codex weekly remaining {0}%'; trayUnavailable = 'Codex quota unavailable'; dayHour = '{0}d {1}h'; hourMinute = '{0}h {1}m'; minute = '{0}m'
        detailsTitle = 'Banked reset details'; detailsCount = 'Available banked resets: {0}'; detailsUnknownCount = 'Available banked resets: Not provided'
        detailsUnavailable = 'Grant and expiry details were not provided.'; detailsPending = 'Quota data unavailable or expired; refresh to view current reset details.'; detailsEmpty = 'No grant or expiry rows were provided.'
        detailsScope = 'Only details returned by Codex are shown. This is not a complete history or a prediction.'; grant = 'Granted: {0}'; expiry = 'Expires: {0}'; notProvided = 'Not provided'; unnamedGrant = 'Banked reset'
        openDetails = 'View banked reset details'; setup = 'Set up Codex'; setupTip = 'Install Codex CLI or sign in, then refresh.'
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
        justNow = 'Updated just now'; minuteAgo = 'Updated 1 minute ago'; minutesAgo = 'Updated {0} minutes ago'; updateUnknown = 'Update time unavailable'
        creditDetailsRow = '{0} · Details ›'; confirmedBanked = 'Confirmed banked reset grant'; confirmedRegular = 'Confirmed global reset'
        noAnnouncements = 'Monitored sources report no confirmed banked reset grants or global resets'; announcementsUnavailable = 'Confirmed announcements unavailable'; pendingUpdate = 'Information pending update'
        retention = 'Completed results retained for 24h'; forecastPending = 'Public estimates pending update'; phaseUpcoming = 'Upcoming'; phaseWaiting = 'Scheduled time passed; monitoring sources have no completion record'; phaseAnnounced = 'Announced · awaiting delivery'; phaseUnknown = 'Source did not provide a delivery record'; phaseDelivered = 'Delivered'; phaseArchived = 'Delivered'
        scheduled = 'Scheduled {0}'; originalScheduled = 'Originally scheduled {0}'; scheduleUnknown = 'Delivery time not announced'; announcedOn = 'Published: {0}'; deliveredOn = 'Completed {0}'
        scheduledGrant = 'Scheduled grant: {0}'; scheduledReset = 'Scheduled reset: {0}'; originalGrant = 'Originally scheduled grant: {0}'; originalReset = 'Originally scheduled reset: {0}'
        localAnnouncementTime = '{0} (local {1})'; dateOnlySchedule = '{0} (time not announced)'
        sourceTimeZoneNote = 'Converted from {0} by the monitoring source; see original post.'; sourceWithdrawn = 'Monitoring sources no longer list this record'; withdrawnRecord = 'Record withdrawn by sources'
        publicUpdated = 'Public data updated {0}'; publicUpdateUnknown = 'Public update time unavailable'; refreshCadence = 'Auto-refresh: quota every 1 min · public data every 10 min'; sourceLinks = 'codexreset.ai / whenreset.app'
        announcementSource = 'View announcement'; deliverySource = 'Delivery record'; announcementHistory = 'Announcement & delivery history'; historyEmpty = 'No announcement or delivery records'
        oddsTitle = 'Estimated global reset odds'; odds24 = '24 hours'; odds48 = '48 hours'; odds7d = '7 days'; oddsNote = 'Historical frequency estimate, not a promised reset or your weekly account reset.'
        expandHistory = 'Show announcement and delivery history'; collapseHistory = 'Hide announcement and delivery history'
    }
    'zh-CN' = @{
        newGrant = '有新的重置次数赠送公告，点击查看详情'; newGlobalReset = '有新的全局额度重置公告，点击查看详情'; newAnnouncements = '有新的重置次数赠送和全局额度重置公告，点击查看详情'
        app = 'Codex 周额度'; loading = '读取中'; reading = '正在读取额度'; updated = '数据已更新'; unavailable = '暂不可用'; refreshing = '正在刷新'
        compact = '极简'; refresh = '刷新'; weekly = '本周剩余'; untilReset = '距离重置'; reset = '重置 {0}'; resetUnknown = '重置时间 —'
        lastUpdated = '最近更新 {0}'; stale = '数据已过期，请刷新'; cards = '可用重置 {0}次'; cardsUnknown = '可用重置 —'
        fiveHour = 'Plus · 5小时额度'; percentRemaining = '{0}% 剩余'; external = '公开全局额度重置'; lastAnnouncement = '上次公告 {0} · {1}'
        paid = '付费账号'; all = '全部账号'; unknownScope = '适用范围详见公告'; delivered = '记录送达 {0}'; deliveryUnknown = '送达时间未确认'
        publicUnavailable = '上次公开重置暂不可用'; deliveryEmpty = '送达时间 —'; probability = '历史估计 24h {0}% · 48h {1}% · 7天 {2}%'
        oddsUnknown = '历史概率估计暂不可用'; attribution = '历史频率估计 · codexreset.ai / whenreset.app'; publicSource = '公开数据 · codexreset.ai'
        tipRefresh = '立即刷新额度'; tipHide = '隐藏到系统托盘'; tipCompact = '切换到极简悬浮窗'; tipExpand = '单击展开，拖动可调整位置'
        tipResize = '拖动边缘调整大小'; tipOdds = '公开全局额度重置的历史频率估计，不是账号每周重置时间，也不是 OpenAI 承诺。'
        tipRemaining = '本周剩余 {0}% · 单击展开'; tipUnavailable = '额度暂不可用 · 单击展开'; tipDrag = '拖动悬浮窗'
        show = '显示悬浮窗'; mode = '切换极简 / 详细'; hide = '隐藏到托盘'; refreshNow = '立即刷新'; onTop = '始终置顶'; quit = '退出额度工具'
        language = '语言'; languageAuto = '跟随系统'; languageEn = 'English'; languageZh = '简体中文'; languageSaveFailed = '语言设置保存失败，请重试。'
        trayRemaining = 'Codex 本周剩余 {0}%'; trayUnavailable = 'Codex 周额度暂不可用'; dayHour = '{0}天 {1}小时'; hourMinute = '{0}小时 {1}分'; minute = '{0}分钟'
        detailsTitle = '额度重置明细'; detailsCount = '可用重置次数：{0}'; detailsUnknownCount = '可用重置次数：未提供'
        detailsUnavailable = 'Codex 未提供发放和到期明细。'; detailsPending = '额度数据暂不可用或已过期，请刷新后查看重置详情。'; detailsEmpty = '未提供发放或到期记录。'
        detailsScope = '仅显示 Codex 返回的明细，不代表完整历史或未来发放。'; grant = '发放：{0}'; expiry = '到期：{0}'; notProvided = '未提供'; unnamedGrant = '可用重置'
        openDetails = '查看额度重置明细'; setup = '设置 Codex'; setupTip = '安装 Codex CLI 或登录后，再刷新。'
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
        justNow = '刚刚更新'; minuteAgo = '1分钟前更新'; minutesAgo = '{0}分钟前更新'; updateUnknown = '更新时间暂不可用'
        creditDetailsRow = '{0} · 查看明细 ›'; confirmedBanked = '已确认重置次数赠送'; confirmedRegular = '已确认全局额度重置'
        noAnnouncements = '监控来源暂无已确认的重置次数赠送或全局额度重置公告'; announcementsUnavailable = '已确认公告暂不可用'; pendingUpdate = '信息待更新'
        retention = '完成结果保留24小时'; forecastPending = '公开概率信息待更新'; phaseUpcoming = '即将进行'; phaseWaiting = '预定时间已过，监控来源未提供完成记录'; phaseAnnounced = '已公告 · 等待送达'; phaseUnknown = '来源未提供送达记录'; phaseDelivered = '已送达'; phaseArchived = '已送达'
        scheduled = '计划 {0}'; originalScheduled = '原定 {0}'; scheduleUnknown = '送达时间尚未公布'; announcedOn = '公告发布 {0}'; deliveredOn = '确认完成 {0}'
        scheduledGrant = '预定送达 {0}'; scheduledReset = '预定重置 {0}'; originalGrant = '原定送达 {0}'; originalReset = '原定重置 {0}'
        localAnnouncementTime = '{0}（本地 {1}）'; dateOnlySchedule = '{0}（具体时间未公布）'
        sourceTimeZoneNote = '来源按 {0} 时区换算；原文见公告。'; sourceWithdrawn = '监控来源已撤下此记录'; withdrawnRecord = '来源已撤下的公告记录'
        publicUpdated = '公告数据更新 {0}'; publicUpdateUnknown = '公告更新时间暂不可用'; refreshCadence = '自动刷新：额度每1分钟 · 公共信息每10分钟'; sourceLinks = 'codexreset.ai / whenreset.app'
        announcementSource = '查看公告'; deliverySource = '送达记录'; announcementHistory = '公告与送达记录'; historyEmpty = '暂无公告与送达记录'
        oddsTitle = '未来全局额度重置概率'; odds24 = '24小时'; odds48 = '48小时'; odds7d = '7天'; oddsNote = '历史频率估计，不代表重置承诺，也不是账号每周重置时间。'
        expandHistory = '展开公告与送达记录'; collapseHistory = '收起公告与送达记录'
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

function Format-WidgetAnnouncementDate([DateTimeOffset]$date, [string]$language, [TimeZoneInfo]$timeZone = [TimeZoneInfo]::Local, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $local=[TimeZoneInfo]::ConvertTime($date,$timeZone)
    $cultureName=if ((Resolve-WidgetLanguage $language) -eq 'zh-CN') {'zh-CN'} else {'en-US'}
    $format=if ($cultureName -eq 'zh-CN') {'M月d日 HH:mm'} else {'MMM d HH:mm'}
    if ($local.Year -ne ([TimeZoneInfo]::ConvertTime($now,$timeZone)).Year) {
        $format=if ($cultureName -eq 'zh-CN') {'yyyy年M月d日 HH:mm'} else {'MMM d yyyy HH:mm'}
    }
    # ConvertTime selects the offset at this event instant, including DST.
    $offset=[int]$local.Offset.TotalMinutes
    $sign=if ($offset -lt 0) {'-'} else {'+'}
    $magnitude=[Math]::Abs($offset)
    $zone=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'UTC{0}{1:00}:{2:00}', $sign, [int][Math]::Floor($magnitude/60), ($magnitude%60))
    Get-WidgetText 'localAnnouncementTime' $language @($local.ToString($format,[Globalization.CultureInfo]::GetCultureInfo($cultureName)),$zone)
}

function Format-WidgetRelativeUpdate($updatedAt, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    if ($null -eq $updatedAt) { return Get-WidgetText 'updateUnknown' $language }
    try {
        $age = $now - [DateTimeOffset]::FromUnixTimeMilliseconds([long]$updatedAt)
        if ($age.TotalSeconds -lt -60) { return Get-WidgetText 'updateUnknown' $language }
        $minutes = [Math]::Max(0, [int][Math]::Floor($age.TotalMinutes))
        if ($minutes -lt 1) { return Get-WidgetText 'justNow' $language }
        if ($minutes -eq 1) { return Get-WidgetText 'minuteAgo' $language }
        return Get-WidgetText 'minutesAgo' $language @($minutes)
    } catch { return Get-WidgetText 'updateUnknown' $language }
}
function Get-WidgetHeaderLayout([int]$width, [int]$titleWidth, [int]$statusWidth) {
    $left = 18; $buttonSize = 32; $gap = 6
    $toolbarLeft = $width - $left - 3 * $buttonSize - 2 * $gap
    $secondRow = $left + $titleWidth + 12 + $statusWidth + 12 -gt $toolbarLeft
    $buttons = @()
    foreach ($kind in @('refresh','compact','hide')) {
        $buttons += [pscustomobject]@{ kind=$kind; x=$toolbarLeft+$buttons.Count*($buttonSize+$gap); y=10; width=$buttonSize; height=$buttonSize }
    }
    [pscustomobject]@{
        titleX=$left; titleY=10; titleWidth=[Math]::Min($titleWidth,$toolbarLeft-$left-12)
        statusX=$(if ($secondRow) {$left} else {$left+$titleWidth+12})
        statusY=$(if ($secondRow) {42} else {10}); statusWidth=$(if ($secondRow) {$width-2*$left} else {$toolbarLeft-$left-$titleWidth-24})
        statusSecondRow=$secondRow; height=$(if ($secondRow) {72} else {54}); buttons=$buttons
    }
}
function Get-WidgetOddsColumns([int]$width) {
    $gap=8; $columnWidth=[int][Math]::Floor(($width-2*$gap)/3)
    for ($i=0; $i -lt 3; $i++) {
        $x=$i*($columnWidth+$gap)
        [pscustomobject]@{ x=$x; width=$(if ($i -eq 2) {$width-$x} else {$columnWidth}) }
    }
}
function Get-WidgetDetailSectionOrder([bool]$plus) {
    'hero'
    if ($plus) { 'fiveHour' }
    'credits'; 'announcements'; 'probability'; 'history'; 'sources'
}
function ConvertTo-WidgetTimestamp($value) {
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return $null }
    $parsed=[DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse([string]$value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)) { return $parsed }
    return $null
}
function Get-WidgetAnnouncementPhase($row, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    if ($row.sourceWithdrawn) { return 'unknown' }
    $delivered=ConvertTo-WidgetTimestamp $row.deliveredAt
    if ($delivered -and $delivered -le $now) {
        if (($now-$delivered).TotalHours -ge 24) { return 'archived' }
        return 'delivered'
    }
    $scheduled=ConvertTo-WidgetTimestamp $row.scheduledAt
    if ($scheduled) {
        if ($scheduled -le $now) { return 'waiting' }
        return 'upcoming'
    }
    if ($row.scheduledDate -match '^\d{4}-\d{2}-\d{2}$') {
        $day=[datetime]::MinValue
        if ([datetime]::TryParseExact([string]$row.scheduledDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$day)) {
            # Match the service/browser calendar boundary without displaying an
            # invented delivery time for a date-only announcement.
            $end=[DateTimeOffset]::new([datetime]::SpecifyKind($day.AddDays(1),[DateTimeKind]::Utc))
            if ($now -ge $end) { return 'waiting' }
            return 'upcoming'
        }
    }
    return 'announced'
}
function Test-WidgetHttpsUrl([string]$url) {
    if (-not $url -or $url -match '[\x00-\x20]') { return $false }
    $uri=$null
    [Uri]::TryCreate($url,[UriKind]::Absolute,[ref]$uri) -and $uri.Scheme -eq 'https' -and -not [string]::IsNullOrWhiteSpace($uri.Host) -and [string]::IsNullOrEmpty($uri.UserInfo)
}
function Get-WidgetAnnouncementKey($row) {
    if ($row.id) { return "$($row.kind):$($row.id)" }
    return "$($row.kind):$($row.sourceUrl):$($row.announcedAt):$($row.scheduledAt):$($row.scheduledDate)"
}
function Format-WidgetPublicUpdate($feed, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $updated=ConvertTo-WidgetTimestamp $feed.sourceUpdatedAt
    if ($updated -and $updated -le $now) { return Get-WidgetText 'publicUpdated' $language @((Format-WidgetDate $updated $language)) }
    return Get-WidgetText 'publicUpdateUnknown' $language
}
function Get-WidgetForecastView($external, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $forecast=if ($external -and $external.status -eq 'ok') {$external.forecast} else {$null}
    $available=$false; $values=@($null,$null,$null)
    if ($forecast) {
        try {
            $updated=ConvertTo-WidgetTimestamp $forecast.sourceUpdatedAt
            if ($updated -and $updated -le $now.AddMinutes(5) -and ($now-$updated).TotalHours -le 24) {
                $numbers=@(); $valid=$true
                foreach ($field in @('next24h','next48h','next7d')) {
                    if ($null -eq $forecast.$field) {$valid=$false;break}
                    $number=[double]$forecast.$field
                    if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt 0 -or $number -gt 100) {$valid=$false;break}
                    $numbers+=,$number
                }
                if ($valid -and $numbers.Count -eq 3 -and $numbers[0] -le $numbers[1] -and $numbers[1] -le $numbers[2]) {$available=$true;$values=$numbers}
            }
        } catch { }
    }
    [pscustomobject]@{available=$available;values=$values;pendingText=$(if (-not $available) {Get-WidgetText 'forecastPending' $language} else {''})}
}
function Get-WidgetFiveHourView($quota, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $visible=$quota -and $quota.status -eq 'ok' -and $quota.plan -eq 'plus'
    $percentText=Get-WidgetText 'unavailable' $language; $resetText=Get-WidgetText 'resetUnknown' $language
    if ($visible -and $quota.fiveHour -and $null -ne $quota.updatedAt -and $null -ne $quota.fiveHour.remainingPercent -and $null -ne $quota.fiveHour.resetsAt) {
        try {
            $age=$now-[DateTimeOffset]::FromUnixTimeMilliseconds([long]$quota.updatedAt)
            $resetAt=[DateTimeOffset]::FromUnixTimeSeconds([long]$quota.fiveHour.resetsAt)
            $remaining=[double]$quota.fiveHour.remainingPercent
            if ($age.TotalMinutes -le 10 -and $age.TotalSeconds -ge -60 -and $resetAt -gt $now -and $remaining -ge 0 -and $remaining -le 100) {
                $percentText=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'{0}%',@($remaining))
                $resetText=Get-WidgetText 'reset' $language @((Format-WidgetDate $resetAt $language))
            }
        } catch { }
    }
    [pscustomobject]@{visible=[bool]$visible;percentText=$percentText;resetText=$resetText}
}
function Get-WidgetAnnouncementAlertView($alerts, [string]$language) {
    $ids=@(); $kinds=@()
    foreach ($row in @($alerts.unread)) {
        if (-not $row -or $row.kind -notin @('banked','regular')) {continue}
        $id=[string]$row.id; $suffix='#'+[string]$row.kind
        if (-not $id.EndsWith($suffix,[StringComparison]::Ordinal)) {continue}
        if (-not (Test-WidgetHttpsUrl $id.Substring(0,$id.Length-$suffix.Length))) {continue}
        $ids+=,$id; $kinds+=,[string]$row.kind
        if ($ids.Count -ge 100) {break}
    }
    $key=if (($kinds | Select-Object -Unique).Count -gt 1) {'newAnnouncements'} elseif ($kinds -contains 'banked') {'newGrant'} else {'newGlobalReset'}
    [pscustomobject]@{ids=@($ids);hasUnread=($ids.Count -gt 0);tooltip=$(if ($ids.Count) {Get-WidgetText $key $language} else {''})}
}
function Get-WidgetAnnouncementReadIds($alerts, $view, [bool]$visible) {
    if (-not $visible) {return ,@()}
    $rendered=@{}
    foreach ($row in @($view.active)+@($view.history)) {if ($row) {$rendered[[string]$row.key]=$true}}
    return ,@($alerts.ids | Where-Object {$rendered.ContainsKey([string]$_)})
}
function Get-WidgetNoticeBounds([double]$width, [double]$height) {
    $diameter=[Math]::Max(5,[Math]::Min(8,[Math]::Min($width,$height)*0.12))
    [pscustomobject]@{x=$width-$diameter-5;y=5;width=$diameter;height=$diameter}
}
function ConvertTo-WidgetAnnouncementRow($row, [string]$language, [DateTimeOffset]$now, [bool]$historical = $false, [TimeZoneInfo]$timeZone = [TimeZoneInfo]::Local) {
    $phase=Get-WidgetAnnouncementPhase $row $now
    $completed=$phase -in @('delivered','archived')
    if ($historical -and -not $completed) { $phase='unknown' }
    $scheduleKey=$(if ($completed) {'original'} else {'scheduled'})+$(if ($row.kind -eq 'banked') {'Grant'} else {'Reset'})
    $scheduledText=$null; $completedText=$null; $announcedText=$null
    $delivered=ConvertTo-WidgetTimestamp $row.deliveredAt
    $scheduled=ConvertTo-WidgetTimestamp $row.scheduledAt
    if ($scheduled) { $scheduledText=Get-WidgetText $scheduleKey $language @((Format-WidgetAnnouncementDate $scheduled $language $timeZone $now)) }
    elseif ($row.scheduledDate -match '^\d{4}-\d{2}-\d{2}$') {
        $date=[datetime]::MinValue
        if ([datetime]::TryParseExact([string]$row.scheduledDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date)) {
            $format=if ((Resolve-WidgetLanguage $language) -eq 'zh-CN') {'M月d日'} else {'MMM d'}
            $culture=if ((Resolve-WidgetLanguage $language) -eq 'zh-CN') {'zh-CN'} else {'en-US'}
            $dateText=Get-WidgetText 'dateOnlySchedule' $language @($date.ToString($format,[Globalization.CultureInfo]::GetCultureInfo($culture)))
            $scheduledText=Get-WidgetText $scheduleKey $language @($dateText)
        }
    }
    if (-not $scheduledText -and -not $completed -and -not $historical) { $scheduledText=Get-WidgetText 'scheduleUnknown' $language }
    if ($completed) { $completedText=Get-WidgetText 'deliveredOn' $language @((Format-WidgetAnnouncementDate $delivered $language $timeZone $now)) }
    $announced=ConvertTo-WidgetTimestamp $row.announcedAt
    if ($announced) { $announcedText=Get-WidgetText 'announcedOn' $language @((Format-WidgetAnnouncementDate $announced $language $timeZone $now)) }
    $scope=if ($row.scope -eq 'paid') {Get-WidgetText 'paid' $language} elseif ($row.scope -eq 'all') {Get-WidgetText 'all' $language} elseif ($row.scopeLabel) {[string]$row.scopeLabel} else {Get-WidgetText 'unknownScope' $language}
    $phaseKey=if ($row.sourceWithdrawn) {'sourceWithdrawn'} else {'phase'+(Get-Culture).TextInfo.ToTitleCase($phase)}
    $scheduleNote=if ($scheduled -and $row.scheduledTimeZone) {Get-WidgetText 'sourceTimeZoneNote' $language @([string]$row.scheduledTimeZone)} else {''}
    $summary=if ((Resolve-WidgetLanguage $language) -eq 'zh-CN' -and $row.summaryZh) {[string]$row.summaryZh} elseif ($row.summary) {[string]$row.summary} else {''}
    $details=@((Get-WidgetText $phaseKey $language))
    if ($scheduledText) {$details+=,$scheduledText}
    if ($completedText) {$details+=,$completedText}
    if ($announcedText) {$details+=,$announcedText}
    if ($scheduleNote) {$details+=,$scheduleNote}
    $details+=,$scope
    [pscustomobject]@{
        key=Get-WidgetAnnouncementKey $row; phase=$phase
        title=Get-WidgetText $(if ($row.sourceWithdrawn) {'withdrawnRecord'} elseif ($row.kind -eq 'banked') {'confirmedBanked'} else {'confirmedRegular'}) $language
        details=$details -join ' · '; scheduledText=$scheduledText; completedText=$completedText; announcedText=$announcedText; scheduleNote=$scheduleNote; scopeText=$scope
        summary=$summary
        retentionText=$(if ($phase -eq 'delivered') {Get-WidgetText 'retention' $language} else {''})
        sourceUrl=$(if (Test-WidgetHttpsUrl $row.sourceUrl) {[string]$row.sourceUrl} else {$null})
        deliverySourceUrl=$(if ($completed -and (Test-WidgetHttpsUrl $row.deliverySourceUrl)) {[string]$row.deliverySourceUrl} else {$null})
    }
}
function Get-WidgetAnnouncementView($external, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $active=New-Object 'System.Collections.Generic.List[object]'; $history=New-Object 'System.Collections.Generic.List[object]'
    $feed=if ($external) {$external.announcements} else {$null}
    $stamp=ConvertTo-WidgetTimestamp $feed.sourceUpdatedAt
    $stale=-not $feed -or $feed.stale -or $feed.status -ne 'ok' -or -not $stamp -or $stamp -gt $now.AddMinutes(5) -or ($now-$stamp).TotalHours -gt 24
    $seen=@{}
    foreach ($row in @($feed.items)) {
        if (-not $row -or $row.kind -notin @('banked','regular')) { continue }
        $key=Get-WidgetAnnouncementKey $row
        if ($seen.ContainsKey($key)) { continue }; $seen[$key]=$true
        $view=ConvertTo-WidgetAnnouncementRow $row $language $now
        if ($view.phase -eq 'archived' -or $row.sourceWithdrawn) {$history.Add($view)} else {$active.Add($view)}
    }
    foreach ($row in @($feed.history)) {
        if (-not $row -or $row.kind -notin @('banked','regular')) { continue }
        $key=Get-WidgetAnnouncementKey $row
        if ($seen.ContainsKey($key)) { continue }; $seen[$key]=$true
        $history.Add((ConvertTo-WidgetAnnouncementRow $row $language $now $true))
    }
    [pscustomobject]@{
        active=@($active.ToArray()); history=@($history.ToArray())
        emptyText=Get-WidgetText $(if (-not $stale) {'noAnnouncements'} else {'announcementsUnavailable'}) $language
        staleText=$(if ($active.Count -gt 0 -and $stale) {Get-WidgetText 'pendingUpdate' $language} else {''})
        sourceUpdateText=$(if ($active.Count -gt 0 -and $stale) {Format-WidgetPublicUpdate $feed $language $now} else {''})
    }
}
function Merge-WidgetExternalData($previous, $incoming, [bool]$transportFailure = $false) {
    # Clone the public response so a failure cannot mutate a previously cached
    # successful snapshot. Persisted known rows survive an empty schedule feed.
    $basis=if ($incoming -and -not $transportFailure) {$incoming} elseif ($previous) {$previous} else {[pscustomobject]@{status='unavailable';forecast=$null}}
    $result=$basis | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $fresh=if ($incoming -and -not $transportFailure) {$incoming.announcements} else {$null}
    $old=if ($previous) {$previous.announcements} else {$null}
    $feed=if ($fresh) {$fresh | ConvertTo-Json -Depth 12 | ConvertFrom-Json} elseif ($old) {$old | ConvertTo-Json -Depth 12 | ConvertFrom-Json} else {[pscustomobject]@{status='unavailable';items=@();history=@();sourceUpdatedAt=$null;stale=$true}}
    $entries=[ordered]@{}
    foreach ($snapshot in @($old,$fresh)) {
        if (-not $snapshot) { continue }
        # A source may retain the same canonical row in both collections. Its
        # active collection owns the 24-hour display lifecycle; history only
        # wins when the newer source snapshot no longer includes it as active.
        foreach ($bucket in @('history','items')) {
            foreach ($row in @($snapshot.$bucket)) {
                if (-not $row -or $row.kind -notin @('banked','regular')) { continue }
                $identity=Get-WidgetAnnouncementKey $row
                $copy=$row | ConvertTo-Json -Depth 8 | ConvertFrom-Json
                if ($entries.Contains($identity)) {
                    $known=$entries[$identity].row
                    foreach ($field in @('deliveredAt','scheduledAt','scheduledDate','announcedAt','sourceUrl','deliverySourceUrl')) {
                        if (-not $copy.$field -and $known.$field) { $copy | Add-Member -NotePropertyName $field -NotePropertyValue $known.$field -Force }
                    }
                }
                $entries[$identity]=[pscustomobject]@{row=$copy;bucket=$bucket}
            }
        }
    }
    $feed | Add-Member -NotePropertyName items -NotePropertyValue @($entries.Values | Where-Object {$_.bucket -eq 'items'} | ForEach-Object {$_.row}) -Force
    $feed | Add-Member -NotePropertyName history -NotePropertyValue @($entries.Values | Where-Object {$_.bucket -eq 'history'} | ForEach-Object {$_.row}) -Force
    if ($transportFailure -or -not $fresh -or $fresh.status -ne 'ok') {
        if ($transportFailure -or -not $incoming) {
            $result | Add-Member -NotePropertyName status -NotePropertyValue 'unavailable' -Force
            $result | Add-Member -NotePropertyName forecast -NotePropertyValue $null -Force
        }
        $feed | Add-Member -NotePropertyName stale -NotePropertyValue $true -Force
        if ($entries.Count -gt 0) {$feed | Add-Member -NotePropertyName status -NotePropertyValue 'ok' -Force}
    }
    $result | Add-Member -NotePropertyName announcements -NotePropertyValue $feed -Force
    return $result
}

function Format-WidgetResetDetails($data, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $fresh=$false
    if ($data -and $data.status -eq 'ok' -and $null -ne $data.updatedAt -and $null -ne $data.resetsAt -and $null -ne $data.remainingPercent) {
        try {
            $age=$now-[DateTimeOffset]::FromUnixTimeMilliseconds([long]$data.updatedAt)
            $resetAt=[DateTimeOffset]::FromUnixTimeSeconds([long]$data.resetsAt)
            $percent=[double]$data.remainingPercent
            $fresh=$age.TotalMinutes -le 10 -and $age.TotalSeconds -ge -60 -and $resetAt -gt $now -and $percent -ge 0 -and $percent -le 100
        } catch {}
    }
    if (-not $fresh) {$data=$null}
    $lines = New-Object 'System.Collections.Generic.List[string]'
    if ($data -and $null -ne $data.resetCards) { $lines.Add((Get-WidgetText 'detailsCount' $language @($data.resetCards))) }
    else { $lines.Add((Get-WidgetText 'detailsUnknownCount' $language)) }
    $lines.Add('')
    if (-not $fresh) { $lines.Add((Get-WidgetText 'detailsPending' $language)) }
    elseif ($null -eq $data.resetDetails) { $lines.Add((Get-WidgetText 'detailsUnavailable' $language)) }
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
function Get-WidgetModePosition($saved, [ValidateSet('Detail','Compact')][string]$mode) {
    if (-not $saved) { return $null }
    $prefix = $mode.ToLowerInvariant()
    $x = $saved.($prefix + 'X'); $y = $saved.($prefix + 'Y')
    if ($null -eq $x -or $null -eq $y) {
        if ($saved.mode -ne $mode) { return $null }
        $x = $saved.x; $y = $saved.y
    }
    if ([string]$x -notmatch '^-?\d{1,9}$' -or [string]$y -notmatch '^-?\d{1,9}$') { return $null }
    return [pscustomobject]@{ x = [int]$x; y = [int]$y }
}
function Get-WidgetTransitionPosition($current, $remembered, $size, $screen) {
    if ($remembered) { $x = $remembered.x; $y = $remembered.y }
    else {
        $rightAnchor = ($current.Left + $current.Width / 2) -gt ($screen.Left + $screen.Width / 2)
        $bottomAnchor = ($current.Top + $current.Height / 2) -gt ($screen.Top + $screen.Height / 2)
        $x = if ($rightAnchor) { $current.Right - $size.Width } else { $current.Left }
        $y = if ($bottomAnchor) { $current.Bottom - $size.Height } else { $current.Top }
    }
    return [pscustomobject]@{
        x = [int][Math]::Max($screen.Left, [Math]::Min($x, $screen.Right - $size.Width))
        y = [int][Math]::Max($screen.Top, [Math]::Min($y, $screen.Bottom - $size.Height))
    }
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
            # Read the native process to completion before inspecting its exit status.
            # Select-Object -First 1 in the native pipeline can stop it too early.
            $versionLines = @(& $candidate --version 2>$null)
            $probeExitCode = $LASTEXITCODE
            $version = $versionLines | Select-Object -First 1
            if ($probeExitCode -eq 0 -and $version -match '^v(\d+)\.' -and [int]$Matches[1] -ge 24) { return [IO.Path]::GetFullPath($candidate) }
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
