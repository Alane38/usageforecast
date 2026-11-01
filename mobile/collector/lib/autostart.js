// Démarrage automatique du collecteur à l'ouverture de session : unité systemd (Linux), LaunchAgent (macOS), script du dossier
// Démarrage (Windows). Fonction pure : elle dit quels fichiers écrire et quelles commandes lancer ; collector.js s'en charge.
import { join } from "node:path";

/** Nom de fichier, que le chemin soit Unix ou Windows (le plan se calcule aussi pour une autre plateforme). */
const basename = (path) => path.split(/[\\/]/).pop();

export const SERVICE_NAME = "usageforecast-collecteur";
export const LAUNCH_LABEL = "fr.usageforecast.collecteur";

/** Commande qui lance le collecteur : l'exécutable compilé seul, ou `bun <script>` en développement. */
export function launchCommand({ execPath, scriptPath }) {
  return /^bun(\.exe)?$/i.test(basename(execPath)) ? [execPath, scriptPath, "lancer"] : [execPath, "lancer"];
}

const xml = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const systemdQuote = (text) => `"${text.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
const vbsQuote = (text) => text.replace(/"/g, '""');

/**
 * @returns {{file: string, content: string, start: string[][], stop: string[][], note: string}}
 *   `start` : commandes à lancer après l'écriture du fichier ; `stop` : avant de le supprimer.
 */
export function autostartPlan({ platform, home, env, execPath, scriptPath, uid = 501 }) {
  const command = launchCommand({ execPath, scriptPath });
  const configDir = env.CLAUDE_CONFIG_DIR?.trim();
  if (platform === "linux") {
    const file = join(env.XDG_CONFIG_HOME?.trim() || join(home, ".config"), "systemd", "user", `${SERVICE_NAME}.service`);
    const content = ["[Unit]", "Description=Collecteur UsageForecast (prêt de quota)", "After=network-online.target", "",
      "[Service]", `ExecStart=${command.map(systemdQuote).join(" ")}`, configDir ? `Environment=${systemdQuote(`CLAUDE_CONFIG_DIR=${configDir}`)}` : null,
      // Arrêt normal (prêt terminé) : pas de redémarrage. Plantage ou coupure réseau : nouvel essai une minute après.
      "Restart=on-failure", "RestartSec=60", "", "[Install]", "WantedBy=default.target", ""].filter((line) => line !== null).join("\n");
    return { file, content,
      start: [["systemctl", "--user", "daemon-reload"], ["systemctl", "--user", "enable", "--now", `${SERVICE_NAME}.service`]],
      stop: [["systemctl", "--user", "disable", "--now", `${SERVICE_NAME}.service`]],
      note: `Journal : journalctl --user -u ${SERVICE_NAME}` };
  }
  if (platform === "darwin") {
    const file = join(home, "Library", "LaunchAgents", `${LAUNCH_LABEL}.plist`);
    const log = join(home, "Library", "Logs", `${SERVICE_NAME}.log`);
    const content = ['<?xml version="1.0" encoding="UTF-8"?>',
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
      '<plist version="1.0">', "<dict>",
      `  <key>Label</key><string>${LAUNCH_LABEL}</string>`,
      "  <key>ProgramArguments</key>", "  <array>", ...command.map((part) => `    <string>${xml(part)}</string>`), "  </array>",
      configDir ? `  <key>EnvironmentVariables</key><dict><key>CLAUDE_CONFIG_DIR</key><string>${xml(configDir)}</string></dict>` : null,
      "  <key>RunAtLoad</key><true/>",
      "  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>",
      `  <key>StandardOutPath</key><string>${xml(log)}</string>`, `  <key>StandardErrorPath</key><string>${xml(log)}</string>`,
      "</dict>", "</plist>", ""].filter((line) => line !== null).join("\n");
    return { file, content, start: [["launchctl", "bootstrap", `gui/${uid}`, file]], stop: [["launchctl", "bootout", `gui/${uid}`, file]], note: `Journal : ${log}` };
  }
  if (platform === "win32") {
    const appData = env.APPDATA || join(home, "AppData", "Roaming");
    const file = join(appData, "Microsoft", "Windows", "Start Menu", "Programs", "Startup", `${SERVICE_NAME}.vbs`);
    const line = command.map((part) => (part === "lancer" ? part : `""${vbsQuote(part)}""`)).join(" ");
    const content = ["' Collecteur UsageForecast : lancé à l'ouverture de session, sans fenêtre (prêt de quota).",
      `CreateObject("WScript.Shell").Run "${line}", 0, False`, ""].join("\r\n");
    // Arrêt : seulement l'exécutable compilé (en développement, tuer « bun.exe » toucherait d'autres programmes).
    return { file, content, start: [["wscript.exe", file]], stop: command.length === 2 ? [["taskkill", "/IM", basename(execPath), "/F"]] : [],
      note: "Il tourne sans fenêtre ; « collecteur etat » montre son dernier envoi." };
  }
  return null;
}
