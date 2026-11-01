// Où sont les journaux de Claude Code, et où le collecteur range sa configuration, selon le système. Fonctions pures (l'environnement est passé).
import { join } from "node:path";

/**
 * Dossiers `projects` de Claude Code à parcourir, sans doublon : `CLAUDE_CONFIG_DIR` (liste séparée par des virgules acceptée),
 * sinon `~/.config/claude` puis `~/.claude` (les deux emplacements existent selon les versions).
 */
export function claudeProjectDirs({ env, home }) {
  const roots = [];
  const configured = env.CLAUDE_CONFIG_DIR?.trim();
  if (configured) roots.push(...configured.split(",").map((part) => part.trim()).filter(Boolean));
  else {
    const xdg = env.XDG_CONFIG_HOME?.trim() || join(home, ".config");
    roots.push(join(xdg, "claude"), join(home, ".claude"));
  }
  return [...new Set(roots.map((root) => join(root, "projects")))];
}

/** Dossier de configuration du collecteur : à côté de celui de l'app Mac sur macOS, dans `%APPDATA%` sous Windows, XDG sous Linux. */
export function collectorConfigDir({ platform, env, home }) {
  if (platform === "win32") return join(env.APPDATA || join(home, "AppData", "Roaming"), "UsageForecast");
  if (platform === "darwin") return join(home, "Library", "Application Support", "UsageForecast");
  return join(env.XDG_CONFIG_HOME?.trim() || join(home, ".config"), "usageforecast");
}
