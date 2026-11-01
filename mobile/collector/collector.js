#!/usr/bin/env bun
// Collecteur UsageForecast pour l'invité d'un prêt de quota (ADR 003) : Windows, Linux ou macOS.
// Lit les journaux de Claude Code de cette machine et envoie, chiffrés, les heures d'activité et les tokens par tranche de 5 minutes.
import { homedir, platform as osPlatform } from "node:os";
import { runCycle } from "./lib/cycle.js";
import { linkOf, pairingFromInput } from "./lib/link.js";
import { claudeProjectDirs, collectorConfigDir } from "./lib/paths.js";
import { forgetPairing, loadPairing, loadState, savePairing, saveState } from "./lib/store.js";

export const VERSION = "0.1.0";
const LOOP_MS = 60 * 1000;

const context = { env: process.env, home: homedir(), platform: osPlatform() };
const configDir = collectorConfigDir(context);
const dirs = claudeProjectDirs(context);

function when(ms) {
  return ms ? new Date(ms).toLocaleString("fr-FR") : "jamais";
}

const HELP = `Collecteur UsageForecast ${VERSION}

  associer <adresse-du-relais>   crée un coffre et affiche le lien à transmettre au propriétaire du compte
  associer <lien-d-association>  utilise le coffre que le propriétaire t'a donné
  lancer                         tourne en continu (un tour par minute, envoi seulement s'il y a de l'activité)
  une-fois [--essai] [--forcer]  un seul tour ; --essai affiche ce qui serait envoyé sans rien envoyer
  etat                           association, dernier envoi, dernière activité vue
  oublier                        supprime l'association de cette machine

Ce qui est envoyé : des heures et des nombres de tokens. Jamais le texte de tes conversations, tes projets ni tes fichiers.`;

async function cycle({ dryRun = false, force = false } = {}) {
  const pairing = loadPairing(configDir);
  const state = loadState(configDir);
  const result = await runCycle({ pairing, state, now: Date.now(), dirs, collectorVersion: VERSION, platform: context.platform, dryRun, force });
  if (!dryRun) saveState(configDir, state);
  return { result, state };
}

async function main(args) {
  const [command, ...rest] = args;
  if (command === "associer") {
    const outcome = pairingFromInput(rest[0]);
    if (outcome.error) throw new Error(outcome.error);
    savePairing(configDir, outcome.pairing);
    console.log(outcome.created
      ? `Coffre créé. Transmets ce lien au propriétaire du compte (il contient la clé : par un canal privé) :\n\n${linkOf(outcome.pairing)}\n`
      : "Associé au coffre donné par le propriétaire du compte.");
    console.log("Lance ensuite : collecteur lancer");
  } else if (command === "une-fois") {
    const { result } = await cycle({ dryRun: rest.includes("--essai"), force: rest.includes("--forcer") });
    if (result.report && rest.includes("--essai")) console.log(JSON.stringify(result.report, null, 2));
    console.log(`${result.added} nouvelle(s) réponse(s) lue(s). ${result.sent ? `Envoyé (${result.reason}).` : result.error ? `Pas envoyé : ${result.error}.` : "Rien à envoyer."}`);
  } else if (command === "lancer") {
    if (!loadPairing(configDir)) throw new Error("collecteur non associé : lance d'abord « associer »");
    console.log(`Collecteur lancé. Journaux lus dans : ${dirs.join(", ")}`);
    for (;;) {
      const { result } = await cycle();
      if (result.sent) console.log(`${new Date().toLocaleTimeString("fr-FR")} envoyé (${result.reason})`);
      else if (result.error) console.error(`${new Date().toLocaleTimeString("fr-FR")} échec : ${result.error}`);
      await new Promise((resolve) => setTimeout(resolve, LOOP_MS));
    }
  } else if (command === "etat") {
    const pairing = loadPairing(configDir);
    const state = loadState(configDir);
    const last = Object.values(state.messages).reduce((max, record) => Math.max(max, record.t), 0);
    console.log([
      `Association : ${pairing ? `${pairing.relay}, coffre ${pairing.id.slice(0, 8)}…` : "aucune"}`,
      `Dernier envoi : ${when(state.lastPushAt)}${state.lastError ? ` (dernier échec : ${state.lastError})` : ""}`,
      `Dernière activité Claude Code vue : ${when(last)}`,
      `Envois aujourd'hui : ${state.pushesToday}`,
      `Journaux : ${dirs.join(", ")}`,
      `Configuration : ${configDir}`,
    ].join("\n"));
  } else if (command === "oublier") {
    forgetPairing(configDir);
    console.log("Association supprimée sur cette machine.");
  } else {
    console.log(HELP);
  }
}

if (import.meta.main) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(`Erreur : ${error.message}`);
    process.exit(1);
  });
}
