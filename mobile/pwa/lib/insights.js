// Statistiques du journal quotidien : même logique, mêmes seuils et mêmes résultats que app/DailyInsights.swift (les tests reprennent ses cas).
import { weekdayIndex } from "./format.js";

/** Une journée est exploitable à partir de 5 h de relevés (300 minutes). */
export const MIN_RELIABLE_SAMPLES = 300;
export const SOLID_WEEKDAY_COUNT = 3;
export const INDICATIVE_BELOW = 3;

const pad2 = (value) => String(value).padStart(2, "0");
const addDays = (date, days) => new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
const startOfDay = (date) => new Date(date.getFullYear(), date.getMonth(), date.getDate());

/** « 2026-10-19 » (jour local). */
export const stamp = (date) => `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;

export function dateFromStamp(text) {
  const parts = String(text).split("-").map(Number);
  return parts.length === 3 && parts.every(Number.isInteger) ? new Date(parts[0], parts[1] - 1, parts[2]) : null;
}

export const isReliable = (summary) => summary.samples >= MIN_RELIABLE_SAMPLES;

/** Les `count` derniers jours, aujourd'hui compris, du plus ancien au plus récent ; un jour sans donnée a `summary: null`. */
export function recentDays(summaries, count, now = new Date()) {
  const byDay = new Map(summaries.map((summary) => [summary.day, summary]));
  const today = startOfDay(now);
  return Array.from({ length: count }, (_, index) => {
    const date = addDays(today, -(count - 1 - index));
    const day = stamp(date);
    const summary = byDay.get(day) ?? null;
    return { day, date, summary, isToday: index === count - 1, isReliable: summary ? isReliable(summary) : false };
  });
}

/** Jours passés fiables (aujourd'hui exclu, car incomplet) sur les `windowDays` derniers jours. */
export function reliablePastDays(summaries, windowDays, now = new Date()) {
  return recentDays(summaries, windowDays, now).filter((day) => !day.isToday && day.summary && day.isReliable).map((day) => day.summary);
}

export function averagePerDay(summaries, windowDays = 14, now = new Date()) {
  const days = reliablePastDays(summaries, windowDays, now);
  if (days.length === 0) return null;
  return { value: days.reduce((sum, day) => sum + day.weeklyUsed, 0) / days.length, days: days.length };
}

export function busiestDay(summaries) {
  const reliable = summaries.filter(isReliable);
  return reliable.length === 0 ? null : reliable.reduce((best, day) => (day.weeklyUsed > best.weeklyUsed ? day : best));
}

/** Moyenne par jour de la semaine, lundi en premier, sur les jours passés fiables des 12 dernières semaines. */
export function weekdayStats(summaries, now = new Date()) {
  const buckets = Array.from({ length: 7 }, () => []);
  for (const summary of reliablePastDays(summaries, 84, now)) {
    const date = dateFromStamp(summary.day);
    if (date) buckets[weekdayIndex(date)].push(summary.weeklyUsed);
  }
  return buckets.map((values, weekday) => ({
    weekday,
    average: values.length ? values.reduce((sum, value) => sum + value, 0) / values.length : null,
    count: values.length,
    isSolid: values.length >= SOLID_WEEKDAY_COUNT,
  }));
}

/** Pour chaque heure : sur combien de jours fiables (28 derniers jours, aujourd'hui exclu) l'usage a augmenté. */
export function hourStats(summaries, windowDays = 28, now = new Date()) {
  const days = reliablePastDays(summaries, windowDays, now);
  return Array.from({ length: 24 }, (_, hour) => {
    const activeDays = days.filter((day) => day.activeHours.includes(hour)).length;
    return { hour, activeDays, totalDays: days.length, fraction: days.length ? activeDays / days.length : 0 };
  });
}

export function peakHour(stats) {
  const active = stats.filter((stat) => stat.activeDays > 0);
  return active.length === 0 ? null : active.reduce((best, stat) => (stat.activeDays > best.activeDays ? stat : best));
}

/** Semaine en cours comparée à la précédente à jours égaux : les jours complets du lundi à hier, des deux côtés. */
export function weekComparison(summaries, now = new Date()) {
  const today = startOfDay(now);
  const completed = weekdayIndex(today);
  const byDay = new Map(summaries.map((summary) => [summary.day, summary]));
  const total = (start) => {
    const days = Array.from({ length: completed }, (_, offset) => byDay.get(stamp(addDays(start, offset)))).filter(Boolean);
    return { sum: days.reduce((sum, day) => sum + day.weeklyUsed, 0), usable: days.filter(isReliable).length };
  };
  const currentStart = addDays(today, -completed);
  const current = total(currentStart);
  const previous = total(addDays(currentStart, -7));
  const previousSum = completed > 0 && previous.usable === completed ? previous.sum : null;
  return { completedDays: completed, current: current.sum, previous: previousSum, delta: previousSum === null ? null : current.sum - previousSum };
}

export const CONFIDENCE = [
  { key: "veryLow", label: "Très peu de données", detail: "Les moyennes par jour de la semaine apparaissent à partir de 3 jours identiques observés.", level: 1 },
  { key: "building", label: "En construction", detail: "Les tendances se précisent à chaque semaine qui passe.", level: 2 },
  { key: "good", label: "Correct", detail: "Assez de recul pour comparer tes semaines.", level: 3 },
  { key: "solid", label: "Fiable", detail: "Plusieurs semaines complètes : ton rythme habituel est bien établi.", level: 4 },
];

export function confidence(summaries) {
  const reliable = summaries.filter(isReliable).length;
  return CONFIDENCE[reliable < 3 ? 0 : reliable < 14 ? 1 : reliable < 28 ? 2 : 3];
}
