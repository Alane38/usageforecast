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
