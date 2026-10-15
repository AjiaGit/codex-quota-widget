# Shared native helpers. Dot-source this file; it does not start a service or UI.
$script:WidgetStrings = @{
    en = @{
        activityHeading = 'Reset updates'
        accountType = 'Your account'
        publicType = 'Public update'
        recoveryRestored = 'Your quota recovered'
        recoveryHelp = 'Observed from local quota readings. The detection time is not the exact reset time and does not confirm a global cause.'
        earlierUpdates = 'Earlier updates ({0})'
        activityEmpty = 'No recent updates'
        activityEmptyHelp = 'Earlier records are available in History.'
        localTimeNote = 'All times are local (currently {0})'
        publicRefreshFailed = 'Public updates could not be fetched'
        publicStale = 'Public announcement source has not updated'
        publicInvalid = 'Public source returned unusable data'
        publicSourceDelayed = 'Recent announcements may not be included'
        publicSourceTime = 'Source data updated {0}'
        publicPending = 'Public information pending update'
        publicCache = 'Showing saved public updates'
        publicNoCache = 'No saved public updates are available.'
        publicRetry = 'Retry'
        lastFetched = 'Last successful refresh {0}'
        dataSources = 'Data sources'
        moreMessage = 'Message details'
        completionNotProvided = 'Completion time: not provided by source'
        upcomingGrantTitle = 'Banked reset grant announced'
        upcomingResetTitle = 'Global reset announced'
        deliveredGrantTitle = 'Source recorded a reset grant'
        deliveredResetTitle = 'Source recorded a global reset'
        unconfirmedGrantTitle = 'Reset grant update'
        unconfirmedResetTitle = 'Quota reset update'
        recoveryMore = 'About this record'
        publicRetrying = 'Refreshing public updates'
        detailsPartial = 'The list may be incomplete; the available count above is authoritative.'
        historyAttribution = 'Earlier historical records'
        resetLabel = 'Banked resets'
        disclosureDetails = 'Details'
        recoveryCount = '{0} records'; recoveryNone = 'No records'; relatedBanked = 'Banked reset news'; relatedRegular = 'Global reset news'; phaseUnconfirmed = 'Tracker has no completion time'; sourceScope = 'Tracker scope: {0}'; postedOn = 'Posted: {0}'
        recoveryTitle = 'My quota recoveries'; recoveryDetected = 'Noticed locally: {0}'; recoveryObserved = 'Previous reading: {0}'; recoveryExplanation = 'Changes to your own quota.'; recoveryTracking = 'Recording since {0}.'; recoveryEmpty = 'No new quota recovery recorded yet.'; recoveryUnavailable = 'Tracking unavailable. Refresh after signing in to Codex.'; recoveryUnsaved = 'Local saving failed; new records may be lost when the app closes.'
        newGrant = 'New banked reset grant announcement · Click for details'; newGlobalReset = 'New global reset announcement · Click for details'; newAnnouncements = 'New banked reset grant and global reset announcements · Click for details'
        app = 'Codex quota'; loading = 'Loading'; reading = 'Reading quota'; updated = 'Updated'; unavailable = 'Unavailable'; refreshing = 'Refreshing'
        compact = 'Mini'; refresh = 'Refresh'; weekly = 'Weekly remaining'; untilReset = 'Time to reset'; reset = 'Resets {0}'; resetUnknown = 'Reset time —'
        lastUpdated = 'Updated {0}'; stale = 'Data is stale. Refresh to update.'; cards = 'Banked resets {0}'; cardsUnknown = 'Banked resets —'
        fiveHour = 'Plus · 5-hour quota'; percentRemaining = '{0}% remaining'; external = 'Public global resets'; lastAnnouncement = 'Announced {0} · {1}'
        paid = 'Paid accounts'; all = 'All accounts'; unknownScope = 'Account scope: see announcement'; delivered = 'Delivered {0}'; deliveryUnknown = 'Delivery not confirmed'
        publicUnavailable = 'Public reset data unavailable'; deliveryEmpty = 'Delivery time —';
        attribution = 'Public reset data · codex-reset.com / codexreset.dev'; publicSource = 'Public data · codex-reset.com'
        tipRefresh = 'Refresh quota now'; tipHide = 'Hide to tray'; tipCompact = 'Switch to mini widget'; tipExpand = 'Click to expand; drag to move'
        tipResize = 'Drag the edge to resize';
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
        retention = 'Completed results retained for 24h'; phaseUpcoming = 'Upcoming'; phaseWaiting = 'Scheduled time passed; monitoring sources have no completion record'; phaseAnnounced = 'Announced · awaiting delivery'; phaseUnknown = 'Source did not provide a delivery record'; phaseDelivered = 'Delivered'; phaseArchived = 'Delivered'
        scheduled = 'Scheduled {0}'; originalScheduled = 'Originally scheduled {0}'; scheduleUnknown = 'Delivery time not announced'; announcedOn = 'Published: {0}'; completionPosted = 'Completion statement posted {0}'; deliveredOn = 'Completed {0}'
        scheduledGrant = 'Scheduled grant: {0}'; scheduledReset = 'Scheduled reset: {0}'; originalGrant = 'Originally scheduled grant: {0}'; originalReset = 'Originally scheduled reset: {0}'
        localAnnouncementTime = '{0} (local {1})'; dateOnlySchedule = '{0} (time not announced)'
        sourceTimeZoneNote = 'Converted from {0} by the monitoring source; see original post.'; sourceWithdrawn = 'Monitoring sources no longer list this record'; withdrawnRecord = 'Record withdrawn by sources'
        publicUpdated = 'Public data updated {0}'; publicUpdateUnknown = 'Public update time unavailable'; refreshCadence = 'Auto-refresh: quota every 1 min · public data every 10 min'; sourceLinks = 'codex-reset.com / codexreset.dev'
        announcementSource = 'View announcement'; deliverySource = 'Delivery record'; announcementHistory = 'History'; historyEmpty = 'No history yet'

        expandHistory = 'Show history'; collapseHistory = 'Hide history'
    }
    'zh-CN' = @{
        activityHeading = '重置动态'
        accountType = '我的账号'
        publicType = '公开消息'
        recoveryRestored = '本账号额度已恢复'
        recoveryHelp = '依据本机额度变化记录。发现时间不是准确重置时刻，也不能确认全局重置原因。'
        earlierUpdates = '较早消息（{0}）'
        activityEmpty = '最近没有新动态'
        activityEmptyHelp = '历史消息仍可在下方查看。'
        localTimeNote = '所有时间均为本地时间（当前 {0}）'
        publicRefreshFailed = '暂时无法获取公共信息'
        publicStale = '公告源暂未更新'
        publicInvalid = '公告源数据暂不可用'
        publicSourceDelayed = '新公告可能尚未收录'
        publicSourceTime = '来源数据更新于 {0}'
        publicPending = '公开数据待更新'
        publicCache = '正在显示已保存的公共信息'
        publicNoCache = '暂无已保存的公共信息。'
        publicRetry = '重试'
        lastFetched = '上次成功获取 {0}'
        dataSources = '数据来源'
        moreMessage = '消息详情'
        completionNotProvided = '完成时间：来源未提供'
        upcomingGrantTitle = '重置次数赠送预告'
        upcomingResetTitle = '全局额度重置预告'
        deliveredGrantTitle = '来源已记录重置次数赠送'
        deliveredResetTitle = '来源已记录全局额度重置'
        unconfirmedGrantTitle = '重置次数赠送消息'
        unconfirmedResetTitle = '额度重置消息'
        recoveryMore = '记录说明'
        publicRetrying = '正在刷新公共信息'
        detailsPartial = '列表可能不完整，可用数量以上方显示为准。'
        historyAttribution = '早期历史记录'
        resetLabel = '可用重置'
        disclosureDetails = '详情'
        recoveryCount = '{0} 条记录'; recoveryNone = '暂无记录'; relatedBanked = '重置次数赠送消息'; relatedRegular = '全局重置消息'; phaseUnconfirmed = '网站未提供完成时间'; sourceScope = '网站标注：{0}'; postedOn = '消息发布 {0}'
        recoveryTitle = '我的额度恢复'; recoveryDetected = '本机发现：{0}'; recoveryObserved = '上次读取：{0}'; recoveryExplanation = '这里只记录你自己的额度变化。'; recoveryTracking = '从 {0} 开始记录。'; recoveryEmpty = '还没有新的额度恢复记录。'; recoveryUnavailable = '记录暂不可用，登录 Codex 后刷新。'; recoveryUnsaved = '本地保存失败，本次新记录可能在关闭应用后丢失。'
        newGrant = '有新的重置次数赠送公告，点击查看详情'; newGlobalReset = '有新的全局额度重置公告，点击查看详情'; newAnnouncements = '有新的重置次数赠送和全局额度重置公告，点击查看详情'
        app = 'Codex 周额度'; loading = '读取中'; reading = '正在读取额度'; updated = '数据已更新'; unavailable = '暂不可用'; refreshing = '正在刷新'
        compact = '极简'; refresh = '刷新'; weekly = '本周剩余'; untilReset = '距离重置'; reset = '重置 {0}'; resetUnknown = '重置时间 —'
        lastUpdated = '最近更新 {0}'; stale = '数据已过期，请刷新'; cards = '可用重置 {0}次'; cardsUnknown = '可用重置 —'
        fiveHour = 'Plus · 5小时额度'; percentRemaining = '{0}% 剩余'; external = '公开全局额度重置'; lastAnnouncement = '上次公告 {0} · {1}'
        paid = '付费账号'; all = '全部账号'; unknownScope = '适用范围详见公告'; delivered = '记录送达 {0}'; deliveryUnknown = '送达时间未确认'
        publicUnavailable = '上次公开重置暂不可用'; deliveryEmpty = '送达时间 —';
        attribution = '公开重置记录 · codex-reset.com / codexreset.dev'; publicSource = '公开数据 · codex-reset.com'
        tipRefresh = '立即刷新额度'; tipHide = '隐藏到系统托盘'; tipCompact = '切换到极简悬浮窗'; tipExpand = '单击展开，拖动可调整位置'
        tipResize = '拖动边缘调整大小';
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
        retention = '完成结果保留24小时'; phaseUpcoming = '即将进行'; phaseWaiting = '预定时间已过，监控来源未提供完成记录'; phaseAnnounced = '已公告 · 等待送达'; phaseUnknown = '来源未提供送达记录'; phaseDelivered = '已送达'; phaseArchived = '已送达'
        scheduled = '计划 {0}'; originalScheduled = '原定 {0}'; scheduleUnknown = '送达时间尚未公布'; announcedOn = '公告发布 {0}'; completionPosted = '完成声明发布 {0}'; deliveredOn = '确认完成 {0}'
        scheduledGrant = '预定送达 {0}'; scheduledReset = '预定重置 {0}'; originalGrant = '原定送达 {0}'; originalReset = '原定重置 {0}'
        localAnnouncementTime = '{0}（本地 {1}）'; dateOnlySchedule = '{0}（具体时间未公布）'
        sourceTimeZoneNote = '来源按 {0} 时区换算；原文见公告。'; sourceWithdrawn = '监控来源已撤下此记录'; withdrawnRecord = '来源已撤下的公告记录'
        publicUpdated = '公告数据更新 {0}'; publicUpdateUnknown = '公告更新时间暂不可用'; refreshCadence = '自动刷新：额度每1分钟 · 公共信息每10分钟'; sourceLinks = 'codex-reset.com / codexreset.dev'
        announcementSource = '查看公告'; deliverySource = '送达记录'; announcementHistory = '历史记录'; historyEmpty = '暂无历史记录'

        expandHistory = '展开历史记录'; collapseHistory = '收起历史记录'
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

function Format-WidgetCompactDate([DateTimeOffset]$date, [string]$language, [TimeZoneInfo]$zone=[TimeZoneInfo]::Local, [DateTimeOffset]$now=[DateTimeOffset]::UtcNow) {
    $local=[TimeZoneInfo]::ConvertTime($date,$zone);$current=[TimeZoneInfo]::ConvertTime($now,$zone)
    if ($local.Offset -ne $current.Offset) {return Format-WidgetAnnouncementDate $date $language $zone $now}
    $culture=if ((Resolve-WidgetLanguage $language) -eq 'zh-CN') {'zh-CN'} else {'en-US'}
    $format=if ($culture -eq 'zh-CN') {'MM/dd HH:mm'} else {'MM/dd, HH:mm'}
    if ($local.Year -ne $current.Year) {$format=if ($culture -eq 'zh-CN') {'yyyy/MM/dd HH:mm'} else {'MM/dd/yyyy, HH:mm'}}
    $local.ToString($format,[Globalization.CultureInfo]::GetCultureInfo($culture))
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
    # Match NativeDetailHeaderLayout in the primary macOS version.
    $left=if ($width -lt 520) {16} else {30}; $buttonSize=32; $gap=4
    $toolbarLeft=$width-16-3*$buttonSize-2*$gap
    $secondRow=$titleWidth+18+$statusWidth -gt $toolbarLeft-12-$left
    $buttons=@()
    foreach ($kind in @('refresh','compact','hide')) {
        $buttons+=,[pscustomobject]@{kind=$kind;x=$toolbarLeft+$buttons.Count*($buttonSize+$gap);y=14;width=$buttonSize;height=$buttonSize}
    }
    [pscustomobject]@{
        titleX=$left;titleY=15;titleWidth=[Math]::Min($titleWidth,$toolbarLeft-12-$left)
        statusX=$(if ($secondRow) {$left} else {$left+$titleWidth+18})
        statusY=$(if ($secondRow) {52} else {18})
        statusWidth=$(if ($secondRow) {$width-2*$left} else {$toolbarLeft-12-$left-$titleWidth-18})
        statusSecondRow=$secondRow;height=$(if ($secondRow) {84} else {60});buttons=$buttons
    }
}
function Get-WidgetDetailMetrics([int]$width) {
    # Embedded app.css dimensions, in the existing saved 96-DPI coordinate model.
    $inset=if ($width -le 420) {14} elseif ($width -le 520) {16} else {24}
    $ring=[Math]::Max(92,[Math]::Min(112,$width*0.22))
    $gap=[Math]::Max(14,[Math]::Min(24,$width*0.04))
    [pscustomobject]@{inset=$inset;ring=[int][Math]::Round($ring);copyX=[int][Math]::Round($ring+2*$gap+1);dividerX=[int][Math]::Round($ring+$gap);countdownPixels=[Math]::Max(24,[Math]::Min(30,$width*0.05))}
}
function Get-WidgetResetDetailsView($data, [string]$language, [DateTimeOffset]$now=[DateTimeOffset]::UtcNow) {
    $fresh=$false
    if ($data -and $data.status -eq 'ok' -and $null -ne $data.updatedAt -and $null -ne $data.resetsAt -and $null -ne $data.remainingPercent) {
        try {
            $age=$now-[DateTimeOffset]::FromUnixTimeMilliseconds([long]$data.updatedAt)
            $fresh=$age.TotalMinutes -le 10 -and $age.TotalSeconds -ge -60 -and [DateTimeOffset]::FromUnixTimeSeconds([long]$data.resetsAt) -gt $now -and [double]$data.remainingPercent -ge 0 -and [double]$data.remainingPercent -le 100
        } catch {}
    }
    $rows=@()
    $note=if (-not $fresh) {Get-WidgetText 'detailsPending' $language} elseif ($null -eq $data.resetDetails) {Get-WidgetText 'detailsUnavailable' $language} elseif (@($data.resetDetails).Count -eq 0) {Get-WidgetText 'detailsEmpty' $language} else {Get-WidgetText 'detailsPartial' $language}
    if ($fresh) {
        foreach ($record in @($data.resetDetails)) {
            if (-not $record) {continue}
            $dates=@{}
            foreach ($field in @(@('grantedAt','grant'),@('expiresAt','expiry'))) {
                $text=Get-WidgetText 'notProvided' $language
                if ($null -ne $record.($field[0])) {try {$text=Format-WidgetCompactDate ([DateTimeOffset]::FromUnixTimeSeconds([long]$record.($field[0]))) $language ([TimeZoneInfo]::Local) $now} catch {}}
                $dates[$field[1]]=Get-WidgetText $field[1] $language @($text)
            }
            $rows+=,[pscustomobject]@{title=$(if ($record.title) {[string]$record.title} else {Get-WidgetText 'unnamedGrant' $language});description=[string]$record.description;granted=$dates.grant;expires=$dates.expiry}
        }
    }
    [pscustomobject]@{note=$note;rows=@($rows)}
}
function Get-WidgetActivityPartition($rows) {
    $featured=@();$earlier=@();$personal=$false;$public=$false
    foreach ($row in @($rows)) {
        $first=if ($row.kind -eq 'recovery') {-not $personal} else {-not $public}
        if ($row.kind -eq 'recovery') {$personal=$true} else {$public=$true}
        if ($first -or $row.phase -in @('upcoming','waiting','announced')) {$featured+=,$row} else {$earlier+=,$row}
    }
    [pscustomobject]@{featured=@($featured);earlier=@($earlier)}
}
function Get-WidgetVisibleActivityView($activity, [bool]$earlierOpen, [bool]$historyOpen) {
    $active=@($activity.featured)
    if ($earlierOpen) {$active+=@($activity.earlier)}
    [pscustomobject]@{active=@($active);history=$(if ($historyOpen) {@($activity.history)} else {@()})}
}
function Get-WidgetPublicNoticeView($external, [string]$language, [DateTimeOffset]$now=[DateTimeOffset]::UtcNow) {
    $feed=$external.announcements;$stamp=ConvertTo-WidgetTimestamp $feed.sourceUpdatedAt
    $fresh=$stamp -and $stamp -le $now.AddMinutes(5) -and ($now-$stamp).TotalHours -le 24
    $fetched=''
    if ($null -ne $feed.lastFetchedAt) {try {$date=[DateTimeOffset]::FromUnixTimeMilliseconds([long]$feed.lastFetchedAt);if ($date -le $now) {$fetched=Get-WidgetText 'lastFetched' $language @((Format-WidgetCompactDate $date $language ([TimeZoneInfo]::Local) $now))}} catch {}}
    $reason=$feed.reason
    if (-not $reason) {$reason=if ($external.status -eq 'unavailable' -or $feed.status -eq 'unavailable') {'request-failed'} elseif (-not $fresh) {'source-stale'} else {$null}}
    $titleKey=switch ($reason) {'request-failed' {'publicRefreshFailed'} 'invalid-data' {'publicInvalid'} 'source-stale' {'publicStale'} default {'publicPending'}}
    [pscustomobject]@{
        visible=($external.status -ne 'loading' -and -not ($external.status -eq 'ok' -and $feed.status -eq 'ok' -and -not $feed.stale -and $fresh))
        hasCache=(@($feed.items).Where({$_}).Count+@($feed.history).Where({$_}).Count -gt 0)
        reason=$reason;failed=($reason -eq 'request-failed');title=(Get-WidgetText $titleKey $language)
        help=$(if ($reason -eq 'source-stale') {Get-WidgetText 'publicSourceDelayed' $language} else {''})
        sourceUpdatedText=$(if ($stamp -and $stamp -le $now) {Get-WidgetText 'publicSourceTime' $language @((Format-WidgetCompactDate $stamp $language ([TimeZoneInfo]::Local) $now))} else {''})
        lastFetchedText=$fetched
    }
}
function Get-WidgetLocalTimeNote([string]$language, [DateTimeOffset]$now=[DateTimeOffset]::UtcNow) {
    $offset=[int]$now.ToLocalTime().Offset.TotalMinutes;$sign=if ($offset -lt 0) {'-'} else {'+'};$minutes=[Math]::Abs($offset)
    $zone=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'UTC{0}{1:00}:{2:00}',$sign,[int][Math]::Floor($minutes/60),$minutes%60)
    Get-WidgetText 'localTimeNote' $language @($zone)
}
function Get-WidgetActivityPresentation($row, [string]$language) {
    if ($row.kind -eq 'recovery') {
        return [pscustomobject]@{title=(Get-WidgetText 'recoveryRestored' $language);label=(Get-WidgetText 'accountType' $language);fact=$row.details;status='';extra=(@((Get-WidgetText 'recoveryHelp' $language),$row.title,$row.summary) | Where-Object {$_}) -join [Environment]::NewLine;missing=$false}
    }
    $completed=$row.phase -in @('delivered','archived')
    $explicit=$completed -or $row.explicit
    $key=$(if ($completed) {'delivered'} elseif ($explicit) {'upcoming'} else {'unconfirmed'})+$(if ($row.kind -eq 'banked') {'GrantTitle'} else {'ResetTitle'})
    $title=Get-WidgetText $(if ($row.withdrawn) {'withdrawnRecord'} else {$key}) $language
    $completedText=if ($row.compactCompletedText) {$row.compactCompletedText} else {$row.completedText}
    $scheduledText=if ($row.compactScheduledText) {$row.compactScheduledText} else {$row.scheduledText}
    $announcedText=if ($row.compactAnnouncedText) {$row.compactAnnouncedText} else {$row.announcedText}
    $fact=if ($completedText) {$completedText} elseif ($scheduledText) {$scheduledText} else {$announcedText}
    $extra=@(@($scheduledText,$announcedText) | Where-Object {$_ -and $_ -ne $fact})
    $extra+=@($row.scheduleNote,$row.summary,$row.retentionText) | Where-Object {$_}
    [pscustomobject]@{title=$title;label=(Get-WidgetText 'publicType' $language);fact=(@($fact,$row.scopeText) | Where-Object {$_}) -join ' · ';status=$(if ($row.phase -in @('waiting','announced')) {Get-WidgetText ('phase'+(Get-Culture).TextInfo.ToTitleCase([string]$row.phase)) $language} else {''});extra=$extra -join [Environment]::NewLine;missing=($row.phase -in @('unknown','unconfirmed'))}
}
function Test-WidgetOutsideClick([string]$mode, [bool]$visible, [bool]$animating,
                                 [Drawing.Rectangle]$frame, [Drawing.Point]$point) {
    return $mode -eq 'Detail' -and $visible -and -not $animating -and -not $frame.Contains($point)
}

function Get-WidgetDetailAutoHeightSetting($saved) {
    # Restore the Mac baseline once for legacy fixed-height Windows layouts.
    # A resize saved by this layout version remains a deliberate preference.
    try {
        if ($saved -and [int]$saved.detailLayoutVersion -ge 5 -and $null -ne $saved.detailAutoHeight) {
            return [bool]$saved.detailAutoHeight
        }
    } catch { }
    return $true
}
function Get-WidgetDetailFittedFrame([Drawing.Rectangle]$frame, [int]$contentHeight,
                                    [int]$headerHeight, [Drawing.Rectangle]$screen, $preferredPosition = $null) {
    if ($preferredPosition) { $frame.Location=[Drawing.Point]::new([int]$preferredPosition.x,[int]$preferredPosition.y) }
    $width=[Math]::Min($frame.Width,$screen.Width)
    $height=[Math]::Min($screen.Height,[Math]::Max(390,$contentHeight+$headerHeight+10))
    $x=[Math]::Max($screen.Left,[Math]::Min($frame.Left,$screen.Right-$width))
    $y=[Math]::Max($screen.Top,[Math]::Min($frame.Top,$screen.Bottom-$height))
    return [Drawing.Rectangle]::new($x,$y,$width,$height)
}
function Get-WidgetRecoveryView($data, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $history=if ($data -and $data.status -eq 'ok') {$data.recoveryHistory} else {$null}
    $ready=$history -and $history.status -in @('ok','unsaved')
    $rows=@()
    if ($ready) {
        foreach ($row in @($history.records | Sort-Object detectedAt -Descending | Select-Object -First 50)) {
            try {
                $detected=[DateTimeOffset]::FromUnixTimeMilliseconds([long]$row.detectedAt)
                $observed=[DateTimeOffset]::FromUnixTimeMilliseconds([long]$row.observedFrom)
                if ($detected -gt $now -or $detected -le $observed -or $row.beforePercent -lt 0 -or $row.afterPercent -gt 100 -or $row.afterPercent -le $row.beforePercent) {continue}
                $rows+=,[pscustomobject]@{kind='recovery';detectedAt=[long]$row.detectedAt;sortAt=[long]$row.detectedAt;title=((Get-WidgetText 'recoveryTitle' $language)+' · '+[string]$row.beforePercent+'% → '+[string]$row.afterPercent+'%'); details=(Get-WidgetText 'recoveryDetected' $language @((Format-WidgetAnnouncementDate $detected $language))); summary=(Get-WidgetText 'recoveryObserved' $language @((Format-WidgetAnnouncementDate $observed $language))); sourceUrl=$null; deliverySourceUrl=$null; retention=$null}
            }catch{}
        }
    }
    $note=Get-WidgetText 'recoveryExplanation' $language
    if ($ready -and $history.trackingSince) {
        try {$note+=' '+(Get-WidgetText 'recoveryTracking' $language @((Format-WidgetAnnouncementDate ([DateTimeOffset]::FromUnixTimeMilliseconds([long]$history.trackingSince)) $language)))}catch{}
    }
    if ($history -and $history.status -eq 'unsaved') {$note+=' '+(Get-WidgetText 'recoveryUnsaved' $language)}
    [pscustomobject]@{rows=$rows;note=$note;empty=(Get-WidgetText $(if ($ready) {'recoveryEmpty'} else {'recoveryUnavailable'}) $language)}
}
function Get-WidgetDetailSectionOrder([bool]$plus) {
    'hero'
    if ($plus) { 'fiveHour' }
    'credits'; 'announcements'; 'history'; 'sources'; 'footer'
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
    if ($row.certainty -ne 'announced') { return 'unconfirmed' }
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
function Get-WidgetFiveHourView($quota, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $visible=$quota -and $quota.status -eq 'ok' -and $quota.plan -eq 'plus'
    $percentText=Get-WidgetText 'unavailable' $language; $resetText=Get-WidgetText 'resetUnknown' $language; $compactResetText=$resetText
    if ($visible -and $quota.fiveHour -and $null -ne $quota.updatedAt -and $null -ne $quota.fiveHour.remainingPercent -and $null -ne $quota.fiveHour.resetsAt) {
        try {
            $age=$now-[DateTimeOffset]::FromUnixTimeMilliseconds([long]$quota.updatedAt)
            $resetAt=[DateTimeOffset]::FromUnixTimeSeconds([long]$quota.fiveHour.resetsAt)
            $remaining=[double]$quota.fiveHour.remainingPercent
            if ($age.TotalMinutes -le 10 -and $age.TotalSeconds -ge -60 -and $resetAt -gt $now -and $remaining -ge 0 -and $remaining -le 100) {
                $percentText=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'{0}%',@($remaining))
                $resetText=Get-WidgetText 'reset' $language @((Format-WidgetDate $resetAt $language))
                $compactResetText=Get-WidgetText 'reset' $language @((Format-WidgetCompactDate $resetAt $language ([TimeZoneInfo]::Local) $now))
            }
        } catch { }
    }
    [pscustomobject]@{visible=[bool]$visible;percentText=$percentText;resetText=$resetText;compactResetText=$compactResetText}
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
    foreach ($row in @($view.active)+@($view.history)) {if ($row) {$id=if ($row.id) {[string]$row.id} else {[string]$row.key};$rendered[$id]=$true}}
    return ,@($alerts.ids | Where-Object {$rendered.ContainsKey([string]$_)})
}
function Get-WidgetNoticeBounds([double]$width, [double]$height) {
    $diameter=[Math]::Max(5,[Math]::Min(8,[Math]::Min($width,$height)*0.12))
    [pscustomobject]@{x=$width-$diameter-5;y=5;width=$diameter;height=$diameter}
}
function ConvertTo-WidgetAnnouncementRow($row, [string]$language, [DateTimeOffset]$now, [bool]$historical = $false, [TimeZoneInfo]$timeZone = [TimeZoneInfo]::Local) {
    $phase=Get-WidgetAnnouncementPhase $row $now
    $completed=$phase -in @('delivered','archived')
    $explicit=$completed -or $row.certainty -eq 'announced'
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
    if (-not $explicit) { $scheduledText=$null }
    if ($explicit -and -not $scheduledText -and -not $completed -and -not $historical) { $scheduledText=Get-WidgetText 'scheduleUnknown' $language }
    $completionKey=if ($row.completionTimeBasis -eq 'announcement') {'completionPosted'} else {'deliveredOn'}
    if ($completed) { $completedText=Get-WidgetText $completionKey $language @((Format-WidgetAnnouncementDate $delivered $language $timeZone $now)) }
    $announced=ConvertTo-WidgetTimestamp $row.announcedAt
    if ($announced) { $announcedText=Get-WidgetText $(if ($explicit) {'announcedOn'} else {'postedOn'}) $language @((Format-WidgetAnnouncementDate $announced $language $timeZone $now)) }
    $scope=if ($row.scope -eq 'paid') {Get-WidgetText 'paid' $language} elseif ($row.scope -eq 'all') {Get-WidgetText 'all' $language} elseif ($row.scopeLabel) {[string]$row.scopeLabel} else {Get-WidgetText 'unknownScope' $language}
    if (-not $explicit) {$scope=Get-WidgetText 'sourceScope' $language @($scope)}
    $phaseKey=if ($row.sourceWithdrawn) {'sourceWithdrawn'} else {'phase'+(Get-Culture).TextInfo.ToTitleCase($phase)}
    $scheduleNote=if ($scheduled -and $row.scheduledTimeZone) {Get-WidgetText 'sourceTimeZoneNote' $language @([string]$row.scheduledTimeZone)} else {''}
    $summary=if ((Resolve-WidgetLanguage $language) -eq 'zh-CN' -and $row.summaryZh) {[string]$row.summaryZh} elseif ($row.summary) {[string]$row.summary} else {''}
    $compactScheduled=$scheduledText;$compactCompleted=$completedText;$compactAnnounced=$announcedText
    if ($scheduled -and $scheduledText) {$compactScheduled=Get-WidgetText $scheduleKey $language @((Format-WidgetCompactDate $scheduled $language $timeZone $now))}
    if ($completed) {$compactCompleted=Get-WidgetText $completionKey $language @((Format-WidgetCompactDate $delivered $language $timeZone $now))}
    if ($announced) {$compactAnnounced=Get-WidgetText $(if ($explicit) {'announcedOn'} else {'postedOn'}) $language @((Format-WidgetCompactDate $announced $language $timeZone $now))}
    $details=@((Get-WidgetText $phaseKey $language))
    if ($scheduledText) {$details+=,$scheduledText}
    if ($completedText) {$details+=,$completedText}
    if ($announcedText) {$details+=,$announcedText}
    if ($scheduleNote) {$details+=,$scheduleNote}
    $details+=,$scope
    [pscustomobject]@{
        key=Get-WidgetAnnouncementKey $row; id=[string]$row.id; kind=[string]$row.kind; explicit=$explicit; withdrawn=[bool]$row.sourceWithdrawn; phase=$phase; sortAt=$(if ($announced) {$announced.ToUnixTimeMilliseconds()} else {[long]::MinValue})
        title=Get-WidgetText $(if ($row.sourceWithdrawn) {'withdrawnRecord'} elseif ($row.kind -eq 'banked') {if ($explicit) {'confirmedBanked'} else {'relatedBanked'}} else {if ($explicit) {'confirmedRegular'} else {'relatedRegular'}}) $language
        compactScheduledText=$compactScheduled;compactCompletedText=$compactCompleted;compactAnnouncedText=$compactAnnounced
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
function Get-WidgetResetActivityView($data, $external, [string]$language, [DateTimeOffset]$now = [DateTimeOffset]::UtcNow) {
    $public=Get-WidgetAnnouncementView $external $language $now
    $recovery=Get-WidgetRecoveryView $data $language $now
    $active=@($public.active); $history=@($public.history)
    foreach ($record in $recovery.rows) {
        $row=$record | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        if ($now.ToUnixTimeMilliseconds()-$record.detectedAt -lt 86400000) {
            $active+=,$row
        } else { $history+=,$row }
    }
    $stale=$public.staleText; $sourceUpdate=$public.sourceUpdateText
    if ($active.Count -and -not $public.active.Count) {$stale=$public.emptyText; $sourceUpdate=$null}
    if ($data -and $data.status -eq 'ok' -and $data.recoveryHistory.status -eq 'unsaved') {
        $stale=(@($stale,(Get-WidgetText 'recoveryUnsaved' $language)) | Where-Object {$_}) -join ' · '
    }
    [pscustomobject]@{active=@($active | Sort-Object sortAt -Descending);history=@($history | Sort-Object sortAt -Descending);emptyText=$public.emptyText;staleText=$stale;sourceUpdateText=$sourceUpdate}
}
function Merge-WidgetExternalData($previous, $incoming, [bool]$transportFailure = $false) {
    # Clone the public response so a failure cannot mutate a previously cached
    # successful snapshot. Persisted known rows survive an empty schedule feed.
    $basis=if ($incoming -and -not $transportFailure) {$incoming} elseif ($previous) {$previous} else {[pscustomobject]@{status='unavailable'}}
    $result=$basis | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $result.PSObject.Properties.Remove('forecast')
    $fresh=if ($incoming -and -not $transportFailure) {$incoming.announcements} else {$null}
    $old=if ($previous) {$previous.announcements} else {$null}
    $feed=if ($fresh) {$fresh | ConvertTo-Json -Depth 12 | ConvertFrom-Json} elseif ($old) {$old | ConvertTo-Json -Depth 12 | ConvertFrom-Json} else {[pscustomobject]@{status='unavailable';items=@();history=@();sourceUpdatedAt=$null;stale=$true}}
    $originalKinds=@{}
    foreach ($snapshot in @($old,$fresh)) {
        if (-not $snapshot) { continue }
        foreach ($row in @($snapshot.history)+@($snapshot.items)) {
            if ($row -and $row.kind -in @('banked','regular') -and $row.kindBasis -eq 'original' -and (Test-WidgetHttpsUrl $row.sourceUrl)) {
                $originalKinds[[string]$row.sourceUrl]=[string]$row.kind
            }
        }
    }
    $entries=[ordered]@{}
    foreach ($snapshot in @($old,$fresh)) {
        if (-not $snapshot) { continue }
        # A source may retain the same canonical row in both collections. Its
        # active collection owns the 24-hour display lifecycle; history only
        # wins when the newer source snapshot no longer includes it as active.
        foreach ($bucket in @('history','items')) {
            foreach ($row in @($snapshot.$bucket)) {
                if (-not $row -or $row.kind -notin @('banked','regular')) { continue }
                $copy=$row | ConvertTo-Json -Depth 8 | ConvertFrom-Json
                if ($originalKinds.ContainsKey([string]$copy.sourceUrl)) {
                    $copy.kind=$originalKinds[[string]$copy.sourceUrl]
                    $copy | Add-Member -NotePropertyName id -NotePropertyValue ($copy.sourceUrl+'#'+$copy.kind) -Force
                    $copy | Add-Member -NotePropertyName kindBasis -NotePropertyValue 'original' -Force
                }
                $identity=Get-WidgetAnnouncementKey $copy
                if ($entries.Contains($identity)) {
                    $known=$entries[$identity].row
                    foreach ($field in @('deliveredAt','scheduledAt','scheduledDate','announcedAt','sourceUrl','deliverySourceUrl','completionTimeBasis','kindBasis')) {
                        if (-not $copy.$field -and $known.$field) { $copy | Add-Member -NotePropertyName $field -NotePropertyValue $known.$field -Force }
                    }
                }
                # A later full original can invalidate a pairing inferred from a
                # mirror's category; do not preserve those old completion fields.
                if ($copy.deliveredAt -and $copy.deliverySourceUrl -ne $copy.sourceUrl -and $originalKinds.ContainsKey([string]$copy.deliverySourceUrl) -and $originalKinds[[string]$copy.deliverySourceUrl] -ne $copy.kind) {
                    foreach ($field in @('deliveredAt','deliverySourceUrl','completionTimeBasis')) {
                        $copy | Add-Member -NotePropertyName $field -NotePropertyValue $null -Force
                    }
                }
                $entries[$identity]=[pscustomobject]@{row=$copy;bucket=$bucket}
            }
        }
    }
    # A paired row replaces its independently cached completion post, including
    # aliases from an earlier partial response and rows without a persisted id.
    $completionAliases=@{}
    foreach ($entry in @($entries.Values)) {
        $row=$entry.row
        if ($row.deliveredAt -and (Test-WidgetHttpsUrl $row.deliverySourceUrl) -and $row.deliverySourceUrl -ne $row.sourceUrl) {
            $completionAliases["$($row.kind):$($row.deliverySourceUrl)"]=$true
        }
    }
    foreach ($identity in @($entries.Keys)) {
        $row=$entries[$identity].row
        if ($completionAliases.ContainsKey("$($row.kind):$($row.sourceUrl)")) { $entries.Remove($identity) }
    }
    $feed | Add-Member -NotePropertyName items -NotePropertyValue @($entries.Values | Where-Object {$_.bucket -eq 'items'} | ForEach-Object {$_.row}) -Force
    $feed | Add-Member -NotePropertyName history -NotePropertyValue @($entries.Values | Where-Object {$_.bucket -eq 'history'} | ForEach-Object {$_.row}) -Force
    if ($transportFailure -or -not $fresh -or $fresh.status -ne 'ok') {
        if ($transportFailure -or -not $incoming) {
            $result | Add-Member -NotePropertyName status -NotePropertyValue 'unavailable' -Force
            $feed | Add-Member -NotePropertyName reason -NotePropertyValue 'request-failed' -Force
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
# Store packages contain a GUI Codex.exe as well as the app-server console CLI.
# Inspect PE metadata without launching either program or changing authentication.
function Test-WidgetCodexCandidate([string]$path) {
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    if ([IO.Path]::GetExtension($path) -eq '.cmd') { return $true }
    $stream = $null; $reader = $null
    try {
        $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $reader = New-Object IO.BinaryReader($stream)
        if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) { return $false }
        $stream.Position = 60; $offset = $reader.ReadInt32()
        if ($offset -lt 64 -or $offset -gt $stream.Length - 94) { return $false }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550) { return $false }
        $stream.Position = $offset + 24; $magic = $reader.ReadUInt16()
        if ($magic -notin @(0x10b,0x20b)) { return $false }
        $stream.Position = $offset + 24 + 68
        return $reader.ReadUInt16() -eq 3
    } catch { return $false }
    finally { if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() } }
}
# Codex materializes its CLI outside the protected MSIX package. Use only a copy
# whose bytes match the installed package, avoiding guesses among saved versions.
function Find-WidgetExtractedCodex([string]$packageBinary) {
    if (-not $env:LOCALAPPDATA) { return $null }
    $root = Join-Path $env:LOCALAPPDATA 'OpenAI/Codex/bin'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $null }
    $candidates = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'codex.exe' } | Where-Object { Test-WidgetCodexCandidate $_ })
    if (-not $candidates.Count) { return $null }
    try {
        $expected = (Get-FileHash -LiteralPath $packageBinary -Algorithm SHA256 -ErrorAction Stop).Hash
        foreach ($candidate in $candidates) {
            if ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256 -ErrorAction Stop).Hash -eq $expected) { return $candidate }
        }
    } catch { }
    return $null
}
function Find-WidgetCodex([switch]$ConsoleOnly) {
    if ((-not $ConsoleOnly -or [IO.Path]::GetExtension($env:CODEX_CLI_PATH) -ne '.cmd') -and (Test-WidgetCodexCandidate $env:CODEX_CLI_PATH)) { return $env:CODEX_CLI_PATH }
    foreach ($name in @('codex.exe','codex.cmd')) {
        if ($ConsoleOnly -and $name -eq 'codex.cmd') { continue }
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -and (Test-WidgetCodexCandidate $command.Source)) { return $command.Source }
    }
    $candidates = @()
    if ($env:APPDATA -and -not $ConsoleOnly) { $candidates += Join-Path $env:APPDATA 'npm/codex.cmd' }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs/Codex/resources/codex.exe'
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs/Codex/resources/app.asar.unpacked/node_modules/@openai/codex/vendor/x86_64-pc-windows-msvc/codex/codex.exe'
    }
    foreach ($candidate in $candidates) { if (Test-WidgetCodexCandidate $candidate) { return [IO.Path]::GetFullPath($candidate) } }
    if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
        foreach ($package in @(Get-AppxPackage '*Codex*' -ErrorAction SilentlyContinue)) {
            if (-not $package.InstallLocation) { continue }
            $candidates = Get-ChildItem -LiteralPath $package.InstallLocation -Filter codex.exe -File -Recurse -ErrorAction SilentlyContinue
            foreach ($candidate in $candidates) {
                if (Test-WidgetCodexCandidate $candidate.FullName) {
                    $extracted = Find-WidgetExtractedCodex $candidate.FullName
                    if ($extracted) { return $extracted }
                    return $candidate.FullName
                }
            }
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
