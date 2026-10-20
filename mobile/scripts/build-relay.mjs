// Fabrique le relais déployable dans relay/dist (ignoré par git) : le worker, plus l'application mobile (pwa/) embarquée dans
// assets.generated.js, avec le service worker numéroté. Le dépôt ne garde qu'un fichier d'assets vide pour les tests du relais.
// Usage : bun mobile/scripts/build-relay.mjs
import { createHash } from "node:crypto";
import { copyFileSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const pwa = join(here, "..", "pwa");
const source = join(here, "..", "relay", "src");
const dist = join(here, "..", "relay", "dist");

const TYPES = {
  ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".webmanifest": "application/manifest+json", ".svg": "image/svg+xml", ".png": "image/png",
};
const BINARY = new Set([".png"]);
const SKIP = new Set(["test"]);

function walk(directory) {
  return readdirSync(directory).flatMap((name) => {
    if (SKIP.has(name)) return [];
    const path = join(directory, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
}

export function collect() {
  const files = walk(pwa).sort();
  const hash = createHash("sha256");
  for (const file of files) hash.update(relative(pwa, file)).update(readFileSync(file));
  const build = hash.digest("hex").slice(0, 10);
  const shell = files.map((file) => "/" + relative(pwa, file)).filter((path) => path !== "/sw.js").map((path) => (path === "/index.html" ? "/" : path));
  const assets = {};
  for (const file of files) {
    const path = "/" + relative(pwa, file);
    const extension = path.slice(path.lastIndexOf("."));
    let body = readFileSync(file);
    if (path === "/sw.js") body = Buffer.from(body.toString("utf8").replace("__BUILD__", build).replace('["__SHELL__"]', JSON.stringify(shell)));
    const key = path === "/index.html" ? "/" : path;
    assets[key] = {
      type: TYPES[extension] ?? "application/octet-stream",
      // Rien n'est figé dans le cache du navigateur : une mise à jour doit être vue tout de suite (le service worker gère l'hors-ligne).
      cache: "no-cache",
      binary: BINARY.has(extension),
      body: BINARY.has(extension) ? body.toString("base64") : body.toString("utf8"),
    };
  }
  return { assets, build };
}

export function generate() {
  const { assets, build } = collect();
  const code = `// Fichier généré par mobile/scripts/build-relay.mjs (build ${build}) : ne pas modifier à la main.
const ASSETS = ${JSON.stringify(assets)};

export const BUILD = ${JSON.stringify(build)};

export function assetFor(path) {
  const asset = ASSETS[path];
  if (!asset) return null;
  const body = asset.binary ? Uint8Array.from(atob(asset.body), (char) => char.charCodeAt(0)) : asset.body;
  return { type: asset.type, cache: asset.cache, body };
}
`;
  mkdirSync(dist, { recursive: true });
  copyFileSync(join(source, "worker.js"), join(dist, "worker.js"));
  writeFileSync(join(dist, "assets.generated.js"), code);
  return { files: Object.keys(assets).length, build, bytes: code.length, dist };
}

if (import.meta.main) console.log(generate());
