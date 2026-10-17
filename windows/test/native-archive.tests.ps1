$ErrorActionPreference='Stop'
# FABRICATED: presentation and reminder-reading boundaries; no account or UI access.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
function Check($actual,$expected,$message){if($actual -cne $expected){throw "$message : expected [$expected], got [$actual]"}}
$now=[DateTimeOffset]::Parse('2026-10-17T12:00:00Z')
$url='https://x.com/thsottiaux/status/1000000000000000991'
$raw=[pscustomobject]@{id=($url+'#regular');kind='regular';sourceUrl=$url;announcedAt=$now.AddHours(-30).ToString('o');certainty='announced';announcementBasis='original';statementBasis='original';scheduledAt=$now.AddHours(1).ToString('o');scheduleText='at 13:00 UTC';noticeVersion='FABRICATED-v1'}
$history=@(0..7 | ForEach-Object {[pscustomobject]@{id=('old-'+$_);kind='regular';sortAt=(100-$_);noticeVersion='FABRICATED-v1'}})
$activity=[pscustomobject]@{active=@();history=$history}
$folded=Get-WidgetVisibleActivityView $activity
Check $folded.active.Count 0 'Archived records do not occupy current messages'
Check $folded.history.Count 0 'History starts folded'
Check $folded.historyTotal 8 'Stored history is retained'
Check (Get-WidgetText 'activityEmpty' 'zh-CN') '暂无新消息' 'Empty current list has clear copy'
$first=Get-WidgetVisibleActivityView $activity 3 $true 3
Check ($first.history.id -join ',') 'old-0,old-1,old-2' 'Only first three historical records load'
Check $first.historyNextCount 3 'Next historical batch contains three'
$second=Get-WidgetVisibleActivityView $activity 3 $true 6
Check $second.history.Count 6 'Second historical page appends three'
Check $second.historyNextCount 2 'Last historical page preserves the remaining two'
Check (Get-WidgetVisibleActivityView $activity 3 $false 9).history.Count 0 'Collapse unloads every historical control'
Check (Get-WidgetVisibleActivityView $activity 3 $true 3).history.Count 3 'Reopening history starts at three'
Write-Output 'PASS folded history, three-record batches, collapse and no-loss storage'
foreach($language in @('en','zh-CN')) {
    $external=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');items=@();history=@($raw)}}
    $view=Get-WidgetResetActivityView $null $external $language $now
    Check $view.active.Count 1 'A valid old preview remains visible even in source history'
    Check $view.active[0].previewPriority $true 'Valid preview remains prioritized'
    $expired=Get-WidgetResetActivityView $null $external $language $now.AddHours(1)
    Check $expired.active.Count 0 'Expired preview archives at its deadline'
    Check $expired.history.Count 1 'Expired preview remains in history'
    Check ([bool]$expired.history[0].completedEvidence) $false 'Archiving never invents completion'
    $correction=[pscustomobject]@{id='https://x.com/thsottiaux/status/1000000000000000992#regular';kind='regular';sourceUrl='https://x.com/thsottiaux/status/1000000000000000992';announcedAt=$now.AddMinutes(-1).ToString('o');certainty='announced';announcementBasis='original';statementBasis='original';correction='cancelled';relatedUrls=@($url);noticeVersion='FABRICATED-v2'}
    $external.announcements.history=@($raw,$correction)
    $changed=Get-WidgetResetActivityView $null $external $language $now
    Check (@($changed.active | Where-Object id -eq $correction.id).Count) 1 'Linked cancellation resurfaces from source history'
    $page=Get-WidgetVisibleActivityView $changed
    $notice=Get-WidgetAnnouncementAlertView ([pscustomobject]@{unread=@([pscustomobject]@{id='https://x.com/thsottiaux/status/1000000000000000992#regular';kind='regular';version='FABRICATED-v2'})}) $language
    Check (Get-WidgetAnnouncementReadEntries $notice $page $true).Count 1 'Visible current correction can clear its matching reminder'
    $page.active[0].noticeVersion='FABRICATED-old'
    Check (Get-WidgetAnnouncementReadEntries $notice $page $true).Count 0 'Old rendered version cannot clear a changed reminder'
    $aged=Get-WidgetResetActivityView $null $external $language $now.AddHours(24)
    Check $aged.active.Count 0 'Old corrections archive after a day'
    $correction.announcedAt=$now.AddHours(-30).ToString('o')
    $correction | Add-Member NoteProperty previewPriority $true
    $external.announcements | Add-Member NoteProperty previewTrace @([pscustomobject]@{id=$correction.id;notifiedAt=$now.ToUnixTimeMilliseconds()})
    $oldPostChange=Get-WidgetResetActivityView $null $external $language $now
    Check (@($oldPostChange.active | Where-Object id -eq $correction.id).Count) 1 'An active new service reminder overrides the old post date'
    $offline=Get-WidgetResetActivityView $null $external $language $now.AddHours(25)
    Check $offline.active.Count 0 'An old cached service priority expires after its reminder window'
    Check $offline.history.Count 2 'Offline archiving retains both historical records'
    Write-Output "PASS valid/expired preview, linked correction and version-qualified read ($language)"
}
