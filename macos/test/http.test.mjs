import test from 'node:test';
import assert from 'node:assert/strict';
import fs, { mkdtemp, rm } from 'node:fs/promises';
import { syncBuiltinESMExports } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { get } from 'node:http';
import { startMonitor, queryAppServer } from '../monitor.mjs';
import { createAnnouncementStore } from '../external.mjs';
for(const afterSuccess of [false,true])test(`a failed public response waits for its persisted snapshot before allowing retry (${afterSuccess?'cached success':'startup'})`,async(context)=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-public-failure-order-'));
  const events=[];
  let releaseWrite,writeEntered,releaseQuery,queryEntered,publicQueries=0,running;
  const failedQuery=afterSuccess?2:1;
  const blockedWrite=new Promise(resolve=>{releaseWrite=resolve;});
  const enteredWrite=new Promise(resolve=>{writeEntered=resolve;});
  const blockedQuery=new Promise(resolve=>{releaseQuery=resolve;});
  const enteredQuery=new Promise(resolve=>{queryEntered=resolve;});
  const originalRename=fs.rename;
  const mockedRename=context.mock.method(fs,'rename',async(source,destination)=>{
    const firstFailure=destination===join(directory,'announcements.json')&&publicQueries===failedQuery;
    if(firstFailure){writeEntered();await blockedWrite;}
    const result=await originalRename(source,destination);
    if(firstFailure)events.push('snapshot persisted');
    return result;
  });
  // Synchronize the builtin's imported binding so the actual store still does
  // its real file write, with only the first atomic rename held at a barrier.
  syncBuiltinESMExports();
  try{
    running=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>({}),externalQuery:async()=>{
      publicQueries++;
      if(publicQueries===failedQuery)throw Error('offline');
      if(publicQueries===failedQuery+1){queryEntered();await blockedQuery;}
      return {status:'ok',announcements:{status:'ok',stale:false,sourceUpdatedAt:new Date().toISOString(),items:[],history:[]}};
    }});
    const base=`http://127.0.0.1:${running.server.address().port}`;
    let failedRefresh;
    if(afterSuccess){
      assert.equal((await(await fetch(base+'/api/external')).json()).status,'ok');
      failedRefresh=fetch(base+'/api/external/refresh',{method:'POST',headers:{Origin:base}});
    }
    await enteredWrite;
    const requestEntered=new Promise(resolve=>running.server.prependOnceListener('request',(_request,response)=>{
      response.once('finish',()=>events.push('public response finished'));
      resolve();
    }));
    const initial=fetch(base+'/api/external');
    await requestEntered;
    releaseWrite();
    assert.equal((await(await initial).json()).status,'unavailable');
    if(failedRefresh)assert.equal((await(await failedRefresh).json()).status,'unavailable');
    assert.deepEqual([...events],['snapshot persisted','public response finished'],'The published failure and persisted snapshot must finish together');
    const retryResponse=fetch(base+'/api/external/refresh',{method:'POST',headers:{Origin:base}});
    await enteredQuery;
    const cached=await(await fetch(base+'/api/external',{signal:AbortSignal.timeout(5000)})).json();
    assert.equal(cached.status,'unavailable','Ordinary reads keep the settled cache while the provider is fetching');
    releaseQuery();
    const retried=await(await retryResponse).json();
    assert.equal(retried.status,'ok');
    assert.equal(retried.announcements.stale,false);
    assert.equal(publicQueries,failedQuery+1,'Retry performs a new query after the visible failure');
  }finally{
    releaseWrite();releaseQuery();
    if(running)await running.stop();
    mockedRename.mock.restore();syncBuiltinESMExports();
    await rm(directory,{recursive:true,force:true});
  }
});
test('public retry immediately re-fetches failed sources without refreshing account quota',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-public-retry-'));
  let publicQueries=0,quotaQueries=0;
  const {server,stop}=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>{quotaQueries++;return {};},externalQuery:async()=>{
    publicQueries++;
    if(publicQueries===1)throw Error('offline');
    return {status:'ok',announcements:{status:'ok',stale:false,sourceUpdatedAt:new Date().toISOString(),items:[],history:[]}};
  }});
  const base=`http://127.0.0.1:${server.address().port}`;
  try{
    assert.equal((await(await fetch(base+'/api/external')).json()).status,'unavailable');
    await fetch(base+'/api/usage');const beforeQuota=quotaQueries;
    assert.equal((await fetch(base+'/api/external/refresh',{method:'POST',headers:{Origin:'https://attacker.example'}})).status,403);
    assert.equal(publicQueries,1);
    const response=await fetch(base+'/api/external/refresh',{method:'POST',headers:{Origin:base}});
    assert.equal(response.status,200,'A public-only retry endpoint is available');
    const next=await response.json();
    assert.equal(next.status,'ok');assert.equal(next.announcements.stale,false);
    assert.ok(Number.isFinite(next.announcements.lastFetchedAt));
    assert.equal(publicQueries,2,'Retry must not silently reuse the one-minute cache');
    assert.equal(quotaQueries,beforeQuota,'Public retry leaves account fetching independent');
  }finally{await stop();await rm(directory,{recursive:true,force:true});}
});
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
  context.mock.timers.enable({apis:['setInterval','Date'],now:Date.now()});
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
  const item={kind:'regular',certainty:'announced',announcementBasis:'original',statementBasis:'original',sourceUrl:'https://x.com/thsottiaux/status/1000000000000000981',announcedAt:new Date(Date.now()-60000).toISOString()};
  let queries=0;
  const {server,stop}=await startMonitor({port:0,settingsFile:join(directory,'settings.json'),query:async()=>({}),externalQuery:async()=>{
    queries++;return {status:'ok',announcements:{status:'ok',items:[item],history:[],sourceUpdatedAt:new Date().toISOString()}};
  }});
  const base=`http://127.0.0.1:${server.address().port}`;
  const read=async()=>(await(await fetch(base+'/api/announcement-alerts')).json());
  const post=(body,origin=base)=>fetch(base+'/api/announcement-alerts/read',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin},body:JSON.stringify(body)});
  try {
    const external=await(await fetch(base+'/api/external')).json();
    const expected={unread:[{id:item.sourceUrl+'#regular',kind:'regular',version:'["regular",null,null,null,null,null,null,null,null]'}]};
    assert.deepEqual(external.announcementAlerts,expected);
    assert.deepEqual(await read(),expected);
    assert.equal(queries,1,'native alert polling reads the cache only');
    assert.equal((await post({ids:[expected.unread[0].id]},'https://attacker.example')).status,403);
    assert.equal((await post({ids:'all'})).status,400);
    assert.equal((await fetch(base+'/api/announcement-alerts/read',{method:'POST',body:'ids=all'})).status,415);
    assert.deepEqual(await read(),expected,'failed writes never clear unread notices');
    assert.equal((await post({ids:[]})).status,200);
    assert.deepEqual(await read(),expected,'only explicitly viewed IDs are acknowledged');
    assert.equal((await fetch(base+'/preview.mjs')).status,200,'The browser can load the shared preview module');
    assert.equal((await post({ids:[{id:expected.unread[0].id,version:'older'}]})).status,200);
    assert.deepEqual(await read(),expected,'An old visible version cannot clear a newer preview');
    assert.equal((await post({ids:[expected.unread[0]]})).status,200);
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
