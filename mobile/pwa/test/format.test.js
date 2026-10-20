import { describe, expect, test } from "bun:test";
import { tidy, age, budgetLine, ceiling, duration, recentLine, clock, countdown, dayLabel, hoursText, isStale, paceChip, percent, points, tone, weekdayIndex } from "../lib/format.js";

const MIN = 60000;

describe("textes", () => {
  test("points : pluriel et décimale", () => {
    expect(points(22)).toBe("22 pts");
    expect(points(1)).toBe("1 pt");
    expect(points(7.2)).toBe("7,2 pts");
    expect(points(9.96)).toBe("10 pts");
    expect(points(9.94)).toBe("9,9 pts");
    expect(points(0)).toBe("0 pts");
    expect(points(14.4)).toBe("14 pts");
  });

  test("décompte : 45 min, 2h14, 3j 4h", () => {
    expect(countdown(45 * MIN)).toBe("45 min");
    expect(countdown(134 * MIN)).toBe("2h14");
    expect(countdown(125 * MIN)).toBe("2h05");
    expect(countdown((3 * 1440 + 4 * 60) * MIN)).toBe("3j 4h");
    expect(countdown(-5 * MIN)).toBe("0 min");
  });

  test("âge des données", () => {
    expect(age(20000)).toBe("à l'instant");
    expect(age(12 * MIN)).toBe("il y a 12 min");
    expect(age(3 * 60 * MIN)).toBe("il y a 3 h");
    expect(age(2 * 1440 * MIN)).toBe("il y a 2 j");
    expect(isStale(10 * MIN)).toBe(false);
    expect(isStale(10 * MIN + 1)).toBe(true);
  });

  test("jours et heures", () => {
    expect(weekdayIndex(new Date(2026, 9, 19))).toBe(0);
    expect(weekdayIndex(new Date(2026, 9, 18))).toBe(6);
    expect(dayLabel(new Date(2026, 9, 19))).toBe("lun. 19/10");
    expect(dayLabel(new Date(2026, 8, 5))).toBe("sam. 5/09");
    expect(clock(new Date(2026, 9, 19, 18, 5))).toBe("18 h 05");
    expect(hoursText([0, 1, 2, 7, 9, 10])).toBe("0–\u20602, 7, 9–\u206010 h");
    expect(hoursText([16])).toBe("16 h");
    expect(hoursText([])).toBe("—");
  });

  test("pourcentage et plafond d'axe", () => {
    expect(percent(0.346)).toBe("35 %");
    expect(ceiling(0)).toBe(10);
    expect(ceiling(29)).toBe(30);
    expect(ceiling(30)).toBe(30);
    expect(ceiling(30.1)).toBe(40);
  });
});

describe("rythme (mêmes règles que le popover)", () => {
  test("libellés", () => {
    expect(paceChip(100, "under")).toBe("Limite atteinte");
    expect(paceChip(93, "under")).toBe("Limite proche");
    expect(paceChip(8, "under")).toBe("En dessous du rythme");
    expect(paceChip(40, "onTrack")).toBe("En rythme");
    expect(paceChip(40, "over")).toBe("Trop rapide");
    expect(paceChip(75, "onTrack")).toBe("Usage élevé");
    expect(paceChip(10, null)).toBeNull();
    expect(paceChip(80, null)).toBe("Usage élevé");
  });

  test("tonalités : l'âge des données grise le calme mais jamais un danger ni un avertissement", () => {
    expect(tone(95, "under", true)).toBe("danger");
    expect(tone(88, "over", true)).toBe("warning");
    expect(tone(80, "under", true)).toBe("warning");
    expect(tone(40, "onTrack", true)).toBe("stale");
    expect(tone(95, "under", false)).toBe("danger");
    expect(tone(70, "under", false)).toBe("warning");
    expect(tone(20, "over", false)).toBe("warning");
    expect(tone(20, "under", false)).toBe("ok");
  });
});

describe("durées et lignes de synthèse", () => {
  test("durée : 25 min, 1 h 40, 38 h, 3 j 4 h", () => {
    expect(duration(25 * 60)).toBe("25 min");
    expect(duration(100 * 60)).toBe("1 h 40");
    expect(duration(60 * 60)).toBe("1 h");
    expect(duration(38 * 3600)).toBe("38 h");
    expect(duration((3 * 24 + 4) * 3600)).toBe("3 j 4 h");
    expect(duration(72 * 3600)).toBe("3 j");
  });

  test("rythme récent", () => {
    expect(recentLine({ ratePerHour: 8.2 })).toBe("Rythme récent : 8,2 %/h");
    expect(recentLine({ ratePerHour: 12 })).toBe("Rythme récent : 12 %/h");
    expect(recentLine({ ratePerHour: 1 })).toBe("Rythme récent : 1 %/h");
    expect(recentLine({ ratePerHour: 0.4 })).toBeNull();
    expect(recentLine({ ratePerHour: 0.4, exhaustsAt: new Date(2026, 9, 19, 18, 40) })).toBe("Rythme récent : 0,4 %/h · 100 % vers 18 h 40");
    expect(recentLine(null)).toBeNull();
  });

  test("budget du jour", () => {
    expect(budgetLine({ allowed: 24, used: 17, level: "ok" })).toBe("Aujourd'hui : 17 % sur 24 % conseillés");
    expect(budgetLine({ allowed: 24, used: 31, level: "over" })).toBe("Aujourd'hui : 31 % sur 24 % conseillés, dépassé de 7 %");
  });
});

describe("espaces insécables", () => {
  test("un nombre n'est jamais séparé de son unité", () => {
    expect(tidy("100 % vers 14 h 02")).toBe("100\u00a0% vers 14\u00a0h\u00a002");
    expect(tidy("Expirent dans 17 j · ≈ 5,88 $ par jour")).toBe("Expirent dans 17\u00a0j · ≈ 5,88\u00a0$ par jour");
    expect(tidy("Rythme récent : 8,2 %/h")).toBe("Rythme récent : 8,2\u00a0%/h");
    expect(tidy("24 pts de semaine, 1 pt")).toBe("24\u00a0pts de semaine, 1\u00a0pt");
  });

  test("les textes sans nombre ne changent pas", () => {
    expect(tidy("Session en cours")).toBe("Session en cours");
    expect(tidy("à l'instant")).toBe("à l'instant");
  });
});
