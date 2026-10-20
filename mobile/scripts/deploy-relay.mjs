// Déploie le relais (et l'application mobile qu'il sert) sur ton compte Cloudflare, gratuitement.
// Usage : bun mobile/scripts/deploy-relay.mjs [--dry-run]
// Prérequis : être connecté à Cloudflare (`npx wrangler login` une fois, ou la variable CLOUDFLARE_API_TOKEN).
// Ce script crée un espace de stockage « VAULT » et publie un Worker « usageforecast-relay » : rien d'autre n'est touché.
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { generate } from "./build-relay.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const relayDir = join(here, "..", "relay");
const configPath = join(relayDir, "wrangler.toml");
const dryRun = process.argv.includes("--dry-run");
const PLACEHOLDER = "REMPLACE_PAR_LE_DEPLOIEMENT";
// Titre des nouveaux espaces ; « VAULT » est le titre des premiers déploiements, toujours reconnu.
const TITLES = ["usageforecast-relay-vault", "VAULT"];

const say = (text) => console.log(text);
const fail = (text, code = 1) => { console.error(`\n✗ ${text}`); process.exit(code); };

function wrangler(args, { capture = true } = {}) {
  const result = spawnSync("npx", ["--yes", "wrangler@4", ...args], { cwd: relayDir, encoding: "utf8", stdio: capture ? ["inherit", "pipe", "pipe"] : "inherit" });
  return { ok: result.status === 0, out: `${result.stdout ?? ""}${result.stderr ?? ""}` };
}

say("1/5  Fabrication du relais et de l'application mobile…");
const built = generate();
say(`     ${built.files} fichiers, build ${built.build}, ${Math.round(built.bytes / 1024)} Ko → relay/dist`);

if (dryRun) {
  say("\nMode essai : rien n'est envoyé à Cloudflare. Étapes à venir :");
  say("  2/5  vérifier la connexion (wrangler whoami)");
  say("  3/5  réutiliser ou créer l'espace de stockage VAULT (son identifiant reste dans relay/dist, hors du dépôt)");
  say("  4/5  publier le Worker « usageforecast-relay »");
  say("  5/5  contrôler que la page d'accueil répond, puis afficher l'adresse à coller dans UsageForecast > Réglages > Mobile");
  process.exit(0);
}

say("2/5  Vérification de la connexion à Cloudflare…");
const who = wrangler(["whoami"]);
if (!who.ok || /not authenticated|You are not logged in/i.test(who.out)) {
  fail("Tu n'es pas connecté à Cloudflare. Lance d'abord : npx wrangler login (une fois), puis relance ce script.", 2);
}

say("3/5  Espace de stockage des coffres chiffrés…");
// Idempotent : on réutilise l'espace existant (cherché par son titre) au lieu d'en créer un à chaque déploiement.
let namespaceId = null;
const listed = wrangler(["kv", "namespace", "list"]);
if (listed.ok) {
  try {
    const parsed = JSON.parse(listed.out.slice(listed.out.indexOf("[")));
    namespaceId = parsed.find((entry) => TITLES.includes(entry.title))?.id ?? null;
  } catch { /* liste illisible : on tentera la création */ }
}
if (namespaceId) {
  say(`     existant (${namespaceId.slice(0, 8)}…)`);
} else {
  const created = wrangler(["kv", "namespace", "create", TITLES[0]]);
  namespaceId = created.out.match(/"?id"?\s*[=:]\s*"([0-9a-f]{32})"/)?.[1] ?? null;
  if (!created.ok || !namespaceId) fail(`Création de l'espace de stockage impossible :\n${created.out}`);
  say(`     créé (${namespaceId.slice(0, 8)}…)`);
}

// La configuration réelle (avec l'identifiant propre à ton compte) vit dans relay/dist, ignoré par git : le dépôt garde le modèle.
const config = readFileSync(configPath, "utf8").replace(PLACEHOLDER, namespaceId).replace(/^main = .*$/m, 'main = "worker.js"');
writeFileSync(join(relayDir, "dist", "wrangler.toml"), config);

say("4/5  Publication du Worker…");
const deployed = wrangler(["deploy", "--config", "dist/wrangler.toml"], { capture: true });
if (!deployed.ok) fail(`Publication impossible :\n${deployed.out}`);
const url = deployed.out.match(/https:\/\/[a-z0-9.-]+\.workers\.dev/i)?.[0];
if (!url) fail(`Publié, mais l'adresse n'a pas été trouvée dans la sortie :\n${deployed.out}`);

say("5/5  Contrôle…");
let healthy = false;
for (let attempt = 0; attempt < 8 && !healthy; attempt++) {
  if (attempt > 0) await new Promise((resolve) => setTimeout(resolve, 5000));   // un nouveau Worker met parfois quelques secondes à répondre
  healthy = (await fetch(url).catch(() => null))?.ok === true;
}
if (!healthy) fail(`Le relais ne répond pas encore sur ${url} (attends une minute puis ouvre l'adresse dans un navigateur).`);

say(`\n✓ Relais en ligne : ${url}`);
say("  Colle cette adresse dans UsageForecast > Réglages > Mobile, active la synchro, puis scanne le code avec ton téléphone.");
