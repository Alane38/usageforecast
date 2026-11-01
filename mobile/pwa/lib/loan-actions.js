// Actions du propriétaire depuis le téléphone : créer un prêt (code d'invitation + commande pour le Mac) ou le terminer.
// Réseau par `fetchImpl` (relatif au relais qui sert l'application). Ne lève jamais : retourne { ok } ou { error } lisible.
import { controlPairing, newPairing, sealJson, writeToken } from "./crypto.js";
import { endCommand, prepareLoan } from "./loan.js";

async function putControl(pairing, command, fetchImpl) {
  const control = await controlPairing(pairing);
  const response = await fetchImpl(`/v1/${control.id}`, {
    method: "PUT",
    headers: { "content-type": "text/plain", "x-write-token": await writeToken(control.key) },
    body: await sealJson(command, control.key),
  });
  if (response.status === 403) return "le coffre de contrôle appartient à une autre clé : réassocie ce téléphone depuis le Mac";
  return response.ok ? null : `le relais a répondu ${response.status}`;
}

/**
 * @returns {Promise<{ok: true, pending: object}|{error: string}>} `pending` : ce qu'il faut afficher et garder jusqu'à ce que le Mac
 *   applique la commande (le code, son expiration, l'identifiant de la commande).
 */
export async function createLoan({ pairing, guestName, share, endsAt, now = new Date(), fetchImpl = globalThis.fetch, iterations }) {
  if (!guestName.trim()) return { error: "Indique le prénom de la personne." };
  if (!(share >= 0.1 && share <= 0.9)) return { error: "La part doit être entre 10 et 90 %." };
  if (!(endsAt > now)) return { error: "La fin du prêt doit être dans le futur." };
  try {
    const prepared = await prepareLoan({ guestName, share, endsAt, now, newPairing, iterations });
    const invite = await fetchImpl(`/v1/invite/${prepared.inviteID}`, { method: "PUT", headers: { "content-type": "text/plain" }, body: prepared.invite });
    if (!invite.ok) return { error: `Invitation refusée par le relais (${invite.status}). Réessaie.` };
    const problem = await putControl(pairing, prepared.command, fetchImpl);
    if (problem) return { error: `Le Mac ne pourra pas recevoir le prêt : ${problem}.` };
    return { ok: true, pending: { action: "create", commandID: prepared.command.id, code: prepared.code, expiresAt: prepared.expiresAt.toISOString(),
      guestName: guestName.trim(), share, endsAt: endsAt.toISOString(), createdAt: now.toISOString() } };
  } catch {
    return { error: "Pas de connexion au relais. Réessaie quand tu es en ligne." };
  }
}

export async function endLoan({ pairing, now = new Date(), fetchImpl = globalThis.fetch }) {
  try {
    const command = endCommand(now);
    const problem = await putControl(pairing, command, fetchImpl);
    return problem ? { error: `Fin du prêt non transmise : ${problem}.` } : { ok: true, pending: { action: "end", commandID: command.id, createdAt: now.toISOString() } };
  } catch {
    return { error: "Pas de connexion au relais. Réessaie quand tu es en ligne." };
  }
}

/** La commande en attente est-elle appliquée par le Mac (ou dépassée) ? Alors on l'oublie. */
export function pendingSettled(pending, loan, now = Date.now()) {
  if (!pending) return true;
  if (loan?.lastCommandID === pending.commandID) return true;
  if (pending.action === "end" && !loan) return true;
  return now - Date.parse(pending.createdAt) > 24 * 3600 * 1000;   // le Mac est resté éteint un jour entier : on ne bloque plus l'écran
}
