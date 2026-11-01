import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { appendFileSync, mkdirSync, mkdtempSync, rmSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { claudeProjectDirs, collectorConfigDir } from "../lib/paths.js";
import { listTranscripts, readNewRecords } from "../lib/reader.js";
import { forgetPairing, loadPairing, loadState, savePairing, saveState } from "../lib/store.js";
import { assistantLine } from "./fixtures.js";

let root;
beforeEach(() => {
  root = mkdtempSync(join(tmpdir(), "collecteur-"));
});
afterEach(() => rmSync(root, { recursive: true, force: true }));

const NOW = Date.now();

describe("lecture incrémentale des journaux", () => {
  test("parcourt les sous-dossiers (sous-agents), ignore les autres fichiers, dossier absent : rien", () => {
    mkdirSync(join(root, "projet", "session", "subagents"), { recursive: true });
    writeFileSync(join(root, "projet", "a.jsonl"), "");
    writeFileSync(join(root, "projet", "session", "subagents", "b.jsonl"), "");
    writeFileSync(join(root, "projet", "notes.txt"), "");
    expect(listTranscripts(root).sort()).toEqual([join(root, "projet", "a.jsonl"), join(root, "projet", "session", "subagents", "b.jsonl")]);
    expect(listTranscripts(join(root, "absent"))).toEqual([]);
  });

  test("une ligne en cours d'écriture n'est lue qu'une fois terminée, et rien n'est lu deux fois", () => {
    const path = join(root, "s.jsonl");
    const files = {};
    writeFileSync(path, `${assistantLine({ id: "a" })}\n${assistantLine({ id: "b" }).slice(0, 40)}`);
    expect(readNewRecords({ dirs: [root], files, now: NOW }).map((r) => r.key)).toEqual(["a:req_1"]);
    appendFileSync(path, `${assistantLine({ id: "b" }).slice(40)}\n`);
    expect(readNewRecords({ dirs: [root], files, now: NOW }).map((r) => r.key)).toEqual(["b:req_1"]);
    expect(readNewRecords({ dirs: [root], files, now: NOW })).toEqual([]);
  });

  test("fichier raccourci ou remplacé : relu depuis le début ; fichier supprimé : oublié", () => {
    const path = join(root, "s.jsonl");
    const files = {};
    writeFileSync(path, `${assistantLine({ id: "a" })}\n${assistantLine({ id: "b" })}\n`);
    readNewRecords({ dirs: [root], files, now: NOW });
    writeFileSync(path, `${assistantLine({ id: "c" })}\n`);
    expect(readNewRecords({ dirs: [root], files, now: NOW }).map((r) => r.key)).toEqual(["c:req_1"]);
    rmSync(path);
    readNewRecords({ dirs: [root], files, now: NOW });
    expect(files).toEqual({});
  });

  test("fichier inchangé depuis plus de 8 jours : pas lu", () => {
    const path = join(root, "vieux.jsonl");
    writeFileSync(path, `${assistantLine()}\n`);
    const old = (NOW - 9 * 24 * 3600 * 1000) / 1000;
    utimesSync(path, old, old);
    expect(readNewRecords({ dirs: [root], files: {}, now: NOW })).toEqual([]);
  });

  test("une ligne géante (plus de 8 Mo) est sautée sans bloquer la suite", () => {
    const path = join(root, "gros.jsonl");
    writeFileSync(path, `${assistantLine({ id: "avant" })}\n${"x".repeat(9 * 1024 * 1024)}\n${assistantLine({ id: "apres" })}\n`);
    const files = {};
    expect(readNewRecords({ dirs: [root], files, now: NOW }).map((r) => r.key)).toEqual(["avant:req_1", "apres:req_1"]);
    expect(files[path].offset).toBe(statSync(path).size);
  });
});

describe("emplacements selon le système", () => {
  test("journaux : CLAUDE_CONFIG_DIR prioritaire (liste acceptée), sinon ~/.config/claude et ~/.claude", () => {
    expect(claudeProjectDirs({ env: { CLAUDE_CONFIG_DIR: "/a, /b" }, home: "/h" })).toEqual([join("/a", "projects"), join("/b", "projects")]);
    expect(claudeProjectDirs({ env: {}, home: "/h" })).toEqual([join("/h", ".config", "claude", "projects"), join("/h", ".claude", "projects")]);
    expect(claudeProjectDirs({ env: { XDG_CONFIG_HOME: "/x" }, home: "/h" })[0]).toBe(join("/x", "claude", "projects"));
  });

  test("configuration : %APPDATA% sous Windows, Application Support sur macOS, XDG sous Linux", () => {
    expect(collectorConfigDir({ platform: "win32", env: { APPDATA: "C:\\Users\\sam\\AppData\\Roaming" }, home: "C:\\Users\\sam" })).toBe(join("C:\\Users\\sam\\AppData\\Roaming", "UsageForecast"));
    expect(collectorConfigDir({ platform: "darwin", env: {}, home: "/Users/sam" })).toBe(join("/Users/sam", "Library", "Application Support", "UsageForecast"));
    expect(collectorConfigDir({ platform: "linux", env: {}, home: "/home/sam" })).toBe(join("/home/sam", ".config", "usageforecast"));
  });
});

describe("fichiers du collecteur", () => {
  const pairing = { relay: "https://relais.example", id: "0123456789abcdef0123456789abcdef", key: "abc" };

  test("association : aller-retour, droits 0600, oubli", () => {
    const dir = join(root, "config");
    expect(loadPairing(dir)).toBeNull();
    savePairing(dir, pairing);
    expect(loadPairing(dir)).toEqual(pairing);
    if (process.platform !== "win32") expect(statSync(join(dir, "collecteur.json")).mode & 0o777).toBe(0o600);
    forgetPairing(dir);
    expect(loadPairing(dir)).toBeNull();
  });

  test("état : valeurs par défaut si absent ou abîmé, aller-retour sinon", () => {
    const dir = join(root, "config");
    expect(loadState(dir).messages).toEqual({});
    saveState(dir, { ...loadState(dir), pushesToday: 4 });
    expect(loadState(dir).pushesToday).toBe(4);
    writeFileSync(join(dir, "collecteur-etat.json"), "{abîmé");
    expect(loadState(dir).pushesToday).toBe(0);
  });
});
