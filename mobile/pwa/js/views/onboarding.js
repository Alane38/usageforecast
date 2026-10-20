// Premier lancement : expliquer l'appairage et accepter un lien collé. Un lien ouvert depuis le QR code est pris en charge par app.js.
import { h } from "../dom.js";

export function onboardingView(state, actions) {
  const input = h("input", { class: "link", type: "text", inputmode: "url", autocomplete: "off", autocapitalize: "off", spellcheck: "false", placeholder: "Colle ici le lien du Mac", "aria-label": "Lien d'appairage" });
  const error = h("p", { class: "notice error", hidden: true, role: "alert" });
  const submit = () => {
    const result = actions.pair(input.value);
    error.hidden = result.ok;
    error.textContent = result.ok ? "" : result.message;
  };
  return [
    h("section", { class: "card empty" },
      h("h2", null, "Surveille Claude depuis ton téléphone"),
      h("p", { class: "muted" }, "Ton usage, tes prévisions et tes statistiques, chiffrés de bout en bout entre ton Mac et ce téléphone.")),
    h("section", { class: "card" },
      h("h2", null, "Associer ce téléphone"),
      h("ol", { class: "steps" },
        h("li", null, "Sur ton Mac, ouvre UsageForecast > Réglages > Mobile et active la synchro."),
        h("li", null, "Scanne le code avec l'appareil photo du téléphone : cette page s'ouvre déjà associée."),
        h("li", null, "Sans caméra ? Copie le lien affiché sur le Mac et colle-le ci-dessous.")),
      h("div", { class: "stack" }, input, h("button", { class: "btn primary", onclick: submit }, "Associer"), error)),
    state.message ? h("p", { class: "notice error" }, state.message) : null,
  ];
}
