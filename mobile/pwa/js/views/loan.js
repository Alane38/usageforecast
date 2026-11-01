// Onglet « Prêt » du propriétaire : le prêt en cours (calculé par le Mac), sa création avec un code d'invitation, sa fin.
import { h, setLeft, setWidth } from "../dom.js";
import { age, moment, points } from "../../lib/format.js";
import { formatCode } from "../../lib/loan.js";

const field = (key, value) => h("div", { class: "field" }, h("span", { class: "k" }, key), h("span", { class: "v" }, value));

function shareBar(loan) {
  const guest = h("span", { class: "fill seg-guest" }), owner = h("span", { class: "fill seg-owner" }), limit = h("span", { class: "tick" });
  setWidth(guest, Math.min(loan.guestUsed, 100));
  setLeft(owner, loan.sharePoints);
  setWidth(owner, Math.min(loan.ownerUsed, loan.reservePoints));
  setLeft(limit, loan.sharePoints);
  return h("div", { class: "bar split", role: "img", "aria-label": `${loan.guestName} ${points(loan.guestUsed)} sur ${points(loan.sharePoints)}, toi ${points(loan.ownerUsed)} sur ${points(loan.reservePoints)}` }, guest, owner, limit);
}

function forecast(loan, now) {
  const over = loan.guestUsed - loan.sharePoints;
  if (over > 0) return h("p", { class: "chip tone-danger" }, `Part dépassée de ${points(over)} : c'est ta réserve qui paie.`);
  if (loan.guestExhaustsAt && loan.guestRatePerDay !== null) {
    return h("p", { class: "chip tone-warning" }, `Au rythme de ${loan.guestName} (≈ ${points(loan.guestRatePerDay)} par jour), sa part est épuisée ${moment(loan.guestExhaustsAt, now)}, avant la fin du prêt.`);
  }
  return h("p", { class: "chip tone-ok" }, "Sa part tient jusqu'à la fin du prêt au rythme actuel.");
}

function currentCard(loan, now, pending, actions) {
  return [
    h("section", { class: "card", "aria-label": "Prêt en cours" },
      h("div", { class: "row" }, h("h2", null, `Prêt à ${loan.guestName}`), h("span", { class: "muted" }, loan.active ? `jusqu'à ${moment(loan.endsAt, now)}` : "terminé")),
      shareBar(loan),
      h("div", { class: "legend" }, h("span", null, `${loan.guestName} ${points(loan.guestUsed)} / ${points(loan.sharePoints)}`), h("span", { class: "owner" }, `toi ${points(loan.ownerUsed)} / ${points(loan.reservePoints)}`)),
      forecast(loan, now),
      field("Attribution", `${points(loan.guestMeasured)} mesurés · ${points(loan.guestEstimated)} estimés`),
      field("Collecteur", loan.collectorAt ? `${loan.collectorPlatform ?? "?"}, ${age(now - loan.collectorAt)}` : "pas encore entendu"),
      loan.status ? h("p", { class: "notice" }, loan.status) : null),
    h("section", { class: "card" },
      h("h2", null, "Terminer le prêt"),
      h("p", { class: "muted" }, "Retire d'abord son accès : claude.ai › Settings › Claude Code, corbeille à côté de sa connexion (sinon Settings › Account). « Log Out » dans Settings › Account déconnecte tout."),
      pending?.action === "end" ? h("p", { class: "notice" }, "Fin demandée : ton Mac l'applique dans les 5 minutes.")
        : h("button", { class: "btn danger", onclick: actions.endLoan }, "Terminer le prêt")),
  ];
}

function codeCard(pending, now) {
  const expiresAt = new Date(pending.expiresAt);
  const expired = expiresAt <= now;
  const share = async () => {
    const text = `Code UsageForecast : ${formatCode(pending.code)} (valable 15 min). Sur ton PC : collecteur associer ${location.origin} ${formatCode(pending.code)}`;
    try { await navigator.share({ text }); } catch { try { await navigator.clipboard.writeText(text); } catch { /* rien */ } }
  };
  return h("section", { class: "card code-card", "aria-label": "Code d'invitation" },
    h("h2", null, `Code pour ${pending.guestName}`),
    h("p", { class: "invite-code" }, formatCode(pending.code)),
    h("p", { class: "muted" }, expired ? "Code expiré : s'il n'a pas servi, crée un nouveau prêt." : `Valable jusqu'à ${moment(expiresAt, now)}, une seule fois. Sur son ordinateur : « collecteur associer ${location.origin} ${formatCode(pending.code)} ».`),
    expired ? null : h("button", { class: "btn primary", onclick: share }, "Partager le code"),
    h("p", { class: "muted" }, "Ton Mac reçoit le prêt dans les 5 minutes et commence le suivi."));
}

function creationCard(snapshot, actions, message) {
  const name = h("input", { class: "link", type: "text", id: "loan-name", autocomplete: "off", placeholder: "Prénom" });
  const share = h("input", { type: "range", id: "loan-share", min: "10", max: "90", step: "5", value: "70" });
  const shareText = h("strong", null, "70 %");
  const keep = h("span", null, "30 %");
  share.addEventListener("input", () => { shareText.textContent = `${share.value} %`; keep.textContent = `${100 - Number(share.value)} %`; });
  const end = snapshot?.weekly?.resetsAt ?? new Date(Date.now() + 7 * 86400000);
  const local = new Date(end.getTime() - end.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  const endInput = h("input", { class: "link", type: "datetime-local", id: "loan-end", value: local });
  const submit = (event) => actions.createLoan({ guestName: name.value, share: Number(share.value) / 100, endsAt: new Date(endInput.value), button: event.currentTarget });
  return h("section", { class: "card stack", "aria-label": "Prêter une part de ta semaine" },
    h("h2", null, "Prêter une part de ta semaine"),
    h("label", { for: "loan-name", class: "muted" }, "Prénom de la personne"), name,
    h("div", { class: "row" }, h("label", { for: "loan-share", class: "muted" }, "Sa part de la semaine"), shareText), share,
    h("p", { class: "muted" }, "Tu gardes ", keep, " de la limite hebdomadaire. La limite de 5 h n'est pas partagée."),
    h("label", { for: "loan-end", class: "muted" }, "Fin du prêt (par défaut : le prochain reset)"), endInput,
    message ? h("p", { class: "notice error", role: "alert" }, message) : null,
    h("button", { class: "btn primary", onclick: submit }, "Créer le code d'invitation"));
}

export function loanView(state, actions) {
  const { snapshot, loanPending: pending, loanMessage, now } = state;
  const loan = snapshot?.loan ?? null;
  const nodes = [];
  if (pending?.action === "create" && loan?.lastCommandID !== pending.commandID) nodes.push(codeCard(pending, new Date(now)));
  if (loan) nodes.push(...currentCard(loan, new Date(now), pending, actions));
  else if (!pending) nodes.push(creationCard(snapshot, actions, loanMessage));
  nodes.push(h("section", { class: "card" },
    h("h2", null, "Comment c'est compté"),
    h("p", { class: "muted" }, "Ton Mac attribue chaque hausse de la semaine à celui qui utilisait Claude Code à ce moment (mesuré) ; aux deux en même temps, au prorata des tokens ; à personne, à l'invité (estimé). Le collecteur de l'invité n'envoie que des heures et des nombres de tokens, chiffrés.")));
  return nodes;
}
