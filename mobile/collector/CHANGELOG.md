# Collecteur : journal des changements

Canal de livraison à part (ADR 003) : tags `collector-vX.Y.Z`, version dans `collector.js`. Une section par version, la plus récente en haut.

## 0.3.0

- S'arrête seul quand le propriétaire termine le prêt (sans recréer son coffre sur le relais).
- `collecteur demarrage-auto` : lancé à chaque ouverture de session (Linux, macOS, Windows) ; `demarrage-auto retirer` l'enlève.

## 0.2.0

- `collecteur associer <relais> <CODE>` : association avec le code d'invitation créé sur le téléphone du propriétaire (15 minutes,
  une seule fois). Affiche le lien du tableau de bord de l'invité.

## 0.1.0

- Première version : lit les journaux de Claude Code de la machine, compte chaque réponse une fois, envoie chiffrés les heures
  d'activité et les tokens par tranche de 5 minutes. Jamais le texte des conversations, les projets ni les chemins.
