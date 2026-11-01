// Le document envoyé au Mac d'Alane (chiffré avant l'envoi). Ne contient que des heures et des nombres : aucun texte, projet ni chemin.
import { buckets, lastActivityAt } from "./ledger.js";

export const REPORT_VERSION = 1;

export function buildReport({ messages, now, reason, collectorVersion, platform }) {
  const last = lastActivityAt(messages);
  return {
    kind: "guest-activity",
    version: REPORT_VERSION,
    updatedAt: new Date(now).toISOString(),
    reason,
    collector: { version: collectorVersion, platform },
    lastActivityAt: last ? new Date(last).toISOString() : null,
    bucketMinutes: 5,
    buckets: buckets(messages),
  };
}
