import { describe, expect, test } from "bun:test";
import { PULL_MAX, PULL_TRIGGER, pullDistance, shouldRefresh } from "../lib/pull.js";

describe("tirer pour actualiser", () => {
  test("un tirage vertical vers le bas donne la moitié du déplacement", () => {
    expect(pullDistance(0, 60)).toBe(30);
    expect(pullDistance(10, 100)).toBe(50);
  });

  test("un geste horizontal, une remontée ou un doigt immobile ne tirent pas", () => {
    expect(pullDistance(80, 40)).toBe(0);     // défilement horizontal (courbes)
    expect(pullDistance(0, -50)).toBe(0);     // vers le haut
    expect(pullDistance(0, 0)).toBe(0);
  });

  test("la distance est plafonnée", () => {
    expect(pullDistance(0, 1000)).toBe(PULL_MAX);
  });

  test("l'actualisation part au seuil, pas avant", () => {
    expect(shouldRefresh(PULL_TRIGGER - 1)).toBe(false);
    expect(shouldRefresh(PULL_TRIGGER)).toBe(true);
    expect(shouldRefresh(pullDistance(0, 100))).toBe(false);   // 50 px : encore trop court
    expect(shouldRefresh(pullDistance(0, 140))).toBe(true);    // 70 px
  });
});
