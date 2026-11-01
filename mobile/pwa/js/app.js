// Chef d'orchestre : appairage, synchronisation périodique, thème, installation, rendu des trois écrans.
import { watchForNewVersion } from "../lib/update-watch.js";
import { enablePullToRefresh } from "./pull-to-refresh.js";
import { h, icon } from "./dom.js";
import { parsePairing } from "../lib/crypto.js";
import { createStore } from "../lib/store.js";
import { normalize } from "../lib/snapshot.js";
import { nextDelaySeconds, pull } from "../lib/sync.js";
import { age, isStale } from "../lib/format.js";
import { homeView } from "./views/home.js";
import { statsView } from "./views/stats.js";
import { settingsView } from "./views/settings.js";
import { onboardingView } from "./views/onboarding.js";
import { loanView } from "./views/loan.js";
import { guestView } from "./views/guest.js";
import { createLoan as sendLoan, endLoan as sendEnd, pendingSettled } from "../lib/loan-actions.js";

const store = createStore();
const state = { pairing: store.pairing(), prefs: store.prefs(), loanPending: store.loanPending(), loanMessage: "", snapshot: null, checkedAt: null, stamp: null, status: "loading", message: "", tab: "home", now: Date.now(), installable: false, refreshing: false };
let installEvent = null;
let failures = 0;
let timer = null;

const root = document.getElementById("app");
const syncChip = document.getElementById("sync");
const refreshButton = document.getElementById("refresh");
const themeButton = document.getElementById("theme");
const nav = document.getElementById("nav");

function loadCached() {
  const cached = store.snapshot();
  if (!cached?.raw) return;
  state.snapshot = normalize(cached.raw);
  state.checkedAt = cached.checkedAt ?? null;
  state.stamp = cached.stamp ?? null;
  if (state.snapshot) state.status = "cached";
}

function applyTheme() {
  const theme = state.prefs.theme;
  // Sombre par défaut : pas d'attribut. « light » force le clair, « auto » suit le téléphone (voir css/base.css).
  if (theme === "light" || theme === "auto") document.documentElement.dataset.theme = theme;
  else delete document.documentElement.dataset.theme;
  const light = theme === "light" || (theme === "auto" && matchMedia("(prefers-color-scheme: light)").matches);
  document.querySelector('meta[name="theme-color"]')?.setAttribute("content", light ? "#f3f3f5" : "#101012");   // barre d'état du navigateur
}

/** Vrai si l'affichage est clair en ce moment (choix « clair », ou « auto » avec un téléphone en mode clair). */
function isLightNow() {
  const theme = state.prefs.theme;
  return theme === "light" || (theme === "auto" && matchMedia("(prefers-color-scheme: light)").matches);
}

function renderThemeButton() {
  const light = isLightNow();
  themeButton.replaceChildren(icon(light ? "moon" : "sun"));
  themeButton.setAttribute("aria-label", light ? "Passer au thème sombre" : "Passer au thème clair");
}

function renderChrome() {
  renderThemeButton();
  const paired = Boolean(state.pairing);
  nav.hidden = !paired;
  refreshButton.hidden = !paired;
  refreshButton.classList.toggle("spin", state.refreshing);
  syncChip.replaceChildren();
  if (!paired) return;
  const offline = state.status === "error";
  const stale = state.snapshot ? isStale(state.now - state.snapshot.dataAt) : false;
  const label = !state.snapshot ? (state.status === "loading" ? "Chargement…" : "Aucune donnée")
    : offline ? `Hors ligne · ${age(state.now - state.snapshot.dataAt)}` : stale ? `Données anciennes · ${age(state.now - state.snapshot.dataAt)}` : `À jour · ${age(state.now - state.snapshot.dataAt)}`;
  syncChip.append(h("span", { class: "dot" + (offline ? " error" : stale ? " stale" : "") }), label);
  // Un invité ne voit que sa part : ni les statistiques du propriétaire, ni l'onglet Prêt.
  const guest = state.snapshot?.kind === "guest";
  for (const button of nav.querySelectorAll("button")) {
    button.setAttribute("aria-current", button.dataset.tab === state.tab ? "page" : "false");
    button.hidden = guest && (button.dataset.tab === "stats" || button.dataset.tab === "loan");
  }
}

function buildScreen(actions) {
  if (!state.pairing) return onboardingView(state, actions);
  if (state.tab === "settings") return settingsView(state, actions);
  if (!state.snapshot) {
    return [h("section", { class: "card empty" }, h("h2", null, state.status === "loading" ? "Chargement…" : "En attente du Mac"),
      h("p", { class: "muted" }, state.message || "Les données arrivent dès que ton Mac les envoie."))];
  }
  if (state.snapshot.kind === "guest") return guestView(state);
  if (state.tab === "loan") return loanView(state, actions);
  return (state.tab === "stats" ? statsView : homeView)(state);
}

function render() {
  state.now = Date.now();
  renderChrome();
  const actions = { refresh, forget, setTheme, install, pair, createLoan, endLoan };
  let nodes;
  try {
    nodes = buildScreen(actions);
  } catch (error) {
    // Une erreur d'affichage ne doit jamais laisser un écran figé ou vide : on le dit, et on garde la navigation.
    console.error(error);
    nodes = [h("section", { class: "card" }, h("h2", null, "Affichage impossible"),
      h("p", { class: "notice error" }, `Cet écran n'a pas pu s'afficher (${error.message}). Recharge l'application ; si ça persiste, mets-la à jour.`))];
  }
  const showNotice = state.pairing && state.tab !== "settings" && state.message && state.snapshot;
  const notice = showNotice ? h("p", { class: "notice" + (state.status === "invalid" ? " error" : "") }, state.message) : null;
  root.replaceChildren(...[notice, ...nodes].filter(Boolean));
}

function showUpdateBanner() {
  if (document.getElementById("update-banner")) return;
  const banner = h("button", { id: "update-banner", class: "update-banner", onclick: () => location.reload() },
    "Nouvelle version disponible · toucher pour actualiser");
  document.body.prepend(banner);
}

async function refresh() {
  if (!state.pairing || state.refreshing) return;
  state.refreshing = true;
  renderChrome();
  const result = await pull({ pairing: state.pairing, previousStamp: state.stamp });
  state.refreshing = false;
  state.checkedAt = Date.now();
  state.status = result.status;
  state.message = result.message ?? "";
  if (result.status === "updated") {
    state.snapshot = result.snapshot;
    if (state.loanPending && pendingSettled(state.loanPending, result.snapshot.loan)) setLoanPending(null);
    state.stamp = result.stamp;
    store.saveSnapshot({ raw: result.raw, stamp: result.stamp, checkedAt: state.checkedAt });
    failures = 0;
  } else if (result.status === "unchanged" || result.status === "empty") {
    failures = 0;
  } else {
    failures += 1;
  }
  render();
  schedule();
}

function schedule() {
  clearTimeout(timer);
  if (document.visibilityState !== "visible" || !state.pairing) return;
  timer = setTimeout(refresh, nextDelaySeconds(failures) * 1000);
}

function pair(input) {
  const pairing = parsePairing(input);
  if (!pairing) return { ok: false, message: "Ce lien n'est pas valide. Copie-le en entier depuis les Réglages du Mac." };
  store.savePairing(pairing);
  state.pairing = pairing;
  state.snapshot = null;
  state.stamp = null;
  state.status = "loading";
  state.message = "";
  state.tab = "home";
  render();
  refresh();
  return { ok: true };
}

function setLoanPending(pending) {
  state.loanPending = pending;
  store.saveLoanPending(pending);
}

async function createLoan({ guestName, share, endsAt, button }) {
  button.disabled = true;
  button.textContent = "Création du code…";
  const result = await sendLoan({ pairing: state.pairing, guestName, share, endsAt });
  state.loanMessage = result.error ?? "";
  if (result.ok) setLoanPending(result.pending);
  render();
}

async function endLoan() {
  if (!confirm("Terminer le prêt ? As-tu retiré son accès sur claude.ai (Settings › Claude Code) ?")) return;
  const result = await sendEnd({ pairing: state.pairing });
  state.loanMessage = result.error ?? "";
  if (result.ok) setLoanPending(result.pending);
  render();
}

function forget() {
  if (!confirm("Oublier cet appareil ? Il faudra rescanner le code du Mac.")) return;
  store.forget();
  Object.assign(state, { pairing: null, snapshot: null, stamp: null, checkedAt: null, status: "loading", message: "", tab: "home", loanPending: null, loanMessage: "" });
  clearTimeout(timer);
  render();
}

function setTheme(theme) {
  state.prefs = { ...state.prefs, theme };
  store.savePrefs(state.prefs);
  applyTheme();
  render();
}

async function install() {
  if (!installEvent) return;
  installEvent.prompt();
  await installEvent.userChoice;
  installEvent = null;
  state.installable = false;
  render();
}

function start() {
  applyTheme();
  // Lien ouvert depuis le QR code du Mac : on l'enregistre puis on retire la clé de la barre d'adresse.
  if (location.hash.length > 1) {
    const pairing = parsePairing(location.hash);
    history.replaceState(null, "", location.pathname + location.search);
    if (pairing) { store.savePairing(pairing); state.pairing = pairing; store.saveSnapshot(null); state.stamp = null; }
    else state.message = "Le lien d'appairage est invalide ou incomplet.";
  }
  if (state.pairing) loadCached();
  nav.addEventListener("click", (event) => {
    const button = event.target.closest("button[data-tab]");
    if (!button) return;
    state.tab = button.dataset.tab;
    render();
    window.scrollTo(0, 0);
  });
  refreshButton.addEventListener("click", refresh);
  enablePullToRefresh(refresh);
  themeButton.addEventListener("click", () => setTheme(isLightNow() ? "dark" : "light"));
  document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") { render(); refresh(); } else clearTimeout(timer); });
  window.addEventListener("online", refresh);
  window.addEventListener("beforeinstallprompt", (event) => { event.preventDefault(); installEvent = event; state.installable = true; render(); });
  setInterval(() => { if (document.visibilityState === "visible") render(); }, 30000);
  nav.querySelectorAll("button").forEach((button) => button.prepend(icon(button.dataset.icon)));
  refreshButton.append(icon("refresh"));
  render();
  refresh();
  watchForNewVersion({
    serviceWorker: navigator.serviceWorker,
    onNewVersion: showUpdateBanner,
    onVisible: (handler) => document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") handler(); }),
  });
}

start();
