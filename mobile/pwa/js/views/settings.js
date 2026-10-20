// Écran Réglages : l'état de la synchro, le thème, l'installation et l'oubli de l'appareil.
import { h } from "../dom.js";
import { age, clock } from "../../lib/format.js";

const field = (key, value) => h("div", { class: "field" }, h("span", { class: "k" }, key), h("span", { class: "v" }, value));

export function settingsView(state, actions) {
  const { snapshot, pairing, prefs, checkedAt, now, status, message } = state;
  const themes = [["dark", "Sombre"], ["light", "Clair"], ["auto", "Auto"]];
  const syncLabel = status === "error" ? "Échec, nouvel essai automatique" : status === "invalid" ? "Données illisibles" : status === "empty" ? "En attente du Mac" : "Active";
  return [
    h("section", { class: "card" },
      h("h2", null, "Synchronisation"),
      message ? h("p", { class: "notice" + (status === "invalid" || status === "error" ? " error" : "") }, message) : null,
      field("État", syncLabel),
      field("Dernière vérification", checkedAt ? `${age(now - checkedAt)} (${clock(new Date(checkedAt))})` : "jamais"),
      snapshot ? field("Dernières données du Mac", `${age(now - snapshot.dataAt)} · ${snapshot.source}`) : null,
      snapshot ? field("Version du Mac", snapshot.appVersion || "inconnue") : null,
      field("Appareil", pairing ? `…${pairing.id.slice(-6)}` : "non associé"),
      h("button", { class: "btn", onclick: actions.refresh }, "Actualiser maintenant")),
    h("section", { class: "card" },
      h("h2", null, "Apparence"),
      h("div", { class: "seg", role: "group", "aria-label": "Thème" },
        themes.map(([value, label]) => h("button", { "aria-pressed": String(prefs.theme === value), onclick: () => actions.setTheme(value) }, label)))),
    h("section", { class: "card" },
      h("h2", null, "Application"),
      state.installable ? h("button", { class: "btn primary", onclick: actions.install }, "Installer sur l'écran d'accueil")
        : h("p", { class: "muted" }, "Pour l'installer : menu ⋮ du navigateur (Chrome, Firefox…), puis « Installer » ou « Ajouter à l'écran d'accueil »."),
      h("p", { class: "muted" }, "Les données sont chiffrées de bout en bout : le relais ne voit jamais ton usage, seule la clé de ce téléphone les déchiffre.")),
    h("section", { class: "card" },
      h("h2", null, "Oublier cet appareil"),
      h("p", { class: "muted" }, "Efface la clé et les données de ce téléphone. Pour le réassocier, il faudra rescanner le code du Mac."),
      h("button", { class: "btn danger", onclick: actions.forget }, "Oublier cet appareil")),
  ];
}
