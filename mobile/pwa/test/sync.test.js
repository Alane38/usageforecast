import { describe, expect, test } from "bun:test";
import { MAX_POLL_SECONDS, nextDelaySeconds, pull } from "../lib/sync.js";
import { ID, KEY, encrypt, rawSnapshot } from "./helpers.js";

const pairing = { id: ID, key: KEY };
const respond = (body, { status = 200, stamp = "1000" } = {}) => async (url) => {
  respond.lastUrl = url;
  return new Response(body, { status, headers: stamp ? { "x-updated-at": stamp } : {} });
};

describe("lecture sur le relais", () => {
  test("récupère, déchiffre et valide", async () => {
    const result = await pull({ pairing, fetchImpl: respond(await encrypt(rawSnapshot())) });
    expect(result.status).toBe("updated");
    expect(result.snapshot.weekly.percent).toBe(54);
    expect(result.raw.version).toBe(1);
    expect(result.stamp).toBe("1000");
    expect(respond.lastUrl).toBe(`/v1/${ID}`);
  });

  test("même horodatage qu'avant : inchangé, sans déchiffrer", async () => {
    const result = await pull({ pairing, previousStamp: "1000", fetchImpl: respond("contenu qui ne sera pas lu") });
    expect(result.status).toBe("unchanged");
  });

  test("coffre vide : message pour l'utilisateur", async () => {
    const result = await pull({ pairing, fetchImpl: respond("{}", { status: 404 }) });
    expect(result.status).toBe("empty");
    expect(result.message).toContain("rien envoyé");
  });

  test("erreur du relais ou réseau coupé : error, jamais d'exception", async () => {
    expect((await pull({ pairing, fetchImpl: respond("", { status: 500 }) })).status).toBe("error");
    const offline = await pull({ pairing, fetchImpl: async () => { throw new TypeError("Failed to fetch"); } });
    expect(offline).toMatchObject({ status: "error", message: "Pas de connexion au relais." });
  });

  test("mauvaise clé : invalide, avec la marche à suivre", async () => {
    const wrongKey = Uint8Array.from({ length: 32 }, () => 9);
    const result = await pull({ pairing, fetchImpl: respond(await encrypt(rawSnapshot(), wrongKey)) });
    expect(result.status).toBe("invalid");
    expect(result.message).toContain("Réassocie");
  });

  test("version de données inconnue : invalide, sans casser", async () => {
    const result = await pull({ pairing, fetchImpl: respond(await encrypt(rawSnapshot({ version: 99 }))) });
    expect(result.status).toBe("invalid");
    expect(result.message).toContain("mets à jour");
  });
});

describe("cadence", () => {
  test("60 s, doublé à chaque échec, plafonné à 10 minutes", () => {
    expect(nextDelaySeconds(0)).toBe(60);
    expect(nextDelaySeconds(1)).toBe(120);
    expect(nextDelaySeconds(3)).toBe(480);
    expect(nextDelaySeconds(4)).toBe(MAX_POLL_SECONDS);
    expect(nextDelaySeconds(40)).toBe(MAX_POLL_SECONDS);
    expect(nextDelaySeconds(-1)).toBe(60);
  });
});
