import { existsSync, accessSync, constants } from 'node:fs';
import { dirname, join, delimiter } from 'node:path';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';

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
    if(existsSync(binary))return binary;
  }
  return null;
}
export function resolveCodex({ platform=process.platform, arch=process.arch, env=process.env, home=homedir() }={}) {
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
    try{accessSync(path,platform==='win32'?constants.F_OK:constants.X_OK);return {command:path,args:['app-server']};}catch{}
  }
  throw Object.assign(new Error('Codex CLI is not installed'),{code:'cli_missing'});
}
