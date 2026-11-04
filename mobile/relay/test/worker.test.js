import { describe, expect, test } from "bun:test";
import worker, { MAX_BLOB_BYTES } from "../src/worker.js";

/** Espace de stockage en mémoire, avec la même interface que Workers KV pour ce qu'utilise le relais. */
function fakeKV() {
  const store = new Map();
  return {
    store,
    async get(key) { return store.get(key)?.value ?? null; },
    async getWithMetadata(key) { const entry = store.get(key); return { value: entry?.value ?? null, metadata: entry?.metadata ?? null }; },
    async put(key, value, options = {}) { store.set(key, { value, metadata: options.metadata, ttl: options.expirationTtl }); },
  };
}

const ID = "0123456789abcdef0123456789abcdef";
const OTHER_ID = "fedcba9876543210fedcba9876543210";
const TOKEN = "a".repeat(64);
const OTHER_TOKEN = "b".repeat(64);
const BLOB = "oKGio6SlpqeoqaqrnToUSCmnbZ1YR-q8ZROsu1LR6TTezi9REKnTcKBV7_CgZQ";

const call = (env, method, path, { body, token } = {}) =>
  worker.fetch(new Request(`https://relay.test${path}`, { method, body, headers: token ? { "x-write-token": token } : {} }), env);

describe("écriture", () => {
  test("le premier envoi enregistre le coffre, la lecture rend le texte chiffré", async () => {
    const env = { VAULT: fakeKV() };
    expect((await call(env, "PUT", `/v1/${ID}`, { body: BLOB, token: TOKEN })).status).toBe(200);
    const response = await call(env, "GET", `/v1/${ID}`);
    expect(response.status).toBe(200);
    expect(await response.text()).toBe(BLOB);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(Number(response.headers.get("x-updated-at"))).toBeGreaterThan(0);
  });

  test("le jeton n'est jamais stocké en clair, seulement son empreinte", async () => {
    const env = { VAULT: fakeKV() };
    await call(env, "PUT", `/v1/${ID}`, { body: BLOB, token: TOKEN });
    const stored = [...env.VAULT.store.values()].map((entry) => entry.value).join("|");
    expect(stored).not.toContain(TOKEN);
    expect(env.VAULT.store.get(`auth:${ID}`).value).toMatch(/^[0-9a-f]{64}$/);
  });

  test("le même jeton peut réécrire, un autre jeton est refusé", async () => {
    const env = { VAULT: fakeKV() };
    await call(env, "PUT", `/v1/${ID}`, { body: BLOB, token: TOKEN });
    expect((await call(env, "PUT", `/v1/${ID}`, { body: "nouveau", token: TOKEN })).status).toBe(200);
    expect((await call(env, "PUT", `/v1/${ID}`, { body: "pirate", token: OTHER_TOKEN })).status).toBe(403);
    expect(await (await call(env, "GET", `/v1/${ID}`)).text()).toBe("nouveau");
  });

  test("sans jeton ou avec un jeton mal formé : refus", async () => {
    const env = { VAULT: fakeKV() };
    expect((await call(env, "PUT", `/v1/${ID}`, { body: BLOB })).status).toBe(401);
    expect((await call(env, "PUT", `/v1/${ID}`, { body: BLOB, token: "court" })).status).toBe(401);
    expect(env.VAULT.store.size).toBe(0);
  });

  test("contenu invalide ou trop gros : refus, rien n'est écrit", async () => {
    const env = { VAULT: fakeKV() };
    expect((await call(env, "PUT", `/v1/${ID}`, { body: "", token: TOKEN })).status).toBe(413);
    expect((await call(env, "PUT", `/v1/${ID}`, { body: "pas du base64url !", token: TOKEN })).status).toBe(400);
    expect((await call(env, "PUT", `/v1/${ID}`, { body: "a".repeat(MAX_BLOB_BYTES + 1), token: TOKEN })).status).toBe(413);
    expect(env.VAULT.store.size).toBe(0);
  });

  test("les données expirent au bout de 30 jours", async () => {
    const env = { VAULT: fakeKV() };
    await call(env, "PUT", `/v1/${ID}`, { body: BLOB, token: TOKEN });
    expect(env.VAULT.store.get(`blob:${ID}`).ttl).toBe(60 * 60 * 24 * 30);
  });
});

describe("lecture", () => {
  test("un coffre vide ou inconnu : 404, un autre coffre n'est pas lisible", async () => {
    const env = { VAULT: fakeKV() };
    expect((await call(env, "GET", `/v1/${ID}`)).status).toBe(404);
    await call(env, "PUT", `/v1/${ID}`, { body: BLOB, token: TOKEN });
    expect((await call(env, "GET", `/v1/${OTHER_ID}`)).status).toBe(404);
  });

  test("identifiant mal formé : 400", async () => {
    const env = { VAULT: fakeKV() };
    expect((await call(env, "GET", "/v1/pas-un-identifiant")).status).toBe(400);
    expect((await call(env, "GET", `/v1/${ID.toUpperCase()}`)).status).toBe(400);
  });

  test("méthodes non permises", async () => {
    const env = { VAULT: fakeKV() };
    const response = await call(env, "DELETE", `/v1/${ID}`);
    expect(response.status).toBe(405);
    expect(response.headers.get("allow")).toBe("GET, PUT");
    expect((await call(env, "POST", "/")).status).toBe(405);
  });
});

describe("application", () => {
  test("la page d'accueil est servie avec une politique de sécurité stricte", async () => {
    const response = await call({ VAULT: fakeKV() }, "GET", "/");
    expect(response.status).toBe(200);
    expect(response.headers.get("content-security-policy")).toContain("default-src 'self'");
    expect(response.headers.get("content-security-policy")).toContain("frame-ancestors 'none'");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
  });

  test("un chemin inconnu : 404 en JSON", async () => {
    const response = await call({ VAULT: fakeKV() }, "GET", "/n-existe-pas");
    expect(response.status).toBe(404);
    expect(response.headers.get("content-type")).toBe("application/json");
  });
});
