// Récupération du snapshot chiffré sur le relais, déchiffrement et validation. Ne lève jamais d'exception : retourne un statut lisible.
import { decryptJson } from "./crypto.js";
import { normalize } from "./snapshot.js";

export const POLL_SECONDS = 60;
export const MAX_POLL_SECONDS = 600;

/** Délai avant la prochaine vérification : 60 s, doublé à chaque échec consécutif, plafonné à 10 minutes. */
export function nextDelaySeconds(consecutiveFailures) {
  return Math.min(POLL_SECONDS * 2 ** Math.max(consecutiveFailures, 0), MAX_POLL_SECONDS);
}

/**
 * @returns {Promise<{status: "updated"|"unchanged"|"empty"|"invalid"|"error", snapshot?: object, raw?: object, stamp?: string, message?: string}>}
 */
export async function pull({ pairing, previousStamp = null, fetchImpl = globalThis.fetch }) {
  let response;
  try {
    response = await fetchImpl(`/v1/${pairing.id}`, { cache: "no-store" });
  } catch {
    return { status: "error", message: "Pas de connexion au relais." };
  }
  if (response.status === 404) return { status: "empty", message: "Ton Mac n'a encore rien envoyé : ouvre UsageForecast et vérifie que la synchro mobile est activée." };
  if (!response.ok) return { status: "error", message: `Le relais a répondu une erreur (${response.status}).` };

  const stamp = response.headers.get("x-updated-at") ?? "";
  if (stamp && stamp === previousStamp) return { status: "unchanged", stamp };

  const raw = await decryptJson(await response.text(), pairing.key);
  if (!raw) return { status: "invalid", message: "Impossible de déchiffrer les données : la clé ne correspond plus. Réassocie cet appareil depuis le Mac." };
  const snapshot = normalize(raw);
  if (!snapshot) return { status: "invalid", message: "Format de données non reconnu : mets à jour cette application ou celle du Mac." };
  return { status: "updated", snapshot, raw, stamp };
}
