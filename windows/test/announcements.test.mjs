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

test('no known announcements use one merged notice; transport failure has a different notice and retains known rows', () => {
  assert.equal(typeof view.deriveAnnouncementsView, 'function');
  const empty = view.deriveAnnouncementsView({ status: 'ok', items: [], history: [] }, now, 'UTC', 'zh-CN');
  assert.deepEqual(empty.rows, []);
  assert.equal(empty.notice, '暂无已确认的赠送或全局额度重置公告');
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
  assert.equal(view.derivePublicStatus({ status: 'ok', forecast: {}, announcements: { status: 'ok', stale: false } }, now, 'UTC', 'en'), '');
  const status = view.derivePublicStatus({ status: 'ok', forecast: {}, announcements: { status: 'unavailable', sourceUpdatedAt: at(-hour), stale: true } }, now, 'UTC', 'en');
  assert.match(status, /Public information pending update/);
  assert.match(status, /11:00/);
  assert.doesNotMatch(status, /Quota|Updated \d+ min/);
});
