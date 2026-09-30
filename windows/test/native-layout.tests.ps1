$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
$script:failures = 0
function Assert-Equal($actual, $expected, [string]$reason) {
    if ($actual -cne $expected) { throw "$reason. Expected [$expected], got [$actual]" }
}
function Test-Case([string]$name, [scriptblock]$body) {
    try { & $body; Write-Output "PASS $name" }
    catch { $script:failures++; Write-Output "FAIL $name : $($_.Exception.Message)" }
}
$now = [DateTimeOffset]'2026-09-30T12:00:00Z'
function New-Event([string]$id, [string]$kind = 'banked') {
    [pscustomobject]@{ id=$id; kind=$kind; announcedAt='2026-09-29T12:00:00Z'; scheduledAt=$null; scheduledDate=$null; deliveredAt=$null; scope='paid'; scopeLabel=$null; sourceUrl='https://example.org/announcement'; deliverySourceUrl=$null; summary='Confirmed announcement'; summaryZh='已确认公告' }
}
function New-External($items = @(), $history = @(), [string]$status = 'ok') {
    [pscustomobject]@{ status='ok'; forecast=$null; announcements=[pscustomobject]@{ status=$status; items=@($items); history=@($history); sourceUpdatedAt='2026-09-30T11:00:00Z'; stale=$false } }
}
Test-Case 'relative quota age uses source updatedAt in both languages' {
    Assert-Equal (Format-WidgetRelativeUpdate ($now.AddSeconds(-10).ToUnixTimeMilliseconds()) 'en' $now) 'Updated just now' 'Fresh quota'
    Assert-Equal (Format-WidgetRelativeUpdate ($now.AddSeconds(-59).ToUnixTimeMilliseconds()) 'zh-CN' $now) '刚刚更新' 'Sub-minute age'
    Assert-Equal (Format-WidgetRelativeUpdate ($now.AddSeconds(-61).ToUnixTimeMilliseconds()) 'en' $now) 'Updated 1 minute ago' 'Minute boundary'
    Assert-Equal (Format-WidgetRelativeUpdate ($now.AddMinutes(-7).ToUnixTimeMilliseconds()) 'zh-CN' $now) '7分钟前更新' 'Chinese age'
    Assert-Equal (Format-WidgetRelativeUpdate $null 'en' $now) 'Update time unavailable' 'Unknown age'
}
Test-Case 'narrow header keeps relative age below title and ordered equal toolbar targets' {
    $header = Get-WidgetHeaderLayout 404 132 145
    Assert-Equal $header.statusSecondRow $true 'Narrow status row'
    Assert-Equal ($header.buttons.kind -join ',') 'refresh,compact,hide' 'Toolbar order'
    foreach ($button in $header.buttons) { Assert-Equal $button.width 32 'Equal hit target'; Assert-Equal $button.height 32 'Equal hit target' }
    if ($header.statusY -le $header.titleY -or $header.buttons[-1].x + 32 -gt 404) { throw 'Header overflow' }
    Assert-Equal (Get-WidgetHeaderLayout 620 132 145).statusSecondRow $false 'Wider inline status'
}
Test-Case 'public probability always has three nonoverlapping columns' {
    foreach ($width in @(320,364,620)) {
        $columns = @(Get-WidgetOddsColumns $width)
        Assert-Equal $columns.Count 3 'Probability column count'
        for ($i=0; $i -lt 2; $i++) { if ($columns[$i].x + $columns[$i].width -gt $columns[$i+1].x) { throw 'Overlapping columns' } }
        Assert-Equal ($columns[-1].x + $columns[-1].width) $width 'Columns fit available width'
    }
}
Test-Case 'Plus quota precedes credits and confirmed announcements precede probability' {
    Assert-Equal ((Get-WidgetDetailSectionOrder $true) -join ',') 'hero,fiveHour,credits,announcements,probability,history,sources' 'Plus section order'
    Assert-Equal ((Get-WidgetDetailSectionOrder $false) -contains 'fiveHour') $false 'Non-Plus quota'
}
Test-Case 'confirmed announcements move from upcoming to waiting without inferred delivery' {
    $row = New-Event 'hidden-event-key'; $row.scheduledAt=$now.AddMinutes(1).ToString('o')
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now) 'upcoming' 'Future event'
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now.AddMinutes(1)) 'waiting' 'Due boundary'
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now.AddDays(5)) 'waiting' 'Elapsed schedule is not delivery'
    $row.scheduledAt=$null
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now) 'announced' 'No schedule'
}
Test-Case 'only past delivery evidence completes an event and archives it at 24 hours' {
    $row = New-Event 'completed'; $row.deliveredAt=$now.ToString('o')
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now) 'delivered' 'Recorded delivery'
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now.AddHours(24).AddSeconds(-1)) 'delivered' 'Retained for 24h'
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now.AddHours(24)) 'archived' 'Archive boundary'
    $row.deliveredAt=$now.AddDays(1).ToString('o')
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now) 'announced' 'Future timestamp is not evidence of completion'
}
Test-Case 'date-only schedules never invent midnight and summaries follow language' {
    $row = New-Event 'private-key'; $row.scheduledDate='2026-10-02'
    $view = Get-WidgetAnnouncementView (New-External @($row)) 'zh-CN' $now
    Assert-Equal $view.active.Count 1 'One event'
    if (-not $view.active[0].details.Contains('10月2日') -or $view.active[0].details -match '00:00|private-key') { throw 'Date-only display invented a time or exposed an ID' }
    Assert-Equal $view.active[0].summary '已确认公告' 'Chinese summary'
    Assert-Equal (Get-WidgetAnnouncementView (New-External @($row)) 'en' $now).active[0].summary 'Confirmed announcement' 'English summary'
}
Test-Case 'two kinds stay separate and empty/unavailable feeds use one muted state line' {
    $a=New-Event 'banked'; $b=New-Event 'regular' 'regular'
    $view=Get-WidgetAnnouncementView (New-External @($a,$b)) 'en' $now
    Assert-Equal $view.active.Count 2 'Both confirmed kinds'
    Assert-Equal $view.active[0].title 'Confirmed reset credit grant' 'Banked title'
    Assert-Equal $view.active[1].title 'Confirmed global temporary reset' 'Regular title'
    Assert-Equal (Get-WidgetAnnouncementView (New-External) 'zh-CN' $now).emptyText '暂无已确认的重置卡赠送或全局临时重置公告' 'Merged empty state'
    Assert-Equal (Get-WidgetAnnouncementView (New-External @() @() 'unavailable') 'en' $now).emptyText 'Confirmed announcements unavailable' 'Unavailable state'
}
Test-Case 'rendering archives delivered rows locally even without another fetch' {
    $row=New-Event 'completed'; $row.deliveredAt=$now.AddHours(-23).ToString('o')
    $value=New-External @($row)
    Assert-Equal (Get-WidgetAnnouncementView $value 'en' $now).active.Count 1 'Initial active row'
    $later=Get-WidgetAnnouncementView $value 'en' $now.AddHours(1)
    Assert-Equal $later.active.Count 0 'Local archive'
    Assert-Equal $later.history.Count 1 'Archived history row'
}
Test-Case 'local transport failure and restart preserve announcements with pending-update status' {
    $base=Join-Path ([IO.Path]::GetTempPath()) ('quota-announcement-test-'+[guid]::NewGuid())
    try {
        $previous=New-External @((New-Event 'unresolved'))
        $retained=Merge-WidgetExternalData $previous $null $true
        Write-WidgetJson (Join-Path $base 'native-public-cache.json') $retained
        $restored=Read-WidgetJson (Join-Path $base 'native-public-cache.json')
        $view=Get-WidgetAnnouncementView $restored 'zh-CN' $now
        Assert-Equal $view.active.Count 1 'Known row survives restart'
        Assert-Equal $view.staleText '信息待更新' 'Connection failure state'
        Assert-Equal $previous.announcements.stale $false 'Previous object not mutated'
    } finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
}
Test-Case 'empty scheduled fetch retains unresolved known rows and delivery replaces same identity' {
    $a=New-Event 'stable'; $known=New-External @($a)
    Assert-Equal (Merge-WidgetExternalData $known (New-External) $false).announcements.items.Count 1 'Unresolved announcement retention'
    $delivered=New-Event 'stable'; $delivered.deliveredAt=$now.AddMinutes(-1).ToString('o')
    $merged=Merge-WidgetExternalData $known (New-External @($delivered)) $false
    Assert-Equal $merged.announcements.items.Count 1 'Identity deduplication'
    Assert-Equal (Get-WidgetAnnouncementView $merged 'en' $now).active[0].phase 'delivered' 'Delivery evidence replacement'
}
Test-Case 'source links reject executable insecure and credential-bearing URLs' {
    foreach ($url in @('http://example.org','file:///C:/a.exe','javascript:alert(1)','https://user:secret@example.org',('https://example.org'+"`n"+'x'))) {
        Assert-Equal (Test-WidgetHttpsUrl $url) $false 'Unsafe link'
    }
    Assert-Equal (Test-WidgetHttpsUrl 'https://example.org/confirmed?id=1') $true 'HTTPS source'
}
Test-Case 'date-only phases wait only after the whole scheduled UTC day without inventing a clock time' {
    $row=New-Event 'date-only'; $row.scheduledDate='2026-10-02'
    Assert-Equal (Get-WidgetAnnouncementPhase $row ([DateTimeOffset]'2026-10-02T23:59:59Z')) 'upcoming' 'Whole announcement date'
    Assert-Equal (Get-WidgetAnnouncementPhase $row ([DateTimeOffset]'2026-10-03T00:00:00Z')) 'waiting' 'Date completion boundary'
    $row.scheduledDate='2026-02-30'
    Assert-Equal (Get-WidgetAnnouncementPhase $row $now) 'announced' 'Invalid calendar date'
}
Test-Case 'a refreshed announcement cannot erase recorded delivery evidence' {
    $old=New-Event 'same-source'; $old.deliveredAt=$now.AddHours(-1).ToString('o')
    $incoming=New-Event 'same-source'; $incoming.summary='Refreshed description'
    $merged=Merge-WidgetExternalData (New-External @($old)) (New-External @($incoming)) $false
    Assert-Equal (Get-WidgetAnnouncementView $merged 'en' $now).active[0].phase 'delivered' 'Recorded completion retained'
    Assert-Equal $merged.announcements.items[0].summary 'Refreshed description' 'Fresh descriptive data'
}
Test-Case 'canonical event present in service active and history remains active only once' {
    $event=New-Event 'same-canonical-source'; $event.scheduledAt=$now.AddHours(1).ToString('o')
    $history=$event | ConvertTo-Json | ConvertFrom-Json; $history.scheduledAt=$null
    $merged=Merge-WidgetExternalData $null (New-External @($event) @($history)) $false
    Assert-Equal $merged.announcements.items.Count 1 'Service active event must not be moved to history'
    $view=Get-WidgetAnnouncementView $merged 'en' $now
    Assert-Equal $view.active.Count 1 'Visible active event'
    Assert-Equal $view.history.Count 0 'No duplicate visible history'
    Assert-Equal $view.active[0].phase 'upcoming' 'Original schedule retained'
}
Test-Case 'duplicate completed row survives outage through its 24-hour display boundary' {
    $event=New-Event 'recent-delivery'; $event.scheduledAt=$now.AddHours(-2).ToString('o'); $event.deliveredAt=$now.AddHours(-1).ToString('o')
    $merged=Merge-WidgetExternalData $null (New-External @($event) @($event)) $false
    $offline=Merge-WidgetExternalData $merged $null $true
    Assert-Equal (Get-WidgetAnnouncementView $offline 'en' $now).active.Count 1 'Recently completed event still active during outage'
    $later=Get-WidgetAnnouncementView $offline 'en' $now.AddHours(23)
    Assert-Equal $later.active.Count 0 'Archive after 24h'
    Assert-Equal $later.history.Count 1 'One archived record'
}
Test-Case 'completed announcements retain planned and completion timestamps plus scope' {
    $event=New-Event 'planned-and-delivered'; $event.scheduledAt=$now.AddHours(-2).ToString('o'); $event.deliveredAt=$now.AddHours(-1).ToString('o')
    foreach ($language in @('en','zh-CN')) {
        $row=(Get-WidgetAnnouncementView (New-External @($event)) $language $now).active[0]
        if (-not $row.details.Contains((Format-WidgetDate ([DateTimeOffset]$event.scheduledAt) $language))) { throw 'Original planned time was replaced by completion time' }
        if (-not $row.details.Contains((Format-WidgetDate ([DateTimeOffset]$event.deliveredAt) $language))) { throw 'Completion timestamp omitted' }
        if (-not $row.details.Contains((Get-WidgetText 'paid' $language))) { throw 'Completed event scope omitted' }
        Assert-Equal $row.scheduledText (Get-WidgetText 'originalScheduled' $language @((Format-WidgetDate ([DateTimeOffset]$event.scheduledAt) $language))) 'Explicit original plan'
    }
    $event.scheduledAt=$null; $event.scheduledDate='2026-09-30'
    $row=(Get-WidgetAnnouncementView (New-External @($event)) 'en' $now).active[0]
    if ($row.scheduledText -match '00:00' -or -not $row.scheduledText.Contains('Sep 30')) { throw 'Completed date-only event invented an original clock time' }
}
Test-Case 'Plus five-hour view preserves percent and reset time while other plans omit it' {
    $quota=[pscustomobject]@{status='ok'; plan='plus'; updatedAt=$now.ToUnixTimeMilliseconds(); fiveHour=[pscustomobject]@{remainingPercent=32; resetsAt=$now.AddHours(1).ToUnixTimeSeconds()}}
    $view=Get-WidgetFiveHourView $quota 'en' $now
    Assert-Equal $view.visible $true 'Plus-only visibility'
    Assert-Equal $view.percentText '32%' 'Reported remaining percentage'
    if (-not $view.resetText.Contains((Format-WidgetDate $now.AddHours(1) 'en'))) { throw 'Five-hour reset time omitted' }
    $quota.plan='pro'; Assert-Equal (Get-WidgetFiveHourView $quota 'en' $now).visible $false 'Pro is not Plus'
    $quota.plan='plus'; $quota.fiveHour=$null
    Assert-Equal (Get-WidgetFiveHourView $quota 'en' $now).percentText 'Unavailable' 'Missing data is not invented'
}
Test-Case 'source pending state is separate from quota age and appears only once' {
    $known=New-External @((New-Event 'known')); $known.announcements.stale=$true; $known.announcements.sourceUpdatedAt=$now.AddHours(-3).ToString('o')
    $view=Get-WidgetAnnouncementView $known 'en' $now
    Assert-Equal $view.staleText 'Information pending update' 'Single announcement pending state'
    $source=Format-WidgetPublicUpdate $known.announcements 'en' $now
    if (-not $source.Contains((Format-WidgetDate $now.AddHours(-3) 'en'))) { throw 'Public source timestamp not preserved' }
    Assert-Equal (Format-WidgetRelativeUpdate ($now.AddMinutes(-1).ToUnixTimeMilliseconds()) 'en' $now) 'Updated 1 minute ago' 'Quota freshness remains independent'
    $empty=New-External @() @() 'unavailable'; $empty.announcements.stale=$true
    $unavailable=Get-WidgetAnnouncementView $empty 'en' $now
    Assert-Equal $unavailable.staleText '' 'Unavailable line does not duplicate pending warning'
    Assert-Equal $unavailable.emptyText 'Confirmed announcements unavailable' 'One unavailable line'
}
Test-Case 'inventory and evidence link terminology match the approved bilingual layout' {
    Assert-Equal (Get-WidgetText 'cards' 'en' @(2)) 'Reset credits 2' 'Inventory is not consumption count'
    Assert-Equal (Get-WidgetText 'announcementSource' 'en') 'View announcement' 'Announcement link'
    Assert-Equal (Get-WidgetText 'deliverySource' 'en') 'Delivery record' 'Evidence link'
    foreach ($language in @('en','zh-CN')) {
        $cadence=Get-WidgetText 'refreshCadence' $language
        if (-not $cadence.Contains('1') -or -not $cadence.Contains('10')) { throw 'Quota/public cadence omitted' }
    }
}
Test-Case 'forecast outage and restart never display cached odds as current without active notices' {
    $previous=New-External
    $previous.forecast=[pscustomobject]@{next24h=15;next48h=33;next7d=69;sourceUpdatedAt=$now.AddMinutes(-2).ToString('o')}
    $offline=Merge-WidgetExternalData $previous $null $true
    Assert-Equal $offline.status 'unavailable' 'Local connection failure invalidates public freshness'
    $view=Get-WidgetForecastView $offline 'en' $now
    Assert-Equal $view.available $false 'Cached odds cannot be presented as current'
    if (-not $view.pendingText) {throw 'No source pending state without active notices'}
    $base=Join-Path ([IO.Path]::GetTempPath()) ('quota-forecast-test-'+[guid]::NewGuid())
    try {
        Write-WidgetJson (Join-Path $base 'native-public-cache.json') $previous
        $restored=Merge-WidgetExternalData (Read-WidgetJson (Join-Path $base 'native-public-cache.json')) $null $true
        Assert-Equal (Get-WidgetForecastView $restored 'en' $now).available $false 'Restart requires a new successful response'
        $fresh=Merge-WidgetExternalData $restored $previous $false
        Assert-Equal (Get-WidgetForecastView $fresh 'en' $now).available $true 'Successful fresh response restores estimates'
        $previous.forecast.sourceUpdatedAt=$now.AddDays(-30).ToString('o')
        Assert-Equal (Get-WidgetForecastView $previous 'en' $now).available $false 'Old source data expires even with an ok status'
    } finally {Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue}
}
Test-Case 'completed results explain their 24 hour retention in both languages' {
    $event=New-Event 'retention-caption';$event.deliveredAt=$now.AddHours(-1).ToString('o')
    foreach ($language in @('en','zh-CN')) {
        $row=(Get-WidgetAnnouncementView (New-External @($event)) $language $now).active[0]
        if (-not $row.retentionText -or -not $row.retentionText.Contains('24')) {throw 'Completed result retention caption absent'}
    }
}
if ($script:failures) { throw "$script:failures native layout tests failed" }
