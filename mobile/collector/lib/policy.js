// Quand envoyer : le relais gratuit accepte 1 000 écritures par jour pour tout le compte, et le Mac en prend déjà jusqu'à 288 (ADR 003).

export const MIN_PUSH_MS = 10 * 60 * 1000;
export const HEARTBEAT_MS = 6 * 3600 * 1000;
/** Plafond de sécurité : 144 envois d'activité par jour au plus, plus les signes de vie. */
export const DAILY_CAP = 150;

/**
 * @param {{now: number, lastPushAt: number|null, lastActivityAt: number|null, pushedActivityAt: number|null, pushesToday: number}} state
 * @returns {"activity"|"heartbeat"|null} la raison d'envoyer maintenant, ou null.
 */
export function pushReason({ now, lastPushAt, lastActivityAt, pushedActivityAt, pushesToday }) {
  if (pushesToday >= DAILY_CAP) return null;
  if (lastPushAt === null || lastPushAt === undefined) return "activity";   // premier envoi : le Mac apprend que le collecteur existe
  const elapsed = now - lastPushAt;
  const fresh = lastActivityAt !== null && lastActivityAt !== undefined && lastActivityAt > (pushedActivityAt ?? 0);
  if (fresh && elapsed >= MIN_PUSH_MS) return "activity";
  if (elapsed >= HEARTBEAT_MS) return "heartbeat";
  return null;
}

/** Jour local au format AAAA-MM-JJ : sert à remettre le compteur quotidien à zéro. */
export function dayStamp(now) {
  const date = new Date(now);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}
