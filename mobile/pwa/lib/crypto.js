// Déchiffrement de bout en bout (AES-256-GCM) et lecture du lien d'appairage. Compatible avec app/MobileCrypto.swift :
// le format est `nonce (12 octets) | texte chiffré | étiquette (16 octets)` en base64url, que WebCrypto lit tel quel.

export function b64urlToBytes(text) {
  if (typeof text !== "string" || !/^[A-Za-z0-9_-]*$/.test(text)) return null;
  const padded = text.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(text.length / 4) * 4, "=");
  try {
    return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
  } catch {
    return null;
  }
}

export function bytesToB64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Lit `v1.<identifiant 32 hex>.<clé 32 octets en base64url>`, avec ou sans l'URL et le « # » devant. Nul si invalide. */
export function parsePairing(input) {
  if (typeof input !== "string") return null;
  const fragment = input.includes("#") ? input.slice(input.indexOf("#") + 1) : input.trim();
  const parts = fragment.trim().split(".");
  if (parts.length !== 3 || parts[0] !== "v1" || !/^[0-9a-f]{32}$/.test(parts[1])) return null;
  const key = b64urlToBytes(parts[2]);
  return key && key.length === 32 ? { id: parts[1], key: parts[2] } : null;
}

/** Lien d'association complet, tel que l'affiche le Mac : à coller dans l'application Android ou à scanner. Contient la clé. */
export function pairingLink(pairing, origin) {
  return `${origin}/#v1.${pairing.id}.${pairing.key}`;
}

/** Nul au moindre problème (mauvaise clé, donnée modifiée, format invalide) : on ne distingue pas les causes. */
export async function decryptBlob(blob, keyB64url) {
  const combined = b64urlToBytes(blob);
  const keyBytes = b64urlToBytes(keyB64url);
  if (!combined || combined.length < 12 + 16 || !keyBytes || keyBytes.length !== 32) return null;
  try {
    const key = await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, ["decrypt"]);
    const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: combined.slice(0, 12) }, key, combined.slice(12));
    return new Uint8Array(plain);
  } catch {
    return null;
  }
}

export async function decryptJson(blob, keyB64url) {
  const bytes = await decryptBlob(blob, keyB64url);
  if (!bytes) return null;
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

// --- Écriture (téléphone et collecteur) : mêmes formats que app/MobileCrypto.swift. ---

function keyBytesOf(keyB64url) {
  const bytes = b64urlToBytes(keyB64url);
  if (!bytes || bytes.length !== 32) throw new Error("clé d'association invalide");
  return bytes;
}

export async function sealJson(object, keyB64url, nonce = crypto.getRandomValues(new Uint8Array(12))) {
  const key = await crypto.subtle.importKey("raw", keyBytesOf(keyB64url), "AES-GCM", false, ["encrypt"]);
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, new TextEncoder().encode(JSON.stringify(object))));
  return bytesToB64url(new Uint8Array([...nonce, ...sealed]));
}

/** HMAC-SHA256 d'un libellé avec une clé de 32 octets (base64url). */
export async function hmac(keyB64url, label) {
  const key = await crypto.subtle.importKey("raw", keyBytesOf(keyB64url), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(label)));
}

const hex = (bytes) => [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");

/** Jeton d'écriture d'un coffre : `HMAC-SHA256(clé, "usageforecast/write")` en hexadécimal, comme MobileCrypto.writeToken. */
export async function writeToken(keyB64url) {
  return hex(await hmac(keyB64url, "usageforecast/write"));
}

/** Nouveau coffre : identifiant de 128 bits en hexadécimal et clé de 256 bits en base64url. */
export function newPairing() {
  return { id: hex(crypto.getRandomValues(new Uint8Array(16))), key: bytesToB64url(crypto.getRandomValues(new Uint8Array(32))) };
}

/**
 * Coffre de contrôle du téléphone vers le Mac (prêt créé ou terminé depuis le téléphone), dérivé de l'appairage existant :
 * les deux côtés le retrouvent sans rien échanger de plus. Identifiant : 16 premiers octets de HMAC(clé, "usageforecast/control") ;
 * clé : HMAC(clé, "usageforecast/control-key").
 */
export async function controlPairing(pairing) {
  return { id: hex((await hmac(pairing.key, "usageforecast/control")).slice(0, 16)), key: bytesToB64url(await hmac(pairing.key, "usageforecast/control-key")) };
}
