$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$windows=Split-Path $PSScriptRoot -Parent
. (Join-Path $windows 'Native.ps1')
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $windows 'Floating.ps1'),[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Floating script failed to parse'}
$compile=$ast.EndBlock.Statements | Where-Object {$_.Extent.Text.StartsWith('Add-Type -ReferencedAssemblies') -and $_.Extent.Text.Contains('public static class WidgetOutsideClick')}
$native=$compile.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.Contains('public static class WidgetOutsideClick')},$true)
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition $native.Value
$source=$ast.Extent.Text
$end=$source.IndexOf('$script:baseUrl =', $compile.Extent.EndOffset)
$startup=$source.Substring($compile.Extent.EndOffset,$end-$compile.Extent.EndOffset)
$paint=$ast.Find({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$ring' -and $n.Member.Value -eq 'Add_Paint'},$true)
$render=$paint.Arguments[0].ScriptBlock.GetScriptBlock()
Add-Type -ReferencedAssemblies @('System.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition @"
using System; using System.Drawing; using System.Runtime.InteropServices; using System.Windows.Forms;
public static class FontDpiFixture {
 [StructLayout(LayoutKind.Sequential)] struct Rect { public int left,top,right,bottom; }
 [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window,out Rect rect);
 [DllImport("user32.dll")] static extern IntPtr GetWindowDpiAwarenessContext(IntPtr window);
 [DllImport("gdi32.dll")] static extern uint GetObjectType(IntPtr obj);
 [DllImport("gdi32.dll")] static extern IntPtr GetCurrentObject(IntPtr dc,uint kind);
 [DllImport("gdi32.dll")] static extern int GetObject(IntPtr obj,int count,IntPtr buffer);
 public static int[] PaintContext(Label label,int screenIndex) {
  int type=0,dib=0;
  var previous=SetThreadDpiAwarenessContext(new IntPtr(-5));
  if(previous==IntPtr.Zero) throw new Exception("Fixture GDI scaling unavailable");
  try {
   using(var form=new Form()) {
    var screen=Screen.AllScreens[screenIndex]; form.Text="FABRICATED TEST DATA - direct text paint";
    form.StartPosition=FormStartPosition.Manual;form.AutoScaleMode=AutoScaleMode.None;
    form.Location=new Point(screen.WorkingArea.Left+80,screen.WorkingArea.Top+80);form.ClientSize=new Size(340,100);
    label.Paint+=delegate(object sender,PaintEventArgs e) {
     IntPtr dc=e.Graphics.GetHdc();IntPtr buffer=Marshal.AllocHGlobal(128);
     try {
      type=(int)GetObjectType(dc);
      int bytes=GetObject(GetCurrentObject(dc,7),128,buffer);
      dib=bytes>(IntPtr.Size==8?32:24)?1:0;
     } finally {Marshal.FreeHGlobal(buffer);e.Graphics.ReleaseHdc(dc);}
    };
    form.Controls.Add(label);form.Show();label.Refresh();Application.DoEvents();form.Close();
   }
   return new[]{type,dib};
  } finally {SetThreadDpiAwarenessContext(previous);}
 }
 public static Rectangle[] Measure(int context,int screenIndex) {
  var previous=SetThreadDpiAwarenessContext(new IntPtr(context));
  if(previous==IntPtr.Zero) throw new Exception("Fixture DPI mode unavailable");
  try {
   var screen=Screen.AllScreens[screenIndex];
   using(var form=new Form()) {
    form.Text="FABRICATED TEST DATA - text scaling"; form.FormBorderStyle=FormBorderStyle.None;
    form.StartPosition=FormStartPosition.Manual; form.AutoScaleMode=AutoScaleMode.None;
    form.Bounds=new Rectangle(screen.WorkingArea.Left+80,screen.WorkingArea.Top+80,404,390);
    using(var label=new Label()) {
     label.Text="FABRICATED TEST DATA"; label.Bounds=new Rectangle(20,20,300,40); form.Controls.Add(label);
     form.Show(); Application.DoEvents();
     if(!AreDpiAwarenessContextsEqual(GetWindowDpiAwarenessContext(form.Handle),new IntPtr(context))) throw new Exception("Window lost DPI mode");
     var logical=form.Bounds; var old=SetThreadDpiAwarenessContext(new IntPtr(-3)); Rect rect;
     try { if(!GetWindowRect(form.Handle,out rect)) throw new Exception("Physical bounds unavailable"); }
     finally { SetThreadDpiAwarenessContext(old); }
     form.Close(); return new[]{logical,Rectangle.FromLTRB(rect.left,rect.top,rect.right,rect.bottom)};
    }
   }
  } finally { SetThreadDpiAwarenessContext(previous); }
 }
}
"@
$script:failures=0
function Test-Case([string]$name,[scriptblock]$body) {
 try {& $body;Write-Output "PASS $name"} catch {$script:failures++;Write-Output "FAIL $name : $($_.Exception.Message)"}
}
$previous=[FontDpiFixture]::GetThreadDpiAwarenessContext()
try {
 [void][FontDpiFixture]::SetThreadDpiAwarenessContext([IntPtr](-1))
 Invoke-Expression $startup
 Test-Case 'actual floating startup enables GDI text scaling before creating windows' {
  if(-not [FontDpiFixture]::AreDpiAwarenessContextsEqual([FontDpiFixture]::GetThreadDpiAwarenessContext(),[IntPtr](-5))){throw 'Text remains bitmap-stretched in ordinary DPI-unaware mode'}
 }
 foreach($index in 0..([Windows.Forms.Screen]::AllScreens.Count-1)) {
  Test-Case "GDI scaling preserves logical and physical window geometry on screen $index" {
   $before=[FontDpiFixture]::Measure(-1,$index);$after=[FontDpiFixture]::Measure(-5,$index)
   if($before[0] -ne $after[0] -or $before[1] -ne $after[1]){throw 'Saved window geometry changed with text scaling'}
  }
 }
 $labelFactory=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'New-Label'},$true)
 Invoke-Expression $labelFactory.Extent.Text
 foreach($index in 0..([Windows.Forms.Screen]::AllScreens.Count-1)) {
  Test-Case "actual label paints to a window DC without a stretched DIB buffer on screen $index" {
   $label=New-Label 'FABRICATED TEST DATA' 10 10 300 40 10.5
   $font=$label.Font
   try {
    if($label.UseCompatibleTextRendering){throw 'Actual label uses GDI+ instead of the GDI layout/rendering path'}
    $label.BackColor=[Drawing.Color]::FromArgb(31,36,43);$label.ForeColor=[Drawing.Color]::White
    $paintContext=[FontDpiFixture]::PaintContext($label,$index)
    if($paintContext[0] -ne 3 -or $paintContext[1] -ne 0){throw "Text paint uses HDC type $($paintContext[0]), DIB buffer $($paintContext[1]); enhanced scaling is bypassed"}
   } finally {$label.Dispose();$font.Dispose()}
  }
 }
 $sourceFactoryStart=$source.IndexOf('$attribution=')
 $sourceFactoryEnd=$source.IndexOf('$cadence=',$sourceFactoryStart)
 $sourceFactory=$source.Substring($sourceFactoryStart,$sourceFactoryEnd-$sourceFactoryStart)
 $setSources=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Set-AttributionLinks'},$true)
 Invoke-Expression $setSources.Extent.Text
 foreach($index in 0..([Windows.Forms.Screen]::AllScreens.Count-1)) {
  Test-Case "monitor website links use complete GDI links and direct paint on screen $index" {
   $sourcesPanel=[Windows.Forms.Panel]::new();$fonts=@()
   try {
    Invoke-Expression $sourceFactory
    Set-AttributionLinks 'codex-reset.com / codexreset.dev'
    $links=@($attribution.Controls | Where-Object {$_ -is [Windows.Forms.LinkLabel]})
    if($links.Count -ne 2){throw 'Website links share a GDI+ multi-link label'}
    $fonts=@($attribution.Controls | ForEach-Object {$_.Font})
    foreach($width in @(346,620)) {
     $attribution.Size=[Drawing.Size]::new($width,22)
     $attribution.Height=[Math]::Max(22,$attribution.GetPreferredSize([Drawing.Size]::new($width,0)).Height)
     $attribution.PerformLayout();$right=0
     foreach($child in $attribution.Controls) {
      if($child.Left -lt $right -or $child.Right -gt $width -or $child.Bottom -gt $attribution.Height){throw 'Website links overlap or clip the source row'}
      $right=$child.Right
     }
    }
    foreach($link in $links) {
     if($link.UseCompatibleTextRendering -or $link.Links.Count -ne 1 -or $link.Links[0].Start -ne 0 -or $link.Links[0].Length -ne $link.Text.Length){throw 'Website text does not use a complete GDI link'}
     if($link.Links[0].LinkData -ne ('https://'+$link.Text+'/')){throw 'Website link target changed'}
     $context=[FontDpiFixture]::PaintContext($link,$index)
     if($context[0] -ne 3 -or $context[1] -ne 0){throw 'Website text is still painted into a DIB buffer'}
    }
   } finally {$sourcesPanel.Dispose();foreach($font in $fonts){$font.Dispose()}}
  }
 }
 Test-Case 'Chinese and English wrapping retain the same logical measurements' {
  $font=[Drawing.Font]::new('Segoe UI',10.5)
  try {
   foreach($value in @('Codex weekly quota. Auto-refresh: quota every minute, public info every 10 minutes.','已确认全局额度重置。自动刷新：额度每1分钟，公共信息每10分钟。')) {
    $sizes=@(foreach($context in @(-1,-5)) {
     $old=[FontDpiFixture]::SetThreadDpiAwarenessContext([IntPtr]$context)
     try {[Windows.Forms.TextRenderer]::MeasureText($value,$font,[Drawing.Size]::new(300,32767),([Windows.Forms.TextFormatFlags]::WordBreak -bor [Windows.Forms.TextFormatFlags]::NoPrefix))}
     finally {[void][FontDpiFixture]::SetThreadDpiAwarenessContext($old)}
    })
    if($sizes[0] -ne $sizes[1]){throw 'GDI scaling changed wrapped label metrics'}
   }
  } finally {$font.Dispose()}
 }
 Test-Case 'ring percentage uses GDI text and remains centered for detail and compact sizes' {
  if($paint.Extent.Text -notmatch 'TextRenderer\]::DrawText' -or $paint.Extent.Text -match '\.DrawString\('){throw 'Ring GDI+ text bypasses GDI scaling'}
  $script:colors=@{track=[Drawing.Color]::FromArgb(45,45,45);accent=[Drawing.Color]::FromArgb(0,140,100);text=[Drawing.Color]::White;back=[Drawing.Color]::Black}
  $script:noticeView=[pscustomobject]@{hasUnread=$false};$script:animating=$false
  foreach($width in @(42,110)) {
   $script:mode=if($width -eq 42){'Compact'}else{'Detail'}
   foreach($value in @(0,74,100,$null)) {
    $script:remaining=$value;$sender=[Windows.Forms.Panel]::new();$sender.Size=[Drawing.Size]::new($width,$width)
    $bitmap=[Drawing.Bitmap]::new($width,$width);$g=[Drawing.Graphics]::FromImage($bitmap);$g.Clear([Drawing.Color]::Black)
    try {
     & $render $sender ([Windows.Forms.PaintEventArgs]::new($g,[Drawing.Rectangle]::new(0,0,$width,$width)))
     $pixels=@(for($y=0;$y -lt $width;$y++){for($x=0;$x -lt $width;$x++){ $pixel=$bitmap.GetPixel($x,$y);if($pixel.R -gt 180 -and $pixel.G -gt 180 -and $pixel.B -gt 180){[Drawing.Point]::new($x,$y)}}})
     if($pixels.Count -lt 5){throw "Missing text at width $width, value $value"}
     $xrange=$pixels | Measure-Object X -Minimum -Maximum;$yrange=$pixels | Measure-Object Y -Minimum -Maximum
     if($xrange.Minimum -le 0 -or $xrange.Maximum -ge ($width-1) -or $yrange.Minimum -le 0 -or $yrange.Maximum -ge ($width-1)){throw 'Text touches or clips the control boundary'}
     if([Math]::Abs(($xrange.Minimum+$xrange.Maximum)/2-($width-1)/2) -gt 3 -or [Math]::Abs(($yrange.Minimum+$yrange.Maximum)/2-($width-1)/2) -gt 4){throw 'Text is not centered'}
    } finally {$g.Dispose();$bitmap.Dispose();$sender.Dispose()}
   }
  }
 }
} finally {[void][FontDpiFixture]::SetThreadDpiAwarenessContext($previous)}
if($script:failures){exit 1}