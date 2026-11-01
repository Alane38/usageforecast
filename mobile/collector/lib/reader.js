// Lecture incrémentale des journaux : on reprend chaque fichier là où on s'était arrêté, et seulement jusqu'au dernier saut de ligne
// (une ligne en cours d'écriture sera lue au tour suivant). Un fichier raccourci ou remplacé est relu depuis le début.
import { closeSync, openSync, readSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { KEEP_DAYS } from "./ledger.js";
import { parseLines } from "./transcripts.js";

const MAX_CHUNK = 8 * 1024 * 1024;

/** Tous les `.jsonl` sous un dossier (les sous-agents ont leurs propres fichiers dans des sous-dossiers). Dossier absent : liste vide. */
export function listTranscripts(dir) {
  const found = [];
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return found;
  }
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) found.push(...listTranscripts(path));
    else if (entry.isFile() && entry.name.endsWith(".jsonl")) found.push(path);
  }
  return found;
}

function readFrom(path, offset, size) {
  const length = Math.min(size - offset, MAX_CHUNK);
  const buffer = Buffer.alloc(length);
  const handle = openSync(path, "r");
  try {
    const read = readSync(handle, buffer, 0, length, offset);
    return buffer.subarray(0, read);
  } finally {
    closeSync(handle);
  }
}

/**
 * Lit ce qui est nouveau dans les journaux et retourne les relevés. `files` (chemin → {offset, size}) est mis à jour sur place ;
 * les fichiers disparus en sont retirés, ceux qui n'ont pas bougé depuis plus de `KEEP_DAYS` jours sont ignorés.
 */
export function readNewRecords({ dirs, files, now }) {
  const records = [];
  const seen = new Set();
  const oldest = now - KEEP_DAYS * 24 * 3600 * 1000;
  for (const dir of dirs) {
    for (const path of listTranscripts(dir)) {
      seen.add(path);
      let info;
      try {
        info = statSync(path);
      } catch {
        continue;
      }
      if (info.mtimeMs < oldest) continue;
      const state = files[path] ?? { offset: 0, size: 0 };
      if (info.size < state.offset) {   // fichier raccourci ou remplacé
        state.offset = 0;
        delete state.skipLine;
      }
      while (state.offset < info.size) {
        const chunk = readFrom(path, state.offset, info.size);
        const end = chunk.lastIndexOf(0x0a);
        if (end < 0) {
          // Pas encore de ligne complète. Une ligne plus longue que MAX_CHUNK (énorme sortie d'outil) ne contient jamais de relevé
          // d'usage utile à elle seule : on la saute au lieu de rester bloqué dessus.
          if (chunk.length < MAX_CHUNK) break;
          state.offset += chunk.length;
          state.skipLine = true;
          continue;
        }
        let start = 0;
        if (state.skipLine) {
          start = chunk.indexOf(0x0a) + 1;
          delete state.skipLine;
        }
        records.push(...parseLines(chunk.subarray(start, end + 1).toString("utf8")));
        state.offset += end + 1;
      }
      state.size = info.size;
      files[path] = state;
    }
  }
  for (const path of Object.keys(files)) if (!seen.has(path)) delete files[path];
  return records;
}
