import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { normalizeQuota } from './quota.mjs';
import { queryExternal } from './external.mjs';
import { resolveCodex } from './cli.mjs';
const ROOT=dirname(fileURLToPath(import.meta.url));
const HOST='127.0.0.1', PORT=39224, REFRESH_MS=60000;
const activeChildren=new Set();
const codes=new Set(['cli_missing','signed_out','timeout','network','unsupported','service_unavailable','query_failed']);
const failure=(code)=>Object.assign(new Error(code==='signed_out'?'not logged in':code),{code});
export function classifyError(error) {
  if(codes.has(error?.code))return error.code;
  if(error?.code==='ENOENT')return 'cli_missing';
  if([401,403].includes(error?.code)||/not logged in|unauthenticated|sign.?in|authentication|unauthorized|token.*expired/i.test(error?.message||''))return 'signed_out';
  if(/timeout|timed out/i.test(error?.message||''))return 'timeout';
  if(/network|fetch failed|connection|offline|dns|tls|ssl/i.test(error?.message||''))return 'network';
  return 'query_failed';
}
export function queryAppServer(options={}) {
  return new Promise((resolveResult,rejectResult)=>{
    let child,output,timeout,limits,accountSeen=false,accountPlanType=null,settled=false;
    const finish=(error,result)=>{if(settled)return;settled=true;clearTimeout(timeout);output?.close();child?.kill();if(error)rejectResult(failure(classifyError(error)));else resolveResult(result);};
    try{
      const invocation=options.command?{command:options.command,args:options.args||['app-server']}:resolveCodex();
      child=spawn(invocation.command,invocation.args,{stdio:['pipe','pipe','pipe'],windowsHide:true});activeChildren.add(child);child.once('close',()=>activeChildren.delete(child));
    }catch(error){finish(error);return;}
    child.stderr.resume();child.on('error',error=>finish(error));child.on('exit',()=>finish(failure('query_failed')));child.stdin.on('error',error=>finish(error));
    output=createInterface({input:child.stdout});output.on('line',line=>{
      let message;try{message=JSON.parse(line);}catch{return;}
      if(message.id===0){if(message.error)return finish(message.error);child.stdin.write(JSON.stringify({method:'initialized',params:{}})+'\n');child.stdin.write(JSON.stringify({method:'account/rateLimits/read',id:1})+'\n');child.stdin.write(JSON.stringify({method:'account/read',id:2,params:{refreshToken:false}})+'\n');}
      else if(message.id===1){if(message.error)return finish(message.error);limits=message.result;}
      else if(message.id===2){if(message.error)return finish(message.error);accountSeen=true;const account=message.result?.account;if(!account&&message.result?.requiresOpenaiAuth)return finish(failure('signed_out'));accountPlanType=account?.planType||null;}
      if(limits&&accountSeen)finish(null,{...limits,accountPlanType});
    });
    timeout=setTimeout(()=>finish(failure('timeout')),options.timeoutMs??20000);
    child.stdin.write(JSON.stringify({method:'initialize',id:0,params:{clientInfo:{name:'codex_quota_widget',title:'Codex Quota Widget',version:'0.1.0'}}})+'\n');
  });
}
export const settingsPath=()=>join(process.platform==='win32'?(process.env.LOCALAPPDATA||join(homedir(),'AppData','Local')):join(homedir(),'Library','Application Support'),'CodexWeeklyMonitor','settings.json');
export async function readSettings(path=settingsPath()) {
  try{const data=JSON.parse(await readFile(path,'utf8'));return {language:['auto','en','zh-CN'].includes(data.language)?data.language:'auto'};}catch{return {language:'auto'};}
}
let settingsWrite=Promise.resolve();
export function saveSettings(input,path=settingsPath()) {
  if(!input||!['auto','en','zh-CN'].includes(input.language))return Promise.reject(new Error('Invalid language'));
  const task=settingsWrite.catch(()=>{}).then(async()=>{
    let previous={};try{previous=JSON.parse(await readFile(path,'utf8'));}catch{}
    await mkdir(dirname(path),{recursive:true});const temp=path+'.'+process.pid+'.tmp';
    await writeFile(temp,JSON.stringify({...previous,language:input.language}),{mode:0o600});await rename(temp,path);return {language:input.language};
  });settingsWrite=task;return task;
}
export function createQuotaCache({query=()=>queryAppServer(),now=Date.now}={}) {
  let state={status:'loading'},pending=null,nextDue=0,failures=0;
  const refresh=()=>{
    if(pending)return pending;
    pending=Promise.resolve().then(async()=>{
      try{const result=await query();const quota=normalizeQuota(result,result.accountPlanType);state=quota?{status:'ok',...quota,updatedAt:now()}:{status:'unavailable',errorCode:'unsupported'};failures=0;nextDue=now()+REFRESH_MS;}
      catch(error){failures++;nextDue=now()+Math.min(60000,15000*2**Math.min(failures-1,2));state={status:'unavailable',errorCode:classifyError(error),nextRetryAt:nextDue};}
      finally{pending=null;}return state;
    });return pending;
  };
  return {get state(){return state;},refresh,refreshIfDue:()=>now()>=nextDue?refresh():Promise.resolve(state)};
}
export async function startMonitor({port=PORT,settingsFile=settingsPath(),query,externalQuery=queryExternal}={}) {
  const cache=createQuotaCache({query});
  let externalState={status:'loading',lastGlobal:null,forecast:null},externalPending=null,lastExternalFetch=0;
  const refreshExternal=(force=false)=>{
    if(externalPending)return externalPending;
    if(force&&Date.now()-lastExternalFetch<60000)return Promise.resolve(externalState);
    lastExternalFetch=Date.now();externalPending=Promise.resolve().then(async()=>{
      try{externalState=await externalQuery();}catch{externalState={status:'unavailable',lastGlobal:null,forecast:null};}finally{externalPending=null;}return externalState;
    });return externalPending;
  };
  const files=new Map([['/',['index.html','text/html']],['/app.css',['app.css','text/css']],['/app.mjs',['app.mjs','text/javascript']],['/i18n.mjs',['i18n.mjs','text/javascript']]]);
  const server=createServer(async(request,response)=>{
    try{
      const authority=`${HOST}:${server.address().port}`,origin=`http://${authority}`,url=new URL(request.url||'/',origin);
      if(request.headers.host!==authority){response.writeHead(403).end();return;}
      response.setHeader('Cache-Control','no-store');response.setHeader('X-Content-Type-Options','nosniff');response.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'");
      const json=value=>{response.writeHead(200,{'Content-Type':'application/json; charset=utf-8'});response.end(JSON.stringify(value));};
      if(request.method==='GET'&&url.pathname==='/health'){json({app:'codex-weekly-monitor',version:'0.1.0'});return;}
      if(request.method==='GET'&&url.pathname==='/api/usage'){json(await cache.refreshIfDue());return;}
      if(request.method==='GET'&&url.pathname==='/api/external'){if(externalState.status==='loading')await refreshExternal();json(externalState);return;}
      if(request.method==='GET'&&url.pathname==='/api/settings'){json(await readSettings(settingsFile));return;}
      if(request.method==='POST'){
        if(request.headers.origin&&request.headers.origin!==origin){response.writeHead(403).end();return;}
        if(url.pathname==='/api/settings'){
          if(!/^application\/json(?:;|$)/i.test(request.headers['content-type']||'')){response.writeHead(415).end();return;}
          try{let body='';for await(const chunk of request){body+=chunk;if(body.length>4096)throw Error();}json(await saveSettings(JSON.parse(body),settingsFile));}catch{response.writeHead(400).end();}return;
        }
        if(url.pathname==='/api/refresh'){await Promise.allSettled([cache.refresh(),refreshExternal(true)]);json(cache.state);return;}
      }
      if(request.method==='GET'&&files.has(url.pathname)){const[name,type]=files.get(url.pathname);try{response.writeHead(200,{'Content-Type':type+'; charset=utf-8'});response.end(await readFile(join(ROOT,'public',name)));}catch{response.end();}return;}
      response.writeHead(404).end();
    }catch{if(!response.headersSent)response.writeHead(500);response.end();}
  });
  await new Promise((resolveListen,reject)=>{server.once('error',reject);server.listen(port,HOST,resolveListen);});cache.refresh();refreshExternal();
  const timer=setInterval(()=>cache.refreshIfDue(),5000),externalTimer=setInterval(()=>refreshExternal(),600000);
  const stop=()=>new Promise(resolveStop=>{clearInterval(timer);clearInterval(externalTimer);for(const child of activeChildren)child.kill();server.close(resolveStop);server.closeIdleConnections();});
  return {server,cache,stop};
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===resolve(process.argv[1])){
  startMonitor().then(({stop})=>{process.stdout.write(`Codex Quota Widget: http://${HOST}:${PORT}/\n`);const shutdown=()=>stop().then(()=>process.exit(0));process.once('SIGINT',shutdown);process.once('SIGTERM',shutdown);}).catch(()=>{console.error('Cannot start the local widget service.');process.exitCode=1;});
}
