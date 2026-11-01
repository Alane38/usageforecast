import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { decryptJson } from "../../pwa/lib/crypto.js";
import { KEY } from "../../pwa/test/helpers.js";
import worker from "../../relay/src/worker.js";
import { emptyState, runCycle } from "../lib/cycle.js";
import { MIN_PUSH_MS } from "../lib/policy.js";
import { PRIVATE_TEXT, assistantLine, userLine } from "./fixtures.js";

const PAIRING = { relay: "https://relais.example", id: "0123456789abcdef0123456789abcdef", key: KEY };
const NOW = Date.parse("2026-11-01T10:30:00Z");

/** Le vrai relais (worker.js) sur un stockage en mémoire : le test passe par le même code que la production. */
function relay() {
  const store = new Map();
  const env = {
    VAULT: {
      async get(name) { return store.get(name)?.value ?? null; },
      async put(name, value, options) { store.set(name, { value, metadata: options?.metadata }); },
      async getWithMetadata(name) { const item = store.get(name); return { value: item?.value ?? null, metadata: item?.metadata ?? null }; },
    },
  };
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push(url);
    return worker.fetch(new Request(url, init), env);
  };
  return { store, fetchImpl, calls };
}

let root;
beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), "collecteur-cycle-"));
});
afterEach(() => rmSync(root, { recursive: true, force: true }));

function options(extra) {
  return { pairing: PAIRING, now: NOW, dirs: [root], collectorVersion: "0.1.0", platform: "win32", ...extra };
}

describe("un tour complet, jusqu'au relais", () => {
  test("lit, envoie chiffré au relais ; le propriétaire déchiffre des tranches de 5 minutes", async () => {
    writeFileSync(join(root, "s.jsonl"), [userLine(), assistantLine({ id: "a", at: "2026-11-01T10:02:00Z" }), assistantLine({ id: "a", at: "2026-11-01T10:02:00Z" }), ""].join("\n"));
    const { store, fetchImpl } = relay();
    const state = emptyState();
    const result = await runCycle(options({ state, fetchImpl }));
    expect(result).toMatchObject({ added: 1, reason: "activity", sent: true, error: null });
    const report = await decryptJson(store.get(`blob:${PAIRING.id}`).value, KEY);
    expect(report).toMatchObject({ kind: "guest-activity", version: 1, reason: "activity", collector: { version: "0.1.0", platform: "win32" }, lastActivityAt: "2026-11-01T10:02:00.000Z" });
    expect(report.buckets).toEqual([{ t: Date.parse("2026-11-01T10:00:00Z") / 1000, n: 1, in: 10, out: 20, cw: 30, cr: 40, models: { "claude-opus-5-5": 100 } }]);
    expect(state).toMatchObject({ lastPushAt: NOW, pushesToday: 1, lastError: null });
  });

  test("confidentialité : ni le texte des conversations ni le dossier du projet ne sortent (contrôle négatif inclus)", async () => {
    const transcript = [userLine(), assistantLine()].join("\n") + "\n";
    writeFileSync(join(root, "s.jsonl"), transcript);
    // Contrôle négatif : le journal contient bien ces textes, la vérification ci-dessous n'est donc pas vide de sens.
    expect(transcript).toContain(PRIVATE_TEXT);
    expect(transcript).toContain("secret-client");
    const { store, fetchImpl } = relay();
    await runCycle(options({ state: emptyState(), fetchImpl }));
    const sent = JSON.stringify(await decryptJson(store.get(`blob:${PAIRING.id}`).value, KEY));
    expect(sent).not.toContain(PRIVATE_TEXT);
    expect(sent).not.toContain("secret-client");
    expect(sent).not.toContain(root);
    // Et le relais, lui, ne voit que du chiffré.
    expect(store.get(`blob:${PAIRING.id}`).value).not.toContain("guest-activity");
  });

  test("rien de nouveau peu après un envoi : pas d'appel au relais", async () => {
    writeFileSync(join(root, "s.jsonl"), `${assistantLine()}\n`);
    const { fetchImpl, calls } = relay();
    const state = emptyState();
    await runCycle(options({ state, fetchImpl }));
    const second = await runCycle(options({ state, fetchImpl, now: NOW + MIN_PUSH_MS }));
    expect(second).toMatchObject({ added: 0, reason: null, sent: false });
    expect(calls).toHaveLength(1);
  });

  test("essai : le document est construit mais rien n'est envoyé ni marqué comme envoyé", async () => {
    writeFileSync(join(root, "s.jsonl"), `${assistantLine()}\n`);
    const { calls, fetchImpl } = relay();
    const state = emptyState();
    const result = await runCycle(options({ state, fetchImpl, dryRun: true }));
    expect(result.report.buckets).toHaveLength(1);
    expect(calls).toHaveLength(0);
    expect(state.lastPushAt).toBeNull();
  });

  test("coffre d'un autre appareil : message explicite, l'envoi sera retenté", async () => {
    writeFileSync(join(root, "s.jsonl"), `${assistantLine()}\n`);
    const { store, fetchImpl } = relay();
    store.set(`auth:${PAIRING.id}`, { value: "0".repeat(64) });
    const state = emptyState();
    const result = await runCycle(options({ state, fetchImpl }));
    expect(result.error).toContain("réassocie");
    expect(state.lastPushAt).toBeNull();
    expect(state.lastError).toContain("réassocie");
  });

  test("relais injoignable ou non associé : pas d'exception, un message", async () => {
    writeFileSync(join(root, "s.jsonl"), `${assistantLine()}\n`);
    const offline = await runCycle(options({ state: emptyState(), fetchImpl: async () => { throw new Error("hors ligne"); } }));
    expect(offline.error).toContain("injoignable");
    const unpaired = await runCycle(options({ state: emptyState(), pairing: null }));
    expect(unpaired.error).toBe("collecteur non associé");
  });

  test("le fichier collector.js ne contient aucune clé ni adresse en dur", () => {
    const source = readFileSync(join(import.meta.dir, "..", "collector.js"), "utf8");
    expect(source).not.toMatch(/workers\.dev/);
    expect(source).not.toMatch(/v1\.[0-9a-f]{32}\./);
  });
});
