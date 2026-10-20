// Serveur local de développement : le vrai relais (relay/src/worker.js) avec un stockage en mémoire, qui sert aussi l'application.
// Usage : bun mobile/scripts/dev-server.mjs [port]   puis   bun mobile/scripts/seed-demo.mjs http://localhost:8788
import { generate } from "./build-relay.mjs";

generate();
const { default: worker } = await import("../relay/dist/worker.js");

const store = new Map();
const VAULT = {
  async get(key) { return store.get(key)?.value ?? null; },
  async getWithMetadata(key) { const entry = store.get(key); return { value: entry?.value ?? null, metadata: entry?.metadata ?? null }; },
  async put(key, value, options = {}) { store.set(key, { value, metadata: options.metadata }); },
};

const port = Number(process.argv[2] ?? 8788);
const server = Bun.serve({ port, fetch: (request) => worker.fetch(request, { VAULT }) });
console.log(`Relais et application sur http://localhost:${server.port}`);
