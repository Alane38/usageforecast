// Informations avancées de l'accueil : courbe de la semaine, détail par modèle, utilisation payante.
import { h, setWidth } from "../dom.js";
import { lineChart } from "../charts.js";
import { duration } from "../../lib/format.js";

const percentOf = (value) => Math.round(value);
const DAY_MS = 24 * 3600000;
const WEEK_TICKS = [[168, "−7 j"], [120, "−5 j"], [72, "−3 j"], [0, "maintenant"]];
const when = new Intl.DateTimeFormat("fr-FR", { weekday: "short", hour: "numeric" });

export function weekHistoryCard(snapshot, now) {
  const points = snapshot.weekHistory.map((point) => ({ t: point.t, value: point.w }));
  if (points.length < 10) return null;
  const spanMs = Math.min(Math.max(now - points[0].t, 6 * 3600000), 7 * DAY_MS);
  const readout = h("p", { class: "readout", "aria-live": "polite", "data-hint": "Touche la courbe pour voir une valeur." });
  const chart = lineChart({
    points, spanMs, now, ticks: WEEK_TICKS, maxGapMs: 3 * 3600000, ariaLabel: "Courbe de la semaine sur 7 jours",
    onCursor: (point) => readout.replaceChildren(`${when.format(point.t)} · ${percentOf(point.value)} %`),
  });
  const today = snapshot.usedTodayPercent;
  return h("section", { class: "card", "aria-label": "Historique de la semaine" },
    h("h2", null, `Historique de la semaine · ${duration(spanMs / 1000)}`), chart, readout,
    today !== null ? h("p", { class: "muted" }, `Aujourd'hui : +${percentOf(today)} % de la semaine`) : null);
}

function shareRow(label, text, fraction) {
  const fill = h("span", { class: "fill" });
  if (fraction !== null) setWidth(fill, Math.min(fraction, 1) * 100);
  return h("div", { class: "share" },
    h("div", { class: "row" }, h("span", null, label), h("span", { class: "muted" }, text)),
    fraction !== null ? h("div", { class: "bar", role: "img", "aria-label": `${label} : ${text}` }, fill) : null);
}

export function modelsCard(models) {
  if (!models.length) return null;
  return h("section", { class: "card tone-accent", "aria-label": "Par modèle" },
    h("h2", null, "Par modèle · semaine"),
    ...models.map((model) => shareRow(model.name, `${percentOf(model.percent)} %`, model.percent / 100)));
}

export function extrasCard(extras) {
  if (!extras.length) return null;
  return h("section", { class: "card tone-accent", "aria-label": "Utilisation supplémentaire" },
    h("h2", null, "Compte"),
    ...extras.map((line) => shareRow(line.label, line.text, line.fraction)));
}
