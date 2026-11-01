// Association du collecteur : soit le lien complet d'un coffre (`https://relais/#v1.<id>.<clé>`), soit l'adresse seule du relais
// (un nouveau coffre est alors créé et son lien est à transmettre au Mac d'Alane).
import { pairingLink, parsePairing } from "../../pwa/lib/crypto.js";
import { newPairing } from "./seal.js";

/** Origine du relais, ou null : https obligatoire, http accepté seulement pour le relais local de développement. */
export function relayOrigin(text) {
  let url;
  try {
    url = new URL(text.trim());
  } catch {
    return null;
  }
  const local = url.hostname === "localhost" || url.hostname === "127.0.0.1";
  if (url.protocol !== "https:" && !(url.protocol === "http:" && local)) return null;
  return url.origin;
}

/** @returns {{pairing: {relay: string, id: string, key: string}, created: boolean}|{error: string}} */
export function pairingFromInput(text) {
  if (typeof text !== "string" || !text.trim()) return { error: "donne l'adresse du relais ou le lien d'association" };
  const relay = relayOrigin(text);
  if (!relay) return { error: "adresse invalide : il faut https://… (http seulement pour localhost)" };
  if (text.includes("#")) {
    const parsed = parsePairing(text);
    if (!parsed) return { error: "lien d'association illisible (attendu : https://relais/#v1.<identifiant>.<clé>)" };
    return { pairing: { relay, ...parsed }, created: false };
  }
  return { pairing: { relay, ...newPairing() }, created: true };
}

export function linkOf(pairing) {
  return pairingLink(pairing, pairing.relay);
}
