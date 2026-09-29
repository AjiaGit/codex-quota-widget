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
    return url.protocol === 'https:' ? url.href : null;
  } catch { return null; }
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
  const [resets, forecast] = await Promise.allSettled([
    fetchJson(`${ROOT}/resets.json`, fetchFn),
    fetchJson(`${ROOT}/forecast.json`, fetchFn),
  ]);
  const lastGlobal = resets.status === 'fulfilled' ? normalizeResets(resets.value, now) : null;
  const odds = forecast.status === 'fulfilled' ? normalizeForecast(forecast.value, now) : null;
  return {
    status: lastGlobal || odds ? 'ok' : 'unavailable',
    lastGlobal,
    forecast: odds,
    updatedAt: now,
  };
}
