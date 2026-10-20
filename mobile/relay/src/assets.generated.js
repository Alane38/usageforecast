// Version vide, uniquement pour les tests du relais. `scripts/build-relay.mjs` fabrique la vraie dans relay/dist (application mobile embarquée).
export function assetFor(path) {
  return path === "/" ? { type: "text/html; charset=utf-8", cache: "no-cache", body: "<!doctype html><title>test</title>" } : null;
}
