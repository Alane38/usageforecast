# UsageForecast pour Android (APK)

Une **coque WebView** qui enveloppe la PWA de `mobile/pwa`. Pourquoi pas une TWA : la PWA est servie par le Worker Cloudflare de chaque utilisateur (une adresse différente pour chacun), donc aucun domaine fixe à lier dans un APK public.

- Premier lancement : l'écran « Adresse du relais » demande l'adresse (`https://….workers.dev`) **ou** le lien d'association complet (`https://<relais>/#v1.…`). L'origine est mémorisée dans des préférences privées ; la PWA s'ouvre ensuite en plein écran.
- **Le fragment du lien contient la clé** : il sert au seul premier chargement, reste en mémoire, n'est jamais écrit, journalisé ni envoyé ailleurs. La PWA le range ensuite dans son propre stockage.
- Changer d'adresse ou chercher une mise à jour : **onglet Réglages de l'application, carte « Application Android »** (la seule voie évidente avec la navigation par gestes) ; sinon appui long sur Retour, ou appui long sur l'icône de l'application puis « Adresse du relais » (seule voie avec la navigation par gestes). Changer de relais ou « Oublier » efface le stockage de la PWA (donc l'ancienne clé).
- JavaScript, localStorage, IndexedDB et service worker sont actifs : la PWA marche hors ligne avec ses dernières données.
- Sécurité : permissions `INTERNET`, `ACCESS_NETWORK_STATE` (tâche du widget « réseau requis ») et `REQUEST_INSTALL_PACKAGES` (mise à jour intégrée), aucun trafic en clair, sauvegarde Android désactivée (le stockage contient la clé), liens vers un autre domaine ouverts dans le navigateur, aucun journal.
- Thème sombre par défaut, comme la PWA. Aucune bibliothèque tierce (WebView et framework Android seuls ; JUnit pour les tests).

## Widget

Un widget d'écran d'accueil (redimensionnable de 2x1 à 4x2, thème sombre) affiche la **session** et la **semaine** : pourcentage, couleur selon le rythme (vert, ambre, rouge, mêmes seuils que la PWA), « reset dans … » et l'âge de la donnée, avec « données anciennes » au-delà de 10 minutes. Toucher le widget ouvre l'application. Sans relais ou sans clé, il l'écrit (« Colle le lien d'association pour activer le widget ») ; hors ligne, il garde la dernière valeur avec son âge.

Pour l'activer, colle le **lien d'association complet** (`https://<relais>/#v1.<id>.<clé>`) dans l'écran « Adresse du relais » : l'adresse seule ne suffit pas, car la coque ne voit jamais la clé de la PWA (elle vit dans le stockage de la WebView).

**Ce que le widget stocke, et pourquoi**
- `association` : l'identifiant du coffre et la clé AES-256, **chiffrés par une clé AES-GCM du Android Keystore** (non exportable : son matériel ne quitte pas le Keystore, donc une copie des préférences, une sauvegarde ou un `adb pull` ne donne que du texte inutilisable hors de l'appareil). Il faut la clé pour lire les données, et l'identifiant est lui-même un secret de lecture du relais. Jamais journalisés, jamais dans un Intent, jamais dans un `toString`.
- `widget` : le dernier blob **chiffré** reçu du relais, son horodatage `x-updated-at` et deux indicateurs (hors ligne, coffre vide). Jamais de clair sur disque : il est déchiffré à chaque affichage.
- « Oublier ce relais » et le changement de relais effacent ces deux stockages et la clé du Keystore, puis redessinent le widget.

**Fonctionnement** : un `JobScheduler` périodique (15 min, réseau requis, sans dépendance tierce) fait un seul `GET <relais>/v1/<id>` (https, délais de 8 s, 256 Ko maximum, pas de redirection ; le corps n'est pas relu si `x-updated-at` n'a pas changé). Le téléphone n'écrit jamais sur le relais : le quota d'écriture quotidien ne concerne que le Mac. La tâche est reprogrammée à l'ouverture de l'application, à l'ajout du widget et après un redémarrage (le lanceur rappelle alors le widget) : **`RECEIVE_BOOT_COMPLETED` n'est donc pas demandée**, la permission reste `INTERNET` seule. Limite : Android peut espacer les tâches périodiques (économie d'énergie), l'âge affiché dit toujours la vérité.

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

### Si le widget n'avance pas (Xiaomi, Samsung, etc.)

Le widget se rafraîchit : au système toutes les 30 minutes, par une tâche de fond toutes les 15 minutes, à l'ouverture de l'application et à l'appui sur « ↻ actualiser ». Les surcouches de batterie suspendent souvent les tâches de fond d'une application inactive. Sur Xiaomi : Paramètres, Applications, UsageForecast, **Économiseur de batterie : Aucune restriction**, et **Démarrage automatique** activé ; épingler l'application dans les applications récentes aide aussi. Après une mise à jour de l'APK, appuie une fois sur « ↻ actualiser ».

## Signature et mises à jour

L'APK est signé avec la **clé de debug Android** (`~/.android/debug.keystore`, ou `UF_KEYSTORE`). C'est suffisant pour une installation hors Play Store. Android n'accepte une mise à jour que si la signature est **identique** : l'APK se construit donc toujours sur la machine du mainteneur, avec la même clé. Avec une autre clé, il faut désinstaller d'abord (le stockage de la PWA est perdu : réassocier ensuite).

## Limites

- Pas de Play Store, pas de mise à jour automatique : installer le nouvel APK par-dessus.
- Pas de notifications fermées (la PWA n'en a pas non plus).
- Le relais doit être en https avec un nom de domaine (pas d'IP, pas de `localhost`).
- Hors ligne au tout premier chargement : un écran propose de réessayer (la PWA n'est pas encore en cache).
