import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import * as source from '../external.mjs';
import * as view from '../public/app.mjs';
import * as locale from '../public/i18n.mjs';

const now = Date.parse('2026-09-30T12:00:00Z');
const at = offset => new Date(now + offset).toISOString();
const hour = 3600000;
const feed = (scheduled = null, events = []) => ({ schema: 'whenreset/v1', generated_at: at(0), products: { codex: { scheduled, events } } });
const scheduled = (kind = 'banked') => ({ id: kind, kind, certainty: 'announced', date: '2026-10-01', ts: at(-hour), scope: 'paid', url: `https://x.com/thsottiaux/status/${kind}`, summary: 'Public announcement' });

test('the published WhenReset schedule shape preserves its real UTC time, publication, day and timezone label', () => {
  const time = Date.parse('2026-10-02T06:00:00Z');
  const signal = {day:'2026-10-02',tz_label:'PT',scheduled_for:'2026-10-02T17:00:00Z',announced_at:'2026-10-02T02:14:51Z',certainty:'announced',url:'https://x.com/thsottiaux/status/2105843926221660585',note_zh:'来源预告及其时区换算说明'};
  const result = source.normalizeAnnouncements({...feed(signal),generated_at:new Date(time).toISOString()},time);
  assert.equal(result.status,'ok');
  assert.equal(result.items.length,1);
  assert.equal(result.items[0].kind,'regular');
  assert.equal(result.items[0].scheduledAt,'2026-10-02T17:00:00.000Z');
  assert.equal(result.items[0].announcedAt,'2026-10-02T02:14:51.000Z');
  assert.equal(result.items[0].scheduledDate,'2026-10-02');
  assert.equal(result.items[0].scheduledTimeZone,'PT');
  assert.equal(result.items[0].summaryZh,signal.note_zh);
  assert.equal(result.items[0].scope,null,'Missing scope is not inferred from free text');
  const row=view.deriveAnnouncementsView(result,time,'Asia/Shanghai','zh-CN').rows[0];
  assert.match(row.plannedText,/10\/03.*01:00.*UTC\+08:00/);
  assert.match(row.scheduleNote,/来源.*PT.*换算/);
  assert.equal(row.scheduleNoteDetail,signal.note_zh);
  const hinted=source.normalizeAnnouncements({...feed({...signal,certainty:'hinted'}),generated_at:new Date(time).toISOString()},time);
  assert.deepEqual(hinted.items,[]);
});

test('only a complete fresh reconciliation from both sources withdraws a cached unconfirmed record', async () => {
  const dir=await mkdtemp(join(tmpdir(),'quota-reconcile-'));
  const file=join(dir,'announcements.json');
  try {
    const store=await source.createAnnouncementStore({file,now:()=>now});
    const old=source.normalizeAnnouncements(feed(scheduled('regular')),now);
    await store.update(old);
    await store.update({status:'unavailable',items:[],history:[],sourceUpdatedAt:at(0),reconciledIds:[]});
    assert.equal(store.state.items.length,1,'Failure cannot withdraw an announcement');
    await store.update({...source.normalizeAnnouncements(feed(),now),sourceUpdatedAt:at(-25*hour),reconciledIds:[]});
    assert.equal(store.state.items.length,1,'Stale evidence cannot withdraw an announcement');
    await store.update({...source.normalizeAnnouncements(feed(),now),reconciledIds:[]});
    assert.equal(store.state.items.length,0,'Both fresh complete feeds no longer list this record');
    assert.equal(store.state.history[0].sourceWithdrawn,true);
    assert.equal(store.state.history[0].deliveredAt,null,'Withdrawal is not delivery');
    const row=view.deriveAnnouncementsView(store.state,now,'UTC','zh-CN').history[0];
    assert.equal(row.title,'来源已撤下的公告记录');
    assert.equal(row.status,'监控来源已撤下此记录');
    const restored=await source.createAnnouncementStore({file,now:()=>now});
    assert.equal(restored.state.items.length,0);
    assert.equal(restored.state.history[0].sourceWithdrawn,true);
    await restored.update(old);
    assert.equal(restored.state.items.length,1,'A source can explicitly restore an announcement');
    assert.equal(restored.state.items[0].sourceWithdrawn,false);
  } finally {await rm(dir,{recursive:true,force:true});}
});

test('reconciliation clears withdrawn unread notices but never withdraws evidenced completed records', async () => {
  let time=now;
  const store=await source.createAnnouncementStore({now:()=>time});
  await store.update(source.normalizeAnnouncements(feed(),time));
  time+=hour;
  const fresh={...scheduled(),ts:at(hour)};
  await store.update(source.normalizeAnnouncements({...feed(fresh),generated_at:at(hour)},time));
  assert.equal(store.alerts.unread.length,1);
  await store.update({...source.normalizeAnnouncements({...feed(),generated_at:at(hour)},time),reconciledIds:[]});
  assert.deepEqual(store.alerts.unread,[]);
  const done={...fresh,delivered_at:at(hour)};
  await store.update(source.normalizeAnnouncements({...feed(done),generated_at:at(hour)},time));
  await store.update({...source.normalizeAnnouncements({...feed(),generated_at:at(hour)},time),reconciledIds:[]});
  assert.equal(store.state.items.length,1);
  assert.equal(store.state.items[0].deliveredAt,at(hour));
});

test('explicit announced signals preserve both kinds and date-only promises without interpreting historical estimates', () => {
  assert.equal(typeof source.normalizeAnnouncements, 'function');
  const result = source.normalizeAnnouncements({ ...feed([scheduled(), scheduled('regular')]), next_estimate: '2026-10-02' }, now);
  assert.equal(result.status, 'ok');
  assert.deepEqual(result.items.map(item => item.kind), ['banked', 'regular']);
  assert.equal(result.items[0].scheduledDate, '2026-10-01');
  assert.equal(result.items[0].scheduledAt, null);
  assert.equal(result.items[0].announcedAt, at(-hour));
});

test('hints and unsafe sources never become confirmed announcements; invalid feeds remain unavailable', () => {
  assert.equal(typeof source.normalizeAnnouncements, 'function');
  const hinted = source.normalizeAnnouncements(feed({ ...scheduled(), certainty: 'hinted' }), now);
  assert.deepEqual(hinted.items, []);
  assert.equal(hinted.status, 'ok');
  const unsafe = source.normalizeAnnouncements(feed({ ...scheduled(), url: 'javascript:alert(1)' }), now);
  assert.equal(unsafe.status, 'unavailable');
  assert.deepEqual(unsafe.items, []);
  assert.equal(source.normalizeAnnouncements({ ...feed(), generated_at: at(-25 * hour) }, now).status, 'unavailable');
  assert.equal(source.normalizeAnnouncements({ schema: 'whenreset/v1', generated_at: at(0), products: {} }, now).status, 'unavailable');
});

test('old unresolved records stay in history while recent official announcements remain visible without inventing delivery', () => {
  assert.equal(typeof source.normalizeAnnouncements, 'function');
  const old = { ...scheduled('regular'), ts: at(-72 * hour), certainty: undefined };
  const recent = { ...scheduled(), ts: at(-hour), certainty: undefined, delivered_at: null };
  const result = source.normalizeAnnouncements(feed(null, [old, recent]), now);
  assert.deepEqual(result.items.map(item => item.kind), ['banked']);
  assert.equal(result.items[0].scheduledDate, null);
  assert.equal(result.items[0].deliveredAt, null);
  assert.equal(result.history.length, 2);
});

test('a future or impossible delivery timestamp never confirms completion', () => {
  assert.equal(typeof source.normalizeAnnouncements, 'function');
  const result = source.normalizeAnnouncements(feed(null, [{ ...scheduled(), delivered_at: at(hour) }]), now);
  assert.equal(result.items[0].deliveredAt, null);
  const impossible = source.normalizeAnnouncements(feed(null, [{ ...scheduled(), delivered_at: at(-2 * hour) }]), now);
  assert.equal(impossible.items[0].deliveredAt, null);
});

test('known pending announcements survive lookup failure, empty feeds and restart, then archive only after evidenced completion plus 24 hours', async () => {
  assert.equal(typeof source.createAnnouncementStore, 'function');
  const dir = await mkdtemp(join(tmpdir(), 'quota-announcements-'));
  const file = join(dir, 'announcements.json');
  let time = now;
  try {
    const store = await source.createAnnouncementStore({ file, now: () => time });
    await store.update(source.normalizeAnnouncements(feed(scheduled()), time));
    assert.equal(store.state.items.length, 1);
    await store.update({ status: 'unavailable', items: [], history: [] });
    assert.equal(store.state.items.length, 1);
    assert.equal(store.state.stale, true);
    const restored = await source.createAnnouncementStore({ file, now: () => time });
    assert.equal(restored.state.items.length, 1);
    assert.equal(restored.state.stale, true);
    await restored.update(source.normalizeAnnouncements(feed(), time));
    assert.equal(restored.state.items.length, 1);
    assert.equal(restored.state.stale, true);
    time += 2 * hour;
    await restored.update(source.normalizeAnnouncements({ ...feed(null, [{ ...scheduled(), delivered_at: at(hour), delivered_source_url: 'https://x.com/thsottiaux/status/done' }]), generated_at: new Date(time).toISOString() }, time));
    assert.equal(restored.state.items[0].deliveredAt, at(hour));
    time = now + 25 * hour - 1;
    assert.equal(restored.state.items.length, 1);
    time += 1;
    assert.equal(restored.state.items.length, 0);
    assert.equal(restored.state.history[0].deliveredAt, at(hour));
    assert.equal(JSON.parse(await readFile(file, 'utf8')).version, 1);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('malformed persisted public data cannot create unsafe announcement links', async () => {
  assert.equal(typeof source.createAnnouncementStore, 'function');
  const dir = await mkdtemp(join(tmpdir(), 'quota-announcements-invalid-'));
  try {
    const { writeFile } = await import('node:fs/promises');
    const file = join(dir, 'announcements.json');
    await writeFile(file, JSON.stringify({ version: 1, items: [{ id: 'x', kind: 'banked', sourceUrl: 'javascript:alert(1)', announcedAt: at(-hour) }] }));
    const store = await source.createAnnouncementStore({ file, now: () => now });
    assert.deepEqual(store.state.items, []);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('completed scheduled-only records stay archived after an empty or failed lookup and restart', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'quota-archive-retention-'));
  const file = join(dir, 'announcements.json');
  let time = now;
  try {
    const store = await source.createAnnouncementStore({ file, now: () => time });
    await store.update(source.normalizeAnnouncements(feed({ ...scheduled(), delivered_at: at(0) }), time));
    assert.equal(store.state.items.length, 1);
    assert.equal(store.state.history.length, 0);
    time += 25 * hour;
    assert.equal(store.state.history.length, 1);
    await store.update({ status: 'unavailable', items: [], history: [] });
    assert.equal(store.state.history.length, 1, 'failed lookup preserves the archived record');
    await store.update(source.normalizeAnnouncements({ ...feed(), generated_at: new Date(time).toISOString() }, time));
    assert.equal(store.state.history.length, 1, 'empty successful lookup preserves the archived record');
    const restored = await source.createAnnouncementStore({ file, now: () => time });
    assert.equal(restored.state.items.length, 0);
    assert.equal(restored.state.history[0].kind, 'banked');
    assert.equal(restored.state.history[0].deliveredAt, at(0));
    assert.equal(restored.state.history[0].scheduledDate, '2026-10-01');
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('announcement presentation distinguishes upcoming, awaiting completion, completed and archived stages', () => {
  assert.equal(typeof view.deriveAnnouncementsView, 'function');
  const item = { id: 'b', kind: 'banked', announcedAt: at(-hour), scheduledAt: at(hour), scheduledDate: null, deliveredAt: null, sourceUrl: 'https://x.com/thsottiaux/status/b' };
  const state = { status: 'ok', items: [item], history: [], stale: false };
  assert.equal(view.deriveAnnouncementsView(state, now, 'UTC', 'en').rows[0].phase, 'upcoming');
  assert.equal(view.deriveAnnouncementsView(state, now + hour, 'UTC', 'en').rows[0].phase, 'waiting');
  const done = { ...state, items: [{ ...item, deliveredAt: at(hour) }] };
  assert.equal(view.deriveAnnouncementsView(done, now + 2 * hour, 'UTC', 'en').rows[0].phase, 'delivered');
  assert.equal(view.deriveAnnouncementsView(done, now + 25 * hour, 'UTC', 'en').rows.length, 0);
  assert.equal(view.deriveAnnouncementsView(done, now + 25 * hour, 'UTC', 'en').history.length, 1);
});

test('historical announcements without delivery evidence never imply they are still awaiting delivery', () => {
  const item = { id: 'old-grant', kind: 'banked', announcedAt: at(-7 * 24 * hour), deliveredAt: null, sourceUrl: 'https://x.com/thsottiaux/status/old-grant' };
  for (const [language, status] of [['en', 'Source did not provide a delivery record'], ['zh-CN', '来源未提供送达记录']]) {
    const historical = view.deriveAnnouncementsView({ status: 'ok', items: [], history: [item] }, now, 'UTC', language);
    assert.equal(historical.history[0].phase, 'unknown');
    assert.equal(historical.history[0].status, status);
    assert.equal(historical.history[0].completedText, '');
    assert.equal(historical.history[0].deliverySourceUrl, null);
    const active = view.deriveAnnouncementsView({ status: 'ok', items: [item], history: [] }, now, 'UTC', language);
    assert.equal(active.rows[0].phase, 'announced', 'active announcements retain their pending state');
    assert.equal(active.rows[0].status, locale.t(language, 'announcedWaiting'));
  }
});

test('historical completion labels require and preserve delivery evidence', () => {
  const item = { id: 'done-reset', kind: 'regular', announcedAt: at(-72 * hour), deliveredAt: at(-48 * hour), sourceUrl: 'https://x.com/thsottiaux/status/done-reset', deliverySourceUrl: 'https://x.com/thsottiaux/status/confirmed' };
  const result = view.deriveAnnouncementsView({ status: 'ok', items: [], history: [item] }, now, 'UTC', 'zh-CN');
  assert.equal(result.history[0].phase, 'archived');
  assert.equal(result.history[0].status, '已重置');
  assert.match(result.history[0].completedText, /确认完成/);
  assert.equal(result.history[0].deliverySourceUrl, item.deliverySourceUrl);
});

test('compact announcement alerts baseline existing records and ignore late historical records', async () => {
  let time = now;
  const store = await source.createAnnouncementStore({ now: () => time });
  await store.update({ status: 'unavailable' });
  assert.deepEqual(store.alerts, { unread: [] });
  const old = { ...scheduled(), certainty: undefined, ts: at(-72 * hour) };
  await store.update(source.normalizeAnnouncements(feed(scheduled(), [old]), time));
  assert.deepEqual(store.alerts.unread, [], 'first successful lookup is the baseline');
  time += hour;
  const fresh = { ...scheduled('regular'), ts: at(hour) };
  const addedHistory = { ...old, url: 'https://x.com/thsottiaux/status/older-added', ts: at(-48 * hour) };
  await store.update(source.normalizeAnnouncements({ ...feed([scheduled(), fresh], [old, addedHistory]), generated_at: at(hour) }, time));
  assert.deepEqual(store.alerts.unread, [{ id: fresh.url + '#regular', kind: 'regular' }]);
  await store.update({ status: 'unavailable' });
  assert.equal(store.alerts.unread.length, 1, 'provider failure preserves genuine unread notices');
});

test('unread confirmed announcements survive restart and acknowledgements clear only the IDs that were viewed', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'quota-unread-'));
  const file = join(dir, 'announcements.json');
  let time = now;
  try {
    const store = await source.createAnnouncementStore({ file, now: () => time });
    await store.update(source.normalizeAnnouncements(feed(), time));
    time += hour;
    const grant = { ...scheduled(), ts: at(hour) };
    await store.update(source.normalizeAnnouncements({ ...feed(grant), generated_at: at(hour) }, time));
    const viewed = store.alerts.unread.map(item => item.id);
    time += hour;
    const reset = { ...scheduled('regular'), ts: at(2 * hour) };
    await store.update(source.normalizeAnnouncements({ ...feed([grant, reset]), generated_at: at(2 * hour) }, time));
    assert.equal(store.alerts.unread.length, 2);
    const restarted = await source.createAnnouncementStore({ file, now: () => time });
    assert.equal(restarted.alerts.unread.length, 2);
    await restarted.acknowledge(viewed);
    assert.deepEqual(restarted.alerts.unread, [{ id: reset.url + '#regular', kind: 'regular' }], 'a newly arrived reset remains unread');
    await restarted.acknowledge([reset.url + '#regular']);
    const reopened = await source.createAnnouncementStore({ file, now: () => time });
    await reopened.update(source.normalizeAnnouncements({ ...feed([grant, reset]), generated_at: at(2 * hour) }, time));
    assert.deepEqual(reopened.alerts.unread, [], 'viewed announcements never reappear after restart or repeated polling');
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('hints, failed or stale sources cannot create compact announcement alerts', async () => {
  let time = now;
  const store = await source.createAnnouncementStore({ now: () => time });
  await store.update(source.normalizeAnnouncements(feed(), time));
  time += hour;
  const hint = { ...scheduled(), certainty: 'hinted', ts: at(hour) };
  await store.update(source.normalizeAnnouncements({ ...feed(hint), generated_at: at(hour) }, time));
  await store.update(source.normalizeAnnouncements({ ...feed(null, [hint]), generated_at: at(hour) }, time));
  const fresh = { ...scheduled('regular'), ts: at(hour) };
  const value = source.normalizeAnnouncements({ ...feed(fresh), generated_at: at(hour) }, time);
  await store.update({ ...value, status: 'unavailable', stale: true });
  await store.update({ ...value, sourceUpdatedAt: at(-25 * hour) });
  assert.deepEqual(store.alerts.unread, []);
});

test('hidden compact details never acknowledge notices and a visible detail acknowledges only rendered IDs', () => {
  const alerts = { unread: [{ id: 'shown', kind: 'banked' }, { id: 'arrived-later', kind: 'regular' }] };
  const displayed = { rows: [{ id: 'shown' }], history: [] };
  assert.equal(typeof view.announcementIdsForReading, 'function');
  assert.deepEqual(view.announcementIdsForReading(alerts, displayed, false), []);
  assert.deepEqual(view.announcementIdsForReading(alerts, displayed, true), ['shown']);
  assert.deepEqual(view.announcementIdsForReading(null, displayed, true), []);
});

test('no known announcements use one merged notice; transport failure has a different notice and retains known rows', () => {
  assert.equal(typeof view.deriveAnnouncementsView, 'function');
  const empty = view.deriveAnnouncementsView({ status: 'ok', sourceUpdatedAt:at(0), items: [], history: [] }, now, 'UTC', 'zh-CN');
  assert.deepEqual(empty.rows, []);
  assert.equal(empty.notice, '监控来源暂无已确认的赠送或全局额度重置公告');
  const unavailable = view.deriveAnnouncementsView({ status: 'unavailable', items: [], history: [] }, now, 'UTC', 'zh-CN');
  assert.equal(unavailable.notice, '预告信息暂不可用');
  const known = { id: 'b', kind: 'banked', scheduledDate: '2026-10-01', sourceUrl: 'https://x.com/thsottiaux/status/b' };
  const retained = view.deriveAnnouncementsView({ status: 'unavailable', items: [known], history: [], stale: true }, now, 'UTC', 'en');
  assert.equal(retained.rows.length, 1);
  assert.equal(retained.notice, 'Information pending update');
  assert.doesNotMatch(retained.rows[0].timeText, /00:00/);
});

test('relative update ages advance locally, future and invalid values are bounded, dates keep years only when needed', () => {
  assert.equal(typeof locale.formatRelativeUpdate, 'function');
  assert.equal(locale.formatRelativeUpdate(now - 59000, now, 'zh-CN'), '刚刚更新');
  assert.equal(locale.formatRelativeUpdate(now - 120000, now, 'zh-CN'), '2 分钟前更新');
  assert.equal(locale.formatRelativeUpdate(now - 120000, now, 'en'), 'Updated 2 min ago');
  assert.equal(locale.formatRelativeUpdate(now + hour, now, 'en'), 'Unavailable');
  assert.equal(locale.formatRelativeUpdate(NaN, now, 'en'), 'Unavailable');
  assert.equal(typeof locale.formatShortDate, 'function');
  assert.doesNotMatch(locale.formatShortDate(now + hour, 'UTC', 'en', now), /2026/);
  assert.match(locale.formatShortDate(Date.parse('2027-01-01T08:21:00Z'), 'UTC', 'en', now), /2027/);
});

test('completion keeps the original plan, completion evidence and account scope in both languages', () => {
  const item = { id: 'b', kind: 'banked', announcedAt: at(-hour), scheduledAt: at(hour), deliveredAt: at(2 * hour), scope: 'paid', sourceUrl: 'https://x.com/thsottiaux/status/b', deliverySourceUrl: 'https://x.com/thsottiaux/status/done' };
  const state = { status: 'ok', items: [item], history: [] };
  for (const language of ['en', 'zh-CN']) {
    const row = view.deriveAnnouncementsView(state, now + 3 * hour, 'UTC', language).rows[0];
    assert.match(row.plannedText, /13:00/);
    assert.match(row.completedText, /14:00/);
    assert.equal(row.scopeText, locale.t(language, 'paid'));
    assert.match(row.retentionText, /24/);
  }
  const dayOnly = view.deriveAnnouncementsView({ ...state, items: [{ ...item, scheduledAt: null, scheduledDate: '2026-10-01' }] }, now + 3 * hour, 'America/Los_Angeles', 'en').rows[0];
  assert.match(dayOnly.plannedText, /10\/01/);
  assert.doesNotMatch(dayOnly.plannedText, /00:00|09\/30/);
});

test('public lookup failures show source freshness separately from quota freshness', () => {
  assert.equal(typeof view.derivePublicStatus, 'function');
  assert.equal(view.derivePublicStatus({ status: 'ok', forecast: {next24h:15,next48h:33,next7d:69,sourceUpdatedAt:at(0)}, announcements: { status: 'ok', stale: false, sourceUpdatedAt:at(0) } }, now, 'UTC', 'en'), '');
  const status = view.derivePublicStatus({ status: 'ok', forecast: {}, announcements: { status: 'unavailable', sourceUpdatedAt: at(-hour), stale: true } }, now, 'UTC', 'en');
  assert.match(status, /Public information pending update/);
  assert.match(status, /11:00/);
  assert.doesNotMatch(status, /Quota|Updated \d+ min/);
});

test('precise pending schedules show local time and offset independently from announcement publication', () => {
  const item = { id: 'timed-grant', kind: 'banked', announcedAt: '2026-09-30T10:00:00Z', scheduledAt: '2026-10-01T20:30:00Z', scope: 'paid', sourceUrl: 'https://example.org/announcement' };
  const state = { status: 'ok', items: [item], history: [] };
  const shanghai = view.deriveAnnouncementsView(state, now, 'Asia/Shanghai', 'zh-CN').rows[0];
  assert.match(shanghai.plannedText, /预定送达.*10\/02.*04:30.*本地 UTC\+08:00/);
  assert.match(shanghai.announcedText, /公告发布.*09\/30.*18:00.*本地 UTC\+08:00/);
  const pacific = view.deriveAnnouncementsView({ ...state, items: [{ ...item, kind: 'regular' }] }, now, 'America/Los_Angeles', 'en').rows[0];
  assert.match(pacific.plannedText, /Scheduled reset.*10\/01.*13:30.*local UTC-07:00/);
  assert.match(pacific.announcedText, /Published.*09\/30.*03:00.*local UTC-07:00/);
});

test('local offsets belong to the event instant across DST and include fractional-hour zones', () => {
  assert.equal(typeof locale.formatLocalAnnouncementDate, 'function');
  const before = locale.formatLocalAnnouncementDate(Date.parse('2026-11-01T08:30:00Z'), 'America/Los_Angeles', 'en', now);
  const after = locale.formatLocalAnnouncementDate(Date.parse('2026-11-01T09:30:00Z'), 'America/Los_Angeles', 'en', now);
  assert.match(before, /01:30.*UTC-07:00/);
  assert.match(after, /01:30.*UTC-08:00/);
  assert.match(locale.formatLocalAnnouncementDate(Date.parse('2026-10-01T18:30:00Z'), 'Asia/Kolkata', 'en', now), /10\/02.*00:00.*UTC\+05:30/);
  assert.match(locale.formatLocalAnnouncementDate(now, 'UTC', 'zh-CN', now), /本地 UTC\+00:00/);
});

test('date-only and unspecified schedules never masquerade as precise local delivery times', () => {
  const item = { id: 'date-only', kind: 'banked', announcedAt: at(-hour), scheduledDate: '2026-10-01', sourceUrl: 'https://example.org/announcement' };
  const state = { status: 'ok', items: [item], history: [] };
  const dateOnly = view.deriveAnnouncementsView(state, now, 'America/Los_Angeles', 'zh-CN').rows[0];
  assert.match(dateOnly.plannedText, /10\/01.*具体时间未公布/);
  assert.doesNotMatch(dateOnly.plannedText, /UTC|\d\d:\d\d|09\/30/);
  const unknown = view.deriveAnnouncementsView({ ...state, items: [{ ...item, scheduledDate: null }] }, now, 'Asia/Shanghai', 'en').rows[0];
  assert.equal(unknown.plannedText, 'Delivery time not announced');
  assert.match(unknown.announcedText, /Published.*19:00.*local UTC\+08:00/);
  assert.equal(unknown.completedText, '');
});

test('source timestamps without a timezone cannot invent a local schedule or delivery', () => {
  for (const scheduled_at of ['2026-10-01', '2026-10-01T12:00:00', '2026-02-30T12:00:00Z']) {
    const result = source.normalizeAnnouncements(feed({ ...scheduled(), scheduled_at }), now);
    assert.equal(result.items[0].scheduledAt, null);
    assert.equal(result.items[0].scheduledDate, '2026-10-01');
  }
  const result = source.normalizeAnnouncements(feed({ ...scheduled(), scheduled_at: '2026-10-01T12:00:00+05:30', delivered_at: '2026-09-30T11:30:00' }), now);
  assert.equal(result.items[0].scheduledAt, '2026-10-01T06:30:00.000Z');
  assert.equal(result.items[0].deliveredAt, null);
});
