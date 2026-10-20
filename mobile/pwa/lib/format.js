// Mêmes textes que l'app Mac (MenuBarDisplay, SyncHelpers, AlertRules, StatsStyle), en français.

export const WEEKDAYS = ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."];
export const WEEKDAYS_FULL = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"];

const pad2 = (value) => String(value).padStart(2, "0");

/** 0 = lundi … 6 = dimanche. */
export function weekdayIndex(date) {
  return (date.getDay() + 6) % 7;
}

/** « 22 pts », « 1 pt », « 7,2 pts » : une décimale seulement sous 10 points et si la valeur n'est pas ronde. */
export function points(value) {
  if (value < 10 && Math.round(value) !== value) {
    const text = value.toFixed(1);
    if (!text.startsWith("10")) return `${text.replace(".", ",")} pts`;   // 9,96 s'écrit « 10 pts », pas « 10,0 pts »
  }
  const rounded = Math.round(value);
  return rounded === 1 ? "1 pt" : `${rounded} pts`;
}

export const percent = (fraction) => `${Math.round(fraction * 100)} %`;
export const hourLabel = (hour) => `${hour} h`;

/** « 45 min », « 2h14 », « 3j 4h » : le plus court lisible d'un coup d'œil. */
export function countdown(milliseconds) {
  const totalMinutes = Math.max(Math.floor(milliseconds / 60000), 0);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  if (days > 0) return `${days}j ${hours}h`;
  if (hours > 0) return `${hours}h${pad2(minutes)}`;
  return `${minutes} min`;
}

/** « à l'instant », « il y a 12 min », « il y a 3 h », « il y a 2 j ». */
export function age(milliseconds) {
  const minutes = Math.max(Math.floor(milliseconds / 60000), 0);
  if (minutes < 1) return "à l'instant";
  if (minutes < 60) return `il y a ${minutes} min`;
  if (minutes < 1440) return `il y a ${Math.floor(minutes / 60)} h`;
  return `il y a ${Math.floor(minutes / 1440)} j`;
}

/** Une donnée de plus de 10 minutes est signalée comme périmée. */
export const isStale = (milliseconds) => milliseconds > 600000;

/** « 18 h 40 ». */
export const clock = (date) => `${date.getHours()} h ${pad2(date.getMinutes())}`;

/** « lun. 19/10 ». */
export const dayLabel = (date) => `${WEEKDAYS[weekdayIndex(date)]} ${date.getDate()}/${pad2(date.getMonth() + 1)}`;

/** Heures regroupées par plages : [0, 1, 2, 7, 9, 10] devient « 0–2, 7, 9–10 h ». */
export function hoursText(hours) {
  if (!hours || hours.length === 0) return "—";
  const ranges = [];
  let start = hours[0];
  let previous = hours[0];
  for (const hour of [...hours.slice(1), Infinity]) {
    if (hour === previous + 1) { previous = hour; continue; }
    ranges.push(start === previous ? `${start}` : `${start}–\u2060${previous}`);   // U+2060 : pas de retour à la ligne après le tiret
    start = hour;
    previous = hour;
  }
  return `${ranges.join(", ")} h`;
}

/** Plafond d'axe arrondi à un multiple de 10 (au moins 10). */
export const ceiling = (maxValue) => Math.max(10, Math.ceil(maxValue / 10) * 10);

/** Libellé de rythme : le même que le popover, jamais « en rythme » en jaune. */
export function paceChip(percentValue, pace) {
  if (percentValue >= 100) return "Limite atteinte";
  if (percentValue >= 90) return "Limite proche";
  if (!pace) return percentValue >= 70 ? "Usage élevé" : null;
  if (pace === "over") return "Trop rapide";
  if (percentValue >= 70) return "Usage élevé";
  return pace === "under" ? "En dessous du rythme" : "En rythme";
}

/**
 * Tonalité d'une jauge. Sur le téléphone, des données de quelques minutes sont la norme (le Mac dort, le réseau coupe) :
 * un danger (90 % et plus) et un avertissement (70 % et plus, ou rythme trop rapide) gardent donc leur couleur même si les données sont
 * anciennes, l'âge étant dit à part. Seul le « tout va bien » est grisé : on ne peut pas affirmer que tout va bien sur une donnée ancienne.
 */
export function tone(percentValue, pace, stale) {
  if (percentValue >= 90) return "danger";
  if (percentValue >= 70 || pace === "over") return "warning";
  return stale ? "stale" : "ok";
}

/** « 25 min », « 1 h 40 », « 38 h », « 3 j 4 h » : en jours seulement à partir de 48 h. */
export function duration(seconds) {
  const totalMinutes = Math.max(Math.round(seconds / 60), 0);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  if (totalMinutes >= 48 * 60) return hours > 0 ? `${days} j ${hours} h` : `${days} j`;
  if (totalMinutes >= 600) return `${Math.floor(totalMinutes / 60)} h`;
  if (hours > 0) return minutes > 0 ? `${hours} h ${pad2(minutes)}` : `${hours} h`;
  return `${minutes} min`;
}

/** « Rythme récent : 8,2 %/h · 100 % vers 18 h 40 » ; nul quand le rythme est négligeable et sans échéance. */
export function recentLine(window) {
  const rate = window?.ratePerHour ?? 0;
  if (!window || (rate < 1 && !window.exhaustsAt)) return null;
  const text = (rate < 10 ? String(Math.round(rate * 10) / 10) : String(Math.round(rate))).replace(".", ",");
  return `Rythme récent : ${text} %/h${window.exhaustsAt ? ` · 100 % vers ${clock(window.exhaustsAt)}` : ""}`;
}

/** « Aujourd'hui : 17 % sur 24 % conseillés », avec « dépassé de N % » au-delà. */
export function budgetLine(budget) {
  const base = `Aujourd'hui : ${Math.round(budget.used)} % sur ${Math.round(budget.allowed)} % conseillés`;
  return budget.level === "over" ? `${base}, dépassé de ${Math.round(budget.used - budget.allowed)} %` : base;
}

const NBSP = "\u00a0";

/**
 * Espaces insécables entre un nombre et son unité (« 14 h 02 », « 100 % », « 5 j », « 24 pts ») : un retour à la ligne ne doit jamais
 * séparer « 100 » de « % ». Appliquée à tout texte affiché par `dom.js`.
 */
export function tidy(text) {
  return String(text)
    .replace(/(\d) (%|h\b|j\b|min\b|pts?\b|\$|\/h\b)/g, `$1${NBSP}$2`)
    .replace(/(\d\u00a0h) (\d{2})\b/g, `$1${NBSP}$2`);
}
