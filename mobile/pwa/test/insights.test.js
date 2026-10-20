import { describe, expect, test } from "bun:test";
import * as insights from "../lib/insights.js";
import { NOON, day, insightFixture } from "./helpers.js";

// Mêmes cas, mêmes résultats que « Statistiques du journal » dans tests/main.swift.
const fixture = insightFixture();

describe("jours récents", () => {
  test("14 jours dont aujourd'hui en dernier, case vide sans donnée, jour partiel non fiable", () => {
    const recent = insights.recentDays(fixture, 14, NOON);
    expect(recent.length).toBe(14);
    expect(recent.at(-1).day).toBe("2026-10-19");
    expect(recent.at(-1).isToday).toBe(true);
    expect(recent[0].day).toBe("2026-10-06");
    expect(recent.find((entry) => entry.day === "2026-10-10").isReliable).toBe(false);
    expect(insights.recentDays([], 7, NOON).every((entry) => entry.summary === null)).toBe(true);
  });

  test("aller-retour du jour AAAA-MM-JJ", () => {
    expect(insights.stamp(insights.dateFromStamp("2026-10-19"))).toBe("2026-10-19");
    expect(insights.dateFromStamp("n'importe quoi")).toBeNull();
  });
});

describe("chiffres clés", () => {
  test("moyenne par jour : aujourd'hui et jour partiel exclus (146 / 12)", () => {
    const average = insights.averagePerDay(fixture, 14, NOON);
    expect(average.days).toBe(12);
    expect(average.value).toBeCloseTo(146 / 12, 5);
    expect(insights.averagePerDay([], 14, NOON)).toBeNull();
  });

  test("jour record : 30 points le 30/09", () => {
    expect(insights.busiestDay(fixture).day).toBe("2026-09-30");
    expect(insights.busiestDay([])).toBeNull();
  });
});

describe("rythme habituel", () => {
  test("lundi : moyenne de 3 jours, solide ; samedi : 2 jours (le partiel est exclu), indicatif", () => {
    const weekdays = insights.weekdayStats(fixture, NOON);
    expect(weekdays.length).toBe(7);
    expect(weekdays[0]).toMatchObject({ count: 3, average: 15, isSolid: true });
    expect(weekdays[5]).toMatchObject({ count: 2, average: 10, isSolid: false });
  });

  test("heures : 9 h active 20 jours sur 20, 20 h trois jours, pointe à 9 h", () => {
    const hours = insights.hourStats(fixture, 28, NOON);
    expect(hours.length).toBe(24);
    expect(hours[9]).toMatchObject({ activeDays: 20, totalDays: 20, fraction: 1 });
    expect(hours[20].activeDays).toBe(3);
    expect(hours[3].activeDays).toBe(0);
    expect(insights.peakHour(hours).hour).toBe(9);
    expect(insights.peakHour(insights.hourStats([], 28, NOON))).toBeNull();
  });
});

describe("semaine contre semaine, à jours égaux", () => {
  test("mercredi : lundi + mardi = 25 pts contre 11 la semaine précédente", () => {
    const comparison = insights.weekComparison(fixture, new Date(2026, 9, 14, 12));
    expect(comparison).toMatchObject({ completedDays: 2, current: 25, previous: 11, delta: 14 });
  });

  test("lundi : aucun jour complet, pas de comparaison", () => {
    expect(insights.weekComparison(fixture, NOON)).toMatchObject({ completedDays: 0, current: 0, previous: null, delta: null });
  });

  test("semaine précédente absente du journal : pas de comparaison", () => {
    const comparison = insights.weekComparison(fixture, new Date(2026, 8, 30, 12));
    expect(comparison).toMatchObject({ completedDays: 2, current: 57, previous: null });
    expect(insights.weekComparison([day("2026-10-13", 5), day("2026-10-12", 3)], new Date(2026, 9, 14, 12)).previous).toBeNull();
  });
});

describe("fiabilité", () => {
  test("niveaux selon le nombre de jours fiables", () => {
    const rows = (count) => Array.from({ length: count }, (_, index) => day(`2026-08-${String(index + 1).padStart(2, "0")}`, 1));
    expect(insights.confidence(rows(0)).key).toBe("veryLow");
    expect(insights.confidence(rows(3)).key).toBe("building");
    expect(insights.confidence(rows(14)).key).toBe("good");
    expect(insights.confidence(rows(28)).key).toBe("solid");
    expect(insights.confidence(fixture).key).toBe("good");
  });
});
