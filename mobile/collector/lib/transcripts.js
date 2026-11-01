// Lecture des journaux de session de Claude Code (`<config>/projects/**/*.jsonl`) : une ligne JSON par événement.
// On ne garde que les réponses de l'assistant qui portent `message.usage` : l'heure, le modèle et quatre compteurs de tokens.
// Rien d'autre ne sort de cette fonction : ni texte de conversation, ni nom de projet, ni chemin.

/**
 * @typedef {{key: string, t: number, model: string, in: number, out: number, cw: number, cr: number}} UsageRecord
 *   `t` en millisecondes ; `cw` = écriture du cache, `cr` = lecture du cache.
 */

function count(value) {
  return Number.isFinite(value) && value > 0 ? Math.round(value) : 0;
}

/** Une ligne de journal → un relevé, ou null si la ligne n'en est pas un (autre type, JSON invalide, message synthétique). */
export function parseLine(line) {
  if (!line || line.length < 2) return null;
  let entry;
  try {
    entry = JSON.parse(line);
  } catch {
    return null;
  }
  if (entry?.type !== "assistant") return null;
  const message = entry.message;
  const usage = message?.usage;
  if (!usage || typeof usage !== "object") return null;
  const model = typeof message.model === "string" ? message.model : "inconnu";
  if (model === "<synthetic>") return null;   // réponses fabriquées par Claude Code lui-même : aucun appel au modèle
  const t = Date.parse(entry.timestamp);
  if (!Number.isFinite(t)) return null;
  // Pendant le streaming, la même réponse peut être écrite plusieurs fois : identifiant du message + identifiant de la requête.
  const id = message.id ?? entry.uuid;
  if (typeof id !== "string" || id.length === 0) return null;
  const record = {
    key: `${id}:${entry.requestId ?? ""}`,
    t,
    model,
    in: count(usage.input_tokens),
    out: count(usage.output_tokens),
    cw: count(usage.cache_creation_input_tokens),
    cr: count(usage.cache_read_input_tokens),
  };
  return record.in + record.out + record.cw + record.cr > 0 ? record : null;
}

/** Toutes les lignes complètes d'un morceau de texte (la dernière doit être terminée par un saut de ligne, voir reader.js). */
export function parseLines(text) {
  const records = [];
  for (const line of text.split("\n")) {
    const record = parseLine(line.trim());
    if (record) records.push(record);
  }
  return records;
}
