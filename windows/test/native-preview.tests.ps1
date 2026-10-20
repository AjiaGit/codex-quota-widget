$ErrorActionPreference='Stop'
# FABRICATED public values. Runs in Windows PowerShell; no real account or UI changes.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
function Check($actual,$expected,$message){if($actual -cne $expected){throw "$message : expected [$expected], got [$actual]"}}
$now=[DateTimeOffset]::Parse('2026-10-15T05:30:00Z')
$raw=[pscustomobject]@{id='https://x.com/thsottiaux/status/1000000000000000901#regular';sourceUrl='https://x.com/thsottiaux/status/1000000000000000901';kind='regular';announcedAt='2026-10-15T04:56:07Z';certainty='announced';announcementBasis='original';statementBasis='original';summary='Landing within the next 2 hours';scheduleText='within the next 2 hours';scheduledAt='2026-10-15T06:56:07Z';schedulePrecision='window';sourceSites=@('codex-reset.com');noticeVersion='FABRICATED-version-1'}
foreach($language in @('en','zh-CN')) {
    $row=ConvertTo-WidgetAnnouncementRow $raw $language $now
    Check $row.previewPriority $true 'Current quota preview is prioritized'
    $display=Get-WidgetActivityPresentation $row $language
    Check $display.body $raw.summary 'Original body is directly available'
    if($display.fact -notmatch $(if($language -eq 'en'){'Expected by'}else{'预计.*前'})){throw 'Estimated upper bound was presented as an exact occurrence'}
    Check $row.monitorSourceUrl $null 'Only one original-source link is offered'
    $notice=Get-WidgetAnnouncementAlertView ([pscustomobject]@{unread=@([pscustomobject]@{id=$raw.id;kind='regular';version='FABRICATED-version-1'})}) $language
    $visible=[pscustomobject]@{active=@($row);history=@()}
    Check (Get-WidgetAnnouncementReadEntries $notice $visible $true).Count 1 'Visible version can be read'
    Check (Get-WidgetAnnouncementReadEntries $notice $visible $false).Count 0 'Hidden view cannot mark read'
    $notice.entries[0].version='FABRICATED-version-2'
    Check (Get-WidgetAnnouncementReadEntries $notice $visible $true).Count 0 'Old visible content cannot clear a changed deadline'
    $newer=[pscustomobject]@{id='FABRICATED-newer';kind='regular';sortAt=$now.ToUnixTimeMilliseconds();previewPriority=$false}
    $page=Get-WidgetVisibleActivityView ([pscustomobject]@{active=@($newer,$row);history=@()})
    Check $page.active[0].id $raw.id 'Preview is ahead of a newer report'
    Write-Output "PASS direct preview body, estimated time, one source, priority and version-qualified reading ($language)"
}
Check (Test-WidgetResetPreview $raw $now.AddHours(3)) $false 'Expired preview stops priority'
Write-Output 'PASS expired previews remain historical evidence rather than a completion claim'
