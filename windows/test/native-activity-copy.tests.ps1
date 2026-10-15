$ErrorActionPreference='Stop'
# FABRICATED DATA: portable presentation checks, not Windows desktop acceptance.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
$now=[DateTimeOffset]::Parse('2026-10-15T06:00:00Z')
$url='https://x.com/thsottiaux/status/1000000000000000701'
function Check($actual,$expected,$message){if($actual -cne $expected){throw "$message : expected [$expected], got [$actual]"}}
$record=[pscustomobject]@{id=($url+'#banked');kind='banked';sourceUrl=$url;announcedAt='2026-10-15T04:00:00Z';certainty='announced';sourceSites=@('codexreset.dev');deliveredAt='2026-10-15T05:00:00Z'}
$view=Get-WidgetActivityPresentation (ConvertTo-WidgetAnnouncementRow $record 'zh-CN' $now) 'zh-CN'
Check $view.title 'codexreset.dev 记录：重置卡已发放' 'A post URL alone is not a publisher statement'
Write-Output 'PASS a post URL cannot upgrade website completion attribution'
$record | Add-Member completionTimeBasis 'announcement'
$record | Add-Member sourceWithdrawn $true
$view=Get-WidgetActivityPresentation (ConvertTo-WidgetAnnouncementRow $record 'zh-CN' $now $true) 'zh-CN'
Check $view.title 'TIBO 表示：重置卡已发放' 'Withdrawal keeps known completion'
Check $view.missing $false 'Completed records cannot claim missing completion evidence'
if($view.status -notmatch '撤下' -or $view.status -match '是否已发放尚不明确'){throw 'Withdrawal erased known completion'}
Write-Output 'PASS removed records retain known completion and state their removal'
$record=[pscustomobject]@{id=($url+'#banked');kind='banked';sourceUrl=$url;announcedAt='2026-10-15T04:00:00Z';certainty='announced';sourceSites=@('codex-reset.com');announcementBasis='original'}
function Snapshot($row){[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@($row);history=@();stale=$false}}}
$partial=[pscustomobject]@{id=$record.id;kind='banked';sourceUrl=$url;announcedAt=$record.announcedAt;certainty='announced';sourceSites=@('codexreset.dev')}
$merged=Merge-WidgetExternalData (Snapshot $record) (Snapshot $partial)
$row=$merged.announcements.items[0]
Check ($row.sourceSites -join ',') 'codex-reset.com,codexreset.dev' 'Both contributing sites retained'
Check $row.announcementBasis 'original' 'Partial mirrors preserve original announcement provenance'
Write-Output 'PASS partial native snapshots retain display provenance'

# Execute the actual count expression used by the native main-window control.
# A stale/missing count stays unknown; only Chinese adds the reset-credit unit.
$parseErrors=$null;$tokens=$null
$uiAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $PSScriptRoot -Parent) 'Floating.ps1'),[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) {throw 'Native UI source did not parse'}
$countAssignments=@($uiAst.FindAll({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$count' -and $node.Right.Extent.Text.Contains('$value.resetCards')},$true))
Check $countAssignments.Count 1 'One main-window reset count expression'
$countExpression=[scriptblock]::Create($countAssignments[0].Extent.Text)
foreach ($case in @(
    @{language='zh-CN';number=2;valid=$true;expected='2 张'},
    @{language='zh-CN';number=0;valid=$true;expected='0 张'},
    @{language='en';number=2;valid=$true;expected='2'},
    @{language='en';number=0;valid=$true;expected='0'},
    @{language='zh-CN';number=2;valid=$false;expected='—'},
    @{language='en';number=$null;valid=$true;expected='—'}
)) {
    $script:language=$case.language;$value=[pscustomobject]@{resetCards=$case.number};$valid=$case.valid
    . $countExpression
    Check $count $case.expected 'Localized available reset count'
}
Write-Output 'PASS main-window reset counts preserve zero and unknown states with localized units'
