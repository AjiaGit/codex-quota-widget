$ErrorActionPreference='Stop'
# FABRICATED: portable presentation checks; WinForms geometry is checked separately.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
function Check($actual,$expected,$message){if($actual -cne $expected){throw "$message : expected [$expected], got [$actual]"}}
$now=[DateTimeOffset]::Parse('2026-10-16T06:00:00Z')
$record=[pscustomobject]@{observedFrom=$now.AddMinutes(-3).ToUnixTimeMilliseconds();detectedAt=$now.AddMinutes(-2).ToUnixTimeMilliseconds();beforePercent=20;afterPercent=80}
$older=[pscustomobject]@{observedFrom=$now.AddHours(-2).ToUnixTimeMilliseconds();detectedAt=$now.AddHours(-1).ToUnixTimeMilliseconds();beforePercent=20;afterPercent=80}
$quota=[pscustomobject]@{status='ok';recoveryHistory=[pscustomobject]@{status='ok';records=@($older,$record)}}
foreach($language in @('en','zh-CN')) {
    $view=Get-WidgetRecoveryView $quota $language $now
    Check $view.latestDetectedAt $record.detectedAt 'Newest account recovery anchors the summary'
    if($view.latestText -notmatch $(if($language -eq 'en'){'^Last quota recovery noticed:'}else{'^最近检测到额度恢复：'})){throw 'Missing localized local-recovery summary'}
    $empty=Get-WidgetRecoveryView ([pscustomobject]@{status='ok';recoveryHistory=[pscustomobject]@{status='ok';records=@()}}) $language $now
    Check $empty.latestDetectedAt $null 'Empty account has no recovery time'
    Check $empty.latestText $(if($language -eq 'en'){'Last quota recovery noticed: No records'}else{'最近检测到额度恢复：暂无记录'}) 'New account never inherits another account summary'
    $failed=Get-WidgetRecoveryView ([pscustomobject]@{status='unavailable';recoveryHistory=$quota.recoveryHistory}) $language $now
    Check $failed.latestDetectedAt $null 'Failed account reads never expose cached-account history'
    Check $failed.latestText $(if($language -eq 'en'){'Last quota recovery noticed: Unavailable'}else{'最近检测到额度恢复：暂不可用'}) 'Unavailable is not an empty history'
    Write-Output "PASS newest account summary, no-record and failure states ($language)"
    $raw=[pscustomobject]@{id='fabricated-public';kind='regular';kindKnown=$true;sourceUrl='https://example.invalid/fabricated';announcedAt=$now.AddMinutes(-1).ToString('o');certainty='unconfirmed';sourceSites=@('codex-reset.com')}
    $external=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');items=@($raw);history=@()}}
    $activity=Get-WidgetResetActivityView $quota $external $language $now
    Check $activity.latestRecoveryText $view.latestText 'Public messages cannot replace the local summary'
    $display=Get-WidgetActivityPresentation $activity.active[0] $language
    Check $display.recordLabel $(if($language -eq 'en'){'Public message · Unverified'}else{'公开消息 · 待核实'}) 'Message type and verification stage remain distinct'
    Check $display.status '' 'Repeated verification help is in the disclosure'
    if($display.extra -notmatch $(if($language -eq 'en'){'not yet clear|unclear'}else{'暂无法判断'})){throw 'Disclosure lost verification help'}
    if($display.label -notmatch 'codex-reset.com'){throw 'Collecting website attribution disappeared'}
    $activity=Get-WidgetVisibleActivityView $activity
    Check $activity.active.Count 3 'All three independent records remain available'
    Write-Output "PASS message labels, attribution and independent account records ($language)"
}
$rows=@(0..6 | ForEach-Object {[pscustomobject]@{key=('p'+$_);id=('p'+$_);kind='regular';sortAt=(100-$_)}})
$activity=[pscustomobject]@{active=@($rows[0],$rows[2],$rows[4]);history=@($rows[1],$rows[3],$rows[5],$rows[6])}
foreach($limit in @(0,3)) {
    $first=Get-WidgetVisibleActivityView $activity $limit
    Check ($first.active.id -join ',') 'p0,p1,p2' 'First page contains only the latest three'
    Check $first.nextCount 3 'Next batch is bounded to three'
    Check $first.canCollapse $false 'First page cannot collapse further'
}
$second=Get-WidgetVisibleActivityView $activity 6
Check $second.active.Count 6 'Second page appends three'
Check $second.nextCount 1 'Last batch retains one remaining record'
Check $second.canCollapse $true 'Expanded page can collapse'
Check (Get-WidgetVisibleActivityView $activity 9).active.Count 7 'Every record remains accessible'
Check (Get-WidgetVisibleActivityView $activity).active.Count 3 'Default returns to three'
Write-Output 'PASS chronological 3, 6, 7 and collapse-to-3 pagination'
