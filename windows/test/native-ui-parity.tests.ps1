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
Test-Case 'featured and earlier records follow the Mac disclosure policy' {
 $rows=@([pscustomobject]@{key='r1';kind='recovery';phase='recovered'},[pscustomobject]@{key='p1';kind='regular';phase='delivered'},[pscustomobject]@{key='p2';kind='banked';phase='announced'},[pscustomobject]@{key='r2';kind='recovery';phase='recovered'},[pscustomobject]@{key='p3';kind='regular';phase='delivered'})
 $partition=Get-WidgetActivityPartition $rows
 Assert-Equal ($partition.featured.key -join ',') 'r1,p1,p2' 'Latest account/public and all pending records'
 Assert-Equal ($partition.earlier.key -join ',') 'r2,p3' 'Remaining older records'
 $activity=[pscustomobject]@{featured=$partition.featured;earlier=$partition.earlier;history=@([pscustomobject]@{key='h1'})}
 $view=Get-WidgetVisibleActivityView $activity $false $false
 Assert-Equal ($view.active.key -join ',') 'r1,p1,p2' 'Collapsed older records are not shown'
 Assert-Equal $view.history.Count 0 'Collapsed history is not shown'
 $alerts=[pscustomobject]@{ids=@('p1','p2','p3','h1')}
 Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $view $true) -join ',') 'p1,p2' 'Unshown records remain unread'
 $expanded=Get-WidgetVisibleActivityView $activity $true $true
 Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $expanded $true) -join ',') 'p1,p2,p3,h1' 'Expanded records can be acknowledged'
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
Test-Case 'production announcement IDs acknowledge only the rendered service records' {
 $id='https://example.invalid/FABRICATED-announcement#banked'
 $record=[pscustomobject]@{id=$id;kind='banked';certainty='announced';announcedAt=$now.AddMinutes(-2).ToString('o');scheduledAt=$now.AddDays(1).ToString('o');sourceUrl='https://example.invalid/FABRICATED-announcement';scope='paid'}
 $row=ConvertTo-WidgetAnnouncementRow $record 'en' $now
 $alerts=Get-WidgetAnnouncementAlertView ([pscustomobject]@{unread=@([pscustomobject]@{id=$id;kind='banked'},[pscustomobject]@{id='https://example.invalid/FABRICATED-unseen#regular';kind='regular'})}) 'en'
 $view=[pscustomobject]@{active=@($row);history=@()}
 Assert-Equal ((Get-WidgetAnnouncementReadIds $alerts $view $true) -join ',') $id 'Real service ID shape must match native rendered identity'
 Assert-Equal (Get-WidgetAnnouncementReadIds $alerts $view $false).Count 0 'Hidden details leave notices unread'
}
$start=$source.IndexOf('$script:data = $null');$end=$source.IndexOf('function New-Color',$start)
Invoke-Expression $source.Substring($start,$end-$start)
$script:creditsExpanded=$false;$script:sourcesExpanded=$false;$script:earlierExpanded=$false;$script:creditRenderKey='';$script:creditRows=@();$script:recordExpanded=@{};$script:language='zh-CN';$script:languageSetting='auto';$script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';stale=$false;sourceUpdatedAt=$now.ToString('o');items=@();history=@()}}
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
   $script:automaticDetailHeight=$true;$script:creditsExpanded=$false;$script:historyExpanded=$false;$script:earlierExpanded=$false;$script:sourcesExpanded=$false
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
  $row=[pscustomobject]@{key='FABRICATED-empty';kind='regular';phase='unconfirmed';explicit=$false;scopeText='';summary='';retentionText=''}
  $control=New-AnnouncementControl $row
  try {if($control.Tag.fact.Visible -or $control.Tag.status.Visible){throw 'Empty activity labels still paint at skipped default positions'}}finally{$control.Dispose()}
 }
 Test-Case 'recent recovery disclosure retains the previous observation time' {
  $state=[pscustomobject]@{status='ok';recoveryHistory=[pscustomobject]@{status='ok';records=@([pscustomobject]@{beforePercent=39;afterPercent=74;observedFrom=$now.AddMinutes(-3).ToUnixTimeMilliseconds();detectedAt=$now.AddMinutes(-2).ToUnixTimeMilliseconds()})}}
  $view=Get-WidgetResetActivityView $state $script:externalData 'en' $now
  $presentation=Get-WidgetActivityPresentation $view.active[0] 'en'
  if($presentation.extra -notmatch 'Previous reading:'){throw 'Recent recovery loses its previous observation in About this record'}
 }
 Test-Case 'detail transition lands on the final hero geometry without a jump' {
  $oldBorder=$form.FormBorderStyle;$oldSize=$form.ClientSize
  $script:animationTimer=[Windows.Forms.Timer]::new()
  try {
   $form.FormBorderStyle=[Windows.Forms.FormBorderStyle]::None
   foreach($width in @(404,606,720)) {
    $script:mode='Compact';$script:animating=$false;$script:detailSize=[Drawing.Size]::new($width,640);$script:layoutPlus=$false
    $script:modePositions=@{Compact=$null;Detail=$null}
    Start-ModeTransition 'Detail';$script:animationTimer.Stop();$target=$script:ringTo
    $form.Bounds=$script:animationTo;$script:mode='Detail';$script:animating=$false;Update-ResponsiveLayout
    $point=$form.PointToClient($ring.Parent.PointToScreen($ring.Location))
    $actual=[Drawing.Rectangle]::new($point,$ring.Size)
    Assert-Equal $target $actual 'Animated ring must land exactly on the settled layout'
   }
  }finally{$script:animationTimer.Dispose();foreach($control in $script:detailControls){$control.Visible=$true};$script:animating=$false;$script:mode='Detail';$form.FormBorderStyle=$oldBorder;$form.ClientSize=$oldSize;Update-ResponsiveLayout}
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
 Test-Case 'expanded earlier updates remain displayed after a hidden-window refresh and reopening' {
  $oldExternal=$script:externalData
  try {
   $script:earlierExpanded=$true
   $script:externalData=[pscustomobject]@{status='ok';announcements=[pscustomobject]@{status='ok';sourceUpdatedAt=$now.ToString('o');stale=$false;items=@();history=@()}}
   foreach($i in @(1,2)) {
    $script:externalData.announcements.items+=,[pscustomobject]@{id=('https://example.invalid/FABRICATED-hidden-'+$i+'#regular');kind='regular';certainty='announced';announcedAt=$now.AddMinutes(-$i).ToString('o');deliveredAt=$now.AddMinutes(-$i).ToString('o');sourceUrl='https://example.invalid/FABRICATED-hidden';scope='paid'}
   }
   Show-External;$form.Hide();Show-External;$form.Show()
   if(-not $earlierRowsPanel.Visible -or $script:earlierRows.Count -ne 1){throw 'Previously expanded earlier rows became hidden when refreshed in the tray'}
   $renderedIds=@($script:earlierRows | ForEach-Object {$_.Tag.key})
   foreach($record in $script:visibleActivityView.active | Where-Object {$_.id -like '*hidden-2*'}){if($record.key -notin $renderedIds){throw 'Read view includes an undisplayed earlier record'}}
  }finally{$script:externalData=$oldExternal;$script:earlierExpanded=$false;$script:announcementRenderKey='';$form.Show();Show-External}
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
