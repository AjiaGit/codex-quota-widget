$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$repository=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repository 'installer/windows/InstallerSmoke.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Installer smoke failed to parse'}
$native=$ast.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.Contains('public static class QuotaSmokeWindows')},$true)
if(-not $native){throw 'Actual installer smoke native helper not found'}
$fixture=@'
public static class SmokeScrollFixture {
 [System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(System.IntPtr window);
 [System.Runtime.InteropServices.DllImport("user32.dll",EntryPoint="GetPropW",CharSet=System.Runtime.InteropServices.CharSet.Unicode,ExactSpelling=true)] static extern System.IntPtr GetProp(System.IntPtr window,string name);
 static void Require(bool condition,string message){if(!condition)throw new System.Exception(message);}
 static void Reject(System.Action action,string message){
  bool rejected=false;try{action();}catch(System.InvalidOperationException){rejected=true;}
  Require(rejected,message);
 }
 static void Redraw(System.IntPtr window,bool enabled){QuotaSmokeWindows.SendMessage(window,0x000B,enabled?new System.IntPtr(1):System.IntPtr.Zero,System.IntPtr.Zero);}
 public static string[] Run(){
  var reports=new System.Collections.Generic.List<string>();
  int pid=System.Diagnostics.Process.GetCurrentProcess().Id;
  using(var form=new System.Windows.Forms.Form())
  using(var body=new System.Windows.Forms.Panel())
  using(var content=new System.Windows.Forms.Panel())
  using(var other=new System.Windows.Forms.Form()){
   form.Text="FABRICATED TEST DATA - installer scroll fixture";
   form.ClientSize=new System.Drawing.Size(360,300);
   body.Dock=System.Windows.Forms.DockStyle.Fill;body.AutoScroll=true;
   content.Size=new System.Drawing.Size(300,1400);body.Controls.Add(content);form.Controls.Add(body);
   form.Show();System.Windows.Forms.Application.DoEvents();
   var root=form.Handle;var scroll=body.Handle;
   Require(QuotaSmokeWindows.ScrollBody(root,pid)==scroll,"Fixture did not resolve its own scroll body");
   Require(QuotaSmokeWindows.OwnedScrollPosition(root,scroll,pid)==0,"Initial owned position");
   reports.Add("PASS smoke helper resolves the actual visible owned scroll body");
   Reject(delegate{QuotaSmokeWindows.OwnedScrollPosition(root,scroll,pid+100000);},"Foreign process was accepted");
   Reject(delegate{QuotaSmokeWindows.OwnedScrollPosition(root,other.Handle,pid);},"Unrelated window was accepted");
   reports.Add("PASS smoke scroll rejects a foreign PID and unrelated window");
   form.Hide();System.Windows.Forms.Application.DoEvents();
   Require(GetProp(root,"SysSetRedraw")==System.IntPtr.Zero,"Hidden fixture unexpectedly has redraw marker");
   Reject(delegate{QuotaSmokeWindows.OwnedScrollPosition(root,scroll,pid);},"Actually hidden body was accepted");
   reports.Add("PASS smoke scroll rejects a genuinely hidden body without a redraw marker");
   form.Show();System.Windows.Forms.Application.DoEvents();
   Redraw(root,false);
   System.Threading.Tasks.Task<int> read=null;
   try{
    Require(GetProp(root,"SysSetRedraw")!=System.IntPtr.Zero && !IsWindowVisible(scroll),"Windows did not expose the expected redraw pause visibility state");
    using(var entered=new System.Threading.ManualResetEventSlim(false)){
     read=System.Threading.Tasks.Task.Factory.StartNew(delegate{entered.Set();return QuotaSmokeWindows.OwnedScrollPosition(root,scroll,pid);});
     Require(entered.Wait(1000),"Scroll reader did not start");
     System.Threading.Thread.Sleep(100);
     if(read.IsCompleted){
      string reason=read.IsFaulted?read.Exception.GetBaseException().Message:"returned before redraw resumed";
      throw new System.Exception("Scroll read did not wait for the evidenced redraw pause: "+reason);
     }
     Redraw(root,true);
     var deadline=System.DateTime.UtcNow.AddSeconds(3);
     while(!read.IsCompleted && System.DateTime.UtcNow<deadline){System.Windows.Forms.Application.DoEvents();System.Threading.Thread.Sleep(10);}
     Require(read.IsCompleted,"Scroll read did not finish after redraw resumed");
     Require(read.GetAwaiter().GetResult()==0,"Resumed owned position");
    }
    reports.Add("PASS actual smoke scroll waits through WM_SETREDRAW and keeps the same owned body");
   }finally{Redraw(root,true);System.Windows.Forms.Application.DoEvents();}
   Require(QuotaSmokeWindows.ScrollOwnedBody(root,scroll,pid,3)>0,"Normal owned scrolling stopped working");
   reports.Add("PASS smoke helper still scrolls the verified body after redraw resumes");
   Redraw(root,false);
   try{
    var elapsed=System.Diagnostics.Stopwatch.StartNew();
    Reject(delegate{QuotaSmokeWindows.OwnedScrollPosition(root,scroll,pid);},"A stuck redraw pause was accepted");
    Require(elapsed.ElapsedMilliseconds>=100 && elapsed.ElapsedMilliseconds<4000,"Redraw settling was not bounded");
    reports.Add("PASS a stuck redraw pause fails within its bounded settling deadline");
   }finally{Redraw(root,true);}
  }
  return reports.ToArray();
 }
}
'@
Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll','System.Windows.Forms.dll','System.Drawing.dll') -TypeDefinition ($native.Value+"`n"+$fixture)
[SmokeScrollFixture]::Run() | ForEach-Object {Write-Output $_}
