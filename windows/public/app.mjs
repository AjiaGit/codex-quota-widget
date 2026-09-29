const TEN_MINUTES = 10 * 60 * 1000;

function formatDateTime(milliseconds, timeZone) {
  return new Intl.DateTimeFormat('zh-CN', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(new Date(milliseconds));
}

function formatCountdown(milliseconds) {
  const minutes = Math.max(0, Math.ceil(milliseconds / 60000));
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  const rest = minutes % 60;
  if (days) return `${days}天 ${hours}小时`;
  if (hours) return rest ? `${hours}小时 ${rest}分钟` : `${hours}小时`;
  return `${rest}分钟`;
}

export function deriveView(state, now = Date.now(), timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
  const unavailable = (statusText, message) => ({
    statusText, message, percentText: '—', ringPercent: 0, tone: 'muted',
    resetText: '—', countdownText: '—', updatedText: '—', cardsText: '—',
    showFiveHour: false, fiveHourText: '—', fiveHourResetText: '—',
  });
  if (state?.status === 'loading') return unavailable('正在读取', '正在查询 Codex 额度');
  if (state?.status !== 'ok') return unavailable('暂不可用', state?.message || '无法读取额度');

  const resetMs = state.resetsAt * 1000;
  if (!Number.isFinite(state.updatedAt) || now - state.updatedAt > TEN_MINUTES) {
    return unavailable('数据已过期', '正在等待新的额度数据');
  }
  if (!Number.isFinite(resetMs) || now >= resetMs) {
    return unavailable('等待新周期数据', '重置时间已到，正在等待更新');
  }

  const percent = Math.max(0, Math.min(100, Math.round(state.remainingPercent)));
  const shortReset = state.fiveHour?.resetsAt * 1000;
  const shortValid = state.plan === 'plus' && Number.isFinite(shortReset) && shortReset > now &&
    Number.isFinite(state.fiveHour?.remainingPercent) && state.fiveHour.remainingPercent >= 0 &&
    state.fiveHour.remainingPercent <= 100;
  return {
    statusText: '数据已更新', message: '本周剩余',
    percentText: `${percent}%`, ringPercent: percent,
    tone: percent <= 10 ? 'danger' : percent <= 50 ? 'warning' : 'healthy',
    resetText: formatDateTime(resetMs, timeZone),
    countdownText: formatCountdown(resetMs - now),
    updatedText: formatDateTime(state.updatedAt, timeZone),
    cardsText: Number.isSafeInteger(state.resetCards) && state.resetCards >= 0 ? `${state.resetCards} 张` : '—',
    showFiveHour: state.plan === 'plus',
    fiveHourText: shortValid ? `${Math.round(state.fiveHour.remainingPercent)}% 剩余` : '暂不可用',
    fiveHourResetText: shortValid ? formatDateTime(shortReset, timeZone) : '—',
  };
}

export function deriveExternalView(state, timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
  const last = state?.status === 'ok' ? state.lastGlobal : null;
  const forecast = state?.status === 'ok' ? state.forecast : null;
  const scope = last?.scope === 'paid' ? '付费账号' : last?.scope === 'all' ? '所有账号' : '范围未明';
  return {
    announcementText: last?.announcedAt ? `${formatDateTime(Date.parse(last.announcedAt), timeZone)} · ${scope}` : '暂不可用',
    deliveryText: last?.deliveredAt ? `${formatDateTime(Date.parse(last.deliveredAt), timeZone)} · 站点记录已送达` : '送达时间未确认',
    oddsText: forecast ? `24 小时 ${forecast.next24h}% · 48 小时 ${forecast.next48h}% · 7 天 ${forecast.next7d}%` : '暂不可用',
    sourceText: forecast?.sourceUpdatedAt ? `数据时间 ${formatDateTime(Date.parse(forecast.sourceUpdatedAt), timeZone)}` : '站点数据暂不可用',
  };
}

if (typeof document !== 'undefined') {
  const byId = id => document.getElementById(id);
  const root = byId('card');
  const refreshButton = byId('refresh');
  let state = { status: 'loading' };
  let externalState = { status: 'loading' };
  let loading = false;

  function render() {
    const view = deriveView(state);
    root.dataset.tone = view.tone;
    root.style.setProperty('--ring-value', `${view.ringPercent}%`);
    byId('percent').textContent = view.percentText;
    byId('status').textContent = view.statusText;
    byId('caption').textContent = view.message;
    byId('reset').textContent = view.resetText;
    byId('countdown').textContent = view.countdownText;
    byId('updated').textContent = view.updatedText;
    byId('cards').textContent = view.cardsText;
    byId('five-hour').hidden = !view.showFiveHour;
    byId('five-hour-value').textContent = view.fiveHourText;
    byId('five-hour-reset').textContent = view.fiveHourResetText;
    const external = deriveExternalView(externalState);
    byId('global-announcement').textContent = external.announcementText;
    byId('global-delivery').textContent = external.deliveryText;
    byId('global-odds').textContent = external.oddsText;
    byId('external-updated').textContent = external.sourceText;
    byId('ring').setAttribute('aria-valuenow', String(view.ringPercent));
    byId('ring').setAttribute('aria-valuetext', view.percentText === '—' ? view.statusText : `${view.percentText} 剩余`);
    refreshButton.disabled = loading;
  }

  async function loadExternal() {
    try {
      const response = await fetch('/api/external', { cache: 'no-store' });
      if (!response.ok) throw new Error('服务未连接');
      externalState = await response.json();
    } catch { externalState = { status: 'unavailable' }; }
    render();
  }

  async function load(force = false) {
    if (loading) return;
    loading = true;
    render();
    try {
      const response = await fetch(force ? '/api/refresh' : '/api/usage', {
        method: force ? 'POST' : 'GET', cache: 'no-store',
      });
      if (!response.ok) throw new Error('服务未连接');
      state = await response.json();
    } catch {
      state = { status: 'unavailable', message: '本机监控服务未连接' };
    } finally {
      loading = false;
      render();
      loadExternal();
    }
  }

  refreshButton.addEventListener('click', () => load(true));
  document.addEventListener('visibilitychange', () => { if (!document.hidden) load(); });
  setInterval(() => load(), 60 * 1000);
  setInterval(render, 30 * 1000);
  render();
  load();
}
