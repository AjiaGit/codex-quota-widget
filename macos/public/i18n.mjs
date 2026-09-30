const en = {
  brand:'Codex quota', remaining:'Remaining', weekly:'Weekly remaining', updated:'Updated', loading:'Loading', querying:'Reading Codex quota',
  unavailable:'Unavailable', stale:'Data expired', waiting:'Waiting for new cycle', waitingData:'Waiting for updated quota', resetPassed:'Reset time reached; waiting for an update',
  reset:'Resets at', countdown:'Time to reset', lastUpdate:'Last updated', resets:'Rate-limit resets', refresh:'Refresh now', interval:'Quota refreshes every minute',
  fiveHour:'Plus · 5-hour quota', global:'Public global resets', announcement:'Last announcement', delivery:'Delivery record', odds:'Estimated odds',
  forecastNote:'Historical estimate, not a reset guarantee', language:'Language', auto:'System default',
  paid:'Paid accounts', all:'All accounts', unknownScope:'Scope unknown', delivered:'Delivery recorded by source', deliveryUnknown:'Delivery time not confirmed',
  dataTime:'Source updated', sourceUnavailable:'Source data unavailable',
  cli_missing:'Install Codex CLI or the Codex desktop app, then reopen the widget.',
  signed_out:'Sign in to Codex, then click Refresh.', timeout:'Codex took too long. Retrying automatically.',
  network:'Connection failed. Retrying automatically.', unsupported:'This account does not report a weekly Codex quota.',
  service_unavailable:'The local widget service is not connected. Reopen the app.', query_failed:'Cannot read Codex quota. Update Codex and retry.',
  resetDetails:'Available reset details', detailsUnknown:'Grant and expiry details are not provided.', detailsEmpty:'No detail rows were provided.',
  detailsPartial:'The list may be incomplete; the available count above is authoritative.', granted:'Granted', expires:'Expires', dateUnknown:'Not provided',
  genericReset:'Rate-limit reset', nextGrant:'Future grant dates are not provided by Codex.', resetCount:'{count} resets', resetOne:'1 reset', percentRemaining:'{percent}% remaining',
  daysHours:'{days}d {hours}h', hoursMinutes:'{hours}h {minutes}m', hoursOnly:'{hours}h', minutesOnly:'{minutes}m',
  oddsValue:'24h {a}% · 48h {b}% · 7d {c}%', installCodex:'Codex setup instructions',
};
const zh = {
  brand:'Codex 周额度', remaining:'剩余', weekly:'本周剩余', updated:'数据已更新', loading:'正在读取', querying:'正在查询 Codex 额度',
  unavailable:'暂不可用', stale:'数据已过期', waiting:'等待新周期数据', waitingData:'正在等待新的额度数据', resetPassed:'重置时间已到，正在等待更新',
  reset:'重置时间', countdown:'距离重置', lastUpdate:'最近更新', resets:'重置卡', refresh:'立即刷新', interval:'每分钟读取一次额度',
  fiveHour:'Plus · 5 小时额度', global:'公开全局临时重置', announcement:'上次公告', delivery:'送达记录', odds:'未来概率',
  forecastNote:'历史频率估计，非重置承诺', language:'语言', auto:'跟随系统',
  paid:'付费账号', all:'所有账号', unknownScope:'范围未明', delivered:'站点记录已送达', deliveryUnknown:'送达时间未确认',
  dataTime:'数据时间', sourceUnavailable:'站点数据暂不可用',
  cli_missing:'请安装 Codex CLI 或 Codex 桌面应用，然后重新打开工具。', signed_out:'请先登录 Codex，然后点击刷新。',
  timeout:'Codex 查询超时，正在自动重试。', network:'网络连接失败，正在自动重试。', unsupported:'当前账号未提供七天 Codex 额度。',
  service_unavailable:'本机监控服务未连接，请重新打开工具。', query_failed:'无法读取 Codex 额度，请更新 Codex 后重试。',
  resetDetails:'可用重置卡详情', detailsUnknown:'Codex 未提供发放和到期详情。', detailsEmpty:'Codex 未提供详情条目。',
  detailsPartial:'列表可能不完整，可用数量以上方显示为准。', granted:'发放', expires:'到期', dateUnknown:'未提供',
  genericReset:'重置卡', nextGrant:'Codex 未提供未来发放日期。', resetCount:'{count} 张', resetOne:'1 张', percentRemaining:'{percent}% 剩余',
  daysHours:'{days}天 {hours}小时', hoursMinutes:'{hours}小时 {minutes}分钟', hoursOnly:'{hours}小时', minutesOnly:'{minutes}分钟',
  oddsValue:'24 小时 {a}% · 48 小时 {b}% · 7 天 {c}%', installCodex:'Codex 安装说明',
};
export const dictionaries = { en, 'zh-CN': zh };
export function resolveLanguage(setting='auto', systemLanguage='en') {
  return setting === 'zh-CN' || (setting === 'auto' && /^zh\b/i.test(systemLanguage)) ? 'zh-CN' : 'en';
}
export function t(language, key, vars={}) {
  return (dictionaries[language]?.[key] || en[key] || key).replace(/\{(\w+)\}/g, (_,name)=>String(vars[name] ?? ''));
}
export function formatDate(milliseconds, timeZone, language) {
  if (!Number.isFinite(milliseconds) || Math.abs(milliseconds)>8640000000000000) return t(language,'dateUnknown');
  return new Intl.DateTimeFormat(language, {timeZone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(milliseconds));
}
