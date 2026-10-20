// Les points d'attention de l'écran d'accueil : ce qui mérite d'être lu en premier, du plus grave au moins grave.
import { clock, countdown, age, isStale } from "./format.js";

const SEVERITY = { danger: 0, warning: 1, info: 2 };

function windowAlerts(label, window, now, alerts) {
  if (!window) return;
  const reset = window.resetsAt ? ` : reset dans ${countdown(window.resetsAt - now)}` : "";
  if (window.percent >= 100) alerts.push({ level: "danger", text: `${label} : limite atteinte${reset}` });
  else if (window.percent >= 90) alerts.push({ level: "danger", text: `${label} à ${Math.round(window.percent)} %${reset}` });
  else if (window.exhaustsAt && window.exhaustsAt > now) alerts.push({ level: "warning", text: `${label} : à ce rythme, 100 % vers ${clock(window.exhaustsAt)}` });
}

/** @returns {{level: "danger"|"warning"|"info", text: string}[]} */
export function attention(snapshot, now = new Date()) {
  const alerts = [];
  windowAlerts("Session", snapshot.session, now, alerts);
  windowAlerts("Semaine", snapshot.weekly, now, alerts);

  const budget = snapshot.dayBudget;
  if (budget?.level === "over") alerts.push({ level: "warning", text: `Budget du jour dépassé de ${Math.round(budget.used - budget.allowed)} % : les jours suivants auront d'autant moins` });
  else if (budget?.level === "close") alerts.push({ level: "info", text: `Budget du jour presque atteint (${Math.round(budget.used)} % sur ${Math.round(budget.allowed)} %)` });

  const expiry = snapshot.credits?.detail.match(/Expirent dans (\d+) j/);
  if (expiry && Number(expiry[1]) <= 5) alerts.push({ level: "warning", text: `Crédits API : expirent dans ${expiry[1]} j (${snapshot.credits.value})` });

  if (snapshot.servicesOK === false) alerts.push({ level: "warning", text: "Un service Claude signale un incident" });

  const dataAge = now - snapshot.dataAt;
  if (isStale(dataAge)) alerts.push({ level: "info", text: `Données du Mac anciennes (${age(dataAge)}) : le Mac est peut-être en veille` });

  return alerts.sort((a, b) => SEVERITY[a.level] - SEVERITY[b.level]);
}
