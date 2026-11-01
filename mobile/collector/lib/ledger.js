// Registre des réponses déjà comptées (dédoublonnées) et regroupement en tranches de 5 minutes pour le Mac d'Alane.

export const KEEP_DAYS = 8;
export const BUCKET_MS = 5 * 60 * 1000;

function total(record) {
  return record.in + record.out + record.cw + record.cr;
}

/**
 * Ajoute des relevés au registre (objet clé → relevé), sans compter deux fois une même réponse : si elle revient, on garde la version la
 * plus complète (le streaming écrit d'abord des compteurs partiels). Retourne le nombre de réponses nouvelles.
 */
export function merge(messages, records) {
  let added = 0;
  for (const record of records) {
    const known = messages[record.key];
    if (!known) added++;
    if (!known || total(record) > total(known)) messages[record.key] = { t: record.t, model: record.model, in: record.in, out: record.out, cw: record.cw, cr: record.cr };
  }
  return added;
}

/** Retire ce qui a plus de `KEEP_DAYS` jours : une semaine de prêt plus une marge. */
export function prune(messages, now) {
  const limit = now - KEEP_DAYS * 24 * 3600 * 1000;
  for (const [key, record] of Object.entries(messages)) if (record.t < limit) delete messages[key];
}

export function lastActivityAt(messages) {
  let latest = 0;
  for (const record of Object.values(messages)) if (record.t > latest) latest = record.t;
  return latest || null;
}

/**
 * Tranches de 5 minutes, de la plus ancienne à la plus récente : `t` (début, en secondes), `n` (réponses), les quatre compteurs et
 * `models` (tokens par modèle : le Mac en a besoin pour pondérer quand les deux personnes travaillent en même temps).
 */
export function buckets(messages) {
  const byStart = new Map();
  for (const record of Object.values(messages)) {
    const start = Math.floor(record.t / BUCKET_MS) * BUCKET_MS;
    let bucket = byStart.get(start);
    if (!bucket) {
      bucket = { t: start / 1000, n: 0, in: 0, out: 0, cw: 0, cr: 0, models: {} };
      byStart.set(start, bucket);
    }
    bucket.n++;
    bucket.in += record.in;
    bucket.out += record.out;
    bucket.cw += record.cw;
    bucket.cr += record.cr;
    bucket.models[record.model] = (bucket.models[record.model] ?? 0) + total(record);
  }
  return [...byStart.values()].sort((a, b) => a.t - b.t);
}
