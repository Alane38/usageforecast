import { describe, expect, test } from "bun:test";
import { attention } from "../lib/attention.js";
import { normalize } from "../lib/snapshot.js";
import { rawSnapshot } from "./helpers.js";

const NOW = new Date("2026-10-19T10:05:00Z");
const snap = (overrides, forecast = {}) => {
  const raw = rawSnapshot(overrides);
  raw.forecast = { ...raw.forecast, ...forecast };
  return normalize(raw);
};

describe("points d'attention", () => {
  test("une journée calme : rien à signaler", () => {
    expect(attention(snap({}), NOW)).toEqual([]);
  });

  test("session à 93 % : danger avec le délai avant le reset", () => {
    const alerts = attention(snap({}, { session: { percent: 93, resetsAt: "2026-10-19T11:25:00Z", pace: "over" } }), NOW);
    expect(alerts[0]).toEqual({ level: "danger", text: "Session à 93 % : reset dans 1h20" });
  });

  test("limite atteinte", () => {
    const alerts = attention(snap({}, { weekly: { percent: 100, resetsAt: "2026-10-21T10:05:00Z" } }), NOW);
    expect(alerts[0]).toEqual({ level: "danger", text: "Semaine : limite atteinte : reset dans 2j 0h" });
  });

  test("épuisement prévu avant le reset : avertissement avec l'heure", () => {
    const exhaustsAt = new Date(2026, 9, 19, 18, 40).toISOString();
    const alerts = attention(snap({}, { session: { percent: 40, resetsAt: "2026-10-20T10:00:00Z", exhaustsAt, pace: "over" } }), NOW);
    expect(alerts).toEqual([{ level: "warning", text: "Session : à ce rythme, 100 % vers 18 h 40" }]);
  });

  test("budget du jour dépassé ou presque atteint", () => {
    expect(attention(snap({ dayBudget: { allowed: 24, used: 31, level: "over" } }), NOW)[0].text).toContain("dépassé de 7 %");
    expect(attention(snap({ dayBudget: { allowed: 24, used: 21, level: "close" } }), NOW)[0]).toEqual({ level: "info", text: "Budget du jour presque atteint (21 % sur 24 %)" });
  });

  test("crédits qui expirent dans 5 jours ou moins, pas avant", () => {
    const soon = { title: "Crédits API", value: "100 $", detail: "Expirent dans 3 j · ≈ 33 $ par jour", usedFraction: 0 };
    expect(attention(snap({ credits: soon }), NOW)[0].text).toBe("Crédits API : expirent dans 3 j (100 $)");
    expect(attention(snap({}), NOW)).toEqual([]);
  });

  test("incident de service et données anciennes", () => {
    const alerts = attention(snap({ servicesOK: false, dataAt: "2026-10-19T09:30:00Z" }), NOW);
    expect(alerts.map((alert) => alert.text)).toEqual(["Un service Claude signale un incident", "Données du Mac anciennes (il y a 35 min) : le Mac est peut-être en veille"]);
  });

  test("tri du plus grave au moins grave", () => {
    const alerts = attention(snap({ dayBudget: { allowed: 24, used: 21, level: "close" }, servicesOK: false },
      { session: { percent: 95, resetsAt: "2026-10-19T11:00:00Z" } }), NOW);
    expect(alerts.map((alert) => alert.level)).toEqual(["danger", "warning", "info"]);
  });
});
