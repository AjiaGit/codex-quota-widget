$ErrorActionPreference='Stop'
# FABRICATED DATA. Pure presentation tests also run on PowerShell for macOS;
# they do not validate Windows Forms or physical Windows desktop rendering.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
$script:failures=0
function Test-Case([string]$name,[scriptblock]$action) {
    try { & $action; Write-Output "PASS $name" } catch { $script:failures++; Write-Output "FAIL $name : $($_.Exception.Message)" }
}
function Assert-Equal($actual,$expected,[string]$reason) {
    if ($actual -cne $expected) { throw "$reason. Expected [$expected], got [$actual]" }
}
$now=[DateTimeOffset]::Parse('2026-10-15T06:00:00Z')
$sourceUrl='https://x.com/thsottiaux/status/1000000000000000101'
function New-Hint {
    [pscustomobject]@{id=($sourceUrl+'#regular');kind='regular';certainty='unconfirmed';sourceHint='active';kindKnown=$false;sourceSites=@('codex-reset.com');
        sourceUrl=$sourceUrl;announcedAt='2026-10-15T04:56:00Z';summary='Landing within the next 2 hours';sourceWithdrawn=$false}
}
foreach ($language in @('en','zh-CN')) {
    Test-Case "source hint unread dot and reading keep the evidence label ($language)" {
        $id=$sourceUrl+'#regular'
        $hint=[pscustomobject]@{id=$id;kind='regular';sourceHint=$true}
        $view=Get-WidgetAnnouncementAlertView ([pscustomobject]@{unread=@($hint)}) $language
        Assert-Equal $view.hasUnread $true 'Hint turns on the existing dot'
        Assert-Equal $view.tooltip $(if ($language -eq 'en') {'New monitoring-site hint · Click for details'} else {'有新的监控网站提示，点击查看详情'}) 'Tooltip identifies a hint, not a completed reset'
        $record=ConvertTo-WidgetAnnouncementRow (New-Hint) $language $now
        $shown=[pscustomobject]@{active=@($record);history=@()}
        Assert-Equal (Get-WidgetAnnouncementReadIds $view $shown $false).Count 0 'Hidden details never mark a hint read'
        Assert-Equal ((Get-WidgetAnnouncementReadIds $view $shown $true) -join ',') $id 'Visible hint can be read'
        $collapsed=[pscustomobject]@{active=@();history=@()}
        Assert-Equal (Get-WidgetAnnouncementReadIds $view $collapsed $true).Count 0 'Collapsed records remain unread'
        $mixed=Get-WidgetAnnouncementAlertView ([pscustomobject]@{unread=@($hint,[pscustomobject]@{id='https://example.org/confirmed#banked';kind='banked'})}) $language
        Assert-Equal $mixed.tooltip $(if ($language -eq 'en') {'New reset updates · Click for details'} else {'有新的重置动态，点击查看详情'}) 'Mixed hint/announcement tooltip remains neutral'
    }

    Test-Case "source hint presentation is attributed and not confirmed ($language)" {
        $row=ConvertTo-WidgetAnnouncementRow (New-Hint) $language $now $false ([TimeZoneInfo]::Utc)
        $view=Get-WidgetActivityPresentation $row $language
        Assert-Equal $view.title $(if ($language -eq 'en') {'Reset-related news'} else {'重置相关消息'}) 'Same title as Mac'
        Assert-Equal $view.extra (($(if ($language -eq 'en') {'The event type and whether this is an advance notice or a completion message are unclear.'} else {'暂无法判断具体事项，以及是预告还是完成消息。'}))+[Environment]::NewLine+'Landing within the next 2 hours') 'Disclosure retains both evidence level and original text'
        Assert-Equal $row.monitorSourceUrl $null 'One original-source link'
        Assert-Equal $row.sourceUrl $sourceUrl 'Original post link'
        Assert-Equal $row.explicit $false 'Not a confirmed announcement'
        Assert-Equal $view.missing $false 'Do not imply that only completion time is missing'
        if ($row.completedText -or $row.scheduledText -or $row.deliverySourceUrl) { throw 'Hint invents a schedule or completion' }
        if ($view.extra -notmatch 'Landing within the next 2 hours') { throw 'Original wording missing from details' }
    }
    Test-Case "expired and inactive hints retain their attribution ($language)" {
        $record=New-Hint
        $row=ConvertTo-WidgetAnnouncementRow $record $language $now $true
        $view=Get-WidgetActivityPresentation $row $language
        Assert-Equal $view.status $(if ($language -eq 'en') {'Earlier site hint; subsequent progress is unknown.'} else {'较早的网站提示，后续进展未知。'}) 'Expired without completion'
        $record.sourceHint='inactive';$record.sourceWithdrawn=$true
        $view=Get-WidgetActivityPresentation (ConvertTo-WidgetAnnouncementRow $record $language $now $true) $language
        Assert-Equal $view.status $(if ($language -eq 'en') {'The site stopped flagging this hint; subsequent progress is unknown.'} else {'网站已停止这条提示，后续进展未知。'}) 'Inactive is not completion'
    }
    Test-Case "cached hint expires without a successful server refresh ($language)" {
        $external=[pscustomobject]@{status='unavailable';announcements=[pscustomobject]@{status='unavailable';stale=$true;items=@((New-Hint));history=@()}}
        $view=Get-WidgetAnnouncementView $external $language $now.AddHours(24)
        Assert-Equal $view.active.Count 0 'Expired hint cannot remain current while offline'
        Assert-Equal $view.history.Count 1 'Expired hint remains in history'
    }
    Test-Case "confirmed evidence overrides retained hint metadata ($language)" {
        $record=New-Hint;$record.certainty='announced'
        $row=ConvertTo-WidgetAnnouncementRow $record $language $now
        Assert-Equal $row.explicit $true 'Confirmed evidence keeps its existing presentation'
        Assert-Equal $row.monitorSourceUrl $null 'No source-hint attribution after confirmation'
        $view=Get-WidgetActivityPresentation $row $language
        if ($view.title -in @('Reset-related news','重置相关消息')) { throw 'Confirmation still presented as a hint' }
    }
}
Test-Case 'native cache follows a source hint category correction without duplicate rows' {
    $old=New-Hint;$old.kind='banked';$old.id=$sourceUrl+'#banked'
    $next=New-Hint
    function Snapshot($record) { [pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;items=@($record);history=@($record)}} }
    $previous=Snapshot $old
    $merged=Merge-WidgetExternalData $previous (Snapshot $next)
    Assert-Equal $merged.announcements.items.Count 1 'One post after source category correction'
    Assert-Equal $merged.announcements.items[0].kind 'regular' 'Use the current service category'
    $view=Get-WidgetAnnouncementView $merged 'en' $now
    Assert-Equal $view.active.Count 1 'One visible hint'
    Assert-Equal $view.active[0].monitorSourceUrl $null 'Duplicate monitoring link is omitted'
    $next.certainty='announced';$next.kind='banked';$next.id=$sourceUrl+'#banked';$next.sourceHint=$null
    $confirmed=Merge-WidgetExternalData $merged (Snapshot $next)
    Assert-Equal $confirmed.announcements.items.Count 1 'Confirmation replaces the cached hint'
    Assert-Equal $confirmed.announcements.items[0].kind 'banked' 'Confirmed category takes precedence'
    $view=Get-WidgetAnnouncementView $confirmed 'en' $now
    Assert-Equal $view.active[0].explicit $true 'Confirmation remains confirmed'
    Assert-Equal $view.active[0].monitorSourceUrl $null 'Confirmed record uses the existing presentation'
    Assert-Equal $previous.announcements.items[0].kind 'banked' 'Old snapshot is not mutated'
}
if($script:failures){exit 1}
