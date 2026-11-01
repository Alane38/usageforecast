import { describe, expect, test } from "bun:test";
import { createHmac } from "node:crypto";
import { decryptJson, parsePairing } from "../../pwa/lib/crypto.js";
import { KEY, KEY_BYTES } from "../../pwa/test/helpers.js";
import { linkOf, pairingFromInput, relayOrigin } from "../lib/link.js";
import { newPairing, sealJson, writeToken } from "../lib/seal.js";

describe("chiffrement compatible avec le Mac et le téléphone", () => {
  test("ce que le collecteur chiffre, le code de déchiffrement existant le lit", async () => {
    const blob = await sealJson({ kind: "guest-activity", n: 3 }, KEY);
    expect(await decryptJson(blob, KEY)).toEqual({ kind: "guest-activity", n: 3 });
  });

  test("même vecteur que app/MobileCrypto.swift : clé 0x00…0x1f, nonce 0xa0…0xab", async () => {
    const nonce = Uint8Array.from({ length: 12 }, (_, index) => 0xa0 + index);
    // Le vecteur Swift chiffre {"hello":"mobile"} ; JSON.stringify produit les mêmes octets.
    expect(await sealJson({ hello: "mobile" }, KEY, nonce)).toBe("oKGio6SlpqeoqaqrnToUSCmnbZ1YR-q8ZROsu1LR6TTezi9REKnTcKBV7_CgZQ");
  });

  test("jeton d'écriture : HMAC-SHA256(clé, « usageforecast/write »), comme MobileCrypto.writeToken", async () => {
    const expected = createHmac("sha256", Buffer.from(KEY_BYTES)).update("usageforecast/write").digest("hex");
    expect(await writeToken(KEY)).toBe(expected);
    expect(await writeToken(KEY)).toMatch(/^[0-9a-f]{64}$/);
  });

  test("clé invalide : erreur explicite", async () => {
    await expect(sealJson({}, "court")).rejects.toThrow("clé d'association invalide");
  });
});

describe("association", () => {
  test("adresse seule du relais : un nouveau coffre, dont le lien est lisible par le téléphone et le Mac", () => {
    const outcome = pairingFromInput("https://relais.example.workers.dev/");
    expect(outcome.created).toBe(true);
    const link = linkOf(outcome.pairing);
    expect(link.startsWith("https://relais.example.workers.dev/#v1.")).toBe(true);
    expect(parsePairing(link)).toEqual({ id: outcome.pairing.id, key: outcome.pairing.key });
  });

  test("lien complet : on reprend le coffre donné", () => {
    const pairing = { relay: "https://relais.example.workers.dev", ...newPairing() };
    const outcome = pairingFromInput(linkOf(pairing));
    expect(outcome).toEqual({ pairing, created: false });
  });

  test("refus : http hors localhost, lien abîmé, entrée vide", () => {
    expect(pairingFromInput("http://relais.example.com").error).toContain("https");
    expect(pairingFromInput("https://relais.example.com/#v1.court.abc").error).toContain("illisible");
    expect(pairingFromInput("").error).toBeDefined();
    expect(pairingFromInput(undefined).error).toBeDefined();
    expect(relayOrigin("http://localhost:8788/x")).toBe("http://localhost:8788");
    expect(relayOrigin("pas une adresse")).toBeNull();
  });

  test("deux coffres créés : identifiants et clés différents", () => {
    const [a, b] = [newPairing(), newPairing()];
    expect(a.id).toMatch(/^[0-9a-f]{32}$/);
    expect(a.id).not.toBe(b.id);
    expect(a.key).not.toBe(b.key);
  });
});

describe("association par code d'invitation", () => {
  test("le code créé sur le téléphone donne au collecteur son coffre et le lien de son tableau de bord", async () => {
    const { prepareLoan } = await import("../../pwa/lib/loan.js");
    const { pairingFromCode } = await import("../lib/link.js");
    const { default: worker } = await import("../../relay/src/worker.js");
    const store = new Map();
    const VAULT = {
      async get(key) { return store.get(key) ?? null; },
      async put(key, value) { store.set(key, value); },
      async delete(key) { store.delete(key); },
    };
    const fetchImpl = (url, init) => worker.fetch(new Request(url, init), { VAULT });
    const prepared = await prepareLoan({ guestName: "Sam", share: 0.7, endsAt: new Date("2026-11-05T09:00:00Z"), newPairing, iterations: 1000 });
    await fetchImpl(`https://relais.example/v1/invite/${prepared.inviteID}`, { method: "PUT", body: prepared.invite });
    const outcome = await pairingFromCode("https://relais.example/", prepared.code, { fetchImpl, iterations: 1000 });
    expect(outcome.pairing).toEqual({ relay: "https://relais.example", ...prepared.command.guestVault, view: prepared.command.viewVault });
    expect(parsePairing(outcome.viewLink)).toEqual(prepared.command.viewVault);
    expect((await pairingFromCode("http://relais.example", prepared.code, { fetchImpl })).error).toContain("https");
  });
});
