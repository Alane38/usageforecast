// Compile le collecteur en un exécutable autonome par plateforme (aucun runtime à installer chez l'invité), avec leurs empreintes SHA-256.
// Usage : bun scripts/build-collector.mjs [cible…]   (par défaut toutes ; cibles : linux-x64 linux-arm64 windows-x64 darwin-arm64 darwin-x64)
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { VERSION } from "../collector/collector.js";

const TARGETS = {
  "linux-x64": "usageforecast-collecteur-linux-x64",
  "linux-arm64": "usageforecast-collecteur-linux-arm64",
  "windows-x64": "usageforecast-collecteur-windows-x64.exe",
  "darwin-arm64": "usageforecast-collecteur-macos-arm64",
  "darwin-x64": "usageforecast-collecteur-macos-x64",
};

const root = join(import.meta.dir, "..");
const out = join(root, "collector", "dist");
mkdirSync(out, { recursive: true });

const wanted = process.argv.slice(2);
const unknown = wanted.filter((target) => !TARGETS[target]);
if (unknown.length) {
  console.error(`Cible inconnue : ${unknown.join(", ")}. Cibles : ${Object.keys(TARGETS).join(", ")}`);
  process.exit(1);
}

const sums = [];
for (const target of wanted.length ? wanted : Object.keys(TARGETS)) {
  const file = join(out, TARGETS[target]);
  const build = Bun.spawnSync(["bun", "build", "--compile", "--minify", `--target=bun-${target}`, join(root, "collector", "collector.js"), "--outfile", file], { stdout: "inherit", stderr: "inherit" });
  if (build.exitCode !== 0) {
    console.error(`Échec de la compilation pour ${target}.`);
    process.exit(1);
  }
  sums.push(`${createHash("sha256").update(readFileSync(file)).digest("hex")}  ${TARGETS[target]}`);
}
writeFileSync(join(out, "SHA256SUMS"), `${sums.join("\n")}\n`);
console.log(`Collecteur ${VERSION} : ${sums.length} exécutable(s) dans collector/dist, empreintes dans SHA256SUMS.`);
