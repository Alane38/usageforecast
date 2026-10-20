# Sécurité

## Signaler une faille

Écris en privé via l'onglet **Security > Report a vulnerability** du dépôt GitHub. N'ouvre pas d'issue publique pour une faille. Tu auras une réponse sous une semaine.

## Ce que l'app manipule

- **Cookies claude.ai et Console** (facultatifs) : gardés dans le trousseau macOS pour les versions publiées, jamais écrits dans un journal ni envoyés ailleurs que vers Anthropic pour lire tes limites.
- **Synchro mobile** (désactivée par défaut) : le snapshot est chiffré en AES-256-GCM sur le Mac avant l'envoi vers un relais que tu héberges toi-même ; la clé ne transite que par le code d'association.
- **Mises à jour** : l'archive de la release est vérifiée par son empreinte SHA-256 et son identifiant avant remplacement ; l'ancienne version va à la Corbeille.

## Ce que l'app ne fait pas

Pas de compte, pas de serveur du projet, pas de télémétrie.

## Limite connue

Les versions ne sont pas notarisées par Apple : le certificat de signature est auto-signé, donc macOS redemande l'accès au trousseau après chaque mise à jour. Les points d'accès internes de claude.ai et de la Console peuvent changer sans préavis.
