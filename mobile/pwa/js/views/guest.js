// Vue de l'invité d'un prêt : sa part de la semaine, ce qu'il lui reste, le rythme conseillé, la réserve du propriétaire et ses jours.
import { h, setWidth } from "../dom.js";
import { age, moment, points } from "../../lib/format.js";
import { guestBudget } from "../../lib/loan-view.js";

const DAY_NAMES = ["dim", "lun", "mar", "mer", "jeu", "ven", "sam"];

function daysCard(view) {
  if (!view.days.length) return null;
  const biggest = Math.max(...view.days.map((day) => day.points), 1);
  const rows = view.days.map((day) => {
    const date = new Date(`${day.day}T12:00:00`);
    const fill = h("span", { class: "fill" });
    setWidth(fill, 100);
    const track = h("span", { class: "plan-track" }, fill);
    setWidth(track, (day.points / biggest) * 100);
    return h("div", { class: "plan-row" },
      h("span", { class: "plan-day" }, DAY_NAMES[date.getDay()] ?? day.day),
      h("div", { class: "bar plan-bar", role: "img", "aria-label": `${day.day} : ${points(day.points)}` }, track),
      h("span", { class: "plan-pct" }, points(day.points)));
  });
  return h("section", { class: "card tone-accent", "aria-label": "Tes jours" }, h("h2", null, "Tes jours"), h("p", { class: "muted" }, "Points de la semaine utilisés chaque jour."), ...rows);
}

export function guestView(state) {
  const view = state.snapshot;
  const now = new Date(state.now);
  const budget = guestBudget(view, now);
  const used = view.sharePoints > 0 ? (view.guestUsed / view.sharePoints) * 100 : 100;
  const toneName = budget.over > 0 ? "danger" : used >= 80 || view.guestExhaustsAt ? "warning" : "ok";
  const fill = h("span", { class: "fill" });
  setWidth(fill, used);
  const status = budget.over > 0 ? `Part dépassée de ${points(budget.over)} : tu utilises la réserve du propriétaire du compte.`
    : view.guestExhaustsAt && view.guestRatePerDay !== null ? `À ton rythme (≈ ${points(view.guestRatePerDay)} par jour), ta part est épuisée ${moment(view.guestExhaustsAt, now)}, avant la fin du prêt.`
      : view.guestUsed === 0 ? "Rien d'utilisé pour l'instant." : "Ta part tient jusqu'à la fin du prêt à ton rythme actuel.";
  if (!view.active) {
    return [h("section", { class: "card empty" }, h("h2", null, "Prêt terminé"),
      h("p", { class: "muted" }, `Le prêt s'est terminé (${moment(view.endsAt, now)}). Tu as utilisé ${points(view.guestUsed)} sur ${points(view.sharePoints)}.`))];
  }
  return [
    h("section", { class: `card tone-${toneName}`, "aria-label": "Ta part" },
      h("div", { class: "row" }, h("h2", null, `Ta part : ${Math.round(view.sharePoints)} % de la semaine`), h("span", { class: "muted" }, `jusqu'à ${moment(view.endsAt, now)}`)),
      h("div", null, h("span", { class: "big" }, String(Math.round(view.guestUsed))), h("span", { class: "unit" }, `/ ${Math.round(view.sharePoints)}`)),
      h("div", { class: "bar", role: "img", "aria-label": `${points(view.guestUsed)} utilisés sur ${points(view.sharePoints)}` }, fill),
      h("p", { class: "chip" }, status)),
    h("div", { class: "kpis" },
      h("div", { class: "kpi" }, h("span", { class: "label" }, "Il te reste"), h("span", { class: "value" }, points(budget.left)), h("span", { class: "detail" }, "de ta part")),
      h("div", { class: "kpi" }, h("span", { class: "label" }, "Pour tenir jusqu'à la fin"), h("span", { class: "value" }, budget.left === 0 || budget.perDay === null ? "—" : `${points(budget.perDay)}/j`), h("span", { class: "detail" }, budget.left === 0 ? "part épuisée" : "rythme conseillé"))),
    view.reserveLeft !== null ? h("section", { class: "card" }, h("div", { class: "row" }, h("h2", null, "Réserve du propriétaire"), h("span", null, points(view.reserveLeft))),
      h("p", { class: "muted" }, "À ne pas toucher : c'est la part que le propriétaire du compte garde.")) : null,
    daysCard(view),
    h("section", { class: "card" },
      h("p", { class: "muted" }, `${points(view.guestMeasured)} mesurés, ${points(view.guestEstimated)} estimés. Calculé par le Mac du propriétaire ${age(now - view.updatedAt)}.`),
      h("p", { class: "muted" }, "Mesuré : seul ton Claude Code tournait. Estimé : vous travailliez tous les deux, ou personne d'identifié.")),
  ];
}
