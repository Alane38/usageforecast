// Chiffrement côté collecteur, identique à app/MobileCrypto.swift : AES-256-GCM, `nonce (12) | texte chiffré | étiquette (16)` en base64url,
// et jeton d'écriture `HMAC-SHA256(clé, "usageforecast/write")` en hexadécimal. Le relais ne voit que le résultat.
import { b64urlToBytes, bytesToB64url } from "../../pwa/lib/crypto.js";

const WRITE_LABEL = "usageforecast/write";

function keyBytesOf(keyB64url) {
  const bytes = b64urlToBytes(keyB64url);
  if (!bytes || bytes.length !== 32) throw new Error("clé d'association invalide");
  return bytes;
}

export async function sealJson(object, keyB64url, nonce = crypto.getRandomValues(new Uint8Array(12))) {
  const key = await crypto.subtle.importKey("raw", keyBytesOf(keyB64url), "AES-GCM", false, ["encrypt"]);
  const plain = new TextEncoder().encode(JSON.stringify(object));
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, plain));
  return bytesToB64url(new Uint8Array([...nonce, ...sealed]));
}

export async function writeToken(keyB64url) {
  const key = await crypto.subtle.importKey("raw", keyBytesOf(keyB64url), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(WRITE_LABEL)));
  return [...mac].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Nouveau coffre : identifiant de 128 bits en hexadécimal et clé de 256 bits en base64url. */
export function newPairing() {
  const id = [...crypto.getRandomValues(new Uint8Array(16))].map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return { id, key: bytesToB64url(crypto.getRandomValues(new Uint8Array(32))) };
}
