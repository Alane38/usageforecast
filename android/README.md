# UsageForecast pour Android (APK)

Une **coque WebView** qui enveloppe la PWA de `mobile/pwa`. Pourquoi pas une TWA : la PWA est servie par le Worker Cloudflare de chaque utilisateur (une adresse différente pour chacun), donc aucun domaine fixe à lier dans un APK public.

- Premier lancement : l'écran « Adresse du relais » demande l'adresse (`https://….workers.dev`) **ou** le lien d'association complet (`https://<relais>/#v1.…`). L'origine est mémorisée dans des préférences privées ; la PWA s'ouvre ensuite en plein écran.
- **Le fragment du lien contient la clé** : il sert au seul premier chargement, reste en mémoire, n'est jamais écrit, journalisé ni envoyé ailleurs. La PWA le range ensuite dans son propre stockage.
- Changer d'adresse : appui long sur Retour, ou appui long sur l'icône de l'application puis « Adresse du relais » (seule voie avec la navigation par gestes). Changer de relais ou « Oublier » efface le stockage de la PWA (donc l'ancienne clé).
- JavaScript, localStorage, IndexedDB et service worker sont actifs : la PWA marche hors ligne avec ses dernières données.
- Sécurité : permission `INTERNET` (plus `REQUEST_INSTALL_PACKAGES` pour la mise à jour intégrée), aucun trafic en clair, sauvegarde Android désactivée (le stockage contient la clé), liens vers un autre domaine ouverts dans le navigateur, aucun journal.
- Thème sombre par défaut, comme la PWA. Aucune bibliothèque tierce (WebView et framework Android seuls ; JUnit pour les tests).

## Construire

Prérequis : JDK 17, SDK Android dans `~/Library/Android/sdk` (plateforme 35, build-tools 35) avec les licences déjà acceptées par toi.

```bash
./scripts/build-apk.sh        # lance les tests puis produit build/UsageForecast-<version>-android.apk
```

La version vient de `app/Info.plist` (`CFBundleShortVersionString` et numéro de build). Attention : `scripts/build.sh` et `release.sh` vident `build/`, construis l'APK après eux.

## Installer

```bash
adb install -r build/UsageForecast-<version>-android.apk
```

Ou télécharger l'APK depuis la page des releases du dépôt, l'ouvrir sur le téléphone et autoriser l'installation depuis cette source.

## Mises à jour dans l'application

Réglages (appui long sur Retour ou sur l'icône), puis **Mises à jour**. Un bandeau en bas de l'écran signale aussi une nouvelle version (une recherche par jour au plus).

1. L'application lit `releases/latest` du dépôt GitHub et ne retient que les fichiers `UsageForecast-X.Y.Z-android.apk` et `.apk.sha256` de ce dépôt, en https (`UpdatePolicy`, testé).
2. Elle télécharge l'APK (60 Mo au plus), **vérifie son SHA-256**, puis contrôle que l'archive est bien `com.alane.usageforecast`.
3. Elle la confie à `PackageInstaller`. La première fois, Android demande d'autoriser cette application à installer des mises à jour (« sources inconnues ») ; ensuite il ne reste qu'une confirmation.
4. Android refuse de lui-même toute version signée avec une autre clé : voir la section suivante.

## Signature et mises à jour

L'APK est signé avec la **clé de debug Android** (`~/.android/debug.keystore`, ou `UF_KEYSTORE`). C'est suffisant pour une installation hors Play Store. Android n'accepte une mise à jour que si la signature est **identique** : l'APK se construit donc toujours sur la machine du mainteneur, avec la même clé. Avec une autre clé, il faut désinstaller d'abord (le stockage de la PWA est perdu : réassocier ensuite).

## Limites

- Pas de Play Store, pas de mise à jour automatique : installer le nouvel APK par-dessus.
- Pas de notifications fermées (la PWA n'en a pas non plus).
- Le relais doit être en https avec un nom de domaine (pas d'IP, pas de `localhost`).
- Hors ligne au tout premier chargement : un écran propose de réessayer (la PWA n'est pas encore en cache).
