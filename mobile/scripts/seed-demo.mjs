// Dépose un snapshot de démonstration chiffré sur un relais et affiche le lien d'appairage, pour tester l'application sans le Mac.
// Usage : bun mobile/scripts/seed-demo.mjs http://localhost:8788 [jours] [scénario]
// Scénarios : normal (défaut), alerte (limites proches, budget dépassé, incident, données anciennes), peu (2 jours de journal), vide (aucun journal ni crédits).
import { createHash, createHmac, randomBytes, webcrypto } from "node:crypto";

const relay = (process.argv[2] ?? "http://localhost:8788").replace(/\/$/, "");
const days = Number(process.argv[3] ?? 45);
const scenario = process.argv[4] ?? "normal";
// DEMO_FIXED=1 : clé et identifiant déterministes (démonstration locale uniquement), pour garder le même lien après un redémarrage du serveur.
const fixed = process.env.DEMO_FIXED === "1";
const key = fixed ? createHash("sha256").update("claude-usage-bar demo key").digest() : randomBytes(32);
const id = fixed ? createHash("sha256").update("claude-usage-bar demo id").digest("hex").slice(0, 32) : randomBytes(16).toString("hex");
const b64url = (buffer) => Buffer.from(buffer).toString("base64url");

const now = new Date();
const stamp = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
const base = [26, 22, 24, 20, 17, 7, 4];
const daily = Array.from({ length: days }, (_, index) => {
  const offset = days - 1 - index;
  const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset);
  const weekday = (date.getDay() + 6) % 7;
  const used = Math.max(1, base[weekday] + ((offset * 37) % 9) - 4);
  const hours = (weekday < 5 ? [9, 10, 11, 12, 14, 15, 16, 17, 18] : [10, 11, 15, 16]).filter((hour) => (hour + offset) % 5 !== 0);
  return { day: stamp(date), weeklyUsed: offset === 0 ? used * 0.45 : used, sessionUsed: used * 2.6, peakSession: Math.min(100, 35 + used * 1.8), activeHours: hours, samples: offset === 0 ? 520 : offset % 11 === 3 ? 180 : 1100 + ((offset * 13) % 300) };
});

const nowSeconds = Math.floor(now / 1000);
const history = Array.from({ length: 288 }, (_, index) => {
  const t = nowSeconds - (287 - index) * 300;
  const phase = ((287 - index) * 5 % 300) / 300;
  return { t, s: Math.max(0, Math.round((1 - phase) * 62 + (index % 7 === 0 ? 3 : 0))), w: Math.min(100, 30 + index / 288 * 24) };
});

const snapshot = {
  version: 1, updatedAt: now.toISOString(), dataAt: new Date(now - 90 * 1000).toISOString(), appVersion: "1.13.0", source: "claude.ai",
  forecast: {
    version: 1, updatedAt: now.toISOString(),
    session: { percent: 32, resetsAt: new Date(now.getTime() + (2 * 3600 + 53 * 60) * 1000).toISOString(), projectedPercent: 76, expectedPercent: 41, pace: "under", ratePerHour: 8.2 },
    weekly: { percent: 54, resetsAt: new Date(now.getTime() + (44 * 3600) * 1000).toISOString(), projectedPercent: 73, expectedPercent: 71, pace: "onTrack", perDayPercent: 25, ratePerHour: 1.1 },
    usedTodayPercent: 17, line: "Prévision · session ≈ 76 % · semaine ≈ 73 % (25 %/j)",
  },
  dayBudget: { allowed: 24, used: 17, level: "ok" },
  credits: { title: "Crédits API · Max 5x", value: "100 $", detail: "Expirent dans 17 j · ≈ 5,88 $ par jour", usedFraction: 0 },
  servicesOK: true, history, daily,
};

if (scenario === "alerte") {
  snapshot.dataAt = new Date(now - 22 * 60 * 1000).toISOString();
  snapshot.forecast.session = { percent: 93, resetsAt: new Date(now.getTime() + 75 * 60 * 1000).toISOString(), projectedPercent: 124, expectedPercent: 55, pace: "over", ratePerHour: 21, exhaustsAt: new Date(now.getTime() + 20 * 60 * 1000).toISOString() };
  snapshot.forecast.weekly = { percent: 88, resetsAt: new Date(now.getTime() + 30 * 3600 * 1000).toISOString(), projectedPercent: 112, expectedPercent: 82, pace: "over", perDayPercent: 12, ratePerHour: 3.4 };
  snapshot.dayBudget = { allowed: 24, used: 31, level: "over" };
  snapshot.credits = { title: "Crédits API · Max 20x avec un nom très long pour tester les retours à la ligne", value: "1 250,50 $", detail: "Expirent dans 3 j · ≈ 416,83 $ par jour", usedFraction: 0.62 };
  snapshot.servicesOK = false;
  snapshot.history[snapshot.history.length - 1].s = 93;
}
if (scenario === "peu") {
  snapshot.daily = snapshot.daily.slice(-2);
  snapshot.history = snapshot.history.slice(-30);
  snapshot.credits = null;
}
if (scenario === "vide") {
  snapshot.daily = [];
  snapshot.history = [];
  snapshot.credits = null;
  snapshot.dayBudget = null;
  snapshot.forecast.session = null;
}

const nonce = randomBytes(12);
const cryptoKey = await webcrypto.subtle.importKey("raw", key, "AES-GCM", false, ["encrypt"]);
const sealed = Buffer.from(await webcrypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, cryptoKey, new TextEncoder().encode(JSON.stringify(snapshot))));
const blob = b64url(Buffer.concat([nonce, sealed]));
const writeToken = createHmac("sha256", key).update("claude-usage-bar/write").digest("hex");

const response = await fetch(`${relay}/v1/${id}`, { method: "PUT", body: blob, headers: { "x-write-token": writeToken } });
if (!response.ok) { console.error("Échec de l'envoi :", response.status, await response.text()); process.exit(1); }
console.log(`Snapshot de démonstration déposé (${blob.length} octets chiffrés, ${days} jours de journal).`);
console.log(`${relay}/#v1.${id}.${b64url(key)}`);
