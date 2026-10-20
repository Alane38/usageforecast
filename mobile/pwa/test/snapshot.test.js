import { describe, expect, test } from "bun:test";
import { normalize } from "../lib/snapshot.js";
import { rawSnapshot } from "./helpers.js";

describe("validation du snapshot", () => {
  test("lit un snapshot complet", () => {
    const snapshot = normalize(rawSnapshot());
    expect(snapshot.session.percent).toBe(25);
    expect(snapshot.session.resetsAt).toBeInstanceOf(Date);
    expect(snapshot.weekly.pace).toBe("under");
    expect(snapshot.weekly.perDayPercent).toBe(25);
    expect(snapshot.dayBudget).toEqual({ allowed: 24, used: 17, level: "ok" });
    expect(snapshot.credits.value).toBe("100 $");
    expect(snapshot.history[0].t).toBe(1792400000 * 1000);
    expect(snapshot.daily[0].activeHours).toEqual([16, 17]);
    expect(snapshot.servicesOK).toBe(true);
  });

  test("version inconnue, document vide ou sans prévision : refus", () => {
    expect(normalize(rawSnapshot({ version: 2 }))).toBeNull();
    expect(normalize(null)).toBeNull();
    expect(normalize(rawSnapshot({ forecast: undefined }))).toBeNull();
    expect(normalize(rawSnapshot({ updatedAt: "pas une date" }))).toBeNull();
  });

  test("des champs facultatifs absents ou invalides sont nettoyés, jamais fatals", () => {
    const snapshot = normalize(rawSnapshot({
      dayBudget: { allowed: "x", used: 3 }, credits: { value: 42 }, servicesOK: "oui", source: "autre",
      history: [{ t: "x" }, { t: 5, s: 1 }], daily: [{ day: "2026-10-19" }, { day: "2026-10-18", weeklyUsed: 5, samples: 10, activeHours: [3, 99, "a", 4.5] }],
    }));
    expect(snapshot.dayBudget).toBeNull();
    expect(snapshot.credits).toBeNull();
    expect(snapshot.servicesOK).toBeNull();
    expect(snapshot.source).toBe("claude.ai");
    expect(snapshot.history.length).toBe(1);
    expect(snapshot.daily.length).toBe(1);
    expect(snapshot.daily[0].activeHours).toEqual([3]);
  });

  test("une session absente reste absente", () => {
    const snapshot = normalize(rawSnapshot({ forecast: { updatedAt: "2026-10-19T10:00:00Z", weekly: { percent: 10 } } }));
    expect(snapshot.session).toBeNull();
    expect(snapshot.weekly.percent).toBe(10);
  });
});
