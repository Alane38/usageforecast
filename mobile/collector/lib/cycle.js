// Un tour du collecteur : lire le nouveau, mettre à jour le registre, décider d'envoyer, envoyer. Tout l'état est passé et rendu :
// la boucle (collector.js) se contente de le charger, d'appeler `runCycle` et de le sauvegarder.
import { merge, prune, lastActivityAt } from "./ledger.js";
import { dayStamp, pushReason } from "./policy.js";
import { readNewRecords } from "./reader.js";
import { buildReport } from "./report.js";
import { sealJson, writeToken } from "./seal.js";
import { decryptJson } from "../../pwa/lib/crypto.js";

export function emptyState() {
  return { files: {}, messages: {}, lastPushAt: null, pushedActivityAt: null, pushDay: null, pushesToday: 0, lastError: null, loanEnded: false };
}

/**
 * Le prêt est-il terminé ? Le Mac du propriétaire publie une dernière vue `active: false` dans le coffre de lecture de l'invité.
 * Vrai seulement sur cette preuve ; une erreur réseau ou un coffre illisible ne termine rien.
 */
export async function loanEnded({ pairing, fetchImpl }) {
  if (!pairing?.view) return false;
  try {
    const response = await fetchImpl(`${pairing.relay}/v1/${pairing.view.id}`, { cache: "no-store" });
    if (!response.ok) return false;
    const view = await decryptJson(await response.text(), pairing.view.key);
    return view?.kind === "guest-view" && view.active === false;
  } catch {
    return false;
  }
}

/** Envoie un document chiffré au coffre. Retourne null si tout va bien, sinon un message lisible. */
export async function push({ pairing, report, fetchImpl }) {
  const body = await sealJson(report, pairing.key);
  let response;
  try {
    response = await fetchImpl(`${pairing.relay}/v1/${pairing.id}`, {
      method: "PUT",
      headers: { "content-type": "text/plain", "x-write-token": await writeToken(pairing.key) },
      body,
    });
  } catch (error) {
    return `relais injoignable (${error?.message ?? error})`;
  }
  if (response.status === 403) return "le relais refuse ce jeton : ce coffre appartient à un autre appareil, réassocie le collecteur";
  if (!response.ok) return `le relais a répondu ${response.status}`;
  return null;
}

/**
 * @param {{pairing: {relay: string, id: string, key: string}|null, state: object, now: number, dirs: string[], fetchImpl?: Function,
 *   collectorVersion: string, platform: string, dryRun?: boolean, force?: boolean}} options
 * @returns {Promise<{added: number, reason: string|null, sent: boolean, error: string|null, report: object|null}>}
 */
export async function runCycle({ pairing, state, now, dirs, fetchImpl = globalThis.fetch, collectorVersion, platform, dryRun = false, force = false }) {
  if (state.loanEnded) return { added: 0, reason: null, sent: false, error: null, report: null, ended: true };
  const added = merge(state.messages, readNewRecords({ dirs, files: state.files, now }));
  prune(state.messages, now);
  const today = dayStamp(now);
  if (state.pushDay !== today) {
    state.pushDay = today;
    state.pushesToday = 0;
  }
  const last = lastActivityAt(state.messages);
  const reason = force ? "manual" : pushReason({ now, lastPushAt: state.lastPushAt, lastActivityAt: last, pushedActivityAt: state.pushedActivityAt, pushesToday: state.pushesToday });
  if (!reason) return { added, reason: null, sent: false, error: null, report: null };

  const report = buildReport({ messages: state.messages, now, reason, collectorVersion, platform });
  if (dryRun || !pairing) return { added, reason, sent: false, error: pairing ? null : "collecteur non associé", report };

  // Avant chaque envoi : le prêt est-il fini ? Alors on n'envoie plus rien (le Mac a effacé le coffre, on ne le recrée pas).
  if (await loanEnded({ pairing, fetchImpl })) {
    state.loanEnded = true;
    return { added, reason: null, sent: false, error: null, report: null, ended: true };
  }
  const error = await push({ pairing, report, fetchImpl });
  state.lastError = error;
  if (error) return { added, reason, sent: false, error, report };
  state.lastPushAt = now;
  state.pushedActivityAt = last;
  state.pushesToday++;
  return { added, reason, sent: true, error: null, report };
}
