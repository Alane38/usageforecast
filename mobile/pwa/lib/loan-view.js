// Lecture des données de prêt publiées par le Mac : le résumé dans le snapshot du propriétaire (`snapshot.loan`) et la vue de l'invité
// (document `guest-view` déposé dans son coffre de lecture). Mêmes noms de champs que app/LoanPublishing.swift.

const isNumber = (value) => typeof value === "number" && Number.isFinite(value);
const number = (value) => (isNumber(value) ? value : null);
const toDate = (value) => {
  const date = typeof value === "string" ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime()) ? date : null;
};

function terms(raw) {
  const startsAt = toDate(raw.startsAt), endsAt = toDate(raw.endsAt);
  if (!startsAt || !endsAt || !isNumber(raw.share) || raw.share <= 0 || raw.share >= 1) return null;
  return {
    guestName: String(raw.guestName ?? "").trim() || "l'invité",
    sharePoints: raw.share * 100,
    reservePoints: 100 - raw.share * 100,
    startsAt, endsAt,
    active: raw.active === true,
    guestUsed: number(raw.guestUsed) ?? 0,
    guestMeasured: number(raw.guestMeasured) ?? 0,
    guestEstimated: number(raw.guestEstimated) ?? 0,
    guestRatePerDay: number(raw.guestRatePerDay),
    guestExhaustsAt: toDate(raw.guestExhaustsAt),
  };
}

/** Résumé du prêt dans le snapshot du Mac (null s'il n'y a pas de prêt ou s'il est illisible). */
export function loanInfoOf(raw) {
  if (!raw || typeof raw !== "object") return null;
  const base = terms(raw);
  if (!base) return null;
  return { ...base,
    ownerUsed: number(raw.ownerUsed) ?? 0,
    collectorAt: toDate(raw.collectorAt),
    collectorPlatform: typeof raw.collectorPlatform === "string" ? raw.collectorPlatform : null,
    status: typeof raw.status === "string" ? raw.status : "",
    lastCommandID: typeof raw.lastCommandID === "string" ? raw.lastCommandID : null };
}

/** Vue de l'invité (null si ce n'en est pas une, ou si elle est illisible). */
export function guestViewOf(raw) {
  if (!raw || raw.kind !== "guest-view" || raw.version !== 1) return null;
  const updatedAt = toDate(raw.updatedAt);
  const base = terms(raw);
  if (!updatedAt || !base) return null;
  return { kind: "guest", updatedAt, dataAt: updatedAt, ...base,
    reserveLeft: number(raw.reserveLeft),
    days: (Array.isArray(raw.days) ? raw.days : []).filter((day) => typeof day.day === "string" && isNumber(day.points))
      .map((day) => ({ day: day.day, points: day.points })) };
}

/** Points restants, et rythme conseillé pour finir la période sans dépasser (points par jour). */
export function guestBudget(view, now) {
  const left = Math.max(view.sharePoints - view.guestUsed, 0);
  const days = Math.max((view.endsAt - now) / 86400000, 0);
  return { left, perDay: days >= 0.5 ? left / days : null, over: Math.max(view.guestUsed - view.sharePoints, 0) };
}
