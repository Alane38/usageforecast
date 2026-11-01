# Collecteur UsageForecast (invité d'un prêt de quota)

Petit programme pour la machine de la personne à qui le propriétaire du compte prête une part de sa semaine Claude (voir
`docs/adr/003-pret-de-quota.md`). Il tourne en arrière-plan sous **Windows, Linux ou macOS**, lit les journaux de Claude Code de cette machine
et envoie, **chiffrés**, les heures d'activité et les tokens par tranche de 5 minutes. Le Mac du propriétaire s'en sert pour savoir qui a
consommé quoi.

**Ce qui est envoyé** : des heures et des nombres (tokens d'entrée, de sortie, de cache, par modèle). **Jamais** : le texte des conversations,
les noms de projets, les chemins de fichiers. Un test le vérifie (`test/cycle.test.js`, avec contrôle négatif).

## Utilisation

```bash
collecteur associer https://ton-relais.workers.dev K7QM-4PZX   # avec le code donné par le propriétaire (onglet Prêt de son téléphone)
collecteur associer https://ton-relais.workers.dev     # sans code : crée un coffre et affiche le lien à transmettre au propriétaire
collecteur associer 'https://ton-relais.workers.dev/#v1.<id>.<clé>'   # ou : utilise le coffre donné par le propriétaire
collecteur une-fois --essai     # montre ce qui serait envoyé, sans rien envoyer
collecteur lancer               # tourne en continu
collecteur etat                 # association, dernier envoi, dernière activité vue
```

Le lien contient la clé : il se transmet par un canal privé. Sous Windows, l'exécutable n'est pas signé : SmartScreen demande
« Informations complémentaires › Exécuter quand même » au premier lancement.

## Fonctionnement

- **Journaux lus** : `CLAUDE_CONFIG_DIR/projects` s'il est défini, sinon `~/.config/claude/projects` et `~/.claude/projects`, sous-dossiers
  compris (sous-agents). Lecture incrémentale : chaque fichier reprend là où il s'était arrêté, ligne en cours d'écriture laissée pour plus tard.
- **Dédoublonnage** par `message.id` + `requestId` : Claude Code écrit souvent plusieurs fois la même réponse (sur une vraie session :
  132 lignes pour 55 réponses).
- **Envois** : seulement s'il y a eu de l'activité depuis le dernier, au plus toutes les 10 minutes, plus un signe de vie toutes les 6 h,
  150 par jour au maximum (le relais gratuit accepte 1 000 écritures par jour pour tout le compte).
- **Chiffrement** identique à l'application Mac (AES-256-GCM, jeton d'écriture HMAC) : le relais ne voit que du texte illisible.
- **Fichiers** (droits 0600) : `collecteur.json` (association) et `collecteur-etat.json` (avancement), dans `%APPDATA%\UsageForecast`
  (Windows), `~/Library/Application Support/UsageForecast` (macOS) ou `~/.config/usageforecast` (Linux).

## Développement

```bash
cd mobile
bun test collector                      # tests
bun collector/collector.js une-fois --essai
bun run build:collector                 # 5 exécutables autonomes (≈ 90 à 115 Mo : ils embarquent le runtime Bun) + SHA256SUMS
```

Avec un code, le collecteur affiche aussi le lien du **tableau de bord de l'invité** (l'application mobile, à ouvrir dans un navigateur).

Pas encore fait (ADR 003, étape 4) : révocation vérifiée, démarrage automatique avec la session.
