import test from 'node:test';
import assert from 'node:assert/strict';
import { createAnnouncementStore, queryExternal } from '../external.mjs';
import { announcementIdsForReading, deriveAnnouncementsView } from '../public/app.mjs';

const now = Date.parse('2026-10-11T12:00:00Z');
const preUrl = 'https://x.com/thsottiaux/status/1000000000000000001';
const doneUrl = 'https://x.com/thsottiaux/status/1000000000000000002';
const pre = { id: '1000000000000000001', url: preUrl, text: 'Global reset by EOD.', at: '2026-10-10T22:16:20Z', declared_at: '2026-10-10T22:16:20Z', kind: 'signal' };
const done = { id: '1000000000000000002', url: doneUrl, text: 'Put the reset in the bag. All propagated.', at: '2026-10-11T04:01:09Z', kind: 'signal' };
const feed = (tweets = [], extra = {}) => ({ version: 1, fetched_at: '2026-10-11T11:50:00Z', stale: false, profile: { handle: 'thsottiaux' }, tweets, events: [], ...extra });
const record = (extra = {}) => ({ id: 'cr-1000000000000000002', type: 'global_reset', status: 'recorded', source_url: doneUrl, announced_at: '2026-10-11T04:01:09Z', effective_at: '2026-10-11T04:01:09Z', retrieved_at: '2026-10-11T11:45:00Z', time_basis: 'announcement', source_author: '@thsottiaux (archived by Codex Resets)', evidence_text: 'All propagated.', origin: 'codex_resets', ...extra });
const history = (events = []) => ({ events, count: events.length, coverage: 'partial', timezone: 'UTC' });
const query = (primary, backup = history()) => queryExternal({ now, fetchFn: async (url, options) => {
  assert.match(options.headers['User-Agent'], /^codex-quota-widget\//);
  const data = url === 'https://codex-reset.com/api/feed' ? primary : url === 'https://codexreset.dev/api/history' ? backup : new Error('Unexpected provider');
  if (data instanceof Error) throw data;
  return { ok: true, json: async () => data };
} });

test('a partial archive preserves known publication time and history retention without inventing missing times', async () => {
  // FABRICATED TEST DATA: no network, account, or persisted cache.
  const store = await createAnnouncementStore({ now: () => now });
  const rows = Array.from({ length: 50 }, (_, i) => ({
    id: `https://example.org/fabricated/${i}#regular`, kind: 'regular',
    sourceUrl: `https://example.org/fabricated/${i}`, certainty: 'unconfirmed',
    announcedAt: new Date(now - (i + 2) * 86400000).toISOString(), deliveredAt: null,
  }));
  const snapshot = history => ({ status: 'ok', stale: false, sourceUpdatedAt: new Date(now).toISOString(), items: [], history });
  await store.update(snapshot(rows));
  await store.update(snapshot([{ ...rows[0], announcedAt: null }]));
  assert.equal(store.state.history[0].id, rows[0].id, 'Missing repeated metadata cannot discard a recent cached record');
  assert.equal(store.state.history[0].announcedAt, rows[0].announcedAt);
  assert.equal(store.state.history[0].deliveredAt, null, 'A retained publication is not delivery evidence');
  assert.deepEqual(store.state.history.map(row => row.id), rows.map(row => row.id));
  assert.deepEqual(store.alerts.unread, []);
  const corrected = new Date(now - 86400000).toISOString();
  await store.update(snapshot([{ ...rows[0], announcedAt: corrected }]));
  assert.equal(store.state.history[0].announcedAt, corrected, 'An explicit new publication can update the known time');
  const unknown = await createAnnouncementStore({ now: () => now });
  await unknown.update(snapshot([{ ...rows[0], announcedAt: null }]));
  assert.equal(unknown.state.history[0].announcedAt, null, 'No timestamp is invented for an unknown publication');
});

test('reads the new original announcement feed without inventing an EOD time or trusting timeline labels', async () => {
  const result = await query(feed([pre], { events: [{ id: pre.id, url: preUrl, announced_at: '2026-10-11T03:57:51Z', announcement_state: 'announced', group: 'reset' }] }));
  assert.equal(result.announcements.status, 'ok');
  const item = result.announcements.items[0];
  assert.equal(item.announcedAt, '2026-10-10T22:16:20.000Z');
  assert.equal(item.certainty, 'announced');
  assert.equal(item.scheduledAt, null);
  assert.equal(item.scheduledDate, null);
  assert.equal(item.deliveredAt, null);
});

test('combines the preannouncement and completion statement once across mirrored records', async () => {
  const result = await query(feed([done, pre]), history([record()]));
  assert.equal(result.announcements.items.length, 1);
  const item = result.announcements.items[0];
  assert.equal(item.sourceUrl, preUrl);
  assert.equal(item.deliverySourceUrl, doneUrl);
  assert.equal(item.deliveredAt, '2026-10-11T04:01:09.000Z');
  assert.equal(item.completionTimeBasis, 'announcement');
  const row = deriveAnnouncementsView(result.announcements, now, 'Asia/Shanghai', 'zh-CN').rows[0];
  assert.match(row.completedText, /完成声明发布.*12:01/);
  assert.equal(result.lastGlobal.sourceUrl, preUrl);
});

test('a reset category or conditional wording cannot create a confirmed alert', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed())).announcements);
  const ambiguous = { ...pre, at: '2026-10-11T11:55:00Z', text: 'If we do a global reset by EOD, would you prefer that?', kind: 'reset', explicit_reset_claim: true };
  await store.update((await query(feed([ambiguous]))).announcements);
  assert.equal(store.state.items.some(item => item.certainty === 'announced'), false);
  assert.deepEqual(store.alerts.unread, []);
});

test('backup publication and observation timestamps alone do not prove completion', async () => {
  for (const raw of [record({ evidence_text: 'Global reset recorded.' }), record({ time_basis: 'observation', announced_at: null, evidence_text: 'All propagated.' })]) {
    const result = await query(new Error('offline'), history([raw]));
    assert.equal(result.announcements.history[0].deliveredAt, null);
  }
});

test('backup banked completion is separate from a global reset and uses its evidence publication time', async () => {
  const result = await query(new Error('offline'), history([record({ type: 'banked_reset', evidence_text: 'Confirmed landed across all accounts.' })]));
  assert.equal(result.announcements.items[0].kind, 'banked');
  assert.equal(result.announcements.items[0].completionTimeBasis, 'announcement');
  assert.equal(result.lastGlobal, null);
});

test('a partial archive never withdraws a cached pending announcement and failures preserve last success', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed([pre]))).announcements);
  const checked = store.state.lastFetchedAt;
  const partial = await query(feed(), history());
  assert.equal(partial.announcements.reconciledIds, undefined);
  await store.update(partial.announcements);
  assert.equal(store.state.items[0].sourceUrl, preUrl);
  await store.update((await query(new Error('offline'), new Error('offline'))).announcements);
  assert.equal(store.state.lastFetchedAt, checked);
  assert.equal(store.state.items[0].sourceUrl, preUrl);
});

test('a backup completion closes the cached preannouncement, and recovery of the main feed does not duplicate it', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed([pre]))).announcements);
  await store.update((await query(new Error('offline'), history([record()]))).announcements);
  assert.equal(store.state.items.length, 1);
  assert.equal(store.state.items[0].deliverySourceUrl, doneUrl);
  await store.update((await query(feed([done, pre]), history([record()]))).announcements);
  assert.equal(store.state.items.length, 1);
});

test('unsafe original links and stale provider snapshots cannot become fresh announcements', async () => {
  const unsafe = await query(feed([{ ...done, url: 'https://example.org/not-the-author' }]));
  assert.deepEqual(unsafe.announcements.items, []);
  const stale = await query(feed([pre], { fetched_at: '2026-10-08T00:00:00Z', stale: true }), history([record({ retrieved_at: '2026-10-08T00:00:00Z' })]));
  assert.equal(stale.announcements.reason, 'source-stale');
  assert.equal(stale.announcements.stale, true);
});

test('future, conditional and interrogative completion phrases never claim a completed reset', async () => {
  for (const phrase of ['Global reset will be all propagated by EOD.', 'When the global reset is done, we will announce it.', 'Global reset is complete?', 'The reset is not complete.', 'No reset has been processed.', 'Assuming the global reset is complete, we can get back to work.', 'We need to check whether the global reset is complete.']) {
    const result = await query(feed([{ ...done, text: phrase }]));
    assert.equal(result.announcements.items.some(item => item.deliveredAt), false, phrase);
  }
});

test('a promise to discuss policy is not a promise to reset accounts', async () => {
  for (const phrase of ['We will explain the global reset policy tomorrow.', "Global reset will be discussed in tomorrow's meeting.", 'Global reset will require a policy review.']) {
    const result = await query(feed([{ ...pre, text: phrase }]));
    assert.equal(result.announcements.items.some(item => item.certainty === 'announced'), false, phrase);
  }
});

test('suggestions, capabilities and requests do not become promises while explicit actions do', async () => {
  for (const phrase of ['We should grant a banked reset.', 'We can grant a banked reset.', 'We may give a global reset.', 'Please do a global reset.', 'We request that you grant a banked reset.']) {
    const result = await query(feed([{ ...pre, text: phrase }]));
    assert.equal(result.announcements.items.some(item => item.certainty === 'announced'), false, phrase);
  }
  for (const phrase of ['Loading a new banked reset for you.', "We're granting a banked reset.", 'We will give a banked reset.', 'We are going to do a global reset.', 'Global reset landing tomorrow.', 'Global reset will happen tomorrow.']) {
    const result = await query(feed([{ ...pre, text: phrase }]));
    assert.equal(result.announcements.items[0]?.certainty, 'announced', phrase);
    assert.equal(result.announcements.items[0]?.deliveredAt, null, phrase);
  }
});

test('an explicit pending original announcement stays current past 24 hours without reviving ancient archive promises', async () => {
  const old = { ...pre, at: '2026-10-10T00:00:00Z', declared_at: '2026-10-10T00:00:00Z' };
  const ancient = record({ announced_at: '2026-03-01T00:00:00Z', evidence_text: 'Global reset by EOD.' });
  const result = await query(feed([old]), history([ancient]));
  assert.deepEqual(result.announcements.items.map(item => item.sourceUrl), [preUrl]);
  assert.equal(result.announcements.items[0].deliveredAt, null);
});

test('an old completed pairing enters history without becoming a new live notice', async () => {
  const earlierPre = { ...pre, at: '2026-10-09T06:00:00Z', declared_at: '2026-10-09T06:00:00Z' };
  const earlierDone = { ...done, at: '2026-10-10T07:00:00Z' };
  const result = await query(feed([earlierPre, earlierDone]));
  assert.deepEqual(result.announcements.items, []);
  assert.equal(result.announcements.history.length, 1);
  let clock = Date.parse('2026-10-08T00:00:00Z');
  const store = await createAnnouncementStore({ now: () => clock });
  await store.update({ status: 'ok', stale: false, sourceUpdatedAt: new Date(clock).toISOString(), items: [], history: [] });
  clock = now;
  await store.update(result.announcements);
  assert.deepEqual(store.alerts.unread, []);
  assert.equal(store.state.history.length, 1);
});

test('a partial preannouncement refresh preserves the meaning of cached completion publication time', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed([done, pre]), history([record()]))).announcements);
  await store.update((await query(feed([pre]))).announcements);
  assert.equal(store.state.items[0].completionTimeBasis, 'announcement');
  assert.match(deriveAnnouncementsView(store.state, now, 'UTC', 'en').rows[0].completedText, /^Completion statement posted/);
});

test('reading a completion notice clears its canonical paired row after a partial backup update', async () => {
  let clock = Date.parse('2026-10-10T20:00:00Z');
  const store = await createAnnouncementStore({ now: () => clock });
  await store.update({ status: 'ok', stale: false, sourceUpdatedAt: new Date(clock).toISOString(), items: [], history: [] });
  clock = now;
  await store.update((await query(feed([pre]))).announcements);
  await store.acknowledge(store.alerts.unread.map(item => item.id));
  await store.update((await query(new Error('offline'), history([record()]))).announcements);
  const view = deriveAnnouncementsView(store.state, now, 'UTC', 'en');
  const ids = announcementIdsForReading(store.alerts, view, true);
  assert.deepEqual(ids, [preUrl + '#regular']);
  await store.acknowledge(ids);
  assert.deepEqual(store.alerts.unread, []);
});

test('a late ambiguous preannouncement cannot steal a completion already paired with another record', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  await store.update((await query(feed([done, pre]), history([record()]))).announcements);
  const late = { ...pre, id: '1000000000000000005', url: 'https://x.com/thsottiaux/status/1000000000000000005', at: '2026-10-11T01:00:00Z', declared_at: '2026-10-11T01:00:00Z' };
  await store.update((await query(feed([late]))).announcements);
  assert.equal(store.state.items.length, 2);
  assert.equal(store.state.items.find(item => item.sourceUrl === preUrl).deliverySourceUrl, doneUrl);
  assert.equal(store.state.items.find(item => item.sourceUrl === late.url).deliveredAt, null);
});

test('explicit banked original text takes precedence over a conflicting archive category without a duplicate', async () => {
  for (const statement of [{ ...pre, text: 'Loading a new banked reset for you.' }, { ...done, text: 'Confirmed landed across all accounts. The banked reset is ready.' }]) {
    const archived = record({ source_url: statement.url, announced_at: statement.at, evidence_text: statement.text.split('.')[0] + '.', type: 'global_reset' });
    const result = await query(feed([statement]), history([archived]));
    assert.equal(result.announcements.items.length, 1);
    assert.equal(result.announcements.items[0].kind, 'banked');
    assert.equal(result.announcements.items[0].certainty, 'announced');
    assert.equal(result.lastGlobal, null);
  }
});

test('an explicit original category corrects conflicting cached rows and their unread identities', async () => {
  let clock = Date.parse('2026-10-10T20:00:00Z');
  const store = await createAnnouncementStore({ now: () => clock });
  await store.update({ status: 'ok', stale: false, sourceUpdatedAt: new Date(clock).toISOString(), items: [], history: [] });
  clock = now;
  const backup = history([record({ evidence_text: 'Confirmed landed across all accounts.' })]);
  await store.update((await query(new Error('offline'), backup)).announcements);
  assert.equal(store.state.items[0].kind, 'regular');
  const original = feed([{ ...done, text: 'Confirmed landed across all accounts. The banked reset is ready.' }]);
  const corrected = await query(original, backup);
  assert.equal(corrected.lastGlobal, null);
  await store.update(corrected.announcements);
  // A later partial archive must not undo the original's explicit category.
  await store.update((await query(new Error('offline'), backup)).announcements);
  assert.deepEqual(store.state.items.map(item => item.id), [doneUrl + '#banked']);
  assert.deepEqual(store.state.history.map(item => item.id), [doneUrl + '#banked']);
  assert.deepEqual(store.alerts.unread, [{ id: doneUrl + '#banked', kind: 'banked' }]);
  const ids = announcementIdsForReading(store.alerts, deriveAnnouncementsView(store.state, now, 'UTC', 'en'), true);
  await store.acknowledge(ids);
  assert.deepEqual(store.alerts.unread, []);
});

test('correcting a completion category releases an incompatible cached promise from its old pairing', async () => {
  const store = await createAnnouncementStore({ now: () => now });
  const backup = history([record({ evidence_text: 'Confirmed landed across all accounts.' })]);
  await store.update((await query(feed([pre]), backup)).announcements);
  assert.equal(store.state.items[0].deliverySourceUrl, doneUrl);
  const original = { ...done, text: 'Confirmed landed across all accounts. The banked reset is ready.' };
  await store.update((await query(feed([original, pre]), backup)).announcements);
  await store.update((await query(new Error('offline'), backup)).announcements);
  assert.equal(store.state.items.length, 2);
  const pending = store.state.items.find(item => item.sourceUrl === preUrl);
  assert.equal(pending.kind, 'regular');
  assert.equal(pending.deliveredAt, null);
  assert.equal(pending.deliverySourceUrl, null);
  assert.equal(pending.completionTimeBasis, null);
  const completion = store.state.items.find(item => item.sourceUrl === doneUrl);
  assert.equal(completion.kind, 'banked');
  assert.equal(completion.deliveredAt, '2026-10-11T04:01:09.000Z');
});
