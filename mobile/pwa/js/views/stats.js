// Écran Statistiques : le même contenu que l'onglet du Mac, pensé pour le toucher (une colonne touchée écrit son détail sous le graphique).
import { h, setWidth } from "../dom.js";
import { columnChart } from "../charts.js";
import * as insights from "../../lib/insights.js";
import { WEEKDAYS, WEEKDAYS_FULL, dayLabel, hourLabel, hoursText, percent, points, weekdayIndex } from "../../lib/format.js";

const kpi = (label, value, detail) => h("div", { class: "kpi" }, h("span", { class: "label" }, label), h("span", { class: "value" }, value), h("span", { class: "detail" }, detail));
const plural = (count, word) => `${count} ${word}${count > 1 ? "s" : ""}`;

function card(title, subtitle, ...content) {
  return h("section", { class: "card" }, h("h2", null, title), h("p", { class: "muted" }, subtitle), ...content);
}

function withReadout(buildChart) {
  const readout = h("p", { class: "readout", "aria-live": "polite", "data-hint": "Touche une colonne pour le détail." });
  return [buildChart((item) => readout.replaceChildren(item ? item.tooltip : "")), readout];
}

function dayTooltip(day) {
  if (!day.summary) return `${dayLabel(day.date)} : aucune donnée (app fermée ou Mac en veille).`;
  const summary = day.summary;
  const state = day.isToday ? "en cours" : day.isReliable ? "journée complète" : "peu de relevés";
  return `${dayLabel(day.date)} (${state}) : ${points(summary.weeklyUsed)} de semaine, ${points(summary.sessionUsed)} de session, pic de session ${Math.round(summary.peakSession)} %, actif à ${hoursText(summary.activeHours)}, ${percent(Math.min(summary.samples / 1440, 1))} de la journée enregistrée.`;
}

function dayChart(recent, average) {
  const ceilingValue = Math.max(10, Math.ceil(Math.max(...recent.map((day) => day.summary?.weeklyUsed ?? 0), average?.value ?? 0) / 10) * 10);
  const items = recent.map((day) => ({
    label: WEEKDAYS[weekdayIndex(day.date)].slice(0, 1).toUpperCase(), sub: String(day.date.getDate()), value: day.summary ? day.summary.weeklyUsed : null,
    light: !day.isReliable || day.isToday, emphasis: day.isToday, tooltip: dayTooltip(day),
  }));
  return [...withReadout((onSelect) => columnChart({ items, max: ceilingValue, average: average?.value ?? null, onSelect, tick: average ? `moy. ${points(average.value)}` : null })),
    h("div", { class: "legend" }, h("span", null, "Journée complète"), h("span", { class: "light" }, "En cours ou peu de relevés"))];
}

function hourChart(stats, peak) {
  if ((stats[0]?.totalDays ?? 0) === 0) return [h("p", { class: "muted" }, "Pas encore de journée exploitable (au moins 5 h de relevés dans la journée).")];
  const light = stats[0].totalDays < insights.INDICATIVE_BELOW;
  const items = stats.map((stat) => ({
    label: hourLabel(stat.hour), value: stat.activeDays > 0 ? stat.fraction * 100 : null, light, emphasis: stat.hour === peak?.hour, valueLabel: hourLabel(stat.hour),
    tooltip: `${hourLabel(stat.hour)} : actif ${plural(stat.activeDays, "jour")} sur ${stat.totalDays} (${percent(stat.fraction)}).`,
  }));
  return withReadout((onSelect) => columnChart({ items, max: 100, height: 70, left: 38, axisFormat: (v) => `${v} %`, labelEvery: 6, onSelect, showEmpty: false }));
}

function weekdayChart(stats) {
  const max = Math.max(10, Math.ceil(Math.max(...stats.map((stat) => stat.average ?? 0)) / 10) * 10);
  const items = stats.map((stat) => ({
    label: WEEKDAYS[stat.weekday], sub: stat.count > 0 ? `${stat.count} j` : "—", value: stat.average, light: !stat.isSolid,
    tooltip: stat.average === null ? `${WEEKDAYS_FULL[stat.weekday]} : aucun jour exploitable observé pour l'instant.`
      : `${WEEKDAYS_FULL[stat.weekday]} : ${points(stat.average)} en moyenne sur ${plural(stat.count, "jour")} (${stat.isSolid ? "moyenne fiable" : "indicatif, il faut au moins 3 jours"}).`,
    valueLabel: stat.average === null ? "" : points(stat.average),
  }));
  return [...withReadout((onSelect) => columnChart({ items, max, height: 80, onSelect })),
    h("div", { class: "legend" }, h("span", null, "3 jours observés ou plus"), h("span", { class: "light" }, "Indicatif (1 ou 2 jours)"))];
}

function compareBar(label, value, scale, tone) {
  const fill = h("span", { class: "fill" });
  setWidth(fill, scale > 0 ? (value / scale) * 100 : 0);
  return h("div", { class: `tone-${tone}` }, h("div", { class: "row" }, h("span", null, label), h("span", { class: "muted" }, points(value))), h("div", { class: "bar" }, fill));
}

function weekCard(comparison) {
  const note = `Sur les mêmes ${plural(comparison.completedDays, "jour")} complet${comparison.completedDays > 1 ? "s" : ""} (du lundi à hier).`;
  if (comparison.completedDays === 0) return card("Cette semaine et la précédente", "Semaines du lundi au dimanche, comparées à jours égaux.", h("p", { class: "muted" }, "La semaine commence : la comparaison apparaît dès mardi, sur le jour complet écoulé."));
  const scale = Math.max(comparison.current, comparison.previous ?? 0, 1);
  const delta = comparison.delta;
  const sign = delta > 0 ? "+" : "−";
  return card("Cette semaine et la précédente", "Semaines du lundi au dimanche, comparées à jours égaux.",
    compareBar("Cette semaine", comparison.current, scale, "accent"),
    comparison.previous === null ? h("p", { class: "muted" }, `Pas de comparaison : la semaine précédente n'a pas ces ${plural(comparison.completedDays, "jour")} avec assez de relevés.`)
      : [compareBar("Semaine précédente", comparison.previous, scale, "stale"),
        h("p", { class: "chip" }, delta === 0 ? "Identique à la semaine précédente." : `${sign}${points(Math.abs(delta))}${comparison.previous > 0 ? ` (${sign}${Math.round((Math.abs(delta) / comparison.previous) * 100)} %)` : ""} par rapport à la semaine précédente.`)],
    h("p", { class: "muted" }, note));
}

const JOURNAL_FIRST = 14;
const JOURNAL_STEP = 30;

function journalRow(summary) {
  const date = insights.dateFromStamp(summary.day);
  return h("div", { class: "day-row" },
    h("span", { class: "name" + (insights.isReliable(summary) ? "" : " partial") }, date ? dayLabel(date) : summary.day),
    h("span", null, `${points(summary.weeklyUsed)} de semaine · ${points(summary.sessionUsed)} de session`),
    h("span", null), h("span", { class: "meta" }, `Pic ${Math.round(summary.peakSession)} % · actif à ${hoursText(summary.activeHours)} · ${percent(Math.min(summary.samples / 1440, 1))} enregistré`));
}

/** Le journal, du plus récent au plus ancien : 14 jours d'abord, puis « Afficher plus » par tranches de 30 (jusqu'à 120 jours, la page resterait interminable sinon). */
function journal(summaries) {
  const newestFirst = [...summaries].reverse();
  let shown = JOURNAL_FIRST;
  const list = h("div", null);
  const more = h("button", { class: "btn", type: "button" });
  const fill = () => {
    list.replaceChildren(...newestFirst.slice(0, shown).map(journalRow));
    const rest = newestFirst.length - shown;
    more.hidden = rest <= 0;
    more.textContent = `Afficher plus (${rest} jour${rest > 1 ? "s" : ""} restant${rest > 1 ? "s" : ""})`;
  };
  more.addEventListener("click", () => { shown += JOURNAL_STEP; fill(); });
  fill();
  return h("section", { class: "card" }, h("details", { class: "journal" }, h("summary", null, `Journal complet (${plural(summaries.length, "jour")})`), list, more));
}

export function statsView(state) {
  const summaries = state.snapshot.daily;
  const now = new Date(state.now);
  if (summaries.length === 0) {
    return [h("section", { class: "card" }, h("h2", null, "Ton rythme"), h("p", { class: "muted" }, "Aucune journée enregistrée pour l'instant. Laisse l'app Mac ouverte : une ligne s'ajoute chaque jour."))];
  }
  const confidence = insights.confidence(summaries);
  const average = insights.averagePerDay(summaries, 14, now);
  const hours = insights.hourStats(summaries, 28, now);
  const peak = insights.peakHour(hours);
  const busiest = insights.busiestDay(summaries);
  const today = insights.recentDays(summaries, 1, now)[0].summary;
  const first = insights.dateFromStamp(summaries[0].day);
  return [
    h("section", { class: "card" },
      h("h2", null, "Ton rythme"),
      h("p", { class: "confidence" }, h("span", { class: "meter", "aria-hidden": "true" }, [1, 2, 3, 4].map((level) => h("span", { class: level <= confidence.level ? "on" : "" }))), h("span", null, `Fiabilité : ${confidence.label}`)),
      h("p", { class: "muted" }, confidence.detail),
      first ? h("p", { class: "muted" }, `${plural(summaries.length, "jour")} enregistré${summaries.length > 1 ? "s" : ""} depuis le ${dayLabel(first)}.`) : null),
    h("div", { class: "kpis" },
      kpi("Aujourd'hui", today ? points(today.weeklyUsed) : "—", average ? `moyenne ${points(average.value)}` : "en cours"),
      kpi("Moyenne par jour", average ? points(average.value) : "—", average ? `sur ${plural(average.days, "jour")} complet${average.days > 1 ? "s" : ""}` : "pas encore de jour complet"),
      kpi("Jour record", busiest ? points(busiest.weeklyUsed) : "—", busiest ? dayLabel(insights.dateFromStamp(busiest.day)) : "—"),
      kpi("Heure de pointe", peak ? hourLabel(peak.hour) : "—", peak ? `active ${percent(peak.fraction)} des jours` : "pas encore de jour complet")),
    card("Les 14 derniers jours", "Points de ta limite hebdomadaire consommés chaque jour (1 pt = 1 % de la limite).", ...dayChart(insights.recentDays(summaries, 14, now), average)),
    card("Quand tu travailles", `Part des jours où ton usage a augmenté à chaque heure, sur les 28 derniers jours complets.${hours[0].totalDays > 0 && hours[0].totalDays < insights.INDICATIVE_BELOW ? ` Indicatif : ${hours[0].totalDays} jour(s) seulement.` : ""}`, ...hourChart(hours, peak)),
    card("Par jour de la semaine", "Consommation moyenne de chaque jour. Elle devient fiable à partir de 3 jours identiques observés.", ...weekdayChart(insights.weekdayStats(summaries, now))),
    weekCard(insights.weekComparison(summaries, now)),
    journal(summaries),
  ];
}
