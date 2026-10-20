// Écran d'accueil : ce qui compte maintenant, du plus urgent au plus détaillé.
import { h, icon, setLeft, setWidth } from "../dom.js";
import { lineChart } from "../charts.js";
import { attention } from "../../lib/attention.js";
import { age, budgetLine, countdown, duration, isStale, paceChip, recentLine, tone } from "../../lib/format.js";

const percentOf = (value) => Math.round(value);

function gaugeCard(title, window, { now, stale, showPerDay }) {
  if (!window) return h("section", { class: "card" }, h("h2", null, title), h("p", { class: "muted" }, "Pas de donnée pour l'instant."));
  const toneName = tone(window.percent, window.pace, stale);
  const veil = h("span", { class: "veil" });
  const fill = h("span", { class: "fill" });
  const tick = h("span", { class: "tick" });
  setWidth(veil, window.projectedPercent ?? 0);
  setWidth(fill, window.percent);
  if (window.expectedPercent !== null) setLeft(tick, window.expectedPercent);
  else tick.hidden = true;
  const bar = h("div", {
    class: "bar", role: "img",
    "aria-label": `${percentOf(window.percent)} % utilisé${window.projectedPercent !== null ? `, ${percentOf(window.projectedPercent)} % prévu au reset` : ""}${window.expectedPercent !== null ? `, ${percentOf(window.expectedPercent)} % à rythme régulier` : ""}`,
  }, veil, fill, tick);

  const chip = paceChip(window.percent, window.pace);
  const summary = [window.projectedPercent !== null ? `≈ ${percentOf(window.projectedPercent)} % au reset` : null,
    showPerDay && window.perDayPercent !== null && window.percent < 100 ? `${percentOf(window.perDayPercent)} % par jour` : null].filter(Boolean).join(" · ");
  const recent = recentLine(window);
  return h("section", { class: `card tone-${toneName}`, "aria-label": title },
    h("div", { class: "row" }, h("h2", null, title), window.resetsAt ? h("span", { class: "muted" }, `reset dans ${countdown(window.resetsAt - now)}`) : null),
    h("div", null, h("span", { class: "big" }, String(percentOf(window.percent))), h("span", { class: "unit" }, "%")),
    bar,
    chip ? h("p", { class: "chip" }, chip) : null,
    summary ? h("p", { class: "muted" }, summary) : null,
    recent ? h("p", { class: "muted" }, recent) : null);
}

function budgetCard(budget) {
  if (!budget) return null;
  const toneName = budget.level === "over" ? "danger" : budget.level === "close" ? "warning" : "ok";
  const fill = h("span", { class: "fill" });
  setWidth(fill, budget.allowed > 0 ? (Math.min(budget.used / budget.allowed, 1)) * 100 : 100);
  return h("section", { class: `card tone-${toneName}`, "aria-label": "Budget du jour" },
    h("h2", null, "Budget d'aujourd'hui"),
    h("div", null, h("span", { class: "big" }, String(percentOf(budget.allowed))), h("span", { class: "unit" }, "%")),
    h("p", { class: "muted" }, "à ne pas dépasser aujourd'hui"),
    h("div", { class: "bar", role: "img", "aria-label": budgetLine(budget) }, fill),
    h("p", { class: "chip" }, budgetLine(budget)),
    budget.level === "over" ? h("p", { class: "muted" }, "Les jours suivants auront d'autant moins.") : null);
}

function creditsCard(credits) {
  if (!credits) return null;
  const fill = h("span", { class: "fill" });
  setWidth(fill, credits.usedFraction * 100);
  return h("section", { class: "card tone-accent", "aria-label": credits.title },
    h("h2", null, credits.title),
    h("div", null, h("span", { class: "big nowrap" }, credits.value)),
    h("div", { class: "bar", role: "img", "aria-label": `${percentOf(credits.usedFraction * 100)} % consommé` }, fill),
    credits.detail ? h("p", { class: "muted" }, credits.detail) : null);
}

function historyCard(snapshot, now) {
  const points = snapshot.history.filter((point) => point.s !== null).map((point) => ({ t: point.t, value: point.s }));
  if (points.length < 10) return null;
  const spanMs = Math.min(Math.max(now - points[0].t, 10 * 60000), 24 * 3600000);
  const readout = h("p", { class: "readout", "aria-live": "polite", "data-hint": "Touche la courbe pour voir une valeur." });
  const chart = lineChart({
    points, spanMs, now,
    onCursor: (point) => readout.replaceChildren(`${new Date(point.t).getHours()} h ${String(new Date(point.t).getMinutes()).padStart(2, "0")} · ${percentOf(point.value)} %`),
  });
  return h("section", { class: "card", "aria-label": "Historique de la session" },
    h("h2", null, `Historique de la session · ${duration(spanMs / 1000)}`), chart, readout);
}

export function homeView(state) {
  const snapshot = state.snapshot;
  const now = state.now;
  const stale = isStale(now - snapshot.dataAt);
  const alerts = attention(snapshot, now);
  const services = snapshot.servicesOK === null ? "État des services inconnu" : snapshot.servicesOK ? "Tous les services Claude fonctionnent" : "Un service Claude signale un incident";
  return [
    alerts.length > 0 ? h("section", { class: "card", "aria-label": "À surveiller", role: "status" },
      h("h2", null, "À surveiller"),
      h("ul", { class: "attention" }, alerts.map((alert) => h("li", { class: alert.level }, icon(alert.level), h("span", null, alert.text))))) : null,
    gaugeCard("Session · 5 h", snapshot.session, { now, stale, showPerDay: false }),
    gaugeCard("Semaine · 7 j", snapshot.weekly, { now, stale, showPerDay: snapshot.dayBudget === null }),
    budgetCard(snapshot.dayBudget),
    creditsCard(snapshot.credits),
    historyCard(snapshot, now),
    h("section", { class: "card" },
      h("p", { class: "chip tone-" + (snapshot.servicesOK === false ? "warning" : "ok") }, services),
      h("p", { class: "muted" }, `Données du Mac : ${age(now - snapshot.dataAt)} · ${snapshot.source}`),
      snapshot.line ? h("p", { class: "muted" }, snapshot.line) : null),
  ];
}
