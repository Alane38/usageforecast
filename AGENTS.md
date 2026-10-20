# UsageForecast : guide pour les agents

Application de barre de menus macOS (SwiftUI, sans Xcode) qui suit l'usage de Claude (session 5 h, semaine, crédits API), avec prévisions,
budget du jour, statistiques, historique local et **synchro chiffrée vers une application mobile (PWA)**. Projet personnel (licence MIT).
Contexte long, décisions et pièges : `~/.brain/projects/claude-usage-bar/claude-usage-bar.md` (à lire en premier).

## Structure

- `app/*.swift` : l'application, un fichier par responsabilité, **chacun sous 200 lignes**. Logique pure (testable) séparée des vues.
- `tests/main.swift` : tests de la logique pure (compilés sans UI, via `scripts/test.sh`). `tests/visual/ref/` : références d'écrans.
- `mobile/` : application mobile `pwa/` (HTML/CSS/JS, sans build), relais `relay/` (Cloudflare Worker), `scripts/`. Voir `mobile/README.md`.
- `docs/adr/` : décisions d'architecture (001 secrets, 002 application mobile). `CHANGELOG.md` : une section par version.

## Commandes

```bash
./scripts/test.sh                 # tests Swift (doivent tous passer ; la compilation qui échoue arrête tout)
./scripts/build.sh                # build de développement (secrets en fichier, aucune fenêtre du trousseau)
./scripts/release.sh              # build release (secrets dans le trousseau)
./scripts/visual-check.sh         # compare 22 écrans de démonstration aux références (--update après un changement voulu)
./scripts/bump-version.sh X.Y.Z   # version et numéro de build
cd mobile && bun test             # tests JavaScript (chiffrement, statistiques, relais)
cd mobile && bun run dev          # relais local + application sur http://localhost:8788 ; bun run seed pour des données
cd mobile && bun run deploy       # publie le relais sur Cloudflare (idempotent ; --dry-run pour voir les étapes)
```

Options de l'app pour vérifier sans cliquer : `--snapshot fichier.png` avec `--demo`, `--light`, `--layout gauges|cards`, `--settings --tab <onglet>`,
`--demo-mobile`, `--show-code`, `--used-today N`, `--demo-days N`, `--demo-update`, `--time`, `--bench-chart N`, `--diagnose`. Les captures de démonstration
utilisent une **horloge figée** (`AppClock`) : le rendu est identique tous les jours.

## Règles du projet

- **Preuve avant « fini »** : capture, sortie de test ou rendu. Pour l'interface, **auditer** 320 / 360 / tablette / paysage, clair et sombre, états normal,
  alerte, peu de données, vide, hors ligne. Un seul cas « normal » ne suffit pas.
- **Zéro avertissement** de compilation ; tout changement de logique a son test ; un outil de vérification se vérifie lui-même (contrôle négatif).
- **Flux de livraison** : bump, section du `CHANGELOG.md`, `test.sh`, `release.sh`, installation (`trash` l'ancienne app puis `ditto`), commit, `git tag -a vX.Y.Z -m`, push.
- **Trousseau** : une demande de mot de passe par mise à jour (un seul élément `secret_bundle`). **Après une installation, ne lancer aucun autre processus qui lit
  le trousseau** (diagnostic, capture) avant que l'utilisateur ait validé : chaque processus redemande.
- **Secrets** : jamais dans le dépôt, les journaux ni les captures. La synchro mobile est **désactivée par défaut** ; le relais ne voit que du texte chiffré.
- **Le garde-fous du poste bloque** les commandes dont le texte contient certains mots (clé, secret…) même dans un nom de variable, et `rm` : écrire ces fichiers avec
  les outils d'édition, supprimer avec `trash`.
- Interface en **français** avec accents ; textes explicites (une alerte dit la limite, la durée et son hypothèse).
- Pas d'invention : la règle « jour exceptionnel » a été retirée (1.10.1), ne pas la réintroduire.

## Pièges connus

SDK 26 des outils en ligne de commande (la macro `@State` du SDK 27 exige Xcode) ; propriété stockée impossible dans une `extension` ; calcul répété dans une boucle de
dessin (courbe 529 ms) ; l'attribut `hidden` écrasé par `display:flex` ; service worker absent du navigateur intégré (tester dans un vrai Chrome) ; une donnée ancienne ne
doit pas griser un danger. Détail dans `~/.brain/knowledge/learnings/`.
