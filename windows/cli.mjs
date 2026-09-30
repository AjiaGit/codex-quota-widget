import { existsSync, accessSync, constants } from 'node:fs';
import { dirname, join, delimiter } from 'node:path';
import { homedir } from 'node:os';

export function resolveCodex({ platform=process.platform, env=process.env, home=homedir() }={}) {
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
      const script=join(dirname(path),'node_modules','@openai','codex','bin','codex.js');
      if(existsSync(script))return {command:process.execPath,args:[script,'app-server']};
      continue;
    }
    try{accessSync(path,platform==='win32'?constants.F_OK:constants.X_OK);return {command:path,args:['app-server']};}catch{}
  }
  throw Object.assign(new Error('Codex CLI is not installed'),{code:'cli_missing'});
}
