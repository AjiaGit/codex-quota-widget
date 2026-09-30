import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { get } from 'node:http';
import { startMonitor, queryAppServer } from '../monitor.mjs';
test('settings API persists language and rejects cross-origin and invalid writes',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-http-'));
  const {server,stop}=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>({}),externalQuery:async()=>({status:'unavailable'})});
  const base=`http://127.0.0.1:${server.address().port}`;
  const post=(body,origin=base)=>fetch(base+'/api/settings',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify(body)});
  try{
    assert.deepEqual(await(await fetch(base+'/api/settings')).json(),{language:'auto'});
    assert.equal((await post({language:'zh-CN'})).status,200);
    assert.equal((await post({language:'en'},'https://attacker.example')).status,403);
    assert.equal((await post({language:'../invalid'})).status,400);
    assert.deepEqual(await(await fetch(base+'/api/settings')).json(),{language:'zh-CN'});
    assert.equal((await fetch(base+'/api/settings',{method:'POST',body:'language=en'})).status,415);
    assert.equal((await fetch(base+'/i18n.mjs')).status,200);
    assert.equal((await fetch(base+'/api/usage')).status,200);
    const rejected = await new Promise((resolve,reject)=>get(base+'/health',{headers:{Host:'evil.example'}},response=>{response.resume();resolve(response.statusCode);}).on('error',reject));
    assert.equal(rejected,403);
  }finally{await stop();await rm(directory,{recursive:true,force:true});}
});
test('missing CLI and hung CLI have distinct safe error categories',async()=>{
  await assert.rejects(queryAppServer({command:'/definitely/not/a/codex-cli',timeoutMs:1000}),{code:'cli_missing'});
  await assert.rejects(queryAppServer({command:process.execPath,args:['-e','setInterval(()=>{},1000)'],timeoutMs:50}),{code:'timeout'});
});
