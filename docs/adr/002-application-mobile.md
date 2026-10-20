# 002 : application mobile, PWA et relais chiffré de bout en bout

## Contexte
Alane veut tout surveiller aussi depuis son téléphone, un Android. Les données (limites, prévisions, journal quotidien) n'existent que sur le Mac :
le téléphone ne peut pas les lire seul (le cookie de claude.ai ne donne ni le statusline de Claude Code, ni l'historique, ni les statistiques).

## Décision
1. **Une PWA, pas une application native.** Installable depuis Chrome (icône, plein écran, hors ligne), sans Play Store, sans APK à signer ni SDK à installer
   (la machine n'a ni Gradle ni Xcode, et l'objectif est d'installer le moins possible), et utilisable aussi sur iPhone.
2. **Le Mac pousse, le téléphone tire, via un relais.** Un Cloudflare Worker (gratuit, sur le compte d'Alane) garde un coffre par appareil. Le téléphone n'a besoin ni
   d'être sur le même réseau, ni d'un accès au Mac.
3. **Chiffrement de bout en bout (AES-256-GCM).** Le relais ne stocke que du texte chiffré. La clé voyage dans le fragment d'un lien (code QR), que le navigateur
   n'envoie jamais à un serveur. L'écriture exige un jeton dérivé de la clé par HMAC (le relais n'en garde que l'empreinte SHA-256).
4. **Désactivée par défaut.** « Rien ne quitte ta machine » reste vrai tant que la synchro n'est pas activée explicitement.
5. **Format versionné** (`MobileSnapshot.version`). Un champ ajouté est facultatif ; un changement de sens augmente la version.

## Alternatives écartées
- **Application native Android (Kotlin)** : toolchain à installer, signature, distribution ; aucun avantage décisif pour de l'affichage (les notifications push natives
  seraient le seul vrai gain, et une PWA peut aussi les recevoir via Web Push).
- **Lecture directe de claude.ai depuis le téléphone** : cookie à saisir sur mobile, pas de statusline, pas d'historique ni de statistiques.
- **Serveur HTTP local sur le Mac (même Wi-Fi)** : ne marche pas hors de la maison.
- **Telegram / ntfy comme interface** : utile pour des alertes, pas pour des graphiques ; compatible plus tard, en complément.

## Conséquences
- Un service à déployer une fois (`mobile/scripts/deploy-relay.mjs`) ; coût nul dans les limites gratuites de Cloudflare.
- Le Mac doit être allumé et UsageForecast ouvert pour que les données se rafraîchissent ; le téléphone affiche l'âge des données.
- La clé est dans le stockage local du téléphone : la perte d'un appareil se règle en changeant la clé depuis le Mac (Réassocier).
- Les deux langages (Swift, JavaScript) doivent rester d'accord : vecteur de chiffrement et cas de statistiques communs aux deux suites de tests.
- Les notifications quand l'application est fermée ne sont pas faites (Web Push demande un second service) : suite logique.
