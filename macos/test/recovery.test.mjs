import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import * as view from '../public/app.mjs';
let createRecoveryStore;
try { ({ createRecoveryStore } = await import('../recovery.mjs')); } catch {}
const initial = Date.parse('2026-10-07T03:20:00Z');
const quota = (remainingPercent, resetsAt = 1791590460) => ({ remainingPercent, resetsAt, plan:'pro' });
async function fixture(run) {
  assert.equal(typeof createRecoveryStore,'function');
  const directory=await mkdtemp(join(tmpdir(),'quota-recovery-'));
  let time=initial;
  const file=join(directory,'recovery.json');
  const open=()=>createRecoveryStore({file,now:()=>time});
  try { await run({file,open,tick:(ms=60000)=>{time+=ms;}}); }
  finally { await rm(directory,{recursive:true,force:true}); }
}
test('recovery records start with a baseline and capture observed increases without claiming a global reset',async()=>fixture(async({open,tick})=>{
  const store=await open();
  assert.deepEqual((await store.observe('account-a',quota(45))).records,[]);
  tick();
  const view=await store.observe('account-a',quota(99,1791948588));
  assert.equal(view.records.length,1);
  assert.deepEqual(view.records[0],{observedFrom:initial,detectedAt:initial+60000,beforePercent:45,afterPercent:99,previousResetsAt:1791590460,resetsAt:1791948588});
  assert.equal(view.trackingSince,initial);
  tick();
  assert.equal((await store.observe('account-a',quota(99,1791948588))).records.length,1,'Polling never duplicates a recovery');
}));
test('a recovery can occur without changing the scheduled window, and usage decreases are not recoveries',async()=>fixture(async({open,tick})=>{
  const store=await open();await store.observe('account-a',quota(45));tick();
  assert.equal((await store.observe('account-a',quota(44))).records.length,0);tick();
  assert.equal((await store.observe('account-a',quota(99))).records.length,1);
}));
test('account switches and plan changes never become false recovery records',async()=>fixture(async({open,tick})=>{
  const store=await open();await store.observe('account-a',quota(45));tick();
  assert.equal((await store.observe('account-b',quota(100))).records.length,0);tick();
  assert.equal((await store.observe('account-a',{...quota(99),plan:'plus'})).records.length,0);
}));
test('restart preserves account-specific records and the last successful observation',async()=>fixture(async({open,tick})=>{
  let store=await open();await store.observe('account-a',quota(45));tick();
  store=await open();assert.equal((await store.observe('account-a',quota(99))).records.length,1);tick();
  store=await open();assert.equal((await store.observe('account-a',quota(98))).records.length,1);
  assert.equal((await store.observe('account-b',quota(100))).records.length,0);
}));
test('missing identity, expired and invalid snapshots do not fabricate or replace a baseline',async()=>fixture(async({open,tick})=>{
  const store=await open();await store.observe('account-a',quota(45));tick();
  for(const value of [quota(NaN),quota(101),quota(100,1)])assert.equal((await store.observe('account-a',value)).status,'unavailable');
  assert.equal((await store.observe(null,quota(100))).status,'unavailable');
  assert.equal((await store.observe('account-a',quota(99))).records[0].beforePercent,45);
}));
test('the file contains salted opaque identifiers and no raw account identity',async()=>fixture(async({file,open})=>{
  const store=await open();await store.observe('private-account@example.org',quota(45));
  const text=await readFile(file,'utf8');
  assert.ok(!text.includes('private-account@example.org'));
  assert.match(Object.keys(JSON.parse(text).accounts)[0],/^[a-f0-9]{64}$/);
}));
test('saved snapshots are validated and only public record fields are restored',async()=>fixture(async({file,open,tick})=>{
  let store=await open();await store.observe('account-a',quota(45));tick();await store.observe('account-a',quota(99));
  const saved=JSON.parse(await readFile(file,'utf8')),account=Object.values(saved.accounts)[0];
  account.records[0].email='private-extra@example.org';account.previous.email='private-extra@example.org';
  account.records.push({...account.records[0],afterPercent:120});
  await writeFile(file,JSON.stringify(saved));tick();store=await open();
  const result=await store.observe('account-a',quota(98));
  assert.equal(result.records.length,1);assert.ok(!JSON.stringify(result).includes('private-extra'));
  assert.ok(!(await readFile(file,'utf8')).includes('private-extra'));
}));
test('storage failure preserves live observations with an explicit unsaved status',async()=>fixture(async({file,tick})=>{
  await writeFile(file,'not a directory');
  const store=await createRecoveryStore({file:join(file,'blocked.json'),now:()=>initial});
  assert.equal((await store.observe('account-a',quota(45))).status,'unsaved');
}));
test('a recovery evidenced by earlier local queries survives restart with an unknown previous reset date',async()=>fixture(async({file,open,tick})=>{
  let store=await open();await store.observe('account-a',quota(45));tick();await store.observe('account-a',quota(99));
  const saved=JSON.parse(await readFile(file,'utf8')),account=Object.values(saved.accounts)[0];
  account.records[0].previousResetsAt=null;
  await writeFile(file,JSON.stringify(saved));tick();store=await open();
  const result=await store.observe('account-a',quota(98));
  assert.equal(result.records.length,1);
  assert.equal(result.records[0].beforePercent,45);
  assert.equal(result.records[0].afterPercent,99);
  assert.equal(result.records[0].previousResetsAt,null,'An unknown historical reset date is not invented');
}));
test('local records are bounded and sorted with the latest detection first',async()=>fixture(async({open,tick})=>{
  const store=await open();await store.observe('account-a',quota(0));
  let view;
  for(let i=0;i<55;i++){tick();await store.observe('account-a',quota(0));tick();view=await store.observe('account-a',quota(99));}
  assert.equal(view.records.length,50);
  assert.ok(view.records[0].detectedAt>view.records[49].detectedAt);
}));
test('recovery presentation uses local detection times and distinguishes first use from unavailable tracking',()=>{
  assert.equal(typeof view.deriveRecoveryView,'function');
  const state={status:'ok',recoveryHistory:{status:'ok',trackingSince:initial,records:[{observedFrom:initial,detectedAt:initial+60000,beforePercent:45,afterPercent:99}]}};
  for(const language of ['en','zh-CN']) {
    const result=view.deriveRecoveryView(state,language,'Asia/Shanghai',initial+120000);
    assert.equal(result.rows[0].change,'45% → 99%');
    assert.match(result.rows[0].detected,/11:21/);
    assert.match(result.rows[0].observed,/11:20/);
    assert.match(result.rows[0].detected,/UTC\+08:00/);
    assert.ok(result.note.length>10);
  }
  assert.match(view.deriveRecoveryView({...state,recoveryHistory:{status:'ok',trackingSince:initial,records:[]}},'en').empty,/No new quota recovery/);
  assert.match(view.deriveRecoveryView({status:'unavailable'},'en').empty,/Refresh/);
});
test('reset activity merges personal recoveries with public news without implying global delivery',()=>{
  const now=initial+120000;
  const data={status:'ok',recoveryHistory:{status:'ok',trackingSince:initial,records:[{observedFrom:initial,detectedAt:initial+60000,beforePercent:45,afterPercent:99}]}};
  const feed={status:'ok',sourceUpdatedAt:new Date(initial).toISOString(),items:[{id:'public',kind:'regular',announcedAt:new Date(initial).toISOString(),sourceUrl:'https://example.org/reset',certainty:'unconfirmed'}],history:[]};
  assert.equal(typeof view.deriveResetActivityView,'function');
  for(const language of ['en','zh-CN']) {
    const activity=view.deriveResetActivityView(data,feed,now,'Asia/Shanghai',language);
    assert.deepEqual(activity.rows.map(row=>row.kind),['recovery','regular']);
    assert.equal(activity.rows[0].change,'45% → 99%');
    assert.equal(activity.rows[1].phase,'unconfirmed');
    assert.deepEqual(view.announcementIdsForReading({unread:[{id:'public',kind:'regular'}]},activity.publicView,true),['public']);
  }
});
test('older personal recoveries share history and empty personal history creates no extra activity row',()=>{
  const now=initial+86400000;
  const data={status:'ok',recoveryHistory:{status:'ok',trackingSince:initial-60000,records:[{observedFrom:initial-60000,detectedAt:initial,beforePercent:45,afterPercent:99}]}};
  const feed={status:'ok',sourceUpdatedAt:new Date(now).toISOString(),items:[],history:[{id:'old-public',kind:'regular',announcedAt:new Date(initial-3600000).toISOString(),sourceUrl:'https://example.org/reset'}]};
  assert.equal(typeof view.deriveResetActivityView,'function');
  const activity=view.deriveResetActivityView(data,feed,now,'UTC','en');
  assert.equal(activity.rows.length,0);
  assert.deepEqual(activity.history.map(row=>row.kind),['recovery','regular']);
  const empty=view.deriveResetActivityView({...data,recoveryHistory:{...data.recoveryHistory,records:[]}},feed,now,'UTC','en');
  assert.equal(empty.rows.length,0);
  assert.equal(empty.history.length,1);
});
