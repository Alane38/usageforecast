// Fichiers du collecteur : `collecteur.json` (l'association : relais, coffre, clé) et `collecteur-etat.json` (où en est la lecture).
// Droits 0600, écriture atomique (fichier temporaire puis renommage) pour ne jamais laisser un fichier à moitié écrit.
import { chmodSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { emptyState } from "./cycle.js";

export const PAIRING_FILE = "collecteur.json";
export const STATE_FILE = "collecteur-etat.json";

function readJson(path) {
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function writeJson(dir, name, value) {
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const path = join(dir, name);
  const temporary = `${path}.tmp`;
  writeFileSync(temporary, JSON.stringify(value), { mode: 0o600 });
  renameSync(temporary, path);
  try {
    chmodSync(path, 0o600);
  } catch {
    // Windows : les droits Unix n'existent pas, le dossier %APPDATA% est déjà propre à l'utilisateur.
  }
}

export function loadPairing(dir) {
  const value = readJson(join(dir, PAIRING_FILE));
  const valid = value && typeof value.relay === "string" && /^[0-9a-f]{32}$/.test(value.id ?? "") && typeof value.key === "string" && value.key.length > 0;
  return valid ? value : null;
}

export function forgetPairing(dir) {
  rmSync(join(dir, PAIRING_FILE), { force: true });
}

export function savePairing(dir, pairing) {
  writeJson(dir, PAIRING_FILE, { relay: pairing.relay, id: pairing.id, key: pairing.key });
}

export function loadState(dir) {
  const value = readJson(join(dir, STATE_FILE));
  return value && typeof value.files === "object" && typeof value.messages === "object" ? { ...emptyState(), ...value } : emptyState();
}

export function saveState(dir, state) {
  writeJson(dir, STATE_FILE, state);
}
