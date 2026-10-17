$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$windows=Split-Path $PSScriptRoot -Parent
. (Join-Path $windows 'Native.ps1')
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $windows 'Floating.ps1'),[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Floating script failed to parse'}
$source=$ast.Extent.Text
$native=$ast.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.Contains('public static class WidgetOutsideClick')},$true)
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition $native.Value
[void][WidgetDisplay]::EnableGdiScaling()
[Windows.Forms.Application]::EnableVisualStyles()
foreach($definition in $ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]}) {Invoke-Expression $definition.Extent.Text}
$script:failures=0
function Test-Case([string]$name,[scriptblock]$testAction){try{& $testAction;Write-Output "PASS $name"}catch{$script:failures++;Write-Output "FAIL $name : $($_.Exception.Message)";Write-Output $_.ScriptStackTrace}}
function Assert-Equal($actual,$expected,[string]$reason){if($actual -cne $expected){throw "$reason. Expected [$expected], got [$actual]"}}
$now=[DateTimeOffset]::UtcNow
$quota=[pscustomobject]@{status='ok';plan='pro';updatedAt=$now.ToUnixTimeMilliseconds();resetsAt=$now.AddDays(4).ToUnixTimeSeconds();remainingPercent=74;resetCards=2;resetDetails=@([pscustomobject]@{title='FABRICATED TEST DATA';description='Virtual grant only';grantedAt=$null;expiresAt=$now.AddDays(2).ToUnixTimeSeconds()})}
Test-Case 'header follows macOS insets and fixed toolbar geometry' {
 $wide=Get-WidgetHeaderLayout 606 150 120
 Assert-Equal $wide.titleX 30 'Wide Mac inset';Assert-Equal $wide.height 60 'Mac header height'
 Assert-Equal $wide.buttons[0].y 14 'Mac toolbar vertical placement'
 Assert-Equal ($wide.buttons[1].x-$wide.buttons[0].x) 36 'Mac toolbar gap'
 $narrow=Get-WidgetHeaderLayout 404 132 145
 Assert-Equal $narrow.titleX 16 'Narrow Mac inset';Assert-Equal $narrow.height 84 'Stacked Mac header'
}
Test-Case 'embedded hero follows responsive macOS CSS dimensions' {
 foreach($width in @(404,480,606,720)) {
  $m=Get-WidgetDetailMetrics $width
  if($m.ring -lt 92 -or $m.ring -gt 112 -or $m.copyX -le $m.ring -or $m.countdownPixels -lt 24 -or $m.countdownPixels -gt 30){throw 'Hero does not follow Mac CSS clamps'}
  Assert-Equal $m.inset $(if($width -le 420){14}elseif($width -le 520){16}else{24}) 'Mac responsive page inset'
 }
}
Test-Case 'inline reset details preserve missing dates and authoritative count' {
 $view=Get-WidgetResetDetailsView $quota 'en' $now
 Assert-Equal $view.rows.Count 1 'Returned rows only'
 Assert-Equal $view.rows[0].granted 'Granted: Not provided' 'Missing grant date remains unavailable'
 if($view.note -notmatch 'authoritative'){throw 'Mac partial-list explanation missing'}
 if($view.rows[0].title -ne 'FABRICATED TEST DATA'){throw 'Virtual fixture title lost'}
}
Test-Case 'expired and failed quota cannot expose cached reset details' {
 foreach($state in @([pscustomobject]@{status='unavailable';resetCards=9;resetDetails=$quota.resetDetails},[pscustomobject]@{status='ok';updatedAt=$now.AddMinutes(-11).ToUnixTimeMilliseconds();resetsAt=$quota.resetsAt;remainingPercent=74;resetCards=9;resetDetails=$quota.resetDetails})) {
  $view=Get-WidgetResetDetailsView $state 'zh-CN' $now
  Assert-Equal $view.rows.Count 0 'No stale detail rows'
  if($view.note -notmatch '过期'){throw 'Missing stale detail explanation'}
 }
}
Test-Case 'unified records follow the Mac chronological three-row policy' {
 $rows=@(0..5 | ForEach-Object {[pscustomobject]@{key=('p'+$_);id=('p'+$_);kind='regular';sortAt=(10-$_)}})
 $activity=[pscustomobject]@{active=$rows[0..2];history=$rows[3..5]}
 $view=Get-WidgetVisibleActivityView $activity
 Assert-Equal ($view.active.key -join ',') 'p0,p1,p2' 'Current and archive share the first three'
 $alerts=[pscustomobject]@{ids=@($rows.id)}
 Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $view $true) -join ',') 'p0,p1,p2' 'Unloaded records remain unread'
 $expanded=Get-WidgetVisibleActivityView $activity 6
 Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $expanded $true) -join ',') 'p0,p1,p2,p3,p4,p5' 'Loaded record can be acknowledged'
}
 Test-Case 'public status uses the Mac cache and source freshness rules' {
 $external=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;sourceUpdatedAt=$now.ToString('o');lastFetchedAt=$now.ToUnixTimeMilliseconds();items=@();history=@()}}
 Assert-Equal (Get-WidgetPublicNoticeView $external 'en' $now).visible $false 'Fresh complete public data'
 $external.announcements.sourceUpdatedAt=$now.AddHours(-25).ToString('o')
 Assert-Equal (Get-WidgetPublicNoticeView $external 'en' $now).visible $true 'Old public data stays explicitly stale'
 $external.status='unavailable';$external.announcements.items=@([pscustomobject]@{title='FABRICATED TEST DATA'})
 $view=Get-WidgetPublicNoticeView $external 'zh-CN' $now
 Assert-Equal $view.hasCache $true 'Saved records explicitly attributed'
 Assert-Equal $view.failed $true 'Failure distinct from current data'
}
Test-Case 'public source delay, unusable data and request failure keep distinct reasons and saved records' {
 $record=[pscustomobject]@{id='https://example.invalid/FABRICATED-cache#regular';kind='regular';sourceUrl='https://example.invalid/FABRICATED-cache';announcedAt=$now.AddDays(-4).ToString('o')}
 $sourceAt=$now.AddHours(-80).ToString('o')
 $external=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='unavailable';reason='source-stale';stale=$true;sourceUpdatedAt=$sourceAt;lastFetchedAt=$now.AddHours(-80).ToUnixTimeMilliseconds();items=@();history=@($record)}}
 $delayed=Get-WidgetPublicNoticeView $external 'zh-CN' $now
 Assert-Equal $delayed.reason 'source-stale' 'Old source data is not a failed request'
 Assert-Equal $delayed.failed $false 'Do not use the request failure title'
 Assert-Equal $delayed.hasCache $true 'Saved history remains available'
 if (-not $delayed.help -or -not $delayed.sourceUpdatedText) {throw 'Source delay explanation or update time missing'}
 $external.announcements.reason='invalid-data'
 $invalid=Get-WidgetPublicNoticeView $external 'zh-CN' $now
 if ($invalid.title -eq $delayed.title) {throw 'Unusable data and source delays share a title'}
 $failed=Merge-WidgetExternalData $external $null $true
 $failure=Get-WidgetPublicNoticeView $failed 'zh-CN' $now
 Assert-Equal $failure.reason 'request-failed' 'Transport failure replaces the old reason'
 Assert-Equal $failure.failed $true 'Failure uses its own title'
 Assert-Equal $failed.announcements.history.Count 1 'Failure preserves history'
 Assert-Equal $failed.announcements.sourceUpdatedAt $sourceAt 'Failure preserves the source time'
 $external.announcements.reason=$null;$external.announcements.status='ok';$external.announcements.sourceUpdatedAt=$now.ToString('o')
 $pending=Get-WidgetPublicNoticeView $external 'zh-CN' $now
 if ($pending.title -eq $delayed.title -or $pending.help) {throw 'A fresh retained cache is described as a delayed source'}
 $external.announcements.stale=$false
 Assert-Equal (Get-WidgetPublicNoticeView $external 'en' $now).visible $false 'A fresh complete feed clears the notice'
}
Test-Case 'production announcement IDs acknowledge only the rendered service records' {
 $id='https://example.invalid/FABRICATED-announcement#banked'
 $record=[pscustomobject]@{id=$id;kind='banked';certainty='announced';announcedAt=$now.AddMinutes(-2).ToString('o');scheduledAt=$now.AddDays(1).ToString('o');sourceUrl='https://example.invalid/FABRICATED-announcement';scope='paid'}
 $row=ConvertTo-WidgetAnnouncementRow $record 'en' $now
 $alerts=Get-WidgetAnnouncementAlertView ([pscustomobject]@{unread=@([pscustomobject]@{id=$id;kind='banked'},[pscustomobject]@{id='https://example.invalid/FABRICATED-unseen#regular';kind='regular'})}) 'en'
 $view=[pscustomobject]@{active=@($row);history=@()}
 Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $view $true) -join ',') $id 'Real service ID shape must match native rendered identity'
 Assert-Equal (Get-WidgetAnnouncementReadIds $alerts $view $false).Count 0 'Hidden details leave notices unread'
}
Test-Case 'paired completion replaces its cached standalone alias and preserves publication wording' {
 $preUrl='https://x.com/thsottiaux/status/1000000000000000001';$doneUrl='https://x.com/thsottiaux/status/1000000000000000002'
 $done=[pscustomobject]@{id=($doneUrl+'#regular');kind='regular';certainty='announced';sourceUrl=$doneUrl;deliverySourceUrl=$doneUrl;announcedAt=$now.AddHours(-1).ToString('o');deliveredAt=$now.AddHours(-1).ToString('o');completionTimeBasis='announcement'}
 $paired=[pscustomobject]@{id=($preUrl+'#regular');kind='regular';certainty='announced';sourceUrl=$preUrl;deliverySourceUrl=$doneUrl;announcedAt=$now.AddHours(-2).ToString('o');deliveredAt=$done.deliveredAt;completionTimeBasis='announcement'}
 $previous=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@($done);history=@();stale=$false}}
 $incoming=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@($paired);history=@($paired);stale=$false}}
 $merged=Merge-WidgetExternalData $previous $incoming
 Assert-Equal $merged.announcements.items.Count 1 'Cached standalone completion is removed'
 Assert-Equal $merged.announcements.history.Count 0 'Active canonical row is not repeated in history'
 Assert-Equal $merged.announcements.items[0].id $paired.id 'Canonical preannouncement owns the pair'
 Assert-Equal $previous.announcements.items[0].id $done.id 'Input cache is not mutated'
 foreach($language in @('en','zh-CN')) {
  $row=ConvertTo-WidgetAnnouncementRow $merged.announcements.items[0] $language $now
  $prefix=if($language -eq 'en'){'Completion message posted'}else{'完成消息发布于'}
  if(-not $row.completedText.StartsWith($prefix)){throw 'Completion time is not explicitly the statement publication time'}
 }
 $partial=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@([pscustomobject]@{id=$paired.id;kind='regular';sourceUrl=$preUrl;certainty='announced';announcedAt=$paired.announcedAt});history=@();stale=$false}}
 $retained=Merge-WidgetExternalData $merged $partial
 Assert-Equal $retained.announcements.items[0].completionTimeBasis 'announcement' 'Partial updates preserve the time basis'
 Assert-Equal $retained.announcements.items[0].deliverySourceUrl $doneUrl 'Partial updates preserve the completion source'
}
Test-Case 'original category corrects native cached mirror rows and survives partial updates' {
 $url='https://x.com/thsottiaux/status/1000000000000000002'
 $cached=[pscustomobject]@{id=($url+'#regular');kind='regular';sourceUrl=$url;certainty='announced';announcedAt=$now.AddHours(-1).ToString('o');deliveredAt=$now.AddHours(-1).ToString('o');deliverySourceUrl=$url;completionTimeBasis='announcement'}
 $original=$cached | ConvertTo-Json -Depth 8 | ConvertFrom-Json
 $original.kind='banked';$original.id=$url+'#banked';$original | Add-Member -NotePropertyName kindBasis -NotePropertyValue 'original'
 $previous=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@($cached);history=@();stale=$false}}
 $incoming=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@($original);history=@();stale=$false}}
 $merged=Merge-WidgetExternalData $previous $incoming
 Assert-Equal $merged.announcements.items.Count 1 'Same source is not repeated under a conflicting category'
 Assert-Equal $merged.announcements.items[0].kind 'banked' 'Full original overrides the mirror category'
 Assert-Equal $merged.announcements.items[0].id ($url+'#banked') 'Canonical identity follows the corrected category'
 $retained=Merge-WidgetExternalData $merged $previous
 Assert-Equal $retained.announcements.items.Count 1 'Later partial archive does not restore the old category'
 Assert-Equal $retained.announcements.items[0].kindBasis 'original' 'Original category authority is preserved'
 Assert-Equal $retained.announcements.items[0].kind 'banked' 'Partial update stays in the original category'
 Assert-Equal $previous.announcements.items[0].kind 'regular' 'Input cache is not mutated'
 $preUrl='https://x.com/thsottiaux/status/1000000000000000001'
 $promise=[pscustomobject]@{id=($preUrl+'#regular');kind='regular';kindBasis='original';sourceUrl=$preUrl;certainty='announced';announcedAt=$now.AddHours(-2).ToString('o');deliveredAt=$cached.deliveredAt;deliverySourceUrl=$url;completionTimeBasis='announcement'}
 $pairedCache=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';items=@($promise);history=@();stale=$false}}
 $split=Merge-WidgetExternalData $pairedCache $incoming
 Assert-Equal $split.announcements.items.Count 2 'Corrected banked completion and global promise remain separate'
 $pending=@($split.announcements.items | Where-Object {$_.sourceUrl -eq $preUrl})[0]
 Assert-Equal $pending.deliveredAt $null 'Incompatible completion evidence releases the cached promise'
 Assert-Equal $pending.deliverySourceUrl $null 'Old completion source is removed'
 Assert-Equal $pending.completionTimeBasis $null 'Pending promise has no completion time basis'
}
$start=$source.IndexOf('$script:data = $null');$end=$source.IndexOf('function New-Color',$start)
Invoke-Expression $source.Substring($start,$end-$start)
$script:creditsExpanded=$false;$script:sourcesExpanded=$false;$script:creditRenderKey='';$script:creditRows=@();$script:recordExpanded=@{};$script:language='zh-CN';$script:languageSetting='auto';$script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;sourceUpdatedAt=$now.ToString('o');items=@();history=@()}}
$script:data=$quota;$script:noticeView=[pscustomobject]@{hasUnread=$false;ids=@()};$script:automaticDetailHeight=$false
$script:form=[Windows.Forms.Form]::new();$form.Text='FABRICATED TEST DATA - macOS parity regressions';$form.ClientSize=[Drawing.Size]::new(606,700);$form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::None;$form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
$uiStart=$source.IndexOf('$title = New-Label');$uiEnd=$source.IndexOf('function Set-ControlBox',$uiStart)
Invoke-Expression $source.Substring($uiStart,$uiEnd-$uiStart)
try {
 Set-Theme;Show-Quota;$form.Show();[Windows.Forms.Application]::DoEvents();Show-Quota

 Test-Case 'unchanged detail and compact geometry does not replace the rounded window region' {
  foreach($mode in @('Detail','Compact')) {
   $script:mode=$mode;Update-ResponsiveLayout;Set-RoundedRegion;$region=$form.Region
   for($i=0;$i -lt 5;$i++){Update-ResponsiveLayout}
   if(-not [object]::ReferenceEquals($region,$form.Region)){throw 'A quota refresh recreates the native region despite identical dimensions'}
  }
  $script:mode='Detail';Update-ResponsiveLayout
 }
 Test-Case 'auto-height displays the default content and expanded sources when the screen fits' {
  $oldSize=$form.ClientSize;$oldAuto=$script:automaticDetailHeight
  try {
   $script:automaticDetailHeight=$true;$script:creditsExpanded=$false;$script:activityLimit=3;$script:sourcesExpanded=$false
   foreach($expanded in @($false,$true)) {
    $script:sourcesExpanded=$expanded;$form.ClientSize=[Drawing.Size]::new(606,390);Show-Quota;Update-ResponsiveLayout
    $screen=[Windows.Forms.Screen]::FromControl($form).WorkingArea
    $header=Get-WidgetHeaderLayout $form.Width ([Windows.Forms.TextRenderer]::MeasureText($title.Text,$title.Font).Width+6) ([Windows.Forms.TextRenderer]::MeasureText($status.Text,$status.Font).Width+6)
    $wanted=Get-WidgetDetailFittedFrame $form.Bounds ($content.Height+8) $header.height $screen
    Assert-Equal $form.Bounds $wanted 'Default and inline content must fit'
    if($content.Height+8 -le $body.ClientSize.Height -and $body.VerticalScroll.Visible){throw 'Scrollbar remains although all content fits'}
    if(-not $screen.Contains($form.Bounds)){throw 'Fitted window leaves the working screen'}
   }
  }finally{$script:automaticDetailHeight=$oldAuto;$script:sourcesExpanded=$false;$form.ClientSize=$oldSize;Show-Quota}
 }
 Test-Case 'reopening details starts at the complete hero rather than a saved partial scroll' {
  $oldSize=$form.ClientSize;$oldAuto=$script:automaticDetailHeight;$oldCredits=$script:creditsExpanded
  try {
   $script:automaticDetailHeight=$false;$script:creditsExpanded=$true;$form.ClientSize=[Drawing.Size]::new(404,390);Show-Quota
   $body.AutoScrollPosition=[Drawing.Point]::new(0,70)
   if($body.AutoScrollPosition.Y -ge 0){throw 'Fabricated content did not require scrolling'}
   $node=$ast.Find({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$form' -and $n.Member.Value -eq 'Add_VisibleChanged'},$true)
   function Update-OutsideClickMonitor {}
   function Start-AnnouncementRead {}
   & $node.Arguments[0].ScriptBlock.GetScriptBlock()
   Assert-Equal $body.AutoScrollPosition.Y 0 'Reopened hero starts at the top'
   Assert-Equal $content.Top 0 'No clipped hero after reopen'
  }finally{$script:automaticDetailHeight=$oldAuto;$script:creditsExpanded=$oldCredits;$form.ClientSize=$oldSize;Show-Quota}
 }


 Test-Case 'long inline details scroll without drifting during refresh and shrink back to complete content' {
  $oldData=$script:data;$oldSize=$form.ClientSize;$oldAuto=$script:automaticDetailHeight;$oldCredits=$script:creditsExpanded
  try {
   $rows=@(1..30 | ForEach-Object {[pscustomobject]@{title=('FABRICATED TEST DATA '+$_);description=('Virtual explanation '*8);grantedAt=$null;expiresAt=$null}})
   $script:data=[pscustomobject]@{status='ok';plan='pro';updatedAt=$now.ToUnixTimeMilliseconds();remainingPercent=74;resetsAt=$now.AddDays(4).ToUnixTimeSeconds();resetCards=32;resetDetails=$rows}
   $script:automaticDetailHeight=$true;$script:creditsExpanded=$true;$form.ClientSize=[Drawing.Size]::new(606,390);Show-Quota
   $screen=[Windows.Forms.Screen]::FromControl($form).WorkingArea
   if(-not $screen.Contains($form.Bounds) -or -not $body.VerticalScroll.Visible){throw 'Long disclosures must remain accessible within the screen'}
   $body.AutoScrollPosition=[Drawing.Point]::new(0,140);$offset=$body.AutoScrollPosition.Y
   for($i=0;$i -lt 5;$i++) {
    Update-ResponsiveLayout
    Assert-Equal $body.AutoScrollPosition.Y $offset 'Refresh must preserve the current reading position'
    Assert-Equal $content.Top $offset 'Content uses the same scroll coordinate space'
    Assert-Equal $content.Left ((Get-WidgetDetailMetrics $form.Width).inset-7+$body.AutoScrollPosition.X) 'No horizontal origin drift'
    Assert-Equal $body.HorizontalScroll.Visible $false 'No horizontal scrollbar'
   }
   $script:creditsExpanded=$false;Show-Quota;Update-ResponsiveLayout
   Assert-Equal $body.AutoScrollPosition.Y 0 'Collapsed short content returns to the complete hero'
   Assert-Equal $content.Top 0 'Shrinking content leaves no clipped hero'
   Assert-Equal $body.VerticalScroll.Visible $false 'Short content has no scrollbar'
   $script:automaticDetailHeight=$false;$form.ClientSize=[Drawing.Size]::new(606,390);Update-ResponsiveLayout
   Assert-Equal $form.ClientSize.Height 390 'A deliberate new manual height remains unchanged'
  }finally{$script:data=$oldData;$script:automaticDetailHeight=$oldAuto;$script:creditsExpanded=$oldCredits;$form.ClientSize=$oldSize;Show-Quota}
 }

Test-Case 'completed public request is retained until the UI timer consumes it' {
 $script:externalTask=[Threading.Tasks.Task]::FromResult([int]42);$pending=$script:externalTask
 try {
  Start-ExternalRequest
  if(-not [object]::ReferenceEquals($pending,$script:externalTask)){throw 'Completed public response was overwritten before consumption'}
  Start-PublicRetry
  if(-not [object]::ReferenceEquals($pending,$script:externalTask)){throw 'Completed retry response was overwritten before consumption'}
 }finally{$script:externalTask=$null}
}
 Test-Case 'reset details open inside the existing window without another form' {
  $before=[Windows.Forms.Application]::OpenForms.Count
  Show-ResetDetails
  Assert-Equal ([Windows.Forms.Application]::OpenForms.Count) $before 'No separate details window'
  Assert-Equal $script:creditsExpanded $true 'Details expanded in place'
  Assert-Equal $script:mode 'Detail' 'Details do not collapse the widget'
  if(-not $creditDetailsPanel -or $creditDetailsPanel.Parent -ne $creditsPanel){throw 'Details not in the credits section'}
  if($creditsPanel.Height -le $cards.Bottom){throw 'Inline content did not reflow'}
 }
 Test-Case 'inline reset details collapse and reopen repeatedly without new windows' {
  for($i=0;$i -lt 8;$i++){Toggle-ResetDetails;Assert-Equal $script:creditsExpanded $false 'Collapsed';Toggle-ResetDetails;Assert-Equal $script:creditsExpanded $true 'Reopened'}
  Assert-Equal ([Windows.Forms.Application]::OpenForms.Count) 1 'No detail forms leaked'
 }
 Test-Case 'all sections reflow at supported widths without horizontal overflow' {
  foreach($lang in @('en','zh-CN')) {
   $script:language=$lang;$script:announcementRenderKey='';$script:creditRenderKey='';Show-Quota
   foreach($width in @(404,480,606,720)) {
    $form.ClientSize=[Drawing.Size]::new($width,640);Update-ResponsiveLayout
    $y=0
    foreach($name in Get-WidgetDetailSectionOrder $false){$panel=$script:sectionPanels[$name];if($panel.Top -lt $y -or $panel.Right -gt $content.Width){throw "Section overlap or overflow: $name"};$y=$panel.Bottom}
    if($cadence.Bottom -gt $footerPanel.Height -or $countdown.Right -gt $heroPanel.Width){throw 'Footer or hero clipped'}
   }
  }
 }
 Test-Case 'sources collapse independently and retain two complete GDI website links' {
  Assert-Equal $script:sourcesExpanded $false 'Sources initially collapsed'
  Toggle-DataSources;Assert-Equal $script:sourcesExpanded $true 'Sources opened'
  foreach($link in $script:attributionSiteLinks){if($link.UseCompatibleTextRendering -or $link.Links.Count -ne 1 -or $link.Links[0].Length -ne $link.Text.Length){throw 'Link GDI text fix regressed'}}
  Toggle-DataSources;Assert-Equal $script:sourcesExpanded $false 'Sources closed'
 }
 Test-Case 'missing optional text cannot mask dates or activity content' {
  $record=[pscustomobject]@{title='FABRICATED TEST DATA';description='';granted='Granted: Not provided';expires='Expires: Not provided'}
  $control=New-ResetCreditControl $record
  try {if($control.Tag.description.Visible){throw 'Empty description still paints an opaque label over the grant date'}}finally{$control.Dispose()}
  $row=[pscustomobject]@{key='FABRICATED-empty';kind='regular';phase='announced';explicit=$true;scopeText='';summary='';retentionText=''}
  $control=New-AnnouncementControl $row
  try {if($control.Tag.fact.Visible -or $control.Tag.status.Visible){throw 'Empty activity labels still paint at skipped default positions'}}finally{$control.Dispose()}
  $row.phase='unconfirmed';$row.explicit=$false;$row.summary='FABRICATED public body shown without expanding'
  $control=New-AnnouncementControl $row
  try {
   Assert-Equal $control.Tag.fact.Visible $false 'An absent date/fact remains hidden'
   Assert-Equal $control.Tag.status.Visible $false 'An absent status remains hidden'
   Assert-Equal $control.Tag.more $null 'Public body does not require an explanation disclosure'
   if ($null -eq $control.Tag.body -or $control.Tag.body.Text -cne $row.summary) {throw 'Public body is not directly available'}
   if ($control.Tag.label.Text -notmatch [regex]::Escape((T 'categoryUnverifiedShort'))) {throw 'Unverified public message lost its visible category'}
  }finally{$control.Dispose()}
 }
 Test-Case 'local recovery summary stays in the hero in both languages and cannot inherit public messages' {
  $oldData=$script:data;$oldLanguage=$script:languageSetting;$oldSize=$form.ClientSize;$oldAuto=$script:automaticDetailHeight
  # Set-Language updates native menu controls as well as the visible labels.
  # Build the real menu fixture before using the production language path.
  $menuStart=$source.IndexOf('$menu = New-Object System.Windows.Forms.ContextMenu')
  $menuEnd=$source.IndexOf('$form.ContextMenu = $menu',$menuStart)
  Invoke-Expression $source.Substring($menuStart,$menuEnd-$menuStart)
  try {
   $script:automaticDetailHeight=$false
   $recovery=[pscustomobject]@{observedFrom=$now.AddMinutes(-3).ToUnixTimeMilliseconds();detectedAt=$now.AddMinutes(-2).ToUnixTimeMilliseconds();beforePercent=20;afterPercent=80}
   $script:data=[pscustomobject]@{status='ok';plan='pro';updatedAt=$now.ToUnixTimeMilliseconds();resetsAt=$now.AddDays(4).ToUnixTimeSeconds();remainingPercent=74;resetCards=2;recoveryHistory=[pscustomobject]@{status='ok';records=@($recovery)}}
   foreach ($lang in @('en','zh-CN')) {
    $script:languageSetting=$lang;Set-Language
    foreach($width in @(404,606)) {
     $form.ClientSize=[Drawing.Size]::new($width,700);Show-Quota;Update-ResponsiveLayout
     if(-not $latestRecovery.Visible -or $latestRecovery.Parent -ne $heroPanel){throw 'Recovery summary is missing from the quota area'}
     if($latestRecovery.Text -notmatch $(if($lang -eq 'en'){'^Last quota recovery noticed:'}else{'^最近检测到额度恢复：'})){throw 'Recovery summary is untranslated'}
     if($latestRecovery.Top -lt [Math]::Max($ring.Bottom,$reset.Bottom) -or $latestRecovery.Right -gt $heroPanel.Width -or $latestRecovery.Bottom -gt $heroPanel.Height){throw 'Recovery summary overlaps the hero or is clipped'}
     $before=$latestRecovery.Text;Show-External
     Assert-Equal $latestRecovery.Text $before 'External refresh cannot change the account recovery time'
    }
   }
   $script:data=[pscustomobject]@{status='unavailable';recoveryHistory=$script:data.recoveryHistory};Show-Quota
   if($latestRecovery.Text -match [regex]::Escape((Format-WidgetCompactDate $now.AddMinutes(-2) $script:language))){throw 'Failed account query exposed an old account recovery time'}
  }finally{$script:data=$oldData;$script:languageSetting=$oldLanguage;$script:automaticDetailHeight=$oldAuto;$form.ClientSize=$oldSize;Set-Language;Show-Quota;$menu.Dispose()}
 }
 Test-Case 'the new recovery label participates in the production detail drag registration' {
  $oldDrag=$drag;$script:dragTestOrigins=@()
  $drag=[Windows.Forms.MouseEventHandler]{param($sender,$event);$script:dragTestOrigins+=,$sender}
  $binding=@($ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.ForEachStatementAst] -and $_.Extent.Text.Contains('.Add_MouseDown($drag)')})
  Assert-Equal $binding.Count 1 'One production detail drag registration'
  Invoke-Expression $binding[0].Extent.Text
  try {
   $raise=[Windows.Forms.Control].GetMethod('OnMouseDown',([Reflection.BindingFlags]::Instance -bor [Reflection.BindingFlags]::NonPublic))
   [void]$raise.Invoke($latestRecovery,@([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,1,1,0)))
   Assert-Equal $script:dragTestOrigins.Count 1 'Dragging from the new label reaches the registered handler'
   if(-not [object]::ReferenceEquals($script:dragTestOrigins[0],$latestRecovery)){throw 'Drag origin is not the recovery label'}
  }finally{Invoke-Expression ($binding[0].Extent.Text.Replace('.Add_MouseDown($drag)','.Remove_MouseDown($drag)'));$drag=$oldDrag;Remove-Variable dragTestOrigins -Scope Script -ErrorAction SilentlyContinue}
 }
 Test-Case 'recent recovery disclosure retains the previous observation time' {
  $state=[pscustomobject]@{status='ok';recoveryHistory=[pscustomobject]@{status='ok';records=@([pscustomobject]@{beforePercent=39;afterPercent=74;observedFrom=$now.AddMinutes(-3).ToUnixTimeMilliseconds();detectedAt=$now.AddMinutes(-2).ToUnixTimeMilliseconds()})}}
  $view=Get-WidgetResetActivityView $state $script:externalData 'en' $now
  $presentation=Get-WidgetActivityPresentation $view.active[0] 'en'
  if($presentation.extra -notmatch 'Previous reading:'){throw 'Recent recovery loses its previous observation in About this record'}
 }
 Test-Case 'detail transition lands on the final hero geometry without a jump' {
  $oldBorder=$form.FormBorderStyle;$oldSize=$form.ClientSize
  try {
   $form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
   foreach($width in @(404,606,720)) {
    $script:mode='Compact';$script:animating=$false;$script:detailSize=[Drawing.Size]::new($width,640);$script:layoutPlus=$false
    $script:modePositions=@{Compact=$null;Detail=$null}
    Start-ModeTransition 'Detail'
    $point=$form.PointToClient($ring.Parent.PointToScreen($ring.Location))
    $ringSize=if($width -le 420){92}elseif($width -le 520){100}else{112}
    $inset=if($width -le 420){14}elseif($width -le 520){16}else{24}
    $header=$body.Top
    Assert-Equal $point.X $inset 'Final hero keeps the accepted Mac inset'
    Assert-Equal $point.Y ($header+10) 'Final hero follows the header'
    Assert-Equal $ring.Width $ringSize 'Final hero ring stays responsive'
   }
  }finally{foreach($control in $script:detailControls){$control.Visible=$true};$script:animating=$false;$script:mode='Detail';$form.FormBorderStyle=$oldBorder;$form.ClientSize=$oldSize;Update-ResponsiveLayout}
 }
 Test-Case 'Plus five-hour content stays readable at narrow and wide widths in both languages' {
  $old=$script:data
  try {
   $plus=[pscustomobject]@{status='ok';plan='plus';updatedAt=$now.ToUnixTimeMilliseconds();resetsAt=$now.AddDays(4).ToUnixTimeSeconds();remainingPercent=74;resetCards=2;resetDetails=$quota.resetDetails;fiveHour=[pscustomobject]@{remainingPercent=32;resetsAt=$now.AddHours(3).ToUnixTimeSeconds()}}
   foreach($lang in @('en','zh-CN')) {
    $script:language=$lang;$script:data=$plus;Show-Quota
    foreach($width in @(404,480,526,606,720)) {
     $form.ClientSize=[Drawing.Size]::new($width,640);Update-ResponsiveLayout
     foreach($label in @($fiveTitle,$fiveValue,$fiveReset)) {
      if($label.Width -lt 20 -or $label.Right -gt $fivePanel.Width -or $label.Bottom -gt $fivePanel.Height){throw 'Five-hour text is clipped or narrowed beyond readability'}
     }
     if($fiveTitle.Bounds.IntersectsWith($fiveValue.Bounds) -or $fiveTitle.Bounds.IntersectsWith($fiveReset.Bounds) -or $fiveValue.Bounds.IntersectsWith($fiveReset.Bounds)){throw 'Five-hour texts overlap'}
     if($width -gt 520 -and $fiveReset.Top -ne $fiveTitle.Top){throw 'Wide five-hour row does not follow the Mac inline layout'}
    }
   }
  }finally{$script:data=$old;Show-Quota}
 }
 Test-Case 'long grant descriptions and expanded activity facts cannot overlap subsequent content' {
  $long=('FABRICATED TEST DATA long record explanation ' * 12)
  foreach($width in @(404,606)) {
   $form.ClientSize=[Drawing.Size]::new($width,640);Update-ResponsiveLayout
   $record=[pscustomobject]@{title=$long;description=$long;granted='Granted: Not provided';expires='Expires: Not provided'}
   $grant=New-ResetCreditControl $record;$oldRows=$script:creditRows;$script:creditRows=@($grant)
   try {
    [void](Layout-ResetCreditRows $creditRowsPanel.Width);$bottom=0
    foreach($control in @($grant.Tag.title,$grant.Tag.description,$grant.Tag.granted,$grant.Tag.expires)){if($control.Top -lt $bottom -or $control.Right -gt $grant.Width){throw 'Long grant text overlap'};$bottom=$control.Bottom}
    if($bottom -gt $grant.Height){throw 'Grant row clips its final date'}
   }finally{$script:creditRows=$oldRows;$grant.Dispose()}
   $item=[pscustomobject]@{id='FABRICATED-long';kind='regular';certainty='announced';announcedAt=$now.AddDays(-1).ToString('o');scheduledAt=$now.AddDays(1).ToString('o');sourceUrl='https://example.invalid/FABRICATED';summary=$long;scope='paid'}
   $row=ConvertTo-WidgetAnnouncementRow $item $script:language $now;$script:recordExpanded[$row.key]=$true
   $control=New-AnnouncementControl $row;$holder=[Windows.Forms.Panel]::new();$holder.Controls.Add($control)
   try {
    [void](Layout-AnnouncementRows $holder @($control) $content.Width)
    if($control.Tag.extraPanel.Bottom -gt $control.Height -or $control.Tag.extraPanel.Top -lt $control.Tag.more.Bottom){throw 'Long expanded activity details overlap or clip'}
   }finally{$holder.Dispose();$script:recordExpanded.Remove($row.key)}
  }
 }
 Test-Case 'stale or invalid Plus readings cannot expose cached reset times in the rendered row' {
  $old=$script:data
  try {
   foreach($fixture in @(
    @{age=11;percent=32;hours=3},@{age=0;percent=101;hours=3},@{age=0;percent=32;hours=-1}
   )) {
    $script:data=[pscustomobject]@{status='ok';plan='plus';updatedAt=$now.AddMinutes(-$fixture.age).ToUnixTimeMilliseconds();resetsAt=$now.AddDays(4).ToUnixTimeSeconds();remainingPercent=74;resetCards=2;fiveHour=[pscustomobject]@{remainingPercent=$fixture.percent;resetsAt=$now.AddHours($fixture.hours).ToUnixTimeSeconds()}}
    Show-Quota
    Assert-Equal $fiveReset.Text (T 'resetUnknown') 'Invalid five-hour reset time stays unavailable'
    Assert-Equal $fiveValue.Text (T 'unavailable') 'Invalid five-hour percentage stays unavailable'
   }
  }finally{$script:data=$old;Show-Quota}
 }
 Test-Case 'unified rows remain displayed after a hidden-window refresh and reopening' {
  $oldExternal=$script:externalData
  try {
   $script:activityLimit=3
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');stale=$false;items=@();history=@()}}
   foreach($i in @(1,2)) {
    $script:externalData.announcements.items+=,[pscustomobject]@{id=('https://example.invalid/FABRICATED-hidden-'+$i+'#regular');kind='regular';certainty='announced';announcedAt=$now.AddMinutes(-$i).ToString('o');deliveredAt=$now.AddMinutes(-$i).ToString('o');sourceUrl=('https://example.invalid/FABRICATED-hidden-'+$i);scope='paid'}
   }
   Show-External;$form.Hide();Show-External;$form.Show()
   Assert-Equal $script:announcementRows.Count 2 'Both records stay in one list'
   $renderedIds=@($script:announcementRows | ForEach-Object {$_.Tag.key})
   foreach($record in $script:visibleActivityView.active){if($record.key -notin $renderedIds){throw 'Read view includes an undisplayed record'}}
  }finally{$script:externalData=$oldExternal;$script:activityLimit=3;$script:announcementRenderKey='';$form.Show();Show-External}
 }
 Test-Case 'loaded activity restores the user anchor when the remaining content fits' {
  $oldExternal=$script:externalData;$oldPosition=$script:modePositions;$oldPath=$script:positionPath;$oldAuto=$script:automaticDetailHeight;$oldBounds=$form.Bounds
  $temp=Join-Path ([IO.Path]::GetTempPath()) ('widget-anchor-'+[guid]::NewGuid().ToString('N')+'.json')
  try {
   $screen=[Windows.Forms.Screen]::AllScreens[-1].WorkingArea
   $anchor=[pscustomobject]@{x=$screen.Left+55;y=$screen.Top+80}
   $script:positionPath=$temp;$script:modePositions=@{Detail=$anchor;Compact=[pscustomobject]@{x=$screen.Left+10;y=$screen.Top+100}}
   $script:automaticDetailHeight=$true;$script:activityLimit=3;$script:creditsExpanded=$false;$script:sourcesExpanded=$false
   $form.Bounds=[Drawing.Rectangle]::new($anchor.x,$anchor.y,644,700)
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');stale=$false;items=@();history=@()}}
   Show-External
   Assert-Equal $form.Top $anchor.y 'Empty view starts at the user anchor'
   foreach($i in 1..50){$script:externalData.announcements.history+=,[pscustomobject]@{id=('https://example.invalid/FABRICATED-anchor-'+$i+'#regular');kind='regular';sourceUrl='https://example.invalid/FABRICATED';certainty='announced';announcedAt=$now.AddDays(-$i).ToString('o');deliveredAt=$now.AddDays(-$i).ToString('o')}}
   Show-External
   Show-External
   while($script:visibleActivityView.nextCount -gt 0){$activityMore.PerformClick()}
   Assert-Equal $form.Top $screen.Top 'Long history temporarily fits the full screen'
   Save-WindowPosition
   Assert-Equal (Read-WidgetJson $temp).detailY $anchor.y 'Temporary screen fitting must not overwrite the user anchor'
   $activityLess.PerformClick()
   Assert-Equal $script:announcementRows.Count 3 'Collapse returns to the first page'
   $script:externalData.announcements.history=@();Show-External
   Assert-Equal $form.Top $anchor.y 'Fitting content returns to the user anchor'
   Save-WindowPosition
   Assert-Equal (Get-WidgetModePosition (Read-WidgetJson $temp) 'Detail').y $anchor.y 'Restart keeps the original anchor'
  }finally {
   $script:externalData=$oldExternal;$script:modePositions=$oldPosition;$script:positionPath=$oldPath;$script:automaticDetailHeight=$oldAuto;$script:activityLimit=3;$form.Bounds=$oldBounds
   if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force};Show-External
  }
 }
 Test-Case 'unified pagination materializes only loaded rows and reuses unchanged native controls' {
  $oldExternal=$script:externalData
  try {
   $script:activityLimit=3;$script:announcementRenderKey=''
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');stale=$false;items=@();history=@()}}
   foreach($i in 1..50){$script:externalData.announcements.history+=,[pscustomobject]@{id=('https://example.invalid/FABRICATED-lazy-'+$i+'#regular');kind='regular';sourceUrl='https://example.invalid/FABRICATED';certainty='announced';announcedAt=$now.AddDays(-$i).ToString('o');deliveredAt=$now.AddDays(-$i).ToString('o')}}
   Show-External
   Assert-Equal $activityRowsPanel.Controls.Count 3 'First page does not create fifty sets of native controls'
   Show-External
   Assert-Equal $script:announcementRows.Count 3 'History initially creates only three recent records'
   $first=$script:announcementRows[0];$activityMore.PerformClick()
   Assert-Equal $script:announcementRows.Count 6 'More history appends three records'
   if(-not [object]::ReferenceEquals($first,$script:announcementRows[0])){throw 'Appending history rebuilt previously shown controls'}
   while($script:visibleActivityView.nextCount -gt 0){$activityMore.PerformClick()}
   Assert-Equal $script:announcementRows.Count 50 'Every stored record is still accessible in batches'
   Assert-Equal $script:visibleActivityView.nextCount 0 'No more action at the end'
   $activityLess.PerformClick()
   Assert-Equal $script:announcementRows.Count 3 'Reopening history starts with three records again'
   $first=$script:announcementRows[0];Show-External
   if(-not [object]::ReferenceEquals($first,$script:announcementRows[0])){throw 'An unchanged refresh rebuilt the history controls'}
  }finally{$script:externalData=$oldExternal;$script:activityLimit=3;$script:announcementRenderKey='';Show-External}
 }
 Test-Case 'unchanged theme checks do not invalidate the visible native text tree' {
  Set-Theme
  $script:themeInvalidations=0
  $handler=[Windows.Forms.InvalidateEventHandler]{$script:themeInvalidations++}
  $title.Add_Invalidated($handler)
  try {Set-Theme;Assert-Equal $script:themeInvalidations 0 'Unchanged theme must not repaint every label on each minute'}finally{$title.Remove_Invalidated($handler)}
 }

 Test-Case 'numeric tray badge uses large readable glyphs without a quota ring' {
  $oldTray=$script:tray;$oldRemaining=$script:remaining;$oldKey=$script:trayIconKey;$oldIcon=$script:ownedTrayIcon
  $script:tray=[Windows.Forms.NotifyIcon]::new();$script:ownedTrayIcon=$null
  try {
   foreach($value in @(76,100,0)) {
    $script:remaining=$value;$script:trayIconKey='';Set-Tray-QuotaIcon
    $bitmap=$script:ownedTrayIcon.ToBitmap()
    try {
     $accentPixels=0;$top=32;$bottom=-1
     for($y=0;$y -lt 32;$y++){for($x=0;$x -lt 32;$x++){
      $pixel=$bitmap.GetPixel($x,$y)
      if($pixel.A -gt 0 -and $pixel.G -gt $pixel.R+35 -and $pixel.G -gt $pixel.B+20){$accentPixels++}
      if($pixel.A -gt 100){$top=[Math]::Min($top,$y);$bottom=[Math]::Max($bottom,$y)}
     }}
     Assert-Equal $accentPixels 0 'Tray has no green ring crowding the number'
     if($bottom-$top+1 -lt $(if($value -eq 100){13}else{15})){throw ('Numeric tray glyph is too small: '+$value+' height '+($bottom-$top+1))}
     if($script:tray.Text -notmatch [string]$value){throw 'Tooltip loses the authoritative percentage'}
    }finally{$bitmap.Dispose()}
   }
  }finally{if($script:ownedTrayIcon){$script:ownedTrayIcon.Dispose()};$script:tray.Dispose();$script:tray=$oldTray;$script:remaining=$oldRemaining;$script:trayIconKey=$oldKey;$script:ownedTrayIcon=$oldIcon}
 }

 Test-Case 'numeric tray contrast follows the taskbar independently of light or dark apps' {
  # FABRICATED theme settings: do not change the real registry or taskbar.
  $oldTray=$script:tray;$oldRemaining=$script:remaining;$oldKey=$script:trayIconKey;$oldIcon=$script:ownedTrayIcon;$oldColors=$script:colors
  $existingReader=Get-Item Function:\Get-ItemProperty -ErrorAction SilentlyContinue
  $existingReaderScript=if($existingReader){$existingReader.ScriptBlock}else{$null}
  function script:Get-ItemProperty {
   [CmdletBinding()]param([string]$Path,[string]$Name)
   if($Path -ne 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -or $Name -ne 'SystemUsesLightTheme'){throw 'Unexpected theme registry query'}
   [pscustomobject]@{SystemUsesLightTheme=$script:fixtureSystemLight}
  }
  $script:tray=[Windows.Forms.NotifyIcon]::new();$script:ownedTrayIcon=$null
  try {
   foreach($appColor in @([Drawing.Color]::FromArgb(23,32,45),[Drawing.Color]::FromArgb(243,245,247))) {
    $script:colors=@{text=$appColor;accent=[Drawing.Color]::FromArgb(28,168,135)}
    $script:remaining=76;$script:trayIconKey=''
    foreach($systemLight in @(0,1,0)) {
     $script:fixtureSystemLight=$systemLight;Set-Tray-QuotaIcon
     $bitmap=$script:ownedTrayIcon.ToBitmap()
     try {
      $matching=0
      for($y=0;$y -lt 32;$y++){for($x=0;$x -lt 32;$x++){
       $pixel=$bitmap.GetPixel($x,$y)
       if($pixel.A -gt 200 -and $(if($systemLight -eq 1){$pixel.R -lt 80 -and $pixel.G -lt 80 -and $pixel.B -lt 80}else{$pixel.R -gt 190 -and $pixel.G -gt 190 -and $pixel.B -gt 190})){$matching++}
      }}
      if($matching -lt 20){throw ('Tray digits lack contrast for taskbar light='+$systemLight+' app foreground='+$appColor+'; matching pixels='+$matching)}
     }finally{$bitmap.Dispose()}
    }
   }
  }finally{
   if($script:ownedTrayIcon){$script:ownedTrayIcon.Dispose()};$script:tray.Dispose()
   $script:tray=$oldTray;$script:remaining=$oldRemaining;$script:trayIconKey=$oldKey;$script:ownedTrayIcon=$oldIcon;$script:colors=$oldColors
   Remove-Item Function:\Get-ItemProperty -ErrorAction SilentlyContinue
   if($existingReaderScript){Set-Item Function:\Get-ItemProperty $existingReaderScript}
   Remove-Variable fixtureSystemLight -Scope Script -ErrorAction SilentlyContinue
  }
 }

 Test-Case 'an unchanged unavailable quota still refreshes taskbar-only theme changes' {
  $oldTray=$script:tray;$oldRemaining=$script:remaining;$oldKey=$script:trayIconKey;$oldIcon=$script:ownedTrayIcon;$oldColors=$script:colors
  $oldData=$script:data;$oldMessage=$script:message
  $existingReader=Get-Item Function:\Get-ItemProperty -ErrorAction SilentlyContinue
  $existingReaderScript=if($existingReader){$existingReader.ScriptBlock}else{$null}
  function script:Get-ItemProperty {
   [CmdletBinding()]param([string]$Path,[string]$Name)
   if($Path -ne 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -or $Name -ne 'SystemUsesLightTheme'){throw 'Unexpected theme registry query'}
   [pscustomobject]@{SystemUsesLightTheme=$script:fixtureSystemLight}
  }
  $script:tray=[Windows.Forms.NotifyIcon]::new();$script:ownedTrayIcon=$null
  try {
   $script:colors=$oldColors.Clone();$script:colors.text=[Drawing.Color]::FromArgb(243,245,247)
   $script:data=[pscustomobject]@{status='unavailable'};$script:message='FABRICATED unavailable quota'
   $script:fixtureSystemLight=0;$script:trayIconKey='';$script:quotaRenderKey=''
   Show-Quota;Show-Quota
   $key=$script:quotaRenderKey;$darkIcon=$script:ownedTrayIcon
   $script:fixtureSystemLight=1;Show-Quota
   Assert-Equal $script:quotaRenderKey $key 'The displayed quota remains unchanged'
   if([object]::ReferenceEquals($darkIcon,$script:ownedTrayIcon)){throw 'Taskbar-only theme change left the cached unavailable tray icon unchanged'}
  }finally{
   if($script:ownedTrayIcon){$script:ownedTrayIcon.Dispose()};$script:tray.Dispose()
   $script:tray=$oldTray;$script:remaining=$oldRemaining;$script:trayIconKey=$oldKey;$script:ownedTrayIcon=$oldIcon;$script:colors=$oldColors
   $script:data=$oldData;$script:message=$oldMessage;$script:quotaRenderKey=''
   Remove-Item Function:\Get-ItemProperty -ErrorAction SilentlyContinue
   if($existingReaderScript){Set-Item Function:\Get-ItemProperty $existingReaderScript}
   Remove-Variable fixtureSystemLight -Scope Script -ErrorAction SilentlyContinue
   Show-Quota
  }
 }

 Test-Case 'current and archived rows share one native list without old disclosure entries' {
  $oldExternal=$script:externalData
  try {
   $script:activityLimit=3;$script:announcementRenderKey=''
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');stale=$false;history=@();items=@()}}
   foreach($i in 1..8){
    $row=[pscustomobject]@{id=('https://example.invalid/FABRICATED-unified-'+$i+'#regular');kind='regular';sourceUrl=('https://example.invalid/FABRICATED-unified-'+$i);certainty='announced';announcedAt=$now.AddHours(-$i).ToString('o');deliveredAt=$now.AddHours(-$i).ToString('o')}
    if($i -le 2){$script:externalData.announcements.items+=,$row}else{$script:externalData.announcements.history+=,$row}
   }
   Show-External
   Assert-Equal $script:announcementRows.Count 3 'First three records share the list'
   Assert-Equal $activityMore.Visible $true 'More is available'
   Assert-Equal $form.Controls.Find('earlier-updates-toggle',$true).Length 0 'No earlier entry'
   Assert-Equal $form.Controls.Find('announcement-history-toggle',$true).Length 0 'No separate history entry'
   $activityMore.PerformClick()
   Assert-Equal $script:announcementRows.Count 6 'Next batch appends three records'
   Assert-Equal $activityMore.Visible $true 'More remains available for the final batch'
   $activityMore.PerformClick()
   Assert-Equal $script:announcementRows.Count 8 'Final batch loads the remaining records'
   Assert-Equal $activityMore.Visible $false 'More hides at the end'
  }finally{$script:externalData=$oldExternal;$script:activityLimit=3;$script:announcementRenderKey='';Show-External}
 }
 Test-Case 'clicking the detail drag surface without moving preserves a temporary-fit anchor' {
  $oldPositions=$script:modePositions;$oldBounds=$form.Bounds;$oldAuto=$script:automaticDetailHeight
  try {
   $screen=[Windows.Forms.Screen]::FromControl($form).WorkingArea
   $script:automaticDetailHeight=$true;$script:modePositions=@{Detail=[pscustomobject]@{x=$screen.Left+55;y=$screen.Top+80};Compact=$null}
   $form.Location=[Drawing.Point]::new($screen.Left+55,$screen.Top)
   $start=$source.IndexOf('$drag = {');$end=$source.IndexOf('foreach ($control in @($form,$title',$start)
   $handlerSource=$source.Substring($start,$end-$start)
   # Replace only the blocking native mouse-move loop, preserving the actual
   # product event handler and its anchor/persistence effects.
   $handlerSource=$handlerSource -replace '\[void\]\[WidgetDrag\]::ReleaseCapture\(\)','[void]0' -replace '\[void\]\[WidgetDrag\]::SendMessage\([^\r\n]*\)','[void]0'
   Invoke-Expression $handlerSource
   & $drag $title ([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,0,0,0))
   Assert-Equal $script:modePositions.Detail.y ($screen.Top+80) 'A click is not a new window placement'
   $movedSource=$source.Substring($start,$end-$start) -replace '\[void\]\[WidgetDrag\]::ReleaseCapture\(\)','[void]0' -replace '\[void\]\[WidgetDrag\]::SendMessage\([^\r\n]*\)','$form.Top+=24'
   $beforeMove=$form.Top
   Invoke-Expression $movedSource
   & $drag $title ([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::Left,1,0,0,0))
   Assert-Equal $script:modePositions.Detail.y ($beforeMove+24) 'A real move records the new anchor'
   Assert-Equal $script:detailDragging $false 'Native move-loop guard resets after dragging'
  }finally{$script:modePositions=$oldPositions;$script:automaticDetailHeight=$oldAuto;$form.Bounds=$oldBounds}
 }
 Test-Case 'unchanged quota refresh does not repaint the unchanged detail title' {
  $script:mode='Detail';$script:animating=$false;Show-Quota;[Windows.Forms.Application]::DoEvents()
  $script:refreshTitlePaints=0
  $paint=[Windows.Forms.PaintEventHandler]{param($sender,$e);$script:refreshTitlePaints++}
  $title.Add_Paint($paint)
  try {Show-Quota;[Windows.Forms.Application]::DoEvents();Assert-Equal $script:refreshTitlePaints 0 'Unchanged reads need no full-window repaint'}
  finally {$title.Remove_Paint($paint)}
 }
 Test-Case 'native mode changes finish in one update without opacity or intermediate frames' {
  $oldBounds=$form.Bounds;$oldSize=$script:detailSize;$oldMode=$script:mode;$oldAuto=$script:automaticDetailHeight
  $script:animationTimer=[Windows.Forms.Timer]::new()
  try {
   $script:automaticDetailHeight=$false;$script:mode='Compact';$script:animating=$false;$script:detailSize=[Drawing.Size]::new(606,700);$script:layoutPlus=$false
   Start-ModeTransition 'Detail'
   Assert-Equal $script:mode 'Detail' 'The first click completes the native detail state'
   Assert-Equal $script:animating $false 'No per-frame PowerShell layout remains pending'
   Assert-Equal $form.Opacity 1 'Native text stays opaque during mode changes'
   Start-ModeTransition 'Compact'
   Assert-Equal $script:mode 'Compact' 'Collapsing completes in the same update'
   Assert-Equal $body.Visible $false 'Collapsed content is hidden'
  }finally{$script:animationTimer.Stop();$script:animationTimer.Dispose();$script:detailSize=$oldSize;$script:mode=$oldMode;$script:animating=$false;$script:automaticDetailHeight=$oldAuto;$form.Bounds=$oldBounds;Set-ModeVisual ($script:mode -eq 'Compact')}
 }
 Test-Case 'long inline history retains all records and realizes only rows in the scroll viewport' {
  $oldExternal=$script:externalData;$oldBounds=$form.Bounds;$oldAuto=$script:automaticDetailHeight
  $oldClient=$script:client;$oldNotice=$script:noticeView;$oldReadTask=$script:announcementReadTask;$oldReadContent=$script:announcementReadContent
  try {
   $script:automaticDetailHeight=$false;$script:creditsExpanded=$false;$script:announcementRenderKey=''
   $form.ClientSize=[Drawing.Size]::new(606,500)
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;sourceUpdatedAt=$now.ToString('o');items=@();history=@()}}
   foreach($i in 1..50){$script:externalData.announcements.history+=,[pscustomobject]@{id=('https://example.invalid/FABRICATED-viewport-'+$i+'#regular');noticeVersion='FABRICATED-visible-version';kind='regular';sourceUrl='https://example.invalid/FABRICATED';certainty='announced';announcedAt=$now.AddDays(-$i).ToString('o');deliveredAt=$now.AddDays(-$i).ToString('o')}}
   Show-External;while($script:visibleActivityView.nextCount -gt 0){$activityMore.PerformClick()};$body.AutoScrollPosition=[Drawing.Point]::Empty
   $node=$ast.Find({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$body' -and $n.Member.Value -eq 'Add_Scroll'},$true)
   if(-not $node){throw 'Native scroll does not update the activity viewport'}
   & $node.Arguments[0].ScriptBlock.GetScriptBlock()
   Assert-Equal $script:announcementRows.Count 50 'All fabricated records remain available'
   Assert-Equal $script:announcementRows[-1].IsHandleCreated $false 'Offscreen history does not allocate hundreds of HWNDs on first expansion'
   if($body.AutoScrollMinSize.Height -le 6000){throw 'The full history scroll extent was truncated'}
   Add-Type -AssemblyName System.Net.Http
   $script:client=[pscustomobject]@{captured=@()}
   $script:client | Add-Member ScriptMethod PostAsync {param($url,$content);$this.captured=@(($content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json).ids | ForEach-Object {$_.id});[Threading.Tasks.Task]::FromResult(0)}
   $script:noticeView=[pscustomobject]@{ids=@($script:visibleActivityView.active | ForEach-Object {$_.id});entries=@($script:visibleActivityView.active | ForEach-Object {[pscustomobject]@{id=$_.id;version=$_.noticeVersion}});hasUnread=$true}
   $script:announcementReadTask=$null
   $nativeRead=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Start-AnnouncementRead'},$true)
   & $nativeRead.Body.GetScriptBlock()
   $lastId=$script:visibleActivityView.active[-1].id
   if($lastId -in $script:client.captured){throw 'An unshown final record was acknowledged before scrolling'}
   $body.AutoScrollPosition=[Drawing.Point]::new(0,$body.AutoScrollMinSize.Height)
   & $node.Arguments[0].ScriptBlock.GetScriptBlock()
   Assert-Equal $script:announcementRows[-1].Visible $true 'The last record appears when scrolled into view'
   Assert-Equal $script:announcementRows[0].Visible $false 'Rows scrolled out of view stop painting'
   $script:announcementReadTask=$null
   if($script:announcementReadContent){$script:announcementReadContent.Dispose();$script:announcementReadContent=$null}
   & $nativeRead.Body.GetScriptBlock()
   if($lastId -notin $script:client.captured){throw 'The shown final record was not acknowledged after scrolling'}
   $body.AutoScrollPosition=[Drawing.Point]::Empty;Update-ActivityViewport
   $wheel=$body.GetType().GetMethod('OnMouseWheel',[Reflection.BindingFlags]'Instance,NonPublic')
   $event=$ast.Find({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$body' -and $n.Member.Value -eq 'Add_MouseWheel'},$true)
   if($event){$handler=$event.Arguments[0].ScriptBlock.GetScriptBlock();$body.Add_MouseWheel($handler)}
   try {
    for($i=0;$i -lt 180;$i++){$wheel.Invoke($body,@([Windows.Forms.MouseEventArgs]::new([Windows.Forms.MouseButtons]::None,0,20,20,-120)))}
    Assert-Equal $script:announcementRows[-1].Visible $true 'Actual mouse-wheel scrolling realizes the final record'
   }finally{if($event){$body.Remove_MouseWheel($handler)}}
  }finally{if($script:announcementReadContent -and $script:announcementReadContent -ne $oldReadContent){$script:announcementReadContent.Dispose()};$script:client=$oldClient;$script:noticeView=$oldNotice;$script:announcementReadTask=$oldReadTask;$script:announcementReadContent=$oldReadContent;$script:externalData=$oldExternal;$script:activityLimit=3;$script:announcementRenderKey='';$script:automaticDetailHeight=$oldAuto;$form.Bounds=$oldBounds;$body.AutoScrollPosition=[Drawing.Point]::Empty;Show-External}
 }
 Test-Case 'a fast repeated public retry failure restores the retry action' {
  Add-Type -AssemblyName System.Net.Http
  $oldClient=$script:client;$oldTask=$script:externalTask;$oldExternal=$script:externalData;$oldContent=$script:externalRequestContent
  try {
   $script:client=[pscustomobject]@{};$script:client | Add-Member ScriptMethod PostAsync {param($url,$body);[Threading.Tasks.Task]::FromResult(0)}
   $script:externalTask=$null;$script:externalData=[pscustomobject]@{status='unavailable';announcements=[pscustomobject]@{status='unavailable';stale=$true;sourceUpdatedAt=$null;items=@();history=@()}}
   Show-External;Assert-Equal $publicRetry.Enabled $true 'Failed public data can be retried'
   Start-PublicRetry
   Assert-Equal $publicRetry.Enabled $false 'The action waits for response consumption'
   Show-External
   Assert-Equal $publicRetry.Enabled $false 'A completed response still waits for consumption'
   $script:externalTask=$null;Show-External
   Assert-Equal $publicRetry.Enabled $true 'A same-state fast failure must re-enable retry'
   Assert-Equal $publicRetry.Text (T 'publicRetry') 'The retry label cannot remain stuck'
  }finally{if($script:externalRequestContent -and $script:externalRequestContent -ne $oldContent){$script:externalRequestContent.Dispose()};$script:client=$oldClient;$script:externalTask=$oldTask;$script:externalRequestContent=$oldContent;$script:externalData=$oldExternal;$script:announcementRenderKey='';Show-External}
 }
 Test-Case 'a repeated empty quota failure cannot leave the status stuck refreshing' {
  $oldClient=$script:client;$oldTask=$script:requestTask;$oldSettings=$script:settingsTask;$oldData=$script:data;$oldMessage=$script:message
  try {
   $script:client=[pscustomobject]@{};$script:client | Add-Member ScriptMethod GetAsync {param($url);[Threading.Tasks.Task]::FromResult(0)}
   $script:requestTask=$null;$script:settingsTask=$null;$script:data=$null;$script:message=T 'service_unavailable'
   Show-Quota;Start-Request $false
   Assert-Equal $status.Text (T 'refreshing') 'Empty reads can show the in-flight status'
   $script:requestTask=$null;Show-Quota
   Assert-Equal $status.Text (T 'unavailable') 'Same failure returns to unavailable'
  }finally{$script:client=$oldClient;$script:requestTask=$oldTask;$script:settingsTask=$oldSettings;$script:data=$oldData;$script:message=$oldMessage;$script:quotaRenderKey='';Show-Quota}
 }
 Test-Case 'language changes in compact mode preserve a usable detail window and inline history' {
  $oldLanguage=$script:languageSetting;$oldExternal=$script:externalData;$oldLimit=$script:activityLimit
  $menuStart=$source.IndexOf('$menu = New-Object System.Windows.Forms.ContextMenu')
  $menuEnd=$source.IndexOf('$form.ContextMenu = $menu',$menuStart)
  Invoke-Expression $source.Substring($menuStart,$menuEnd-$menuStart)
  # Keep the real native save path, substituting only local HTTP and its modal
  # warning presentation. No fixture settings reach the user's service or cache.
  function Invoke-RestMethod {param($Uri,$Method,$ContentType,$Body,$TimeoutSec);[Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json}
  $saveDefinition=$ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Save-WidgetLanguage'}
  $warning="[void][Windows.Forms.MessageBox]::Show((T 'languageSaveFailed'), (T 'app'), [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning)"
  Invoke-Expression $saveDefinition.Extent.Text.Replace($warning,'$script:languageFailure=$_.Exception.Message')
  try {
   $languageRecords=@(1..50 | ForEach-Object {[pscustomobject]@{id=('https://example.invalid/FABRICATED-language-'+$_+'#regular');kind='regular';certainty='announced';announcedAt=$now.AddDays(-$_).ToString('o');sourceUrl=('https://example.invalid/FABRICATED-language-'+$_);summary='FABRICATED TEST DATA - Long history for language switching';summaryZh='虚构测试数据 - 语言切换长历史';deliveredAt=$now.AddDays(-$_).AddHours(1).ToString('o')}})
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;sourceUpdatedAt=$now.ToString('o');lastFetchedAt=$now.ToUnixTimeMilliseconds();items=@();history=$languageRecords}}
   Show-External
   $script:activityLimit=3;Show-External;Start-ModeTransition 'Compact'
   foreach($setting in @('en','zh-CN','auto')) {
    $script:languageFailure=$null;Save-WidgetLanguage $setting;if($script:languageFailure){throw $script:languageFailure}
    Assert-Equal $script:mode 'Compact' 'Changing language keeps the current mode'
    Assert-Equal $script:layoutBusy $false 'Language update releases layout'
    Start-ModeTransition 'Detail'
    if($form.ClientSize.Width -lt 404 -or $form.ClientSize.Height -lt 390){throw 'Expanded detail kept compact dimensions'}
    Show-External
    Assert-Equal $script:announcementRows.Count 3 'History still opens in batches after language switching'
    while ($script:visibleActivityView.nextCount -gt 0) {$activityMore.PerformClick()}
    Assert-Equal $script:announcementRows.Count 50 'All history survives language switching'
    Assert-Equal $title.Text (T 'app') 'Title translated'
    Assert-Equal $cadence.Text (T 'refreshCadence') 'Footer translated'
    $script:activityLimit=3;Show-External;Start-ModeTransition 'Compact'
   }
  }finally{$script:languageSetting=$oldLanguage;$script:externalData=$oldExternal;$script:activityLimit=$oldLimit;Set-Language;Start-ModeTransition 'Detail';$menu.Dispose()}
 }
 Test-Case 'inline disclosure draws crisp GDI text and supports keyboard activation' {
  if($cards.GetType().Name -ne 'WidgetDisclosureButton' -or $cards.UseCompatibleTextRendering){throw 'Summary is not the direct GDI disclosure control'}
  $script:creditsExpanded=$false
  $key=[Windows.Forms.KeyEventArgs]::new([Windows.Forms.Keys]::Space)
  $method=$cards.GetType().GetMethod('OnKeyDown',[Reflection.BindingFlags]'Instance,NonPublic')
  $method.Invoke($cards,@($key))
  Assert-Equal $script:creditsExpanded $true 'Space opens inline details'
 }
} finally {
 foreach($other in @([Windows.Forms.Application]::OpenForms)){if($other -ne $form){$other.Close();$other.Dispose()}}
 $tooltip.Dispose();$form.Dispose()
}
if($script:failures){exit 1}
