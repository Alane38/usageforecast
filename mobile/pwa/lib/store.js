// Stockage local du téléphone : l'appairage (identifiant + clé), le dernier snapshot reçu (pour l'affichage hors ligne) et les préférences.
// Tout accès peut échouer (navigation privée, stockage plein) : l'application doit alors continuer à fonctionner.

const KEYS = { pairing: "cub.pairing", snapshot: "cub.snapshot", prefs: "cub.prefs" };

export function createStore(storage = globalThis.localStorage) {
  const read = (key) => {
    try {
      const raw = storage.getItem(key);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  };
  const write = (key, value) => {
    try {
      storage.setItem(key, JSON.stringify(value));
      return true;
    } catch {
      return false;
    }
  };
  return {
    pairing: () => read(KEYS.pairing),
    savePairing: (pairing) => write(KEYS.pairing, pairing),
    /** { raw, stamp, checkedAt } : le snapshot tel que reçu, l'horodatage du relais et l'instant de la dernière vérification. */
    snapshot: () => read(KEYS.snapshot),
    saveSnapshot: (entry) => write(KEYS.snapshot, entry),
    prefs: () => ({ theme: "dark", ...(read(KEYS.prefs) ?? {}) }),
    savePrefs: (prefs) => write(KEYS.prefs, prefs),
    /** Oublie l'appareil : l'appairage et les données. Les préférences d'affichage restent. */
    forget() {
      try {
        storage.removeItem(KEYS.pairing);
        storage.removeItem(KEYS.snapshot);
      } catch { /* rien à faire */ }
    },
  };
}
