// Service worker : l'application s'ouvre hors ligne. Les fichiers de l'application sont pris sur le réseau et gardés en cache pour l'hors-ligne ;
// les données (/v1/…) ne passent JAMAIS par le cache : elles viennent toujours du réseau, ou de l'écran de secours de l'application.
const CACHE = "cub-__BUILD__";
const SHELL = ["__SHELL__"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => Promise.allSettled(SHELL.map((path) => cache.add(path)))).then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key.startsWith("cub-") && key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin || url.pathname.startsWith("/v1/")) return;
  // Réseau d'abord : toujours la dernière version de l'application quand on est en ligne ; le cache ne sert qu'hors ligne.
  event.respondWith(
    fetch(request).then((response) => {
      if (response.ok) caches.open(CACHE).then((cache) => cache.put(request, response.clone()));
      return response;
    }).catch(async () => (await caches.match(request, { ignoreSearch: true })) ?? new Response("Hors ligne", { status: 503, headers: { "content-type": "text/plain; charset=utf-8" } })),
  );
});
