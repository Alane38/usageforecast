import { describe, expect, test } from "bun:test";
import { controlPairing, decryptJson, newPairing, parsePairing } from "../lib/crypto.js";
import { CODE_LENGTH, commandOf, endCommand, formatCode, inviteOf, inviteSecrets, newInviteCode, normalizeCode, prepareLoan, redeemInvite } from "../lib/loan.js";
import { guestBudget, guestViewOf, loanInfoOf, revocationOf } from "../lib/loan-view.js";
import { pull } from "../lib/sync.js";
import worker from "../../relay/src/worker.js";
import { createHmac } from "node:crypto";
import { ID, KEY, KEY_BYTES, encrypt } from "./helpers.js";

const FAST = 1000;   // itérations réduites pour les tests (la valeur réelle est vérifiée une fois, plus bas)

function relay() {
  const store = new Map();
  const VAULT = {
    async get(key) { return store.get(key)?.value ?? null; },
    async getWithMetadata(key) { const entry = store.get(key); return { value: entry?.value ?? null, metadata: entry?.metadata ?? null }; },
    async put(key, value, options = {}) { store.set(key, { value, metadata: options.metadata, ttl: options.expirationTtl }); },
    async delete(key) { store.delete(key); },
  };
  return { store, fetchImpl: (url, init) => worker.fetch(new Request(url, init), { VAULT }) };
}

describe("code d'invitation", () => {
  test("8 caractères sans I, L, O, U ; affiché en deux groupes", () => {
    const code = newInviteCode();
    expect(code).toHaveLength(CODE_LENGTH);
    expect(code).toMatch(/^[0-9A-HJKMNP-TV-Z]{8}$/);
    expect(formatCode("K7QM4PZX")).toBe("K7QM-4PZX");
  });

  test("tolère ce qu'une personne tape : minuscules, espaces, tiret, O pour 0, I et L pour 1", () => {
    expect(normalizeCode(" k7qm-4pzx ")).toBe("K7QM4PZX");
    expect(normalizeCode("O0IL-ABCD")).toBe("0011ABCD");
    expect(normalizeCode("K7QM4PZ")).toBeNull();
    expect(normalizeCode("K7QM4PZU")).toBeNull();
    expect(normalizeCode(42)).toBeNull();
  });

  test("identifiant et clé dérivés du code : stables, différents d'un code à l'autre, réglage réel de 200 000 itérations", async () => {
    const real = await inviteSecrets("K7QM4PZX");
    expect(real.id).toMatch(/^[0-9a-f]{32}$/);
    expect(await inviteSecrets("K7QM4PZX")).toEqual(real);
    expect((await inviteSecrets("K7QM4PZY")).id).not.toBe(real.id);
    expect((await inviteSecrets("K7QM4PZX", FAST)).id).not.toBe(real.id);
  });
});

describe("prêt créé sur le téléphone, code utilisé par le collecteur", () => {
  const endsAt = new Date("2026-11-05T09:00:00Z");

  test("l'invitation passe une fois par le relais, puis plus jamais", async () => {
    const { fetchImpl, store } = relay();
    const prepared = await prepareLoan({ guestName: " Sam ", share: 0.7, endsAt, newPairing, iterations: FAST, now: new Date("2026-11-01T15:00:00Z") });
    expect(prepared.expiresAt.toISOString()).toBe("2026-11-01T15:15:00.000Z");
    const put = await fetchImpl(`https://relais.test/v1/invite/${prepared.inviteID}`, { method: "PUT", body: prepared.invite });
    expect(put.status).toBe(200);
    expect(store.get(`invite:${prepared.inviteID}`).ttl).toBe(900);
    expect(store.get(`invite:${prepared.inviteID}`).value).not.toContain("Sam");   // le relais ne voit que du chiffré
    expect((await fetchImpl(`https://relais.test/v1/invite/${prepared.inviteID}`, { method: "PUT", body: prepared.invite })).status).toBe(409);

    const redeemed = await redeemInvite({ relay: "https://relais.test", code: formatCode(prepared.code).toLowerCase(), fetchImpl, iterations: FAST });
    expect(redeemed.invite).toEqual({ guestVault: prepared.command.guestVault, viewVault: prepared.command.viewVault, guestName: "Sam", share: 0.7, endsAt });
    expect((await redeemInvite({ relay: "https://relais.test", code: prepared.code, fetchImpl, iterations: FAST })).error).toContain("déjà utilisé");
  });

  test("la commande pour le Mac porte les mêmes coffres et conditions ; un mauvais code ne donne rien", async () => {
    const { fetchImpl } = relay();
    const prepared = await prepareLoan({ guestName: "Sam", share: 0.7, endsAt, newPairing, iterations: FAST });
    expect(commandOf(prepared.command)).toMatchObject({ action: "create", guestName: "Sam", share: 0.7, endsAt, guestVault: prepared.command.guestVault });
    expect(prepared.command.guestVault.id).not.toBe(prepared.command.viewVault.id);
    expect((await redeemInvite({ relay: "https://relais.test", code: "ZZZZZZZZ", fetchImpl, iterations: FAST })).error).toContain("code inconnu");
    expect((await redeemInvite({ relay: "https://relais.test", code: "trop court", fetchImpl })).error).toContain("code invalide");
  });

  test("documents abîmés ou d'un autre type : refusés sans exception", () => {
    expect(inviteOf({ kind: "loan-invite", version: 1, guestVault: { id: "x", key: "y" } })).toBeNull();
    expect(inviteOf(null)).toBeNull();
    expect(commandOf({ ...endCommand(), version: 2 })).toBeNull();
    expect(commandOf(endCommand())).toMatchObject({ action: "end" });
    expect(commandOf({ kind: "loan-command", version: 1, id: "a", action: "create", createdAt: "2026-11-01T00:00:00Z" })).toBeNull();
  });
});

describe("coffre de contrôle (téléphone vers Mac)", () => {
  test("dérivé de l'appairage : même résultat des deux côtés, sans rien échanger de plus", async () => {
    const control = await controlPairing({ id: ID, key: KEY });
    expect(control).toEqual(await controlPairing({ id: ID, key: KEY }));
    expect(control.id).toMatch(/^[0-9a-f]{32}$/);
    expect(control.id).not.toBe(ID);
    expect(parsePairing(`v1.${control.id}.${control.key}`)).toEqual(control);
    // Calcul indépendant (node:crypto) et vecteur repris dans tests/loan_tests.swift (clé 0x00…0x1f) : le Mac trouve le même coffre.
    const expectedID = createHmac("sha256", Buffer.from(KEY_BYTES)).update("usageforecast/control").digest("hex").slice(0, 32);
    expect(control.id).toBe(expectedID);
    expect(control).toEqual({ id: "5eb8630571dc84b780e161b6770e21bd", key: "WYnkzqQ3h3V4pt-UEed36U56vxWZghyPB2XK3kn1Xaw" });  // gitleaks:allow (vecteur de test factice, clé publique 0x00…0x1f)
  });
});

describe("données de prêt publiées par le Mac", () => {
  const base = { guestName: "Sam", share: 0.7, startsAt: "2026-10-29T09:00:00Z", endsAt: "2026-11-05T09:00:00Z", active: true, guestUsed: 38, guestMeasured: 35, guestEstimated: 3, guestRatePerDay: 12, guestExhaustsAt: "2026-11-04T07:00:00Z" };

  test("résumé dans le snapshot du propriétaire", () => {
    const info = loanInfoOf({ ...base, ownerUsed: 14, collectorAt: "2026-11-01T14:56:00Z", collectorPlatform: "Windows", status: "" });
    expect(info).toMatchObject({ guestName: "Sam", sharePoints: 70, reservePoints: 30, guestUsed: 38, ownerUsed: 14, collectorPlatform: "Windows" });
    expect(loanInfoOf({ ...base, share: 1.5 })).toBeNull();
    expect(loanInfoOf(undefined)).toBeNull();
  });

  test("vue de l'invité : jours, réserve, budget conseillé", () => {
    const view = guestViewOf({ kind: "guest-view", version: 1, updatedAt: "2026-11-01T15:00:00Z", ...base, reserveLeft: 16, days: [{ day: "2026-10-29", points: 6 }, { day: "x" }] });
    expect(view).toMatchObject({ kind: "guest", reserveLeft: 16, days: [{ day: "2026-10-29", points: 6 }] });
    const budget = guestBudget(view, new Date("2026-11-01T09:00:00Z"));
    expect(budget.left).toBe(32);
    expect(budget.perDay).toBe(8);
    expect(guestViewOf({ ...base, kind: "guest-view", version: 1 })).toBeNull();   // sans date de mise à jour
  });

  test("l'application lit un coffre d'invité comme une vue réduite, pas comme un snapshot invalide", async () => {
    const blob = await encrypt({ kind: "guest-view", version: 1, updatedAt: "2026-11-01T15:00:00Z", ...base });
    const result = await pull({ pairing: { id: ID, key: KEY }, fetchImpl: async () => new Response(blob, { headers: { "x-updated-at": "1" } }) });
    expect(result.status).toBe("updated");
    expect(result.snapshot.kind).toBe("guest");
    expect(await decryptJson(blob, KEY)).toMatchObject({ kind: "guest-view" });
  });
});

describe("vecteurs croisés avec le Mac (tests/loan_tests.swift)", () => {
  test("le téléphone lit la vue de l'invité exactement telle que le Mac l'écrit", () => {
    const fromSwift = {"active":true,"days":[{"day":"2027-01-15","points":6}],"endsAt":"2027-01-22T08:00:00Z","guestEstimated":3,"guestExhaustsAt":"2027-01-20T20:37:53Z","guestMeasured":35,"guestName":"Sam","guestRatePerDay":12.666666666666666,"guestUsed":38,"kind":"guest-view","reserveLeft":16,"share":0.7,"startsAt":"2027-01-15T08:00:00Z","updatedAt":"2027-01-18T08:00:00Z","version":1};
    expect(guestViewOf(fromSwift)).toMatchObject({ kind: "guest", sharePoints: 70, guestUsed: 38, reserveLeft: 16, guestRatePerDay: 12.666666666666666, days: [{ day: "2027-01-15", points: 6 }] });
  });

  test("la commande lue par le Mac a exactement la forme que le téléphone produit", async () => {
    const prepared = await prepareLoan({ guestName: "Sam", share: 0.7, endsAt: new Date("2026-11-05T09:00:00Z"), newPairing, iterations: FAST });
    expect(Object.keys(prepared.command).sort()).toEqual(["action", "createdAt", "endsAt", "guestName", "guestVault", "id", "kind", "share", "version", "viewVault"]);
    const swiftVector = {"kind":"loan-command","version":1,"id":"6f1c2b9e-1d2a-4c3b-9a8e-7f6d5c4b3a21","action":"create","createdAt":"2026-11-01T15:00:00.000Z","guestName":"Sam","share":0.7,"endsAt":"2026-11-05T09:00:00.000Z","guestVault":{"id":"0123456789abcdef0123456789abcdef","key":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"},"viewVault":{"id":"fedcba9876543210fedcba9876543210","key":"Hx4dHBsaGRgXFhUUExIREA8ODQwLCgkIBwYFBAMCAQA"}};  // gitleaks:allow (vecteur de test factice, clé publique 0x00…0x1f)
    expect(Object.keys(swiftVector).sort()).toEqual(Object.keys(prepared.command).sort());
    expect(commandOf(swiftVector)).toMatchObject({ action: "create", share: 0.7 });
  });
});


describe("vérification de la révocation (snapshot du Mac)", () => {
  test("lue telle que le Mac l'écrit ; phase inconnue ou dates manquantes : ignorée", () => {
    const raw = { guestName: "Sam", endedAt: "2026-11-05T09:00:00Z", watchEndsAt: "2026-11-07T09:00:00Z", phase: "suspicious", unexplained: 3 };
    expect(revocationOf(raw)).toMatchObject({ guestName: "Sam", phase: "suspicious", unexplained: 3 });
    expect(revocationOf({ ...raw, phase: "autre" })).toBeNull();
    expect(revocationOf({ ...raw, endedAt: null })).toBeNull();
    expect(revocationOf(undefined)).toBeNull();
  });
});
