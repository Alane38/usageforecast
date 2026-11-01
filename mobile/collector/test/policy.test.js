import { describe, expect, test } from "bun:test";
import { DAILY_CAP, HEARTBEAT_MS, MIN_PUSH_MS, dayStamp, pushReason } from "../lib/policy.js";

const NOW = Date.parse("2026-11-01T12:00:00Z");
const base = { now: NOW, lastPushAt: NOW - MIN_PUSH_MS, lastActivityAt: NOW - 60_000, pushedActivityAt: NOW - 3_600_000, pushesToday: 3 };

describe("quand envoyer", () => {
  test("premier envoi : toujours, pour que le Mac sache que le collecteur existe", () => {
    expect(pushReason({ ...base, lastPushAt: null, lastActivityAt: null })).toBe("activity");
  });

  test("activité nouvelle et 10 minutes écoulées : envoi", () => {
    expect(pushReason(base)).toBe("activity");
  });

  test("activité nouvelle mais moins de 10 minutes : on attend", () => {
    expect(pushReason({ ...base, lastPushAt: NOW - MIN_PUSH_MS + 1 })).toBeNull();
  });

  test("aucune activité nouvelle : rien, sauf le signe de vie toutes les 6 h", () => {
    const idle = { ...base, pushedActivityAt: base.lastActivityAt };
    expect(pushReason(idle)).toBeNull();
    expect(pushReason({ ...idle, lastActivityAt: null })).toBeNull();
    expect(pushReason({ ...idle, lastPushAt: NOW - HEARTBEAT_MS })).toBe("heartbeat");
  });

  test("plafond quotidien atteint : plus rien, même un signe de vie", () => {
    expect(pushReason({ ...base, pushesToday: DAILY_CAP })).toBeNull();
    expect(pushReason({ ...base, pushesToday: DAILY_CAP, lastPushAt: NOW - HEARTBEAT_MS })).toBeNull();
  });

  test("au pire 144 envois d'activité et 4 signes de vie par jour : sous le plafond", () => {
    expect(24 * 3600 * 1000 / MIN_PUSH_MS + 24 * 3600 * 1000 / HEARTBEAT_MS).toBeLessThanOrEqual(DAILY_CAP);
  });

  test("jour local AAAA-MM-JJ", () => {
    expect(dayStamp(new Date(2026, 10, 1, 23, 59).getTime())).toBe("2026-11-01");
    expect(dayStamp(new Date(2026, 10, 2, 0, 0).getTime())).toBe("2026-11-02");
  });
});
