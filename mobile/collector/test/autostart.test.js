import { describe, expect, test } from "bun:test";
import { join } from "node:path";
import { LAUNCH_LABEL, SERVICE_NAME, autostartPlan, launchCommand } from "../lib/autostart.js";

describe("démarrage automatique", () => {
  test("commande : l'exécutable compilé seul, ou bun et le script en développement", () => {
    expect(launchCommand({ execPath: "/opt/collecteur", scriptPath: "/x/collector.js" })).toEqual(["/opt/collecteur", "lancer"]);
    expect(launchCommand({ execPath: "/home/sam/.bun/bin/bun", scriptPath: "/x/collector.js" })).toEqual(["/home/sam/.bun/bin/bun", "/x/collector.js", "lancer"]);
    expect(launchCommand({ execPath: "C:\\bun\\bun.exe", scriptPath: "C:\\x\\collector.js" })).toHaveLength(3);
  });

  test("Linux : unité systemd utilisateur, chemin avec espace entre guillemets, CLAUDE_CONFIG_DIR transmis, pas de redémarrage après un arrêt normal", () => {
    const plan = autostartPlan({ platform: "linux", home: "/home/sam", env: { CLAUDE_CONFIG_DIR: "/data/claude" }, execPath: "/home/sam/Mes outils/collecteur" });
    expect(plan.file).toBe(join("/home/sam", ".config", "systemd", "user", `${SERVICE_NAME}.service`));
    expect(plan.content).toContain('ExecStart="/home/sam/Mes outils/collecteur" "lancer"');
    expect(plan.content).toContain('Environment="CLAUDE_CONFIG_DIR=/data/claude"');
    expect(plan.content).toContain("Restart=on-failure");
    expect(plan.start.at(-1)).toEqual(["systemctl", "--user", "enable", "--now", `${SERVICE_NAME}.service`]);
    expect(autostartPlan({ platform: "linux", home: "/h", env: {}, execPath: "/c" }).content).not.toContain("Environment=");
  });

  test("macOS : LaunchAgent au XML échappé, relancé seulement après un plantage, journal dans ~/Library/Logs", () => {
    const plan = autostartPlan({ platform: "darwin", home: "/Users/sam", env: {}, execPath: "/Users/sam/A&B/collecteur", uid: 502 });
    expect(plan.file).toBe(join("/Users/sam", "Library", "LaunchAgents", `${LAUNCH_LABEL}.plist`));
    expect(plan.content).toContain("<string>/Users/sam/A&amp;B/collecteur</string>");
    expect(plan.content).toContain("<key>SuccessfulExit</key><false/>");
    expect(plan.start).toEqual([["launchctl", "bootstrap", "gui/502", plan.file]]);
    expect(plan.note).toContain("Library/Logs");
  });

  test("Windows : script du dossier Démarrage, sans fenêtre, guillemets doublés pour un chemin avec espaces", () => {
    const plan = autostartPlan({ platform: "win32", home: "C:\\Users\\sam", env: { APPDATA: "C:\\Users\\sam\\AppData\\Roaming" }, execPath: "C:\\Program Files\\collecteur.exe" });
    expect(plan.file).toContain(join("Microsoft", "Windows", "Start Menu", "Programs", "Startup"));
    expect(plan.content).toContain('Run """C:\\Program Files\\collecteur.exe"" lancer", 0, False');
    expect(plan.stop).toEqual([["taskkill", "/IM", "collecteur.exe", "/F"]]);
    expect(autostartPlan({ platform: "win32", home: "C:\\h", env: {}, execPath: "C:\\bun\\bun.exe", scriptPath: "C:\\x\\c.js" }).stop).toEqual([]);
  });

  test("système inconnu : rien", () => {
    expect(autostartPlan({ platform: "aix", home: "/h", env: {}, execPath: "/c" })).toBeNull();
  });
});
