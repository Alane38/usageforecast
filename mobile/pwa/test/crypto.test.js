import { describe, expect, test } from "bun:test";
import { b64urlToBytes, bytesToB64url, decryptBlob, decryptJson, parsePairing } from "../lib/crypto.js";
import { ID, KEY, KEY_BYTES, encrypt } from "./helpers.js";

// Vecteur produit par app/MobileCrypto.swift (clé 0x00…0x1f, nonce 0xa0…0xab) : l'app Mac et le téléphone doivent s'entendre.
const SWIFT_BLOB = "oKGio6SlpqeoqaqrnToUSCmnbZ1YR-q8ZROsu1LR6TTezi9REKnTcKBV7_CgZQ";

describe("compatibilité avec l'app Mac", () => {
  test("déchiffre exactement ce que l'app Mac a produit", async () => {
    expect(await decryptJson(SWIFT_BLOB, KEY)).toEqual({ hello: "mobile" });
  });

  test("mauvaise clé, donnée modifiée ou blob illisible : refus (null, jamais d'exception)", async () => {
    expect(await decryptBlob(SWIFT_BLOB, bytesToB64url(new Uint8Array(32).fill(7)))).toBeNull();
    const tampered = b64urlToBytes(SWIFT_BLOB);
    tampered[tampered.length - 1] ^= 1;
    expect(await decryptBlob(bytesToB64url(tampered), KEY)).toBeNull();
    expect(await decryptBlob("n'importe quoi", KEY)).toBeNull();
    expect(await decryptBlob("", KEY)).toBeNull();
    expect(await decryptBlob(SWIFT_BLOB, "court")).toBeNull();
  });

  test("aller-retour avec un nonce aléatoire", async () => {
    const first = await encrypt({ a: 1 });
    expect(first).not.toBe(await encrypt({ a: 1 }));
    expect(await decryptJson(first, KEY)).toEqual({ a: 1 });
  });

  test("un texte déchiffré qui n'est pas du JSON : null", async () => {
    const key = await crypto.subtle.importKey("raw", KEY_BYTES, "AES-GCM", false, ["encrypt"]);
    const nonce = new Uint8Array(12);
    const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, new TextEncoder().encode("pas du json")));
    expect(await decryptJson(bytesToB64url(new Uint8Array([...nonce, ...sealed])), KEY)).toBeNull();
  });
});

describe("base64url", () => {
  test("aller-retour sans « + / = »", () => {
    const bytes = Uint8Array.from([0xfb, 0xff, 0xfe, 0x00, 0x3e]);
    const text = bytesToB64url(bytes);
    expect(text).not.toMatch(/[+/=]/);
    expect([...b64urlToBytes(text)]).toEqual([...bytes]);
  });

  test("caractères interdits : null", () => {
    expect(b64urlToBytes("a+b")).toBeNull();
    expect(b64urlToBytes(42)).toBeNull();
  });
});

describe("lien d'appairage", () => {
  test("lit le lien complet, le fragment seul ou avec un dièse", () => {
    const fragment = `v1.${ID}.${KEY}`;
    expect(parsePairing(`https://usage.example.workers.dev/#${fragment}`)).toEqual({ id: ID, key: KEY });
    expect(parsePairing(`#${fragment}`)).toEqual({ id: ID, key: KEY });
    expect(parsePairing(`  ${fragment}  `)).toEqual({ id: ID, key: KEY });
  });

  test("refuse une version inconnue, un identifiant mal formé, une clé trop courte ou absente", () => {
    expect(parsePairing(`v2.${ID}.${KEY}`)).toBeNull();
    expect(parsePairing(`v1.court.${KEY}`)).toBeNull();
    expect(parsePairing(`v1.${ID.toUpperCase()}.${KEY}`)).toBeNull();
    expect(parsePairing(`v1.${ID}.AAAA`)).toBeNull();
    expect(parsePairing("https://usage.example.workers.dev/")).toBeNull();
    expect(parsePairing(undefined)).toBeNull();
  });
});
