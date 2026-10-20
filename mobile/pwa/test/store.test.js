import { describe, expect, test } from "bun:test";
import { createStore } from "../lib/store.js";

function memoryStorage(failures = {}) {
  const map = new Map();
  return {
    map,
    getItem(key) { if (failures.get) throw new Error("accès refusé"); return map.has(key) ? map.get(key) : null; },
    setItem(key, value) { if (failures.set) throw new Error("quota dépassé"); map.set(key, value); },
    removeItem(key) { map.delete(key); },
  };
}

describe("stockage local", () => {
  test("appairage et snapshot : aller-retour", () => {
    const store = createStore(memoryStorage());
    expect(store.pairing()).toBeNull();
    expect(store.savePairing({ id: "a", key: "b" })).toBe(true);
    expect(store.pairing()).toEqual({ id: "a", key: "b" });
    store.saveSnapshot({ raw: { version: 1 }, stamp: "123", checkedAt: 5 });
    expect(store.snapshot()).toEqual({ raw: { version: 1 }, stamp: "123", checkedAt: 5 });
  });

  test("préférences : thème sombre par défaut, valeurs enregistrées conservées", () => {
    const store = createStore(memoryStorage());
    expect(store.prefs()).toEqual({ theme: "dark" });
    store.savePrefs({ theme: "dark" });
    expect(store.prefs().theme).toBe("dark");
  });

  test("oublier l'appareil efface l'appairage et les données, pas les préférences", () => {
    const store = createStore(memoryStorage());
    store.savePairing({ id: "a", key: "b" });
    store.saveSnapshot({ raw: {} });
    store.savePrefs({ theme: "light" });
    store.forget();
    expect(store.pairing()).toBeNull();
    expect(store.snapshot()).toBeNull();
    expect(store.prefs().theme).toBe("light");
  });

  test("un stockage qui échoue ne casse jamais l'application", () => {
    const store = createStore(memoryStorage({ get: true, set: true }));
    expect(store.pairing()).toBeNull();
    expect(store.savePairing({ id: "a", key: "b" })).toBe(false);
    expect(store.prefs()).toEqual({ theme: "dark" });
    expect(() => store.forget()).not.toThrow();
  });

  test("un contenu corrompu est ignoré", () => {
    const storage = memoryStorage();
    storage.map.set("cub.pairing", "{pas du json");
    expect(createStore(storage).pairing()).toBeNull();
  });
});
