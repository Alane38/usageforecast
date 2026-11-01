# 003 : prêt de quota à une autre personne, collecteur Linux / Windows / macOS

## Contexte
Alane prête par moments son compte Claude à une autre personne : il autorise sa machine avec le code de `/login` de Claude Code, et pendant
une période cette personne travaille avec le compte d'Alane. Il veut lui accorder une part de la limite **hebdomadaire** (par exemple 70 %,
Alane garde 30 %), que chacun voie où il en est, être alerté en cas de dépassement, et surtout **revenir à la situation d'avant** par une
révocation fiable. L'invité peut être sous Windows, Linux ou macOS ; UsageForecast n'existe que sur Mac (et en lecture sur téléphone).

Faits établis (vérifiés le 1er novembre 2026) :
- Les conditions grand public d'Anthropic (section 2, en vigueur depuis le 8 octobre 2025) disent : « You also may not make your Account
  available to anyone else. » Ce montage y est contraire ; c'est un choix assumé par Alane, signalé une fois, pas répété dans l'interface.
- Les limites (5 h, semaine) sont celles du compte : claude.ai et le `rate_limits` du statusline donnent **un seul pourcentage**, sans dire qui
  l'a consommé.
- Claude Code écrit chaque session dans `<config>/projects/<projet>/<session>.jsonl` ; chaque réponse porte l'heure, le modèle et
  `message.usage` (entrée, sortie, deux compteurs de cache). Format non documenté officiellement ; lignes en double possibles pendant le
  streaming (dédoublonner par `message.id` + `requestId`). Conservation : 30 jours par défaut (`cleanupPeriodDays`). `<config>` vaut
  `CLAUDE_CONFIG_DIR`, sinon `~/.claude` ou `~/.config/claude`.
- Révocation (aide officielle « How do I log out of all active sessions? ») : **Settings › Claude Code**, corbeille (ou la session dans
  **Settings › Account**) ; « Log Out » de Settings › Account déconnecte tout, Claude Code compris. Des utilisateurs ont signalé en avril 2026
  un jeton encore valide après révocation (ticket clos en mai 2026, correctif non décrit) : la révocation doit être **vérifiée**.
- Relais : le stockage clé-valeur gratuit de Cloudflare accepte 1 000 écritures par jour pour tout le compte ; le Mac en fait jusqu'à 288.

## Décision
1. **Un « prêt » est un objet explicite** : une personne, une part de la **semaine** (la limite de 5 h n'est pas partagée ; à revoir si elle
   pose problème), une période (par défaut jusqu'au prochain reset hebdomadaire), des droits de lecture (réserve d'Alane visible : oui par
   défaut ; historique d'Alane : non). Un seul prêt à la fois. Il se crée depuis le Mac (Réglages › Prêt) ou le téléphone (onglet Prêt).
2. **Un collecteur sur la machine de l'invité**, en JavaScript (`mobile/collector/`), compilé en un exécutable unique par plateforme avec
   `bun build --compile` (Windows, Linux, macOS). Il **ne lit que les journaux de Claude Code** : heures d'activité et tokens par tranche de
   5 minutes. Il ne touche pas aux réglages de Claude Code et n'envoie **jamais** de texte de conversation, de nom de projet ni de chemin.
   Le tableau de bord de l'invité est la PWA existante (navigateur ou application de bureau) : aucune seconde interface.
3. **Attribution faite par le Mac d'Alane**, qui a le pourcentage du compte (cookie) et lit le coffre du collecteur :
   - une hausse de la semaine pendant laquelle **seul** l'invité a de l'activité → à l'invité, **mesuré** ;
   - seul Alane actif (ses propres journaux Claude Code, ou une conversation claude.ai récente) → à Alane, **mesuré** ;
   - les deux actifs → réparti au prorata des tokens pondérés par modèle, **estimé** ;
   - personne d'actif → **inexpliqué** (pendant un prêt : attribué à l'invité et marqué estimé ; après un prêt : alerte).
   Chaque chiffre affiché dit s'il est mesuré ou estimé.
4. **Révocation en deux étapes, vérifiée côté Alane** : l'application guide vers Settings › Claude Code (elle ne peut pas couper l'accès
   elle-même), puis le Mac surveille la semaine pendant 48 h. Toute hausse sans activité d'Alane déclenche « activité inexpliquée après la fin
   du prêt », avec le chemin « Log Out » partout. La vérification ne dépend pas du collecteur de l'invité (qu'il peut arrêter). Fin du prêt :
   le lien de l'invité est invalidé et son coffre effacé.
5. **Alertes, des deux côtés**, avec la limite, la durée et l'hypothèse : seuil de la part (80 % par défaut), prévision de dépassement avant
   la fin du prêt, réserve d'Alane entamée, collecteur muet (l'attribution passe en estimation), activité inexpliquée (non désactivable).
6. **Budget d'écritures du relais** : le collecteur n'envoie que s'il y a eu de l'activité depuis le dernier envoi, au plus toutes les
   10 minutes (144 par jour au maximum), plus un signe de vie toutes les 6 h ; la vue partagée de l'invité est republiée au plus toutes les
   15 minutes (96). Total au pire ≈ 530 sur 1 000.
7. **Même chiffrement que l'ADR 002** : un coffre par collecteur, AES-256-GCM, jeton d'écriture `HMAC-SHA256(clé, "usageforecast/write")`,
   lien `v1.<id>.<clé>`. Le relais ne voit toujours que du texte chiffré.
8. **Quatrième canal de livraison**, séparé des trois autres : le collecteur a ses releases `collector-vX.Y.Z` (exécutables + SHA-256).
   Il ne fait jamais proposer de mise à jour au Mac ni à l'APK.

## Étapes
1. **Collecteur** (ce changement) : lecture incrémentale et dédoublonnée des journaux, tranches de 5 minutes, chiffrement, politique d'envoi,
   commandes `associer`, `une-fois`, `lancer`, `etat`, compilation multiplateforme. Association par lien `v1.<id>.<clé>` en attendant le code court.
2. Mac : lecture du coffre de l'invité, attribution (logique pure testée), bloc « Prêt » du popover, onglet Réglages › Prêt, alertes.
3. Relais et PWA : code d'invitation court à usage unique (15 min), coffre de contrôle pour créer un prêt depuis le téléphone, vue de
   l'invité, onglet Prêt.
4. Révocation vérifiée et fin de prêt (effacement du coffre : nouvelle route `DELETE` du relais, protégée par le jeton d'écriture).

## Alternatives écartées
- **Exiger le statusline chez l'invité** : il faudrait modifier ses réglages Claude Code, et `rate_limits` a déjà disparu dans une version
  (2.1.96). Il reste une source de secours possible, pas une dépendance.
- **Convertir les tokens en pourcentage** : le poids d'un token dépend du modèle et du cache, et Anthropic ne publie pas la formule.
  Les tokens ne servent qu'à répartir une hausse quand les deux personnes travaillent en même temps.
- **Application de bureau avec icône (Tauri, Electron)** : une seconde interface à maintenir pour un gain faible ; la PWA s'installe déjà
  comme application de bureau. À reconsidérer si l'invité réclame une icône dans la barre des tâches.
- **Plan Team ou API par personne** : la seule solution conforme et exacte (limites ou plafonds par personne), écartée par Alane pour l'instant.

## Conséquences
- L'exécutable Windows n'est pas signé : avertissement SmartScreen au premier lancement (« Exécuter quand même »).
- L'attribution suppose des horloges à l'heure (écart toléré : une tranche de 5 minutes).
- Si le format des journaux change, le collecteur voit moins d'activité : le Mac le signale (« collecteur muet ») au lieu d'attribuer en silence.
