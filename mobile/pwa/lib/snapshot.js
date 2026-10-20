// Validation du snapshot déchiffré. Une donnée inattendue ne doit jamais casser l'écran : on la refuse ou on la nettoie ici.

export const SUPPORTED_VERSION = 1;

const isNumber = (value) => typeof value === "number" && Number.isFinite(value);
const toDate = (value) => {
  const date = typeof value === "string" ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime()) ? date : null;
};

function windowOf(raw) {
  if (!raw || !isNumber(raw.percent)) return null;
  return {
    percent: raw.percent,
    resetsAt: toDate(raw.resetsAt),
    projectedPercent: isNumber(raw.projectedPercent) ? raw.projectedPercent : null,
    expectedPercent: isNumber(raw.expectedPercent) ? raw.expectedPercent : null,
    ratePerHour: isNumber(raw.ratePerHour) ? raw.ratePerHour : null,
    exhaustsAt: toDate(raw.exhaustsAt),
    perDayPercent: isNumber(raw.perDayPercent) ? raw.perDayPercent : null,
    pace: ["under", "onTrack", "over"].includes(raw.pace) ? raw.pace : null,
  };
}

function summaryOf(raw) {
  if (!raw || typeof raw.day !== "string" || !isNumber(raw.weeklyUsed) || !isNumber(raw.samples)) return null;
  return {
    day: raw.day,
    weeklyUsed: raw.weeklyUsed,
    sessionUsed: isNumber(raw.sessionUsed) ? raw.sessionUsed : 0,
    peakSession: isNumber(raw.peakSession) ? raw.peakSession : 0,
    activeHours: Array.isArray(raw.activeHours) ? raw.activeHours.filter((hour) => Number.isInteger(hour) && hour >= 0 && hour < 24) : [],
    samples: raw.samples,
  };
}

/** Nul si la version n'est pas supportée ou si les champs indispensables manquent. */
export function normalize(raw) {
  if (!raw || raw.version !== SUPPORTED_VERSION) return null;
  const updatedAt = toDate(raw.updatedAt);
  const dataAt = toDate(raw.dataAt) ?? updatedAt;
  if (!updatedAt || !raw.forecast) return null;
  return {
    version: raw.version,
    updatedAt,
    dataAt,
    appVersion: String(raw.appVersion ?? ""),
    source: raw.source === "statusline" ? "statusline" : "claude.ai",
    session: windowOf(raw.forecast.session),
    weekly: windowOf(raw.forecast.weekly),
    usedTodayPercent: isNumber(raw.forecast.usedTodayPercent) ? raw.forecast.usedTodayPercent : null,
    line: typeof raw.forecast.line === "string" ? raw.forecast.line : "",
    dayBudget: raw.dayBudget && isNumber(raw.dayBudget.allowed) && isNumber(raw.dayBudget.used)
      ? { allowed: raw.dayBudget.allowed, used: raw.dayBudget.used, level: ["ok", "close", "over"].includes(raw.dayBudget.level) ? raw.dayBudget.level : "ok" }
      : null,
    credits: raw.credits && typeof raw.credits.value === "string"
      ? { title: String(raw.credits.title ?? "Crédits API"), value: raw.credits.value, detail: String(raw.credits.detail ?? ""), usedFraction: isNumber(raw.credits.usedFraction) ? raw.credits.usedFraction : 0 }
      : null,
    servicesOK: typeof raw.servicesOK === "boolean" ? raw.servicesOK : null,
    history: (Array.isArray(raw.history) ? raw.history : []).filter((point) => isNumber(point.t)).map((point) => ({ t: point.t * 1000, s: isNumber(point.s) ? point.s : null, w: isNumber(point.w) ? point.w : null })),
    daily: (Array.isArray(raw.daily) ? raw.daily : []).map(summaryOf).filter(Boolean),
  };
}
