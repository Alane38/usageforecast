# Journal des changements

Format : une section par version, la plus récente en haut.

## 1.18.5 : 23 octobre 2026

### Corrigé
- **Android : le widget ne se mettait pas à jour.** Sa seule mécanique était une tâche `JobScheduler`, que les surcouches de batterie (Xiaomi, etc.) suspendent et qu'une mise à jour de l'APK efface. Trois déclencheurs de plus : la période du système (30 minutes, qui survit à une mise à jour), **l'ouverture de l'application** (le widget se rafraîchit aussitôt), et **un appui sur le pied du widget** (« ↻ actualiser »), qui actualise sans ouvrir l'application.

## 1.18.4 : 22 octobre 2026

### Corrigé
- **Planning de la semaine : les petits blocs affichent leur valeur.** Le bloc « avant auj. » et le dernier jour (partiel, souvent 8 % de la barre) restaient vides parce qu'ils étaient trop étroits pour le texte. Ils affichent maintenant leur pourcentage en plus petit, en gardant les proportions exactes. Nouvelle scène de contrôle visuel « fin de semaine ».

## 1.18.3 : 22 octobre 2026

### Corrigé
- Le formatage du jour dans les heures d'épuisement ne dépend plus du fuseau horaire de la machine (la 1.18.2 n'a pas été publiée : ses tests échouaient sur un serveur en UTC). Les tests passent maintenant sous plusieurs fuseaux.

## 1.18.2 : 22 octobre 2026 (non publiée, voir 1.18.3)

### Corrigé
- **Heure d'épuisement sans jour** : « 100 % vers 13 h 47 » pouvait désigner mardi, dans cinq jours. Le jour est maintenant indiqué dès qu'il n'est plus aujourd'hui (« demain 9 h 05 », « mar. 13 h 47 »), sur le Mac (ligne de rythme, alerte de session, export du statusline) et sur le téléphone (rythme et alertes).

## 1.18.1 : 22 octobre 2026

### Ajouté
- **Application mobile : bandeau « Nouvelle version disponible »** quand une nouvelle version de l'application est installée pendant qu'elle est ouverte (toucher pour actualiser), et vérification du serveur à chaque retour sur l'application (pas seulement au prochain lancement). 4 tests.
- **Android (APK)** : recherche d'une nouvelle version à chaque ouverture et chaque retour (au plus toutes les 15 minutes) au lieu d'une fois par jour.
- **Mac** : recherche d'une nouvelle version toutes les heures au lieu de toutes les 6 heures.

## 1.18.0 : 22 octobre 2026

### Ajouté
- **Application mobile : tirer vers le bas pour actualiser**, comme dans un navigateur (PWA installée, navigateur et APK). Un cercle suit le doigt quand la page est tout en haut, passe à l'accent au seuil, puis l'actualisation part au relâchement. Un geste horizontal (courbes) ou un défilement normal ne le déclenchent jamais. 4 tests sur la logique.

## 1.17.3 : 22 octobre 2026

### Corrigé
- **« Données anciennes » à tort sur le téléphone** : depuis la 1.14.2, le Mac n'envoyait rien quand les pourcentages n'avaient pas bougé (présence toutes les 20 minutes), alors que le téléphone juge une donnée périmée après 10 minutes. Le Mac envoie maintenant toutes les 5 minutes, valeurs identiques ou non (288 écritures par jour pour 1 000 autorisées).
- **Application mobile déjà installée** : les consignes d'installation n'apparaissent plus dans les Réglages quand l'application tourne installée (PWA autonome ou APK).

## 1.17.2 : 22 octobre 2026

### Ajouté
- **Application mobile : « Copier le lien d'association »** (Réglages, carte « Associer un autre appareil ») : retrouve le lien complet depuis un téléphone déjà associé, par exemple pour l'APK Android, sans repasser par le Mac. Le lien contient la clé : à ne partager avec personne.

## 1.17.1 : 22 octobre 2026

### Ajouté
- **Android sans bouton Retour (navigation par gestes)** : l'onglet Réglages de l'application affiche une carte « Application Android » (version, **Mises à jour**, **Adresse du relais et widget**), visible seulement dans l'APK ; un second raccourci « Mises à jour » est ajouté à l'appui long sur l'icône. Passerelle `NativeBridge` limitée à l'ouverture de ces deux écrans et au numéro de version.

## 1.17.0 : 22 octobre 2026

### Ajouté
- **Android : mise à jour dans l'application.** Réglages, Mises à jour : l'application lit la dernière release du dépôt, télécharge l'APK, **vérifie son SHA-256**, contrôle qu'il s'agit bien d'UsageForecast, puis passe par l'installateur d'Android (autorisation « sources inconnues » la première fois). Un bandeau signale une nouvelle version, une recherche par jour au plus. Seuls les fichiers du dépôt, en https, sont acceptés.
- **Android : widget d'écran d'accueil** (de 2x1 à 4x2) : session et semaine avec couleur de rythme, reset et âge de la donnée, mis à jour en arrière-plan (une lecture du relais toutes les 15 minutes au plus ; le téléphone n'écrit jamais). L'identifiant et la clé d'association, collés avec le lien complet, sont chiffrés par le Keystore d'Android.
- Tests Android : 35 (versions, URL de confiance, empreinte, déchiffrement avec le vecteur partagé avec le Mac et la PWA, lecture du snapshot).

## 1.16.1 : 22 octobre 2026

### Corrigé
- **Fausse alerte juste après un reset de session** : 2 points en 5 minutes donnaient « Rythme récent : 24 %/h · 100 % vers 14 h 30 » et une alerte « à ce rythme » alors que la session était à 2 %. Le rythme de session demande maintenant 15 minutes d'observation après un reset (le pourcentage est un entier, une si courte fenêtre ne dit rien).

## 1.16.0 : 22 octobre 2026

### Ajouté
- **Application mobile : les informations avancées du popover.** Courbe de **l'historique de la semaine sur 7 jours** (un point par heure) avec « Aujourd'hui : +x % de la semaine », détail **par modèle** (Sonnet, Fable), et carte « Compte » : utilisation supplémentaire payante (dépensé sur plafond), crédits gratuits, réinitialisations de limite disponibles. Calculés par le Mac, envoyés dans le snapshot chiffré ; un envoi plus ancien reste lisible. La courbe accepte maintenant des axes et une durée d'interruption configurables.

## 1.15.0 : 22 octobre 2026

### Ajouté
- **Application mobile : carte « Planning de la semaine »** sur l'accueil (budget conseillé jour par jour jusqu'au reset, le jour en cours se remplit de ce qui est déjà consommé), calculée par le Mac et envoyée dans le snapshot chiffré. Un téléphone qui reçoit un envoi plus ancien, sans planning, reste lisible. Il faut la 1.15.0 sur le Mac pour que le planning arrive.

## 1.14.4 : 22 octobre 2026

### Ajouté
- **Application mobile : bouton soleil/lune dans l'en-tête** pour passer du sombre au clair en un geste (le sombre reste le thème par défaut ; le choix est mémorisé). Publié en redéployant le relais : aucune mise à jour de l'APK nécessaire.

## 1.14.3 : 21 octobre 2026

### Corrigé
- **Budget du jour faux le jour d'un reset hebdomadaire** : la consommation d'avant le reset (fin de l'ancienne semaine) était comptée dans « Aujourd'hui », d'où « 17 % sur 13 % conseillés, dépassé » alors que 6 % seulement avaient été consommés dans la nouvelle semaine. La consommation du jour repart maintenant de zéro à la remise à zéro.

## 1.14.2 : 21 octobre 2026

### Corrigé
- **Synchro mobile : limite gratuite de Cloudflare dépassée.** Un envoi par minute faisait 1 440 écritures par jour pour 1 000 autorisées : le relais refusait tout après environ 16 h 40 jusqu'à minuit UTC. Désormais au plus un envoi toutes les 5 minutes (288 par jour), rien si les valeurs n'ont pas changé (envoi de présence toutes les 20 minutes), envoi immédiat sur demande, et plafond de sécurité de 800 par jour.
- Rouvrir l'application (Applications, Spotlight) ouvre sa fenêtre, même si l'icône de la barre de menu est masquée.

## 1.14.1 : 20 octobre 2026

### Ajouté
- **Nouveau nom : UsageForecast**, partout : application (`UsageForecast.app`), exécutable, icône, archives de release (`UsageForecast-X.Y.Z-arm64.zip`), dossier de données (`~/Library/Application Support/UsageForecast`), relais mobile (`usageforecast-relay`).
- **Assistant de premier lancement** : s'ouvre une fois si aucune donnée n'arrive, propose le réglage du statusline de Claude Code (à copier) ou le cookie claude.ai, et montre en direct si les données arrivent. Rouvrable depuis Réglages > Général.
- **Statusline lu à un emplacement standard** (`~/Library/Application Support/UsageForecast/statusline.json`) en plus de l'ancien chemin : la copie la plus récente l'emporte.
- **Installateur en une ligne** (`docs/install.sh` (servi à `https://alane38.github.io/usageforecast/install.sh`)) : télécharge la dernière release, vérifie son SHA-256, contrôle l'identifiant de l'archive, installe dans Applications. `--uninstall` retire l'app, `--purge` met aussi les données à la Corbeille.
- **Script de captures** (`scripts/make-screenshots.sh`) : régénère les images du README et du site à partir des écrans de démonstration.
- **Application Android (APK)** : coque WebView de l'application mobile (`android/`, `scripts/build-apk.sh`). Au premier lancement elle demande l'adresse de ton relais, la mémorise, puis ouvre la PWA en plein écran ; seule la permission réseau est demandée, https uniquement, navigation limitée au domaine du relais. Signée avec la clé de debug Android (installation hors Play Store ; les mises à jour exigent la même clé).
- **Site** (`docs/`, servi par GitHub Pages), `SECURITY.md`, modèles d'issue.

### Modifié
- **Identifiant technique renommé** (`com.alane.usageforecast`, comme l'application Android), ainsi que le relais mobile (`usageforecast-relay`), le titre de l'application mobile et les constantes de chiffrement : un Mac déjà appairé doit réassocier son téléphone.
- **Code réécrit** : l'ensemble de l'analyse des réponses, des crédits, des réglages, du suivi des services, de la récupération, de la fenêtre, du popover et des raccourcis est réécrit, avec des fonctions plus courtes et des retours anticipés (comportement et textes inchangés : 337 tests et 22 rendus de référence identiques).
- Anciens scripts de DMG, ancien logo et ancienne chaîne de build supprimés ; plus aucun lien vers l'ancien projet.
- Dépôt renommé `Alane38/usageforecast`. README réécrit pour le public.
- Mobile : le champ de l'adresse du relais n'affiche plus d'exemple qui ressemble à une valeur ; astuce d'installation Firefox corrigée ; icônes de l'application générées depuis le même dessin que le Mac ; thème sombre par défaut.

## 1.13.0 : 20 octobre 2026

### Ajouté
- **Application mobile (PWA) pour Android** : accueil (points d'attention, session et semaine avec repère de rythme et prévision, budget du jour, crédits, historique 24 h tactile, état des services), **Statistiques** identiques à celles du Mac (14 jours, heures, jours de la semaine, semaines à jours égaux, journal complet, fiabilité) et Réglages (état de la synchro, thème clair/sombre/auto, installation). Elle s'installe depuis Chrome (« Ajouter à l'écran d'accueil »), s'ouvre en plein écran et **marche hors ligne** avec les dernières données, dont elle indique l'âge. Audit Lighthouse mobile : 100 en accessibilité, bonnes pratiques et SEO.
- **Chiffrement de bout en bout** : le Mac chiffre un snapshot (AES-256-GCM) et l'envoie une fois par minute à un petit **relais Cloudflare Worker** (gratuit, sur ton compte) qui ne stocke que du texte illisible pendant 30 jours. La clé ne voyage que dans le code QR que tu scannes toi-même (dans le fragment du lien, jamais envoyé à un serveur). Jamais de cookie ni de compte dans les données.
- **Onglet « Mobile »** dans les Réglages : activer la synchro (désactivée par défaut : rien ne quitte la machine sinon), adresse du relais, **code QR d'association** (masqué après une minute, décodé et vérifié), copier le lien, **Réassocier** (nouvelle clé, coupe l'ancien téléphone).
- `mobile/` : relais (`relay/`), application (`pwa/`), scripts (`bun run deploy` crée le stockage et publie le Worker, `dev`, `seed`), documentation `mobile/README.md` et ADR 002. Tests : 65 en JavaScript (dont le vecteur de chiffrement et les cas de statistiques partagés avec Swift), 320 en Swift.
- **Audit visuel complet de l'application mobile** (320, 360, 390, tablette et paysage, clair et sombre, états normal, alerte, peu de données, vide, hors ligne) : un danger à 90 % et plus ou un avertissement ne sont plus grisés par l'âge des données ; en-tête sur deux lignes, carte crédits qui ne casse plus avec un long titre, étiquettes de l'historique et des jours lisibles, espaces insécables entre nombres et unités, journal paginé (14 jours puis « Afficher plus »), barre du bas compacte en paysage, en-tête aligné sur la colonne en tablette.
- CI : un job `mobile` (tests et fabrication du relais) qui tourne sur Ubuntu, donc sans attendre une machine macOS.

### Modifié
- La prévision envoyée au statusline expose aussi `expectedPercent` (le repère de rythme de la jauge) ; `ForecastExport` est factorisé (`currentForecast`) pour servir le statusline et le téléphone.
- Correctif d'affichage : 9,96 points s'écrit « 10 pts » et non « 10,0 pts » (Mac et téléphone).

### À faire pour l'utiliser
- Déployer le relais une fois : `cd mobile && npx wrangler login && bun run deploy`, puis coller son adresse dans Réglages > Mobile. Les notifications quand l'application est fermée ne sont pas encore faites.

## 1.12.0 : 20 octobre 2026

### Ajouté
- **Onglet « Statistiques »** dans les Réglages : ton rythme habituel, lu dans le journal quotidien.
  - **Quatre chiffres clés** : aujourd'hui, moyenne par jour, jour record, heure de pointe.
  - **Les 14 derniers jours** : colonnes de points de limite hebdomadaire consommés, avec la moyenne, le maximum et aujourd'hui étiquetés, les journées incomplètes en plus clair, et une info-bulle détaillée au survol (points de semaine et de session, pic, heures actives, couverture).
  - **Quand tu travailles** : part des jours où tu es actif à chaque heure (28 derniers jours complets), heure de pointe étiquetée.
  - **Par jour de la semaine** : consommation moyenne de chaque jour ; barres pleines à partir de 3 jours observés, claires (« indicatif ») avant.
  - **Cette semaine et la précédente, à jours égaux** : seuls les jours complets écoulés comptent des deux côtés, pour ne pas comparer une semaine entamée à une semaine entière.
  - **Journal complet** : le tableau jour par jour (semaine, session, pic, heures actives, couverture), la même donnée que les graphiques.
  - **Fiabilité** en quatre crans (très peu de données, en construction, correct, fiable) avec une phrase qui explique ce qu'on peut en attendre ; **bouton « Afficher le fichier »**.
- Conception selon les règles de visualisation : une seule teinte pour les grandeurs (vert/jaune/rouge réservés aux états), barres de 22 pt au plus à bout arrondi de 4 pt, étiquettes seulement sur les extrêmes, texte jamais coloré comme les barres, mode clair et sombre, VoiceOver sur chaque colonne.
- Seuil d'exploitation : une journée compte à partir de 5 h de relevés ; aujourd'hui, incomplet, n'entre jamais dans les moyennes.
- Outils de démonstration : `--demo-days N` (taille du journal fictif), `--demo-day-shift N` (décale l'horloge figée), `--open-journal`. Quatre écrans de plus dans la comparaison visuelle (19 au total, tous à 0,000 %).

## 1.11.1 : 20 octobre 2026

### Corrigé
- **Lenteur croissante du popover quand on survole la courbe ou clique sur un bouton.** Cause : à chaque dessin, la courbe recalculait son plafond d'axe pour chacun de ses points (calcul quadratique). Avec 24 h d'historique (1 440 relevés), un dessin coûtait **529 ms** ; il coûte maintenant **1,6 ms**. Plus l'historique grossissait dans la journée, plus ça ramait, d'où « fluide au début ».
- Le tracé est maintenant isolé de la couche de survol : passer la souris sur la courbe ne redessine plus la courbe, seulement l'info-bulle.

### Ajouté
- Outils de mesure : `--bench-chart [nombre de relevés]` (coût d'un dessin de la courbe) et `--time` (durée du rendu complet d'une capture).

## 1.11.0 : 20 octobre 2026

### Ajouté
- **Journal quotidien** (`daily.jsonl`) : une ligne par jour dans `~/Library/Application Support/UsageForecast/` (points de semaine et de session consommés, pic de session, heures d'activité, nombre de relevés), **gardée 400 jours** au lieu des 8 jours de l'historique minute par minute. C'est la base pour apprendre ton rythme habituel (par jour de la semaine, sur des mois). Mis à jour toutes les 10 minutes, droits 0600, rien ne quitte la machine.
- **Reprise de l'existant** : au premier lancement, tous les relevés déjà présents dans `history.jsonl` deviennent des résumés quotidiens avant d'être purgés ; un résumé plus complet n'est jamais écrasé par un plus partiel (le jour le plus ancien de la fenêtre de 8 jours, tronqué, garde son résumé).
- Réglages > Général : « Journal quotidien — N jours enregistrés depuis le … ».

### À venir
- Exploitation du journal (rythme habituel par jour de la semaine, budget du jour qui en tient compte, alerte « au-dessus de ton lundi habituel ») : une fois 3 à 4 semaines accumulées.

## 1.10.2 : 19 octobre 2026

### Modifié
- **Un seul mot de passe par mise à jour au lieu de deux (voire quatre)** : les deux cookies (claude.ai et Console) vivent maintenant dans **un seul élément du trousseau**, lu une seule fois par lancement. macOS lie l'autorisation du trousseau à l'empreinte du binaire, par élément ; avec un seul élément, une seule demande par nouvelle version.
- **Migration automatique au premier lancement** : les deux anciens éléments sont lus, regroupés dans le nouvel élément, puis supprimés. Cette fois-ci seulement, macOS peut donc redemander l'autorisation pour les anciens éléments.
- Un accès refusé au trousseau n'écrase plus rien : le contenu n'est ni mis en cache ni réécrit tant que la lecture n'a pas réussi.

## 1.10.1 : 19 octobre 2026

### Retiré
- **Jour exceptionnel** (ajouté en 1.9.1) : il ne servait qu'à masquer le jaune et le rouge du budget du jour, qui n'est de toute façon qu'un repère. Le budget redevient le même tous les jours ; le réglage `exceptional_days` est supprimé de l'app installée.

### Modifié
- **Horloge fixe en mode démonstration** (`AppClock`) : les captures `--demo` se font toujours le 19/10/2026 à midi, donc la comparaison visuelle (`scripts/visual-check.sh`, tolérance 0,1 %) donne 0,000 % d'écart à toute heure et tous les jours. Avant, les décomptes et les jours du planning la faisaient varier de 0,1 à 2,6 %.

## 1.10.0 : 19 octobre 2026

### Ajouté
- **Mise à jour en un clic** : le bandeau « Version X disponible » propose « Installer » (et « Notes »). L'app télécharge le zip de la release GitHub, **vérifie la somme SHA-256, l'identifiant, la version et la signature**, puis un script attend sa fermeture, **met l'ancienne application à la Corbeille** (jamais supprimée), installe la nouvelle et la relance. Au moindre doute, rien n'est touché et le bandeau explique pourquoi (« somme SHA-256 ne correspond pas… »). Seuls les téléchargements HTTPS depuis les releases de ce dépôt sont acceptés ; une release sans somme SHA-256 n'est pas installable en un clic.
- Options de développement `--test-install` (même chemin sur des fichiers locaux, sans quitter) et `--demo-update working|failed`. Fichier `AppDelegate+CommandLine.swift` pour les outils en ligne de commande.

### Modifié
- Tolérance de la comparaison visuelle resserrée à 0,1 % de pixels (à 0,4 %, le changement d'un bouton passait inaperçu) ; les captures de démonstration ne lisent plus les vrais jours exceptionnels.

### À savoir
- Les releases de la CI sont signées « ad hoc » (pas avec ton certificat local) : après une mise à jour en un clic, macOS peut redemander l'Accès complet au disque et le trousseau. Pour toi, `scripts/release.sh` garde l'identité stable.

## 1.9.1 : 19 octobre 2026

### Ajouté
- **Jour exceptionnel** : un jour déclaré exceptionnel (développement intensif, journée de rattrapage) garde sa consommation affichée mais sans jaune, sans rouge ni « dépassé » : « Aujourd'hui : 45 % sur 39 % conseillés · jour exceptionnel ». Les jours se déclarent dans le réglage `exceptional_days` (liste de dates AAAA-MM-JJ), sans bouton pour l'instant.

## 1.9.0 : 19 octobre 2026

### Ajouté
- **Budget du jour** : « Aujourd'hui : 9 % sur 24 % conseillés », en gris dans le budget, en jaune au-delà de 80 %, en rouge avec « dépassé de N % » et « les jours suivants auront d'autant moins ». Le budget est calculé à minuit : il ne rétrécit pas quand on consomme, donc le dépassement reste visible.
- **Planning de la semaine depuis minuit** : le bloc « auj. » est le budget complet de la journée, avec une jauge qui se remplit (« 9 / 22 % »), rouge quand il est dépassé. Le gris à gauche devient « avant auj. ».
- **Prévenir des nouvelles versions** : lecture de la dernière release GitHub toutes les 6 h (requête publique, aucune donnée envoyée), bandeau « Version X disponible · Voir » dans le popover et une notification par version. Désactivable, avec « Rechercher maintenant ».
- **Organisation suivie** : si le compte claude.ai a plusieurs organisations (personnel, équipe), un sélecteur dans Réglages > Connexions choisit laquelle suivre (par défaut, la dernière utilisée sur claude.ai).
- **CI GitHub** : tests et compilations (développement et release) à chaque push. **Release GitHub** avec l'application zippée et sa somme SHA-256 à chaque tag `vX.Y.Z` (non notarisée : clic droit > Ouvrir).
- **Régression visuelle** : `scripts/visual-check.sh` compare 15 écrans de démonstration (clair et sombre) à des références (`tests/visual/ref`), `--update` après un changement voulu.

### Modifié
- `scripts/test.sh` s'arrête si la compilation des tests échoue (avant, il pouvait exécuter un ancien binaire).
- Carte « Budget d'aujourd'hui » : le chiffre est le budget conseillé du jour, plus la moyenne par jour.
- Deux fichiers redécoupés pour rester sous 200 lignes (`SettingsGeneralTab`, `UsageManager+DisplaySettings`).

## 1.8.0 : 19 octobre 2026

### Modifié
- **Première version de déploiement : secrets dans le trousseau macOS.** Les deux cookies (claude.ai et Console) quittent le fichier de développement au premier lancement, puis le fichier est supprimé. macOS peut demander une fois l'autorisation du trousseau à chaque nouvelle version ; c'est le prix de la protection.
- **`UsageForecast.swift` (1 560 lignes) découpé en 13 fichiers de moins de 200 lignes** : `AppDelegate` (+ Shortcuts, Popover), `UsageManager` (+ Settings, Fetch, Credits, Parsing), `StatusManager`, `StatusModels`, `PasteableText`, `AppEntry`, `AppExtensions`. Aucun changement de comportement : mêmes fonctions, mêmes propriétés publiées, mêmes journaux.
- README aligné sur la nouvelle structure.

### Ajouté
- Options de développement `--import-browser` (import Zen/Firefox en ligne de commande, statuts seulement) et `--wait` (délai des captures).

## 1.7.0 : 19 octobre 2026

### Modifié
- **Mode clair lisible** : les couleurs d'état (vert, ambre, rouge) ont une version plus profonde sur fond clair (contraste d'au moins 4,5:1 pour le texte). Avant, le vert et le jaune étaient presque illisibles sur blanc, et le texte blanc du planning disparaissait sur fond pâle.
- **Cartes : le rythme est dit en toutes lettres** (« Trop rapide », « Sous le rythme ») sous chaque anneau, au lieu de la seule couleur. Les deux cartes ont la même hauteur.
- **Planning de la semaine** : bloc « utilisé » étiqueté, étiquettes des jours écartées quand elles se chevaucheraient (fin de semaine chargée), texte du bloc à encre normale.
- **Courbe** : la valeur finale est posée sur une pastille et ne se superpose plus au tracé ; textes d'axe à 11 pt.
- Session à 0 % sans fenêtre ouverte : « Aucune session en cours » au lieu d'un 0 % sans explication.

### Ajouté
- **VoiceOver et aide** sur les jauges et anneaux ; info-bulle de la jauge qui explique le trait (rythme régulier) et la zone claire (prévision).
- Option de capture `--light` pour vérifier le rendu en mode clair.

## 1.6.6 : 19 octobre 2026

### Modifié
- **Courbe d'historique refaite selon les bonnes pratiques de visualisation** : ligne de 2 pt, lavis léger (10 %) sous la courbe, grille pleine et discrète (plus de pointillés), point final de 8 pt avec anneau, étiquettes ciblées (valeur finale, pic), texte en encre discrète.
- **Axe vertical adaptatif et toujours étiqueté** (20, 50 ou 100 %) : une session basse n'est plus écrasée en bas, et l'axe repasse à 100 % dès que l'usage monte.
- **Survol** : repère vertical et info-bulle « heure · valeur » sur le relevé le plus proche.
- Description pour VoiceOver (durée, valeur de départ, valeur finale, pic).

## 1.6.5 : 19 octobre 2026

### Modifié
- **Courbe d'historique** : l'axe colle exactement à la durée des relevés (de 10 minutes à 24 h) au lieu de paliers ronds, donc la courbe remplit toute la largeur dès les premières minutes. Le titre et le libellé gauche donnent la durée réelle (« Historique · 19 min », « il y a 19 min »).
- Repères **100 %** et **50 %**, point sur la valeur actuelle, et valeur de la session affichée à droite.

## 1.6.4 : 19 octobre 2026

### Corrigé
- **Courbe d'historique écrasée dans un coin** quand l'historique est jeune : l'échelle s'adapte maintenant à la durée disponible (1, 3, 6, 12 ou 24 h) et le titre l'indique (« Historique · 3 h »).
- Le tracé est **interrompu à chaque trou de plus de 30 minutes** (app fermée, veille) : plus de longue pente entre deux relevés distants.

## 1.6.3 : 19 octobre 2026

### Corrigé
- **Fausse alerte « limite de la semaine »** : le rythme hebdomadaire se calculait sur les 3 dernières heures, donc une rafale de travail était extrapolée à toute la semaine, nuits comprises (4,7 %/h tenus 35 h, alors que la projection sur la semaine donnait 71 %). Il se calcule maintenant sur **24 h avec au moins 12 h d'observation** ; en dessous, l'app utilise la moyenne de la semaine.
- Les messages disent qu'il s'agit d'une hypothèse (« si ça continue ») et donnent la **période de blocage** (« de mardi à 2 h 26 à mercredi à 14 h 00, soit environ 35 h »).

## 1.6.2 : 19 octobre 2026

### Modifié
- **Alertes de limite plus explicites** : le titre dit de quelle limite il s'agit (« Limite de la semaine atteinte mercredi à 2 h 15 »), le texte donne ton rythme, la **durée pendant laquelle tu serais bloqué** et, pour la semaine, le **budget par jour à tenir**.
- Heures sans zéro initial (« 0 h 03 » au lieu de « 00 h 03 »), durées courtes (« 1 h 20 », « 38 h », « 3 j 4 h »).

### Nouveau
- Bouton **« Voir des exemples d'alertes »** dans Réglages > Alertes, pour lire les textes avant qu'une vraie alerte arrive.

## 1.6.1 : 19 octobre 2026

### Nouveau
- Quand macOS bloque la lecture du navigateur (Firefox, Chrome), trois boutons guident l'autorisation : **ouvrir l'Accès complet au disque**, **afficher l'app dans le Finder** (pour la glisser dans la liste), **relancer l'app**. macOS ne permet pas à une app de s'accorder cet accès elle-même : seul l'interrupteur reste à activer.

### Modifié
- Onglet Connexions réorganisé : l'import depuis le navigateur passe en premier, chaque rapport n'apparaît qu'à sa place.

## 1.6.0 : 19 octobre 2026

### Nouveau
- **Alertes anticipées** (réglables une par une) : « tu atteindras 100 % vers 18 h 40 » avant que ça arrive, part de session ou de semaine **inutilisée** avant un reset, **session libérée** après la limite, **session claude.ai expirée**, **crédits API qui expirent** (à 5, 2 et 1 jour). Chaque alerte n'est envoyée qu'une fois.
- **Historique local** (un relevé par minute, 8 jours, fichier réservé à l'utilisateur) : courbe de la session sur 24 h, consommation du jour (« +9 % de la semaine »), **rythme récent** (par heure) et heure d'atteinte de 100 % à ce rythme.
- **Planning de la semaine** : part de la limite utilisable chaque jour jusqu'au reset, au prorata des heures.
- **Export de la prévision** (`forecast.json`) pour le statusline de Claude Code, avec une ligne prête à afficher (réglable dans l'onglet Général).

### Modifié
- Notifications via UserNotifications (l'API dépréciée n'est plus utilisée) : zéro avertissement de compilation.

## 1.5.0 : 19 octobre 2026

### Nouveau
- Design réglable : popover en **jauges** (barre avec repère de rythme et prévision) ou en **cartes** (budget du jour, anneaux).
- Trois styles de barre de menu : étincelle, **double anneau** (semaine à l'extérieur, session à l'intérieur), **deux valeurs**.
- Valeur affichée réglable pour chaque style : session, hebdo, la plus haute, les deux. Option « icône seule » et décompte avant reset.
- Vraie **fenêtre de réglages** à cinq onglets (Affichage, Connexions, Crédits, Alertes, Général), tout en français.
- Rafraîchissement **toutes les minutes**, ralenti à 5 min tant que l'API refuse, retour à 60 s au premier succès.
- Popover ancré en haut à droite si l'icône est masquée par une barre de menu pleine.

### Sécurité et stockage
- **Développement** : cookies dans un fichier protégé (0600), aucune fenêtre du trousseau.
- **Release** (`scripts/release.sh`) : cookies dans le trousseau macOS. Voir `docs/adr/001-stockage-des-secrets.md`.
- Bouton d'import de l'ancien trousseau (une demande de mot de passe, à l'initiative de l'utilisateur).

### Corrigé
- Barres : bouts arrondis seulement sur la piste, remplissage et voile à plat.
- Libellé de rythme sans pastille et cohérent avec la couleur (« Usage élevé », « Limite proche »…).
- Au Refresh, un statusline ancien n'écrase plus les valeurs fraîches.
- Retrait de l'ancienne vue de 800 lignes et du code mort.

## 1.4.0 : 18 octobre 2026

### Nouveau
- Source **statusline de Claude Code** (`rate_limits`) : données sans cookie ni appel réseau.
- **Prévisions** : fin de semaine estimée, budget par jour, rythme de la session de 5 h avec heure d'atteinte de 100 %.
- **Crédits API de la Console** (Max/Team) : solde, dépense, échéance, budget par jour, avec saisie manuelle en repli.
- Import des sessions depuis Zen/Firefox, âge des données affiché, diagnostic du trousseau (`--diagnose`).
- Icône de l'application (jauge et étincelle, générée par `scripts/make_icon.py`).
- Build local **sans Xcode** (`scripts/build.sh`, SDK 26, signature par certificat local stable) et tests (`scripts/test.sh`).

### Sécurité
- Cookie dans le Keychain avec migration depuis l'ancien stockage en clair.
- Plus de réponse brute de l'API ni d'identifiants dans les journaux ; aucun flux distant de bannières.

### Corrigé
- Le popover suit la hauteur de son contenu (l'en-tête n'est plus rogné).
