# Application mobile de UsageForecast

Surveille ton usage de Claude depuis ton téléphone : jauges de session et de semaine, prévisions, budget du jour, crédits API, historique 24 h et les statistiques de ton rythme. Une **application web installable (PWA)** : elle s'ajoute à l'écran d'accueil d'Android (et d'iPhone), s'ouvre en plein écran, marche hors ligne avec les dernières données et se met à jour toute seule. Pas de Play Store, pas d'APK à signer.

```
 Mac (UsageForecast)                Relais (Cloudflare Worker)              Téléphone (PWA)
 ───────────────────                 ──────────────────────────              ───────────────
 snapshot JSON  ──chiffré AES-256──▶  coffre <id> : texte illisible  ──────▶  déchiffre avec la clé
 (1 envoi / 5 min)                   (30 jours, jamais lu)                    affiche, garde en cache
        ▲                                                                           │
        └──── la clé ne voyage que dans le code QR que tu scannes toi-même ─────────┘
```

## Sécurité : ce que le relais voit

**Rien.** Le Mac chiffre le snapshot (AES-256-GCM) avant de l'envoyer ; la clé n'existe que sur le Mac et sur le téléphone.

- La clé voyage dans le **fragment** du lien d'association (`https://relais/#v1.<id>.<clé>`) : un navigateur n'envoie jamais le fragment à un serveur.
- Le coffre est désigné par un identifiant de 128 bits impossible à deviner ; l'écriture exige un jeton (HMAC dérivé de la clé) dont le relais ne garde que l'empreinte.
- Les données expirent au bout de 30 jours ; le relais refuse tout ce qui n'est pas du base64url de moins de 256 Ko.
- La page est servie avec une politique de sécurité stricte (aucun script externe, aucun contenu inséré en ligne) et tout le DOM est construit sans `innerHTML`.
- **Jamais** envoyés : tes cookies, ton compte, tes messages. Seulement des pourcentages, des prévisions, le solde des crédits, l'état des services et le journal quotidien (120 jours).
- Côté téléphone, la clé est dans le stockage local de l'application : verrouille ton téléphone. Perdu ou prêté ? Dans UsageForecast, **Réglages > Mobile > Réassocier** change la clé et coupe l'ancien appareil.

## Mettre en place (une fois, environ 5 minutes)

1. **Créer le relais** (gratuit, sur ton compte Cloudflare) :
   ```bash
   cd mobile
   npx wrangler login      # une seule fois : ouvre ton navigateur
   bun run deploy          # crée l'espace de stockage, publie le Worker, affiche son adresse
   ```
   `bun run deploy -- --dry-run` montre les étapes sans rien publier. Relancer le script est sans risque : il réutilise l'espace de stockage existant (son identifiant reste dans `relay/dist`, ignoré par git) et republie le Worker.
2. **Sur le Mac** : UsageForecast > Réglages > **Mobile**. Colle l'adresse du relais, active la synchro, clique « Afficher le code d'association ».
3. **Sur le téléphone** : scanne le code avec l'appareil photo. L'application s'ouvre déjà associée. Menu ⋮ du navigateur (Chrome ou Firefox) > « Installer » ou « Ajouter à l'écran d'accueil » (Chrome propose aussi un bouton « Installer » dans les Réglages de l'application).
   Sans caméra : « Copier le lien » sur le Mac, puis colle-le sur l'écran d'association.

## Ce que montre l'application

- **Accueil** : points d'attention, session et semaine (jauge avec repère de rythme et prévision), budget du jour, crédits, historique 24 h (touche la courbe pour une valeur), état des services.
- **Statistiques** : les mêmes que l'onglet du Mac (14 jours, heures de travail, jours de la semaine, semaines à jours égaux, journal complet), avec leur niveau de fiabilité. Touche une colonne pour le détail.
- **Réglages** : état de la synchro, thème (sombre par défaut, quel que soit le mode du téléphone ; clair et auto au choix), installation, oublier l'appareil.
- **Hors ligne** : l'application s'ouvre avec les dernières données et indique leur âge.

Pas encore : les **notifications** quand l'application est fermée (elles demandent un service Web Push ; c'est la suite logique).

## Développer

```bash
cd mobile
bun test                 # 65 tests : chiffrement, formats, statistiques, alertes, stockage, synchro, relais
bun run dev              # relais + application sur http://localhost:8788
bun run seed             # y dépose un snapshot de démonstration chiffré (lien d'association stable)
```

| Dossier | Rôle |
|---|---|
| `pwa/lib/` | Logique pure, testée : `crypto`, `format`, `insights` (port de `DailyInsights.swift`), `attention`, `snapshot`, `store`, `sync` |
| `pwa/js/` | Interface : `app.js` (orchestration), `views/` (accueil, statistiques, réglages, association), `charts.js` (SVG tactile), `dom.js` |
| `pwa/css/`, `sw.js`, `manifest.webmanifest` | Design clair/sombre, hors-ligne, installation |
| `relay/src/worker.js` | Le relais (PUT/GET d'un coffre chiffré + sert l'application) |
| `scripts/` | `build-relay` (embarque l'application dans le Worker), `dev-server`, `seed-demo`, `deploy-relay` |

Côté Mac : `app/MobileSnapshot.swift` (format), `MobileCrypto.swift`, `MobileUploader.swift`, `UsageManager+MobileSync.swift`, `SettingsMobileTab.swift`, `QRCode.swift`.

**Les deux langages doivent rester d'accord** : les tests Swift et JavaScript partagent un vecteur de chiffrement fixe (`MobileCrypto` ↔ `crypto.test.js`) et les mêmes cas de statistiques. Pour essayer le vrai chemin Mac vers téléphone : `bun run dev`, `bun run seed`, ouvrir le lien affiché, puis lancer l'app Mac avec `--demo --snapshot x.png --mobile-upload http://localhost:8788`.

**Faire évoluer le snapshot** : ajouter un champ optionnel ne casse rien (le téléphone ignore l'inconnu). Changer le sens d'un champ ou en retirer un exige d'augmenter `MobileSnapshot.currentVersion` et `SUPPORTED_VERSION` ; un téléphone plus ancien affiche alors « mets à jour cette application ».

## Dépannage

| Symptôme | Cause probable |
|---|---|
| « Ton Mac n'a encore rien envoyé » | Synchro désactivée, adresse du relais fausse, ou Mac éteint : regarde « État » dans Réglages > Mobile |
| « Impossible de déchiffrer » | La clé a changé (Réassocier) : rescanne le code |
| « Ce coffre est lié à une autre clé » (sur le Mac) | Le coffre a été créé avec une autre clé : clique « Réassocier » |
| Données « anciennes » | Le Mac est en veille ou UsageForecast est fermé : le téléphone ne peut afficher que ce que le Mac a envoyé |
