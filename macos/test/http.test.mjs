import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { get } from 'node:http';
import { startMonitor, queryAppServer } from '../monitor.mjs';
import { createAnnouncementStore } from '../external.mjs';
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

test('usage API persists recovery snapshots and isolates accounts without exposing their identities',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-recovery-http-'));
  const settingsFile=join(directory,'settings.json');
  let remaining=45,identity='test-private@example.org',running;
  const query=async()=>({accountIdentity:identity,accountPlanType:'pro',rateLimits:{primary:{usedPercent:100-remaining,windowDurationMins:10080,resetsAt:1900000000}}});
  const open=()=>startMonitor({port:0,settingsFile,query,externalQuery:async()=>({status:'unavailable'})});
  try {
    running=await open();let base=`http://127.0.0.1:${running.server.address().port}`;
    assert.deepEqual((await(await fetch(base+'/api/usage')).json()).recoveryHistory.records,[]);
    await running.stop();running=null;
    remaining=99;running=await open();base=`http://127.0.0.1:${running.server.address().port}`;
    const result=await(await fetch(base+'/api/usage')).json();
    assert.equal(result.recoveryHistory.records.length,1);
    assert.equal(result.recoveryHistory.records[0].beforePercent,45);
    assert.ok(!JSON.stringify(result).includes(identity));
    identity='other-private@example.org';remaining=100;
    const other=await(await fetch(base+'/api/refresh',{method:'POST'})).json();
    assert.deepEqual(other.recoveryHistory.records,[]);
  }finally {if(running)await running.stop();await rm(directory,{recursive:true,force:true});}
});

test('external API restores confirmed announcements after a service restart and source failure',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-announcement-http-'));
  const settingsFile=join(directory,'settings.json');
  const at=new Date(Date.now()-60000).toISOString();
  const item={id:'fixture',kind:'banked',certainty:'announced',sourceUrl:'https://x.com/thsottiaux/status/fixture',announcedAt:at,scheduledDate:'2026-10-01'};
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

test('announcement alert cache and scoped read API preserve unread notices and reject cross-origin writes',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-alert-http-'));
  const baseline=Date.now()-120000;
  const store=await createAnnouncementStore({file:join(directory,'announcements.json'),now:()=>baseline});
  await store.update({status:'ok',items:[],history:[],sourceUpdatedAt:new Date(baseline).toISOString()});
  const item={kind:'banked',certainty:'announced',sourceUrl:'https://example.org/new-grant',announcedAt:new Date(Date.now()-60000).toISOString()};
  let queries=0;
  const {server,stop}=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>({}),externalQuery:async()=>{
    queries++;return {status:'ok',announcements:{status:'ok',items:[item],history:[],sourceUpdatedAt:new Date().toISOString()}};
  }});
  const base=`http://127.0.0.1:${server.address().port}`;
  const read=async()=>(await(await fetch(base+'/api/announcement-alerts')).json());
  const post=(body,origin=base)=>fetch(base+'/api/announcement-alerts/read',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify(body)});
  try {
    const external=await(await fetch(base+'/api/external')).json();
    const expected={unread:[{id:item.sourceUrl+'#banked',kind:'banked'}]};
    assert.deepEqual(external.announcementAlerts,expected);
    assert.deepEqual(await read(),expected);
    assert.equal(queries,1,'native alert polling reads the cache only');
    assert.equal((await post({ids:[expected.unread[0].id]},'https://attacker.example')).status,403);
    assert.equal((await post({ids:'all'})).status,400);
    assert.equal((await fetch(base+'/api/announcement-alerts/read',{method:'POST',body:'ids=all'})).status,415);
    assert.deepEqual(await read(),expected,'failed writes never clear unread notices');
    assert.equal((await post({ids:[]})).status,200);
    assert.deepEqual(await read(),expected,'only explicitly viewed IDs are acknowledged');
    assert.equal((await post({ids:[expected.unread[0].id]})).status,200);
    assert.deepEqual(await read(),{unread:[]});
    assert.equal(queries,1);
  }finally {await stop();await rm(directory,{recursive:true,force:true});}
});

test('stopping the service drains an in-progress public snapshot write before reporting shutdown complete',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-shutdown-http-'));
  let release;
  const external=new Promise(resolve=>{release=()=>resolve({status:'unavailable',announcements:{status:'unavailable'}});});
  const {server,stop}=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>({}),externalQuery:()=>external});
  let stopped=false;
  const shutdown=stop().then(()=>{stopped=true;});
  try {
    await new Promise(resolve=>setTimeout(resolve,20));
    const closedBeforeWrite=stopped;
    release();
    await shutdown;
    assert.equal(closedBeforeWrite,false,'shutdown must not race the final local state write');
  }finally {release();await shutdown;await rm(directory,{recursive:true,force:true,maxRetries:3,retryDelay:10});}
});
