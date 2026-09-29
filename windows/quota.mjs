function usableWindow(window) {
  return window && Number.isFinite(window.usedPercent) && window.usedPercent >= 0 &&
    window.usedPercent <= 100 && Number.isSafeInteger(window.resetsAt) && window.resetsAt > 0;
}

function pickWindow(bucket, minutes) {
  const window = [bucket.primary, bucket.secondary].find(item => item?.windowDurationMins === minutes);
  return usableWindow(window)
    ? { remainingPercent: Math.round(100 - window.usedPercent), resetsAt: window.resetsAt }
    : null;
}

export function normalizeQuota(response, accountPlanType = null) {
  if (!response || typeof response !== 'object') return null;

  const buckets = response.rateLimitsByLimitId;
  const codex = buckets && Object.hasOwn(buckets, 'codex')
    ? buckets.codex
    : response.rateLimits;
  if (!codex || typeof codex !== 'object') return null;

  const weekly = pickWindow(codex, 10080);
  if (!weekly) return null;

  const rawPlan = String(accountPlanType || codex.planType || '').toLowerCase();
  const plan = rawPlan.startsWith('plus') ? 'plus' : rawPlan.startsWith('pro') ? 'pro' : 'unknown';
  const availableCount = response.rateLimitResetCredits?.availableCount;

  return {
    ...weekly,
    plan,
    fiveHour: plan === 'plus' ? pickWindow(codex, 300) : null,
    resetCards: Number.isSafeInteger(availableCount) && availableCount >= 0 ? availableCount : null,
  };
}
