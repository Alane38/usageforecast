import { describe, expect, test } from "bun:test";
import { watchForNewVersion } from "../lib/update-watch.js";

function fakeServiceWorker({ controller }) {
  const listeners = {};
  const registration = { updates: 0, update: async () => { registration.updates += 1; } };
  return {
    controller,
    registration,
    addEventListener: (name, handler) => { listeners[name] = handler; },
    register: async () => registration,
    fire: (name) => listeners[name]?.(),
  };
}

describe("nouvelle version de l'application", () => {
  test("un changement de contrôleur après un premier chargement signale la nouvelle version", () => {
    const worker = fakeServiceWorker({ controller: {} });
    let signaled = 0;
    watchForNewVersion({ serviceWorker: worker, onNewVersion: () => { signaled += 1; }, onVisible: () => {} });
    worker.fire("controllerchange");
    expect(signaled).toBe(1);
  });

  test("au tout premier chargement (aucun contrôleur), rien n'est signalé", () => {
    const worker = fakeServiceWorker({ controller: null });
    let signaled = 0;
    watchForNewVersion({ serviceWorker: worker, onNewVersion: () => { signaled += 1; }, onVisible: () => {} });
    worker.fire("controllerchange");
    expect(signaled).toBe(0);
  });

  test("chaque retour sur l'application interroge le serveur", async () => {
    const worker = fakeServiceWorker({ controller: {} });
    let comeBack = () => {};
    watchForNewVersion({ serviceWorker: worker, onNewVersion: () => {}, onVisible: (handler) => { comeBack = handler; } });
    await Promise.resolve();
    comeBack();
    comeBack();
    expect(worker.registration.updates).toBe(2);
  });

  test("sans service worker (navigateur ancien), aucune erreur", () => {
    expect(() => watchForNewVersion({ serviceWorker: undefined, onNewVersion: () => {}, onVisible: () => {} })).not.toThrow();
  });
});
