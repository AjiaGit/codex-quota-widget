$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
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
    [pscustomobject]@{ id=$id; kind=$kind; certainty='announced'; announcedAt='2026-09-29T12:00:00Z'; scheduledAt=$null; scheduledDate=$null; deliveredAt=$null; scope='paid'; scopeLabel=$null; sourceUrl='https://example.org/announcement'; deliverySourceUrl=$null; summary='Confirmed announcement'; summaryZh='已确认公告' }
}
function New-External($items = @(), $history = @(), [string]$status = 'ok') {
    [pscustomobject]@{ status='ok'; announcements=[pscustomobject]@{ status=$status; items=@($items); history=@($history); sourceUpdatedAt='2026-09-30T11:00:00Z'; stale=$false } }
}
Test-Case 'outside clicks collapse only a visible settled detail window' {
    $frame=[Drawing.Rectangle]::new(-606,100,606,585)
    $outside=[Drawing.Point]::new(20,300)
    Assert-Equal (Test-WidgetOutsideClick 'Detail' $true $false $frame $outside) $true 'Outside detail'
    Assert-Equal (Test-WidgetOutsideClick 'Detail' $true $false $frame ([Drawing.Point]::new(-300,300))) $false 'Inside detail'
    Assert-Equal (Test-WidgetOutsideClick 'Detail' $true $false $frame ([Drawing.Point]::new(-606,100))) $false 'Window edge'
    Assert-Equal (Test-WidgetOutsideClick 'Compact' $true $false $frame $outside) $false 'Compact stays visible'
    Assert-Equal (Test-WidgetOutsideClick 'Detail' $false $false $frame $outside) $false 'Hidden stays hidden'
    Assert-Equal (Test-WidgetOutsideClick 'Detail' $true $true $frame $outside) $false 'Transition not interrupted'
}
Test-Case 'automatic detail height fits content while respecting the working screen' {
    $frame=[Drawing.Rectangle]::new(800,200,606,585)
    $screen=[Drawing.Rectangle]::new(0,0,1440,900)
    Assert-Equal (Get-WidgetDetailFittedFrame $frame 600 54 $screen) ([Drawing.Rectangle]::new(800,200,606,664)) 'Fits content and keeps the top'
    Assert-Equal (Get-WidgetDetailFittedFrame $frame 1800 54 $screen) ([Drawing.Rectangle]::new(800,0,606,900)) 'Long history stays on screen'
}

Test-Case 'legacy fixed detail height migrates to fitting without changing future manual preference' {
 Assert-Equal (Get-WidgetDetailAutoHeightSetting $null) $true 'New install fits'
 Assert-Equal (Get-WidgetDetailAutoHeightSetting ([pscustomobject]@{detailLayoutVersion=4;detailAutoHeight=$false})) $true 'Legacy short window must fit'
 Assert-Equal (Get-WidgetDetailAutoHeightSetting ([pscustomobject]@{detailLayoutVersion=5;detailAutoHeight=$false})) $false 'New manual resize remains saved'
 Assert-Equal (Get-WidgetDetailAutoHeightSetting ([pscustomobject]@{detailLayoutVersion=5;detailAutoHeight=$true})) $true 'New auto preference persists'
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
Test-Case 'Plus quota precedes credits and announcements lead directly to history' {
    Assert-Equal ((Get-WidgetDetailSectionOrder $true) -join ',') 'hero,fiveHour,credits,announcements,history,sources,footer' 'Plus section order'
    Assert-Equal ((Get-WidgetDetailSectionOrder $false) -contains 'fiveHour') $false 'Non-Plus quota'
}
Test-Case 'personal recoveries share reset news and move into the same history after 24 hours' {
    $start=$now.AddMinutes(-2).ToUnixTimeMilliseconds(); $found=$now.AddSeconds(-30).ToUnixTimeMilliseconds()
    $data=[pscustomobject]@{status='ok';recoveryHistory=[pscustomobject]@{status='ok';trackingSince=$start;records=@([pscustomobject]@{observedFrom=$start;detectedAt=$found;beforePercent=45;afterPercent=99})}}
    $event=New-Event 'public'; $event.announcedAt=$now.AddMinutes(-1).ToString('o')
    $feed=New-External @($event)
    $view=Get-WidgetResetActivityView $data $feed 'en' $now
    Assert-Equal $view.active.Count 2 'Both sources in one list'
    Assert-Equal $view.active[0].kind 'recovery' 'Newest personal recovery first'
    Assert-Equal $view.active[1].phase 'announced' 'Personal recovery does not confirm public delivery'
    $later=Get-WidgetResetActivityView $data $feed 'en' ($now.AddHours(24))
    Assert-Equal $later.history[0].kind 'recovery' 'Older recovery shares history'
    Assert-Equal $later.active.Count 1 'Pending public announcement remains active'
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
    if (-not $view.active[0].scheduledText.Contains('10月2日') -or $view.active[0].scheduledText -match '\d{1,2}:\d{2}' -or $view.active[0].details -match 'private-key') { throw 'Date-only display invented a time or exposed an ID' }
    foreach ($zone in @([TimeZoneInfo]::Utc, [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time'))) {
        $zoned = ConvertTo-WidgetAnnouncementRow $row 'zh-CN' $now $false $zone
        if (-not $zoned.scheduledText.Contains('10月2日') -or $zoned.scheduledText -match '\d{1,2}:\d{2}' -or $zoned.details -match 'private-key') { throw 'Date-only display invented a time or exposed an ID' }
        if (-not $zoned.announcedText.Contains('UTC')) { throw 'Publication lost its independently reported time zone' }
    }
    Assert-Equal $view.active[0].summary '已确认公告' 'Chinese summary'
    Assert-Equal (Get-WidgetAnnouncementView (New-External @($row)) 'en' $now).active[0].summary 'Confirmed announcement' 'English summary'
}
Test-Case 'two kinds stay separate and empty/unavailable feeds use one muted state line' {
    $a=New-Event 'banked'; $b=New-Event 'regular' 'regular'
    $view=Get-WidgetAnnouncementView (New-External @($a,$b)) 'en' $now
    Assert-Equal $view.active.Count 2 'Both confirmed kinds'
    Assert-Equal $view.active[0].title 'Confirmed banked reset grant' 'Banked title'
    Assert-Equal $view.active[1].title 'Confirmed global reset' 'Regular title'
    Assert-Equal (Get-WidgetAnnouncementView (New-External) 'zh-CN' $now).emptyText '监控来源暂无已确认的重置次数赠送或全局额度重置公告' 'Merged empty state'
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
        Assert-Equal $row.scheduledText (Get-WidgetText 'originalGrant' $language @((Format-WidgetAnnouncementDate ([DateTimeOffset]$event.scheduledAt) $language ([TimeZoneInfo]::Local) $now))) 'Explicit original plan'
    }
    $event.scheduledAt=$null; $event.scheduledDate='2026-09-30'
    $row=(Get-WidgetAnnouncementView (New-External @($event)) 'en' $now).active[0]
    if ($row.scheduledText -match '00:00' -or -not $row.scheduledText.Contains('Sep 30')) { throw 'Completed date-only event invented an original clock time' }
}
Test-Case 'precise schedules show event-time local offsets and independent publication times' {
    $zone=[TimeZoneInfo]::CreateCustomTimeZone('Test +08',[TimeSpan]::FromHours(8),'Test +08','Test +08')
    $event=New-Event 'timed-grant'; $event.scheduledAt='2026-10-01T20:30:00Z'; $event.announcedAt='2026-09-30T10:00:00Z'
    $row=ConvertTo-WidgetAnnouncementRow $event 'zh-CN' $now $false $zone
    if ($row.scheduledText -notmatch '预定送达.*10月2日 04:30.*本地 UTC\+08:00') { throw 'Scheduled time did not convert across the local date boundary' }
    if ($row.announcedText -notmatch '公告发布.*9月30日 18:00.*本地 UTC\+08:00') { throw 'Publication time omitted or confused with delivery' }
    $india=[TimeZoneInfo]::CreateCustomTimeZone('Test +0530',[TimeSpan]::FromMinutes(330),'Test +0530','Test +0530')
    if ((Format-WidgetAnnouncementDate ([DateTimeOffset]'2026-10-01T18:30:00Z') 'en' $india $now) -notmatch 'Oct 2 00:00.*UTC\+05:30') { throw 'Fractional offset or midnight conversion failed' }
    $pacific=[TimeZoneInfo]::FindSystemTimeZoneById('Pacific Standard Time')
    if ((Format-WidgetAnnouncementDate ([DateTimeOffset]'2026-11-01T08:30:00Z') 'en' $pacific $now) -notmatch '01:30.*UTC-07:00') { throw 'Pre-DST-change offset incorrect' }
    if ((Format-WidgetAnnouncementDate ([DateTimeOffset]'2026-11-01T09:30:00Z') 'en' $pacific $now) -notmatch '01:30.*UTC-08:00') { throw 'Post-DST-change offset incorrect' }
    $event.scheduledAt=$null; $event.scheduledDate='2026-10-01'
    $row=ConvertTo-WidgetAnnouncementRow $event 'en' $now $false $pacific
    if ($row.scheduledText -notmatch 'Oct 1.*time not announced' -or $row.scheduledText -match 'UTC|00:00') { throw 'Date-only source invented a local clock or zone' }
    $event.scheduledDate=$null
    $row=ConvertTo-WidgetAnnouncementRow $event 'en' $now $false $zone
    Assert-Equal $row.scheduledText 'Delivery time not announced' 'Missing delivery time remains unknown'
}
Test-Case 'source-withdrawn records stay neutral in history after native cache reconciliation' {
    $event=New-Event 'withdrawn-source'
    $withdrawn=$event | ConvertTo-Json | ConvertFrom-Json
    $withdrawn | Add-Member -NotePropertyName sourceWithdrawn -NotePropertyValue $true
    $merged=Merge-WidgetExternalData (New-External @($event)) (New-External @() @($withdrawn)) $false
    $view=Get-WidgetAnnouncementView $merged 'zh-CN' $now
    Assert-Equal $view.active.Count 0 'Withdrawn event must leave active announcements'
    Assert-Equal $view.history[0].title '来源已撤下的公告记录' 'Neutral withdrawn title'
    if ($view.history[0].details -notmatch '监控来源已撤下此记录') { throw 'Source correction status omitted' }
    $event.scheduledAt=$now.AddHours(1).ToString('o')
    $event | Add-Member -NotePropertyName scheduledTimeZone -NotePropertyValue 'PT'
    $view=Get-WidgetAnnouncementView (New-External @($event)) 'en' $now
    if ($view.active[0].scheduleNote -notmatch 'PT.*monitoring source') { throw 'Upstream timezone interpretation not attributed' }
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
    Assert-Equal (Get-WidgetText 'cards' 'en' @(2)) 'Banked resets 2' 'Inventory is not consumption count'
    Assert-Equal (Get-WidgetText 'announcementSource' 'en') 'View announcement' 'Announcement link'
    Assert-Equal (Get-WidgetText 'deliverySource' 'en') 'Delivery record' 'Evidence link'
    foreach ($language in @('en','zh-CN')) {
        $cadence=Get-WidgetText 'refreshCadence' $language
        if (-not $cadence.Contains('1') -or -not $cadence.Contains('10')) { throw 'Quota/public cadence omitted' }
    }
}
Test-Case 'completed results explain their 24 hour retention in both languages' {
    $event=New-Event 'retention-caption';$event.deliveredAt=$now.AddHours(-1).ToString('o')
    foreach ($language in @('en','zh-CN')) {
        $row=(Get-WidgetAnnouncementView (New-External @($event)) $language $now).active[0]
        if (-not $row.retentionText -or -not $row.retentionText.Contains('24')) {throw 'Completed result retention caption absent'}
    }
}
Test-Case 'expired announcement cache does not claim no confirmed announcements' {
    $value=New-External
    $later=$now.AddHours(25)
    $view=Get-WidgetAnnouncementView $value 'en' $later
    Assert-Equal $view.emptyText 'Confirmed announcements unavailable' 'Source cache expired'
}
Test-Case 'historical rows without delivery evidence do not imply an outstanding delivery' {
    $event=New-Event 'historical-grant'; $event.announcedAt=$now.AddDays(-7).ToString('o')
    foreach ($language in @('en','zh-CN')) {
        $historical=(Get-WidgetAnnouncementView (New-External @() @($event)) $language $now).history[0]
        Assert-Equal $historical.phase 'unknown' 'Historical delivery status'
        if (-not $historical.details.Contains((Get-WidgetText 'phaseUnknown' $language))) {throw 'Missing delivery record was not explained'}
        Assert-Equal $historical.completedText $null 'No invented completion'
        $active=(Get-WidgetAnnouncementView (New-External @($event)) $language $now).active[0]
        Assert-Equal $active.phase 'announced' 'Active announcements still await evidence'
    }
    $event.deliveredAt=$now.AddDays(-2).ToString('o'); $event.deliverySourceUrl='https://example.org/delivered'
    $confirmed=(Get-WidgetAnnouncementView (New-External @() @($event)) 'en' $now).history[0]
    Assert-Equal $confirmed.phase 'archived' 'Historical confirmed delivery preserved'
    Assert-Equal $confirmed.deliverySourceUrl $event.deliverySourceUrl 'Delivery evidence preserved'
}
Test-Case 'compact announcement indicator validates sources and both localized announcement kinds' {
    $alerts=[pscustomobject]@{unread=@([pscustomobject]@{id='https://example.org/grant#banked';kind='banked'},[pscustomobject]@{id='https://example.org/reset#regular';kind='regular'})}
    $view=Get-WidgetAnnouncementAlertView $alerts 'en'
    Assert-Equal $view.hasUnread $true 'Unread indicator'
    if (-not $view.tooltip.Contains('banked reset grant and global reset')) {throw 'Kinds not explained'}
    $zh=Get-WidgetAnnouncementAlertView $alerts 'zh-CN'
    if (-not $zh.tooltip.Contains('重置次数赠送和全局额度重置')) {throw 'Chinese tooltip missing'}
    $bad=[pscustomobject]@{unread=@([pscustomobject]@{id='javascript:alert(1)#banked';kind='banked'},[pscustomobject]@{id='https://example.org/hint#hinted';kind='hinted'})}
    Assert-Equal (Get-WidgetAnnouncementAlertView $bad 'en').hasUnread $false 'Unsafe or unconfirmed notices ignored'
    foreach ($side in @(48,64,100)) {
        $rect=Get-WidgetNoticeBounds $side $side
        if ($rect.x -lt 5 -or $rect.y -lt 5 -or $rect.x+$rect.width -gt $side-5 -or $rect.width -lt 5 -or $rect.width -gt 8) {throw 'Dot is outside compact bounds'}
    }
}
Test-Case 'hidden detail never acknowledges notices and newly arrived unseen IDs stay unread' {
    $alerts=[pscustomobject]@{ids=@('shown','later')}
    $view=[pscustomobject]@{active=@([pscustomobject]@{key='shown'});history=@()}
    Assert-Equal (Get-WidgetAnnouncementReadIds $alerts $view $false).Count 0 'Compact and hidden state'
    Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $view $true) -join ',') 'shown' 'Only rendered IDs'
}
Test-Case 'history pages expose only five more rows and never mark later pages read' {
    $rows=@(0..11 | ForEach-Object {[pscustomobject]@{id=('history-'+$_);key=('history-'+$_)}})
    $activity=[pscustomobject]@{featured=@();earlier=@();history=$rows}
    $alerts=[pscustomobject]@{ids=@($rows.id)}
    Assert-Equal (Get-WidgetVisibleActivityView $activity $false $false).history.Count 0 'Closed history'
    $first=Get-WidgetVisibleActivityView $activity $false $true
    Assert-Equal ($first.history.id -join ',') 'history-0,history-1,history-2,history-3,history-4' 'Initial five recent records'
    Assert-Equal $first.historyNextCount 5 'Next batch size'
    Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $first $true) -join ',') 'history-0,history-1,history-2,history-3,history-4' 'Only shown records become read'
    $second=Get-WidgetVisibleActivityView $activity $false $true 10
    Assert-Equal $second.history.Count 10 'Second batch'
    Assert-Equal $second.historyNextCount 2 'Final partial batch'
    $all=Get-WidgetVisibleActivityView $activity $false $true 15
    Assert-Equal $all.history.Count 12 'Final page includes all remaining rows'
    Assert-Equal $all.historyNextCount 0 'No more button after the end'
    Assert-Equal $activity.history.Count 12 'Stored history retained'
}
if ($script:failures) { throw "$script:failures native layout tests failed" }
