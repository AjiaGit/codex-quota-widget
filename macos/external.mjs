import { readFile, mkdir, writeFile, rename } from 'node:fs/promises';
import { dirname } from 'node:path';
const ROOT = 'https://codexreset.ai/api/v1';
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

function recentTimestamp(value, now) {
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp <= now + 5 * 60 * 1000 &&
    now - timestamp <= MAX_AGE_MS;
}

function safeHttpsUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password ? url.href : null;
  } catch { return null; }
}

const emptyAnnouncements = () => ({ status: 'unavailable', items: [], history: [], sourceUpdatedAt: null, lastFetchedAt: null, stale: true });
function preciseTimestamp(value) {
  // A calendar date or an unzoned clock time cannot be converted reliably.
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})$/i.test(value) || !dateOnly(value.slice(0,10))) return NaN;
  return Date.parse(value);
}
function timestamp(value, now, earliest = -Infinity) {
  const ms = preciseTimestamp(value);
  return Number.isFinite(ms) && ms <= now && ms >= earliest ? new Date(ms).toISOString() : null;
}
function dateOnly(value) {
  if(typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
  const ms=Date.parse(value+'T00:00:00Z');
  return Number.isFinite(ms)&&new Date(ms).toISOString().slice(0,10)===value?value:null;
}
const text = value => typeof value === 'string' ? value.slice(0, 2000) : null;
function normalizedAnnouncement(raw, now, scheduled = false, persisted = false) {
  // WhenReset's Codex scheduled object describes a global reset and may omit kind.
  const kind=scheduled && raw?.kind === undefined ? 'regular' : raw?.kind;
  if (!['banked', 'regular'].includes(kind)) return null;
  const sourceUrl = safeHttpsUrl(persisted ? raw.sourceUrl : raw.url);
  if (!sourceUrl) return null;
  const announcedAt = timestamp(persisted ? raw.announcedAt : raw.announced_at ?? raw.ts, now);
  const deliveredAt = timestamp(persisted ? raw.deliveredAt : raw.delivered_at, now, announcedAt ? Date.parse(announcedAt) : -Infinity);
  const schedule = persisted ? raw.scheduledAt : scheduled ? raw.scheduled_for ?? raw.scheduled_at : null;
  const scheduledMs = preciseTimestamp(schedule);
  return {
    id: sourceUrl + '#' + kind,
    kind, announcedAt, certainty: raw.certainty === 'announced' ? 'announced' : 'unconfirmed',
    scheduledAt: Number.isFinite(scheduledMs) ? new Date(scheduledMs).toISOString() : null,
    scheduledDate: dateOnly(persisted ? raw.scheduledDate : scheduled ? raw.day ?? raw.date : null),
    scheduledTimeZone: text(persisted ? raw.scheduledTimeZone : scheduled ? raw.tz_label : null),
    deliveredAt, scope: text(raw.scope), scopeLabel: text(persisted ? raw.scopeLabel : raw.scope_label),
    sourceUrl, deliverySourceUrl: deliveredAt ? safeHttpsUrl(persisted ? raw.deliverySourceUrl : raw.delivered_source_url) : null,
    summary: text(raw.summary ?? (scheduled ? raw.note_en : null)), summaryZh: text(persisted ? raw.summaryZh : raw.summary_zh ?? (scheduled ? raw.note_zh : null)),
    sourceWithdrawn: persisted && raw.sourceWithdrawn === true,
  };
}
function deduplicate(items) {
  const map = new Map();
  for (const item of items) {
    const previous = map.get(item.id);
    map.set(item.id, previous ? { ...previous, ...item,
      scheduledAt: item.scheduledAt || previous.scheduledAt,
      scheduledDate: item.scheduledDate || previous.scheduledDate,
      certainty: item.certainty === 'announced' || previous.certainty === 'announced' ? 'announced' : 'unconfirmed',
      deliveredAt: item.deliveredAt || previous.deliveredAt,
      deliverySourceUrl: item.deliverySourceUrl || previous.deliverySourceUrl } : item);
  }
  return [...map.values()];
}
const active = (item, now) => !item.sourceWithdrawn && (item.deliveredAt
  ? now - Date.parse(item.deliveredAt) < MAX_AGE_MS
  : item.certainty === 'announced' || item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS);
const confirmedAnnouncement = item => item.certainty === 'announced' || Boolean(item.deliveredAt);

export function normalizeAnnouncements(data, now = Date.now()) {
  const product = data?.products?.codex;
  if (data?.schema !== 'whenreset/v1' || !recentTimestamp(data.generated_at, now) || !product ||
      !Object.hasOwn(product, 'scheduled') || !Array.isArray(product.events)) return emptyAnnouncements();
  const signals = product.scheduled === null ? [] : Array.isArray(product.scheduled) ? product.scheduled : [product.scheduled];
  let invalid = false;
  const upcoming = [];
  for (const raw of signals) {
    if (raw?.certainty === 'hinted') continue;
    const item = raw?.certainty === 'announced' ? normalizedAnnouncement(raw, now, true) : null;
    if (item) upcoming.push(item); else invalid = true;
  }
  const history = product.events.filter(raw => raw?.certainty !== 'hinted').map(raw => normalizedAnnouncement(raw, now)).filter(Boolean);
  const current = history.filter(item => item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS ||
    item.deliveredAt && active(item, now));
  const combined = deduplicate([...upcoming, ...current]);
  return { status: invalid ? 'unavailable' : 'ok', items: combined.filter(item => active(item, now)),
    history: deduplicate(history).sort((a,b) => Date.parse(b.announcedAt || 0) - Date.parse(a.announcedAt || 0)).slice(0,50),
    sourceUpdatedAt: data.generated_at, stale: invalid };
}

export async function createAnnouncementStore({ file, now = Date.now } = {}) {
  let snapshot = emptyAnnouncements(), writes = Promise.resolve();
  let baselineAt = null;
  const observed = new Set(), unread = new Map();
  const alertIdentity = id => {
    if(typeof id !== 'string')return null;
    const kind = id.endsWith('#banked') ? 'banked' : id.endsWith('#regular') ? 'regular' : null;
    return kind && safeHttpsUrl(id.slice(0, -kind.length - 1)) ? { id, kind } : null;
  };
  const alerts = () => ({ unread: [...unread.values()] });
  const clean = entries => (Array.isArray(entries) ? entries : []).slice(0,100)
    .map(item => normalizedAnnouncement(item, now(), false, true)).filter(Boolean);
  try {
    const saved = JSON.parse(await readFile(file, 'utf8'));
    if (saved.version === 1) snapshot = { ...snapshot, items: clean(saved.items), history: clean(saved.history),
      sourceUpdatedAt: timestamp(saved.sourceUpdatedAt, now()),
      lastFetchedAt: Number.isFinite(saved.lastFetchedAt) && saved.lastFetchedAt >= 0 && saved.lastFetchedAt <= now() ? saved.lastFetchedAt : null, stale: true };
    const tracking = saved.version === 1 && saved.alertTracking;
    if(tracking?.version === 1 && Number.isFinite(tracking.baselineAt) && tracking.baselineAt <= now()) {
      baselineAt = tracking.baselineAt;
      for(const id of (Array.isArray(tracking.observed) ? tracking.observed : []).slice(-500))if(alertIdentity(id))observed.add(id);
      for(const entry of (Array.isArray(tracking.unread) ? tracking.unread : []).slice(0,100)) {
        const identity = alertIdentity(entry?.id);
        if(identity && identity.kind === entry.kind && observed.has(identity.id) &&
          [...snapshot.items,...snapshot.history].some(item=>item.id===identity.id && confirmedAnnouncement(item)))unread.set(identity.id,identity);
      }
    }
  } catch {}
  const project = () => {
    const items = snapshot.items.filter(item => active(item, now()));
    return { ...snapshot, items, history: deduplicate([...snapshot.history, ...snapshot.items.filter(item => !active(item, now()))])
      .sort((a,b)=>Date.parse(b.announcedAt || 0)-Date.parse(a.announcedAt || 0)).slice(0,50),
      stale: snapshot.stale || !snapshot.sourceUpdatedAt || now() - Date.parse(snapshot.sourceUpdatedAt) > MAX_AGE_MS };
  };
  const persist = async () => {
    if(!file)return;
    writes = writes.catch(()=>{}).then(async()=>{
      await mkdir(dirname(file), { recursive: true }); const temp = file + '.' + process.pid + '.tmp';
      await writeFile(temp, JSON.stringify({ version:1, ...project(), alertTracking: {
        version:1, baselineAt, observed:[...observed].slice(-500), unread:alerts().unread,
      } }), { mode:0o600 }); await rename(temp,file);
    });
    // Storage failure must not erase confirmed live data or unread notices.
    await writes.catch(()=>{});
  };
  return {
    get state() { return project(); },
    get alerts() { return alerts(); },
    async acknowledge(ids) {
      for(const id of (Array.isArray(ids) ? ids : []).slice(0,100))unread.delete(id);
      await persist();
      return alerts();
    },
    async update(input) {
      const known=new Map([...snapshot.history,...snapshot.items].map(item=>[item.id,item]));
      const mergeKnown=item=>known.has(item.id)?deduplicate([known.get(item.id),item])[0]:item;
      const freshItems = clean(input?.items).map(mergeKnown), freshHistory = clean(input?.history).map(mergeKnown);
      const fresh=input?.status === 'ok' && !input.stale && recentTimestamp(input.sourceUpdatedAt,now());
      if(fresh) {
        if(baselineAt !== null)for(const item of freshItems) {
          if(confirmedAnnouncement(item) && (!observed.has(item.id) || known.has(item.id) && !confirmedAnnouncement(known.get(item.id))) && item.announcedAt && Date.parse(item.announcedAt) >= baselineAt)
            unread.set(item.id,{id:item.id,kind:item.kind});
        }
        else baselineAt = now();
        for(const item of [...freshHistory,...freshItems])observed.add(item.id);
      }
      for(const item of [...freshHistory,...freshItems])if(!confirmedAnnouncement(item))unread.delete(item.id);
      const previous = project(), previousItems = previous.items;
      const evidence = new Map([...freshHistory, ...freshItems].map(item => [item.id, item]));
      // Absence only changes status when both complete, fresh feeds agree. Failure
      // or an empty single-source lookup must preserve the pending announcement.
      const reconciled=fresh && Array.isArray(input.reconciledIds) && input.reconciledIds.every(id=>alertIdentity(id)) ? new Set(input.reconciledIds) : null;
      const retained = previousItems.map(item => evidence.has(item.id) ? deduplicate([item, evidence.get(item.id)])[0] :
        reconciled && !reconciled.has(item.id) && !item.deliveredAt ? {...item,sourceWithdrawn:true} : item);
      for(const item of retained)if(item.sourceWithdrawn)unread.delete(item.id);
      snapshot = { status: input?.status === 'ok' ? 'ok' : 'unavailable',
        lastFetchedAt: fresh ? now() : snapshot.lastFetchedAt,
        items: deduplicate([...retained, ...freshItems]),
        history: deduplicate([...previous.history, ...freshHistory, ...retained.filter(item=>item.sourceWithdrawn)]),
        sourceUpdatedAt: timestamp(input?.sourceUpdatedAt, now()) || snapshot.sourceUpdatedAt,
        stale: input?.status !== 'ok' || input?.stale === true || retained.some(item => !item.sourceWithdrawn && !evidence.has(item.id)) };
      await persist();
      return project();
    },
  };
}

export function normalizeResets(data, now = Date.now()) {
  if (data?.schema_version !== 1 || !recentTimestamp(data.generated_at, now) ||
      !Array.isArray(data.events)) return null;
  const latest = data.events.filter(event => event?.kind === 'regular' &&
    Number.isFinite(Date.parse(event.announced_at)) && Date.parse(event.announced_at) <= now)
    .sort((a, b) => Date.parse(b.announced_at) - Date.parse(a.announced_at))[0];
  if (!latest) return null;
  const deliveredAt = latest.delivered_at && Number.isFinite(Date.parse(latest.delivered_at)) &&
    Date.parse(latest.delivered_at) <= now ? latest.delivered_at : null;
  return {
    announcedAt: latest.announced_at,
    deliveredAt,
    scope: typeof latest.scope === 'string' ? latest.scope : null,
    sourceUrl: safeHttpsUrl(latest.url),
    deliverySourceUrl: deliveredAt ? safeHttpsUrl(latest.delivered_source_url) : null,
    sourceUpdatedAt: data.generated_at,
  };
}

async function fetchJson(url, fetchFn) {
  const response = await fetchFn(url, {
    headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`External API returned ${response.status}`);
  return response.json();
}

export async function queryExternal({ fetchFn = fetch, now = Date.now() } = {}) {
  const [resets, announcements] = await Promise.allSettled([
    fetchJson(`${ROOT}/resets.json`, fetchFn),
    fetchJson('https://whenreset.app/api/v1/resets.json', fetchFn),
  ]);
  const lastGlobal = resets.status === 'fulfilled' ? normalizeResets(resets.value, now) : null;
  const announcementView=announcements.status === 'fulfilled' ? normalizeAnnouncements(announcements.value, now) : emptyAnnouncements();
  if (lastGlobal && announcementView.status === 'ok') {
    const events=[...resets.value.events,...announcements.value.products.codex.events];
    const records=events.map(raw=>normalizedAnnouncement(raw,now));
    if(records.every(Boolean))announcementView.reconciledIds=[...new Set([
      ...records.map(item=>item.id),
      ...announcementView.items.map(item=>item.id),
    ])];
  }
  return {
    status: lastGlobal || announcementView.status === 'ok' ? 'ok' : 'unavailable',
    lastGlobal,
    announcements: announcementView,
    updatedAt: now,
  };
}
