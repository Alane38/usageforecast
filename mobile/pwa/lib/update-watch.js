// Détecte qu'une nouvelle version de l'application vient d'être installée. Logique isolée (le service worker est injecté) pour être testable.

/**
 * Un nouveau service worker prend la main dès son installation (skipWaiting + clients.claim) : la page ouverte garde pourtant
 * l'ancien code. `onNewVersion` est appelée au changement de contrôleur, sauf au tout premier chargement (aucun contrôleur avant).
 * `isVisible` / `onVisible` : à chaque retour sur l'application, on interroge le serveur sans attendre le prochain lancement.
 */
export function watchForNewVersion({ serviceWorker, onNewVersion, onVisible, isVisible = () => true }) {
  if (!serviceWorker) return;
  const hadController = Boolean(serviceWorker.controller);
  serviceWorker.addEventListener("controllerchange", () => { if (hadController) onNewVersion(); });
  serviceWorker.register("/sw.js").then((registration) => {
    onVisible(() => { if (isVisible()) registration.update().catch(() => {}); });
  }).catch(() => {});
}
