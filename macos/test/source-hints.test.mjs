import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { queryExternal, createAnnouncementStore } from '../external.mjs';
import { deriveAnnouncementsView, deriveResetActivityView, announcementIdsForReading, visibleAnnouncementView } from '../public/app.mjs';

// FABRICATED IDs, timestamps and responses; wording reproduces a missed public signal.
const now = Date.parse('2026-10-15T06:00:00Z');
const hour = 3600000;
const parent = { id: '1000000000000000100', url: 'https://x.com/thsottiaux/status/1000000000000000100',
  text: 'Day 10/ Reset', at: '2026-10-15T04:55:00Z', kind: 'other' };
const reply = { id: '1000000000000000101', url: 'https://x.com/thsottiaux/status/1000000000000000101',
  text: 'Landing within the next 2 hours', at: '2026-10-15T04:56:00Z', kind: 'signal',
  is_reply: true, replying_to: 'thsottiaux', in_reply_to_tweet_id: parent.id, conversation_id: parent.id };
const headline = post => ({ tweet_id: post.id, url: post.url, summary: post.text, at: post.at, kind: 'signal', active: true });
const feed = (posts = [reply, parent], extra = {}) => ({ version: 1, profile: { handle: 'thsottiaux' },
  fetched_at: new Date(now).toISOString(), stale: false, tweets: posts, signal: headline(reply),
  events: posts.filter(post => post.kind === 'signal').map(post => ({ id: post.id, url: post.url, group: 'reset',
    type: 'reset', announcement_state: 'none', summary: post.text, announced_at: post.at })), ...extra });
const query = (data, time = now, backup = { coverage: 'partial', events: [] }) => queryExternal({ now: time,
  fetchFn: async url => { const body = url.endsWith('/api/feed') ? data : backup;
    if (body instanceof Error) throw body;
    return { ok: true, json: async () => body };
  } });
const archiveReply = (type = 'global_reset') => ({ coverage: 'partial', events: [{ type, status: 'recorded',
  source_url: reply.url, announced_at: reply.at, retrieved_at: new Date(now).toISOString(),
  time_basis: 'announcement', evidence_text: reply.text }] });

test('a fresh archive cannot erase cached hint attribution, revive an inactive hint, or refresh its source', async () => {
  for (const active of [true, false]) {
    const store = await createAnnouncementStore({ now: () => now });
    await store.update((await query(feed([reply], { signal: { ...headline(reply), active } }))).announcements);
    await store.update((await query(new Error('FABRICATED primary offline'), now, archiveReply())).announcements);
    const item = store.state.history[0];
    assert.equal(item.sourceHint, active ? 'active' : 'inactive');
    assert.equal(item.sourceWithdrawn, !active);
    assert.equal(store.state.items.length, active ? 1 : 0);
    if (active) assert.equal(store.state.stale, true, 'Fresh backup evidence does not refresh the unavailable hint source');
    assert.deepEqual(store.alerts.unread, []);
  }
});

test('conflicting mirror categories still produce one attributed hint for the same post across partial refreshes', async () => {
  const credits = feed([reply], { events: [{ url: reply.url, group: 'credits' }] });
  const result = await query(credits, now, archiveReply());
  assert.equal(result.announcements.items.length, 1);
  assert.equal(result.announcements.items[0].sourceHint, 'active');
  assert.equal(result.lastGlobal, null);
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(credits)).announcements);
  await store.update((await query(new Error('FABRICATED primary offline'), now, archiveReply())).announcements);
  assert.equal(store.state.items.length, 1);
  assert.equal(store.state.history.length, 1);
  assert.equal(store.state.items[0].sourceHint, 'active');
  assert.equal(store.state.stale, true);
});

test('a validated inactive headline withdraws a known hint even when a partial timeline omits its post', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed())).announcements);
  const inactive = { ...headline(reply), active: false };
  for (const extra of [
    { signal: inactive, stale: true },
    { signal: { ...inactive, tweet_id: '999' } },
    { signal: inactive, profile: { handle: 'someone_else' } },
  ]) {
    await store.update((await query(feed([], extra), now, archiveReply())).announcements);
    assert.equal(store.state.items.length, 1, 'Stale or mismatched source evidence cannot withdraw a hint');
  }
  await store.update((await query(feed([], { signal: inactive }))).announcements);
  assert.equal(store.state.items.length, 0);
  assert.equal(store.state.history[0].sourceHint, 'inactive');
  const empty = await createAnnouncementStore({ now: () => now });
  await empty.update((await query(feed([], { signal: inactive }))).announcements);
  assert.equal(empty.state.history.length, 0, 'A headline status cannot invent an unseen record');
});

test('a source headline displays a subjectless reply without confirming a reset or inventing a deadline', async () => {
  const result = await query(feed());
  assert.equal(result.announcements.items.length, 1);
  const item = result.announcements.items[0];
  assert.equal(item.sourceUrl, reply.url);
  assert.equal(item.announcedAt, '2026-10-15T04:56:00.000Z');
  assert.equal(item.certainty, 'unconfirmed');
  assert.equal(item.deliveredAt, null);
  assert.equal(item.scheduledAt, null);
  assert.equal(result.lastGlobal, null, 'A site hint is not the latest confirmed public reset');
  for (const [language, title, status] of [
    ['zh-CN', '重置相关消息待核实', '暂无法判断具体事项，以及是预告还是完成消息。'],
    ['en', 'Reset update awaiting verification', 'The event type and whether this is an advance notice or a completion message are unclear.'],
  ]) {
    const row = deriveAnnouncementsView(result.announcements, now, 'Asia/Shanghai', language).rows[0];
    assert.equal(row.display.title, title);
    assert.equal(row.display.status, status);
    assert.equal(row.monitorSourceUrl, 'https://codex-reset.com/');
    assert.equal(row.sourceUrl, reply.url);
    assert.equal(row.summary, reply.text);
    assert.equal(row.completedText, '');
    assert.equal(row.plannedText, '');
    assert.equal(row.display.completionMissing, false, 'Do not imply that only the completion time is missing');
    assert.equal(deriveResetActivityView({ status: 'unavailable' }, result.announcements, now, 'UTC', language).rows[0].id, item.id);
  }
});

test('recent website-classified signals survive headline replacement without showing unrelated posts', async () => {
  const next = { ...reply, id: '1000000000000000102', url: 'https://x.com/thsottiaux/status/1000000000000000102',
    text: 'More details shortly', at: '2026-10-15T05:15:00Z' };
  const unrelated = { ...parent, id: '1000000000000000103', url: 'https://x.com/thsottiaux/status/1000000000000000103',
    text: 'A faster editor is coming', kind: 'boost' };
  const result = await query(feed([next, reply, parent, unrelated], { signal: headline(next) }));
  assert.deepEqual(deriveAnnouncementsView(result.announcements, now, 'UTC', 'en').rows.map(item => item.sourceUrl), [next.url, reply.url]);
  assert.equal(result.lastGlobal, null);
});

test('source hints require matching author, post identity, website reset classification and fresh timestamps', async () => {
  const cases = [
    feed([reply], { profile: { handle: 'someone_else' } }),
    feed([{ ...reply, url: 'https://example.org/not-tibo' }]),
    feed([{ ...reply, id: '1000000000000000999' }]),
    feed([{ ...reply, at: '2026-10-15T07:00:00Z' }]),
    feed([{ ...reply, at: '2026-10-14T04:56:00Z' }]),
    feed([reply], { fetched_at: '2026-10-13T06:00:00Z' }),
    feed([reply], { stale: true }),
    feed([{ ...reply, kind: 'boost' }], { signal: { ...headline(reply), kind: 'boost' } }),
    feed([reply], { events: [] }),
    feed([reply], { events: [{ url: reply.url, group: 'boost' }] }),
  ];
  for (const data of cases) assert.deepEqual((await query(data)).announcements.items, []);
  const forged = feed([reply], { signal: { ...headline(reply), tweet_id: '1000000000000000999' }, events: [] });
  assert.deepEqual((await query(forged)).announcements.items, []);
});

test('a fresh backup cannot make stale primary hints current', async () => {
  const backup = { coverage: 'partial', events: [{ type: 'global_reset', status: 'recorded',
    source_url: parent.url, announced_at: '2026-10-13T05:00:00Z', effective_at: '2026-10-13T05:00:00Z',
    retrieved_at: new Date(now).toISOString(), time_basis: 'announcement', evidence_text: 'All propagated.' }] };
  const result = await query(feed([reply], { stale: true }), now, backup);
  assert.equal(result.announcements.items.some(item => item.sourceUrl === reply.url), false);
});

test('new hints notify once, survive restart unread, and stay read after viewing without confirming a reset', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'quota-source-hints-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  let clock = now - 2 * hour;
  const file = join(dir, 'announcements.json');
  const store = await createAnnouncementStore({ file, now: () => clock });
  await store.update((await query(feed([], { signal: null, fetched_at: new Date(clock).toISOString() }), clock)).announcements);
  clock = now;
  const incoming = (await query(feed())).announcements;
  await store.update(incoming);
  await store.update(incoming);
  assert.equal(store.state.items.length, 1);
  const expected = [{ id: reply.url + '#regular', kind: 'regular', sourceHint: true }];
  assert.deepEqual(store.alerts.unread, expected);
  const restored = await createAnnouncementStore({ file, now: () => clock });
  await restored.update(incoming);
  assert.equal(restored.state.items.length, 1);
  assert.equal(deriveAnnouncementsView(restored.state, clock, 'UTC', 'en').rows[0].display.title, 'Reset update awaiting verification');
  assert.deepEqual(restored.alerts.unread, expected);
  assert.equal(restored.state.items[0].certainty, 'unconfirmed');
  assert.equal(restored.state.items[0].deliveredAt, null);
  assert.equal(restored.state.items[0].scheduledAt, null);
  await restored.acknowledge(expected.map(item => item.id));
  const viewed = await createAnnouncementStore({ file, now: () => clock });
  await viewed.update(incoming);
  assert.deepEqual(viewed.alerts.unread, []);
  assert.equal(viewed.state.items[0].sourceHint, 'active');
});

async function trackedStore() {
  let clock = now - 2 * hour;
  const store = await createAnnouncementStore({ now: () => clock });
  await store.update((await query(feed([], { signal: null, fetched_at: new Date(clock).toISOString() }), clock)).announcements);
  clock = now;
  return { store, setTime: value => { clock = value; } };
}

test('first lookup and late historical hints do not create a backlog of unread notices', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed())).announcements);
  assert.deepEqual(store.alerts.unread, []);
  const { store: tracked } = await trackedStore();
  const old = { ...reply, at: '2026-10-15T03:00:00Z' };
  await tracked.update((await query(feed([old], { signal: headline(old) }))).announcements);
  assert.deepEqual(tracked.alerts.unread, []);
});

test('offline refresh and archival preserve unread hints until the visible record is read', async () => {
  const { store, setTime } = await trackedStore();
  await store.update((await query(feed())).announcements);
  await store.update((await query(new Error('FABRICATED offline'), now, archiveReply())).announcements);
  assert.equal(store.alerts.unread.length, 1);
  setTime(now + 24 * hour);
  await store.update({ status: 'unavailable' });
  const activity = deriveResetActivityView({ status: 'unavailable' }, store.state, now + 24 * hour, 'UTC', 'en');
  const visible = visibleAnnouncementView(activity);
  assert.deepEqual(announcementIdsForReading(store.alerts, visible, false), []);
  const expanded = visibleAnnouncementView(activity);
  const viewed = announcementIdsForReading(store.alerts, expanded, true);
  assert.deepEqual(viewed, [reply.url + '#regular']);
  await store.acknowledge(viewed);
  assert.deepEqual(store.alerts.unread, []);
});

test('reading the first unified page leaves the sixth hint unread until more is loaded', async () => {
  const { store } = await trackedStore();
  const newer=Array.from({length:5},(_,i)=>({...reply,id:'100000000000000012'+i,url:'https://x.com/thsottiaux/status/100000000000000012'+i,at:`2026-10-15T05:0${i}:00Z`}));
  await store.update((await query(feed([...newer,reply],{signal:headline(newer[4])}))).announcements);
  const activity=deriveResetActivityView({status:'unavailable'},store.state,now,'UTC','en');
  const visible=visibleAnnouncementView(activity);
  assert.deepEqual(announcementIdsForReading(store.alerts,visible,false),[]);
  const viewed=announcementIdsForReading(store.alerts,visible,true);
  assert.equal(viewed.length,5);
  assert.equal(viewed.includes(reply.url+'#regular'),false);
  await store.acknowledge(viewed);
  assert.deepEqual(store.alerts.unread.map(item=>item.id),[reply.url+'#regular']);
  await store.acknowledge(announcementIdsForReading(store.alerts,visibleAnnouncementView(activity,{limit:10}),true));
  assert.deepEqual(store.alerts.unread,[]);
});

test('source hint category corrections migrate unread identity without alerting again after reading', async () => {
  const { store } = await trackedStore();
  const credits = feed([reply], { events: [{ url: reply.url, group: 'credits' }] });
  await store.update((await query(credits)).announcements);
  assert.deepEqual(store.alerts.unread, [{ id: reply.url + '#banked', kind: 'banked', sourceHint: true }]);
  await store.update((await query(credits, now, archiveReply())).announcements);
  assert.deepEqual(store.alerts.unread, [{ id: reply.url + '#regular', kind: 'regular', sourceHint: true }]);
  await store.acknowledge([reply.url + '#regular']);
  await store.update((await query(credits)).announcements);
  assert.deepEqual(store.alerts.unread, []);
});

test('a stale confirmation updates an existing unread hint type without reviving a read notice', async () => {
  for (const alreadyRead of [false, true]) {
    const { store } = await trackedStore();
    const id = reply.url + '#regular';
    await store.update((await query(feed())).announcements);
    assert.deepEqual(store.alerts.unread, [{ id, kind: 'regular', sourceHint: true }]);
    if (alreadyRead) await store.acknowledge([id]);
    const promise = { ...reply, text: 'Global reset landing tomorrow.' };
    for (const stale of [true, false]) {
      await store.update((await query(feed([promise], { signal: headline(promise), stale }))).announcements);
      assert.equal(store.state.items[0].certainty, 'announced');
      assert.equal(store.state.items[0].sourceHint, null);
      assert.deepEqual(store.alerts.unread, alreadyRead ? [] : [{ id, kind: 'regular' }]);
    }
    await store.acknowledge([id]);
    await store.update((await query(feed([promise], { signal: headline(promise) }))).announcements);
    assert.deepEqual(store.alerts.unread, []);
  }
});

test('stale and inactive site signals cannot create or revive unread notices', async () => {
  const { store } = await trackedStore();
  await store.update((await query(feed([reply], { stale: true }), now, archiveReply())).announcements);
  assert.equal(store.alerts.unread.length, 1, 'A fresh archive can independently supply an unverified update');
  await store.acknowledge([reply.url + '#regular']);
  await store.update((await query(feed())).announcements);
  assert.deepEqual(store.alerts.unread, [], 'A second collecting site is not a new message stage');
  await store.update((await query(feed([], { signal: { ...headline(reply), active: false } }))).announcements);
  assert.deepEqual(store.alerts.unread, []);
  await store.update((await query(feed([reply], { signal: null }))).announcements);
  assert.deepEqual(store.alerts.unread, []);
});

test('an explicit stop clears an unread hint even after it has moved into history', async () => {
  const { store, setTime } = await trackedStore();
  await store.update((await query(feed())).announcements);
  assert.equal(store.alerts.unread.length, 1);
  const later = now + 24 * hour;
  setTime(later);
  await store.update({ status: 'unavailable' });
  assert.equal(store.state.items.length, 0);
  assert.equal(store.alerts.unread.length, 1);
  await store.update((await query(feed([], { signal: { ...headline(reply), active: false }, fetched_at: new Date(later).toISOString() }), later)).announcements);
  assert.equal(store.state.history[0].sourceHint, 'inactive');
  assert.deepEqual(store.alerts.unread, []);
});

test('failed refresh keeps a stale hint and its original expiry instead of withdrawing or renewing it', async () => {
  let clock = now;
  const store = await createAnnouncementStore({ now: () => clock });
  await store.update((await query(feed())).announcements);
  clock += hour;
  await store.update((await query(new Error('FABRICATED offline'), clock)).announcements);
  assert.equal(store.state.items.length, 1);
  assert.equal(store.state.items[0].sourceWithdrawn, false);
  assert.equal(store.state.stale, true);
  clock = Date.parse(reply.at) + 24 * hour;
  await store.update((await query(feed([reply], { fetched_at: new Date(clock).toISOString() }), clock)).announcements);
  assert.equal(store.state.items.length, 0);
  assert.equal(store.state.history.length, 1);
  const row = deriveAnnouncementsView(store.state, clock, 'UTC', 'en').history[0];
  assert.match(row.display.status, /Earlier site hint; subsequent progress is unknown/);
  assert.equal(row.completedText, '');
  assert.deepEqual(store.alerts.unread, []);
});

test('explicitly inactive source hints stay inactive through partial feeds and can be explicitly reactivated', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed())).announcements);
  await store.update((await query(feed([reply], { signal: { ...headline(reply), active: false } }))).announcements);
  assert.equal(store.state.items.length, 0);
  assert.equal(store.state.history[0].sourceWithdrawn, true);
  await store.update((await query(feed([reply], { signal: null }))).announcements);
  assert.equal(store.state.items.length, 0, 'A retained timeline entry does not undo an explicit inactive signal');
  await store.update((await query(feed())).announcements);
  assert.equal(store.state.items.length, 1);
  assert.deepEqual(store.alerts.unread, []);
});

test('hint metadata cannot downgrade a confirmed post or overwrite its confirmed wording', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  const promise = { ...reply, text: 'Global reset landing tomorrow.' };
  await store.update((await query(feed([promise], { signal: headline(promise) }))).announcements);
  await store.update((await query(feed())).announcements);
  const row = deriveAnnouncementsView(store.state, now, 'UTC', 'en').rows[0];
  assert.equal(store.state.items.length, 1);
  assert.equal(store.state.items[0].certainty, 'announced');
  assert.equal(row.summary, promise.text);
  assert.equal(row.monitorSourceUrl, null);
});

test('a later completion is not attached to an unconfirmed website hint', async () => {
  const completion = { ...parent, id: '1000000000000000104', url: 'https://x.com/thsottiaux/status/1000000000000000104',
    at: '2026-10-15T05:30:00Z', text: 'All propagated.' };
  const result = await query(feed([reply, completion], { events: [{ url: reply.url, group: 'reset' }, { url: completion.url, group: 'reset' }] }));
  assert.equal(result.announcements.items.length, 2);
  assert.equal(result.announcements.items.find(item => item.sourceUrl === reply.url).deliveredAt, null);
  assert.equal(result.lastGlobal.sourceUrl, completion.url);
});

test('the displayed cache expires hints even when a failed server refresh leaves old items in memory', async () => {
  const result = await query(feed());
  const view = deriveAnnouncementsView({ ...result.announcements, stale: true }, now + 24 * hour, 'UTC', 'en');
  assert.equal(view.rows.length, 0);
  assert.equal(view.history.length, 1);
  assert.match(view.history[0].display.status, /Earlier site hint; subsequent progress is unknown/);
});
