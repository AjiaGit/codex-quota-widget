const en = {
  updatedNow:'Updated just now', updatedAgo:'Updated {minutes} min ago',
  confirmedAnnouncements:'Confirmed announcements', confirmedGrant:'Confirmed banked reset grant', confirmedReset:'Confirmed global reset',
  noAnnouncements:'Monitored sources report no confirmed banked reset grant or global reset announcements', announcementsUnavailable:'Announcement information unavailable', informationPending:'Information pending update',
  upcoming:'Upcoming', waitingDelivery:'Time reached; awaiting confirmation', announcedWaiting:'Announced; awaiting delivery', historyDeliveryUnknown:'Source did not provide a delivery record', grantDone:'Granted', resetDone:'Reset confirmed',
  scheduled:'Scheduled', source:'Source', announcementHistory:'Announcements and delivery records', historyEmpty:'No announcement records available', compact:'Switch to compact', hide:'Hide floating widget',
  viewAnnouncement:'View announcement', details:'Details', completed:'Completed', original:'Scheduled', retention:'Completed results retained for 24h', publicPending:'Public information pending update', lastSuccess:'Last source update', cadence:'Auto-refresh: quota every 1 min · public data every 10 min',
  sevenDays:'7d', historyAttribution:'Earlier historical records',
  brand:'Codex quota', remaining:'Remaining', weekly:'Weekly remaining', updated:'Updated', loading:'Loading', querying:'Reading Codex quota',
  unavailable:'Unavailable', stale:'Data expired', waiting:'Waiting for new cycle', waitingData:'Waiting for updated quota', resetPassed:'Reset time reached; waiting for an update',
  reset:'Resets at', countdown:'Time to reset', lastUpdate:'Last updated', resets:'Banked resets', refresh:'Refresh now', interval:'Quota refreshes every minute',
  fiveHour:'Plus · 5-hour quota', global:'Public global resets', announcement:'Last announcement', delivery:'Delivery record', odds:'Global reset estimates',
  forecastNote:'Historical estimate, not a reset promise', language:'Language', auto:'System default',
  paid:'Paid accounts', all:'All accounts', unknownScope:'Scope unknown', delivered:'Delivery recorded by source', deliveryUnknown:'Delivery time not confirmed',
  dataTime:'Source updated', sourceUnavailable:'Source data unavailable',
  cli_missing:'Install Codex CLI or the Codex desktop app, then reopen the widget.',
  signed_out:'Sign in to Codex, then click Refresh.', timeout:'Codex took too long. Retrying automatically.',
  network:'Connection failed. Retrying automatically.', unsupported:'This account does not report a weekly Codex quota.',
  service_unavailable:'The local widget service is not connected. Reopen the app.', query_failed:'Cannot read Codex quota. Update Codex and retry.',
  resetDetails:'Available reset details', detailsUnknown:'Grant and expiry details are not provided.', detailsEmpty:'No detail rows were provided.', detailsPending:'Quota data unavailable or expired; refresh to view current reset details.',
  detailsPartial:'The list may be incomplete; the available count above is authoritative.', granted:'Granted', expires:'Expires', dateUnknown:'Not provided',
  genericReset:'Banked reset', nextGrant:'Future grant dates are not provided by Codex.', resetCount:'{count} resets', resetOne:'1 reset', percentRemaining:'{percent}% remaining',
  daysHours:'{days}d {hours}h', hoursMinutes:'{hours}h {minutes}m', hoursOnly:'{hours}h', minutesOnly:'{minutes}m',
  oddsValue:'24h {a}% · 48h {b}% · 7d {c}%', installCodex:'Codex setup instructions',
};
const zh = {
  updatedNow:'刚刚更新', updatedAgo:'{minutes} 分钟前更新',
  confirmedAnnouncements:'已确认预告', confirmedGrant:'已确认重置次数赠送', confirmedReset:'已确认全局额度重置',
  noAnnouncements:'监控来源暂无已确认的赠送或全局额度重置公告', announcementsUnavailable:'预告信息暂不可用', informationPending:'信息待更新',
  upcoming:'即将到来', waitingDelivery:'时间已到，等待确认', announcedWaiting:'已公告，等待送达确认', historyDeliveryUnknown:'来源未提供送达记录', grantDone:'已赠送', resetDone:'已重置',
  scheduled:'预定', source:'来源', announcementHistory:'公告与送达记录', historyEmpty:'暂无公告记录', compact:'切换到极简', hide:'隐藏悬浮窗',
  viewAnnouncement:'查看公告', details:'详情', completed:'确认完成', original:'原定', retention:'完成结果保留 24 小时', publicPending:'公开数据待更新', lastSuccess:'上次来源更新', cadence:'自动刷新：额度每 1 分钟 · 公共信息每 10 分钟',
  sevenDays:'7 天', historyAttribution:'早期历史记录',
  brand:'Codex 周额度', remaining:'剩余', weekly:'本周剩余', updated:'数据已更新', loading:'正在读取', querying:'正在查询 Codex 额度',
  unavailable:'暂不可用', stale:'数据已过期', waiting:'等待新周期数据', waitingData:'正在等待新的额度数据', resetPassed:'重置时间已到，正在等待更新',
  reset:'重置时间', countdown:'距离重置', lastUpdate:'最近更新', resets:'可用重置', refresh:'立即刷新', interval:'每分钟读取一次额度',
  fiveHour:'Plus · 5 小时额度', global:'公开全局额度重置', announcement:'上次公告', delivery:'送达记录', odds:'全局重置历史估计',
  forecastNote:'历史估计，非重置承诺', language:'语言', auto:'跟随系统',
  paid:'付费账号', all:'所有账号', unknownScope:'范围未明', delivered:'站点记录已送达', deliveryUnknown:'送达时间未确认',
  dataTime:'数据时间', sourceUnavailable:'站点数据暂不可用',
  cli_missing:'请安装 Codex CLI 或 Codex 桌面应用，然后重新打开工具。', signed_out:'请先登录 Codex，然后点击刷新。',
  timeout:'Codex 查询超时，正在自动重试。', network:'网络连接失败，正在自动重试。', unsupported:'当前账号未提供七天 Codex 额度。',
  service_unavailable:'本机监控服务未连接，请重新打开工具。', query_failed:'无法读取 Codex 额度，请更新 Codex 后重试。',
  resetDetails:'可用重置详情', detailsUnknown:'Codex 未提供发放和到期详情。', detailsEmpty:'Codex 未提供详情条目。', detailsPending:'额度数据暂不可用或已过期，请刷新后查看重置详情。',
  detailsPartial:'列表可能不完整，可用数量以上方显示为准。', granted:'发放', expires:'到期', dateUnknown:'未提供',
  genericReset:'可用重置', nextGrant:'Codex 未提供未来发放日期。', resetCount:'{count} 次', resetOne:'1 次', percentRemaining:'{percent}% 剩余',
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
export function formatRelativeUpdate(milliseconds, now=Date.now(), language='en') {
  if (!Number.isFinite(milliseconds) || milliseconds > now || now-milliseconds > 10*60*1000) return t(language,'unavailable');
  const minutes=Math.floor((now-milliseconds)/60000);
  return minutes < 1 ? t(language,'updatedNow') : t(language,'updatedAgo',{minutes});
}
export function formatShortDate(milliseconds,timeZone,language,now=Date.now(),dateOnly=false) {
  if (!Number.isFinite(milliseconds) || Math.abs(milliseconds)>8640000000000000) return t(language,'dateUnknown');
  const year = new Intl.DateTimeFormat('en',{timeZone,year:'numeric'});
  const options={timeZone,month:'2-digit',day:'2-digit'};
  if(year.format(milliseconds)!==year.format(now))options.year='numeric';
  if(!dateOnly)Object.assign(options,{hour:'2-digit',minute:'2-digit',hour12:false});
  return new Intl.DateTimeFormat(language,options).format(milliseconds);
}
