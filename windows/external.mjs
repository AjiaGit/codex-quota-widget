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

const emptyAnnouncements = () => ({ status: 'unavailable', items: [], history: [], sourceUpdatedAt: null, stale: true });
function timestamp(value, now, earliest = -Infinity) {
  const ms = typeof value === 'string' ? Date.parse(value) : NaN;
  return Number.isFinite(ms) && ms <= now && ms >= earliest ? new Date(ms).toISOString() : null;
}
function dateOnly(value) {
  if(typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
  const ms=Date.parse(value+'T00:00:00Z');
  return Number.isFinite(ms)&&new Date(ms).toISOString().slice(0,10)===value?value:null;
}
const text = value => typeof value === 'string' ? value.slice(0, 2000) : null;
function normalizedAnnouncement(raw, now, scheduled = false, persisted = false) {
  if (!['banked', 'regular'].includes(raw?.kind)) return null;
  const sourceUrl = safeHttpsUrl(persisted ? raw.sourceUrl : raw.url);
  if (!sourceUrl) return null;
  const announcedAt = timestamp(persisted ? raw.announcedAt : raw.ts, now);
  const deliveredAt = timestamp(persisted ? raw.deliveredAt : raw.delivered_at, now, announcedAt ? Date.parse(announcedAt) : -Infinity);
  const schedule = persisted ? raw.scheduledAt : scheduled ? raw.scheduled_at : null;
  const scheduledMs = typeof schedule === 'string' ? Date.parse(schedule) : NaN;
  return {
    id: sourceUrl + '#' + raw.kind,
    kind: raw.kind, announcedAt,
    scheduledAt: Number.isFinite(scheduledMs) ? new Date(scheduledMs).toISOString() : null,
    scheduledDate: dateOnly(persisted ? raw.scheduledDate : scheduled ? raw.date : null),
    deliveredAt, scope: text(raw.scope), scopeLabel: text(persisted ? raw.scopeLabel : raw.scope_label),
    sourceUrl, deliverySourceUrl: deliveredAt ? safeHttpsUrl(persisted ? raw.deliverySourceUrl : raw.delivered_source_url) : null,
    summary: text(raw.summary), summaryZh: text(persisted ? raw.summaryZh : raw.summary_zh),
  };
}
function deduplicate(items) {
  const map = new Map();
  for (const item of items) {
    const previous = map.get(item.id);
    map.set(item.id, previous ? { ...previous, ...item,
      scheduledAt: item.scheduledAt || previous.scheduledAt,
      scheduledDate: item.scheduledDate || previous.scheduledDate,
      deliveredAt: item.deliveredAt || previous.deliveredAt,
      deliverySourceUrl: item.deliverySourceUrl || previous.deliverySourceUrl } : item);
  }
  return [...map.values()];
}
const active = (item, now) => !item.deliveredAt || now - Date.parse(item.deliveredAt) < MAX_AGE_MS;

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
  const history = product.events.map(raw => normalizedAnnouncement(raw, now)).filter(Boolean);
  const current = history.filter(item => item.announcedAt && now - Date.parse(item.announcedAt) < MAX_AGE_MS ||
    item.deliveredAt && active(item, now));
  const combined = deduplicate([...upcoming, ...current]);
  return { status: invalid ? 'unavailable' : 'ok', items: combined.filter(item => active(item, now)),
    history: deduplicate(history).sort((a,b) => Date.parse(b.announcedAt || 0) - Date.parse(a.announcedAt || 0)).slice(0,50),
    sourceUpdatedAt: data.generated_at, stale: invalid };
}

export async function createAnnouncementStore({ file, now = Date.now } = {}) {
  let snapshot = emptyAnnouncements(), writes = Promise.resolve();
  const clean = entries => (Array.isArray(entries) ? entries : []).slice(0,100)
    .map(item => normalizedAnnouncement(item, now(), false, true)).filter(Boolean);
  try {
    const saved = JSON.parse(await readFile(file, 'utf8'));
    if (saved.version === 1) snapshot = { ...snapshot, items: clean(saved.items), history: clean(saved.history),
      sourceUpdatedAt: timestamp(saved.sourceUpdatedAt, now()), stale: true };
  } catch {}
  const project = () => {
    const items = snapshot.items.filter(item => active(item, now()));
    return { ...snapshot, items, history: deduplicate([...snapshot.history, ...snapshot.items.filter(item => !active(item, now()))])
      .sort((a,b)=>Date.parse(b.announcedAt || 0)-Date.parse(a.announcedAt || 0)).slice(0,50),
      stale: snapshot.stale || !snapshot.sourceUpdatedAt || now() - Date.parse(snapshot.sourceUpdatedAt) > MAX_AGE_MS };
  };
  return {
    get state() { return project(); },
    async update(input) {
      const freshItems = clean(input?.items), freshHistory = clean(input?.history);
      const previous = project(), previousItems = previous.items;
      const evidence = new Map([...freshHistory, ...freshItems].map(item => [item.id, item]));
      const retained = previousItems.map(item => evidence.has(item.id) ? deduplicate([item, evidence.get(item.id)])[0] : item);
      snapshot = { status: input?.status === 'ok' ? 'ok' : 'unavailable',
        items: deduplicate([...retained, ...freshItems]),
        history: deduplicate([...previous.history, ...freshHistory]),
        sourceUpdatedAt: timestamp(input?.sourceUpdatedAt, now()) || snapshot.sourceUpdatedAt,
        stale: input?.status !== 'ok' || input?.stale === true || previousItems.some(item => !evidence.has(item.id)) };
      if (file) {
        writes = writes.catch(()=>{}).then(async()=>{
          await mkdir(dirname(file), { recursive: true }); const temp = file + '.' + process.pid + '.tmp';
          await writeFile(temp, JSON.stringify({ version:1, ...project() }), { mode:0o600 }); await rename(temp,file);
        });
        // A storage error must not erase confirmed data from the live widget.
        await writes.catch(()=>{});
      }
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

export function normalizeForecast(data, now = Date.now()) {
  if (data?.schema_version !== 1 || data.available !== true ||
      !recentTimestamp(data.generated_at, now)) return null;
  const values = [data.probabilities?.raw_24h, data.probabilities?.raw_48h,
    data.probabilities?.raw_7d];
  if (!values.every(value => Number.isFinite(value) && value >= 0 && value <= 1) ||
      values[0] > values[1] || values[1] > values[2]) return null;
  return {
    next24h: Math.round(values[0] * 100),
    next48h: Math.round(values[1] * 100),
    next7d: Math.round(values[2] * 100),
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
  const [resets, forecast, announcements] = await Promise.allSettled([
    fetchJson(`${ROOT}/resets.json`, fetchFn),
    fetchJson(`${ROOT}/forecast.json`, fetchFn),
    fetchJson('https://whenreset.app/api/v1/resets.json', fetchFn),
  ]);
  const lastGlobal = resets.status === 'fulfilled' ? normalizeResets(resets.value, now) : null;
  const odds = forecast.status === 'fulfilled' ? normalizeForecast(forecast.value, now) : null;
  return {
    status: lastGlobal || odds ? 'ok' : 'unavailable',
    lastGlobal,
    forecast: odds,
    announcements: announcements.status === 'fulfilled' ? normalizeAnnouncements(announcements.value, now) : emptyAnnouncements(),
    updatedAt: now,
  };
}
