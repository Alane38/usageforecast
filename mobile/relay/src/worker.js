// Relais de la synchro mobile : un coffre par appareil, qui ne contient que du texte chiffré de bout en bout.
// L'app Mac écrit (PUT) avec un jeton d'écriture ; le téléphone lit (GET) avec l'identifiant du coffre, secret de 128 bits.
// Sans la clé, que le relais ne voit jamais, les données sont illisibles : le relais ne sait rien de l'usage.
import { assetFor } from "./assets.generated.js";

const ID = /^[0-9a-f]{32}$/;
const TOKEN = /^[0-9a-f]{64}$/;
export const MAX_BLOB_BYTES = 256 * 1024;
export const TTL_SECONDS = 60 * 60 * 24 * 30;

const SECURITY = {
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "x-frame-options": "DENY",
  "cross-origin-opener-policy": "same-origin",
};

const CSP = "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; "
  + "manifest-src 'self'; worker-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json", "cache-control": "no-store", ...SECURITY, ...extra } });
}

async function sha256Hex(text) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Comparaison en temps constant de deux chaînes hexadécimales de même longueur. */
function sameHex(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let index = 0; index < a.length; index++) diff |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return diff === 0;
}

async function put(request, env, id) {
  const token = request.headers.get("x-write-token") ?? "";
  if (!TOKEN.test(token)) return json({ error: "jeton d'écriture invalide" }, 401);
  const declared = Number(request.headers.get("content-length") ?? 0);
  if (declared > MAX_BLOB_BYTES) return json({ error: "trop volumineux" }, 413);
  const blob = await request.text();
  if (blob.length === 0 || blob.length > MAX_BLOB_BYTES) return json({ error: "taille invalide" }, 413);
  if (!/^[A-Za-z0-9_-]+$/.test(blob)) return json({ error: "format invalide" }, 400);

  const tokenHash = await sha256Hex(token);
  const known = await env.VAULT.get(`auth:${id}`);
  // Premier envoi : le coffre s'enregistre avec l'empreinte du jeton ; ensuite seul ce jeton peut écrire.
  if (known && !sameHex(known, tokenHash)) return json({ error: "jeton refusé" }, 403);
  if (!known) await env.VAULT.put(`auth:${id}`, tokenHash, { expirationTtl: TTL_SECONDS });
  await env.VAULT.put(`blob:${id}`, blob, { expirationTtl: TTL_SECONDS, metadata: { at: Date.now() } });
  return json({ ok: true, bytes: blob.length });
}

async function get(env, id) {
  const { value, metadata } = await env.VAULT.getWithMetadata(`blob:${id}`);
  if (value === null) return json({ error: "coffre vide" }, 404);
  return new Response(value, {
    headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store", "x-updated-at": String(metadata?.at ?? ""), ...SECURITY },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/v1\/([^/]+)$/);
    if (match) {
      if (!ID.test(match[1])) return json({ error: "identifiant invalide" }, 400);
      if (request.method === "PUT") return put(request, env, match[1]);
      if (request.method === "GET") return get(env, match[1]);
      return json({ error: "méthode non permise" }, 405, { allow: "GET, PUT" });
    }
    if (request.method !== "GET" && request.method !== "HEAD") return json({ error: "méthode non permise" }, 405);
    const asset = assetFor(url.pathname);
    if (!asset) return json({ error: "introuvable" }, 404);
    const headers = { "content-type": asset.type, "cache-control": asset.cache, ...SECURITY };
    if (asset.type.startsWith("text/html")) headers["content-security-policy"] = CSP;
    return new Response(request.method === "HEAD" ? null : asset.body, { headers });
  },
};
