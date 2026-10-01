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

test('external API restores confirmed announcements after a service restart and source failure',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-announcement-http-'));
  const settingsFile=join(directory,'settings.json');
  const at=new Date(Date.now()-60000).toISOString();
  const item={id:'fixture',kind:'banked',sourceUrl:'https://x.com/thsottiaux/status/fixture',announcedAt:at,scheduledDate:'2026-10-01'};
  let running;
  try {
    running=await startMonitor({port:0,settingsFile,query:async()=>({}),externalQuery:async()=>({status:'ok',announcements:{status:'ok',items:[item],history:[],sourceUpdatedAt:at}})});
    let base=`http://127.0.0.1:${running.server.address().port}`;
    assert.equal((await(await fetch(base+'/api/external')).json()).announcements.items.length,1);
    await running.stop();running=null;
    running=await startMonitor({port:0,settingsFile,query:async()=>({}),externalQuery:async()=>{throw Error('offline');}});
    base=`http://127.0.0.1:${running.server.address().port}`;
    const restored=(await(await fetch(base+'/api/external')).json()).announcements;
    assert.equal(restored.items.length,1);assert.equal(restored.stale,true);assert.equal(restored.status,'unavailable');
    assert.equal(restored.items[0].sourceUrl,item.sourceUrl);
  }finally { if(running)await running.stop();await rm(directory,{recursive:true,force:true}); }
});

test('public data is queried on the ten-minute timer and polling the cache does not query the provider',async(context)=>{
  context.mock.timers.enable({apis:['setInterval']});
  const directory=await mkdtemp(join(tmpdir(),'quota-public-cadence-'));
  let queries=0,running;
  try {
    running=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>({}),externalQuery:async()=>({status:'ok',updatedAt:++queries,announcements:{status:'unavailable'}})});
    const base=`http://127.0.0.1:${running.server.address().port}`;
    const read=async()=>(await(await fetch(base+'/api/external')).json());
    assert.equal((await read()).updatedAt,1);
    context.mock.timers.tick(599999);
    assert.equal((await read()).updatedAt,1);
    context.mock.timers.tick(1);
    // The timer starts an asynchronous store write; observe the response after it completes.
    for(let tries=0;tries<30&&(await read()).updatedAt===1;tries++)await new Promise(resolve=>setTimeout(resolve,10));
    assert.equal((await read()).updatedAt,2);
    assert.equal(queries,2);
  }finally {if(running)await running.stop();context.mock.timers.reset();await rm(directory,{recursive:true,force:true});}
});
