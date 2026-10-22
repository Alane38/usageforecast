// Tirer vers le bas pour actualiser. Logique pure (testable) : la distance affichée et le déclenchement.

export const PULL_TRIGGER = 64;   // distance affichée (px) à partir de laquelle le relâchement actualise
export const PULL_MAX = 96;

/**
 * Distance d'indicateur pour un doigt déplacé de (dx, dy). 0 si le geste n'est pas un tirage vertical vers le bas
 * (défilement horizontal, remontée), pour ne jamais gêner le curseur des courbes ni le défilement normal.
 */
export function pullDistance(dx, dy) {
  if (dy <= 0 || Math.abs(dx) * 1.5 > dy) return 0;
  return Math.min(dy * 0.5, PULL_MAX);   // résistance : l'indicateur suit à moitié de vitesse
}

export const shouldRefresh = (distance) => distance >= PULL_TRIGGER;
