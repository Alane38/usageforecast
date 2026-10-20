# 001 : stockage des secrets, développement et release

## Contexte
L'app garde deux cookies de session (claude.ai et Console). Le trousseau macOS est le bon endroit, mais il lie
l'autorisation d'accès à l'empreinte exacte du binaire quand la signature n'a pas d'identifiant d'équipe Apple
(certificat auto-signé local). Chaque recompilation redemande donc le mot de passe, ce qui rend le développement pénible.

## Décision
Le stockage dépend de la compilation :
- **développement** (`scripts/build.sh`, défaut) : un fichier par secret dans
  `~/Library/Application Support/UsageForecast/secrets` (droits 0600, dossier 0700). Aucune fenêtre du trousseau.
- **release** (`scripts/build.sh --release` ou `scripts/release.sh`) : trousseau macOS, chiffré et réservé à l'app. **Un seul élément** (`secret_bundle`, JSON) contient tous les secrets (depuis la 1.10.2).
  Au premier lancement, les secrets saisis en développement passent dans le trousseau puis le fichier est supprimé.

Le mode actif est affiché dans Réglages > Connexions.

## Conséquences
- En développement, les cookies sont lisibles par tout programme lancé sous ce compte.
  À ne pas utiliser comme version « de tous les jours » partagée : on déploie en release.
- Une release redemande l'autorisation du trousseau une fois par nouvelle version (empreinte différente). L'autorisation étant demandée par élément, regrouper les secrets en un seul élément ramène ce coût à **une demande par version** (avant la 1.10.2 : une par cookie, soit deux, et quatre quand un diagnostic lisait le trousseau en parallèle juste après l'installation).
- Ne jamais lancer un second processus qui lit le trousseau (diagnostic, capture) juste après une installation, avant que l'utilisateur ait validé : chaque processus redemande.
- L'ancien trousseau peut être repris en développement avec un bouton explicite (une demande de mot de passe).
