$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$windows=Split-Path $PSScriptRoot -Parent
. (Join-Path $windows 'Native.ps1')
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $windows 'Floating.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Floating script failed to parse'}
$source=$ast.Extent.Text
$native=$ast.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.Contains('public static class WidgetOutsideClick')},$true)
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition $native.Value
Add-Type -ReferencedAssemblies @('System.dll','System.Windows.Forms.dll') -TypeDefinition @'
using System;using System.Runtime.InteropServices;using System.Windows.Forms;
public static class MenuFixture {
 [DllImport("user32.dll")]public static extern uint GetMenuItemID(IntPtr menu,int index);
 [DllImport("user32.dll")]public static extern int GetMenuItemCount(IntPtr menu);
 [DllImport("user32.dll")]public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")]public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")]public static extern bool AreDpiAwarenessContextsEqual(IntPtr first,IntPtr second);
}
'@
$script:failures=0
function Test-Case([string]$name,[scriptblock]$action){try{& $action;Write-Output "PASS $name"}catch{$script:failures++;Write-Output "FAIL $name : $($_.Exception.Message)"}}
function Assert-Equal($actual,$expected,[string]$reason){if($actual -cne $expected){throw "$reason. Expected [$expected], got [$actual]"}}
$script:language='en'
function T([string]$key){Get-WidgetText $key $script:language}
function Save-WidgetLanguage([string]$setting){$script:chosenLanguage=$setting}
$form=New-Object Windows.Forms.Form
$ring=New-Object Windows.Forms.Control
$start=$source.IndexOf('$menu = New-Object ')
$end=$source.IndexOf('$script:tray = New-Object ',$start)
Invoke-Expression $source.Substring($start,$end-$start)
try {
 Test-Case 'native menus keep language choices and actions when the float is hidden' {
  $form.Hide()
  if($menu -isnot [Windows.Forms.ContextMenu]){throw 'Tray popup still uses the virtualized ToolStrip window path'}
  Assert-Equal $languageMenu.MenuItems.Count 3 'Language submenu choices'
  Assert-Equal (($languageMenu.MenuItems | ForEach-Object {$_.Tag}) -join ',') 'auto,en,zh-CN' 'Stable language tags'
  Assert-Equal $setupItem.Visible $false 'Setup stays hidden for a connected account'
  Assert-Equal ([MenuFixture]::GetMenuItemCount($languageMenu.Handle)) 3 'OS receives all language options'
 }
 Test-Case 'native command IDs dispatch each language without contacting an account' {
  foreach($index in 0..2){
   $script:chosenLanguage=$null
   $id=[MenuFixture]::GetMenuItemID($languageMenu.Handle,$index)
   Assert-Equal ([WidgetTrayMenu]::DispatchCommand($menu,$id)) $true 'Native command handled'
   Assert-Equal $script:chosenLanguage $languageMenu.MenuItems[$index].Tag 'Correct language selected'
  }
  Assert-Equal ([WidgetTrayMenu]::DispatchCommand($menu,0)) $false 'Cancelled menu changes nothing'
 }
 Test-Case 'physical menu coordinates restore the floating GDI context after success and failure' {
  $original=[MenuFixture]::SetThreadDpiAwarenessContext([IntPtr]::new(-5))
  try {
   $script:menuContext=$null
   [WidgetTrayMenu]::InPhysicalContext([Action]{$script:menuContext=[MenuFixture]::GetThreadDpiAwarenessContext()})
   Assert-Equal ([MenuFixture]::AreDpiAwarenessContextsEqual($script:menuContext,[IntPtr]::new(-3))) $true 'Menu uses physical per-monitor coordinates'
   Assert-Equal ([MenuFixture]::AreDpiAwarenessContextsEqual([MenuFixture]::GetThreadDpiAwarenessContext(),[IntPtr]::new(-5))) $true 'Float context restored'
   try{[WidgetTrayMenu]::InPhysicalContext([Action]{throw 'FABRICATED TEST FAILURE'})}catch{}
   Assert-Equal ([MenuFixture]::AreDpiAwarenessContextsEqual([MenuFixture]::GetThreadDpiAwarenessContext(),[IntPtr]::new(-5))) $true 'Failure restores float context'
  }finally{[void][MenuFixture]::SetThreadDpiAwarenessContext($original)}
 }
 Test-Case 'tray popup owner exists independently of a hidden floating form' {
  $form.Hide()
  Assert-Equal ([WidgetTrayMenu]::OwnerHandle -ne [IntPtr]::Zero) $true 'Dedicated popup owner'
  Assert-Equal $form.Visible $false 'Creating a menu owner does not show the float'
 }
}finally{if('WidgetTrayMenu' -as [type]){[WidgetTrayMenu]::Dispose()};$menu.Dispose();$ring.Dispose();$form.Dispose()}
if($script:failures){exit 1}
