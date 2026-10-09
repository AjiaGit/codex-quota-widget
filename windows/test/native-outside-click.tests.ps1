$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$windows = Split-Path $PSScriptRoot -Parent
. (Join-Path $windows 'Native.ps1')
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $windows 'Floating.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Floating script failed to parse.' }
$native = $ast.Find({param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] -and $node.Value.Contains('public static class WidgetOutsideClick')}, $true)
if (-not $native) { throw 'Outside click implementation not found.' }
$assignment = $ast.Find({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$script:outsideClickAction'}, $true)
$expression = $assignment.Right.Find({param($node) $node -is [Management.Automation.Language.ScriptBlockExpressionAst]}, $true)
$handler = $expression.ScriptBlock.GetScriptBlock()
function Start-ModeTransition([string]$mode) { $script:mode = $mode }
$checkHandler = [Action[Windows.Forms.Form,Drawing.Point,bool]] {
    param($fixtureForm,$point,$expectCompact)
    $form = $fixtureForm
    $script:mode = 'Detail'; $script:animating = $false; $script:resizing = $false; $script:detailsForm = $null
    & $handler $point
    if (($script:mode -eq 'Compact') -ne $expectCompact) { throw 'Actual floating handler misclassified physical point.' }
}
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition $native.Value
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class OutsideClickFixture {
    [StructLayout(LayoutKind.Sequential)] struct Point { public int x,y; }
    [StructLayout(LayoutKind.Sequential)] struct MouseData { public Point point; public uint mouseData,flags,time; public UIntPtr extraInfo; }
    [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int left,top,right,bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window,out Rect rect);
    [DllImport("user32.dll")] static extern bool PhysicalToLogicalPointForPerMonitorDPI(IntPtr window,ref Point point);
    [DllImport("user32.dll")] static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")] static extern bool AreDpiAwarenessContextsEqual(IntPtr first,IntPtr second);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint process);
    public static string[] Run(Type production,Action<Form,System.Drawing.Point,bool> checkHandler) {
        var reports = new List<string>();
        var previous = GetThreadDpiAwarenessContext();
        if(previous == IntPtr.Zero) throw new Exception("Cannot establish DPI-unaware fixture thread");
        var flags = BindingFlags.NonPublic | BindingFlags.Static;
        try {
            foreach(var awareness in new[]{-1,-2,-3}) {
              if(SetThreadDpiAwarenessContext(new IntPtr(awareness)) == IntPtr.Zero) throw new Exception("Fixture DPI context unavailable");
              foreach(var screen in Screen.AllScreens) {
                using(var form = new Form()) {
                    form.Text = "FABRICATED TEST DATA - native DPI fixture";
                    form.AutoScaleMode = AutoScaleMode.None;
                    form.StartPosition = FormStartPosition.Manual;
                    form.Location = new System.Drawing.Point(screen.WorkingArea.Left+80, screen.WorkingArea.Top+80);
                    form.ClientSize = new Size(260,220); form.TopMost = true;
                    var child = new TextBox { Multiline=true, Dock=DockStyle.Fill, Text="FABRICATED TEST DATA" };
                    form.Controls.Add(child); form.Show(); form.Activate(); form.BringToFront(); Application.DoEvents();
                    var restore = SetThreadDpiAwarenessContext(new IntPtr(-3));
                    if(restore == IntPtr.Zero) throw new Exception("Fixture physical context unavailable");
                    Rect physicalBounds;
                    try { if(!GetWindowRect(child.Handle,out physicalBounds)) throw new Exception("Fixture bounds unavailable"); }
                    finally { SetThreadDpiAwarenessContext(restore); }
                    var physical = new Point {x=physicalBounds.right-20,y=physicalBounds.bottom-35};
                    var converted = physical;
                    if(!PhysicalToLogicalPointForPerMonitorDPI(form.Handle,ref converted)) throw new Exception("Fixture conversion failed");
                    var logical = new System.Drawing.Point(converted.x,converted.y);
                    uint hitProcess;
                    var hitContext = SetThreadDpiAwarenessContext(new IntPtr(-3));
                    try { GetWindowThreadProcessId(WindowFromPoint(physical),out hitProcess); }
                    finally { SetThreadDpiAwarenessContext(hitContext); }
                    if(hitProcess != (uint)System.Diagnostics.Process.GetCurrentProcess().Id) throw new Exception("Fixture physical point did not hit its own child window");
                    var context = GetThreadDpiAwarenessContext();
                    var frame = (Rectangle)production.GetMethod("GetPhysicalBounds").Invoke(null,new object[]{form});
                    if(!frame.Contains(physical.x,physical.y) || frame.Contains(frame.Right+20,frame.Bottom+20)) throw new Exception("Physical bounds do not contain the child and exclude outside points");
                    if(!AreDpiAwarenessContextsEqual(context,GetThreadDpiAwarenessContext())) throw new Exception("Bounds query leaked DPI context");
                    checkHandler(form,new System.Drawing.Point(physical.x,physical.y),false);
                    checkHandler(form,new System.Drawing.Point(frame.Right+20,frame.Bottom+20),true);
                    reports.Add("PASS actual floating handler uses physical frame and restores DPI context "+awareness+" on "+screen.DeviceName);
                    int callbacks = 0; System.Drawing.Point delivered = System.Drawing.Point.Empty;
                    production.GetField("receiver",flags).SetValue(null,form);
                    production.GetField("clicked",flags).SetValue(null,new Action<System.Drawing.Point>(point => {callbacks++;delivered=point;}));
                    var record = new MouseData {point=physical};
                    var buffer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(MouseData)));
                    try {
                        Marshal.StructureToPtr(record,buffer,false);
                        production.GetMethod("OnMouse",flags).Invoke(null,new object[]{0,new IntPtr(0x0201),buffer});
                        Application.DoEvents();
                        if(callbacks != 0) throw new Exception("Owned child click was queued as outside: "+screen.DeviceName+" logical="+logical+" physical="+physical.x+","+physical.y);
                        reports.Add("PASS physical owned-child click stays inside at DPI context "+awareness+" on "+screen.DeviceName+" (logical "+logical+", physical "+physical.x+","+physical.y+")");
                        if(!AreDpiAwarenessContextsEqual(context,GetThreadDpiAwarenessContext())) throw new Exception("Mouse callback leaked DPI context");
                        var outside = new Point {x=frame.Right+20,y=frame.Bottom+20};
                        record.point=outside;
                        Marshal.StructureToPtr(record,buffer,false);
                        production.GetMethod("OnMouse",flags).Invoke(null,new object[]{0,new IntPtr(0x0201),buffer});
                        Application.DoEvents();
                        if(callbacks!=1 || delivered.X!=outside.x || delivered.Y!=outside.y) throw new Exception("Outside click was not delivered in physical coordinates");
                        if(!AreDpiAwarenessContextsEqual(context,GetThreadDpiAwarenessContext())) throw new Exception("Outside callback leaked DPI context");
                        reports.Add("PASS outside click remains physical and restores DPI context "+awareness+" on "+screen.DeviceName);
                        using(var dialog = new Form()) {
                            dialog.Text="FABRICATED TEST DATA - owned dialog";
                            dialog.StartPosition=FormStartPosition.Manual;
                            dialog.Location=new System.Drawing.Point(screen.WorkingArea.Left+450,screen.WorkingArea.Top+100);
                            dialog.ClientSize=new Size(130,120); dialog.TopMost=true;
                            dialog.Show(form); dialog.Activate(); Application.DoEvents();
                            var dialogContext=SetThreadDpiAwarenessContext(new IntPtr(-3));
                            Rect dialogBounds;
                            try { if(!GetWindowRect(dialog.Handle,out dialogBounds)) throw new Exception("Owned dialog fixture bounds unavailable"); }
                            finally {SetThreadDpiAwarenessContext(dialogContext);}
                            record.point=new Point{x=(dialogBounds.left+dialogBounds.right)/2,y=(dialogBounds.top+dialogBounds.bottom)/2};
                            if(frame.Contains(record.point.x,record.point.y)) throw new Exception("Owned dialog fixture must be outside the main frame");
                            var validateContext=SetThreadDpiAwarenessContext(new IntPtr(-3));
                            try {if(WindowFromPoint(record.point)!=dialog.Handle) throw new Exception("Fixture point did not hit its owned dialog");}
                            finally {SetThreadDpiAwarenessContext(validateContext);}
                            callbacks=0;
                            Marshal.StructureToPtr(record,buffer,false);
                            production.GetMethod("OnMouse",flags).Invoke(null,new object[]{0,new IntPtr(0x0201),buffer});
                            Application.DoEvents();
                            if(callbacks!=0) throw new Exception("Owned dialog click was queued as outside");
                            reports.Add("PASS owned dialog remains interactive at DPI context "+awareness+" on "+screen.DeviceName);
                            dialog.Close();
                        }
                    } finally {Marshal.FreeHGlobal(buffer);}
                    production.GetField("receiver",flags).SetValue(null,null);
                    production.GetField("clicked",flags).SetValue(null,null);
                    form.Close();
                }
            }
            }
        } finally {
            production.GetField("receiver",flags).SetValue(null,null);
            production.GetField("clicked",flags).SetValue(null,null);
            SetThreadDpiAwarenessContext(previous);
        }
        return reports.ToArray();
    }
}
"@
[OutsideClickFixture]::Run([WidgetOutsideClick],$checkHandler) | ForEach-Object { Write-Output $_ }
