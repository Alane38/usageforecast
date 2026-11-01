// Prêt de quota (ADR 003) : code d'invitation, commandes du téléphone vers le Mac, et lecture des données de prêt.
// Partagé par l'application mobile et le collecteur. Ne lève jamais d'exception sur une donnée reçue : on la refuse ou on la nettoie.
import { b64urlToBytes, bytesToB64url, decryptJson, sealJson } from "./crypto.js";

// Base 32 de Crockford : pas de I, L, O, U (ni confusion 0/O, 1/I/L, ni mot gênant). 8 caractères = 40 bits.
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
export const CODE_LENGTH = 8;
export const INVITE_TTL_SECONDS = 15 * 60;
/** Lent exprès : le code ne fait que 40 bits ; il ne vit que 15 minutes et ne sert qu'une fois, mais le relais ne doit pas pouvoir le deviner vite. */
export const INVITE_ITERATIONS = 200_000;

export function newInviteCode(random = crypto.getRandomValues(new Uint8Array(CODE_LENGTH))) {
  return [...random].map((byte) => ALPHABET[byte % 32]).join("");
}

/** Code tapé par une personne → forme canonique (8 caractères), ou null. Tolère minuscules, espaces, tirets, O pour 0 et I/L pour 1. */
export function normalizeCode(text) {
  if (typeof text !== "string") return null;
  const cleaned = text.toUpperCase().replace(/[\s-]/g, "").replace(/O/g, "0").replace(/[IL]/g, "1");
  return cleaned.length === CODE_LENGTH && [...cleaned].every((char) => ALPHABET.includes(char)) ? cleaned : null;
}

export const formatCode = (code) => `${code.slice(0, 4)}-${code.slice(4)}`;

/** Identifiant (où le relais range l'invitation) et clé de chiffrement, tirés du code par PBKDF2-SHA256. */
export async function inviteSecrets(code, iterations = INVITE_ITERATIONS) {
  const material = await crypto.subtle.importKey("raw", new TextEncoder().encode(code), "PBKDF2", false, ["deriveBits"]);
  const bits = new Uint8Array(await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt: new TextEncoder().encode("usageforecast/invite/v1"), iterations }, material, 48 * 8));
  return { id: [...bits.slice(0, 16)].map((byte) => byte.toString(16).padStart(2, "0")).join(""), key: bytesToB64url(bits.slice(16)) };
}

const isPairing = (value) => value && /^[0-9a-f]{32}$/.test(value.id) && b64urlToBytes(value.key)?.length === 32;
const isNumber = (value) => typeof value === "number" && Number.isFinite(value);
const toDate = (value) => {
  const date = typeof value === "string" ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime()) ? date : null;
};

/** Ce que reçoit l'invité en échange du code : où déposer son activité, où lire sa vue, et les conditions du prêt. */
export function inviteOf(raw) {
  if (!raw || raw.kind !== "loan-invite" || raw.version !== 1 || !isPairing(raw.guestVault) || !isPairing(raw.viewVault)) return null;
  const endsAt = toDate(raw.endsAt);
  if (!endsAt || !isNumber(raw.share)) return null;
  return { guestVault: { id: raw.guestVault.id, key: raw.guestVault.key }, viewVault: { id: raw.viewVault.id, key: raw.viewVault.key },
    guestName: String(raw.guestName ?? ""), share: raw.share, endsAt };
}

/** Commande déposée par le téléphone dans le coffre de contrôle ; le Mac l'applique une fois (identifiant unique). */
export function commandOf(raw) {
  if (!raw || raw.kind !== "loan-command" || raw.version !== 1 || typeof raw.id !== "string" || !toDate(raw.createdAt)) return null;
  if (raw.action === "end") return { id: raw.id, action: "end", createdAt: toDate(raw.createdAt) };
  if (raw.action !== "create" || !isPairing(raw.guestVault) || !isPairing(raw.viewVault) || !isNumber(raw.share) || !toDate(raw.endsAt)) return null;
  return { id: raw.id, action: "create", createdAt: toDate(raw.createdAt), guestName: String(raw.guestName ?? ""), share: raw.share,
    endsAt: toDate(raw.endsAt), guestVault: raw.guestVault, viewVault: raw.viewVault };
}

/**
 * Prépare un prêt depuis le téléphone : nouveaux coffres pour l'invité, code, invitation chiffrée et commande pour le Mac.
 * `newPairing` est passé pour les tests. Ne contacte pas le réseau : l'appelant dépose les deux documents.
 */
export async function prepareLoan({ guestName, share, endsAt, now = new Date(), newPairing, code = newInviteCode(), iterations }) {
  const guestVault = newPairing(), viewVault = newPairing();
  const terms = { guestName: guestName.trim(), share, endsAt: endsAt.toISOString() };
  const secrets = await inviteSecrets(code, iterations);
  const invite = await sealJson({ kind: "loan-invite", version: 1, ...terms, guestVault, viewVault }, secrets.key);
  const command = { kind: "loan-command", version: 1, id: crypto.randomUUID(), action: "create", createdAt: now.toISOString(), ...terms, guestVault, viewVault };
  return { code, inviteID: secrets.id, invite, command, expiresAt: new Date(now.getTime() + INVITE_TTL_SECONDS * 1000) };
}

export function endCommand(now = new Date()) {
  return { kind: "loan-command", version: 1, id: crypto.randomUUID(), action: "end", createdAt: now.toISOString() };
}

/** Échange un code contre l'invitation (une seule fois). `fetchImpl(url, init)` ; `relay` sans « / » final. */
export async function redeemInvite({ relay, code, fetchImpl = globalThis.fetch, iterations }) {
  const canonical = normalizeCode(code);
  if (!canonical) return { error: "code invalide : 8 caractères, par exemple K7QM-4PZX" };
  const secrets = await inviteSecrets(canonical, iterations);
  let response;
  try {
    response = await fetchImpl(`${relay}/v1/invite/${secrets.id}/claim`, { method: "POST" });
  } catch {
    return { error: "relais injoignable" };
  }
  if (response.status === 404) return { error: "code inconnu, déjà utilisé ou expiré (15 minutes) : demande un nouveau code" };
  if (!response.ok) return { error: `le relais a répondu ${response.status}` };
  const invite = inviteOf(await decryptJson(await response.text(), secrets.key));
  return invite ? { invite } : { error: "invitation illisible : mets à jour le collecteur" };
}
