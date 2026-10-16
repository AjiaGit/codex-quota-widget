import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { queryExternal, createAnnouncementStore } from '../external.mjs';
import { deriveAnnouncementsView, derivePublicNotice } from '../public/app.mjs';
import { analyzePublicPost } from '../public-evidence.mjs';

// Entirely FABRICATED public responses, identifiers, times and in-memory stores.
const now = Date.parse('2026-10-16T06:00:00Z'), hour = 3600000;
const iso = value => new Date(value).toISOString();
const url = id => `https://x.com/thsottiaux/status/1000000000000000${id}`;
const post = (id, text, at = now - 600000, extra = {}) => ({ id: url(id).split('/').at(-1), url: url(id), text, at: iso(at), kind: 'signal', ...extra });
const feed = (tweets = [], extra = {}) => ({ version: 1, profile: { handle: 'thsottiaux' }, fetched_at: iso(now), stale: false, tweets, events: [], ...extra });
const history = (events = [], extra = {}) => ({ coverage: 'partial', events, ...extra });
const archived = (id, text, extra = {}) => ({ type: 'global_reset', status: 'recorded', source_url: url(id), announced_at: iso(now - 600000), retrieved_at: iso(now), time_basis: 'announcement', evidence_text: text, ...extra });
const query = (primary, backup = history(), at = now) => queryExternal({ now: at, fetchFn: async provider => {
  const value = provider.includes('codex-reset.com/') ? primary : backup;
  if (value instanceof Error) throw value;
  return { ok: true, json: async () => value };
} });
const rows = result => result.announcements.history;
const view = item => deriveAnnouncementsView({ status: 'ok', sourceUpdatedAt: iso(now), items: [item], history: [] }, now, 'UTC', 'zh-CN').rows[0];
async function baseline(file) {
  let clock = now - hour;
  const store = await createAnnouncementStore({ file, now: () => clock });
  await store.update({ status: 'ok', stale: false, sourceUpdatedAt: iso(clock), items: [], history: [] });
  clock = now;
  return store;
}

test('stale primary completion cannot borrow freshness from an unrelated live archive to notify', async () => {
  const store = await baseline();
  const result = await query(feed([post('101', 'Global reset is complete.')], { stale: true }), history([archived('999', 'Global reset recorded.', { announced_at: iso(now - 3 * 24 * hour) })]));
  await store.update(result.announcements);
  assert.deepEqual(store.alerts.unread, []);
  assert.ok(rows(result).find(row => row.sourceUrl === url('101')), 'Keep stale history visible');
});

test('one failed provider remains visible even while a backup successfully supplies records', async () => {
  const result = await query(new Error('FABRICATED offline'), history([archived('102', 'Global reset recorded.')]));
  const notice = derivePublicNotice(result, now, 'UTC', 'zh-CN');
  assert.equal(notice.visible, true);
  assert.match(notice.title, /部分来源/);
  assert.match(notice.help, /codex-reset\.com/);
  assert.equal(result.announcements.providerHealth.find(provider => provider.site === 'codex-reset.com').status, 'unavailable');
});

test('feed freshness expires independently of the 24-hour message display lifetime', async () => {
  const result = await query(feed([], { fetched_at: iso(now - 31 * 60000) }), new Error('FABRICATED offline'));
  assert.equal(result.announcements.stale, true);
  assert.equal(result.announcements.reason, 'source-stale');
});

test('unrelated completion cannot close a promise by time proximity or different account scope', async () => {
  const promise = post('103', 'Global reset by EOD for paid accounts.', now - hour, { conversation_id: '1000000000000000100' });
  const done = post('104', 'Global reset is complete for free accounts.', now - 600000, { conversation_id: '1000000000000000200', in_reply_to_tweet_id: '1000000000000000200' });
  const result = await query(feed([promise, done]));
  assert.equal(rows(result).find(row => row.sourceUrl === promise.url).deliveredAt, null);
  assert.equal(rows(result).length, 2);
});

test('mixed actions bind completion to quota reset and leave reset-credit grant as a promise', async () => {
  const result = await query(feed([post('105', 'Global reset is complete. We will give a banked reset.')]));
  const regular = rows(result).find(row => row.kind === 'regular'), banked = rows(result).find(row => row.kind === 'banked');
  assert.ok(regular?.deliveredAt);
  assert.equal(banked?.certainty, 'announced');
  assert.equal(banked?.deliveredAt, null);
});

test('archive category cannot lend reset context to an unrelated generic completion sentence', async () => {
  const entry = post('106', 'Confirmed landed. The interface redesign is available.');
  const result = await query(feed([entry], { events: [{ url: entry.url, group: 'reset' }] }));
  assert.equal(rows(result).some(row => row.deliveredAt), false);
});

test('full quoted reset context resolves a short completion but unrelated radar posts remain excluded', async () => {
  const promise = post('107', 'Global reset by EOD.', now - hour);
  const completion = post('108', 'Done and dusted', now - 600000, { quoted_tweet: { ...promise, author: { screen_name: 'thsottiaux' } } });
  const result = await query(feed([promise], { radar_context: [completion, post('109', 'Nice. Will fix') ] }));
  const linked = rows(result).find(row => row.sourceUrl === promise.url);
  assert.equal(linked.deliverySourceUrl, completion.url);
  assert.equal(rows(result).length, 1);
});

test('a quote from another author cannot supply missing reset context', async () => {
  const result = await query(feed([], { radar_context: [post('110', 'Done and dusted', now - 600000, { quoted_tweet: { ...post('111', 'Global reset by EOD.'), author: { screen_name: 'someone_else' } } })] }));
  assert.equal(rows(result).some(row => row.deliveredAt), false);
});

test('categorized archive plus context-only short completion stays visible and unverified without inventing a relation', async () => {
  const completion = post('112', 'Done and dusted');
  const result = await query(feed([], { radar_context: [completion] }), history([archived('112', completion.text)]));
  assert.equal(rows(result).length, 1);
  assert.equal(rows(result)[0].deliveredAt, null);
  assert.equal(view(rows(result)[0]).display.category, '待核实消息');
  assert.match(view(rows(result)[0]).display.title, /额度重置消息待核实/);
  const store = await baseline();
  await store.update(result.announcements);
  assert.equal(store.alerts.unread.length, 1);
});

test('website-only reset-credit observations retain website scope and observation time through persistence', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'quota-observation-'));
  try {
    const result = await query(feed([], { banked_observations: [{ id: '1000000000000000113', kind: 'banked', source: 'observed', banked_state: 'available', at: iso(now - 600000), title: 'Banked reset observed', text: 'FABRICATED: monitoring accounts received a reset credit.' }] }));
    assert.equal(rows(result).length, 1);
    const store = await baseline(join(directory, 'cache.json'));
    await store.update(result.announcements);
    const restored = await createAnnouncementStore({ file: join(directory, 'cache.json'), now: () => now });
    const row = view(restored.state.items[0]);
    assert.equal(row.display.category, '完成消息');
    assert.match(row.display.title, /codex-reset\.com 检测到：监测账号收到重置卡/);
    assert.doesNotMatch(row.display.title, /TIBO|Tibo|本账号|所有账号/);
    assert.match(row.completedText, /网站检测/);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('explicit same-post correction clears cached completion while a cropped mirror cannot undo the correction', async () => {
  const store = await baseline();
  await store.update((await query(feed([post('114', 'Global reset is complete.')]))).announcements);
  const correction = post('114', 'Global reset is not complete. The earlier statement was incorrect.');
  await store.update((await query(feed([correction]))).announcements);
  const item = store.state.items.find(row => row.sourceUrl === correction.url);
  assert.equal(item.deliveredAt, null);
  assert.equal(item.correction, 'not-complete');
  await store.update((await query(feed(), history([archived('114', 'Global reset is complete.')]))).announcements);
  assert.equal(store.state.items.find(row => row.sourceUrl === correction.url).deliveredAt, null);
});

test('fresh explicit completion can resolve a correction as a genuinely new update', async () => {
  const store = await baseline();
  for (const text of ['Global reset is complete.', 'Global reset is not complete. The earlier statement was incorrect.', 'Global reset is complete.']) {
    await store.update((await query(feed([post('115', text)]))).announcements);
  }
  assert.ok(store.state.items.find(row => row.sourceUrl === url('115')).deliveredAt);
});

test('unverified to promise to completion notifies at each real stage, never on a mirror or restart', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'quota-stages-'));
  try {
    const file = join(directory, 'cache.json'), store = await baseline(file);
    const entry = post('116', 'Landing within the next 2 hours');
    const input = feed([entry], { events: [{ url: entry.url, group: 'reset' }] });
    await store.update((await query(input)).announcements);
    assert.equal(store.alerts.unread.length, 1);
    await store.acknowledge([entry.url + '#regular']);
    for (const text of ['Global reset by EOD.', 'Global reset is complete.']) {
      await store.update((await query(feed([{ ...entry, text }]))).announcements);
      assert.equal(store.alerts.unread.length, 1, text);
      await store.acknowledge([entry.url + '#regular']);
    }
    await store.update((await query(feed([{ ...entry, text: 'Global reset is complete.' }]), history([archived('116', 'Global reset is complete.')]))).announcements);
    assert.deepEqual(store.alerts.unread, []);
    const restarted = await createAnnouncementStore({ file, now: () => now });
    assert.deepEqual(restarted.alerts.unread, []);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('three presentation categories preserve preview, completion and unresolved semantics in both languages', () => {
  for (const kind of ['regular', 'banked']) {
    const item = { kind, sourceUrl: url('117'), announcedAt: iso(now - 600000), sourceSites: ['codex-reset.com'], announcementBasis: 'original', certainty: 'announced' };
    const preview = view(item), pending = view({ ...item, certainty: 'unconfirmed', announcementBasis: null });
    const completed = view({ ...item, deliveredAt: item.announcedAt, completionTimeBasis: 'announcement' });
    assert.equal(preview.display.category, '预告');
    assert.equal(completed.display.category, '完成消息');
    assert.equal(pending.display.category, '待核实消息');
    assert.match(pending.display.status, /暂无法判断是预告还是完成消息/);
    assert.equal(pending.display.completionMissing, false, 'Do not add a redundant unknown-completion line');
    assert.equal(deriveAnnouncementsView({ items: [item] }, now, 'UTC', 'en').rows[0].display.category, 'Advance notice');
  }
});

test('unknown-kind hints do not guess reset-credit or quota-reset titles', async () => {
  const entry = post('118', 'More details soon');
  const result = await query(feed([entry], { events: [{ url: entry.url, group: 'reset' }] }));
  const row = view(rows(result)[0]);
  assert.equal(row.display.title, '重置相关消息待核实');
  assert.match(row.display.status, /具体事项/);
});

test('website event-only records are retained as attributed unverified updates rather than dropped or promoted', async () => {
  const result = await query(feed([], { events: [{ id: '1000000000000000119', url: url('119'), group: 'reset', source: 'archive', confidence: 'high', announcement_state: 'announced', announced_at: iso(now - 600000), summary: 'FABRICATED archived reset-related update with no original statement.' }] }));
  assert.equal(rows(result).length, 1);
  const item = rows(result)[0];
  assert.equal(item.certainty, 'unconfirmed');
  assert.equal(item.deliveredAt, null);
  assert.deepEqual(item.sourceSites, ['codex-reset.com']);
});

test('backup upstream failure cannot be hidden by freshly generated or retrieved timestamps', async () => {
  const result = await query(new Error('FABRICATED primary offline'), { status: 'unknown', resetArchiveSyncedAt: iso(now - hour), generatedAt: iso(now), sources: [{ id: 'codex-resets', status: 'error', checked_at: iso(now) }], events: [archived('120', 'Global reset is complete.')] });
  assert.equal(result.announcements.stale, true);
  const store = await baseline();
  await store.update(result.announcements);
  assert.deepEqual(store.alerts.unread, []);
});

test('public refresh cadence accelerates only a recent pending message and backs off for rate limits', async () => {
  const { externalRefreshDelay } = await import('../monitor.mjs');
  assert.equal(typeof externalRefreshDelay, 'function');
  const waiting = { announcements: { items: [{ certainty: 'announced', announcedAt: iso(now - 600000) }] } };
  assert.equal(externalRefreshDelay(waiting, now), 120000);
  assert.equal(externalRefreshDelay(waiting, now + 3 * hour), 600000);
  assert.equal(externalRefreshDelay({ announcements: { items: [{ ...waiting.announcements.items[0], deliveredAt: iso(now) }] } }, now), 600000);
  assert.equal(externalRefreshDelay({ announcements: { ...waiting.announcements, providerHealth: [{ retryAfterMs: 900000 }] } }, now), 900000);
  assert.equal(externalRefreshDelay({ announcements: { ...waiting.announcements, providerHealth: [{ status:'unavailable', retryAfterMs:900000 },{ status:'ok' }] } }, now), 120000, 'One throttled source cannot stop the working provider');
  const unavailable={announcements:{providerHealth:[{status:'unavailable'},{status:'unavailable'}]}};
  assert.equal(externalRefreshDelay(unavailable,now,1),60000);
  assert.equal(externalRefreshDelay(unavailable,now,3),240000);
});

test('Retry-After suppresses repeated manual provider requests until the source cooldown expires', async () => {
  const backoff = new Map();
  let requests = 0;
  const fetchFn = async provider => {
    if (!provider.includes('codex-reset.com/')) return { ok: true, json: async () => history([archived('121', 'Global reset recorded.')]) };
    requests++;
    return { ok: false, status: 429, headers: { get: () => '900' } };
  };
  await queryExternal({ now, fetchFn, backoff });
  await queryExternal({ now: now + 60000, fetchFn, backoff });
  assert.equal(requests, 1);
  await queryExternal({ now: now + 901000, fetchFn, backoff });
  assert.equal(requests, 2);
});

test('both actions in one post keep separate unread identities instead of treating one as a corrected category', async () => {
  const store = await baseline();
  const result = await query(feed([post('122', 'Global reset is complete. We will give a banked reset.')]));
  await store.update(result.announcements);
  assert.equal(store.state.items.length, 2);
  assert.deepEqual(store.alerts.unread.map(row => row.kind).sort(), ['banked', 'regular']);
  await store.acknowledge([url('122') + '#regular']);
  assert.deepEqual(store.alerts.unread.map(row => row.kind), ['banked']);
});

test('bounded diagnostics explain ignored context without persisting message bodies', async () => {
  const entry = post('123', 'FABRICATED unrelated private-looking text that must not be logged');
  const result = await query(feed([], { radar_context: [entry] }));
  assert.ok(result.announcements.diagnostics.some(row => row.postId === entry.id && row.reason === 'no-reset-context'));
  assert.doesNotMatch(JSON.stringify(result.announcements.diagnostics), /private-looking text/);
});

test('partial rollout and a prepared reset do not become global completion claims', async () => {
  for (const text of ['Global reset is complete for some accounts.', 'The banked reset is ready.', 'The banked reset UI patch is ready. It is done.']) {
    const result = await query(feed([post('124', text)]));
    assert.equal(rows(result).some(row => row.deliveredAt), false, text);
  }
});

test('a correction to a linked completion also releases its previously paired promise', async () => {
  const store = await baseline();
  const promise = post('125', 'Global reset by EOD.', now - 1200000);
  const completed = post('126', 'Global reset is complete.', now - 600000, { in_reply_to_tweet_id: promise.id });
  await store.update((await query(feed([promise, completed]))).announcements);
  assert.ok(store.state.items.find(row => row.sourceUrl === promise.url).deliveredAt);
  await store.update((await query(feed([promise, { ...completed, text: 'Global reset is not complete. The earlier statement was incorrect.' }]))).announcements);
  assert.equal(store.state.items.some(row => row.deliveredAt), false);
});

test('explicit website observation in an archive event is shown with monitoring scope and a site-record timestamp', async () => {
  const event={id:'1000000000000000127',url:url('127'),group:'reset',source:'archive',announced_at:iso(now-600000),
    summary:'FABRICATED: The global reset arrived on our checks; publication is reported separately.'};
  const result=await query(feed([], {events:[event]}));
  const record=rows(result).find(row=>row.statementBasis==='observation');
  assert.ok(record);
  assert.equal(record.completionTimeBasis,'site-report');
  const row=view(record);
  assert.match(row.display.title,/监测账号额度已恢复/);
  assert.match(row.completedText,/网站记录/);
  assert.doesNotMatch(row.completedText,/完成消息发布|本机发现/);
  for(const summary of ['The global reset has not arrived on our checks.','If the global reset arrived on our checks, we would report it.',
    'The interface redesign arrived on our checks.', 'The banked reset arrived on our checks.']) {
    const negative=await query(feed([], {events:[{...event,summary}]}));
    assert.equal(rows(negative).some(row=>row.deliveredAt),false);
  }
});

test('a stale stage cannot consume the first fresh stage notification, including after restart', async () => {
  const directory=await mkdtemp(join(tmpdir(),'quota-fresh-stage-'));
  try {
    for(const [index,initial,next] of [[1,'Global reset by EOD.','Global reset is complete.'],[2,'More details soon','Global reset by EOD.']]) {
      const file=join(directory,`${index}.json`),entry=post('201'+index,initial);
      const store=await baseline(file),events=[{url:entry.url,group:'reset'}];
      await store.update((await query(feed([entry],{events}))).announcements);
      await store.acknowledge([entry.url+'#regular']);
      await store.update((await query(feed([{...entry,text:next}],{events,stale:true}))).announcements);
      assert.deepEqual(store.alerts.unread,[]);
      const restarted=await createAnnouncementStore({file,now:()=>now});
      const fresh=(await query(feed([{...entry,text:next}],{events}))).announcements;
      await restarted.update(fresh);
      assert.equal(restarted.alerts.unread.length,1,next);
      await restarted.acknowledge([entry.url+'#regular']);
      await restarted.update(fresh);
      assert.deepEqual(restarted.alerts.unread,[]);
    }
  } finally {await rm(directory,{recursive:true,force:true});}
});

test('an older stale original cannot roll back a fresh explicit correction or its timestamp',async()=>{
  const store=await baseline(),entry=post('202','Global reset is not complete. The earlier statement was incorrect.');
  await store.update((await query(feed([entry]))).announcements);
  await store.update((await query(feed([{...entry,text:'Global reset is complete.'}],{stale:true,fetched_at:iso(now-hour)}))).announcements);
  const item=store.state.items.find(row=>row.sourceUrl===entry.url);
  assert.equal(item.correction,'not-complete');
  assert.equal(item.deliveredAt,null);
  assert.equal(item.evidenceUpdatedAt,iso(now));
});

test('a bare completion reply to two different promised actions cannot choose either action',async()=>{
  const promise=post('203','Global reset by EOD. We will give a banked reset tomorrow.',now-1200000);
  const done=post('204','Done and dusted',now-600000,{in_reply_to_tweet_id:promise.id});
  const result=await query(feed([promise,done]));
  assert.equal(rows(result).some(row=>row.deliveredAt),false);
  assert.equal(rows(result).filter(row=>row.certainty==='announced').length,2);
});

test('a correction about reset credits cannot erase a quota completion in the same post',async()=>{
  const promise=post('205','Global reset by EOD.',now-1200000);
  const done=post('206','Global reset is complete. No banked reset has been granted.',now-600000,{in_reply_to_tweet_id:promise.id});
  const result=await query(feed([promise,done]));
  assert.ok(rows(result).find(row=>row.sourceUrl===promise.url)?.deliveredAt);
  assert.equal(rows(result).find(row=>row.kind==='banked')?.correction,'not-complete');
});

test('negating cancellation or delay is not itself a cancellation or delay correction',()=>{
  for(const word of ['cancelled','canceled','delayed','postponed']) {
    assert.equal(analyzePublicPost(post('207',`Global reset is not ${word}.`))[0].correction,null,word);
    assert.equal(analyzePublicPost(post('207',`Global reset is ${word}.`))[0].correction,
      ['cancelled','canceled'].includes(word)?'cancelled':'delayed',word);
  }
});

test('conflicting nested quote identity cannot be rescued by a valid flat quote identifier',async()=>{
  const promise=post('208','Global reset by EOD.',now-1200000);
  for(const quoted of [
    {...promise,author:{screen_name:'other_author'}},
    {...promise,url:url('209'),author:{screen_name:'thsottiaux'}},
    {...promise,id:'1000000000000000999',author:{screen_name:'thsottiaux'}},
  ]) {
    const done=post('210','Done and dusted',now-600000,{quoted_tweet:quoted,quoted_tweet_id:promise.id});
    assert.equal(rows(await query(feed([promise,done]))).some(row=>row.deliveredAt),false);
  }
});

test('an explicit related cancellation updates the original promise but unrelated corrections do not',async()=>{
  const promise=post('211','Global reset by EOD.',now-1200000);
  for(const [relation,expected] of [[promise.id,'cancelled'],['1000000000000000999',null]]) {
    const correction=post('212','Global reset is cancelled.',now-600000,{in_reply_to_tweet_id:relation});
    const result=await query(feed([promise,correction]));
    assert.equal(rows(result).find(row=>row.sourceUrl===promise.url)?.correction,expected);
  }
});

test('an unverified backup-only update opens the website that supplied it',async()=>{
  const result=await query(feed(),history([archived('213','Global reset recorded.')]));
  assert.equal(view(rows(result)[0]).monitorSourceUrl,'https://codexreset.dev/');
});

test('upgrading a legacy cache does not replay a read linked completion',async()=>{
  const directory=await mkdtemp(join(tmpdir(),'quota-legacy-stage-'));
  try {
    const file=join(directory,'cache.json'),store=await baseline(file);
    const promise=post('214','Global reset by EOD.',now-1200000);
    const done=post('215','Global reset is complete.',now-600000,{in_reply_to_tweet_id:promise.id});
    const fresh=(await query(feed([promise,done]))).announcements;
    await store.update(fresh);
    await store.acknowledge(store.alerts.unread.map(item=>item.id));
    const saved=JSON.parse(await readFile(file,'utf8'));
    delete saved.alertTracking.observedStages;
    await writeFile(file,JSON.stringify(saved));
    const upgraded=await createAnnouncementStore({file,now:()=>now});
    await upgraded.update(fresh);
    assert.deepEqual(upgraded.alerts.unread,[]);
  } finally {await rm(directory,{recursive:true,force:true});}
});
