param([string]$NativePath=(Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1'))
$ErrorActionPreference='Stop'
# FABRICATED DATA. These portable tests validate native presentation and cache
# contracts; they are not physical Windows or Windows Forms acceptance.
. $NativePath
$now=[DateTimeOffset]::Parse('2026-10-16T06:00:00Z')
$url='https://x.com/thsottiaux/status/1000000000000000901'
function Check($actual,$expected,[string]$message) {if($actual -cne $expected){throw "$message : expected [$expected], got [$actual]"}}
foreach($language in @('en','zh-CN')) {
    foreach($kind in @('regular','banked')) {
        $row=[pscustomobject]@{id=($url+'#'+$kind);kind=$kind;sourceUrl=$url;announcedAt='2026-10-16T05:00:00Z';certainty='announced';announcementBasis='original';statementBasis='original';sourceSites=@('codex-reset.com')}
        $view=Get-WidgetActivityPresentation (ConvertTo-WidgetAnnouncementRow $row $language $now) $language
        Check $view.category $(if($language -eq 'en'){'Advance notice'}else{'预告'}) 'Preview category'
        if($view.title -notmatch 'Tibo'){throw 'Publisher attribution was lost'}
        $row.certainty='unconfirmed';$row.statementBasis='site'
        $view=Get-WidgetActivityPresentation (ConvertTo-WidgetAnnouncementRow $row $language $now) $language
        Check $view.category $(if($language -eq 'en'){'Unverified update'}else{'待核实消息'}) 'Unverified category'
        Check $view.missing $false 'No redundant completion-missing line'
        if($view.title -match 'Tibo'){throw 'Site-only evidence became a publisher statement'}
        $row.certainty='announced';$row.statementBasis='observation'
        $row | Add-Member deliveredAt '2026-10-16T05:30:00Z'
        $row | Add-Member completionTimeBasis 'observation'
        $view=Get-WidgetActivityPresentation (ConvertTo-WidgetAnnouncementRow $row $language $now) $language
        Check $view.category $(if($language -eq 'en'){'Completion update'}else{'完成消息'}) 'Completion category'
        if($view.title -notmatch $(if($language -eq 'en'){'monitoring'}else{'监测账号'})){throw 'Website observation broadened into a global/account claim'}
        if($view.fact -notmatch $(if($language -eq 'en'){'Website detected'}else{'网站检测'})){throw 'Observation time became a publication time'}
        Write-Output "PASS three categories, attribution and observation scope ($language/$kind)"
    }
    $external=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;partial=$true;sourceUpdatedAt='2026-10-16T05:55:00Z';providerHealth=@([pscustomobject]@{site='codex-reset.com';status='unavailable'});items=@();history=@()}}
    $notice=Get-WidgetPublicNoticeView $external $language $now
    Check $notice.visible $true 'Partial outage must remain visible'
    Check $notice.title $(if($language -eq 'en'){'Some message sources are unavailable'}else{'部分来源暂不可用'}) 'Partial source warning'
    Write-Output "PASS partial source failure is visible ($language)"
}
$completed=[pscustomobject]@{id=($url+'#regular');kind='regular';kindBasis='original';sourceUrl=$url;deliveredAt='2026-10-16T05:30:00Z';certainty='announced'}
$old=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';providerHealth=@();items=@($completed);history=@()}}
$regular=[pscustomobject]@{id=($url+'#regular');kind='regular';kindBasis='original';sourceUrl=$url;certainty='unconfirmed';correction='not-complete';deliveredAt=$null;multiKind=$true}
$banked=[pscustomobject]@{id=($url+'#banked');kind='banked';kindBasis='original';sourceUrl=$url;certainty='announced';multiKind=$true}
$next=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';providerHealth=@();items=@($regular,$banked);history=@()}}
$merged=Merge-WidgetExternalData $old $next
Check $merged.announcements.items.Count 2 'Service-owned mixed actions must stay separate'
Check $merged.announcements.items[0].deliveredAt $null 'UI cache must not restore a corrected completion'
$failed=Merge-WidgetExternalData $merged $null $true
Check $failed.announcements.items.Count 2 'Transport failure retains both cached actions'
Check $failed.announcements.stale $true 'Transport failure remains visible'
Write-Output 'PASS service-owned mixed actions and explicit corrections survive native cache/failure handling'

$backup=[pscustomobject]@{id=($url+'#regular');kind='regular';sourceUrl=$url;announcedAt='2026-10-16T05:00:00Z';certainty='unconfirmed';sourceHint='recent';sourceSites=@('codexreset.dev')}
$backupRow=ConvertTo-WidgetAnnouncementRow $backup 'en' $now
Check $backupRow.sourceUrl $url 'Backup hint keeps its original post as the single evidence action'
Check $backupRow.monitorSourceUrl $null 'Backup hint does not add a second monitoring-site action'
Check (Get-WidgetActivityAttribution $backupRow 'en').source 'codexreset.dev' 'Backup website attribution remains visible'
Write-Output 'PASS backup-only hint retains one original action and the supplying website attribution'
