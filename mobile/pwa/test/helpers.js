import { bytesToB64url } from "../lib/crypto.js";

export const KEY_BYTES = Uint8Array.from({ length: 32 }, (_, index) => index);
export const KEY = bytesToB64url(KEY_BYTES);
export const ID = "0123456789abcdef0123456789abcdef";

/** Chiffre comme le fait l'app Mac (nonce aléatoire puis texte chiffré et étiquette), pour tester la lecture de bout en bout. */
export async function encrypt(object, keyBytes = KEY_BYTES) {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, ["encrypt"]);
  const sealed = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, new TextEncoder().encode(JSON.stringify(object))));
  return bytesToB64url(new Uint8Array([...nonce, ...sealed]));
}

export function day(stampText, used, samples = 1000, hours = [9]) {
  return { day: stampText, weeklyUsed: used, sessionUsed: used * 2, peakSession: 40, activeHours: hours, samples };
}

/** Le même jeu de données que tests/main.swift : 28/09 au 18/10 (le 10/10 partiel), puis aujourd'hui lundi 19/10. */
export function insightFixture() {
  const rows = [];
  for (const d of [28, 29, 30]) rows.push(day(`2026-09-${d}`, d, 1000, d === 28 ? [9, 20] : [9]));
  for (let d = 1; d <= 18; d++) rows.push(day(`2026-10-${String(d).padStart(2, "0")}`, d, d === 10 ? 100 : 1000, d === 5 || d === 12 ? [9, 20] : [9]));
  rows.push(day("2026-10-19", 7, 400));
  return rows;
}

export const NOON = new Date(2026, 9, 19, 12);   // lundi 19 octobre 2026, midi

export function rawSnapshot(overrides = {}) {
  return {
    version: 1,
    updatedAt: "2026-10-19T10:00:00Z",
    dataAt: "2026-10-19T10:00:00Z",
    appVersion: "1.13.0",
    source: "claude.ai",
    forecast: {
      version: 1,
      updatedAt: "2026-10-19T10:00:00Z",
      session: { percent: 25, resetsAt: "2026-10-19T12:30:00Z", projectedPercent: 77, expectedPercent: 35, pace: "under", ratePerHour: 8.2 },
      weekly: { percent: 54, resetsAt: "2026-10-21T10:00:00Z", projectedPercent: 73, expectedPercent: 60, pace: "under", perDayPercent: 25 },
      usedTodayPercent: 17,
      line: "Prévision · session ≈ 77 %",
    },
    dayBudget: { allowed: 24, used: 17, level: "ok" },
    credits: { title: "Crédits API · Max 5x", value: "100 $", detail: "Expirent dans 17 j · ≈ 5,88 $ par jour", usedFraction: 0 },
    servicesOK: true,
    history: [{ t: 1792400000, s: 10, w: 50 }, { t: 1792400300, s: 12, w: 50 }],
    daily: [{ day: "2026-10-19", weeklyUsed: 22, sessionUsed: 60, peakSession: 52, activeHours: [16, 17], samples: 499 }],
    ...overrides,
  };
}
