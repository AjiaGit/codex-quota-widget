import { existsSync, accessSync, constants, openSync, closeSync, readSync, fstatSync } from 'node:fs';
import { dirname, join, delimiter } from 'node:path';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Windows desktop GUI hosts also use Codex.exe; only console PE files can run app-server.
function windowsConsoleBinary(path) {
  let file;
  try {
    file=openSync(path,'r');const size=fstatSync(file).size,head=Buffer.alloc(64);
    if(size<64||readSync(file,head,0,64,0)!==64||head.readUInt16LE(0)!==0x5a4d)return false;
    const offset=head.readInt32LE(60),pe=Buffer.alloc(94);
    if(offset<64||offset>size-94||readSync(file,pe,0,94,offset)!==94)return false;
    return pe.readUInt32LE(0)===0x4550&&[0x10b,0x20b].includes(pe.readUInt16LE(24))&&pe.readUInt16LE(92)===3;
  } catch {return false;} finally {if(file!==undefined)closeSync(file);}
}
// Launch npm's native binary directly: terminating a JavaScript launcher on Windows
// would not reliably terminate the App Server child it creates.
function npmBinary(shim,arch) {
  const triple=arch==='arm64'?'aarch64-pc-windows-msvc':arch==='x64'?'x86_64-pc-windows-msvc':null;
  if(!triple)return null;
  const scope=join(dirname(shim),'node_modules','@openai'),core=join(scope,'codex');
  const packageName=`@openai/codex-win32-${arch}`;
  const roots=[join(scope,`codex-win32-${arch}`),core];
  try{roots.unshift(dirname(createRequire(join(core,'bin','codex.js')).resolve(`${packageName}/package.json`)));}catch{}
  for(const root of roots)for(const folder of ['bin','codex']){
    const binary=join(root,'vendor',triple,folder,'codex.exe');
    if(existsSync(binary)&&windowsConsoleBinary(binary))return binary;
  }
  return null;
}
// A running service keeps its old environment when the desktop app updates.
// Reuse native Store discovery only after those inherited paths stop working.
function discoverWindowsCodex() {
  if(process.platform!=='win32')return null;
  const native=join(dirname(fileURLToPath(import.meta.url)),'Native.ps1');
  if(!existsSync(native))return null;
  const powershell=join(process.env.SystemRoot||'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
  // The service may inherit PowerShell 7's module path. Use WinPS's own modules
  // so Get-FileHash can validate the extracted Store copy. Pass the script path
  // as data: PowerShell treats smart quotes in interpolated paths as syntax.
  const env=Object.fromEntries(Object.entries(process.env).filter(([key])=>!['PSMODULEPATH','CODEX_WIDGET_NATIVE_HELPER_PATH'].includes(key.toUpperCase())));
  env.PSModulePath=join(dirname(powershell),'Modules');env.CODEX_WIDGET_NATIVE_HELPER_PATH=native;
  const command='[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); . $env:CODEX_WIDGET_NATIVE_HELPER_PATH; $env:CODEX_CLI_PATH=$null; Find-WidgetCodex -ConsoleOnly';
  try {
    return execFileSync(powershell,['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-Command',command],
      {env,encoding:'utf8',windowsHide:true,timeout:5000,maxBuffer:8192,stdio:['ignore','pipe','ignore']}).trim();
  }catch{return null;}
}
export function resolveCodex({ platform=process.platform, arch=process.arch, env=process.env, home=homedir(),
  discoverWindows=env===process.env?discoverWindowsCodex:null }={}) {
  const explicit=env.CODEX_CLI_PATH;
  const pathEntries=(env.PATH||'').split(delimiter).filter(Boolean);
  const defaults=platform==='darwin'?[
    ...pathEntries.map(path=>join(path,'codex')),
    '/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex',
    '/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex',
    '/Applications/Codex.app/Contents/Resources/codex',
    join(home,'Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex'),
    '/opt/homebrew/bin/codex','/usr/local/bin/codex',join(home,'.local/bin/codex'),
  ]:platform==='win32'?[
    ...pathEntries.flatMap(path=>[join(path,'codex.exe'),join(path,'codex.cmd')]),
    ...(env.APPDATA?[join(env.APPDATA,'npm','codex.cmd')]:[]),
    ...(env.LOCALAPPDATA?[join(env.LOCALAPPDATA,'Programs','Codex','resources','codex.exe')]:[]),
  ]:pathEntries.map(path=>join(path,'codex'));
  const candidates=explicit?[explicit,...defaults]:defaults;
  for (const path of candidates) {
    if (!existsSync(path)) continue;
    if (/\.cmd$/i.test(path)) {
      const binary=npmBinary(path,arch);
      if(binary)return {command:binary,args:['app-server']};
      continue;
    }
    if(platform==='win32'&&!windowsConsoleBinary(path))continue;
    try{accessSync(path,platform==='win32'?constants.F_OK:constants.X_OK);return {command:path,args:['app-server']};}catch{}
  }
  if(platform==='win32'&&discoverWindows){
    let discovered;try{discovered=discoverWindows();}catch{}
    if(typeof discovered==='string'&&discovered.trim()){
      // Apply the same console-PE/npm validation; never execute a GUI or shim.
      const invocation=resolveCodex({platform,arch,home,env:{...env,CODEX_CLI_PATH:discovered.trim()},discoverWindows:null});
      if(env===process.env)env.CODEX_CLI_PATH=invocation.command;
      return invocation;
    }
  }
  throw Object.assign(new Error('Codex CLI is not installed'),{code:'cli_missing'});
}
